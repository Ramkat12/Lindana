import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:is_project_1/components/my_button.dart';
import 'package:is_project_1/components/my_textfield.dart';
import 'package:is_project_1/pages/admin_pages/admin_homepage.dart';
import 'package:is_project_1/pages/legal_aid_pages/legalaid_homepage.dart';
import 'package:is_project_1/pages/forgot_password_page.dart';
import 'package:is_project_1/pages/register_page.dart';
import 'package:is_project_1/pages/user_pages/user_homepage.dart';
import 'package:is_project_1/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  void signUserIn() async {
    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
      showErrorMessage('Please fill in all fields');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': usernameController.text.trim(),
          'password': passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        final Map responseData = json.decode(response.body);

        await AuthService.storeTokens(
          responseData['access_token'],
          responseData['refresh_token'],
        );

        final roleId = await AuthService.getCurrentUserRole();

        if (mounted && roleId != null) {
          Widget destinationPage;
          if (roleId == 4) {
            destinationPage = const AdminHomepage();
          } else if (roleId == 6) {
            destinationPage = const LegalAidHomepage();
          } else {
            destinationPage = const UserHomepage();
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => destinationPage),
          );

          showSuccessMessage('Login successful!');
        }
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = json.decode(response.body);
        showErrorMessage(errorData['detail'] ?? 'Invalid credentials');
      } else {
        showErrorMessage('Login failed. Please try again.');
      }
    } catch (e) {
      showErrorMessage('Network error. Please check your connection.');
      print('Login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF), // Mild lilac background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

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

                  const SizedBox(height: 50),

                  // Sign-in card (starting from Welcome Back)
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
                    child: Column(
                      children: [
                        // Welcome text
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            color: Color(0xFF2D3748),
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Sign in to continue',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Email/Phone field
                        SizedBox(
                          width: double.infinity,
                          child: MyTextfield(
                            controller: usernameController,
                            hintText: 'Email or Phone Number',
                            obscureText: false,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Password field
                        SizedBox(
                          width: double.infinity,
                          child: MyTextfield(
                            controller: passwordController,
                            hintText: 'Password',
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

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Color(0xFF4FABCB),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Sign in button
                        isLoading
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
                                onTap: signUserIn,
                                child: Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4FABCB),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Sign In',
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

                        const SizedBox(height: 28),

                        // Divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                thickness: 0.5,
                                color: Colors.grey[400],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                thickness: 0.5,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Register link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Don\'t have an account? ',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 15,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Register',
                                style: TextStyle(
                                  color: Color(0xFF4FABCB),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

  @override
  void dispose() {
    _animationController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

// Keep all other classes unchanged
class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(
        child: Text(
          'Welcome, you are logged in!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class ExamplePageWithLogout extends StatelessWidget {
  const ExamplePageWithLogout({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthService.logout();

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: const Center(child: Text('Your page content here')),
    );
  }
}

class LogoutButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback? onLoggedOut;

  const LogoutButton({super.key, this.text, this.icon, this.onLoggedOut});

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthService.logout();
      onLoggedOut?.call();

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (text != null) {
      return TextButton(
        onPressed: () => _handleLogout(context),
        child: Text(text!),
      );
    }

    return IconButton(
      icon: Icon(icon ?? Icons.logout),
      onPressed: () => _handleLogout(context),
      tooltip: 'Logout',
    );
  }
}
