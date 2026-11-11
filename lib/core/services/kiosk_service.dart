import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to the Android side that makes PixelPod the whole phone. The
/// phone locks itself whenever the app resumes; this channel is for the
/// maintenance exit and dock mode.
class KioskService {
  KioskService._();

  static const _channel = MethodChannel('uk.dotfound.pixelpod/kiosk');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<void> _invoke(String method, [Object? arguments]) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint('Kiosk $method failed: ${error.message}');
    } on MissingPluginException catch (_) {}
  }

  /// Unlocks the phone and opens Android's Wi-Fi settings. The phone
  /// relocks the next time PixelPod is opened.
  static Future<void> openWifiSettings() => _invoke('openWifiSettings');

  static Future<void> openBluetoothSettings() =>
      _invoke('openBluetoothSettings');

  /// Keeps the screen on while charging.
  static Future<void> setDockMode({required bool enabled}) =>
      _invoke('setDockMode', enabled);
}
