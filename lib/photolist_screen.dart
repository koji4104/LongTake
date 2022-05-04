import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;
import 'model.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'localizations.dart';
import 'package:video_player/video_player.dart';
import 'dart:math';

class PhotoListScreen extends ConsumerWidget {
  PhotoListScreen(){}
  
  String title='In-app data';
  List<PhotoData> dataList = [];
  int numIndex = 20;

  bool _init = false;
  int selectedIndex = 0;
  BuildContext? context;
  WidgetRef? ref;

  void init(BuildContext context, WidgetRef ref) {
    if(_init == false){
      readFiles(ref);
      _init = true;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    this.context = context;
    this.ref = ref;
    int num = ref.watch(photoListProvider).num;
    int size = ref.watch(photoListProvider).size;
    int sizemb = (size/1024/1024).toInt();
    //print('-- num=${num}');

    Future.delayed(Duration.zero, () => init(context,ref));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n("photolist_title")),
        backgroundColor:Color(0xFF000000),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.save),
            iconSize: 32.0,
            onPressed: () => _saveFileWithDialog(context,ref),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            iconSize: 32.0,
            onPressed: () => _deleteFileWithDialog(context,ref),
          ),
          SizedBox(width: 10),
        ],
      ),
      body: Stack(children: <Widget>[
      Container(
      margin: EdgeInsets.symmetric(vertical:4, horizontal:10),
          child:Row(mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.image, size: 12.0, color: Colors.white),
            SizedBox(width: 4),
            Text(num.toString()),
            SizedBox(width: 8),
            Icon(Icons.folder, size: 12.0, color: Colors.white),
            SizedBox(width: 4),
            Text(sizemb.toString() + ' MB'),
          ]
        )
      ),
      Container(
        margin: EdgeInsets.only(top:24),
        child:getListView(context,ref),
        )
      ])
    );
  }

  Widget getListView(BuildContext context, WidgetRef ref) {
    int crossAxisCount = 3;
    double w = MediaQuery.of(context).size.width;
    if(w>800)
      crossAxisCount = 5;
    else if(w>600)
      crossAxisCount = 4;

      return Container(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        children: List.generate(dataList.length, (index) {
          return MyCard(data: dataList[index]);
        })),
    );
  }

  // /data/user/0/com.example.longtake/app_flutter/photo/2022-0417-170926.mp4
  Future<bool> readFiles(WidgetRef ref) async {
    try {
      dataList.clear();
      if (kIsWeb) {
        for (int i = 1; i < 30; i++) {
          PhotoData d = new PhotoData('');
          int h = (i / 10).toInt();
          int m = (i % 10).toInt();
          d.date = DateTime(2022, 1, 1, h, m, 0);
          d.path = 'aaa.mp4';
          d.playtime = i*1800;
          dataList.add(d);
        }
      } else {
        final Directory appdir = await getApplicationDocumentsDirectory();
        final photodir = Directory('${appdir.path}/photo');
        await Directory('${appdir.path}/photo').create(recursive: true);
        List<FileSystemEntity> _files = photodir.listSync(recursive:true, followLinks:false);
        _files.sort((a,b) { return b.path.compareTo(a.path); });

        print('-- photolist readFiles() _files.length=${_files.length}');

        final _thumbdir = Directory('${appdir.path}/thumb');
        await Directory('${appdir.path}/thumb').create(recursive: true);
        List<FileSystemEntity> _entities = _thumbdir.listSync(recursive:true, followLinks:false);
        List<String> _thumbs = [];
        for (FileSystemEntity e in _entities) {
          _thumbs.add(e.path);
        }

        final String thumbDir = '${appdir.path}/thumb/';
        for (FileSystemEntity file in _files) {
          PhotoData d = new PhotoData(file.path);
          if(d.path.substring(d.path.length-4,d.path.length)=='.mp4') {
            if(File(file.path).exists()==false){
              print('-- photolist readFiles() not found=${file.path}');
              continue;
            }
            d.thumb = thumbDir + basenameWithoutExtension(file.path) + ".jpg";

            if (await File(d.thumb).exists() == false) {
              print('-- photolist d.path=${d.path}');
              print('-- photolist d.thumb=${d.thumb}');
              try{
                String? s = await video_thumbnail.VideoThumbnail.thumbnailFile(
                  video: file.path,
                  thumbnailPath: d.thumb,
                  imageFormat: video_thumbnail.ImageFormat.JPEG,
                  maxHeight: 240,
                  quality: 70);
                d.thumb = (s != null) ? s : "";
              } on Exception catch (e) {
                print('-- err thumbnail');
              }
            }

            if (_thumbs.indexOf(d.thumb) >= 0)
              _thumbs.removeAt(_thumbs.indexOf(d.thumb));

            VideoData? info = await FlutterVideoInfo().getVideoInfo(d.path);
            if(info != null && info.duration != null){
              d.playtime = (info.duration!/1000.0).toInt();
            }

          } else if(d.path.substring(d.path.length-4,d.path.length)=='.jpg') {
            d.thumb = d.path;
          }

          d.date = file.statSync().modified;
          d.byte = await File(d.path).length();
          dataList.add(d);
        } // for

        // delete unused thumbnail
        for (String u1 in _thumbs) {
          if (await File(u1).exists()) {
            await File(u1).delete();
          }
        }
      }

      int totalBytes = 0;
      if (kIsWeb==false) {
        for (PhotoData d in dataList) {
          if (await File(d.path).exists())
            totalBytes += d.byte;
        }
      }

      ref.read(photoListProvider).num = dataList.length;
      ref.read(photoListProvider).size = totalBytes;
      ref.read(photoListProvider).notifyListeners();

    } on Exception catch (e) {
      print('-- readFiles() e=' + e.toString());
    }
    return true;
  }

  /// Save file
  /// Move to photolibrary
  _saveFileWithDialog(BuildContext context, WidgetRef ref) async {
    List<PhotoData> list = ref.read(selectedListProvider).list;
    Text msg = Text('Save to photolibrary (${list.length})');
    Text btn = Text('OK', style:TextStyle(fontSize:16, color:Colors.lightBlue));
    showDialogEx(context, msg, btn, _saveFile, list);
  }
  _saveFile(List<PhotoData> list) async {
    try {
      for(PhotoData data in list){
        if(data.path.contains('.jpg'))
          await GallerySaver.saveImage(data.path);
        else if(data.path.contains('.mp4'))
          await GallerySaver.saveVideo(data.path);

        await File(data.path).delete();
        if(await File(data.thumb).exists())
          await File(data.thumb).delete();

        await new Future.delayed(new Duration(milliseconds:100));
      }
      if(this.ref!=null)
        readFiles(this.ref!);
    } on Exception catch (e) {
      print('-- _saveFile ${e.toString()}');
    }
  }

  /// delete file
  _deleteFileWithDialog(BuildContext context, WidgetRef ref) async {
    List<PhotoData> list = ref.read(selectedListProvider).list;
    Text msg = Text('Delete files (${list.length})');
    Text btn = Text('Delete', style:TextStyle(fontSize:16, color:Colors.lightBlue));
    showDialogEx(context, msg, btn, _deleteFile, list);
  }

  _deleteFile(List<PhotoData> list) async {
    try {
      for(PhotoData data in list){
        await File(data.path).delete();
        if(await File(data.thumb).exists())
          await File(data.thumb).delete();
        await new Future.delayed(new Duration(milliseconds:100));
      };
      if(this.ref!=null)
        readFiles(this.ref!);
    } on Exception catch (e) {
      print('-- _deleteFile ${e.toString()}');
    }
  }

  /// Show dialog (OK or Cancel)
  Future<void> showDialogEx(
      BuildContext context,
      Text msg,
      Text buttonText,
      Function func,
      List<PhotoData> list
    ) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: msg,
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style:TextStyle(fontSize:16, color:Colors.lightBlue)),
              onPressed:(){ Navigator.of(context).pop(); },
            ),
            TextButton(
              child: buttonText,
              onPressed:(){ func(list); Navigator.of(context).pop(); },
            ),
          ],
        );
      }
    );
  }

  String l10n(String text){
    return Localized.of(context!).text(text);
  }
}

