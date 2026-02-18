import 'dart:async';
import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_VoiceTaskHandler());
}

class _VoiceTaskHandler extends TaskHandler {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _isListening = false;
  String _wakeWord = 'msaada';
  SendPort? _sendPort;

  // v7: onStart takes SendPort? as second param
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    final prefs = await SharedPreferences.getInstance();
    _wakeWord = prefs.getString('voice_wake_word') ?? 'msaada';
    await _listen();
  }

  // v7: onRepeatEvent takes SendPort? as second param — watchdog every 5s
  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    if (!_isListening) await _listen();
  }

  // v7: onDestroy takes SendPort? as second param
  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    if (_isListening) await _speech.stop();
    _isListening = false;
  }

  @override
  void onReceiveData(Object data) {
    if (data is String) _wakeWord = data;
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_stop') FlutterForegroundTask.stopService();
  }

  Future<void> _listen() async {
    if (!_initialized) {
      _initialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            Future.delayed(const Duration(milliseconds: 500), _listen);
          }
        },
        onError: (_) {
          _isListening = false;
          Future.delayed(const Duration(seconds: 3), _listen);
        },
      );
    }
    if (!_initialized) return;
    _isListening = true;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _isListening = false;
          if (result.recognizedWords.toLowerCase().contains(
            _wakeWord.toLowerCase(),
          )) {
            // v7: send via sendPort directly
            _sendPort?.send('WAKE_WORD_DETECTED');
          }
          Future.delayed(const Duration(milliseconds: 300), _listen);
        }
      },
      localeId: 'en_US',
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 4),
      cancelOnError: true,
    );
  }
}

class BackgroundVoiceService {
  BackgroundVoiceService._();
  static final BackgroundVoiceService instance = BackgroundVoiceService._();

  void Function()? onWakeWordDetected;
  ReceivePort? _receivePort;

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'lindana_voice',
        channelName: 'Lindana Voice Monitor',
        channelDescription: 'Listening for your emergency wake word',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        // v7: buttons and iconData removed from AndroidNotificationOptions
        // notification buttons are no longer supported in v7+
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      // v7: uses interval directly, NOT eventAction
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> startIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('voice_activation_enabled') ?? false;
    if (!enabled) return;

    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // v7: attach receivePort BEFORE startService
    _attachPort();

    if (await FlutterForegroundTask.isRunningService) return;

    final wakeWord = prefs.getString('voice_wake_word') ?? 'msaada';

    await FlutterForegroundTask.startService(
      notificationTitle: 'Lindana is listening',
      notificationText: 'Say "$wakeWord" to trigger emergency mode',
      callback: startCallback,
    );
  }

  Future<void> stop() async {
    _receivePort?.close();
    _receivePort = null;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  Future<void> pause() => stop();
  Future<void> resume() => startIfEnabled();

  // v7: sendDataToTask is void (not async)
  Future<void> updateWakeWord(String newWord) async {
    FlutterForegroundTask.sendData(newWord);
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Lindana is listening',
      notificationText: 'Say "$newWord" to trigger emergency mode',
    );
  }

  void _attachPort() {
    _receivePort?.close();
    _receivePort = FlutterForegroundTask.receivePort;
    _receivePort?.listen((data) {
      if (data == 'WAKE_WORD_DETECTED') onWakeWordDetected?.call();
    });
  }
}
