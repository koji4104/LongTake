import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'localizations.dart';
import 'log_screen.dart';
import 'common.dart';

class EnvData {
  int val;
  String key = '';
  List<int> vals = [];
  List<String> keys = [];
  String name = '';

  EnvData({
    required int this.val,
    required List<int> this.vals,
    required List<String> this.keys,
    required String this.name}){
    set(val);
  }

  // 選択肢と同じものがなければひとつ大きいいものになる
  set(int? newval) {
    if (newval==null)
      return;
    if (vals.length > 0) {
      val = vals[0];
      for (var i=0; i<vals.length; i++) {
        if (newval <= vals[i]) {
          val = vals[i];
          if(keys.length>=i)
            key = keys[i];
          break;
        }
      }
    }
  }
}

/// Environment
class Environment {
  /// 形式 1=video, 2=image, 3=audio
  EnvData recording_mode = EnvData(
    val:1,
    vals:[1,2],
    keys:['mode_video','mode_image'],
    name:'recording_mode',
  );
  /// ビデオ分割
  EnvData video_interval_sec = EnvData(
    val:3600,
    vals:[30,1800,3600,7200],
    keys:['30 sec','30','60','120'],
    name:'video_interval_sec',
  );
  /// 写真撮影間隔
  EnvData image_interval_sec = EnvData(
    val:60,
    vals:[10,60,300,600],
    keys:['10 sec','1','5','10'],
    name:'image_interval_sec',
  );
  EnvData autostop_sec = EnvData(
    val:3600,
    vals:[60,3600,21600,43200,86400],
    keys:['60 sec','1','6','12','24'],
    name:'autostop_sec',
  );

  EnvData save_mb = EnvData(
    val:256,
    vals:[128,256,512,1024,2048,4096,8192,16384],
    keys:['128 MB','256 MB','512 MB','1 GB','2 GB','4 GB','8 GB','16 GB'],
    name:'save_mb',
  );
  EnvData ex_save_mb = EnvData(
    val:256,
    vals:[128,256,512,1024,2048,4096,8192,16384],
    keys:['128 MB','256 MB','512 MB','1 GB','2 GB','4 GB','8 GB','16 GB'],
    name:'ex_save_mb',
  );
  /// 外部ストレージ 0=None 1=PhotoLibrary
  EnvData ex_storage = EnvData(
    val:0,
    vals:[0,1],
    keys:['None','PhotoLibrary'],
    name:'ex_storage',
  );
  EnvData camera_height = EnvData(
    val:480,
    vals:[240,480,720,1080],
    keys:['320X240','640x480','1280x720','1920x1080'],
    name:'camera_height',
  );
  // 0=back, 1=Front(Face)
  EnvData camera_pos = EnvData(
    val:0,
    vals:[0,1],
    keys:['back','front'],
    name:'camera_pos',
  );

  Future load() async {
    if(kIsWeb)
      return;
    print('-- load()');
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _loadSub(prefs, recording_mode);
      _loadSub(prefs, video_interval_sec);
      _loadSub(prefs, image_interval_sec);
      _loadSub(prefs, save_mb);
      _loadSub(prefs, ex_storage);
      _loadSub(prefs, ex_save_mb);
      _loadSub(prefs, autostop_sec);
      _loadSub(prefs, camera_height);
      _loadSub(prefs, camera_pos);
    } on Exception catch (e) {
      print('-- load() e=' + e.toString());
    }
  }
  _loadSub(SharedPreferences prefs, EnvData data) {
    data.set(prefs.getInt(data.name) ?? data.val);

  }

  Future save(EnvData data) async {
    if(kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(data.name, data.val);
  }
}

final settingsScreenProvider = ChangeNotifierProvider((ref) => ChangeNotifier());

class SettingsScreen extends ConsumerWidget {
  SettingsScreen(){}
  Environment env = new Environment();
  bool bInit = false;

  Future init() async {
    if(bInit) return;
      bInit = true;
    try {
      await env.load();
      _ref!.read(settingsScreenProvider).notifyListeners();
    } on Exception catch (e) {
      print('-- SettingsScreen init e=' + e.toString());
    }
    return true;
  }

  BuildContext? _context;
  WidgetRef? _ref;
  MyEdge _edge = MyEdge(provider:settingsScreenProvider);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _context = context;
    _ref = ref;
    Future.delayed(Duration.zero, () => init());
    ref.watch(settingsScreenProvider);

