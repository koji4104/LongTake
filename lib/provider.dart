import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'model.dart';
import 'settings_screen.dart';

final redrawProvider = ChangeNotifierProvider((ref) => redrawNotifier(ref));
class redrawNotifier extends ChangeNotifier {
  redrawNotifier(ref){}
}

final selectedListProvider = ChangeNotifierProvider((ref) => selectedListNotifier(ref));
class selectedListNotifier extends ChangeNotifier {
  List<SaveData> list = [];
  selectedListNotifier(ref){}

  select(SaveData data) {
    if(list.contains(data)) {
      list.remove(data);
    } else {
      list.add(data);
    }
    this.notifyListeners();
  }

  bool contains(SaveData data) {
    return list.contains(data);
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

final pastProvider = StateProvider<String>((ref) {
  return '';
});

final isScreenSaverProvider = StateProvider<bool>((ref) {
  return false;
});

final isRecordingProvider = StateProvider<bool>((ref) {
  return false;
});