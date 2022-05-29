import 'package:flutter/material.dart';

class SampleLocalizationsDelegate extends LocalizationsDelegate<Localized> {
  const SampleLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => ['en','ja'].contains(locale.languageCode);
  @override
  Future<Localized> load(Locale locale) async => Localized(locale);
  @override
  bool shouldReload(SampleLocalizationsDelegate old) => false;
}

class Localized {
  Localized(this.locale);
  final Locale locale;

  static Localized of(BuildContext context) {
    return Localizations.of (context, Localized)!;
  }

  static Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'settings_title': 'Settings',
      'photolist_title': 'In-app data',
      'recording_mode': 'mode',
      'recording_mode_desc':'Video is recording. Photo is photo shooting.',
      'mode_video': 'Video',
      'mode_image': 'Photo',
      'video_interval_sec': 'Video split min',
      'video_interval_sec_desc': 'Divide the video file to be recorded by time.',
      'image_interval_sec': 'Photo interval min',
      'image_interval_sec_desc': 'Shoot at intervals.',
      'ex_storage':'External storage',
      'ex_save_mb':'External storage max size',
      'save_mb': 'In-App max size',
      'save_mb_desc': 'If the save size is exceeded, the oldest one will be deleted.',
      'autostop_sec': 'Automatic stop (Hour)',
      'autostop_sec_desc': 'Recording (shooting) is automatically stopped. The black screen is maintained even if it is stopped.',
      'camera_height': 'camera size',
      'camera_height_desc': 'Select camera size.',
      'precautions':'precautions\nStop when the app goes to the background. Requires 5GB free space. Requires 10% battery.',
    },
    'ja': {
      'settings_title': '設定',
      'photolist_title': 'アプリ内データ',
      'recording_mode': '形式',
      'recording_mode_desc':'保存する形式を選んでください。',
      'mode_video': 'ビデオ',
      'mode_image': '写真',
      'video_interval_sec': 'ビデオ分割（分）',
      'video_interval_sec_desc': '録画ファイルを分割します。',
      'image_interval_sec': '写真撮影間隔（分）',
      'image_interval_sec_desc': '写真の撮影間隔を選んでください。',
      'ex_storage':'外部ストレージ',
      'ex_save_mb':'外部ストレージ上限サイズ',
      'save_mb': 'アプリ内データ上限サイズ',
      'save_mb_desc': 'アプリ内データが上限サイズを超えると古いものから削除します。削除したくないファイルはフォトライブラリに移動してください。',
      'autostop_sec': '自動停止（時間）',
      'autostop_sec_desc': '自動的に録画（撮影）を停止します。停止しても黒画面を維持します。バッテリー残量10%以下で自動停止します。',
      'autostop_sec': '自動停止（時間）',
      'autostop_sec_desc': '自動的に録画（撮影）を停止します。停止しても黒画面を維持します。バッテリー残量10%以下で自動停止します。',
      'camera_height': 'カメラサイズ',
      'camera_height_desc': 'カメラサイズを選んでください。',
      'precautions':'注意事項\nアプリがバックグラウンドになると停止します。本体空き容量5GB以上必要です。バッテリー残量10%以上必要です。',
    },
  };

  String text(String text) {
    String? s;
    try {
      if (locale.languageCode == "ja")
        s = _localizedValues["ja"]?[text];
      else
        s = _localizedValues["en"]?[text];
    } on Exception catch (e) {}
    return s!=null ? s : text;
  }
}

