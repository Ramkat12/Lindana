import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:is_project_1/components/image_picker_widget.dart';
import 'package:is_project_1/pages/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  // Controllers
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final emergencyContactController = TextEditingController();
  final emegencyContactNameController = TextEditingController();
  final emergencyContactEmailController = TextEditingController();
  final pskController = TextEditingController();
  final aboutController = TextEditingController();

  // State
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int selectedRole = 5;
  List<int> selectedExpertiseAreas = [];
  List<Map<String, dynamic>> expertiseAreas = [];
  bool _loadingExpertiseAreas = false;
  File? _profileImage;
  bool _isLoading = false;
  int _currentStep = 1; // 1 basic | 2 password | 3 role-specific

  // Animation
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  String API_BASE_URL =
      dotenv.env['API_BASE_URL'] ?? 'https://2da6347a111f.ngrok-free.app';

  String get roleString =>
      selectedRole == 5 ? 'Safety Concerned Individual' : 'Legal Aid Provider';

  static const _blue = Color(0xFF4FABCB);
  static const _dark = Color(0xFF2D3748);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadExpertiseAreas();
    _loadEnv();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  Future<void> _loadEnv() async {
    try {
      await dotenv.load(fileName: '.env');
      setState(() {
        API_BASE_URL =
            dotenv.env['API_BASE_URL'] ?? 'https://4ffe55f88bc6.ngrok-free.app';
      });
    } catch (_) {}
  }

  Future<void> _loadExpertiseAreas() async {
    setState(() => _loadingExpertiseAreas = true);
    try {
      final res = await http.get(
        Uri.parse('$API_BASE_URL/expertise-areas'),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        setState(
          () => expertiseAreas = (json.decode(res.body) as List)
              .cast<Map<String, dynamic>>(),
        );
      }
    } catch (_) {
    } finally {
      setState(() => _loadingExpertiseAreas = false);
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _next(int to) {
    setState(() => _currentStep = to);
    _animCtrl.forward(from: 0);
  }

  void _back() {
    setState(() => _currentStep -= 1);
    _animCtrl.forward(from: 0);
  }

  // ── Registration ───────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (roleString == 'Safety Concerned Individual' &&
        (emergencyContactController.text.isEmpty ||
            emegencyContactNameController.text.isEmpty ||
            emergencyContactEmailController.text.isEmpty)) {
      _err('Please fill in all emergency contact fields');
      return;
    }
    if (roleString == 'Legal Aid Provider' && selectedExpertiseAreas.isEmpty) {
      _err('Please select at least one expertise area');
      return;
    }
    if (_profileImage != null &&
        await _profileImage!.length() > 2 * 1024 * 1024) {
      _err('Image must be less than 2 MB');
      return;
    }
    setState(() => _isLoading = true);
    try {
      roleString == 'Safety Concerned Individual'
          ? await _registerSafetyUser()
          : await _registerLegalAid();
    } catch (e) {
      _err('Registration failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _b64() async {
    if (_profileImage == null) return null;
    return base64Encode(await _profileImage!.readAsBytes());
  }

  Future<void> _registerSafetyUser() async {
    final res = await http.post(
      Uri.parse('$API_BASE_URL/register/user'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'full_name': nameController.text.trim(),
        'phone_number': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'password_hash': passwordController.text,
        'emergency_contact_number': emergencyContactController.text.trim(),
        'emergency_contact_name': emegencyContactNameController.text.trim(),
        'emergency_contact_email': emergencyContactEmailController.text.trim(),
        'role_id': selectedRole,
        'status': 'Pending',
        'profile_image': await _b64(),
      }),
    );
    res.statusCode == 200
        ? _success()
        : _err(
            res.statusCode == 422
                ? 'Validation: ${json.decode(res.body)['detail'][0]['msg']}'
                : 'Registration failed. Try again.',
          );
  }

  Future<void> _registerLegalAid() async {
    final res = await http.post(
      Uri.parse('$API_BASE_URL/register/legal_aid_provider'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'full_name': nameController.text.trim(),
        'phone_number': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'password_hash': passwordController.text,
        'expertise_area_ids': selectedExpertiseAreas,
        'role_id': selectedRole,
        'status': 'Pending',
        'profile_image': await _b64(),
        'psk_number': pskController.text.trim(),
        'about': aboutController.text.trim(),
      }),
    );
    res.statusCode == 200
        ? _success()
        : _err('Registration failed. Try again.');
  }

  // ── Feedback ───────────────────────────────────────────────────────────────
  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _success() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Success 🎉'),
        content: const Text('Your account has been created!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text(
              'Login now',
              style: TextStyle(color: _blue, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared UI helpers ──────────────────────────────────────────────────────

  /// All text fields use this decoration — no MyTextfield nesting = no overflow
  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
    filled: true,
    fillColor: Colors.grey[50],
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _blue, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.red.shade400),
    ),
  );

  Widget _tf(
    TextEditingController c,
    String hint, {
    bool obscure = false,
    Widget? suffix,
  }) => TextField(
    controller: c,
    obscureText: obscure,
    style: const TextStyle(fontSize: 15, color: _dark),
    decoration: _dec(hint).copyWith(suffixIcon: suffix),
  );

  Widget _eyeBtn(bool hidden, VoidCallback onTap) => IconButton(
    icon: Icon(
      hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
      color: Colors.grey[400],
      size: 20,
    ),
    onPressed: onTap,
  );

  Widget _btn(String label, VoidCallback? onTap, {bool loading = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: onTap == null ? Colors.grey[300] : _blue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      );

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey[300]!, width: 1.4),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.07),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[400],
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _backBtn() => GestureDetector(
    onTap: _back,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 15,
        color: _dark,
      ),
    ),
  );

  Widget _dots() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3, (i) {
      final active = _currentStep == i + 1;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: active ? 22 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: active ? _blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }),
  );

  Widget _divider() => Row(
    children: [
      Expanded(child: Divider(thickness: 0.5, color: Colors.grey[300])),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'or',
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),
      ),
      Expanded(child: Divider(thickness: 0.5, color: Colors.grey[300])),
    ],
  );

  // ── Step 1 — Photo, name, contact, role ────────────────────────────────────
  Widget _step1() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Account',
          style: TextStyle(
            color: _dark,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Start with your basic information',
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),

        const SizedBox(height: 28),

        Center(
          child: ImagePickerWidget(
            onImagePicked: (img) => setState(() => _profileImage = img),
          ),
        ),

        const SizedBox(height: 28),

        _label('Personal Details'),
        _tf(nameController, 'Full Name'),
        const SizedBox(height: 14),
        _tf(phoneController, 'Phone Number'),
        const SizedBox(height: 14),
        _tf(emailController, 'Email Address'),

        const SizedBox(height: 22),

        _label('Account Type'),
        DropdownButtonFormField<int>(
          value: selectedRole,
          decoration: _dec('Select Role'),
          dropdownColor: Colors.white,
          style: const TextStyle(color: _dark, fontSize: 15),
          items: const [
            DropdownMenuItem(
              value: 5,
              child: Text('Safety Concerned Individual'),
            ),
            DropdownMenuItem(value: 6, child: Text('Legal Aid Provider')),
          ],
          onChanged: (v) => setState(() {
            selectedRole = v!;
            selectedExpertiseAreas.clear();
          }),
        ),

        const SizedBox(height: 32),

        _btn('Next', () {
          if (nameController.text.isEmpty ||
              phoneController.text.isEmpty ||
              emailController.text.isEmpty) {
            _err('Please fill in all fields');
            return;
          }
          _next(2);
        }),

        const SizedBox(height: 24),
        _divider(),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                'Login',
                style: TextStyle(
                  color: _blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  // ── Step 2 — Password only ─────────────────────────────────────────────────
  Widget _step2() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _backBtn(),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set Password',
                  style: TextStyle(
                    color: _dark,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Make it strong and memorable',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 32),

        _label('Password'),
        _tf(
          passwordController,
          'Password',
          obscure: _obscurePassword,
          suffix: _eyeBtn(
            _obscurePassword,
            () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 14),
        _tf(
          confirmPasswordController,
          'Confirm Password',
          obscure: _obscureConfirmPassword,
          suffix: _eyeBtn(
            _obscureConfirmPassword,
            () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
          ),
        ),

        const SizedBox(height: 32),

        _btn('Next', () {
          if (passwordController.text.isEmpty ||
              confirmPasswordController.text.isEmpty) {
            _err('Please fill in both fields');
            return;
          }
          if (passwordController.text != confirmPasswordController.text) {
            _err('Passwords do not match');
            return;
          }
          _next(3);
        }),
      ],
    ),
  );

  // ── Step 3 — Role-specific details ────────────────────────────────────────
  Widget _step3() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _backBtn(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Almost Done',
                    style: TextStyle(
                      color: _dark,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    roleString == 'Legal Aid Provider'
                        ? 'Provider details'
                        : 'Emergency contact info',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Safety Concerned Individual
        if (roleString == 'Safety Concerned Individual') ...[
          _label('Emergency Contact'),
          _tf(emegencyContactNameController, 'Contact Name'),
          const SizedBox(height: 14),
          _tf(emergencyContactController, 'Contact Phone Number'),
          const SizedBox(height: 14),
          _tf(emergencyContactEmailController, 'Contact Email'),
        ],

        // Legal Aid Provider
        if (roleString == 'Legal Aid Provider') ...[
          _label('Professional Details'),
          _tf(pskController, 'LSK Practicing Certificate Number'),
          const SizedBox(height: 14),
          _tf(aboutController, 'Brief description (education, experience…)'),

          const SizedBox(height: 22),

          _label('Expertise Areas'),
          _loadingExpertiseAreas
              ? const Center(
                  child: SizedBox(
                    height: 30,
                    width: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _blue,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: expertiseAreas.map((area) {
                    final sel = selectedExpertiseAreas.contains(area['id']);
                    return FilterChip(
                      label: Text(
                        area['name'],
                        style: TextStyle(
                          fontSize: 13,
                          color: sel ? _blue : Colors.grey[700],
                        ),
                      ),
                      selected: sel,
                      onSelected: (v) => setState(
                        () => v
                            ? selectedExpertiseAreas.add(area['id'])
                            : selectedExpertiseAreas.remove(area['id']),
                      ),
                      backgroundColor: Colors.grey[50],
                      selectedColor: const Color(0xFF4FABCB).withOpacity(0.12),
                      checkmarkColor: _blue,
                      side: BorderSide(color: sel ? _blue : Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                    );
                  }).toList(),
                ),

          if (selectedExpertiseAreas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${selectedExpertiseAreas.length} selected',
                style: const TextStyle(fontSize: 12, color: _blue),
              ),
            ),
        ],

        const SizedBox(height: 32),

        _btn(
          'Create Account',
          _isLoading ? null : _register,
          loading: _isLoading,
        ),
      ],
    ),
  );

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                const SizedBox(height: 40),

                const Text(
                  'LINDANA',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 24),
                _dots(),
                const SizedBox(height: 32),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: _currentStep == 1
                      ? KeyedSubtree(key: const ValueKey(1), child: _step1())
                      : _currentStep == 2
                      ? KeyedSubtree(key: const ValueKey(2), child: _step2())
                      : KeyedSubtree(key: const ValueKey(3), child: _step3()),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    emergencyContactController.dispose();
    emegencyContactNameController.dispose();
    emergencyContactEmailController.dispose();
    pskController.dispose();
    aboutController.dispose();
    super.dispose();
  }
}
