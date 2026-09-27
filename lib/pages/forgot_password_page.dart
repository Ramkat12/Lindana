import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:is_project_1/components/my_textfield.dart';
import 'package:is_project_1/services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSendingOtp = false;
  bool _isResetting = false;
  bool _otpSent = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Phase 1: Request OTP
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email address');
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSuccess(responseData['detail'] ?? 'Verification code sent to your email!');
        setState(() {
          _otpSent = true;
        });
        _animationController.reset();
        _animationController.forward();
      } else {
        _showError(responseData['detail'] ?? 'Failed to send verification code. Please try again.');
      }
    } catch (e) {
      _showError('Connection error. Please check your internet.');
      debugPrint('Forgot password error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  // Phase 2: Reset Password using OTP
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (otp.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError('Please fill in all verification fields');
      return;
    }

    if (otp.length != 6) {
      _showError('OTP must be exactly 6 digits');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    setState(() {
      _isResetting = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'otp': otp,
          'new_password': password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSuccess(responseData['detail'] ?? 'Password reset successfully! Please sign in.');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context); // Go back to login page
        }
      } else {
        _showError(responseData['detail'] ?? 'Invalid code or password reset failed.');
      }
    } catch (e) {
      _showError('Connection error. Please try again.');
      debugPrint('Reset password error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF), // Mild lilac background to match LoginPage
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D3748)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  const Text(
                    'LINDANA',
                    style: TextStyle(
                      color: Color(0xFF4FABCB),
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Card Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: !_otpSent ? _buildRequestOtpView() : _buildVerifyOtpView(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── VIEW 1: Request OTP ────────────────────────────────────────────────────
  Widget _buildRequestOtpView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Forgot Password',
          style: TextStyle(
            color: Color(0xFF2D3748),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Enter your registered email address and we'll send you a 6-digit OTP to reset your password.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        // Email field
        SizedBox(
          width: double.infinity,
          child: MyTextfield(
            controller: _emailController,
            hintText: 'Enter your Email Address',
            obscureText: false,
          ),
        ),
        const SizedBox(height: 28),

        // Send OTP button
        _isSendingOtp
            ? Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF4FABCB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            : GestureDetector(
                onTap: _sendOtp,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FABCB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Send OTP Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  // ── VIEW 2: Verify OTP & Change Password ────────────────────────────────────
  Widget _buildVerifyOtpView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Verify & Reset',
          style: TextStyle(
            color: Color(0xFF2D3748),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "We have sent a 6-digit code to\n${_emailController.text.trim()}",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        // OTP Code input
        SizedBox(
          width: double.infinity,
          child: MyTextfield(
            controller: _otpController,
            hintText: '6-Digit OTP Code',
            obscureText: false,
          ),
        ),
        const SizedBox(height: 16),

        // New Password field
        SizedBox(
          width: double.infinity,
          child: MyTextfield(
            controller: _passwordController,
            hintText: 'New Password',
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.grey[500],
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm Password field
        SizedBox(
          width: double.infinity,
          child: MyTextfield(
            controller: _confirmPasswordController,
            hintText: 'Confirm New Password',
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.grey[500],
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Reset Password button
        _isResetting
            ? Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF4FABCB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              )
            : GestureDetector(
                onTap: _resetPassword,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FABCB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Reset Password',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
        const SizedBox(height: 20),

        // Back link
        GestureDetector(
          onTap: () {
            setState(() {
              _otpSent = false;
            });
            _animationController.reset();
            _animationController.forward();
          },
          child: const Text(
            'Change Email Address',
            style: TextStyle(
              color: Color(0xFF4FABCB),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
