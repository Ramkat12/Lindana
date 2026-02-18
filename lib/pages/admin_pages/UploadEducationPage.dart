import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UploadEducationPage extends StatefulWidget {
  const UploadEducationPage({super.key});

  @override
  State<UploadEducationPage> createState() => _UploadEducationPageState();
}

class _UploadEducationPageState extends State<UploadEducationPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _priceController = TextEditingController();
  String baseUrl = 'https://d2d35afcbdcd.ngrok-free.app';
  @override
  void initState() {
    super.initState();
    loadEnv();
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

  final List<String> _categories = [
    'Personal Safety',
    'Travel Safety',
    'Street Safety',
    'Public Transport',
    'Community Warnings',
    'At Home',
  ];

  String? _selectedCategory;
  bool _isSubmitting = false;

  Future<void> _submitContent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await Supabase.instance.client.from('educational_content').insert({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category': _selectedCategory,
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'is_paid': true,
        'uploaded_by': 'admin@yourapp.com', // Replace as needed
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Educational content uploaded successfully!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Educational Content'),
        backgroundColor: const Color(0xFF4FABCB),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Create New Module',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 6,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter the content' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
                validator: (val) => val == null ? 'Select a category' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (KES)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter a price';
                  final parsed = double.tryParse(val);
                  if (parsed == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitContent,
                  icon: const Icon(Icons.upload),
                  label: Text(
                    _isSubmitting ? 'Uploading...' : 'Upload Content',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4FABCB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
