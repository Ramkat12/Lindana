import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  /// Emergency alert channel — max importance so it plays sound + vibrates
  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    'lindana_emergency_v2',
    'Emergency Alerts',
    description: 'Plays sound and vibrates when emergency is triggered.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Foreground service channel (silent — just shows the persistent icon)
  const AndroidNotificationChannel fgChannel = AndroidNotificationChannel(
    'my_foreground',
    'Safety Monitor',
    description: 'Shake detection is running in the background.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin pluginFG =
      FlutterLocalNotificationsPlugin();

  await pluginFG
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(alertChannel);

  await pluginFG
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(fgChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Lindana Safety Active',
      initialNotificationContent:
          'Shake detection is running. Shake hard to send alert.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) => service.setAsForegroundService());
    service.on('setAsBackground').listen((_) => service.setAsBackgroundService());
  }

  service.on('stopService').listen((_) => service.stopSelf());

  // ── Shake Detection ────────────────────────────────────────────────────────
  // Threshold: 22 m/s² — requires a more rigorous, intense shake (approx 2.2G).
  // Avoids accidental activations while ensuring true panic shakes trigger it.
  const double shakeThreshold = 22.0;
  const int shakeCountThreshold = 3;
  const Duration shakeTimeWindow = Duration(seconds: 2);

  int shakeCount = 0;
  DateTime? lastShakeTime;

  accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 200))
      .listen((AccelerometerEvent event) {
    final double magnitude =
        sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));

    if (magnitude > shakeThreshold) {
      final now = DateTime.now();
      if (lastShakeTime == null ||
          now.difference(lastShakeTime!) < shakeTimeWindow) {
        shakeCount++;
        lastShakeTime = now;
        if (shakeCount >= shakeCountThreshold) {
          _triggerBackgroundPanic(service);
          shakeCount = 0;
        }
      } else {
        shakeCount = 1;
        lastShakeTime = now;
      }
    }
  });

  // Update foreground notification every hour
  Timer.periodic(const Duration(hours: 1), (_) async {
    if (service is AndroidServiceInstance &&
        await service.isForegroundService()) {
      service.setForegroundNotificationInfo(
        title: 'Lindana Safety Active',
        content: 'Shake detection is running.',
      );
    }
  });
}

Future<void> _triggerBackgroundPanic(ServiceInstance service) async {
  // 1. Notify main isolate (shows panic mode page)
  service.invoke('onShakeDetected');

  // 2. Show a high-priority notification to wake the screen (fullScreenIntent) which allows PanicScreen to show
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  await plugin.show(
    999,
    '🚨 Shake Detected',
    'Tap to open Panic Mode and send emergency distress signal.',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'lindana_emergency_v2',
        'Emergency Alerts',
        channelDescription: 'Shake triggered emergency alert',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        // Use default notification sound
        sound: null,
      ),
    ),
    payload: 'shake_alert',
  );
}
