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
import 'provider.dart';

class PhotoListScreen extends ConsumerWidget {
  PhotoListScreen(){}
  
  String title='Capture';
  List<SaveData> dataList = [];
  int numIndex = 20;

  bool _init = false;
  int selectedIndex = 0;
  BuildContext? context;
  WidgetRef? ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    this.context = context;
    this.ref = ref;
    int num = ref.watch(photoListProvider).num;
    int size = ref.watch(photoListProvider).size;
    int sizegb = (size/1024/1024/1024).toInt();
    //int num = 0;
    //int size = 1;
    print('-- num=${num}');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
          )
        ],
      ),
      body: Stack(children: <Widget>[
      Row(mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(width: 12),
            Icon(Icons.image, size: 12.0, color: Colors.white),
            SizedBox(width: 4),
            Text(num.toString()),
            SizedBox(width: 8),
            Icon(Icons.folder, size: 12.0, color: Colors.white),
            SizedBox(width: 4),
            Text(sizegb.toString() + ' GB'),
          ]
      ),
      Container(
        margin: EdgeInsets.only(top:20),
        child:getListView(context,ref),
        )
      ])
    );
  }

  Widget getListView(BuildContext context, WidgetRef ref) {
    readVideoData(ref);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: GridView.count(
        crossAxisCount: 3,
        children: List.generate(dataList.length, (index) {
          return MyCard(data: dataList[index]);
        })),
    );
  }

  // /data/user/0/com.example.longtake/app_flutter/video/2022-0417-170926.mp4
  Future<bool> readVideoData(WidgetRef ref) async {
    if(_init == true) {
      return true;
    }
    _init = true;
    try {
      dataList.clear();
      if (kIsWeb) {
        for (int i = 1; i < 30; i++) {
          SaveData d = new SaveData('');
          int h = (i / 10).toInt();
          int m = (i % 10).toInt();
          d.date = DateTime(2022, 1, 1, h, m, 0);
          dataList.add(d);
        }
      } else {
        final Directory appdir = await getApplicationDocumentsDirectory();
        final photodir = Directory('${appdir.path}/photo');
        await Directory('${appdir.path}/photo').create(recursive: true);
        List<FileSystemEntity> _files = photodir.listSync(recursive:true, followLinks:false);
        _files.sort((a,b) { return b.path.compareTo(a.path); });

        print('-- files=${_files.length}');

        final _thumbdir = Directory('${appdir.path}/thumb');
        await Directory('${appdir.path}/thumb').create(recursive: true);
        List<FileSystemEntity> _entities = _thumbdir.listSync(recursive:true, followLinks:false);
        List<String> _thumbs = [];
        for (FileSystemEntity e in _entities) {
          _thumbs.add(e.path);
        }

        final String thumbDir = '${appdir.path}/thumb/';
        for (FileSystemEntity file in _files) {
          print('-- file.path=${file.path}');
          SaveData d = new SaveData(file.path);

          //print('-- thumb.path=${d.thumb}');

          if(d.path.substring(d.path.length-4,d.path.length)=='.mp4') {
            d.thumb = thumbDir + basenameWithoutExtension(file.path) + ".jpg";
            if (await File(d.thumb).exists() == false) {
              String? s = await video_thumbnail.VideoThumbnail.thumbnailFile(
                video: file.path,
                thumbnailPath: d.thumb,
                imageFormat: video_thumbnail.ImageFormat.JPEG,
                maxHeight: 240,
                quality: 70);
              d.thumb = (s != null) ? s : "";
            }
            if (_thumbs.indexOf(d.thumb) >= 0)
              _thumbs.removeAt(_thumbs.indexOf(d.thumb));
          } else if(d.path.substring(d.path.length-4,d.path.length)=='.jpg'){
            d.thumb = d.path;
          }

          //d.name = DateFormat("MM/dd HH:mm").format(file.statSync().modified);
          d.date = file.statSync().modified;
          d.byte = await File(d.path).length();
          dataList.add(d);
        }

        // delete unused thumbnail
        for (String u1 in _thumbs) {
          if (await File(u1).exists()) {
            await File(u1).delete();
          }
        }
      }

      int totalBytes = 0;
      if (kIsWeb==false) {
        for (SaveData d in dataList) {
          if (await File(d.path).exists())
            totalBytes += d.byte;
        }
      }

      //ref.read(selectedListProvider).clear();
      ref.read(photoListProvider).num = dataList.length;
      ref.read(photoListProvider).size = totalBytes;
      ref.read(photoListProvider).notifyListeners();

    } on Exception catch (e) {
      print('-- e=' + e.toString());
    }
    return true;
  }

  /// Save file
  /// Move to photolibrary
  _saveFileWithDialog(BuildContext context, WidgetRef ref) async {
    List<SaveData> list = ref.read(selectedListProvider).list;
    Text msg = Text('Save to photolibrary (${list.length})');
    Text btn = Text('OK', style:TextStyle(fontSize:16, color:Colors.lightBlue));
    showDialogEx(context, msg, btn, _saveFile, list);
  }
  _saveFile(List<SaveData> list) async {
    try {
      for(SaveData data in list){
        if(data.path.contains('.jpg'))
          await GallerySaver.saveImage(data.path);
        else if(data.path.contains('.mp4'))
          await GallerySaver.saveVideo(data.path);
        await new Future.delayed(new Duration(milliseconds:100));
      }
    } on Exception catch (e) {
      print('-- _saveFile ${e.toString()}');
    }
  }

  /// delete file
  _deleteFileWithDialog(BuildContext context, WidgetRef ref) async {
    List<SaveData> list = ref.read(selectedListProvider).list;
    Text msg = Text('Delete files (${list.length})');
    Text btn = Text('Delete', style:TextStyle(fontSize:16, color:Colors.lightBlue));
    showDialogEx(context, msg, btn, _deleteFile, list);
  }
  _deleteFile(List<SaveData> list) async {
    for(SaveData data in list){
      await File(data.path).delete();
      if(await File(data.thumb).exists())
        await File(data.thumb).delete();
      await new Future.delayed(new Duration(milliseconds:100));
    };
  }

  /// Show dialog (OK or Cancel)
  Future<void> showDialogEx(
      BuildContext context,
      Text msg,
      Text buttonText,
      Function func,
      List<SaveData> list
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
      });
  }
}

