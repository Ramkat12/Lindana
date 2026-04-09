import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;


@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_VoiceTaskHandler());
}

// ── Task handler — runs in its own isolate ─────────────────────────────────
// This isolate persists even when the user swipes the app away, because
// flutter_foreground_task keeps it alive as a foreground service.
// All SMS sending happens HERE, so alerts fire even when the app is closed.

class _VoiceTaskHandler extends TaskHandler {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _isListening = false;

  // Loaded from SharedPreferences on start / updated via sendData()
  String _wakePhrase = 'tuma msaada';
  String _baseUrl = '';
  String _authToken = '';
  List<Map<String, dynamic>> _contacts = [];

  SendPort? _sendPort;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    await _reloadPrefs();
    await _listen();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    // Refresh prefs periodically (token / contacts may change)
    await _reloadPrefs();
    if (!_isListening) await _listen();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    if (_isListening) await _speech.stop();
    _isListening = false;
  }

  @override
  void onReceiveData(Object data) {
    if (data is String) {
      // App sends updated wake phrase via FlutterForegroundTask.sendData()
      _wakePhrase = data;
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_stop') FlutterForegroundTask.stopService();
  }

  // ── Load prefs ────────────────────────────────────────────────────────────

  Future<void> _reloadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _wakePhrase = prefs.getString('voice_wake_word') ?? 'tuma msaada';
    _baseUrl = prefs.getString('api_base_url') ?? '';
    _authToken = prefs.getString('access_token') ?? '';
    final raw = prefs.getString('emergency_contacts_json') ?? '[]';
    try {
      _contacts =
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      _contacts = [];
    }
  }

  // ── Speech loop ───────────────────────────────────────────────────────────

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
      onResult: (result) async {
        if (result.finalResult) {
          _isListening = false;
          final spoken = result.recognizedWords.toLowerCase().trim();
          final phrase = _wakePhrase.toLowerCase().trim();
          if (_phraseDetected(spoken, phrase)) {
            await _handleDetected();
          }
          Future.delayed(const Duration(milliseconds: 300), _listen);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 4),
      // No localeId — uses the device's configured language.
      // This means Swahili phrases work when the phone language is set to Kiswahili,
      // and English phrases work when set to English.
      // ignore: deprecated_member_use
      cancelOnError: true,
    );
  }

  bool _phraseDetected(String spoken, String phrase) {
    if (spoken.contains(phrase)) return true;
    final words = phrase.split(RegExp(r'\s+'));
    if (words.length < 2) return false;
    return words.every((w) => spoken.contains(w));
  }

  // ── Alert: fire both in-app notification AND direct SMS ──────────────────

  Future<void> _handleDetected() async {
    // 1. Notify main isolate (wires to in-app snackbar when app is open)
    _sendPort?.send('ALERT_PHRASE_DETECTED');

    // 2. Send SMS directly from this isolate — works even when app is closed
    await _sendDirectSMS();

    // 3. Show a local push notification so the user knows the alert fired
    await _showLocalNotification();
  }

  Future<void> _sendDirectSMS() async {
    if (_baseUrl.isEmpty || _authToken.isEmpty || _contacts.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('last_known_lat');
    final lng = prefs.getDouble('last_known_lng');

    final locationPart = (lat != null && lng != null)
        ? '\n\nLocation: $lat, $lng\nMap: https://www.google.com/maps/search/?api=1&query=$lat,$lng'
        : '';
    final msg =
        'ALERT: This person may need help.$locationPart\n\nSent: ${DateTime.now()}';

    for (final c in _contacts) {
      final phone = c['contact_number']?.toString() ?? '';
      if (phone.isEmpty) continue;
      try {
        await http
            .post(
              Uri.parse('$_baseUrl/api/send-emergency-sms'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_authToken',
              },
              body: jsonEncode({
                'phone_number': phone,
                'message': msg,
                'is_emergency': true,
              }),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Individual contact failure — continue to next
      }
    }
  }

  Future<void> _showLocalNotification() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await plugin.show(
        998,
        '📩 Alert Sent via Voice',
        'Your emergency contacts have been notified. Help is on the way.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'lindana_emergency_v2',
            'Emergency Alerts',
            channelDescription: 'Voice phrase triggered emergency alert',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    } catch (_) {}
  }
}

// ── Public service: called from main isolate ──────────────────────────────────

class BackgroundVoiceService {
  BackgroundVoiceService._();
  static final BackgroundVoiceService instance = BackgroundVoiceService._();

  /// Fires when the main isolate receives ALERT_PHRASE_DETECTED.
  /// Use this to show an in-app snackbar — SMS is already sent by the task handler.
  void Function()? onWakeWordDetected;
  ReceivePort? _receivePort;

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'lindana_voice',
        channelName: 'Lindana Voice Monitor',
        channelDescription: 'Listening for your emergency wake phrase',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: const ForegroundTaskOptions(
        // Watchdog every 5 s — keeps speech loop alive
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true, // Restart after phone reboot
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Call this whenever contacts are loaded so the task isolate can use them.
  static Future<void> saveContactsForBackground(
    List<Map<String, dynamic>> contacts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_contacts_json', jsonEncode(contacts));
  }

  /// Call this whenever GPS position updates.
  static Future<void> savePositionForBackground(
    double lat,
    double lng,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_known_lat', lat);
    await prefs.setDouble('last_known_lng', lng);
  }

  Future<void> startIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('voice_activation_enabled') ?? false;
    if (!enabled) return;

    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    _attachPort();

    if (await FlutterForegroundTask.isRunningService) return;

    final wakePhrase = prefs.getString('voice_wake_word') ?? 'tuma msaada';

    await FlutterForegroundTask.startService(
      notificationTitle: 'Lindana is listening',
      notificationText: 'Say "$wakePhrase" to send a silent alert',
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

  Future<void> updateWakeWord(String newPhrase) async {
    FlutterForegroundTask.sendData(newPhrase);
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Lindana is listening',
      notificationText: 'Say "$newPhrase" to send a silent alert',
    );
  }

  void _attachPort() {
    _receivePort?.close();
    _receivePort = FlutterForegroundTask.receivePort;
    _receivePort?.listen((data) {
      if (data == 'ALERT_PHRASE_DETECTED') {
        // SMS already sent by task handler — just trigger UI callback
        onWakeWordDetected?.call();
      }
    });
  }
}
