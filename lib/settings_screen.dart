import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'localizations.dart';
import 'log_screen.dart';

class EnvData {
  int val;
  String key = '';
  List<int> vals;
  List<String> keys;
  String name;
  String desc;

  EnvData({
    required int this.val,
    required List<int> this.vals,
    required List<String> this.keys,
    required String this.name,
    required String this.desc}){
    set(val);
  }

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
  /// 1=video, 2=image
  EnvData recording_mode = EnvData(
    val:1,
    vals:[1,2],
    keys:['mode_video','mode_image'],
    name:'recording_mode',
    desc:'recording_mode_desc',
  );

  EnvData video_interval_sec = EnvData(
    val:3600,
    vals:[1800,3600,7200],
    keys:['1800','3600','7200'],
    name:'video_interval_sec',
    desc:'video_interval_sec_desc',
  );
  EnvData image_interval_sec = EnvData(
    val:60,
    vals:[60,300,600],
    keys:['60','300','600'],
    name:'image_interval_sec',
    desc:'image_interval_sec_desc',
  );
  EnvData max_size_gb = EnvData(
    val:10,
    vals:[1,10,100],
    keys:['1','10','100'],
    name:'max_size_gb',
    desc:'max_size_gb_desc',
  );
  EnvData autostop_sec = EnvData(
    val:3600,
    vals:[0,3600,21600,43200],
    keys:['0','3600','21600','43200'],
    name:'autostop_sec',
    desc:'autostop_sec_desc',
  );
  EnvData camera_height = EnvData(
    val:480,
    vals:[240,480,720,1080],
    keys:['240','480','720','1080'],
    name:'camera_height',
    desc:'camera_height_desc',
  );

  load() async {
    if(kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      recording_mode.set(prefs.getInt('recording_mode') ?? 1);
      video_interval_sec.set(prefs.getInt('video_interval_sec') ?? 3600);
      image_interval_sec.set(prefs.getInt('image_interval_sec') ?? 60);
      max_size_gb.set(prefs.getInt('max_size_gb') ?? 10);
      autostop_sec.set(prefs.getInt('autostop_sec') ?? 3600);
      camera_height.set(prefs.getInt('camera_height') ?? 480);
    } on Exception catch (e) {
      print('-- e=' + e.toString());
    }
  }

  save() async {
    if(kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('recording_mode', recording_mode.val);
    await prefs.setInt('video_interval_sec', video_interval_sec.val);
    await prefs.setInt('image_interval_sec', image_interval_sec.val);
    await prefs.setInt('max_size_gb', max_size_gb.val);
    await prefs.setInt('autostop_sec', autostop_sec.val);
    await prefs.setInt('camera_height', camera_height.val);
  }
}

final SettingsScreenProvider = ChangeNotifierProvider((ref) => SettingsScreenNotifier(ref));
class SettingsScreenNotifier extends ChangeNotifier {
  SettingsScreenNotifier(ref){}
}

class SettingsScreen extends ConsumerWidget {
  SettingsScreen(){}
  Environment env = new Environment();

  Future<bool> load() async {
    try {
      await env.load();
    } on Exception catch (e) {
      print('-- e=' + e.toString());
    }
    return true;
  }

  BuildContext? _context;
  WidgetRef? _ref;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _context = context;
    _ref = ref;
    ref.watch(SettingsScreenProvider);

    return WillPopScope(
      onWillPop: () async {
        await env.save();
        Navigator.of(context).pop(true);
        return Future.value(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n("settings_title")),
          actions: <Widget>[],
        ),
        body:FutureBuilder(
          future: load(),
          builder: (context, snapshot) {
          if(snapshot.hasData == false)
            return SingleChildScrollView();

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              MyValue(data: env.recording_mode),
              MyValue(data: env.video_interval_sec),
              MyValue(data: env.image_interval_sec),
              MyValue(data: env.max_size_gb),
              MyValue(data: env.autostop_sec),
              MyValue(data: env.camera_height),
              MyText(Localized.of(context).text("precautions")),
              
              Container(
                margin: const EdgeInsets.symmetric(vertical:4, horizontal:12),
                padding: const EdgeInsets.only(left:4, right:6, top:2, bottom:2),
                child: Row(children: [
                  Text('Log'),
                  Expanded(child: SizedBox(width:1)),
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios, color:Colors.white),
                    iconSize: 14.0,
                    onPressed:(){
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => LogScreen(),
                        ));
                    }
                  ),
              ])),
            ]));
        })
      )
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

  Widget MyValue({required EnvData data}) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF333333),
        borderRadius: BorderRadius.circular(3),
      ),
      margin: const EdgeInsets.symmetric(vertical:3, horizontal:10),
      padding: const EdgeInsets.only(left:8, right:10, top:2, bottom:2),
      child: Row(children: [
        Text(l10n(data.name)),
        Expanded(child: SizedBox(width:1)),
        Text(l10n(data.key)),
        SizedBox(width:4),
        IconButton(
          icon: Icon(Icons.arrow_forward_ios, color:Colors.white),
          iconSize: 14.0,
          onPressed:(){
            Navigator.of(_context!).push(
              MaterialPageRoute<int>(
                builder: (BuildContext context) {
                  return RadioListScreen(data:data);
                })).then((ret){
                  data.set(ret);
                  _ref!.read(SettingsScreenProvider).notifyListeners();
            });
          },
        ),
      ]));
  }

  String l10n(String text){
    return Localized.of(_context!).text(text);
  }
}

final RadioListScreenProvider = StateProvider<int>((ref) {
  return 0;
});
class RadioListScreen extends ConsumerWidget {
  int selected = 0;
  EnvData data;
  WidgetRef? ref;
  BuildContext? context;

  RadioListScreen({required EnvData this.data}){
    selected = data.val;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(RadioListScreenProvider);
    this.context = context;
    this.ref = ref;

    return WillPopScope(
      onWillPop:() async {
        Navigator.of(context).pop(selected);
        return Future.value(true);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n(data.name))),
        body: Container(
          margin:EdgeInsets.only(top:12, left:4, right:4),
          child:getListView()
        ),
      )
    );
  }

  Widget getListView() {
    List<Widget> list = [];
    for(int i=0; i<data.vals.length; i++){
      list.add(RadioListTile(
        tileColor: Color(0xFF333333),
        activeColor: Color(0xFFFF4444),
        title: Text(l10n(data.keys[i])),
        value: data.vals[i],
        groupValue: selected,
        onChanged: (value) => _onRadioSelected(data.vals[i]),
      ));
    }
    list.add(MyText(data.desc));
    return Column(children:list);
  }

  _onRadioSelected(value) {
    if(ref!=null){
      selected = value;
      ref!.read(RadioListScreenProvider.state).state = selected;
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
      padding: EdgeInsets.symmetric(horizontal:8, vertical:6),
      child: Align(
      alignment: Alignment.centerLeft,
      child: Text(l10n(label), style:TextStyle(fontSize:12, color:Colors.white)),
    ));
  }
}
