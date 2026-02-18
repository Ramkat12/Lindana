import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:is_project_1/components/custom_admin.navbar.dart';
import 'package:is_project_1/components/custom_bootom_navbar.dart';
import 'package:is_project_1/components/custom_legal_navbar.dart';
import 'package:is_project_1/models/profile_response.dart';
import 'package:is_project_1/pages/login_page.dart';
import 'package:is_project_1/pages/user_pages/user_analytics.dart';
import 'package:is_project_1/services/api_service.dart'; // Import your API service
import 'package:is_project_1/pages/user_pages/voice_activation_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  ProfileResponse? profile;
  List<EmergencyContact> emergencyContacts = [];
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

      List<EmergencyContact> contacts = [];
      // Only load emergency contacts for role_id == 5
      if (profileData.roleId == 5) {
        try {
          contacts = await ApiService.getEmergencyContacts();
        } catch (e) {
          // Emergency contacts are optional, don't fail the whole page
          print('Failed to load emergency contacts: $e');
        }
      }

      setState(() {
        profile = profileData;
        emergencyContacts = contacts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Closes the dialog
                try {
                  await ApiService.logout();

                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => LoginPage()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  String _getMemberSinceText() {
    // You can implement member since logic here
    // For now, using a placeholder
    return profile?.createdat != null
        ? 'Member since ${profile!.createdat!.toLocal().toString().split(' ')[0]}'
        : 'Member since Unknown';
  }

  String _getProfileImageUrl() {
    if (profile?.profileImage != null && profile!.profileImage!.isNotEmpty) {
      // If it's a relative path, prepend the base URL
      if (profile!.profileImage!.startsWith('/uploads')) {
        return '${ApiService.baseUrl}${profile!.profileImage}';
      }
      return profile!.profileImage!;
    }
    // Default profile image
    return 'https://images.unsplash.com/photo-1494790108755-2616b612b786?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=687&q=80';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,

        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.black87,
                ),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading profile',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadProfileData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Profile Header Section
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Profile Picture
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              (profile?.profileImage != null &&
                                  profile!.profileImage!.isNotEmpty)
                              ? MemoryImage(
                                  base64Decode(profile!.profileImage!),
                                )
                              : null,
                          backgroundColor: Colors.blue[100],
                          child:
                              profile?.profileImage == null ||
                                  profile!.profileImage!.isEmpty
                              ? Icon(
                                  Icons.person,
                                  color: Colors.blue[600],
                                  size: 50,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Name and Title
                      // Name and Title
                      Text(
                        profile?.name ?? 'Unknown User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getMemberSinceText(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      if (profile?.userType == 'legal_aid') ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Legal Aid Provider',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                // Content Section
                Expanded(
                  child: Container(
                    color: Colors.grey[50],
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Personal Information Section
                          _buildSectionHeader('Personal Information'),
                          const SizedBox(height: 16),
                          _buildInfoCard([
                            _buildInfoItem(
                              Icons.person_outline,
                              'Full Name',
                              profile?.name ?? 'N/A',
                              Colors.blue,
                            ),
                            if (profile?.phoneNumber != null)
                              _buildInfoItem(
                                Icons.phone_outlined,
                                'Phone Number',
                                profile!.phoneNumber!,
                                Colors.green,
                              ),
                            _buildInfoItem(
                              Icons.email_outlined,
                              'Email Address',
                              profile?.email ?? 'N/A',
                              Colors.orange,
                            ),
                            if (profile?.userType == 'legal_aid' &&
                                profile?.expertiseAreas.isNotEmpty == true)
                              _buildInfoItem(
                                Icons.gavel_outlined,
                                'Expertise Areas', // Changed to plural
                                profile!
                                    .expertiseAreasString, // Use the helper method
                                Colors.purple,
                              ),
                          ]),

                          // Emergency Contacts Section (only for role_id == 5)
                          if (profile?.roleId == 5) ...[
                            const SizedBox(height: 30),
                            _buildSectionHeader('Emergency Contacts'),
                            const SizedBox(height: 16),
                            if (emergencyContacts.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.contact_phone_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No emergency contacts added',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...emergencyContacts.map(
                                (contact) => _buildEmergencyContact(contact),
                              ),
                          ],

                          const SizedBox(height: 40),

                          // Action Buttons
                          _buildActionButton(
                            'Edit Profile',
                            Colors.blue,
                            Icons.edit,
                            () {
                              // Navigate to edit profile page
                              Navigator.pushNamed(
                                context,
                                '/edit-profile',
                              ).then(
                                (_) => _loadProfileData(),
                              ); // Refresh on return
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            'Voice Activation Settings',
                            Colors.teal,
                            Icons.mic,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const VoiceActivationPage(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                          _buildActionButton(
                            'My Analytics',
                            Colors.blue,
                            Icons.edit,
                            () {
                              // Navigate to edit profile page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const UserAnalytics(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionButton(
                            'Logout',
                            Colors.red,
                            Icons.logout,
                            _handleLogout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContact(EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: Text(
            contact.contactName.isNotEmpty
                ? contact.contactName[0].toUpperCase()
                : 'C',
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          contact.contactName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contact.contactNumber,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            if (contact.emailContact != null &&
                contact.emailContact!.isNotEmpty)
              Text(
                contact.emailContact!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.phone, color: Colors.green, size: 20),
        ),
        onTap: () {
          // Handle phone call - you can implement url_launcher here
          // launch('tel:${contact.contactNumber}');
        },
      ),
    );
  }

  // Method to build the appropriate navigation bar based on role
  Widget _buildBottomNavigationBar() {
    switch (profile?.roleId) {
      case 4: // Admin role
        return const CustomAdminNavigationBar(currentIndex: 3);
      case 5: // Regular user/client role
        return const CustomBottomNavigationBar(currentIndex: 3);
      case 6: // Legal aid provider role
        return const CustomLegalNavigationBar(currentIndex: 3);
      default: // Fallback for any other roles
        return const CustomBottomNavigationBar(currentIndex: 3);
    }
  }

  Widget _buildActionButton(
    String title,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: MaterialButton(
        onPressed: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
