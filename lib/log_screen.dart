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
2022-04-06 00:00:00\tuser\terr\tapp\tmessage1
2022-04-02 00:00:00\tuser\twarn\tapp\tmessage2
2022-04-03 00:00:00\tuser\tinfo\tapp\tmessage3
2022-04-06 00:20:20\tuser\tinfo\tapp\tmessage4
2022-04-05 00:00:00\tuser\tinfo\tapp\tmessage5
2022-04-01 00:00:20\tuser\terr\tapp\tmessage1
2022-04-02 00:20:00\tuser\twarn\tapp\tmessage2
2022-04-06 00:00:20\tuser\tinfo\tapp\tmessage3
2022-04-04 00:00:00\tuser\tinfo\tapp\tmessage4
2022-04-05 00:20:00\tuser\tinfo\tapp\tmessage5
2022-04-01 00:00:00\tuser\terr\tapp\tmessage1
2022-04-02 00:00:20\tuser\twarn\tapp\tmessage2
2022-04-06 00:20:00\tuser\tinfo\tapp\tmessage3
2022-04-04 00:00:00\tuser\tinfo\tapp\tmessage4
2022-04-05 00:00:20\tuser\terr\tapp\tmessage5
2022-04-01 00:00:00\tuser\terr\tapp\tmessage1
2022-04-06 00:10:00\tuser\twarn\tapp\tstart
2022-04-03 00:00:00\tuser\tinfo\tapp\tmessage3
2022-04-04 00:00:00\tuser\tinfo\tapp\tstart
2022-04-05 00:00:00\tuser\tinfo\tapp\tmessage5
2022-04-07 00:10:00\tuser\terr\tapp\tmessage1
2022-04-02 00:00:00\tuser\twarn\tapp\tmessage2
2022-04-03 00:00:00\tuser\tinfo\tapp\tmessage3
2022-04-06 00:10:00\tuser\tinfo\tapp\tstart
2022-04-05 00:00:00\tuser\tinfo\tapp\tstart
''';

final logListProvider = StateProvider<List<MyLogData>>((ref) {
  return [];
});

class MyLog {
  static String _fname = "app.log";
  
  static info(String msg) async {
    await MyLog.write('info', 'app', msg);
  }
  static warn(String msg) async {
    await MyLog.write('warn', 'app', msg);
  }
  static err(String msg) async {
    await MyLog.write('err', 'app', msg);
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
    
    // length byte 100kb
    if(await File(path).exists() && File(path).lengthSync()>100*1024) {
      if(await File(path+'.1').exists())
        File(path+'.1').deleteSync();
      File(path).renameSync(path+'.1');
      File(path).deleteSync();
    }    
    String tsv = '$t\t$u\t$l\t$e\t$msg\n';
    await File(path).writeAsString(tsv, mode:FileMode.append, flush:true);
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
      print('-- MyLog read() Exception ' + e.toString());
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
        backgroundColor:Color(0xFF000000),
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
    for(MyLogData d in list) {
      String stime = DateFormat("yyyy/MM/dd HH:mm").format(DateTime.parse(d.time));
      Wrap w = Wrap(children:[getText(stime),getText(d.msg)]);
      spans.add(TextSpan(text:stime));

      if (d.level.contains('err'))
        spans.add(TextSpan(text: ' '+d.level, style: TextStyle(color:Color(0xFFFF8888))));
      else if (d.level.contains('warn'))
        spans.add(TextSpan(text: ' '+d.level, style: TextStyle(color:Color(0xFFeeee44))));

      spans.add(TextSpan(text:' '+d.msg+'\n'));
    }

    double leftPdd = 8;
    double rightPdd = 8;
    double w = MediaQuery.of(context).size.width;
    if(w>700) {
      leftPdd = 200;
      rightPdd = 12;
    }

    return Container(
      width: MediaQuery.of(context).size.width-leftPdd-20,
      height: MediaQuery.of(context).size.height-120,
        decoration: BoxDecoration(
          color: Color(0xFF333333),
          borderRadius: BorderRadius.circular(4),
        ),
      margin: EdgeInsets.fromLTRB(leftPdd,8,rightPdd,8),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
          padding: EdgeInsets.fromLTRB(8,8,8,8),
        child: SelectableText.rich(
          TextSpan(
            style: TextStyle(fontSize:14, fontFamily:'monospace'),
            children: spans
          )
        )
      )
    );
  }

  Widget getText(String s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical:1, horizontal:4),
      child: Text(s, style:TextStyle(fontSize:14, color:Colors.white)),
    );
  } 
}

