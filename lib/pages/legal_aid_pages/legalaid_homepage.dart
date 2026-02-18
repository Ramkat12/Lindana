import 'package:flutter/material.dart';
import 'package:is_project_1/components/custom_legal_navbar.dart';
import 'package:is_project_1/pages/legal_aid_pages/legal_aid_clients_page.dart';
import 'package:is_project_1/pages/legal_aid_pages/legal_requests.dart';
import 'package:is_project_1/pages/legal_aid_pages/my_tips.dart';
import 'package:is_project_1/models/profile_response.dart';
import 'package:is_project_1/services/api_service.dart';

class LegalAidHomepage extends StatefulWidget {
  const LegalAidHomepage({super.key});

  @override
  State<LegalAidHomepage> createState() => _LegalAidHomepageState();
}

class _LegalAidHomepageState extends State<LegalAidHomepage> {
  ProfileResponse? profile;
  bool isLoading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Load profile data
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4FABCB), // RGB(79, 171, 203)
        elevation: 0,
        title: const Text(
          'Legal Aid provider',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Handle logout
            },
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
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
            // Welcome Message
            const Text(
              'Welcome back,',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              profile?.name.isNotEmpty == true
                  ? profile!.name[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Statistics Cards
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LegalRequestsScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(
                      12,
                    ), // Match your card's border radius
                    child: _buildStatCard('2', 'Pending Requests', Colors.red),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyTipsScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: _buildStatCard('3', 'Legal Tips', Colors.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Quick Actions Section
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Quick Action Items
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.visibility,
                    iconColor: const Color(0xFF4FABCB),
                    title: 'View Client\nMatches',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LegalAidClientsPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.add,
                    iconColor: const Color(0xFF4FABCB),
                    title: 'Add Legal tips',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LegalRequestsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.lightbulb_outline,
                    iconColor: const Color(0xFF4FABCB),
                    title: 'Add Safety Tips',
                    onTap: () {
                      // Handle add safety tips
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.edit,
                    iconColor: const Color(0xFF4FABCB),
                    title: 'My tips',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyTipsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Activity Items (placeholder)
          ],
        ),
      ),
      bottomNavigationBar: const CustomLegalNavigationBar(currentIndex: 0),
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
              fontSize: 28,
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

  Widget _buildQuickActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
