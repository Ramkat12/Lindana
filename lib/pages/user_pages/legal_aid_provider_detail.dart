import 'dart:convert';

import 'package:flutter/material.dart';
import '../../models/legal_aid_requests.dart';
import 'legal_aid_request_form.dart';

class LegalAidProviderDetail extends StatelessWidget {
  final LegalAidProvider provider;

  const LegalAidProviderDetail({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Match user homepage background
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4FABCB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Provider Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Profile Card
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
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Image
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: provider.profileImage != null
                        ? MemoryImage(base64Decode(provider.profileImage!))
                        : AssetImage('assets/images/default_profile.png')
                            as ImageProvider,
                    backgroundColor: const Color(0xFF4FABCB),
                    child: provider.profileImage == null
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 50)
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // Name
                  Text(
                    provider.fullName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: provider.status == 'active'
                          ? Colors.green[100]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      provider.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: provider.status == 'active'
                            ? Colors.green[800]
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Contact Information
            _buildInfoSection('Lawyer background', [
              // Provide an appropriate IconData
              Text(provider.about ?? 'Lawyer information not available'),
            ]),

            const SizedBox(height: 20),

            // Expertise Areas
            _buildInfoSection(
              'Areas of Expertise',
              provider.expertiseAreas.isNotEmpty
                  ? provider.expertiseAreas.map((area) {
                      return _buildExpertiseChip(area.name);
                    }).toList()
                  : [
                      const Text(
                        'No expertise areas available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
            ),

            const SizedBox(height: 32),

            // Request Services Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LegalAidRequestForm(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FABCB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Request Services',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[600], size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpertiseChip(String name) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4FABCB).withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4FABCB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4FABCB),
            ),
          ),
        ],
      ),
    );
  }
}
