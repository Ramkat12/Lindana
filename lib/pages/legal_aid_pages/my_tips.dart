import 'package:flutter/material.dart';
import 'package:is_project_1/components/custom_legal_navbar.dart';
import 'package:is_project_1/models/legal_tips_models.dart';
import 'package:is_project_1/services/legal_tips_service.dart';

class MyTipsScreen extends StatefulWidget {
  const MyTipsScreen({super.key});

  @override
  _MyTipsScreenState createState() => _MyTipsScreenState();
}

class _MyTipsScreenState extends State<MyTipsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';

  final List<String> _filterOptions = ['All', 'Published', 'Draft', 'Archived'];

  // Database integration
  final LegalTipsService _legalTipsService = LegalTipsService();
  List<LegalTip> _tips = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTips();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _legalTipsService.getLegalTips(
        limit: 100, // Adjust as needed
      );

      if (response.success && response.data != null) {
        setState(() {
          _tips = response.data!;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Failed to load tips';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshTips() async {
    await _loadTips();
  }

  List<LegalTip> get _filteredTips {
    if (_selectedFilter == 'All') {
      return _tips;
    }

    TipStatus? statusFilter;
    switch (_selectedFilter) {
      case 'Published':
        statusFilter = TipStatus.published;
        break;
      case 'Draft':
        statusFilter = TipStatus.draft;
        break;
      case 'Archived':
        statusFilter = TipStatus.archived;
        break;
    }

    return _tips.where((tip) => tip.status == statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Tips',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.blue),
            onPressed: () => _navigateToAddTip(),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () => _showSearchDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _refreshTips,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Tips'),
            Tab(text: 'Statistics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTipsTab(), _buildStatisticsTab()],
      ),
      bottomNavigationBar: const CustomLegalNavigationBar(currentIndex: 0),
    );
  }

  Widget _buildTipsTab() {
    return Column(
      children: [
        // Filter Section
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Text(
                'Filter:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filterOptions.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      final count = filter == 'All'
                          ? _tips.length
                          : _tips
                                .where(
                                  (tip) =>
                                      _getStatusString(tip.status) == filter,
                                )
                                .length;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('$filter ($count)'),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                          selectedColor: Colors.blue[100],
                          checkmarkColor: Colors.blue,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tips List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildErrorState()
              : _filteredTips.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _refreshTips,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredTips.length,
                    itemBuilder: (context, index) {
                      return _buildTipCard(_filteredTips[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatisticsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    final publishedTips = _tips
        .where((tip) => tip.status == TipStatus.published)
        .toList();
    final draftTips = _tips
        .where((tip) => tip.status == TipStatus.draft)
        .toList();
    final archivedTips = _tips
        .where((tip) => tip.status == TipStatus.archived)
        .toList();

    return RefreshIndicator(
      onRefresh: _refreshTips,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Tips',
                    _tips.length.toString(),
                    Icons.article,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Published',
                    publishedTips.length.toString(),
                    Icons.publish,
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
                    'Draft',
                    draftTips.length.toString(),
                    Icons.edit,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Archived',
                    archivedTips.length.toString(),
                    Icons.archive,
                    Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Tips
            const Text(
              'Recent Tips',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            ...(_tips.take(5).map((tip) => _buildPerformanceTipCard(tip))),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Tips',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error occurred',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshTips,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTipCard(LegalTip tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            tip.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatusBadge(_getStatusString(tip.status)),
              const Spacer(),
              Text(
                _formatDate(tip.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(LegalTip tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Header with status and menu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildStatusBadge(_getStatusString(tip.status)),
                          if (tip.imageUrl != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.image,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tip.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tip.description,
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
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuAction(value, tip),
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(value: 'view', child: Text('View')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (tip.status == TipStatus.published)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Text('Archive'),
                      )
                    else if (tip.status == TipStatus.draft)
                      const PopupMenuItem(
                        value: 'publish',
                        child: Text('Publish'),
                      ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Duplicate'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats and date
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (tip.status == TipStatus.published) ...[
                  Icon(Icons.visibility, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Published',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ] else ...[
                  Icon(Icons.schedule, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    tip.status == TipStatus.draft
                        ? 'Saved as draft'
                        : 'Archived',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
                const Spacer(),
                if (tip.status != TipStatus.published) ...[
                  ElevatedButton(
                    onPressed: () => _editTip(tip),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      tip.status == TipStatus.draft
                          ? 'Continue Editing'
                          : 'Restore',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ] else ...[
                  Text(
                    _formatDate(tip.publishedAt ?? tip.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Published':
        color = Colors.green;
        break;
      case 'Draft':
        color = Colors.orange;
        break;
      case 'Archived':
        color = Colors.grey;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tips found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'Create your first legal tip to help others'
                : 'No tips found for the selected filter',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddTip,
            icon: const Icon(Icons.add),
            label: const Text('Create Tip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusString(TipStatus status) {
    switch (status) {
      case TipStatus.published:
        return 'Published';
      case TipStatus.draft:
        return 'Draft';
      case TipStatus.archived:
        return 'Archived';
      case TipStatus.deleted:
        return 'Deleted';
    }
  }

  void _handleMenuAction(String action, LegalTip tip) async {
    switch (action) {
      case 'view':
        _viewTip(tip);
        break;
      case 'edit':
        _editTip(tip);
        break;
      case 'archive':
        await _archiveTip(tip);
        break;
      case 'publish':
        await _publishTip(tip);
        break;
      case 'duplicate':
        _duplicateTip(tip);
        break;
      case 'delete':
        await _deleteTip(tip);
        break;
    }
  }

  void _viewTip(LegalTip tip) {
    // Navigate to tip detail view
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Viewing tip: ${tip.title}')));
  }

  void _editTip(LegalTip tip) {
    // Navigate to edit tip screen
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Editing tip: ${tip.title}')));
  }

  Future<void> _archiveTip(LegalTip tip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Archive Tip'),
          content: Text(
            'Are you sure you want to archive "${tip.title}"? It will no longer be visible to users.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final response = await _legalTipsService.updateTipStatus(
          tipId: tip.id,
          status: TipStatus.archived,
        );

        if (response.success) {
          await _refreshTips();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tip archived successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to archive tip: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error archiving tip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _publishTip(LegalTip tip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Publish Tip'),
          content: Text(
            'Are you sure you want to publish "${tip.title}"? It will become visible to all users.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Publish'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final response = await _legalTipsService.updateTipStatus(
          tipId: tip.id,
          status: TipStatus.published,
        );

        if (response.success) {
          await _refreshTips();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tip published successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to publish tip: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error publishing tip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _duplicateTip(LegalTip tip) {
    // Create duplicate tip logic
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Duplicating tip: ${tip.title}')));
  }

  Future<void> _deleteTip(LegalTip tip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Tip'),
          content: Text(
            'Are you sure you want to delete "${tip.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final response = await _legalTipsService.deleteLegalTip(tip.id);

        if (response.success) {
          await _refreshTips();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tip deleted successfully'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete tip: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting tip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToAddTip() {
    // Navigate to AddLegalTipScreen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to Add Legal Tip screen')),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Search Tips'),
          content: const TextField(
            decoration: InputDecoration(
              hintText: 'Enter search terms...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      return '${(difference / 7).floor()} weeks ago';
    } else {
      return '${(difference / 30).floor()} months ago';
    }
  }
}
