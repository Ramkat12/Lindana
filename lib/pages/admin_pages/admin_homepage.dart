import 'package:flutter/material.dart';
import 'package:is_project_1/components/custom_admin.navbar.dart';
import 'package:is_project_1/pages/admin_pages/UploadEducationPage.dart';
import 'package:is_project_1/pages/admin_pages/Moderate_safety_tips_page.dart';
import 'package:is_project_1/pages/admin_pages/verify_providers.dart';
import 'package:is_project_1/pages/admin_pages/admin_analytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminHomepage extends StatefulWidget {
  const AdminHomepage({super.key});

  @override
  State<AdminHomepage> createState() => _AdminHomepageState();
}

class _AdminHomepageState extends State<AdminHomepage> {
  Map<String, dynamic> analytics = {};
  Map<String, dynamic> providerStats = {};
  bool isLoading = true;
  String baseUrl = 'https://d2d35afcbdcd.ngrok-free.app';

  @override
  void initState() {
    super.initState();
    loadEnv();
    _fetchDashboardData();
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

  Future<void> _fetchDashboardData() async {
    final String url = baseUrl;

    final analyticsRes = await http.get(Uri.parse('$url/analytics/overview'));
    final providerStatsRes = await http.get(Uri.parse('$url/provider_stats'));

    print("analyticsRes: ${analyticsRes.body}");
    print("providerStatsRes: ${providerStatsRes.body}");

    if (analyticsRes.statusCode == 200 && providerStatsRes.statusCode == 200) {
      setState(() {
        analytics = jsonDecode(analyticsRes.body);
        providerStats = jsonDecode(providerStatsRes.body);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load dashboard data")),
      );
    }
  }

  String _getTotalRevenue() {
    final revenue = analytics['Total Revenue'];
    if (revenue != null && revenue is List && revenue.isNotEmpty) {
      final totalSum = revenue
          .map((item) => (item['total'] ?? 0).toDouble())
          .fold(0.0, (a, b) => a + b);

      return '${totalSum.toStringAsFixed(1)}K';
    }
    return '0K';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4FABCB), // RGB(79, 171, 203)
        elevation: 0,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'ADMIN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // System Overview Section
            const Text(
              'System Overview',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Administrator Panel',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // Statistics Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '${analytics['users'] ?? '-'}',
                    'TOTAL USERS',
                    const Color(0xFF4FABCB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '${providerStats['total'] ?? '-'}',
                    'LEGAL PROVIDERS',
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '${providerStats['pending'] ?? '-'}',
                    'PENDING\nVERIFICATIONS',
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'KES ${analytics['total_revenue'] ?? '0'}',
                    'TOTAL REVENUE GENERATED',
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Admin Actions Section
            Row(
              children: [
                const Text(
                  'Admin Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Items
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VerifyProvidersPage(),
                  ),
                );
              },
              child: _buildActionItem(
                icon: Icons.check_circle,
                iconColor: Colors.red,
                title: 'Verify Providers',
                subtitle: 'Review pending applications',
                badge: '${providerStats['pending'] ?? '0'}',
                badgeColor: Colors.red,
              ),
            ),

            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ModerateSafetyTipsPage(),
                  ),
                );
              },
              child: _buildActionItem(
                icon: Icons.lightbulb,
                iconColor: Color(0xFF4FABCB),
                title: 'Manage Safety Tips',
                subtitle: 'Review and moderate content',
                badgeColor: Colors.red,
              ),
            ),

            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UploadEducationPage(),
                  ),
                );
              },
              child: _buildActionItem(
                icon: Icons.school,
                iconColor: Colors.blueAccent,
                title: 'Upload Educational Content',
                subtitle: 'Create new modules or articles',
                hasArrow: true,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminAnalyticsPage()),
                );
              },
              child: _buildActionItem(
                icon: Icons.bar_chart,
                iconColor: Colors.green,
                title: 'System Analytics',
                subtitle: 'Usage stats & performance',
                hasArrow: true,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomAdminNavigationBar(currentIndex: 0),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    bool hasArrow = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (hasArrow)
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        ],
      ),
    );
  }
}
