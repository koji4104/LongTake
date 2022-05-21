import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'dart:io';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:photo_gallery/photo_gallery.dart';
import 'package:path/path.dart';

class MyFile{
  String path = '';
  String name = '';
  DateTime date = DateTime(2000,1,1);
  int byte = 0;
  String thumb = '';
  bool isGallery = false;
}

class MyStorage {
  List<MyFile> files = [];
  List<MyFile> galleryFiles = [];
  int appdataTotalBytes = 0;
  int galleryTotalBytes = 0;

  // アプリ内データのファイルリスト
  Future getAppdata() async {
    files.clear();
    final Directory appdir = await getApplicationDocumentsDirectory();
    final photodir = Directory('${appdir.path}/photo');
    await Directory('${appdir.path}/photo').create(recursive: true);
    List<FileSystemEntity> _files = photodir.listSync(recursive:true, followLinks:false);
    _files.sort((a,b) { return b.path.compareTo(a.path); });

    for (FileSystemEntity e in _files) {
      if (e.path.contains('.mp4') == false &&
          e.path.contains('.jpg') == false)
        continue;
      MyFile f = new MyFile();
      f.path = e.path;
      f.date = e.statSync().modified;
      f.name = basename(f.path);
      f.byte = await File(f.path).length();

      if(f.path.contains('.mp4')) {
        f.thumb = '${appdir.path}/thumb/' + basenameWithoutExtension(f.path) + ".jpg";
      } else if(f.path.contains('.jpg')) {
        f.thumb = f.path;
      }

      for (MyFile gf in galleryFiles) {
        if(gf.name == f.name) {
          f.isGallery = true;
          print('-- [${gf.name}][${f.name}]');
        }
      }

      files.add(f);
    }

    appdataTotalBytes = 0;
    for (MyFile f in files) {
      appdataTotalBytes += f.byte;
    }
  }

  // フォトライブラリのファイルリスト
  Future getGallery() async {
    galleryFiles.clear();
    List<Album> videos = await PhotoGallery.listAlbums(mediumType: MediumType.video);
    for(Album album in videos) {
      //if(album.name=='LongTake') {
        MediaPage page = await album.listMedia();
        for (Medium media in page.items) {
          File f = await media.getFile();
          MyFile data = new MyFile();
          data.path = f.path;
          data.name = basename(f.path);
          data.byte = await f.length();
          galleryFiles.add(data);
          print('-- video.name=${data.name} ${album.name}');
        }
      //}
    }
    List<Album> images = await PhotoGallery.listAlbums(mediumType: MediumType.image);
    for(Album album in images) {
      if(album.name=='LongTake') {
        MediaPage page = await album.listMedia();
        for (Medium media in page.items) {
          File f = await media.getFile();
          MyFile data = new MyFile();
          data.path = f.path;
          data.name = basename(f.path);
          data.byte = await f.length();
          galleryFiles.add(data);
          print('-- image.name=${data.name} ${album.name}');
        }
      }
    }
    galleryTotalBytes = 0;
    for (MyFile f in galleryFiles) {
      galleryTotalBytes += f.byte;
    }
  }
}

class MyUI {
  static final double mobileWidth = 700.0;
  static final double desktopWidth = 1100.0;

  static bool isMobile(BuildContext context) {
    return getWidth(context) < mobileWidth;
  }

  static bool isTablet(BuildContext context) {
    return getWidth(context) < desktopWidth &&
        getWidth(context) >= mobileWidth;
  }

  static bool isDesktop(BuildContext context) {
    return getWidth(context) >= desktopWidth;
  }

  static double getWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
}

class MyEdge {
  /// ホームバーの幅（アンドロイド）
  EdgeInsetsGeometry homebarEdge = EdgeInsets.all(0.0);

  /// 設定画面で左側の余白
  EdgeInsetsGeometry settingsEdge = EdgeInsets.all(0.0);

  MyEdge({ProviderBase? provider}) {
    if(provider!=null) this._provider = provider;
  }

  static double homebarWidth = 40.0; // ホームバーの幅
  static double margin = 10.0; // 基本マージン
  static double leftMargin = 200.0; // タブレット時の左マージン

  ProviderBase? _provider;
  double _width = 0;

  /// Edgeを取得
  /// 各スクリーンのbuild()内で呼び出す
  void getEdge(BuildContext context, WidgetRef ref) async {
    if (_width == MediaQuery.of(context).size.width)
      return;
    _width = MediaQuery.of(context).size.width;
    print('-- getEdge() width=${_width.toInt()}');

    if (Platform.isAndroid) {
      NativeDeviceOrientation ori = await NativeDeviceOrientationCommunicator()
          .orientation();
      switch (ori) {
        case NativeDeviceOrientation.landscapeRight:
          homebarEdge = EdgeInsets.only(left: homebarWidth);
          print('-- landscapeRight');
          break;
        case NativeDeviceOrientation.landscapeLeft:
          homebarEdge = EdgeInsets.only(right: homebarWidth);
          break;
        case NativeDeviceOrientation.portraitDown:
        case NativeDeviceOrientation.portraitUp:
          homebarEdge = EdgeInsets.only(bottom: homebarWidth);
          break;
        default:
          break;
      }
    }

    EdgeInsetsGeometry leftEdge = EdgeInsets.all(0.0);
    if (MediaQuery.of(context).size.width > 700) {
      leftEdge = EdgeInsets.only(left: leftMargin);
    }
    this.settingsEdge = EdgeInsets.all(margin);
    this.settingsEdge = this.settingsEdge.add(leftEdge);
    this.settingsEdge = this.settingsEdge.add(homebarEdge);

    if(_provider!=null)
      ref.read(_provider!).notifyListeners();
  }
}
