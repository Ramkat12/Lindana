import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:is_project_1/components/custom_bootom_navbar.dart';
import 'package:is_project_1/models/legal_tips_models.dart' as tips;
import 'package:is_project_1/pages/user_pages/legal_aid_tip_detail';
import 'package:is_project_1/pages/user_pages/legal_requests.dart';
import 'package:is_project_1/pages/user_pages/legal_aid_request_form.dart';
import 'package:is_project_1/pages/user_pages/user_homepage.dart';
import 'package:is_project_1/services/legal_tips_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/legal_aid_requests.dart';
import '../../services/legal_aid_service.dart';
import 'legal_aid_provider_detail.dart';
import 'dart:convert';
import 'dart:typed_data';

// ══════════════════════════════════════════════════════════════════════════════
// DESIGN DIRECTION: Modern Legal Hub
// Teal/Purple palette for professionalism + approachability
// ══════════════════════════════════════════════════════════════════════════════

class UserLegalaid extends StatefulWidget {
  const UserLegalaid({super.key});

  @override
  State<UserLegalaid> createState() => _UserLegalaidState();
}

class _UserLegalaidState extends State<UserLegalaid>
    with SingleTickerProviderStateMixin {
  // ── Brand Colours ─────────────────────────────────────────────────────────
  static const _teal = Color(0xFF4FABCB);
  static const _tealLight = Color(0xFF7EC8E3);
  static const _purple = Color(0xFF7B61FF);
  static const _purpleLight = Color(0xFFA78BFA);
  static const _lilac = Color(0xFFF5F3FF);
  static const _dark = Color(0xFF1A202C);
  static const _slate = Color(0xFF64748B);
  static const _slateLight = Color(0xFF94A3B8);
  static const _white = Color(0xFFFFFFFF);
  static const _success = Color(0xFF059669);
  static const _errorRed = Color(0xFFDC2626);

  List<LegalAidProvider> _providers = [];
  bool _isLoading = true;
  String? _error;
  bool _isLoadingTips = true;
  List<tips.LegalTip> _publishedTips = [];
  String? _tipsError;
  final LegalTipsService _legalTipsService = LegalTipsService();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadLegalAidProviders();
    _fetchPublishedTips();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchPublishedTips() async {
    setState(() {
      _isLoadingTips = true;
      _tipsError = null;
    });
    try {
      final response = await _legalTipsService.getRecentPublishedTips(limit: 3);
      if (response.success && response.data != null) {
        setState(() {
          _publishedTips = response.data!;
          _isLoadingTips = false;
        });
      } else {
        setState(() {
          _tipsError = response.error ?? 'Failed to fetch tips';
          _isLoadingTips = false;
        });
      }
    } catch (e) {
      setState(() {
        _tipsError = 'Network error: $e';
        _isLoadingTips = false;
      });
    }
  }

  Future<void> _loadLegalAidProviders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final providers = await LegalAidService.getLegalAidProviders();
      setState(() {
        _providers = providers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lilac,
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar — Teal/Purple gradient ──────────────────────────────
          SliverAppBar(
            expandedHeight: 190,
            floating: false,
            pinned: true,
            backgroundColor: _dark,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: _white,
                size: 18,
              ),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const UserHomepage()),
                    (_) => false,
                  );
                }
              },
            ),
            actions: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: _white,
                      size: 22,
                    ),
                    onPressed: () {},
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _errorRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
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
                        Color(0xFF1A202C),
                        Color(0xFF4FABCB),
                        Color(0xFF7B61FF),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // decorative circles
                      Positioned(
                        top: -40,
                        right: -40,
                        child: _decorCircle(180, _white.withOpacity(0.04)),
                      ),
                      Positioned(
                        bottom: -30,
                        left: -30,
                        child: _decorCircle(140, _teal.withOpacity(0.08)),
                      ),
                      Positioned(
                        top: 80,
                        right: 70,
                        child: _decorCircle(70, _purple.withOpacity(0.12)),
                      ),

                      // content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _teal.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _teal.withOpacity(0.4),
                                ),
                              ),
                              child: const Text(
                                'LEGAL SERVICES',
                                style: TextStyle(
                                  color: _white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Legal Aid',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                color: _white,
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Expert guidance when you need it most',
                              style: TextStyle(
                                color: _white.withOpacity(0.8),
                                fontSize: 14,
                                height: 1.4,
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

          // ── Body ─────────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick Actions
                _sectionLabel('Quick Actions'),
                const SizedBox(height: 14),
                _quickActions(),

                const SizedBox(height: 32),

                // Legal Aid Providers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionLabel('Our Legal Professionals'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'VERIFIED',
                        style: TextStyle(
                          color: _white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Trusted experts ready to help',
                  style: TextStyle(
                    fontSize: 13,
                    color: _slate.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
                _providersSection(),

                const SizedBox(height: 32),

                // Legal Tips
                _sectionLabel('Recent Legal Insights'),
                const SizedBox(height: 6),
                Text(
                  'Stay informed with expert advice',
                  style: TextStyle(
                    fontSize: 13,
                    color: _slate.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
                _legalTipsSection(),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // QUICK ACTIONS — Gradient cards with teal/purple
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _quickActions() => Row(
    children: [
      Expanded(
        child: _actionCard(
          icon: Icons.folder_outlined,
          label: 'Your Requests',
          description: 'View case history',
          gradient: [_teal, _tealLight],
          accentColor: _white,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LegalRequestsScreen()),
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: _actionCard(
          icon: Icons.gavel_rounded,
          label: 'Get a Lawyer',
          description: 'Request assistance',
          gradient: [_purple, _purpleLight],
          accentColor: _white,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LegalAidRequestForm()),
          ),
        ),
      ),
    ],
  );

  Widget _actionCard({
    required IconData icon,
    required String label,
    required String description,
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: _decorCircle(90, _white.withOpacity(0.08)),
          ),
          Positioned(
            right: 15,
            top: 15,
            child: _decorCircle(40, _white.withOpacity(0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const Spacer(),
                Text(
                  label,
                  style: const TextStyle(
                    color: _white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: _white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // LEGAL AID PROVIDERS — Cards with teal accent
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _providersSection() {
    if (_isLoading) return _shimmerList(3, height: 100);
    if (_error != null) return _errorState(_error!, _loadLegalAidProviders);
    if (_providers.isEmpty)
      return _emptyState(
        icon: Icons.people_outline,
        title: 'No providers available',
        subtitle: 'Check back soon for legal professionals',
      );
    return Column(children: _providers.map(_providerCard).toList());
  }

  Widget _providerCard(LegalAidProvider p) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalAidProviderDetail(provider: p)),
    ),
    child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slateLight.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with teal ring
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: p.status == 'active'
                        ? _teal
                        : _slateLight.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundImage: p.profileImage != null
                      ? NetworkImage(p.profileImage!)
                      : null,
                  backgroundColor: _teal.withOpacity(0.1),
                  child: p.profileImage == null
                      ? Icon(Icons.person, color: _teal, size: 28)
                      : null,
                ),
              ),
              if (p.status == 'active')
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _success,
                      shape: BoxShape.circle,
                      border: Border.all(color: _white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.allExpertiseAreas,
                  style: TextStyle(fontSize: 13, color: _slate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: p.status == 'active'
                        ? _success.withOpacity(0.1)
                        : _slateLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: p.status == 'active' ? _success : _slate,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: _slateLight, size: 14),
        ],
      ),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // LEGAL TIPS — Cards with purple accent
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _legalTipsSection() {
    if (_isLoadingTips) return _shimmerList(2, height: 110);
    if (_tipsError != null)
      return _errorState(_tipsError!, _fetchPublishedTips);
    if (_publishedTips.isEmpty)
      return _emptyState(
        icon: Icons.lightbulb_outline,
        title: 'No legal tips yet',
        subtitle: 'New insights coming soon',
      );
    return Column(children: _publishedTips.map(_tipCard).toList());
  }

  Widget _tipCard(tips.LegalTip tip) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalTipDetailPage(tip: tip)),
    ),
    child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _purple.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(16),
            ),
            child: _buildTipImage(tip),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _dark,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip.description,
                    style: TextStyle(fontSize: 12, color: _slate, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _purple.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person, size: 12, color: _purple),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          tip.legalAidProvider?.fullName ?? 'Legal Expert',
                          style: TextStyle(
                            fontSize: 11,
                            color: _slate,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeago.format(tip.publishedAt ?? tip.createdAt),
                        style: TextStyle(fontSize: 10, color: _slateLight),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(
              Icons.arrow_forward_ios,
              size: 13,
              color: _purple.withOpacity(0.5),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildTipImage(tips.LegalTip tip) => Container(
    width: 90,
    height: 110,
    decoration: BoxDecoration(
      color: _purple.withOpacity(0.05),
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
    ),
    child: _buildTipImageContent(tip),
  );

  Widget _buildTipImageContent(tips.LegalTip tip) {
    if (tip.imageUrl == null || tip.imageUrl!.isEmpty) return _tipPlaceholder();
    final imageUrl = tip.imageUrl!.trim();

    if (_isLocalFilePath(imageUrl)) {
      return CachedNetworkImage(
        imageUrl: _buildFullImageUrl(imageUrl),
        fit: BoxFit.cover,
        placeholder: (_, __) => _tipPlaceholder(),
        errorWidget: (_, __, ___) => _tipPlaceholder(),
      );
    }
    if (_isDataUri(imageUrl) || _isBase64(imageUrl)) {
      try {
        Uint8List bytes = base64Decode(_getBase64Data(imageUrl));
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _tipPlaceholder(),
        );
      } catch (_) {
        return _tipPlaceholder();
      }
    }
    if (_isValidUrl(imageUrl)) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => _tipPlaceholder(),
        errorWidget: (_, __, ___) => _tipPlaceholder(),
      );
    }
    return _tipPlaceholder();
  }

  Widget _tipPlaceholder() => Container(
    color: _purple.withOpacity(0.08),
    child: Icon(
      Icons.article_outlined,
      color: _purple.withOpacity(0.4),
      size: 28,
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════════
  // SHARED UI
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _sectionLabel(String t) => Text(
    t,
    style: const TextStyle(
      fontFamily: 'Georgia',
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: _dark,
      letterSpacing: -0.3,
    ),
  );

  Widget _shimmerList(int n, {double height = 80}) => Column(
    children: List.generate(
      n,
      (_) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: height,
        decoration: BoxDecoration(
          color: _slateLight.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );

  Widget _errorState(String msg, VoidCallback onRetry) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _errorRed.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _errorRed.withOpacity(0.2)),
    ),
    child: Column(
      children: [
        Icon(Icons.error_outline, color: _errorRed, size: 36),
        const SizedBox(height: 12),
        const Text(
          'Something went wrong',
          style: TextStyle(fontWeight: FontWeight.w600, color: _dark),
        ),
        const SizedBox(height: 4),
        Text(
          msg,
          style: TextStyle(fontSize: 12, color: _slate),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: _errorRed,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: _white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: _slate.withOpacity(0.04),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _slateLight.withOpacity(0.15)),
    ),
    child: Column(
      children: [
        Icon(icon, color: _slateLight, size: 42),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: _dark,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: _slate),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _decorCircle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  // ── Image helpers ────────────────────────────────────────────────────────────

  bool _isBase64(String str) {
    try {
      if (str.isEmpty) return false;
      String b64 = str.contains(',') ? str.split(',').last : str;
      if (b64.isEmpty || !RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(b64))
        return false;
      base64Decode(b64);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _getBase64Data(String str) =>
      str.contains(',') ? str.split(',').last : str;

  bool _isValidUrl(String url) {
    try {
      if (url.isEmpty) return false;
      Uri uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _isLocalFilePath(String path) =>
      path.startsWith('/uploads/') ||
      path.startsWith('uploads/') ||
      path.contains('/uploads/');

  String _buildFullImageUrl(String path) {
    const baseUrl = 'https://d2d35afcbdcd.ngrok-free.app';
    return path.startsWith('/') ? '$baseUrl$path' : '$baseUrl/$path';
  }

  bool _isDataUri(String str) =>
      str.startsWith('data:image/') && str.contains(';base64,');
}
