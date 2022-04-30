import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'photolist_screen.dart';
import 'settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'dart:math';
import 'package:wakelock/wakelock.dart';

import 'package:disk_space/disk_space.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'log_screen.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;

bool disableCamera = kIsWeb; // true=test
final bool _testMode = false;

const Color COL_SS_TEXT = Color(0xFFbbbbbb);

class CameraScreen extends ConsumerWidget {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isRecording = false;
  bool _isScreensaver = false;

  DateTime? _startTime;
  DateTime? _recordTime;

  DateTime? lastDiskFreeError;
  Timer? _timer;
  Environment _env = Environment();
  ResolutionPreset _preset = ResolutionPreset.high; // 1280x720

  final Battery _battery = Battery();
  int _batteryLevel = -1;
  int _batteryLevelStart = -1;

  bool bInit = false;
  WidgetRef? _ref;
  BuildContext? _context;
  AppLifecycleState? _state;

  DeviceOrientation _orientation = DeviceOrientation.portraitUp;
  double _previewAngle = 0.0;

  void init(BuildContext context, WidgetRef ref) {
    if(_timer == null)
      _timer = Timer.periodic(Duration(seconds:1), _onTimer);
    if(bInit == false){
      _env.load();
      _initCameraSync(ref);
      bInit = true;
    }
  }

  @override
  void dispose() {
    if(_controller!=null) _controller!.dispose();
    if(_timer!=null) _timer!.cancel();
  }

