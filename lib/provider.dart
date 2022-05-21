import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'model.dart';
import 'common.dart';

final selectedListProvider = ChangeNotifierProvider((ref) => selectedListNotifier(ref));
class selectedListNotifier extends ChangeNotifier {
  List<MyFile> list = [];
  selectedListNotifier(ref){}

  select(MyFile f) {
    if(list.contains(f)) {
      list.remove(f);
    } else {
      list.add(f);
    }
    this.notifyListeners();
  }

  bool contains(MyFile f) {
    return list.contains(f);
  }

  clear() {
    list.clear();
    this.notifyListeners();
  }
}

final photoListProvider = ChangeNotifierProvider((ref) => photoListNotifier(ref));
class photoListNotifier extends ChangeNotifier {
  photoListNotifier(ref){}
  int num = 0;
  int size = 0;
}

final isScreenSaverProvider = StateProvider<bool>((ref) {
  return false;
});

final isRecordingProvider = StateProvider<bool>((ref) {
  return false;
});

final startTimeProvider = StateProvider<DateTime?>((ref) {
  return null;
});

