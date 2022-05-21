/*
  CameraController? _controller;

  void init() async {
    final cameras = await availableCameras();
    if (cameras.length > 0){
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        imageFormatGroup:ImageFormatGroup.bgra8888);
      _controller!.initialize();
    }
  }

  Future<void> test() async {
    imglib.Image? img = await CameraAdapter.getImage(_controller);
  }
*/

import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;
import 'dart:async';

class CameraAdapter {

  static Future<imglib.Image?> getImage(CameraController? controller) async {
    imglib.Image? img;
    if(controller==null) {
      return null;
    }

    if(controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }

    bool b = true;
    if(controller.value.isStreamingImages == false) {
      controller.startImageStream((CameraImage image) async {
        if(b) {
          b = false;
          img = await _toImage(controller, image);
        }
      });
    }

    for (var i = 0; i < 200; i++) {
      await Future.delayed(Duration(milliseconds: 100));
      if (img != null)
        break;
    }
    controller.stopImageStream();
    return img;
  }

  static Future<imglib.Image?> _toImage(CameraController? controller, CameraImage? cameraImage) async {
    imglib.Image? img;
    if(controller==null || cameraImage==null) {
      return null;
    }
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      img = await _fromYuv(cameraImage);
      if(img!=null){
        int angle = controller.description.sensorOrientation;
        if(angle>0)
          img = imglib.copyRotate(img, angle);
      }
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      img = _fromRgb(cameraImage);
    }
    return img;
  }

  static Future<imglib.Image?> _fromYuv(CameraImage? image) async {
    if(image==null)
      return null;
    final int width = image.width;
    final int height = image.height;

    if(image.planes.length<3) {
      print('err convertYuv() planes.length=${image.planes.length}');
      return null;
    } else if(image.planes[1].bytesPerPixel==null) {
      print('err convertYuv() planes[1].bytesPerPixel=null');
      return null;
    } else if(image.planes[0].bytes.length<width*height) {
      print('err convertYuv() planes[0].bytes.length=${image.planes[0].bytes.length}');
      return null;
    }

    try {
      imglib.Image img = imglib.Image(width, height);
      final int perRow = image.planes[1].bytesPerRow;
      final int perPixel = image.planes[1].bytesPerPixel!;

      // YUV -> RGB
      for(int ay=0; ay < height; ay++) {
        for(int ax=0; ax < width; ax++) {
          final int index = ax + (ay * width);
          final int uvIndex = perPixel * (ax / 2).floor() + perRow * (ay / 2).floor();
          final y = image.planes[0].bytes[index];
          final u = image.planes[1].bytes[uvIndex];
          final v = image.planes[2].bytes[uvIndex];
          int r = (y + v * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round().clamp(0, 255);
          int b = (y + u * 1814 / 1024 - 227).round().clamp(0, 255);
          img.data[index] = (0xFF << 24) | (b << 16) | (g << 8) | r;
        }
      }
      return img;
    } catch (e) {
      print("err convertYuv() " + e.toString());
    }
    return null;
  }

  static imglib.Image _fromRgb(CameraImage image) {
    return imglib.Image.fromBytes(
      image.width, image.height,
      image.planes[0].bytes,
      format:imglib.Format.bgra,
    );
  }
}