    _edge.getEdge(context,ref);
    print('-- build');
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(true);
        return Future.value(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n("settings_title")),
          backgroundColor:Color(0xFF000000),
          actions: <Widget>[],
        ),
        body: Container(
          margin: _edge.settingsEdge,
          child: Stack(children: <Widget>[
            getList(context),
          ])
        )
      )
    );
  }

  Widget getList(BuildContext context) {
    int m=env.recording_mode.val; // 1=video 2=image
    int e=env.ex_storage.val; // 0=none 1=library
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(8,8,8,8),
      child: Column(children: [
        MyValue(data: env.recording_mode),
        m==1 ? MyValue(data: env.video_interval_sec) : MyValue(data: env.image_interval_sec),
        MyValue(data: env.save_mb),
        MyValue(data: env.ex_storage),
        if(e==1) MyValue(data: env.ex_save_mb),
        MyValue(data: env.autostop_sec),
        MyValue(data: env.camera_height),
        MyText(Localized.of(context).text("precautions")),
        MyListTile(
          title:Text('Logs'),
          onTap:(){
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LogScreen(),
              )
            );
          }
        ),
      ])
    );
  }

  Widget MyText(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical:10, horizontal:20),
        child: Text(label, style:TextStyle(fontSize:12, color:Colors.white)),
      )
    );
  }

  Widget MyListTile({required Widget title, required Function() onTap}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal:14, vertical:3),
      child: ListTile(
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
        title: title,
        trailing: Icon(Icons.arrow_forward_ios),
        tileColor: Color(0xFF333333),
        hoverColor: Color(0xFF444444),
        onTap: onTap
      ),
    );
  }

  Widget MyValue({required EnvData data}) {
    TextStyle ts = TextStyle(fontSize:16, color:Colors.white);
    return MyListTile(
      title:Row(children:[
        Text(l10n(data.name), style:ts),
        Expanded(child: SizedBox(width:1)),
        Text(l10n(data.key), style:ts),
      ]),
      onTap:() {
        Navigator.of(_context!).push(
          MaterialPageRoute<int>(
            builder: (BuildContext context) {
              return RadioListScreen(data: data);
          })).then((ret) {
            if (data.val != ret) {
              data.set(ret);
              env.save(data);
              _ref!.read(settingsScreenProvider).notifyListeners();
            }
          }
        );
      }
    );
  }

  String l10n(String text){
    return Localized.of(_context!).text(text);
  }
}

final radioSelectedProvider = StateProvider<int>((ref) {
  return 0;
});
final radioListScreenProvider = ChangeNotifierProvider((ref) => ChangeNotifier());
class RadioListScreen extends ConsumerWidget {
  int selected = 0;
  EnvData data;
  WidgetRef? ref;
  BuildContext? context;
  MyEdge _edge = MyEdge(provider:radioListScreenProvider);

  RadioListScreen({required EnvData this.data}){
    selected = data.val;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(radioSelectedProvider);
    ref.watch(radioListScreenProvider);
    this.context = context;
    this.ref = ref;
    _edge.getEdge(context,ref);

    return WillPopScope(
      onWillPop:() async {
        Navigator.of(context).pop(selected);
        return Future.value(true);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n(data.name)), backgroundColor:Color(0xFF000000),),
        body: Container(
          margin: _edge.settingsEdge,
          child:getListView()
        ),
      )
    );
  }

  Widget getListView() {
    List<Widget> list = [];
    for(int i=0; i<data.vals.length; i++){
      list.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal:14, vertical:0),
          child: RadioListTile(
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(3),
          ),
          tileColor: Color(0xFF333333),
          activeColor: Color(0xFFFF4444),
          title: Text(l10n(data.keys[i])),
          value: data.vals[i],
          groupValue: selected,
          onChanged: (value) => _onRadioSelected(data.vals[i]),
      )));
    }
    list.add(MyText(data.name+'_desc')); // 説明
    return Column(children:list);
  }

  _onRadioSelected(value) {
    if(ref!=null){
      selected = value;
      ref!.read(radioSelectedProvider.state).state = selected;
    };
  }

  String l10n(String text) {
    if(this.context!=null)
      return Localized.of(this.context!).text(text);
    else
      return text;
  }

  Widget MyText(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal:10, vertical:6),
      child: Align(
      alignment: Alignment.centerLeft,
      child: Text(l10n(label), style:TextStyle(fontSize:13, color:Colors.white)),
    ));
  }
}
