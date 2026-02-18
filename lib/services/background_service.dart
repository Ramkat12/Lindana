import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sensors_plus/sensors_plus.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  /// OPTIONAL, using custom notification channel id
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'MY FOREGROUND SERVICE', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: false, // We will start it manually when user enables it
      isForegroundMode: true,

      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Safety Service',
      initialNotificationContent: 'Monitoring for emergency gestures',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: false, // We will start it manually
      // this will be executed when app is in foreground in separated isolate
      onForeground: onStart,
      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),
  );
}

// to ensure this is executed
// run app from xcode, then from xcode menu, select Simulate Background Fetch
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Only available for flutter 3.0.0 and later
  DartPluginRegistrant.ensureInitialized();

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

  // Shake Detection Logic
  // We need to re-implement shake logic here because we are in a separate isolate
  double shakeThreshold = 35.0; // Vigorous shake
  int shakeCountThreshold = 3;
  Duration shakeTimeWindow = const Duration(seconds: 2);
  
  int shakeCount = 0;
  DateTime? lastShakeTime;
  
  accelerometerEvents.listen((AccelerometerEvent event) {
    double gForce = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));

    if (gForce > shakeThreshold) {
        DateTime now = DateTime.now();
        if (lastShakeTime == null || now.difference(lastShakeTime!) < shakeTimeWindow) {
            shakeCount++;
            lastShakeTime = now;
            
            if (shakeCount >= shakeCountThreshold) {
                // Trigger PANIC
                _triggerBackgroundPanic(service);
                shakeCount = 0;
            }
        } else {
            shakeCount = 1;
            lastShakeTime = now;
        }
    }
  });

  // bring to foreground
  Timer.periodic(const Duration(hours: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Safety Service Active",
          content: "Shake monitoring is active",
        );
      }
    }
  });
}

void _triggerBackgroundPanic(ServiceInstance service) {
    debugPrint("BACKGROUND SHAKE DETECTED! TRIGGERING PANIC!");
    
    // We can't directly show UI from here.
    // We send a message to the main isolate if it's alive,
    // or we could launch the app / send SMS directly if implemented here.
    // For now, let's invoke a notification that, when tapped, opens the app in panic mode.
    
    service.invoke("onShakeDetected");
    
    // Show a high priority notification immediately
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
      
    flutterLocalNotificationsPlugin.show(
      999,
      'EMERGENCY TRIGGERED',
      'Shake detected! Tap to open Emergency Mode.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'emergency_channel',
          'Emergency Alerts',
          channelDescription: 'Alerts for detected emergencies',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true, // Attempt to wake screen
        ),
      ),
      payload: 'panic_mode',
    );
}
