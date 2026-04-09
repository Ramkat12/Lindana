import 'package:flutter/material.dart';
import 'package:is_project_1/services/background_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Callback type so MapPage (or any parent) can react when the wake word fires.
typedef OnWakeWordDetected = void Function();

class VoiceActivationPage extends StatefulWidget {
  /// Called the moment the wake word is confirmed — wire this to
  /// MapPage._triggerPanicMode() when pushing this page.
  final OnWakeWordDetected? onWakeWordDetected;

  const VoiceActivationPage({super.key, this.onWakeWordDetected});

  @override
  State<VoiceActivationPage> createState() => _VoiceActivationPageState();
}

class _VoiceActivationPageState extends State<VoiceActivationPage>
    with SingleTickerProviderStateMixin {
  // ── Settings ────────────────────────────────────────────────────────────────
  bool _isEnabled = false;
  String _wakeWord = 'tuma msaada';
  final _wakeWordCtrl = TextEditingController();

  // ── Speech ──────────────────────────────────────────────────────────────────
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _heardText = '';
  double _confidence = 0.0;

  // ── Status display ──────────────────────────────────────────────────────────
  _Status _status = _Status.idle;

  // ── Animation (mic pulse) ───────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Constants ────────────────────────────────────────────────────────────────
  static const _blue = Color(0xFF4FABCB);
  static const _dark = Color(0xFF2D3748);
  static const _lilac = Color(0xFFF5F3FF);

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadSettings().then((_) async {
      // FREEDOM FOR THE MIC: Stop the background process while configuring
      await BackgroundVoiceService.instance.stop();
    });

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.25,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _wakeWordCtrl.dispose();
    if (_isListening) _speech.stop();
    
    // Resume background listening when leaving the config page
    if (_isEnabled) {
      BackgroundVoiceService.instance.onWakeWordDetected = widget.onWakeWordDetected;
      BackgroundVoiceService.instance.startIfEnabled();
    } else {
      BackgroundVoiceService.instance.stop();
    }
    
    super.dispose();
  }

  // ── Persistence ──────────────────────────────────────────────────────────────
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isEnabled = prefs.getBool('voice_activation_enabled') ?? false;
      _wakeWord = prefs.getString('voice_wake_word') ?? 'tuma msaada';
      _wakeWordCtrl.text = _wakeWord;
    });
  }

  Future<void> _saveSettings() async {
    final trimmed = _wakeWordCtrl.text.trim();
    if (trimmed.isEmpty) {
      _showSnack('Wake phrase cannot be empty', isError: true);
      return;
    }
    // Require at least 2 words to reduce false triggers
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length < 2) {
      _showSnack(
        'Please enter at least 2 words (e.g. "tuma msaada") to avoid false alarms.',
        isError: true,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_activation_enabled', _isEnabled);
    await prefs.setString('voice_wake_word', trimmed);
    setState(() => _wakeWord = trimmed);

    // Background service is restarted automatically on dispose()
    // This allows the user to test the phrase immediately without mic lock errors.
    
    _showSnack('Settings saved ✓');
  }

  // ── Speech init ──────────────────────────────────────────────────────────────
  Future<bool> _initSpeech() async {
    if (_speechAvailable) return true;

    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _status = _Status.error;
          });
        }
        _pulseCtrl.stop();
        _pulseCtrl.reset();
        _showSnack('Mic error: ${err.errorMsg}', isError: true);
      },
    );

    if (!_speechAvailable && mounted) {
      setState(() => _status = _Status.error);
      _showSnack(
        'Speech recognition not available on this device',
        isError: true,
      );
    }
    return _speechAvailable;
  }

  // ── Listen / stop ────────────────────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _status = _Status.idle;
      });
      _pulseCtrl.stop();
      _pulseCtrl.reset();
      return;
    }

    final ready = await _initSpeech();
    if (!ready) return;

    setState(() {
      _isListening = true;
      _heardText = '';
      _confidence = 0.0;
      _status = _Status.listening;
    });

    _pulseCtrl.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _heardText = result.recognizedWords;
          if (result.finalResult) {
            _confidence = result.confidence;
            _isListening = false;
            _pulseCtrl.stop();
            _pulseCtrl.reset();
            _checkWakeWord(_heardText);
          }
        });
      },
      localeId: 'en_US',
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: true,
    );
  }

  // ── Wake word check ────────────────────────────────────────────────────────────
  void _checkWakeWord(String spoken) {
    final detected = spoken.toLowerCase().contains(_wakeWord.toLowerCase());

    setState(() => _status = detected ? _Status.detected : _Status.missed);

    if (detected) {
      // When testing: just show confirmation — do NOT open panic dialog.
      // In production the background service sends the real SMS alert.
      _showSnack('✅ Phrase detected! An alert would be sent to your contacts.');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Status helpers ────────────────────────────────────────────────────────────
  Color get _statusColor {
    switch (_status) {
      case _Status.listening:
        return _blue;
      case _Status.detected:
        return Colors.green.shade600;
      case _Status.missed:
        return Colors.orange.shade700;
      case _Status.error:
        return Colors.red.shade600;
      case _Status.idle:
        return Colors.grey.shade500;
    }
  }

  String get _statusText {
    switch (_status) {
      case _Status.listening:
        return _heardText.isEmpty
            ? "Listening… say '$_wakeWord'"
            : 'Hearing: "$_heardText"';
      case _Status.detected:
        return '✅ Phrase detected! Alert would be sent to your contacts.';
      case _Status.missed:
        return '❌ Heard: "$_heardText" — phrase not matched.';
      case _Status.error:
        return 'Microphone error. Please try again.';
      case _Status.idle:
        return 'Press the mic to test your wake phrase.';
    }
  }

  IconData get _micIcon =>
      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded;

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lilac,
      appBar: AppBar(
        backgroundColor: _lilac,
        elevation: 0,
        title: const Text(
          'Voice Activation',
          style: TextStyle(
            color: _dark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: _dark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Enable toggle card ──────────────────────────────────────────
            _card(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Enable Voice Activation',
                  style: TextStyle(
                    color: _dark,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Say your wake phrase to silently alert your emergency contacts without opening the app',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ),
                value: _isEnabled,
                activeColor: _blue,
                onChanged: (v) {
                  setState(() => _isEnabled = v);
                  _saveSettings();
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Wake word config card ───────────────────────────────────────
            _sectionLabel('WAKE WORD'),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter at least 2 words as your secret phrase (e.g. "kujeni hapa" or "tuma msaada"). Using 2+ words prevents false triggers from everyday speech.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  // Kiswahili tip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF81C784), width: 1),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🇰🇪 ', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Kiswahili tip: For Swahili phrases to be recognised, go to '
                            'Phone Settings → Language & Input → Speech → Offline Speech '
                            'and download the Kiswahili (sw-KE) language pack.',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _wakeWordCtrl,
                    style: const TextStyle(color: _dark, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'e.g. kujeni hapa, tuma msaada, help me now',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.record_voice_over_rounded,
                        color: _blue,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _blue, width: 1.5),
                      ),
                    ),
                    onChanged: (v) => setState(() => _wakeWord = v.trim()),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _saveSettings,
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Save Wake Word',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Test detection card ─────────────────────────────────────────
            _sectionLabel('TEST DETECTION'),
            _card(
              child: Column(
                children: [
                  Text(
                    'Press the mic and say your wake phrase.\nIf detected, a silent alert is sent to your contacts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),

                  const SizedBox(height: 28),

                  // Mic button with pulse animation
                  GestureDetector(
                    onTap: _toggleListening,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Transform.scale(
                        scale: _isListening ? _pulseAnim.value : 1.0,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: _isListening ? Colors.red : _blue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening ? Colors.red : _blue)
                                    .withOpacity(0.35),
                                blurRadius: 18,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(_micIcon, color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Status text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusText,
                      key: ValueKey(_status),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  // Confidence badge
                  if (_confidence > 0 && _status != _Status.listening) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── How it works card ───────────────────────────────────────────
            _sectionLabel('HOW IT WORKS'),
            _card(
              child: Column(
                children: [
                  _howItWorksRow(
                    Icons.mic_rounded,
                    'App listens for your 2-word wake phrase in background',
                    '1',
                  ),
                  const SizedBox(height: 14),
                  _howItWorksRow(
                    Icons.send_rounded,
                    'A silent SMS alert is sent to your emergency contacts',
                    '2',
                  ),
                  const SizedBox(height: 14),
                  _howItWorksRow(
                    Icons.notifications_active_rounded,
                    'You get a confirmation — app stays open, no panic screen',
                    '3',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey[300]!, width: 1.3),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.07),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[400],
        letterSpacing: 0.9,
      ),
    ),
  );

  Widget _howItWorksRow(IconData icon, String label, String step) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _blue.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            step,
            style: const TextStyle(
              color: _blue,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
      const SizedBox(width: 14),
      Icon(icon, color: _blue, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
      ),
    ],
  );
}

/// Internal status enum to drive the UI cleanly
enum _Status { idle, listening, detected, missed, error }
