import 'package:flutter/material.dart';
import 'package:is_project_1/components/custom_legal_navbar.dart';
import 'package:is_project_1/services/legal_request_service.dart';
import 'package:is_project_1/models/legal_aid_requests.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LegalAidClientsPage extends StatefulWidget {
  const LegalAidClientsPage({super.key});

  @override
  State<LegalAidClientsPage> createState() => _LegalAidClientsPageState();
}

class _LegalAidClientsPageState extends State<LegalAidClientsPage> {
  List<LegalAidRequest> acceptedRequests = [];
  List<LegalAidRequest> recentMatches = [];
  bool isLoading = true;
  String? error;
  String? providerId;
  String? errorMessage;

  // You'll need to get the current provider ID from your authentication system
  // For now, I'll use a placeholder - replace with actual provider ID

  @override
  void initState() {
    super.initState();
    _loadClientData();
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token != null) {
        final decodedToken = JwtDecoder.decode(token);
        providerId = decodedToken['sub']; // Get user ID from token

        // Now load requests with the provider ID
        await _loadClientData();
      } else {
        setState(() {
          errorMessage = 'No authentication token found';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to get provider information: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  // Alternative method using the existing /processed endpoint
  Future<void> _loadClientData() async {
    if (providerId == null) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
      error = null;
    });

    try {
      print('DEBUG: Loading client data for provider: $providerId');

      // Fetch processed requests and filter for accepted ones
      final allProcessedRequests =
          await LegalRequestService.fetchProcessedRequestsForProvider(
            providerId!,
          );

      print('DEBUG: Fetched ${allProcessedRequests.length} processed requests');

      // Filter for only accepted requests
      final acceptedRequestsOnly = allProcessedRequests
          .where((request) => request.status == 'accepted')
          .toList();

      print(
        'DEBUG: Filtered to ${acceptedRequestsOnly.length} accepted requests',
      );

      // Sort by created date to get recent matches
      final sortedRequests = List<LegalAidRequest>.from(acceptedRequestsOnly)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        acceptedRequests = acceptedRequestsOnly;
        recentMatches = sortedRequests.take(5).toList(); // Last 5 matches
        isLoading = false;
      });

      print(
        'DEBUG: Successfully loaded ${acceptedRequests.length} accepted requests',
      );
    } catch (e) {
      print('DEBUG: Error loading client data: $e');
      setState(() {
        error = 'Failed to load client data: ${e.toString()}';
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF7BB3C7),
        elevation: 0,
        title: const Text(
          'Clients page',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadClientData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadClientData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Clients Section
                    _buildActiveClientsSection(),
                    const SizedBox(height: 24),
                    // Recent Matches Section
                    _buildRecentMatchesSection(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const CustomLegalNavigationBar(currentIndex: 1),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Failed to load client data',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            error ?? 'Unknown error',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadClientData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveClientsSection() {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Clients',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7BB3C7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${acceptedRequests.length} active',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7BB3C7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (acceptedRequests.isEmpty)
              _buildEmptyState('No active clients at the moment')
            else
              ...acceptedRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildClientCard(request),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientCard(LegalAidRequest request) {
    final user = request.user;
    final priority = _getPriorityFromRequest(request);
    final priorityColor = _getPriorityColor(priority);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user?.fullName ?? 'Unknown User',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: priorityColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (user?.phoneNumber != null)
            Text(
              user!.phoneNumber!,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          if (user?.email != null)
            Text(
              user!.email,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          const SizedBox(height: 8),
          Text(
            request.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            request.description,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Matched: ${_formatDate(request.createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.phone, size: 18),
                    onPressed: user?.phoneNumber != null
                        ? () => _callClient(user!.phoneNumber!)
                        : null,
                    color: const Color(0xFF7BB3C7),
                  ),
                  IconButton(
                    icon: const Icon(Icons.email, size: 18),
                    onPressed: user?.email != null
                        ? () => _emailClient(user!.email)
                        : null,
                    color: const Color(0xFF7BB3C7),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentMatchesSection() {
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
            const Text(
              'Recent Matches',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            if (recentMatches.isEmpty)
              _buildEmptyState('No recent matches')
            else
              ...recentMatches.map((request) => _buildRecentMatchItem(request)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMatchItem(LegalAidRequest request) {
    final user = request.user;
    final avatarColor = _getAvatarColor(request.id);
    final timeAgo = _getTimeAgo(request.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarColor.withOpacity(0.2),
            child: Text(
              user?.fullName.isNotEmpty == true
                  ? user!.fullName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: avatarColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? 'Unknown User',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getPriorityFromRequest(LegalAidRequest request) {
    // You can implement your own priority logic based on request data
    // For now, using a simple time-based priority
    final daysSinceCreated = DateTime.now()
        .difference(request.createdAt)
        .inDays;

    if (daysSinceCreated <= 1) return 'Urgent';
    if (daysSinceCreated <= 3) return 'High';
    if (daysSinceCreated <= 7) return 'Medium';
    return 'Low';
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Medium':
        return Colors.yellow[700]!;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getAvatarColor(String id) {
    final colors = [
      const Color(0xFF7BB3C7),
      const Color(0xFF9B59B6),
      const Color(0xFFE67E22),
      const Color(0xFF2ECC71),
      const Color(0xFFE74C3C),
      const Color(0xFF3498DB),
    ];
    return colors[id.hashCode % colors.length];
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hrs ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${(difference.inDays / 7).floor()} weeks ago';
    }
  }

  void _callClient(String phoneNumber) {
    // Implement phone call functionality
    // You can use url_launcher package: launch("tel:$phoneNumber")
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Calling $phoneNumber')));
  }

  void _emailClient(String email) {
    // Implement email functionality
    // You can use url_launcher package: launch("mailto:$email")
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Emailing $email')));
  }
}
