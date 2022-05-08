import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'dart:io';
import 'package:hooks_riverpod/hooks_riverpod.dart';
class MyUI {
  MyUI() {}

  static final double mobileWidth = 700.0;
  static final double desktopWidth = 1100.0;

  static bool isMobile(BuildContext context) {
    return MediaQuery
        .of(context)
        .size
        .width < mobileWidth;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery
        .of(context)
        .size
        .width < desktopWidth &&
        MediaQuery
            .of(context)
            .size
            .width >= mobileWidth;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery
        .of(context)
        .size
        .width >= desktopWidth;
  }

  static Size getSize(BuildContext context) {
    return MediaQuery
        .of(context)
        .size;
  }
}

class MyEdge {
  /// ホームバーの幅
  static double homebarWidth = 40.0;

  /// 基本的なマージン
  static double margin = 10.0;

  /// タブレット時の左マージン
  static double leftMargin = 200.0;

  /// ホームバーの幅（アンドロイド）
  EdgeInsetsGeometry homebarEdge = EdgeInsets.all(0.0);

  /// 設定画面で左側の余白
  EdgeInsetsGeometry settingsEdge = EdgeInsets.all(0.0);

  MyEdge({ProviderBase? provider}) {
    if(provider!=null) this._provider = provider;
  }

  ProviderBase? _provider;
  NativeDeviceOrientation? _lastOri;

  /// スクリーンのbuild()内で呼び出す
  void getEdge(BuildContext context, WidgetRef ref) async {
    NativeDeviceOrientation ori = await NativeDeviceOrientationCommunicator()
        .orientation();
    if(_lastOri!=null && _lastOri==ori)
      return;
    _lastOri = ori;

    if (Platform.isAndroid) {
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
