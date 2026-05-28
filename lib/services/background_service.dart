// lib/services/background_service.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

/// Background service that keeps the app alive during screen-off recording.
///
/// Android kills apps in the background unless they run a foreground service
/// with a visible notification. This service does exactly that — it doesn't
/// move GPS/timer logic here (that stays in the main isolate), it just tells
/// Android "this process is doing important work, don't kill me."
class BackgroundServiceManager {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: null,
        onBackground: null,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: false,
        notificationChannelId: 'regatta_screen_channel',
        initialNotificationTitle: 'Regatta Screen',
        initialNotificationContent: 'Klaar om op te nemen',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> _onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
    return true;
  }

  static Future<void> startRecording() async {
    try {
      final service = FlutterBackgroundService();
      if (!(await service.isRunning())) {
        await service.startService();
      }
      service.invoke('setAsForeground', {
        'notificationTitle': 'Regatta Screen',
        'notificationContent': 'GPS en timer actief — opname loopt',
      });
    } on PlatformException {
      // Foreground service not available — recording still works in foreground
    } on MissingPluginException {
      // Plugin not registered — app runs without background service
    }
  }

  static Future<void> stopRecording() async {
    try {
      final service = FlutterBackgroundService();
      service.invoke('stopService');
    } on PlatformException {
      // Service already stopped or not available
    }
  }
}
