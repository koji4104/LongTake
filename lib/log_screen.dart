import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MyLogData {
  String time='';
  String user='';
  String level='';
  String event='';
  String msg='';
  MyLogData({String? time, String? user, String? level, String? event, String? msg}) {
    this.time = time ?? '';
    this.user = user ?? '';
    this.level = level ?? '';
    this.event = event ?? '';
    this.msg = msg ?? '';
  }
  static MyLogData fromJson(Map<String,dynamic> json) {
    return MyLogData(
        time: json['time'],
        user: json['user'],
        level: json['level'],
        event: json['event'],
        msg: json['msg']
    );
  }
}

String sample = '''
2022-04-01 00:00:00\tuser\terr\tapp\tmessage1
2022-04-02 00:00:00\tuser\twarn\tapp\tmessage2
2022-04-03 00:00:00\tuser\tinfo\tapp\tmessage3
2022-04-04 00:00:00\tuser\tinfo\tapp\tmessage4
2022-04-05 00:00:00\tuser\tinfo\tapp\tmessage5
2022-04-01 00:00:00\tuser\terr\tapp\tmessage1
2022-04-02 00:00:00\tuser\twarn\tapp\tmessage2
2022-04-03 00:00:00\tuser\tinfo\tapp\tmessage3
2022-04-04 00:00:00\tuser\tinfo\tapp\tmessage4
2022-04-05 00:00:00\tuser\tinfo\tapp\tmessage5
2022-04-01 00:00:00\tuser\terr\tapp\tmessage1
2022-04-02 00:00:00\tuser\twarn\tapp\tmessage2
2022-04-03 00:00:00\tuser\tinfo\tapp\tmessage3
2022-04-04 00:00:00\tuser\tinfo\tapp\tmessage4
2022-04-05 00:00:00\tuser\tinfo\tapp\tmessage5
2022-04-01 00:00:00\tuser\terr\tapp\tmessage1
2022-04-02 00:00:00\tuser\twarn\tapp\tmessage2
2022-04-03 00:00:00\tuser\tinfo\tapp\tmessage3
2022-04-04 00:00:00\tuser\tinfo\tapp\tmessage4
2022-04-05 00:00:00\tuser\tinfo\tapp\tmessage5
2022-04-01 00:00:00\tuser\terr\tapp\tmessage1
2022-04-02 00:00:00\tuser\twarn\tapp\tmessage2
2022-04-03 00:00:00\tuser\tinfo\tapp\tmessage3
2022-04-04 00:00:00\tuser\tinfo\tapp\tmessage4
2022-04-05 00:00:00\tuser\tinfo\tapp\tmessage5
2022-04-01 00:00:00\tuser\terr\tapp\tmessage1
2022-04-02 00:00:00\tuser\twarn\tapp\tmessage2
2022-04-03 00:00:00\tuser\tinfo\tapp\tmessage3
2022-04-04 00:00:00\tuser\tinfo\tapp\tmessage4
2022-04-05 00:00:00\tuser\tinfo\tapp\tmessage5
''';

final logListProvider = StateProvider<List<MyLogData>>((ref) {
  return [];
});

class MyLog {
  static String _fname = "app.log";
  
  static info(String msg) async {
    MyLog.write('info', 'app', msg);
  }
  static warn(String msg) async {
    MyLog.write('warn', 'app', msg);
  }
  static err(String msg) async {
    MyLog.write('err', 'app', msg);
  }
  static write(String level, String event, String msg) async {
    print('-- ${level} ${msg}');
    if(kIsWeb)
      return ;

    String t = new DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now());
    String l = level;
    String e = event;
    String u = 'user';
    
    final Directory appdir = await getApplicationDocumentsDirectory();
    await Directory('${appdir.path}/log').create(recursive: true);
    final String path = '${appdir.path}/log/$_fname';
    
    // length byte 10kb
    if(await File(path).exists() && File(path).lengthSync()>10*1024) {
      if(await File(path+'.1').exists())
        File(path+'.1').deleteSync();
      File(path).renameSync(path+'.1');
      File(path).deleteSync();
    }    
    String tsv = '$t\t$u\t$l\t$e\t$msg\n';
    File(path).writeAsStringSync(tsv, mode:FileMode.append, flush:true);
  }

  static Future<List<MyLogData>> read() async {
    List<MyLogData> list = [];
    try {
      String txt = '';
      if(kIsWeb) {
        txt = sample;
      } else {
        final Directory appdir = await getApplicationDocumentsDirectory();
        final String path = '${appdir.path}/log/$_fname';
        if (await File(path + '.1').exists()) {
          txt += await File(path + '.1').readAsString();
        }
        if (await File(path).exists()) {
          txt += await File(path).readAsString();
        }
      }

      for (String line in txt.split('\n')) {
        List r = line.split('\t');
        if(r.length>=5){
          MyLogData d = MyLogData(time:r[0],user:r[1],level:r[2],event:r[3],msg:r[4]);
          list.add(d);
        }
        list.sort((a,b) {
          return b.time.compareTo(a.time);
        });
      }
    } on Exception catch (e) {
      print('-- Exception ' + e.toString());
    }
    return list;
  }
}

class LogScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future.delayed(Duration.zero, () => readLog(ref));
    List<MyLogData> list = ref.watch(logListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Logs'),
        actions: <Widget>[],
      ),
      body: getTable(context,ref,list),
    );
  }

  void readLog(WidgetRef ref) async {
    List<MyLogData> list = await MyLog.read();
    ref.watch(logListProvider.state).state = list;
  }
  Widget getTable(BuildContext context, WidgetRef ref, List<MyLogData> list) {
    List<TextSpan> spans = [];
    for(MyLogData d in list){
      String stime = DateFormat("yyyy/MM/dd HH:mm").format(DateTime.parse(d.time));
      Wrap w = Wrap(children:[getText(stime),getText(d.msg)]);
      spans.add(TextSpan(text:stime));

      if (d.level.contains('err'))
        spans.add(TextSpan(text: ' '+d.level, style: TextStyle(color:Color(0xFFFF6666))));
      else if (d.level.contains('warn'))
        spans.add(TextSpan(text: ' '+d.level, style: TextStyle(color:Color(0xFFcccc66))));
      else
        spans.add(TextSpan(text: ' '+d.level, style: TextStyle(color:Color(0xFFDDDDDD))));

      spans.add(TextSpan(text:' '+d.msg+'\n'));
    }
    return Container(
        height: MediaQuery.of(context).size.height-120,
        color: Colors.black54,
        margin: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: SingleChildScrollView(
            //controller: _controller,
            scrollDirection: Axis.vertical,
            padding: EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: SelectableText.rich(
                TextSpan(
                    style:TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace'
                    ),
                    children: spans
                )
            )
        )
    );
  }

  Widget getTable2(BuildContext context, WidgetRef ref, List<MyLogData> list) {
  List<Wrap> rows = [];
  for(MyLogData d in list){
    String stime = DateFormat("yyyy/MM/dd HH:mm").format(DateTime.parse(d.time));
    Wrap w = Wrap(children:[getText(stime),getText(d.msg)]);
    rows.add(w);
  }
  return Container(
    padding: EdgeInsets.fromLTRB(8,8,8,8),
    
    child: SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
    )));
  }
  Widget getText(String s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
      child: Text(s, style:TextStyle(fontSize:14, color:Colors.white)),
    );
  } 
}

