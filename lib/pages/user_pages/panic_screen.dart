import 'dart:async';
import 'package:flutter/material.dart';

class PanicScreen extends StatefulWidget {
  final VoidCallback onSendDistress;
  final VoidCallback onCancel;

  const PanicScreen({
    super.key,
    required this.onSendDistress,
    required this.onCancel,
  });

  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  int tapCount = 0;
  Timer? tapTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shakeAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _pulseController.repeat(reverse: true);

    // Auto-cancel after 30 seconds if no action
    Timer(const Duration(seconds: 30), () {
      if (mounted) {
        widget.onCancel();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    tapTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      tapCount++;
    });

    if (tapCount == 1) {
      // First tap - show accidental message and start timer
      tapTimer = Timer(const Duration(seconds: 3), () {
        if (tapCount == 1) {
          // Only one tap in 3 seconds - treat as accidental
          widget.onCancel();
        }
      });
    } else if (tapCount >= 2) {
      // Two or more taps - send distress signal
      tapTimer?.cancel();
      widget.onSendDistress();
    }

    // Shake animation on tap
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.red,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: const Icon(
                            Icons.warning,
                            size: 100,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'EMERGENCY MODE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (tapCount == 0) ...[
                      const Text(
                        'Tap TWICE to send distress signal\nTap ONCE if accidental',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ] else if (tapCount == 1) ...[
                      const Text(
                        'Tap AGAIN to confirm distress signal\nOr wait 3 seconds to cancel',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 60),
                    GestureDetector(
                      onTap: _handleTap,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: Text(
                            tapCount == 0 ? 'TAP HERE' : 'TAP AGAIN',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (tapCount == 0)
                      TextButton(
                        onPressed: widget.onCancel,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