class MyCard extends ConsumerWidget {
  MyCard({PhotoData? data}) {
    if(data!=null) this.data = data;
  }

  PhotoData data = PhotoData('');
  bool _selected = false;

  @override
  Widget build(BuildContext context, WidgetRef ref){
    _selected = ref.watch(selectedListProvider).contains(data);

    return Container(
      width: 100.0, height: 100.0,
      margin: EdgeInsets.all(4),
      padding: EdgeInsets.all(0),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap:(){
          ref.read(selectedListProvider).select(data);
        },
        onLongPress:(){
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PreviewScreen(data:data),
            ));
        },
        child: getWidget(ref),
      ),
    );
  }

  Widget getWidget(WidgetRef ref){
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if(kIsWeb) Image.network('/lib/assets/test.png',fit:BoxFit.cover)
        else Image.file(File(data.thumb), fit:BoxFit.cover),
        
        Container(
          child: Text(' ' + DateFormat("MM/dd HH:mm").format(data.date) + ' ',
            style: TextStyle(fontSize:14, color:Colors.white, backgroundColor:Colors.black38),
        ),),

        if(data.path.contains('.mp4'))
          Positioned(
            bottom: 0.0, left: 0.0,
            child: Text(' ' + sec2strtime(data.playtime) + ' ',
              style: TextStyle(fontSize:14, color:Colors.white, backgroundColor:Colors.black38),
            ),),

        Positioned(
          right: 6.0, bottom: 6.0,
          child: CircleAvatar(
            backgroundColor: _selected ? Colors.black54 : Color(0x00000000),
            child: Icon(_selected ? Icons.check : null,
              size: 36,
              color: Color(0xFFFF3333)
        ))),
      ]
    );
  }

  String sec2strtime(int sec) {
    String s = "";
    s += (sec/3600).toInt().toString() + ':';
    s += (sec.remainder(3600)/60).toInt().toString().padLeft(2,'0') + ':';
    s += sec.remainder(60).toString().padLeft(2,'0');
    return s;
  }
}