  // low 320x240 (4:3)
  // medium 640x480 (4:3)
  // high 1280x720
  // veryHigh 1920x1080
  // ultraHigh 3840x2160
  ResolutionPreset getPreset() {
    ResolutionPreset p = ResolutionPreset.high;
    int h = _env.camera_height.val;
    if(h>=2160) p = ResolutionPreset.ultraHigh;
    else if(h>=1080) p = ResolutionPreset.veryHigh;
    else if(h>=720) p = ResolutionPreset.high;
    else if(h>=480) p = ResolutionPreset.medium;
    else if(h>=240) p = ResolutionPreset.low;
    return p;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    //setState(() { _state = state; });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    this._ref = ref;
    this._context = context;
    Future.delayed(Duration.zero, () => init(context,ref));
    ref.watch(redrawProvider);

    this._isScreensaver = ref.watch(isScreenSaverProvider);
    this._isRecording = ref.watch(isRecordingProvider);

    if(_isScreensaver) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      Wakelock.enable();
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: []);
      Wakelock.disable();
    }

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      body: Stack(children: <Widget>[

        NativeDeviceOrientationReader(
          useSensor: true,
          builder: (context) {
            if(_controller!=null && this._isRecording==false) {
              DeviceOrientation ori = DeviceOrientation.portraitUp;
              double ang = 0;

              // Video recording upside down.
              switch (NativeDeviceOrientationReader.orientation(context)) {
                case NativeDeviceOrientation.landscapeRight:
                  //ori = DeviceOrientation.landscapeLeft;
                  //ang = pi;
                  ori = DeviceOrientation.landscapeRight;
                  ang = 0;
                  break;
                case NativeDeviceOrientation.landscapeLeft:
                  //ori = DeviceOrientation.landscapeRight;
                  //ang = pi;
                  ori = DeviceOrientation.landscapeLeft;
                  ang = 0;
                  break;
                case NativeDeviceOrientation.portraitDown:
                  ori = DeviceOrientation.portraitDown;
                  ang = 0;
                  break;
                default:
                  break;
              }
              if(this._orientation != ori) {
                _orientation = ori;
                _previewAngle = ang;
                if(_controller!=null)
                  _controller!.lockCaptureOrientation(_orientation);
              }
            }
            return Container();
          }
        ),

        // screen saver
        if (_isScreensaver)
          ScreenSaver(startTime:_startTime),

        if(_isScreensaver==false)
          _cameraWidget(context),

        // Start or Stop button
        if (_isScreensaver==false)
          RecordButton(
            onPressed:(){
              onStart();
              _startTime = DateTime.now();
              ref.read(isScreenSaverProvider.state).state = true;
              ref.read(isRecordingProvider.state).state = true;
              //ref.read(redrawProvider).notifyListeners();
            },
          ),

        // Camera Switch button
        if(_isScreensaver==false)
          MyButton(
            bottom: 60.0, right: 60.0,
            icon: Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed:() => _onCameraSwitch(ref),
          ),

        // PhotoList screen button
        if(_isScreensaver==false)
          MyButton(
            top: 60.0, left: 60.0,
            icon: Icon(Icons.folder, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PhotoListScreen(),
                ));
            }
          ),

        // Settings screen button
        if(_isScreensaver==false)
          MyButton(
            top: 60.0, right: 60.0,
            icon: Icon(Icons.settings, color:Colors.white),
            onPressed:() async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(),
                )
              );
              await _env.load();
              if(_preset != getPreset()){
                print('-- change camera ${_env.camera_height.val}');
                _preset = getPreset();
                _initCameraSync(ref);
              }
            }
          ),
      ]),
    );
  }

  /// Camera
  Widget _cameraWidget(BuildContext context) {
    if(disableCamera) {
      return Positioned(
        left:0, top:0, right:0, bottom:0,
        child: Container(color: Color(0xFF222244)));
    }
    if (_controller == null) {
      return Center(
        child: SizedBox(
          width:32, height:32,
          child: CircularProgressIndicator(),
        ),
      );
    }

    Size _screenSize = MediaQuery.of(context).size;
    Size _cameraSize = _controller!.value.previewSize!;

    double sw = _screenSize.width;
    double sh = _screenSize.height;
    double dw = sw>sh ? sw : sh;
    double dh = sw>sh ? sh : sw;
    double _aspect = sw>sh ? _controller!.value.aspectRatio : 1/_controller!.value.aspectRatio;

    // 16:10 (Up-down black) or 17:9 (Left-right black)
    //double _scale = dw/dh < 16.0/9.0 ? dh/dw * 16.0/9.0 : dw/dh * 9.0/16.0;
    double _scale = dw/dh < _cameraSize.width/_cameraSize.height ? dh/dw * _cameraSize.width/_cameraSize.height : dw/dh * _cameraSize.height/_cameraSize.width;

    print('-- screen=${sw.toInt()}x${sh.toInt()}'
      ' camera=${_cameraSize.width.toInt()}x${_cameraSize.height.toInt()}'
      ' aspect=${_aspect.toStringAsFixed(2)}'
      ' scale=${_scale.toStringAsFixed(2)}');

    return Center(
      child: Transform.scale(
        scale: _scale,
        child: Transform.rotate(
          angle: _previewAngle,
          child: AspectRatio(
            aspectRatio: _aspect,
            child: CameraPreview(_controller!),
      ),),),
    );
  }

  Future<void> _initCameraSync(WidgetRef ref) async {
    if(disableCamera)
      return;
    print('-- _initCameraSync');
    _cameras = await availableCameras();
    if(_cameras.length > 0) {
      _controller = CameraController(_cameras[0], _preset, imageFormatGroup: ImageFormatGroup.yuv420);
      _controller!.initialize().then((_) {
        ref.read(redrawProvider).notifyListeners();
      });
    } else {
      print('-- err _cameras.length==0');
    }
  }

  /// _onCameraSwitch
  Future<void> _onCameraSwitch(WidgetRef ref) async {
    if(disableCamera || _cameras.length<2)
      return;
    final CameraDescription desc = (_controller!.description == _cameras[0]) ? _cameras[1] : _cameras[0];
    await _controller!.dispose();
    _controller = CameraController(desc, _preset);
    try {
      _controller!.initialize().then((_) {
        ref.read(redrawProvider).notifyListeners();
      });
    } on CameraException catch (e) {}
  }

  /// Start recording
  Future<bool> onStart() async {
    if(_testMode) {
      _env.recording_mode.val = 1;
      _env.image_interval_sec.val = 5;
      _env.autostop_sec.val = 30;
    }

    if(kIsWeb == false) {
      if (!_controller!.value.isInitialized) {
        print('-- err !_controller!.value.isInitialized');
        return false;
      }
      if (checkDiskFree()==false) {
        print('-- err checkDiskFree');
        return false;
      }
    }
    _isRecording = true;
    _startTime = DateTime.now();
    _batteryLevelStart = await _battery.batteryLevel;

    if(_env.recording_mode.val==1) {
      startRecording();
      await MyLog.info("Start video");
    } else if(_env.recording_mode.val==2) {
      photoShooting();
      await MyLog.info("Start photo");
    }

    return true;
  }

  /// Stop
  Future<void> onStop() async {
    print('-- onStop');
    try {
      await MyLog.info("Stopped " + recordingTimeString());
      if(_batteryLevelStart>0) {
        await MyLog.info("Battery ${_batteryLevelStart}>${_batteryLevel}%");
      }
      _isRecording = false;
      _startTime = null;
      _recordTime = null;

      if(_env.recording_mode.val==1)
        await stopRecording();

      await Future.delayed(Duration(milliseconds:100));
      await _deleteCacheDir();
    } on Exception catch (e) {
      print('-- onStop() Exception ' + e.toString());
    }
  }

  Future<void> startRecording() async {
    if(kIsWeb) {
      _recordTime = DateTime.now();
      return;
    }
    try {
      await _controller!.startVideoRecording();
      _recordTime = DateTime.now();
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<void> stopRecording() async {
    _recordTime = null;
    if(kIsWeb)
      return;
    if(_env.recording_mode.val==2)
      return;
    try {
      XFile xfile = await _controller!.stopVideoRecording();
      moveFile(File(xfile.path), await getSavePath('.mp4'));
    } on CameraException catch (e) {
      await MyLog.warn(e.code);
      if(e.description!=null)
        await MyLog.warn(e.description!);
      showSnackBar('${e.code}\n${e.description}');
      //_showCameraException(e);
    } on Exception catch (e) {
      print('-- stopRecording() e=${e.toString()}');
    }
  }

  Future<void> splitRecording() async {
    print('Split recording');

    if (_controller!=null && _controller!.value.isRecordingVideo==false)
      return;
    await stopRecording();
    await startRecording();
    _recordTime = DateTime.now();
  }

  Future<void> photoShooting() async {
    _recordTime = null;
    DateTime dt = DateTime.now();
    if (_controller==null)
      return;
    try {
      print('-- photoShooting');
      await _controller!.startVideoRecording();
      await Future.delayed(Duration(seconds: 1));
      XFile xfile = await _controller!.stopVideoRecording();

      String savepath = await getSavePath('.jpg');
      String? s = await video_thumbnail.VideoThumbnail.thumbnailFile(
        video: xfile.path,
        thumbnailPath: savepath,
        imageFormat: video_thumbnail.ImageFormat.JPEG,
        maxHeight: _env.camera_height.val,
        quality: 70);
      File(xfile.path).delete();
    } on Exception catch (e) {
      print('-- photoShooting() Exception ' + e.toString());
    }
    _recordTime = dt;
  }

  //src=/var/mobile/Containers/Data/Application/F168A64A-F632-469D-8CD6-390371BE4FAF/Documents/camera/videos/REC_E8ED36E1-3966-43A1-AB34-AA8AD34CEA08.mp4
  //dst=/var/mobile/Containers/Data/Application/F168A64A-F632-469D-8CD6-390371BE4FAF/Documents/photo/2022-0430-210906.mp4
  Future<File> moveFile(File sourceFile, String newPath) async {
    try {
      if(sourceFile.exists()==false) {
        print('-- moveFile not exists');
        await Future.delayed(Duration(milliseconds:100));
      }
      if(sourceFile.exists()==false) {
        print('-- moveFile not exists');
        await Future.delayed(Duration(milliseconds:100));
      }
      print('-- moveFile src=${sourceFile.path}');
      print('-- moveFile dst=${newPath}');
      return await sourceFile.rename(newPath);
    } on FileSystemException catch (e) {
      print('-- moveFile e=${e.message} ${e.path}');
      final newFile = await sourceFile.copy(newPath);
      await sourceFile.delete();
      return newFile;
    }
  }

  /// onTimer
  void _onTimer(Timer timer) async {
    if(this._batteryLevel<0)
      this._batteryLevel = await _battery.batteryLevel;

    if(_isRecording==false && _recordTime!=null) {
      onStop();
      return;
    }

    // /data/user/0/com.example.longtake/cache/CAP628722182744800763.mp4
    // /data/user/0/com.example.longtake/app_flutter/photo/2022-0410-175118.mp4
    if(_isRecording==true && _recordTime!=null) {
      Duration dur = DateTime.now().difference(_recordTime!);
      if(_env.recording_mode.val==1) {
        if (dur.inSeconds > _env.video_interval_sec.val) {
          splitRecording();
        }
      } else if(_env.recording_mode.val==2) {
        if (dur.inSeconds > _env.image_interval_sec.val) {
          photoShooting();
        }
      }
    }

    // Auto stop
    if(_isRecording==true && _startTime!=null) {
      Duration dur = DateTime.now().difference(_startTime!);
      if (_env.autostop_sec.val > 0 && dur.inSeconds>_env.autostop_sec.val) {
        await MyLog.info("Autostop");
        onStop();
        if(_ref!=null)
          _ref!.read(isRecordingProvider.state).state = false;
      }
    }

    // low battery, low disk
    if(DateTime.now().second == 0) {
      this._batteryLevel = await _battery.batteryLevel;
      if (this._batteryLevel < 10) {
        await MyLog.warn("Low battery");
        stopRecording();
      } else if (await checkDiskFree()==false) {
        await MyLog.warn("Low capacity");
        stopRecording();
      }
    }

    if(_state!=null) {
      if (_state == AppLifecycleState.inactive ||
          _state == AppLifecycleState.detached) {
        await MyLog.warn("App is stop or background");
        onStop();
      }
    }
  } // _onTimer

  Future<String> getSavePath(String ext) async {
    final Directory appdir = await getApplicationDocumentsDirectory();
    final String dirPath = '${appdir.path}/photo';
    await Directory(dirPath).create(recursive: true);
    return '$dirPath/${DateFormat("yyyy-MMdd-HHmmss").format(DateTime.now())}${ext}';
  }

  /// Whether there is 5GB of free space
  Future<bool> checkDiskFree() async {
    if(kIsWeb)
      return true;
    try {
      final Directory appdir = await getApplicationDocumentsDirectory();
      final String dirPath = '${appdir.path}/photo';
      await Directory(dirPath).create(recursive: true);

      final myDir = Directory(dirPath);
      List<FileSystemEntity> _files = myDir.listSync(recursive: true, followLinks: false);
      _files.sort((a,b) {
        return b.path.compareTo(a.path);
      });

      int totalSaveByte = 0;
      for(FileSystemEntity e in _files) {
        totalSaveByte += await File(e.path).length();
      }

      // max_size_gb
      for(int i=0; i<1000; i++) {
        if (totalSaveByte < _env.max_size_gb.val*1024*1024*1024)
          break;
        totalSaveByte -= await File(_files.last.path).length();
        await File(_files.last.path).delete();
        _files.removeLast();
      }

      // Disk Free > 5GB
      int enough = 5;
      if(_testMode)
        enough = 1;

      double? freeMb = await DiskSpace.getFreeDiskSpace;
      int freeGb = 0;
      if(freeMb!=null)
        freeGb = (freeMb / 1024.0).toInt();
      if(freeGb < enough) {
        if(lastDiskFreeError==null || DateTime.now().difference(lastDiskFreeError!).inSeconds>120) {
          await MyLog.warn("Not enough free space ${freeGb.toString()}<${enough} GB");
          lastDiskFreeError = DateTime.now();
        }
        return false;
      }
    } on Exception catch (e) {
      print('-- checkDiskFree() Exception ' + e.toString());
    }
    return true;
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showSnackBar('Error: ${e.code}\n${e.description}');
  }

  void showSnackBar(String msg) {
    if(_context!=null) {
      final snackBar = SnackBar(content: Text(msg));
      ScaffoldMessenger.of(_context!).showSnackBar(snackBar);
    }
  }

  void logError(String code, String? message) {
    print('-- Error Code: $code\n-- Error Message: $message');
  }

  /// Delete the garbage data of the picture.
  Future<void> _deleteCacheDir() async {
    try{
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
    } on Exception catch (e) {
      print('-- _deleteCacheDir() Exception ' + e.toString());
    }
  }

  @override
  bool get wantKeepAlive => true;

  Widget MyButton({required Icon icon, required void Function()? onPressed,
    double? left, double? top, double? right, double? bottom}) {
    return Positioned(
      left:left, top:top, right:right, bottom:bottom,
      child: CircleAvatar(
        backgroundColor: Colors.black54,
        radius: 28.0,
        child: IconButton(
          icon: icon,
          iconSize: 38.0,
          onPressed: onPressed,
        )
      )
    );
  }

  Widget RecordButton({required void Function()? onPressed}) {
    return Center(
      child: Container(
        width: 160, height: 160,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.black26,
            shape: const CircleBorder(
              side: BorderSide(
                color: Colors.white,
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
          ),
          child:Text('START', style:TextStyle(fontSize:16, color:Colors.white)),
          onPressed: onPressed,
        )
      )
    );
  }

  /// 1:00:00
  /// Time from start to stop
  String recordingTimeString() {
    String s = '';
    if(_startTime!=null) {
      Duration dur = DateTime.now().difference(_startTime!);
      s = dur2str(dur);
    }
    return s;
  }

  /// 01:00:00
  String dur2str(Duration dur) {
    String s = "";
    if(dur.inHours>0)
      s += dur.inHours.toString() + ':';
    s += dur.inMinutes.remainder(60).toString().padLeft(2,'0') + ':';
    s += dur.inSeconds.remainder(60).toString().padLeft(2,'0');
    return s;
  }
}

final screenSaverProvider = ChangeNotifierProvider((ref) => ChangeNotifier());
class ScreenSaver extends ConsumerWidget {
  Timer? _timer;
  DateTime? _waitTime;
  DateTime? _startTime;
  WidgetRef? _ref;
  Environment _env = Environment();
  bool _isRecording = true;

  ScreenSaver({DateTime? startTime}){
    this._startTime = startTime;
    this._waitTime = DateTime.now();
  }

  void init(WidgetRef ref) {
    if(_timer==null){
      _timer = Timer.periodic(Duration(seconds:1), _onTimer);
      _env.load();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    this._ref = ref;
    Future.delayed(Duration.zero, () => init(ref));
    ref.watch(screenSaverProvider);
    _isRecording = ref.read(isRecordingProvider);
    //SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays:[]);

    return Scaffold(
      extendBody: true,
      body: Stack(children: <Widget>[
        Positioned(
          top:0, bottom:0, left:0, right:0,
          child: TextButton(
            child: Text(''),
            style: ButtonStyle(backgroundColor:MaterialStateProperty.all<Color>(Colors.black)),
            onPressed:(){
              _waitTime = DateTime.now();
            },
          )
        ),
        if(_waitTime!=null)
          Center(
            child: Container(
              width: 160, height: 160,
              child: StopButton(
                onPressed:(){
                  _waitTime = null;
                  ref.read(isScreenSaverProvider.state).state = false;
                  ref.read(isRecordingProvider.state).state = false;
                }
              )
            )
          ),

        if(_waitTime!=null)
          Positioned(
            bottom:60, left:0, right:0,
            child: Text(recordingString(),
                textAlign:TextAlign.center,
                style:TextStyle(color:COL_SS_TEXT),
          )),

        if(_waitTime!=null)
          Positioned(
            bottom:40, left:0, right:0,
            child: Text(
                elapsedTimeString(),
                textAlign:TextAlign.center,
                style:TextStyle(color:COL_SS_TEXT),
          )),

        ]
      )
    );
  }

  void _onTimer(Timer timer) async {
    try {
      if(_waitTime!=null) {
        if (DateTime.now().difference(_waitTime!).inSeconds > 5) {
          _waitTime = null;
        }
        if (this._ref != null) {
          _ref!.read(screenSaverProvider).notifyListeners();
        }
      }
    } on Exception catch (e) {
      print('-- ScreenSaver _onTimer() Exception '+e.toString());
    }
  }

  Widget StopButton({required void Function()? onPressed}) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: Colors.black26,
        shape: const CircleBorder(
          side: BorderSide(
            color: COL_SS_TEXT,
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
      ),
      child: Text('STOP', style:TextStyle(fontSize:16, color:COL_SS_TEXT)),
      onPressed: onPressed,
    );
  }

  String recordingString() {
    String s = '';
    if(_isRecording==false){
      s = 'Stoped';
    } else if(_env.recording_mode.val==1){
      s = 'Now Video Taking';
    } else if(_env.recording_mode.val==2){
      s = 'Now Photo Taking';
    } else if(_env.recording_mode.val==3){
      s = 'Now Audio Taking';
    }
    return s;
  }

  String elapsedTimeString(){
    String s = '';
    if(_startTime!=null && _isRecording) {
      Duration dur = DateTime.now().difference(_startTime!);
      s = dur2str(dur);
    }
    return s;
  }
  
  /// 01:00:00
  String dur2str(Duration dur) {
    String s = "";
    if(dur.inHours>0)
      s += dur.inHours.toString() + ':';
    s += dur.inMinutes.remainder(60).toString().padLeft(2,'0') + ':';
    s += dur.inSeconds.remainder(60).toString().padLeft(2,'0');
    return s;
  }
}