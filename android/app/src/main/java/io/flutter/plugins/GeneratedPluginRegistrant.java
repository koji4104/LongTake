package io.flutter.plugins;

import androidx.annotation.Keep;
import androidx.annotation.NonNull;
import io.flutter.Log;

import io.flutter.embedding.engine.FlutterEngine;

/**
 * Generated file. Do not edit.
 * This file is generated by the Flutter tool based on the
 * plugins that support the Android platform.
 */
@Keep
public final class GeneratedPluginRegistrant {
  private static final String TAG = "GeneratedPluginRegistrant";
  public static void registerWith(@NonNull FlutterEngine flutterEngine) {
    try {
      flutterEngine.getPlugins().add(new dev.fluttercommunity.plus.battery.BatteryPlusPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin battery_plus, dev.fluttercommunity.plus.battery.BatteryPlusPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new io.flutter.plugins.camera.CameraPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin camera, io.flutter.plugins.camera.CameraPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new de.appgewaltig.disk_space.DiskSpacePlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin disk_space, de.appgewaltig.disk_space.DiskSpacePlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin flutter_plugin_android_lifecycle, io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new com.example.flutter_video_info.FlutterVideoInfoPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin flutter_video_info, com.example.flutter_video_info.FlutterVideoInfoPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new carnegietechnologies.gallery_saver.GallerySaverPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin gallery_saver, carnegietechnologies.gallery_saver.GallerySaverPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new io.flutter.plugins.googlesignin.GoogleSignInPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin google_sign_in_android, io.flutter.plugins.googlesignin.GoogleSignInPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new com.github.rmtmckenzie.native_device_orientation.NativeDeviceOrientationPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin native_device_orientation, com.github.rmtmckenzie.native_device_orientation.NativeDeviceOrientationPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new io.flutter.plugins.pathprovider.PathProviderPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin path_provider_android, io.flutter.plugins.pathprovider.PathProviderPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new com.baseflow.permissionhandler.PermissionHandlerPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin permission_handler, com.baseflow.permissionhandler.PermissionHandlerPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new com.morbit.photogallery.PhotoGalleryPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin photo_gallery, com.morbit.photogallery.PhotoGalleryPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new top.kikt.imagescanner.ImageScannerPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin photo_manager, top.kikt.imagescanner.ImageScannerPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin shared_preferences_android, io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new io.flutter.plugins.videoplayer.VideoPlayerPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin video_player_android, io.flutter.plugins.videoplayer.VideoPlayerPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new xyz.justsoft.video_thumbnail.VideoThumbnailPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin video_thumbnail, xyz.justsoft.video_thumbnail.VideoThumbnailPlugin", e);
    }
    try {
      flutterEngine.getPlugins().add(new creativemaybeno.wakelock.WakelockPlugin());
    } catch(Exception e) {
      Log.e(TAG, "Error registering plugin wakelock, creativemaybeno.wakelock.WakelockPlugin", e);
    }
  }
}