final previewScreenProvider = ChangeNotifierProvider((ref) => ChangeNotifier());
class PreviewScreen extends ConsumerWidget {
  PreviewScreen({PhotoData? data}) {
    if(data!=null) this.data = data;

  }
  PhotoData data = PhotoData('');
  VideoPlayerController? _controller;
  VideoData? _videoInfo;
  WidgetRef? _ref;
  Image? _img;
  bool _init = false;

  void init(BuildContext context, WidgetRef ref) async {
    if(_init == false){
      try{
        if(data.path.contains('.mp4')){
          print('-- init mp4');
          _videoInfo = await FlutterVideoInfo().getVideoInfo(data.path);
          _controller = VideoPlayerController.file(File(data.path));
          if(_controller!=null) {
            _controller!.initialize().then((_) {
              ref.read(previewScreenProvider).notifyListeners();
            });
          } else {
            print('-- _controller is null');
          }

        } else if(data.path.contains('.jpg')){
          _img = Image.file(File(data.path), fit:BoxFit.contain);
        }
      } on Exception catch (e) {
        print('-- PreviewScreen.init ${e.toString()}');
      }
      _init = true;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref){
    Future.delayed(Duration.zero, () => init(context,ref));
    ref.watch(previewScreenProvider);
    this._ref = ref;

    return Scaffold(
      appBar: AppBar(
        title: Text('Preview'),
        actions: <Widget>[],
      ),
      body: Container(
        margin: EdgeInsets.all(10),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap:(){
            Navigator.of(context).pop();
          },
          child: Stack(children: <Widget>[
            player(),
            getInfoText(),
          ])
        ),
    ));
  }

  Widget player() {
    if(kIsWeb) {
      return Center(child:Image.network('/lib/assets/test.png',fit:BoxFit.contain));

    } else if(data.path.contains('.mp4')) {
      if(_controller==null || _controller!.value.isInitialized==false){
        return Container();
      } else {
        double _previewAngle=0;
        if(_videoInfo!=null && Platform.isAndroid){
          if(_videoInfo!.orientation==180){
            _previewAngle=pi;
          }
        }

        return Stack(children: <Widget>[
          Center(
            child: Transform.rotate(
            angle: _previewAngle,
              child:AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ))),

          Center(
            child:CircleAvatar(
            backgroundColor: Colors.black54,
            radius: 40.0,
            child: IconButton(
              icon:Icon(_controller!.value.isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 42.0,
              onPressed:(){
                print('-- onPressed');
                _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                if(_ref!=null)
                  _ref!.read(previewScreenProvider).notifyListeners();
              }
            ),
          )),
        ]);
      }

    } else if(data.path.contains('.jpg')){
      if(_img!=null)
        return Container();
      else
        return Center(child:_img);

    } else {
      return Center(child:Image.network('/lib/assets/test.png',fit:BoxFit.contain));

    }
  }

  Widget getInfoText(){
    if(data.path.contains('.mp4')) {
      if(_videoInfo==null){
        return Container();
      } else {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          width:180, height:100,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              getText(DateFormat("yyyy/MM/dd HH:mm:ss").format(data.date)),
              getText('${_videoInfo!.width}x${_videoInfo!.height}'),
              getText('${(_videoInfo!.duration!/1000).toInt()} sec'),
              getText('${(data.byte/1024).toInt()} kb'),
              getText('rotate ${(_videoInfo!.orientation!).toInt()}'),
           ])
        );
      }
    } else if(data.path.contains('.jpg')) {
      if(_img==null){
        return Container();
      } else {
        return Row(mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text('${_img!.width}x${_img!.height}'),
            SizedBox(width: 8),
            Text('sz=${data.byte/1024} KB'),
            SizedBox(width: 8),
            Text('date=' + DateFormat("yyyy-MM-dd HH:mm:ss").format(data.date)),
          ]
        );
      }

    } else {
      return Container();
    }
  }

  Widget getText(String txt){
    return Align(alignment:Alignment.centerLeft,
      child:Text(txt),
    );
  }
}