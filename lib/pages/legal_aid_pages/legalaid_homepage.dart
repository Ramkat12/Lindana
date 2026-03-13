import 'package:flutter/material.dart';
import 'package:is_project_1/components/custom_legal_navbar.dart';
import 'package:is_project_1/pages/legal_aid_pages/legal_aid_clients_page.dart';
import 'package:is_project_1/pages/legal_aid_pages/legal_requests.dart';
import 'package:is_project_1/pages/legal_aid_pages/my_tips.dart';
import 'package:is_project_1/models/profile_response.dart';
import 'package:is_project_1/services/api_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DESIGN DIRECTION: Professional Legal Provider Dashboard
// ══════════════════════════════════════════════════════════════════════════════
// Tone: Sophisticated, organized, productive — like a modern law office dashboard.
// Navy/gold palette for authority and professionalism.
// Card-based layout with clear visual hierarchy.
// Smooth animations and refined shadows.

class LegalAidHomepage extends StatefulWidget {
  const LegalAidHomepage({super.key});

  @override
  State<LegalAidHomepage> createState() => _LegalAidHomepageState();
}

class _LegalAidHomepageState extends State<LegalAidHomepage>
    with SingleTickerProviderStateMixin {
  // ── Color Palette: Premium Legal Professional ─────────────────────────────
  static const _navyDeep = Color(0xFF1A2332);
  static const _navyMid = Color(0xFF2C3E50);
  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFE8D7A8);
  static const _cream = Color(0xFFFAF8F3);
  static const _slate = Color(0xFF64748B);
  static const _slateLight = Color(0xFF94A3B8);
  static const _white = Color(0xFFFFFFFF);
  static const _success = Color(0xFF059669);
  static const _warning = Color(0xFFF59E0B);
  static const _errorRed = Color(0xFFDC2626);
  static const _purple = Color(0xFF8B5CF6);

  ProfileResponse? profile;
  bool isLoading = true;
  String? error;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadProfileData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
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
      backgroundColor: _cream,
      body: CustomScrollView(
        slivers: [
          // ── Hero Header with Gradient ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: _navyDeep,
            elevation: 0,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12, top: 8),
                child: TextButton.icon(
                  onPressed: () {
                    // Handle logout
                  },
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: _gold,
                    size: 18,
                  ),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    backgroundColor: _gold.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1A2332),
                        Color(0xFF2C3E50),
                        Color(0xFF34495E),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative accent bars
                      Positioned(
                        top: 80,
                        right: -30,
                        child: Container(
                          width: 140,
                          height: 3,
                          decoration: BoxDecoration(
                            color: _gold.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 110,
                        left: -40,
                        child: Container(
                          width: 120,
                          height: 2,
                          decoration: BoxDecoration(
                            color: _goldLight.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Welcome back label
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: _white.withOpacity(0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Provider name — serif for authority
                            Text(
                              profile?.name ?? 'Provider',
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                color: _white,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Role badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _gold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _gold.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.workspace_premium,
                                    color: _gold,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'LEGAL AID PROVIDER',
                                    style: TextStyle(
                                      color: _goldLight,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body Content ──────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: _navyMid),
                    ),
                  )
                else if (error != null)
                  _buildErrorState()
                else ...[
                  // Statistics Cards
                  _buildStatsRow(),
                  const SizedBox(height: 28),

                  // Quick Actions Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _navyDeep,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _slate.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '4 actions',
                          style: TextStyle(
                            fontSize: 11,
                            color: _slate,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Action Grid
                  _buildQuickActionsGrid(),
                ],
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomLegalNavigationBar(currentIndex: 0),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // STATISTICS CARDS — Show key metrics at a glance
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildStatsRow() => Row(
    children: [
      Expanded(
        child: _statCard(
          value: '2',
          label: 'Pending Requests',
          color: _warning,
          icon: Icons.pending_actions_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LegalRequestsScreen()),
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: _statCard(
          value: '3',
          label: 'Legal Tips',
          color: _success,
          icon: Icons.lightbulb_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyTipsScreen()),
          ),
        ),
      ),
    ],
  );

  Widget _statCard({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Icon(Icons.arrow_forward_ios, color: _slateLight, size: 14),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _slate,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // QUICK ACTIONS GRID — 2×2 grid of action cards
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildQuickActionsGrid() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _actionCard(
              icon: Icons.people_rounded,
              title: 'View Client\nMatches',
              gradient: [_navyMid, _navyDeep],
              accentColor: _gold,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegalAidClientsPage()),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _actionCard(
              icon: Icons.add_circle_rounded,
              title: 'Add Legal\nTips',
              gradient: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              accentColor: Color(0xFFC4B5FD),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegalRequestsScreen()),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _actionCard(
              icon: Icons.security_rounded,
              title: 'Add Safety\nTips',
              gradient: [Color(0xFF059669), Color(0xFF047857)],
              accentColor: Color(0xFF6EE7B7),
              onTap: () {
                // Handle add safety tips
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _actionCard(
              icon: Icons.article_rounded,
              title: 'My Tips',
              gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
              accentColor: Color(0xFFFCD34D),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyTipsScreen()),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _actionCard({
    required IconData icon,
    required String title,
    required List<Color> gradient,
    required Color accentColor,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 130,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative accent line
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: _white, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(Icons.arrow_forward, color: accentColor, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // ERROR STATE
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildErrorState() => Container(
    margin: const EdgeInsets.symmetric(vertical: 40),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _errorRed.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _errorRed.withOpacity(0.2)),
    ),
    child: Column(
      children: [
        Icon(Icons.error_outline, color: _errorRed, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Unable to load profile',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _navyDeep,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          error ?? 'Unknown error',
          style: TextStyle(fontSize: 13, color: _slate),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _loadProfileData,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _navyDeep,
            foregroundColor: _white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    ),
  );
}
