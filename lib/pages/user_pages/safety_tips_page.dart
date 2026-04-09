import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:is_project_1/services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ── Category metadata ─────────────────────────────────────────────────────────
const _categories = [
  'All',
  'Personal Safety',
  'Public Transport',
  'At Home',
  'Street Safety',
  'Travel Safety',
  'Community Warnings',
];

const _categoryIcons = {
  'All': Icons.grid_view_rounded,
  'Personal Safety': Icons.shield_rounded,
  'Public Transport': Icons.directions_bus_rounded,
  'At Home': Icons.home_rounded,
  'Street Safety': Icons.streetview_rounded,
  'Travel Safety': Icons.luggage_rounded,
  'Community Warnings': Icons.campaign_rounded,
};

const _categoryColors = {
  'All': Color(0xFF4FABCB),
  'Personal Safety': Color(0xFF7B61FF),
  'Public Transport': Color(0xFFFF6B6B),
  'At Home': Color(0xFF059669),
  'Street Safety': Color(0xFFF59E0B),
  'Travel Safety': Color(0xFF0EA5E9),
  'Community Warnings': Color(0xFFEF4444),
};

// ── Widget ────────────────────────────────────────────────────────────────────
class SafetyTipsPage extends StatefulWidget {
  final bool showUploadDialog;
  const SafetyTipsPage({super.key, this.showUploadDialog = false});

  @override
  State<SafetyTipsPage> createState() => _SafetyTipsPageState();
}

