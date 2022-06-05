import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'photolist_screen.dart';
import 'settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imglib;
import 'package:wakelock/wakelock.dart';

import 'package:disk_space/disk_space.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'log_screen.dart';
import 'common.dart';
import 'camera_adapter.dart';

bool disableCamera = kIsWeb; // true=test
final bool _testMode = true;

const Color COL_SS_TEXT = Color(0xFFbbbbbb);
final cameraScreenProvider = ChangeNotifierProvider((ref) => ChangeNotifier());

class CameraScreen extends ConsumerWidget {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isRecording = false;
  bool _isScreensaver = false;
  int _photoCount = 0;
  DateTime? _startTime;
  DateTime? _recordTime;

  Timer? _timer;
  Environment _env = Environment();
  ResolutionPreset _preset = ResolutionPreset.high; // 1280x720
  ImageFormatGroup _imageFormat = ImageFormatGroup.bgra8888;

  final Battery _battery = Battery();
  int _batteryLevel = -1;
  int _batteryLevelStart = -1;

  bool bInit = false;
  WidgetRef? _ref;
  BuildContext? _context;
  AppLifecycleState? _state;

  MyEdge _edge = MyEdge(provider:cameraScreenProvider);
  MyStorage _storage = new MyStorage();

  void init(BuildContext context, WidgetRef ref) {
    if(bInit == false){
      bInit = true;
      _timer = Timer.periodic(Duration(seconds:1), _onTimer);
      _env.load();
      _initCameraSync(ref);
      _storage.getInApp();
      _storage.getLibrary();
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
    ref.watch(cameraScreenProvider);

    this._isScreensaver = ref.watch(isScreenSaverProvider);
    this._isRecording = ref.watch(isRecordingProvider);

    if(_isScreensaver) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays:[]);
      Wakelock.enable();
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays:[]);
      Wakelock.disable();
    }

    _edge.getEdge(context,ref);

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      body: Container(
        margin: _edge.homebarEdge,
        child: Stack(children: <Widget>[

        // screen saver
        if (_isScreensaver)
          ScreenSaver(startTime:_startTime),

        if(_isScreensaver==false)
          _cameraWidget(context),

        // START
        if (_isScreensaver==false)
          RecordButton(
            onPressed:(){
              onStart();
            },
          ),

        // Camera Switch button
        if(_isScreensaver==false)
          MyButton(
            bottom: 30.0, right: 30.0,
            icon: Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed:() => _onCameraSwitch(ref),
          ),

        // PhotoList screen button
        if(_isScreensaver==false)
          MyButton(
            top:50.0, left:30.0,
            icon: Icon(Icons.folder, color: Colors.white),
            onPressed:() {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PhotoListScreen(),
                )
              );
            }
          ),

        // Settings screen button
        if(_isScreensaver==false)
          MyButton(
            top: 50.0, right: 30.0,
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
        ]
      ),
    ));
  }

  /// カメラウィジェット
  Widget _cameraWidget(BuildContext context) {
    if(disableCamera) {
      return Positioned(
        left:0, top:0, right:0, bottom:0,
        child: Container(color: Color(0xFF222244)));
    }
    if (_controller == null || _controller!.value.previewSize == null) {
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
        child: AspectRatio(
          aspectRatio: _aspect,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  /// カメラ初期化
  Future<void> _initCameraSync(WidgetRef ref) async {
    if(disableCamera)
      return;
    print('-- _initCameraSync');
    _cameras = await availableCameras();
    int pos = _env.camera_pos.val;
    if(_cameras.length<=0) {
      MyLog.err("Camera not found");
      return;
    }
    if(_cameras.length == 1) {
      pos = 0;
    }
    _controller = CameraController(
      _cameras[pos],
      _preset,
      imageFormatGroup:_imageFormat,
      enableAudio:_env.recording_mode==1
    );

    _controller!.initialize().then((_) {
      if(_ref!=null)
        _ref!.read(cameraScreenProvider).notifyListeners();
    });
  }

  /// スイッチ
  Future<void> _onCameraSwitch(WidgetRef ref) async {
    if(disableCamera || _cameras.length<2)
      return;

    int pos = _env.camera_pos.val==0 ? 1 : 0;
    _env.camera_pos.set(pos);
    _env.save(_env.camera_pos);

    await _controller!.dispose();
    _controller = CameraController(
      _cameras[pos],
      _preset,
      imageFormatGroup:_imageFormat,
      enableAudio:_env.recording_mode==1
    );
    try {
      _controller!.initialize().then((_) {
        if(_ref!=null)
          _ref!.read(cameraScreenProvider).notifyListeners();
      });
    } catch (e) {
      await MyLog.err('${e.toString()}');
    }
  }

  /// 開始
  Future<bool> onStart() async {
    if(kIsWeb) {
      _isRecording = true;
      _startTime = DateTime.now();
      _batteryLevelStart = await _battery.batteryLevel;
      if(_ref!=null) {
        _ref!.read(isScreenSaverProvider.state).state = true;
        _ref!.read(isRecordingProvider.state).state = true;
      }
    }

    if (_controller!.value.isInitialized==false) {
      print('-- err _controller!.value.isInitialized==false');
      return false;
    }

    if (isUnitStorageFree()==false) {
      print('-- err isUnitStorageFree');
      return false;
    }

    _isRecording = true;
    _startTime = DateTime.now();
    _batteryLevelStart = await _battery.batteryLevel;

    // 先にセーバー起動
    if(_ref!=null) {
      _ref!.read(isScreenSaverProvider.state).state = true;
      _ref!.read(isRecordingProvider.state).state = true;
    }

    if(_env.recording_mode.val==1) {
      startRecording();
      await MyLog.info("Start video");

    } else if(_env.recording_mode.val==2) {
      _photoCount = 0;
      photoShooting();
      await MyLog.info("Start photo");
    }
    return true;
  }

  /// 停止
  Future<void> onStop() async {
    print('-- onStop');
    try {
      if(_env.recording_mode.val==1) {
        await MyLog.info("Stop video " + recordingTimeString());
      } else if(_env.recording_mode.val==2) {
        await MyLog.info("Stop photo %{_photoCount}");
      }
      if(_batteryLevelStart>0) {
        await MyLog.info("Battery ${_batteryLevelStart}->${_batteryLevel}%");
      }
      _isRecording = false;
      _startTime = null;
      _recordTime = null;

      if(_ref!=null)
        _ref!.read(isRecordingProvider.state).state = false;

      if(_env.recording_mode.val==1) {
        await stopRecording();
      } else if(_env.recording_mode.val==2) {
        if(_controller!.value.isStreamingImages)
          _controller!.stopImageStream();
      }

      await Future.delayed(Duration(milliseconds:100));
      await _deleteCacheDir();
    } on Exception catch (e) {
      print('-- onStop() Exception ' + e.toString());
    }
  }

  // 録画開始
  Future<void> startRecording() async {
    if(kIsWeb) {
      _recordTime = DateTime.now();
      return;
    }
    try {
      if(_controller!.value.isRecordingVideo)
        await _controller!.stopVideoRecording();
      await _controller!.startVideoRecording();
      _recordTime = DateTime.now();

    } on CameraException catch (e) {
      await MyLog.err(e.code + ' ' + (e.description ?? ''));
    } catch (e) {
      await MyLog.err('${e.toString()}');
    }
  }

  // 録画停止
  Future<void> stopRecording() async {
    _recordTime = null;
    if(kIsWeb)
      return;
    try{
      if(_controller!.value.isRecordingVideo) {
        XFile xfile = await _controller!.stopVideoRecording();
        String dst = await getSavePath('.mp4');
        await moveFile(src:xfile.path, dst:dst);
        if(_env.ex_storage.val==1
            && _storage.libraryTotalBytes/1024/1024<_env.ex_save_mb.val){
          _storage.saveLibrary(dst);
        }
      }
    } on CameraException catch (e) {
      await MyLog.err(e.code + ' ' + (e.description ?? ''));
    } catch (e) {
      await MyLog.err('${e.toString()}');
    }
  }

  // 分割
  Future<void> splitRecording() async {
    print("splitRecording");
    await stopRecording();
    await startRecording();
  }

  // 写真
  Future<void> photoShooting() async {
    print("photoShooting");
    _recordTime = null;
    DateTime dt = DateTime.now();
    try {
      imglib.Image? img = await CameraAdapter.takeImage(_controller);
      if(img!=null) {
        String path = await getSavePath('.jpg');
        final File file = File(path);
        await file.writeAsBytes(imglib.encodeJpg(img));
        if(_env.ex_storage.val==1
            && _storage.libraryTotalBytes/1024/1024<_env.ex_save_mb.val) {
          _storage.saveLibrary(path);
        }
        _recordTime = dt;
        _photoCount++;
      } else {
        print('-- photoShooting img=null');
      }
    } catch (e) {
      await MyLog.err('${e.toString()}');
    }
  }

  //src=/var/mobile/Containers/Data/Application/F168A64A-F632-469D-8CD6-390371BE4FAF/Documents/camera/videos/REC_E8ED36E1-3966-43A1-AB34-AA8AD34CEA08.mp4
  //dst=/var/mobile/Containers/Data/Application/F168A64A-F632-469D-8CD6-390371BE4FAF/Documents/photo/2022-0430-210906.mp4
  Future<File> moveFile({required String src, required String dst}) async {
    File srcfile = File(src);
    try {
      if (await srcfile.exists() == false) {
        MyLog.warn('move file not exists');
        await Future.delayed(Duration(milliseconds: 100));
        if (await srcfile.exists() == false) {
          MyLog.warn('move file not exists 2');
          await Future.delayed(Duration(milliseconds: 100));
        }
      }
      print('-- move file src=${src}');
      print('-- move file dst=${dst}');
      return await srcfile.rename(dst);

    } on FileSystemException catch (e) {
      MyLog.err('move file e=${e.message} path=${e.path}');
      final newfile = await srcfile.copy(dst);
      await srcfile.delete();
      return newfile;
    }
  }

  /// タイマー
  void _onTimer(Timer timer) async {
    if(this._batteryLevel<0)
      this._batteryLevel = await _battery.batteryLevel;

    // セーバーで停止ボタンを押したとき
    if(_isRecording==false && _recordTime!=null) {
      onStop();
      return;
    }

    // 自動停止
    if(_isRecording==true && _startTime!=null) {
      Duration dur = DateTime.now().difference(_startTime!);
      if (_env.autostop_sec.val > 0 && dur.inSeconds>_env.autostop_sec.val) {
        await MyLog.info("Autostop");
        onStop();
        return;
      }
    }

    // バッテリーチェック（1分毎）
    if(_isRecording==true && DateTime.now().second == 0) {
      this._batteryLevel = await _battery.batteryLevel;
      if (this._batteryLevel < 10) {
        await MyLog.warn("Low battery");
        onStop();
        return;
      }
    }

    // 分割
    if(_isRecording==true && _recordTime!=null) {
      Duration dur = DateTime.now().difference(_recordTime!);
      if(_env.recording_mode.val==1) {
        if (dur.inSeconds > _env.video_interval_sec.val) {
          if(await isUnitStorageFree()) {
            splitRecording();
          } else {
            onStop();
          }
        }
      } else if(_env.recording_mode.val==2) {
        if (dur.inSeconds > _env.image_interval_sec.val) {
          if(await isUnitStorageFree() && (_photoCount%5)==0) {
            photoShooting();
          } else {
            onStop();
          }
        }
      }
    }

    if(_isRecording==true && _state!=null) {
      if (_state == AppLifecycleState.inactive ||
          _state == AppLifecycleState.detached) {
        await MyLog.warn("App is stop or background");
        onStop();
        return;
      }
    }
  } // _onTimer

  Future<String> getSavePath(String ext) async {
    final Directory appdir = await getApplicationDocumentsDirectory();
    final String dirPath = '${appdir.path}/photo';
    await Directory(dirPath).create(recursive: true);
    return '$dirPath/${DateFormat("yyyy-MMdd-HHmmss").format(DateTime.now())}${ext}';
  }

  /// 本体ストレージの空き容量
  Future<bool> isUnitStorageFree() async {
    if(kIsWeb)
      return true;
    try {
      await _storage.getInApp();
      int totalByte = _storage.totalBytes;

      // アプリ内で上限を超えた古いものを削除
      for(int i=0; i<1000; i++) {
        if (totalByte < _env.save_mb.val*1024*1024)
          break;
        totalByte -= await File(_storage.files.last.path).length();
        await File(_storage.files.last.path).delete();
        _storage.files.removeLast();
      }

      // 本体の空きが5GB必要
      int enough = 5;
      if(_testMode)
        enough = 0;

      double? totalMb = await DiskSpace.getTotalDiskSpace;
      double? freeMb = await DiskSpace.getFreeDiskSpace;
      int totalGb = totalMb!=null ? (totalMb / 1024.0).toInt() : 0;
      int freeGb = freeMb!=null ? (freeMb / 1024.0).toInt() : 0;
      if(freeGb < enough) {
        await MyLog.warn("Not enough free space ${freeGb}/${totalGb} GB");
        return false;
      }

      if(_env.ex_storage.val>0){
        _storage.getLibrary();
      }
    } on Exception catch (e) {
      print('-- checkDiskFree() Exception ' + e.toString());
    }
    return true;
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

  /// キャッシュ削除
  /// data/user/0/com.example.longtake/cache/CAP628722182744800763.mp4
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

  /// 録画時間の文字列
  String recordingTimeString() {
    String s = '';
    if(_startTime!=null) {
      Duration dur = DateTime.now().difference(_startTime!);
      s = dur2str(dur);
    }
    return s;
  }

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
  bool bInit = false;

  ScreenSaver({DateTime? startTime}){
    this._startTime = startTime;
    this._waitTime = DateTime.now();
  }

  void init(WidgetRef ref) {
    if(bInit==false){
      bInit = true;
      _env.load();
      _timer = Timer.periodic(Duration(seconds:1), _onTimer);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    this._ref = ref;
    Future.delayed(Duration.zero, () => init(ref));
    ref.watch(screenSaverProvider);
    _isRecording = ref.read(isRecordingProvider);

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

        // STOPボタン
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

        // 録画中
        if(_waitTime!=null)
          Positioned(
            bottom:60, left:0, right:0,
            child: Text(
              recordingString(),
              textAlign:TextAlign.center,
              style:TextStyle(color:COL_SS_TEXT),
          )),

        // 経過時間
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
        if(DateTime.now().difference(_waitTime!).inSeconds > 5)
          _waitTime = null;
        if(_ref!=null)
          _ref!.read(screenSaverProvider).notifyListeners();
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
    if(_timer==null){
      s = '';
    } else if(_isRecording==false){
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