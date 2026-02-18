import 'package:flutter/material.dart';
import 'package:is_project_1/components/custom_admin.navbar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VerifyProvidersPage extends StatefulWidget {
  const VerifyProvidersPage({super.key});

  @override
  State<VerifyProvidersPage> createState() => _VerifyProvidersPageState();
}

class _VerifyProvidersPageState extends State<VerifyProvidersPage> {
  List<dynamic> pendingProviders = [];
  int totalCount = 0;
  int pendingCount = 0;
  //final String baseUrl = dotenv.env['BASE_URL']!;
  String baseUrl = 'https://d2d35afcbdcd.ngrok-free.app';
  @override
  void initState() {
    super.initState();
    loadEnv();
    _loadPendingProviders();
    _loadStatistics();
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

  Future<void> _loadPendingProviders() async {
    final response = await http.get(Uri.parse('$baseUrl/pending_providers'));
    if (response.statusCode == 200) {
      setState(() {
        pendingProviders = jsonDecode(response.body);
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to load providers")));
    }
  }

  Future<void> _loadStatistics() async {
    final response = await http.get(Uri.parse('$baseUrl/provider_stats'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        totalCount = data['total'];
        pendingCount = data['pending'];
      });
    }
  }

  Future<void> _verifyProvider(String providerId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/verify_provider/$providerId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Provider verified")));
      await _loadPendingProviders(); // Refresh list
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Verification failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF7BB3C7),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Verify Providers',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'U',
                style: TextStyle(
                  color: Color(0xFF7BB3C7),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Verification',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${pendingProviders.length} Pending',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Provider Cards
            Column(
              children: pendingProviders.map((provider) {
                final initials = provider['full_name']
                    .split(' ')
                    .map((s) => s[0])
                    .take(2)
                    .join();

                return _buildProviderCard(
                  name: provider['full_name'],
                  phone: provider['phone_number'],
                  expertise:
                      provider['legal_provider_expertise'] != null &&
                          provider['legal_provider_expertise'] is List &&
                          provider['legal_provider_expertise'].isNotEmpty
                      ? (provider['legal_provider_expertise'][0]['expertise_areas']?['name'] ??
                            'N/A')
                      : 'N/A',
                  lskNumber: provider['psk_number'],
                  avatarText: initials.toUpperCase(),
                  avatarColor: const Color(0xFF7BB3C7),
                  providerId: provider['id'],
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Statistics Section
            _buildStatisticsSection(),
          ],
        ),
      ),
      bottomNavigationBar: const CustomAdminNavigationBar(currentIndex: 1),
    );
  }

  Widget _buildProviderCard({
    required String name,
    required String phone,
    required String expertise,
    required String lskNumber,
    required String avatarText,
    required Color avatarColor,
    required providerId,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: avatarColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      avatarText,
                      style: TextStyle(
                        color: avatarColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              expertise,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              lskNumber,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _verifyProvider(providerId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Verify"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                title: 'Total Providers',
                value: '$totalCount',
                icon: Icons.people,
                color: const Color(0xFF4CAF50),
              ),
            ),
            Container(width: 1, height: 40, color: Colors.grey[300]),
            Expanded(
              child: _buildStatItem(
                title: 'Pending',
                value: '$pendingCount',
                icon: Icons.pending_actions,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
