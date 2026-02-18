import 'package:flutter/material.dart';
import '../../models/legal_aid_requests.dart';
import 'package:is_project_1/pages/user_pages/legal_aid_provider.dart';
import 'package:is_project_1/pages/user_pages/legal_aid_request_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:is_project_1/components/custom_bootom_navbar.dart';

import '../../services/legal_request_service.dart'; // Updated import

class LegalRequestsScreen extends StatefulWidget {
  const LegalRequestsScreen({super.key});

  @override
  _LegalRequestsScreenState createState() => _LegalRequestsScreenState();
}

class _LegalRequestsScreenState extends State<LegalRequestsScreen> {
  List<LegalAidRequest> _requests = [];
  Map<String, LegalAidProvider> _providers = {}; // Cache for providers
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId != null) {
        // Initialize the service first
        await LegalRequestService.initialize();

        // Fetch requests with null safety
        final requests = await LegalRequestService.fetchLegalAidRequests(
          userId,
        );

        // Ensure requests is not null
        final safeRequests = requests ?? <LegalAidRequest>[];

        // Fetch provider details for each unique provider ID
        Set<String> providerIds = safeRequests
            .map((r) => r.legalAidProviderId)
            .where((id) => id.isNotEmpty) // Filter out empty IDs
            .toSet();

        Map<String, LegalAidProvider> providers = {};

        for (String providerId in providerIds) {
          try {
            final provider = await LegalRequestService.fetchProviderById(
              providerId,
            );
            providers[providerId] = provider;
          } catch (e) {
            print('Error fetching provider $providerId: $e');
            // Create a fallback provider if needed
            providers[providerId] = LegalAidProvider(
              id: providerId,
              fullName: 'Unknown Provider',
              email: '',
              phoneNumber: '',
              status: 'unknown',
              profileImage: null,
              pskNumber: '',
              expertiseAreas: [],
              createdAt: DateTime.now(),
              about: 'No information available',
            );
          }
        }

        setState(() {
          _requests = safeRequests;
          _providers = providers;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading requests: $e');
      setState(() {
        _error = 'Failed to load requests: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<LegalAidRequest> get _activeRequests {
    return _requests
        .where(
          (request) =>
              request.status == 'pending' || request.status == 'accepted',
        )
        .toList();
  }

  List<LegalAidRequest> get _pastRequests {
    return _requests
        .where(
          (request) =>
              request.status == 'completed' || request.status == 'declined',
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Match user homepage background
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        // Teal header like other user pages
        backgroundColor: const Color(0xFF4FABCB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Legal Requests',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              _showCreateRequestDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _buildBody(),
      // Ensure regular users always see their own navbar while
      // viewing their legal aid requests (Legal Aid tab = index 1).
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: Color(0xFF4FABCB)),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRequests,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined,
                size: 64, color: Color(0xFF4FABCB)),
            const SizedBox(height: 16),
            Text(
              'No legal requests found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showCreateRequestDialog,
              child: const Text('Create First Request'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Requests Section
            if (_activeRequests.isNotEmpty) ...[
              _buildSectionHeader('Active Requests', _activeRequests.length),
              ..._activeRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildActiveRequestCard(request),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Past Requests Section
            if (_pastRequests.isNotEmpty) ...[
              _buildSectionHeader('Past Requests', _pastRequests.length),
              ..._pastRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildPastRequestCard(request),
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRequestCard(LegalAidRequest request) {
    final provider = _providers[request.legalAidProviderId];
    final providerName = provider?.fullName ?? 'Unknown Provider';
    final status = _formatStatus(request.status);
    final statusColor = _getStatusColor(request.status);
    final timeAgo = _getTimeAgo(request.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue[100],
                backgroundImage: provider?.profileImage != null
                    ? NetworkImage(provider!.profileImage!)
                    : null,
                child: provider?.profileImage == null
                    ? Text(
                        providerName.isNotEmpty
                            ? providerName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'To: $providerName',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                timeAgo,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const Spacer(),
              if (request.status == 'accepted') ...[
                _buildActionButton(
                  'View',
                  Icons.visibility,
                  Colors.blue[600]!,
                  () => _viewDetails(request),
                ),
              ] else ...[
                const SizedBox(width: 8),
                _buildActionButton(
                  'View',
                  Icons.visibility,
                  Colors.grey[600]!,
                  () => _viewDetails(request),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPastRequestCard(LegalAidRequest request) {
    final provider = _providers[request.legalAidProviderId];
    final providerName = provider?.fullName ?? 'Unknown Provider';
    final status = _formatStatus(request.status);
    final statusColor = _getStatusColor(request.status);
    final timeAgo = _getTimeAgo(request.createdAt);
    final hasWarning = request.status == 'declined';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[200],
                backgroundImage: provider?.profileImage != null
                    ? NetworkImage(provider!.profileImage!)
                    : null,
                child: provider?.profileImage == null
                    ? Text(
                        providerName.isNotEmpty
                            ? providerName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'To: $providerName',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                timeAgo,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const Spacer(),

              if (hasWarning) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.warning, color: Colors.red[600], size: 16),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color == Colors.blue ? color : Colors.transparent,
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: color == Colors.blue ? Colors.white : color,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color == Colors.blue ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      case 'declined':
        return 'Declined';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Submitted 1 day ago';
      } else if (difference.inDays < 7) {
        return 'Submitted ${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return 'Submitted $weeks week${weeks > 1 ? 's' : ''} ago';
      } else {
        final months = (difference.inDays / 30).floor();
        return 'Submitted $months month${months > 1 ? 's' : ''} ago';
      }
    } else if (difference.inHours > 0) {
      return 'Submitted ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return 'Submitted ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Submitted just now';
    }
  }

  void _showCreateRequestDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Request'),
          content: const Text('Navigate to create a new legal aid request?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to LegalAidRequestForm
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LegalAidRequestForm(),
                  ),
                );
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _makeCall(String name, String? phoneNumber) {
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calling $name at $phoneNumber...')),
      );
      // Implement actual calling functionality using url_launcher
      launch('tel:$phoneNumber');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone number not available for $name')),
      );
    }
  }

  void _viewDetails(LegalAidRequest request) {
    final provider = _providers[request.legalAidProviderId];
    if (provider != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              LegalAidDetailsPage(request: request, provider: provider),
        ),
      );
    }

    void rateRequest(LegalAidRequest request, String providerName) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Rate Request - $providerName'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How would you rate this legal assistance?'),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 32),
                    Icon(Icons.star, color: Colors.amber, size: 32),
                    Icon(Icons.star, color: Colors.amber, size: 32),
                    Icon(Icons.star, color: Colors.amber, size: 32),
                    Icon(Icons.star_border, color: Colors.amber, size: 32),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you for your rating!')),
                  );
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    }
  }
}