class _SafetyTipsPageState extends State<SafetyTipsPage>
    with SingleTickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> safetyTips = [];
  List<Map<String, dynamic>> educationalContent = [];
  List<dynamic> purchasedContentIds = [];
  String selectedCategory = 'All';
  String? userId;
  String baseUrl = 'https://d2d35afcbdcd.ngrok-free.app';
  bool _tipsLoading = true;
  bool _eduLoading = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    _init();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadEnv();
    await _decodeUserId(); // fast — just reads SharedPreferences
    // All 3 fetches fire in parallel — max wait = slowest single request
    await Future.wait([
      _fetchSafetyTips(),
      _fetchEducationalContent(),
      _fetchPurchases(),
    ]);
    if (widget.showUploadDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAddTipDialog());
    }
  }

  Future<void> _loadEnv() async {
    try {
      await dotenv.load(fileName: '.env');
      setState(() => baseUrl = dotenv.env['API_BASE_URL'] ?? baseUrl);
    } catch (_) {}
  }

  Future<void> _decodeUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;
    try {
      final payload = token.split('.')[1];
      final decoded =
          utf8.decode(base64Url.decode(base64Url.normalize(payload)));
      setState(() => userId = json.decode(decoded)['sub']?.toString());
    } catch (_) {}
  }

  // ── Data fetches — all cached ─────────────────────────────────────────────
  Future<void> _fetchSafetyTips() async {
    const key = 'safety_tips';
    final cached = await CacheService.getList(key);
    if (cached != null && mounted) {
      setState(() {
        safetyTips = cached.map((e) => Map<String, dynamic>.from(e)).toList();
        _tipsLoading = false;
      });
    }
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/get_tips'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        await CacheService.setList(key, data, const Duration(minutes: 10));
        if (mounted) {
          setState(() {
            safetyTips =
                data.map((e) => Map<String, dynamic>.from(e)).toList();
            _tipsLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _tipsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _tipsLoading = false);
    }
  }

  Future<void> _fetchEducationalContent() async {
    const key = 'edu_content';
    final cached = await CacheService.getList(key);
    if (cached != null && mounted) {
      setState(() {
        educationalContent =
            cached.map((e) => Map<String, dynamic>.from(e)).toList();
        _eduLoading = false;
      });
    }
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/get_educational_content'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        await CacheService.setList(key, data, const Duration(minutes: 15));
        if (mounted) {
          setState(() {
            educationalContent =
                data.map((e) => Map<String, dynamic>.from(e)).toList();
            _eduLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _eduLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _eduLoading = false);
    }
  }

  Future<void> _fetchPurchases() async {
    if (userId == null) return;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/user_purchases/$userId'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() => purchasedContentIds = List.from(data['purchased_ids']));
      }
    } catch (_) {}
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = safetyTips
        .where(
          (t) =>
              t['status'] != 'deleted' &&
              (selectedCategory == 'All' ||
                  t['category']?.toString() == selectedCategory),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── Hero App Bar ─────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF1A202C),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.maybePop(context),
              ),
              actions: [
                if (userId != null)
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                    onPressed: _showAddTipDialog,
                    tooltip: 'Submit a tip',
                  ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1A202C),
                        Color(0xFF3B82F6),
                        Color(0xFF4FABCB),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative circles
                      Positioned(
                        top: -30,
                        right: -30,
                        child: _circle(160, Colors.white.withOpacity(0.04)),
                      ),
                      Positioned(
                        bottom: -20,
                        left: -20,
                        child: _circle(120, const Color(0xFF4FABCB).withOpacity(0.1)),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3)),
                              ),
                              child: const Text(
                                'COMMUNITY SAFETY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Safety & Learning',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Community tips and paid resources to keep you safe',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
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

            // ── Educational Resources ─────────────────────────────────────────
            if (!_eduLoading && educationalContent.isNotEmpty)
              SliverToBoxAdapter(child: _eduSection()),

            // ── Category filters ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 0, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Community Safety Tips',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A202C),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shared by your community',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF64748B).withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(child: _categoryChips()),

            // ── Tips grid / shimmer ───────────────────────────────────────────
            if (_tipsLoading)
              SliverToBoxAdapter(child: _shimmerGrid())
            else if (filtered.isEmpty)
              SliverToBoxAdapter(child: _emptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _tipCard(filtered[i]),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Educational section ───────────────────────────────────────────────────
  Widget _eduSection() => Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Educational Resources',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A202C),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B61FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'PREMIUM',
                      style: TextStyle(
                        color: Color(0xFF7B61FF),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Expert guides unlocked via purchase',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF64748B).withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20),
                itemCount: educationalContent.length,
                itemBuilder: (_, i) => _eduCard(educationalContent[i]),
              ),
            ),
          ],
        ),
      );

  Widget _eduCard(Map<String, dynamic> content) {
    final isUnlocked = purchasedContentIds.contains(content['id']);
    return GestureDetector(
      onTap: () async {
        if (isUnlocked) {
          _showContentDetail(content);
        } else {
          final pay = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Unlock Content'),
              content: Text(
                  'This item costs KES ${content['price']}. Would you like to proceed?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4FABCB)),
                  child: const Text('Buy'),
                ),
              ],
            ),
          );
          if (pay == true) _startPaymentFlow(content);
        }
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isUnlocked
                ? [const Color(0xFF059669), const Color(0xFF34D399)]
                : [const Color(0xFF7B61FF), const Color(0xFFA78BFA)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (isUnlocked
                      ? const Color(0xFF059669)
                      : const Color(0xFF7B61FF))
                  .withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: _circle(100, Colors.white.withOpacity(0.07)),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isUnlocked
                          ? Icons.lock_open_rounded
                          : Icons.lock_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    content['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  isUnlocked
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '✓ Unlocked — Tap to read',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'KES ${content['price']}',
                                style: const TextStyle(
                                  color: Color(0xFF7B61FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tap to unlock',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category chips ────────────────────────────────────────────────────────
  Widget _categoryChips() => SizedBox(
        height: 42,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _categories.length,
          itemBuilder: (_, i) {
            final cat = _categories[i];
            final isSelected = cat == selectedCategory;
            final color = _categoryColors[cat] ?? const Color(0xFF4FABCB);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: isSelected ? color : color.withOpacity(0.3)),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _categoryIcons[cat] ?? Icons.label_rounded,
                        size: 14,
                        color: isSelected ? Colors.white : color,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

  // ── Tip card ──────────────────────────────────────────────────────────────
  Widget _tipCard(Map<String, dynamic> tip) {
    final isFlagged = tip['status'] == 'false';
    final cat = tip['category']?.toString() ?? 'All';
    final color = _categoryColors[cat] ?? const Color(0xFF4FABCB);

    return GestureDetector(
      onTap: () => _showTipDetail(tip),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFlagged
                ? Colors.red.withOpacity(0.4)
                : color.withOpacity(0.15),
          ),
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
            // Color accent bar
            Container(
              width: 5,
              height: 80,
              decoration: BoxDecoration(
                color: isFlagged ? Colors.red : color,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isFlagged
                                ? Colors.red.withOpacity(0.1)
                                : color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFlagged
                                    ? Icons.flag_rounded
                                    : (_categoryIcons[cat] ??
                                        Icons.label_rounded),
                                size: 10,
                                color: isFlagged ? Colors.red : color,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isFlagged ? 'FLAGGED' : cat.toUpperCase(),
                                style: TextStyle(
                                  color: isFlagged ? Colors.red : color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tip['title'] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isFlagged
                            ? Colors.red.shade800
                            : const Color(0xFF1A202C),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isFlagged) ...[
                      const SizedBox(height: 4),
                      Text(
                        '⚠️ Flagged as false by moderators',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty / shimmer states ────────────────────────────────────────────────
  Widget _emptyState() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 56, color: const Color(0xFF94A3B8).withOpacity(0.6)),
              const SizedBox(height: 14),
              Text(
                selectedCategory == 'All'
                    ? 'No safety tips yet'
                    : 'No tips in "$selectedCategory"',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Be the first to share a tip with your community!',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _shimmerGrid() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: List.generate(
            4,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF94A3B8).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      );

  // ── Detail bottom sheet ───────────────────────────────────────────────────
  void _showTipDetail(Map<String, dynamic> tip) {
    final cat = tip['category']?.toString() ?? 'All';
    final color = _categoryColors[cat] ?? const Color(0xFF4FABCB);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF94A3B8).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Category badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_categoryIcons[cat] ?? Icons.label_rounded,
                              size: 13, color: color),
                          const SizedBox(width: 5),
                          Text(
                            cat,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A202C),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tip['content'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF334155),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContentDetail(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: SingleChildScrollView(
            controller: ctrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF94A3B8).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(item['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(item['content'] ?? '',
                    style: const TextStyle(
                        fontSize: 16, height: 1.6, color: Color(0xFF334155))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Add tip dialog ────────────────────────────────────────────────────────
  void _showAddTipDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String? selCat;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Share a Safety Tip',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Safety Tip',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _categories
                      .where((c) => c != 'All')
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDlg(() => selCat = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FABCB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: selCat == null
                  ? null
                  : () async {
                      await _uploadTip(
                          titleCtrl.text, contentCtrl.text, selCat!);
                      Navigator.pop(ctx);
                    },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadTip(
      String title, String content, String category) async {
    if (userId == null) return;
    final res = await http.post(
      Uri.parse('$baseUrl/upload_tip'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'content': content,
        'category': category,
        'submitted_by': userId,
        'submitted_by_role': 'user',
        'status': 'pending',
      }),
    );
    if (res.statusCode == 200) {
      await CacheService.remove('safety_tips'); // invalidate cache
      _fetchSafetyTips();
    }
  }

  // ── Payment flow ──────────────────────────────────────────────────────────
  Future<void> _startPaymentFlow(Map<String, dynamic> content) async {
    if (userId == null) return;
    final res = await http.post(
      Uri.parse('$baseUrl/create-order'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'content_id': content['id'],
        'content_title': content['title'],
        'amount': content['price'].toString(),
        'currency': 'USD',
      }),
    );
    if (res.statusCode != 200) return;
    final data = jsonDecode(res.body);
    final orderId = data['order_id'];
    final approvalUrl = data['approval_url'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Complete Payment')),
          body: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..loadRequest(Uri.parse(approvalUrl))
              ..setNavigationDelegate(
                NavigationDelegate(
                  onNavigationRequest: (nav) async {
                    if (nav.url.contains('payment-success')) {
                      await http.post(
                        Uri.parse('$baseUrl/capture-order/$orderId'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode(
                            {'user_id': userId, 'content_id': content['id']}),
                      );
                      _fetchPurchases();
                      Navigator.pop(context);
                      return NavigationDecision.prevent;
                    }
                    return NavigationDecision.navigate;
                  },
                ),
              ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