class MyCard extends ConsumerWidget {
  MyCard({SaveData? data}) {
    if(data!=null) this.data = data;
  }

  SaveData data = SaveData('');
  bool _selected = false;
  double _width = 100.0;
  double _height = 100.0;

  @override
  Widget build(BuildContext context, WidgetRef ref){
    _selected = ref.watch(selectedListProvider).contains(data);

    return Container(
      width: _width, height: _height,
      margin: EdgeInsets.all(4),
      padding: EdgeInsets.all(0),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap:(){
          ref.read(selectedListProvider).select(data);
        },
        child: getWidget(ref),
      ),
    );
  }

  Widget getWidget(WidgetRef ref){
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if(kIsWeb)
          Image.network('/lib/assets/test.png',fit:BoxFit.cover)
        else
          Image.file(File(data.thumb), fit:BoxFit.cover),
        
        Container(
          child: Text(' ' + DateFormat("MM/dd HH:mm").format(data.date) + ' ',
            style: TextStyle(fontSize:14, color:Colors.white, backgroundColor:Colors.black38),
        ),),
        if(data.path.contains('.mp4'))
          Positioned(
            top: 6.0, left: 0.0,
            child: Text(' ' + (data.byte/1024/1024).toInt().toString() + ' MB',
              style: TextStyle(fontSize:14, color:Colors.white, backgroundColor:Colors.black38),
            ),),
        Positioned(
          right: 6.0, bottom: 6.0,
          child: CircleAvatar(
            backgroundColor: _selected ? Colors.black54 : Color(0x00000000),
            child: Icon(_selected ? Icons.check : null,
            size: 36,
            color: Color(0xFFFF0000)
        ))),
      ]
    );
  }
}
