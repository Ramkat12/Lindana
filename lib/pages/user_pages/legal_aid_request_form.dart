import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:is_project_1/models/profile_response.dart';
import 'package:is_project_1/pages/user_pages/legal_requests.dart';
import 'package:is_project_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/legal_aid_requests.dart';
import '../../services/legal_aid_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DESIGN DIRECTION: Professional Legal Form
// ══════════════════════════════════════════════════════════════════════════════
// Tone: Professional, trustworthy, clear — form should feel secure and legitimate.
// Enhanced validation prevents empty submissions and guides users.
// Refined navy/gold palette matches legal aid page aesthetic.
// Progressive disclosure: show validation feedback as user types.

class LegalAidRequestForm extends StatefulWidget {
  final LegalAidProvider? selectedProvider;

  const LegalAidRequestForm({super.key, this.selectedProvider});

  @override
  _LegalAidRequestFormState createState() => _LegalAidRequestFormState();
}

class _LegalAidRequestFormState extends State<LegalAidRequestForm>
    with SingleTickerProviderStateMixin {
  // ── Color Palette: align with user homepage (teal / lilac) ────────────────
  static const _teal = Color(0xFF4FABCB);
  static const _tealDark = Color(0xFF2E86AB);
  static const _lilac = Color(0xFFF5F3FF);
  static const _slate = Color(0xFF64748B);
  static const _slateLight = Color(0xFF94A3B8);
  static const _white = Color(0xFFFFFFFF);
  static const _success = Color(0xFF059669);
  static const _errorRed = Color(0xFFDC2626);

  final _formKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  ProfileResponse? profile;

  List<LegalAidProvider> _allProviders = [];
  LegalAidProvider? _selectedProvider;
  // Kept for potential future filtering by expertise; currently unused.
  // String? _selectedExpertiseArea;
  bool _isLoadingProviders = false;
  bool _isSubmitting = false;
  bool isLoading = true;
  String? error;

  // Validation state
  bool _legalNameTouched = false;
  bool _nationalIdTouched = false;
  bool _titleTouched = false;
  bool _descriptionTouched = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _selectedProvider = widget.selectedProvider;
    if (_selectedProvider != null) {
      _selectedExpertiseArea = _selectedProvider!.primaryExpertise;
    }
    _loadAllProviders();
    _loadProfileData();

    // Add listeners for real-time validation feedback
    _legalNameController.addListener(() {
      if (_legalNameTouched) setState(() {});
    });
    _nationalIdController.addListener(() {
      if (_nationalIdTouched) setState(() {});
    });
    _titleController.addListener(() {
      if (_titleTouched) setState(() {});
    });
    _descriptionController.addListener(() {
      if (_descriptionTouched) setState(() {});
    });
  }

  Future<void> _loadProfileData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      final profileData = await ApiService.getProfile();
      setState(() {
        profile = profileData;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadAllProviders() async {
    if (widget.selectedProvider != null) return;

    setState(() => _isLoadingProviders = true);

    try {
      final providers = await LegalAidService.getLegalAidProviders();
      setState(() {
        _allProviders = providers.where((p) => p.status == 'active').toList();
        _isLoadingProviders = false;
      });
    } catch (e) {
      setState(() => _isLoadingProviders = false);
      _showSnackBar('Error loading providers: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _legalNameController.dispose();
    _nationalIdController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // VALIDATION HELPERS
  // ══════════════════════════════════════════════════════════════════════════════

  String? _validateLegalName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Legal name is required';
    }
    if (value.trim().length < 3) {
      return 'Name must be at least 3 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  String? _validateNationalId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'National ID is required';
    }
    final cleaned = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length < 6) {
      return 'ID must be at least 6 digits';
    }
    if (cleaned.length > 20) {
      return 'ID is too long';
    }
    return null;
  }

  String? _validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Request title is required';
    }
    if (value.trim().length < 5) {
      return 'Title must be at least 5 characters';
    }
    if (value.trim().length > 100) {
      return 'Title is too long (max 100 characters)';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Description is required';
    }
    if (value.trim().length < 20) {
      return 'Please provide more detail (min 20 characters)';
    }
    if (value.trim().length > 2000) {
      return 'Description is too long (max 2000 characters)';
    }
    return null;
  }

  bool get _canSubmit {
    return _legalNameController.text.trim().isNotEmpty &&
        _nationalIdController.text.trim().isNotEmpty &&
        _titleController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        _selectedProvider != null &&
        !_isSubmitting;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lilac,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 24),
                if (_selectedProvider != null) ...[
                  _buildSelectedProviderCard(),
                  const SizedBox(height: 24),
                ],
                _buildLegalNameField(),
                const SizedBox(height: 20),
                _buildNationalIdField(),
                const SizedBox(height: 20),
                _buildTitleField(),
                const SizedBox(height: 20),
                _buildDescriptionField(),
                const SizedBox(height: 20),
                if (_selectedProvider == null) ...[
                  _buildProviderDropdown(),
                  const SizedBox(height: 20),
                ],
                if (_selectedProvider != null) _buildExpertiseDisplay(),
                const SizedBox(height: 32),
                _buildSubmitButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _teal,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: _white, size: 18),
      onPressed: () => Navigator.of(context).pop(),
    ),
    title: const Text(
      'Request Legal Aid',
      style: TextStyle(
        fontFamily: 'Georgia',
        color: _white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
    centerTitle: true,
  );

  // ── Header Card ───────────────────────────────────────────────────────────

  Widget _buildHeaderCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _tealDark,
          _teal,
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.gavel_rounded, color: _white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Legal Aid Request',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Provide accurate details to receive qualified legal assistance',
                style: TextStyle(
                  fontSize: 12,
                  color: _white.withOpacity(0.75),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Selected Provider Card ────────────────────────────────────────────────

  Widget _buildSelectedProviderCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _success.withOpacity(0.3), width: 2),
      boxShadow: [
        BoxShadow(
          color: _success.withOpacity(0.08),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _success, width: 2),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundImage: _selectedProvider!.profileImage != null
                    ? NetworkImage(_selectedProvider!.profileImage!)
                    : null,
                backgroundColor: _tealDark.withOpacity(0.1),
                child: _selectedProvider!.profileImage == null
                    ? Icon(Icons.person, color: _tealDark, size: 24)
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _success,
                  shape: BoxShape.circle,
                  border: Border.all(color: _white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected Provider',
                style: TextStyle(
                  fontSize: 11,
                  color: _success,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _selectedProvider!.fullName,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _tealDark,
                ),
              ),
              Text(
                _selectedProvider!.allExpertiseAreas,
                style: TextStyle(fontSize: 11, color: _slate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _selectedProvider = null;
              _selectedExpertiseArea = null;
            });
          },
          child: Text(
            'Change',
            style: TextStyle(
              color: _success,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  // ── Form Fields ───────────────────────────────────────────────────────────

  Widget _buildLegalNameField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildFieldLabel('Legal Name', Icons.person_outline),
      const SizedBox(height: 10),
      TextFormField(
        controller: _legalNameController,
        decoration: _buildInputDecoration(
          'Enter your full legal name',
          Icons.person,
          error: _legalNameTouched
              ? _validateLegalName(_legalNameController.text)
              : null,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
          LengthLimitingTextInputFormatter(100),
        ],
        textCapitalization: TextCapitalization.words,
        onChanged: (_) {
          if (!_legalNameTouched) setState(() => _legalNameTouched = true);
        },
        validator: _validateLegalName,
      ),
      if (_legalNameTouched &&
          _validateLegalName(_legalNameController.text) == null)
        _buildValidationSuccess(),
    ],
  );

  Widget _buildNationalIdField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildFieldLabel('National ID Number', Icons.badge_outlined),
      const SizedBox(height: 10),
      TextFormField(
        controller: _nationalIdController,
        decoration: _buildInputDecoration(
          'Enter your national ID number',
          Icons.badge,
          error: _nationalIdTouched
              ? _validateNationalId(_nationalIdController.text)
              : null,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(20),
        ],
        onChanged: (_) {
          if (!_nationalIdTouched) setState(() => _nationalIdTouched = true);
        },
        validator: _validateNationalId,
      ),
      if (_nationalIdTouched &&
          _validateNationalId(_nationalIdController.text) == null)
        _buildValidationSuccess(),
    ],
  );

  Widget _buildTitleField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildFieldLabel('Request Title', Icons.title_outlined),
      const SizedBox(height: 10),
      TextFormField(
        controller: _titleController,
        decoration: _buildInputDecoration(
          'Brief, clear title for your request',
          Icons.title,
          error: _titleTouched ? _validateTitle(_titleController.text) : null,
        ),
        inputFormatters: [LengthLimitingTextInputFormatter(100)],
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) {
          if (!_titleTouched) setState(() => _titleTouched = true);
        },
        validator: _validateTitle,
      ),
      if (_titleTouched && _validateTitle(_titleController.text) == null)
        _buildValidationSuccess(),
    ],
  );

  Widget _buildDescriptionField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildFieldLabel('Detailed Description', Icons.description_outlined),
      const SizedBox(height: 10),
      TextFormField(
        controller: _descriptionController,
        maxLines: 5,
        decoration: _buildInputDecoration(
          'Describe your legal situation in detail...',
          Icons.description,
          error: _descriptionTouched
              ? _validateDescription(_descriptionController.text)
              : null,
        ),
        inputFormatters: [LengthLimitingTextInputFormatter(2000)],
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) {
          if (!_descriptionTouched) setState(() => _descriptionTouched = true);
        },
        validator: _validateDescription,
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Icon(Icons.info_outline, size: 13, color: _slate),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Include relevant dates, parties involved, and type of assistance needed',
              style: TextStyle(fontSize: 11, color: _slate, height: 1.3),
            ),
          ),
        ],
      ),
      if (_descriptionTouched &&
          _validateDescription(_descriptionController.text) == null)
        _buildValidationSuccess(),
    ],
  );

  Widget _buildProviderDropdown() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildFieldLabel('Select Legal Aid Provider', Icons.people_outline),
      const SizedBox(height: 10),
      _isLoadingProviders
          ? Container(
              height: 58,
              decoration: BoxDecoration(
                border: Border.all(color: _slateLight.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
                color: _white,
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : DropdownButtonFormField<LegalAidProvider>(
              value: _selectedProvider,
              decoration: _buildInputDecoration(
                'Choose a provider',
                Icons.people,
              ),
              isExpanded: true,
              items: _allProviders.map((provider) {
                return DropdownMenuItem<LegalAidProvider>(
                  value: provider,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        provider.fullName,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _tealDark,
                        ),
                      ),
                      Text(
                        provider.primaryExpertise,
                        style: TextStyle(fontSize: 11, color: _slate),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (LegalAidProvider? newValue) {
                setState(() {
                  _selectedProvider = newValue;
                  _selectedExpertiseArea = newValue?.primaryExpertise;
                });
              },
              validator: (value) =>
                  value == null ? 'Please select a provider' : null,
            ),
    ],
  );

  Widget _buildExpertiseDisplay() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildFieldLabel('Expertise Areas', Icons.workspace_premium_outlined),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _teal.withOpacity(0.05),
          border: Border.all(color: _teal.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _selectedProvider!.allExpertiseAreas,
          style: TextStyle(fontSize: 13, color: _tealDark, height: 1.4),
        ),
      ),
    ],
  );

  Widget _buildSubmitButton() => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: double.infinity,
    height: 54,
    decoration: BoxDecoration(
      gradient: _canSubmit
          ? const LinearGradient(colors: [Color(0xFF2E86AB), Color(0xFF4FABCB)])
          : null,
      color: _canSubmit ? null : _slateLight.withOpacity(0.3),
      borderRadius: BorderRadius.circular(12),
      boxShadow: _canSubmit
          ? [
              BoxShadow(
                color: _tealDark.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _canSubmit ? _submitForm : null,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(_white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: _canSubmit ? _white : _slateLight,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Submit Request',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _canSubmit ? _white : _slateLight,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildFieldLabel(String text, IconData icon) => Row(
    children: [
      Icon(icon, size: 16, color: _teal),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _tealDark,
        ),
      ),
      const SizedBox(width: 4),
      const Text(' *', style: TextStyle(color: _errorRed, fontSize: 14)),
    ],
  );

  Widget _buildValidationSuccess() => Padding(
    padding: const EdgeInsets.only(top: 6, left: 4),
    child: Row(
      children: [
        Icon(Icons.check_circle, size: 14, color: _success),
        const SizedBox(width: 5),
        Text(
          'Looks good',
          style: TextStyle(
            fontSize: 11,
            color: _success,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  InputDecoration _buildInputDecoration(
    String hint,
    IconData icon, {
    String? error,
  }) {
    final hasError = error != null;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _slateLight, fontSize: 13),
      prefixIcon: Icon(icon, color: hasError ? _errorRed : _slate, size: 20),
      errorText: hasError ? error : null,
      errorStyle: const TextStyle(fontSize: 11, height: 1.2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _slateLight.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _slateLight.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _teal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorRed, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _errorRed, width: 2),
      ),
      filled: true,
      fillColor: _white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // FORM SUBMISSION
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> _submitForm() async {
    // Mark all fields as touched to show validation
    setState(() {
      _legalNameTouched = true;
      _nationalIdTouched = true;
      _titleTouched = true;
      _descriptionTouched = true;
    });

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix all errors before submitting', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null || userId.trim().isEmpty) {
        setState(() => _isSubmitting = false);
        _showSnackBar(
          'You must be logged in to submit a request',
          isError: true,
        );
        return;
      }

      // Final validation before submission
      final legalName = _legalNameController.text.trim();
      final nationalId = _nationalIdController.text.trim();
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();

      if (legalName.isEmpty ||
          nationalId.isEmpty ||
          title.isEmpty ||
          description.isEmpty) {
        setState(() => _isSubmitting = false);
        _showSnackBar('All fields must be filled', isError: true);
        return;
      }

      if (_selectedProvider == null) {
        setState(() => _isSubmitting = false);
        _showSnackBar('Please select a legal aid provider', isError: true);
        return;
      }

      await LegalAidService.createLegalAidRequest(
        userId: userId,
        providerId: _selectedProvider!.id,
        title: title,
        description: description,
      );

      setState(() => _isSubmitting = false);

      // Show success dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: _success, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Request Submitted',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            'Your legal aid request has been submitted successfully to ${_selectedProvider!.fullName}. You will be contacted soon.',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LegalRequestsScreen()),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: _tealDark,
                foregroundColor: _white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'View Requests',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: _white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: isError ? _errorRed : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
