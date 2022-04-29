import 'dart:core';

class PhotoData{
  String path = '';
  String name = '';
  DateTime date = DateTime(2000,1,1);
  String thumb = '';
  int byte = 0;
  int playtime = 0; // video (sec)
  PhotoData(String path) {
    this.path = path;
  }
}

