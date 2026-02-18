import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:is_project_1/components/custom_legal_navbar.dart';
import 'package:is_project_1/models/legal_tips_models.dart';
import 'package:is_project_1/pages/legal_aid_pages/legalaid_homepage.dart';
import 'package:is_project_1/pages/legal_aid_pages/my_tips.dart' hide LegalTip;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/legal_tips_service.dart'; // Use the service's definitions

class AddLegalTipScreen extends StatefulWidget {
  final String legalAidProviderId;
  final LegalTip? existingTip; // For editing existing tips

  const AddLegalTipScreen({
    super.key,
    required this.legalAidProviderId,
    this.existingTip,
  });

  @override
  _AddLegalTipScreenState createState() => _AddLegalTipScreenState();
}

class _AddLegalTipScreenState extends State<AddLegalTipScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String baseUrl = 'https://2da6347a111f.ngrok-free.app';

  File? _selectedImage;
  bool _isLoading = false;
  late LegalTipsService _tipsService;
  bool _isEditing = false;

  // Add these variables to store current user info
  String? currentUserId;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadEnv();
    _initializeUser(); // Initialize user first

    // Initialize service - replace with your actual base URL and auth token
    _tipsService = LegalTipsService();

    _isEditing = widget.existingTip != null;

    // If editing, populate fields
    if (_isEditing) {
      _titleController.text = widget.existingTip!.title;
      _descriptionController.text = widget.existingTip!.description;
      // Note: For editing with existing image, you might want to show a preview
      // but keep _selectedImage null unless user selects a new image
    }
  }

  // Get current user ID from token
  Future<void> _initializeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token != null) {
        final decodedToken = JwtDecoder.decode(token);
        setState(() {
          currentUserId = decodedToken['sub']; // Get user ID from token
        });
      } else {
        setState(() {
          errorMessage = 'No authentication token found';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to get user information: ${e.toString()}';
      });
    }
  }

  Future<void> loadEnv() async {
    try {
      await dotenv.load(fileName: ".env");
      setState(() {
        baseUrl = dotenv.env['API_BASE_URL'] ?? baseUrl;
      });
    } catch (e) {
      print('Error loading .env file: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Now you can use currentUserId in your methods
  // For example, when creating or updating a tip:
  /*
  Future<void> _saveTip() async {
    if (_formKey.currentState!.validate() && currentUserId != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Use currentUserId when saving the tip
        // Example API call (adjust based on your LegalTipsService implementation)
        if (_isEditing) {
          // Update existing tip
          await _tipsService.updateTip(
            tipId: widget.existingTip!.id,
            userId: currentUserId!,
            title: _titleController.text,
            description: _descriptionController.text,
            image: _selectedImage,
          );
        } else {
          // Create new tip
          await _tipsService.createTip(
            userId: currentUserId!,
            title: _titleController.text,
            description: _descriptionController.text,
            image: _selectedImage,
          );
        }

        // Navigate back or show success message
        Navigator.pop(context, true);
      } catch (e) {
        setState(() {
          errorMessage = 'Failed to save tip: ${e.toString()}';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              // Handle case when there's no previous page
              // You can navigate to a specific page or show a message
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LegalAidHomepage(),
                ),
                (route) => false,
              ); // Replace with your home route
            }
          },
        ),

        title: Text(
          _isEditing ? 'Edit Legal Tip' : 'Add Legal Tip',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () => _showOptionsMenu(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              _buildLabel('Title'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Enter tip title...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  if (value.trim().length < 3) {
                    return 'Title must be at least 3 characters long';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Image Upload Section
              const Text(
                'Image',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.grey[300]!,
                      style: BorderStyle.solid,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildImageWidget(),
                ),
              ),

              if (_selectedImage != null ||
                  (_isEditing && widget.existingTip!.imageUrl != null)) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                      icon: const Icon(
                        Icons.delete,
                        size: 16,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Remove',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Description Field
              _buildLabel('Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Enter detailed description of the legal tip...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  if (value.trim().length < 10) {
                    return 'Description must be at least 10 characters long';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => _saveAsDraft(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save as Draft',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _publishTip(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4FC3F7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _isEditing ? 'Update Tip' : 'Publish Tip',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomLegalNavigationBar(currentIndex: 0),
    );
  }

  Widget _buildImageWidget() {
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    } else if (_isEditing && widget.existingTip!.imageUrl != null) {
      // Show existing image for editing
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          widget.existingTip!.imageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Icon(Icons.error, color: Colors.red));
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
        ),
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'Tap to upload image',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'PNG, JPG up to 10MB',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      );
    }
  }

  Widget _buildLabel(String text) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const Text(' *', style: TextStyle(color: Colors.red, fontSize: 16)),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        final fileSize = await file.length();

        // Check file size (10MB limit)
        if (fileSize > 10 * 1024 * 1024) {
          _showErrorSnackBar('Image too large. Maximum size is 10MB.');
          return;
        }

        setState(() {
          _selectedImage = file;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting image: $e');
    }
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.preview),
                title: const Text('Preview'),
                onTap: () {
                  Navigator.pop(context);
                  _previewTip();
                },
              ),
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('Help'),
                onTap: () {
                  Navigator.pop(context);
                  _showHelp();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _previewTip() {
    if (_titleController.text.trim().isEmpty &&
        _descriptionController.text.trim().isEmpty) {
      _showErrorSnackBar('Please add content to preview');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            _titleController.text.trim().isEmpty
                ? 'Preview'
                : _titleController.text.trim(),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedImage != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (_isEditing &&
                    widget.existingTip!.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.existingTip!.imageUrl!,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  _descriptionController.text.trim().isEmpty
                      ? 'No description added'
                      : _descriptionController.text.trim(),
                  style: TextStyle(
                    color: _descriptionController.text.trim().isEmpty
                        ? Colors.grey[500]
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Help'),
          content: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tips for creating a good legal tip:'),
              SizedBox(height: 8),
              Text('• Use a clear and descriptive title'),
              Text('• Provide detailed, accurate information'),
              Text('• Add relevant images when helpful'),
              Text('• Write in simple, understandable language'),
              Text('• Ensure content is legally accurate'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAsDraft() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      ApiResponse<LegalTip> response;

      if (_isEditing) {
        response = await _tipsService.updateLegalTip(
          tipId: widget.existingTip!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          imageFile: _selectedImage,
          removeImage:
              _selectedImage == null && widget.existingTip!.imageUrl != null,
          status: TipStatus.draft,
        );
      } else {
        response = await _tipsService.createLegalTip(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          imageFile: _selectedImage,
          status: TipStatus.draft,
          legalAidProviderId: widget.legalAidProviderId,
        );
      }

      if (response.success) {
        _showSuccessSnackBar(
          _isEditing
              ? 'Legal tip updated as draft successfully!'
              : 'Legal tip saved as draft successfully!',
        );
        Navigator.of(context).pop(response.data);
      } else {
        _showErrorSnackBar(response.error ?? 'Failed to save tip');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _publishTip() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      ApiResponse<LegalTip> response;

      if (_isEditing) {
        response = await _tipsService.updateLegalTip(
          tipId: widget.existingTip!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          imageFile: _selectedImage,
          removeImage:
              _selectedImage == null && widget.existingTip!.imageUrl != null,
          status: TipStatus.published,
        );
      } else {
        response = await _tipsService.createLegalTip(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          imageFile: _selectedImage,
          status: TipStatus.published,
          legalAidProviderId: widget.legalAidProviderId,
        );
      }

      if (response.success) {
        _showSuccessDialog();
      } else {
        _showErrorSnackBar(response.error ?? 'Failed to publish tip');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Success!',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
              ),
            ],
          ),
          content: Text(
            _isEditing
                ? 'Your legal tip has been updated and published successfully!'
                : 'Your legal tip has been published successfully!',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyTipsScreen()),
                ); // Go back to previous screen
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4FC3F7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
