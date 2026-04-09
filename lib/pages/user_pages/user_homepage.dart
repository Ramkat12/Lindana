import 'package:flutter/material.dart';
import 'package:is_project_1/components/custom_bootom_navbar.dart';
import 'package:is_project_1/models/profile_response.dart';
import 'package:is_project_1/pages/user_pages/map_page.dart';
import 'package:is_project_1/pages/user_pages/player.dart';
import 'package:is_project_1/pages/user_pages/user_legalaid.dart';
import 'package:is_project_1/pages/user_pages/videos.dart';
import 'package:is_project_1/pages/user_pages/voice_activation_page.dart';
import 'package:is_project_1/services/api_service.dart';
import 'package:is_project_1/services/background_voice_service.dart';
import 'package:is_project_1/services/cache_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:is_project_1/pages/user_pages/safety_tips_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

// ── Models ───────────────────────────────────────────────────────────────────

class PoliceStation {
  final String name;
  final double latitude, longitude;
  PoliceStation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
  factory PoliceStation.fromJson(Map<String, dynamic> j) => PoliceStation(
    name: j['name'],
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
  );
}

class DangerZone {
  final String name, description;
  final double latitude, longitude, radius;
  DangerZone({
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
  factory DangerZone.fromJson(Map<String, dynamic> j) => DangerZone(
    name: j['location_name'] ?? 'Unknown',
    description: j['description'] ?? '',
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    radius: (j['radius'] as num?)?.toDouble() ?? 500.0,
  );
}

class VideoInfo {
  final String url;
  final String? title;
  VideoInfo({required this.url, this.title});
}

class SafetyTip {
  final String title, content;
  SafetyTip({required this.title, required this.content});
  factory SafetyTip.fromJson(Map<String, dynamic> j) =>
      SafetyTip(title: j['title'] ?? 'Untitled', content: j['content'] ?? '');
}

class EducationalContent {
  final String title, content, id;
  final double price;
  final bool isPaid;
  EducationalContent({
    required this.id,
    required this.title,
    required this.content,
    required this.price,
    required this.isPaid,
  });
  factory EducationalContent.fromJson(Map<String, dynamic> j) {
    final raw = j['price'];
    return EducationalContent(
      id: j['id'],
      title: j['title'] ?? 'Untitled',
      content: j['content'] ?? '',
      price: raw != null ? double.tryParse(raw.toString()) ?? 0.0 : 0.0,
      isPaid: j['is_paid'] ?? true,
    );
  }
}

final _videoUrls = [
  'https://www.youtube.com/watch?v=eANy2M_Filw',
  'https://www.youtube.com/watch?v=7zhX02q-b5w',
  'https://www.youtube.com/watch?v=uI4ATOriCIw',
];

// Simple data holder for a quick-action chip
class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// ── Haversine Formula ─────────────────────────────────────────────────────────
// Returns distance in metres between two lat/lng points.
// Formula: a = sin²(Δlat/2) + cos(lat1)·cos(lat2)·sin²(Δlng/2)
//          c = 2·atan2(√a, √(1−a))
//          d = R·c  where R = 6 371 000 m
double _haversineMetres(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371000.0; // Earth's radius in metres
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _toRad(double deg) => deg * pi / 180.0;

// ── Page ─────────────────────────────────────────────────────────────────────

class UserHomepage extends StatefulWidget {
  const UserHomepage({super.key});
  @override
  State<UserHomepage> createState() => _UserHomepageState();
}

class _UserHomepageState extends State<UserHomepage>
    with SingleTickerProviderStateMixin {
  // colours
  static const _teal = Color(0xFF4FABCB);
  static const _lilac = Color(0xFFF5F3FF);
  static const _dark = Color(0xFF1A202C);
  static const _purple = Color(0xFF7B61FF);
  static const _green = Color(0xFF27AE60);
  static const _red = Color(0xFFE53E3E);
  static const _orange = Color(0xFFED8936);

  // state
  String baseUrl = 'https://0b1e-102-208-82-84.ngrok-free.app';
  ProfileResponse? profile;
  bool isLoading = true;
  List<SafetyTip> safetyTips = [];
  bool tipsLoading = true;
  List<EducationalContent> educationalItems = [];
  bool eduLoading = true;
  List<String> purchasedContentIds = [];
  List<VideoInfo> videoInfoList = [];
  bool videoLoading = true;
  List<PoliceStation> policeStations = [];
  bool policeLoading = true;
  List<DangerZone> dangerZones = [];
  bool dangerLoading = true;
  Position? _currentPos;

  // Map controller, markers & perimeter circles
  gmaps.GoogleMapController? _mapController;
  Set<gmaps.Marker> _mapMarkers = {};
  Set<gmaps.Circle> _mapCircles = {};
  bool _mapReady = false;

  // ── Voice activation state (shown on home page) ────────────────────────
  bool _voiceEnabled = false;
  String _wakePhrase = 'tuma msaada';
  bool _reminderDismissed = false;

  late AnimationController _heroCtrl;
  late Animation<double> _heroAnim;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroAnim = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroCtrl.forward();
    _initAll();
    _loadVoiceSettings();
    // Hook voice service so alerts fire even when on the home page.
    // Wake phrase → silent SMS alert (NOT panic dialog).
    BackgroundVoiceService.instance.onWakeWordDetected = _sendAlertFromVoice;
    BackgroundVoiceService.instance.startIfEnabled();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _mapController?.dispose();
    // Clear hook so MapPage can re-register when navigated to
    if (BackgroundVoiceService.instance.onWakeWordDetected == _sendAlertFromVoice) {
      BackgroundVoiceService.instance.onWakeWordDetected = null;
    }
    super.dispose();
  }

  // ── Load voice prefs — used for the reminder banner ─────────────────────
  Future<void> _loadVoiceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _voiceEnabled = prefs.getBool('voice_activation_enabled') ?? false;
      _wakePhrase = prefs.getString('voice_wake_word') ?? 'tuma msaada';
    });
  }

  // ── Voice alert callback (main isolate) ─────────────────────────────────
  // SMS is already sent by the background isolate — even when app is closed.
  // Shows a full popup dialog when the app is in the foreground.
  Future<void> _sendAlertFromVoice() async {
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      pageBuilder: (ctx, _, __) => _HomeVoiceAlertDialog(),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    );
  }


  Future<void> _initAll() async {
    await loadEnv();
    await _getLocation();
    await Future.wait([
      _loadProfile(),
      _fetchSafetyTips(),
      _fetchEducationalContent(),
      _loadVideoInfo(),
      _fetchPoliceStations(),
      _fetchDangerZones(),
    ]);
    final userId = await _getUserId();
    if (userId != null) _fetchPurchases(userId);
    // Build map markers after all data is loaded
    _rebuildMapMarkers();
  }

  Future<void> loadEnv() async {
    try {
      await dotenv.load(fileName: '.env');
      setState(() => baseUrl = dotenv.env['API_BASE_URL'] ?? baseUrl);
    } catch (_) {}
  }

  Future<void> _getLocation() async {
    try {
      bool svc = await Geolocator.isLocationServiceEnabled();
      if (!svc) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever)
        return;
      _currentPos = await Geolocator.getCurrentPosition();
      // Persist for background isolate
      await BackgroundVoiceService.savePositionForBackground(
        _currentPos!.latitude, _currentPos!.longitude,
      );
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      setState(() => isLoading = true);
      final p = await ApiService.getProfile();
      setState(() {
        profile = p;
        isLoading = false;
      });
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchSafetyTips() async {
    const key = 'safety_tips';
    // Show cached instantly
    final cached = await CacheService.getList(key);
    if (cached != null && mounted) {
      setState(() {
        safetyTips = cached.map((e) => SafetyTip.fromJson(e)).toList();
        tipsLoading = false;
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
            safetyTips = data.map((e) => SafetyTip.fromJson(e)).toList();
            tipsLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => tipsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => tipsLoading = false);
    }
  }

  Future<void> _fetchEducationalContent() async {
    const key = 'edu_content';
    final cached = await CacheService.getList(key);
    if (cached != null && mounted) {
      setState(() {
        educationalItems = cached.map((e) => EducationalContent.fromJson(e)).toList();
        eduLoading = false;
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
            educationalItems = data.map((e) => EducationalContent.fromJson(e)).toList();
            eduLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => eduLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => eduLoading = false);
    }
  }

  Future<void> _loadVideoInfo() async {
    setState(() => videoLoading = true);
    final futures = _videoUrls.map((url) async {
      final id = YoutubePlayer.convertUrlToId(url);
      if (id == null) return null;
      try {
        final res = await http.get(
          Uri.parse(
            'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$id&format=json',
          ),
        );
        final title = res.statusCode == 200
            ? jsonDecode(res.body)['title'] as String?
            : null;
        return VideoInfo(url: url, title: title ?? 'Educational Video');
      } catch (_) {
        return VideoInfo(url: url, title: 'Educational Video');
      }
    }).toList();
    final results = await Future.wait(futures);
    setState(() {
      videoInfoList = results.whereType<VideoInfo>().toList();
      videoLoading = false;
    });
  }

  Future<void> _fetchPoliceStations() async {
    const key = 'hp_nearby_police';
    final cached = await CacheService.getList(key);
    if (cached != null && mounted) {
      setState(() {
        policeStations = cached.map((e) => PoliceStation.fromJson(e)).toList();
        policeLoading = false;
      });
    }
    try {
      final lat = _currentPos?.latitude ?? -1.286389;
      final lng = _currentPos?.longitude ?? 36.817223;
      final res = await http
          .get(Uri.parse('$baseUrl/nearby-police?latitude=$lat&longitude=$lng&radius=5000'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['nearby_police'] as List;
        await CacheService.setList(key, data, const Duration(minutes: 5));
        if (mounted) {
          setState(() {
            policeStations = data.map((e) => PoliceStation.fromJson(e)).toList();
            policeLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => policeLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => policeLoading = false);
    }
  }

  Future<void> _fetchDangerZones() async {
    const key = 'hp_danger_zones';
    final cached = await CacheService.getList(key);
    if (cached != null && mounted) {
      setState(() {
        dangerZones = cached.map((e) => DangerZone.fromJson(e)).toList();
        dangerLoading = false;
      });
    }
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/danger-zones'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        await CacheService.setList(key, data, const Duration(minutes: 5));
        if (mounted) {
          setState(() {
            dangerZones = data.map((e) => DangerZone.fromJson(e)).toList();
            dangerLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => dangerLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => dangerLoading = false);
    }
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return null;
    try {
      final payload = token.split('.')[1];
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(payload)),
      );
      return json.decode(decoded)['sub']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchPurchases(String userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/user_purchases/$userId'));
      if (res.statusCode == 200)
        setState(
          () => purchasedContentIds = List<String>.from(
            jsonDecode(res.body)['purchased_ids'],
          ),
        );
    } catch (_) {}
  }

  // ── Haversine distance label ─────────────────────────────────────────────
  // Returns a human-readable string and the raw distance in metres.
  String _distanceLabel(double lat, double lng) {
    if (_currentPos == null) return '';
    final d = _haversineMetres(
      _currentPos!.latitude,
      _currentPos!.longitude,
      lat,
      lng,
    );
    return d < 1000
        ? '${d.toStringAsFixed(0)}m away'
        : '${(d / 1000).toStringAsFixed(1)}km away';
  }

  double _distanceMetres(double lat, double lng) {
    if (_currentPos == null) return double.infinity;
    return _haversineMetres(
      _currentPos!.latitude,
      _currentPos!.longitude,
      lat,
      lng,
    );
  }

  // ── Filtered lists: only items within 5 km ───────────────────────────────
  static const double _mapRadiusMetres = 5000.0; // 5 km

  List<PoliceStation> get _nearbyPolice =>
      _currentPos == null
            ? policeStations
            : policeStations
                  .where(
                    (p) =>
                        _distanceMetres(p.latitude, p.longitude) <=
                        _mapRadiusMetres,
                  )
                  .toList()
        ..sort(
          (a, b) => _distanceMetres(
            a.latitude,
            a.longitude,
          ).compareTo(_distanceMetres(b.latitude, b.longitude)),
        );

  List<DangerZone> get _nearbyDangerZones =>
      _currentPos == null
            ? dangerZones
            : dangerZones
                  .where(
                    (z) =>
                        _distanceMetres(z.latitude, z.longitude) <=
                        _mapRadiusMetres,
                  )
                  .toList()
        ..sort(
          (a, b) => _distanceMetres(
            a.latitude,
            a.longitude,
          ).compareTo(_distanceMetres(b.latitude, b.longitude)),
        );

  // ── Build Google Maps markers + 5km perimeter circle ────────────────────
  void _rebuildMapMarkers() {
    final Set<gmaps.Marker> markers = {};
    final Set<gmaps.Circle> circles = {};

    // 5 km perimeter circle centred on the user
    if (_currentPos != null) {
      circles.add(
        gmaps.Circle(
          circleId: const gmaps.CircleId('perimeter_5km'),
          center: gmaps.LatLng(_currentPos!.latitude, _currentPos!.longitude),
          radius: _mapRadiusMetres,
          strokeColor: const Color(0xFF4FABCB), // teal border
          strokeWidth: 2,
          fillColor: const Color(
            0xFF4FABCB,
          ).withOpacity(0.07), // very subtle teal fill
        ),
      );

      // ── Black pulsating user-location circle ──────────────────────────
      // Outer "pulse" ring — semi-transparent black
      circles.add(
        gmaps.Circle(
          circleId: const gmaps.CircleId('user_pulse'),
          center: gmaps.LatLng(_currentPos!.latitude, _currentPos!.longitude),
          radius: 120, // visual pulse ring
          strokeColor: Colors.black.withOpacity(0.25),
          strokeWidth: 2,
          fillColor: Colors.black.withOpacity(0.08),
        ),
      );
      // Inner solid black dot
      circles.add(
        gmaps.Circle(
          circleId: const gmaps.CircleId('user_dot'),
          center: gmaps.LatLng(_currentPos!.latitude, _currentPos!.longitude),
          radius: 40,
          strokeColor: Colors.black,
          strokeWidth: 3,
          fillColor: Colors.black.withOpacity(0.85),
        ),
      );
    }

    for (final p in _nearbyPolice) {
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('police_${p.name}'),
          position: gmaps.LatLng(p.latitude, p.longitude),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueAzure,
          ),
          infoWindow: gmaps.InfoWindow(
            title: p.name,
            snippet: _distanceLabel(p.latitude, p.longitude),
          ),
        ),
      );
    }

    for (final z in _nearbyDangerZones) {
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('danger_${z.name}'),
          position: gmaps.LatLng(z.latitude, z.longitude),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueRed,
          ),
          infoWindow: gmaps.InfoWindow(
            title: z.name,
            snippet:
                '${_distanceLabel(z.latitude, z.longitude)} · r=${z.radius.toStringAsFixed(0)}m',
          ),
        ),
      );
    }

    setState(() {
      _mapMarkers = markers;
      _mapCircles = circles;
    });

    // Animate camera to user location once map is ready
    if (_mapReady && _currentPos != null) {
      _mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(_currentPos!.latitude, _currentPos!.longitude),
          12.0,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final firstName = profile?.name?.split(' ').first ?? '';

    return Scaffold(
      backgroundColor: _lilac,
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: const Color(
              0xFF3A9ABF,
            ), // pinned bar colour matches teal
            flexibleSpace: FlexibleSpaceBar(
              background: FadeTransition(
                opacity: _heroAnim,
                child: Container(
                  decoration: const BoxDecoration(
                    // Light-teal gradient that matches the app's colour identity
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2E86AB), // deep sky blue
                        Color(0xFF4FABCB), // teal (brand primary)
                        Color(0xFF80CFEA), // light airy teal
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // decorative circles — lighter so they pop on the bright bg
                      Positioned(
                        top: -30,
                        right: -30,
                        child: _decorCircle(
                          160,
                          Colors.white.withOpacity(0.08),
                        ),
                      ),
                      Positioned(
                        bottom: -20,
                        left: -20,
                        child: _decorCircle(
                          120,
                          Colors.white.withOpacity(0.06),
                        ),
                      ),
                      Positioned(
                        top: 20,
                        right: 60,
                        child: _decorCircle(60, Colors.white.withOpacity(0.12)),
                      ),

                      // content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // ── App name ────────────────────────────────────
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.shield_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Lindana',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // ── Greeting ─────────────────────────────────────
                            Text(
                              greeting,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isLoading
                                  ? 'Welcome back 👋'
                                  : 'Hey, $firstName 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // ── Safety status pill ───────────────────────────
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: _green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_nearbyPolice.length} police nearby · ${_nearbyDangerZones.length} danger zones',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
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
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 4),
            ],
          ),

          // ── Body ──────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Wake phrase reminder banner (shown when voice enabled) ──
                if (_voiceEnabled && !_reminderDismissed)
                  _wakePhraseBanner(),
                if (_voiceEnabled && !_reminderDismissed)
                  const SizedBox(height: 16),

                // ── Quick Actions ────────────────────────────────────────────
                _label('Quick Actions'),
                const SizedBox(height: 14),
                _quickActions(),

                const SizedBox(height: 32),

                // ── PANIC banner ─────────────────────────────────────────────
                _panicBanner(),

                const SizedBox(height: 32),

                // ── Nearby Map ───────────────────────────────────────────────
                _rowHeader(
                  'Nearby Safety Map',
                  Icons.map_rounded,
                  _teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapPage()),
                  ),
                ),
                const SizedBox(height: 8),
                _mapLegend(),
                const SizedBox(height: 10),
                _nearbyMap(),

                const SizedBox(height: 32),

                // ── Nearby Police cards ──────────────────────────────────────
                _rowHeader(
                  'Nearby Police',
                  Icons.local_police_rounded,
                  _teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapPage()),
                  ),
                ),
                const SizedBox(height: 14),
                _policeSection(),

                const SizedBox(height: 32),

                // ── Danger Zones cards ───────────────────────────────────────
                _rowHeader(
                  'Danger Zones Near You',
                  Icons.warning_amber_rounded,
                  _red,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapPage()),
                  ),
                ),
                const SizedBox(height: 14),
                _dangerSection(),

                const SizedBox(height: 32),

                // ── Safety Tips ──────────────────────────────────────────────
                _rowHeader(
                  'Safety Tips',
                  Icons.shield_outlined,
                  _purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SafetyTipsPage()),
                  ),
                ),
                const SizedBox(height: 14),
                _safetyTipsSection(),

                const SizedBox(height: 32),

                // ── Videos ───────────────────────────────────────────────────
                _rowHeader(
                  'Educational Videos',
                  Icons.play_circle_outline_rounded,
                  _orange,
                  badge: 'TRENDING',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const videosClass()),
                  ),
                ),
                const SizedBox(height: 14),
                _videosSection(),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 0),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WAKE PHRASE REMINDER BANNER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _wakePhraseBanner() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VoiceActivationPage()),
        );
        // Refresh phrase after returning from settings
        _loadVoiceSettings();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E86AB), Color(0xFF4FABCB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4FABCB).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // mic icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),

            // text col
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🔔 Voice Alert Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                      children: [
                        const TextSpan(text: 'Say '),
                        TextSpan(
                          text: '"$_wakePhrase"',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const TextSpan(text: ' to send a silent alert'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // dismiss button
            GestureDetector(
              onTap: () => setState(() => _reminderDismissed = true),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NEARBY SAFETY MAP — embedded Google Map with Haversine-filtered markers
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _mapLegend() => Row(
    children: [
      _legendDot(gmaps.BitmapDescriptor.hueAzure, 'Police stations', _teal),
      const SizedBox(width: 16),
      _legendDot(gmaps.BitmapDescriptor.hueRed, 'Danger zones', _red),
      const Spacer(),
      Text(
        'within 5 km',
        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
      ),
    ],
  );

  Widget _legendDot(double hue, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ],
  );

  Widget _nearbyMap() {
    final userLat = _currentPos?.latitude ?? -1.286389;
    final userLng = _currentPos?.longitude ?? 36.817223;

    // Show a placeholder while police/danger data is still loading
    if (policeLoading || dangerLoading) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            // ── Google Map ──────────────────────────────────────────────
            gmaps.GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                setState(() => _mapReady = true);
                // Zoom to user once map is ready
                if (_currentPos != null) {
                  controller.animateCamera(
                    gmaps.CameraUpdate.newLatLngZoom(
                      gmaps.LatLng(
                        _currentPos!.latitude,
                        _currentPos!.longitude,
                      ),
                      13.5,
                    ),
                  );
                }
                _rebuildMapMarkers();
              },
              initialCameraPosition: gmaps.CameraPosition(
                target: gmaps.LatLng(userLat, userLng),
                zoom: 13.5,
              ),
              markers: _mapMarkers,
              circles: _mapCircles, // ← 5km perimeter circle
              myLocationEnabled: false,
              myLocationButtonEnabled: false, // we provide our own button
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            ),

            // ── "Open full map" overlay button → navigates to MapPage ──
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapPage()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.open_in_full,
                        size: 13,
                        color: Color(0xFF1A202C),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Full map',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A202C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Re-centre button ─────────────────────────────────────────
            Positioned(
              bottom: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  if (_currentPos != null) {
                    _mapController?.animateCamera(
                      gmaps.CameraUpdate.newLatLngZoom(
                        gmaps.LatLng(
                          _currentPos!.latitude,
                          _currentPos!.longitude,
                        ),
                        13.5,
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _teal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _teal.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),

            // ── Marker count badge ───────────────────────────────────────
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_police_rounded, size: 12, color: _teal),
                    const SizedBox(width: 4),
                    Text(
                      '${_nearbyPolice.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _teal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.warning_amber_rounded, size: 12, color: _red),
                    const SizedBox(width: 4),
                    Text(
                      '${_nearbyDangerZones.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _red,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // QUICK ACTIONS — single row of 4 compact chips
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _quickActions() {
    final actions = [
      _QuickAction(
        icon: Icons.upload_outlined,
        label: 'Upload Tip',
        color: _teal,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SafetyTipsPage(showUploadDialog: true),
          ),
        ),
      ),
      _QuickAction(
        icon: Icons.gavel_outlined,
        label: 'Legal Aid',
        color: _purple,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserLegalaid()),
        ),
      ),
      _QuickAction(
        icon: Icons.location_on_outlined,
        label: 'Share',
        color: _green,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapPage()),
        ),
      ),
      _QuickAction(
        icon: Icons.map_outlined,
        label: 'Map',
        color: _orange,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapPage()),
        ),
      ),
    ];

    return Row(
      children: actions
          .map(
            (a) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: a == actions.last ? 0 : 10),
                child: _compactActionChip(a),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _compactActionChip(_QuickAction a) => GestureDetector(
    onTap: a.onTap,
    child: Container(
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: a.color.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: a.color.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: a.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(a.icon, color: a.color, size: 17),
          ),
          const SizedBox(height: 5),
          Text(
            a.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _dark,
              height: 1.2,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _actionCard({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 110,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
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
            right: -10,
            bottom: -10,
            child: _decorCircle(70, Colors.white.withOpacity(0.08)),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: _decorCircle(30, Colors.white.withOpacity(0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // PANIC BANNER — full width, dramatic
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _panicBanner() => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPage(triggerPanic: true)),
    ),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53E3E), Color(0xFFC0392B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _red.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency Panic',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to immediately alert your emergency contacts',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'SOS',
              style: TextStyle(
                color: _red,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // POLICE STATIONS — horizontal scroll cards (now Haversine-filtered)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _policeSection() {
    if (policeLoading) return _shimmerRow();
    final nearby = _nearbyPolice;
    if (nearby.isEmpty)
      return _emptyState(
        'No police stations within 5 km',
        Icons.local_police_outlined,
      );
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: nearby.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final p = nearby[i];
          final dist = _distanceLabel(p.latitude, p.longitude);
          return Container(
            width: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _teal.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _teal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_police_rounded,
                        color: _teal,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (dist.isNotEmpty)
                      Expanded(
                        child: Text(
                          dist,
                          style: const TextStyle(
                            color: _teal,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _distanceLabel(p.latitude, p.longitude),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DANGER ZONES — horizontal scroll cards (now Haversine-filtered)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _dangerSection() {
    if (dangerLoading) return _shimmerRow();
    final nearby = _nearbyDangerZones;
    if (nearby.isEmpty)
      return _emptyState('No danger zones within 5 km', Icons.shield_outlined);
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: nearby.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final z = nearby[i];
          final dist = _distanceLabel(z.latitude, z.longitude);
          return Container(
            width: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _red.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: _red,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (dist.isNotEmpty)
                      Expanded(
                        child: Text(
                          dist,
                          style: const TextStyle(
                            color: _red,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  z.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Radius: ${z.radius.toStringAsFixed(0)}m',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SAFETY TIPS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _safetyTipsSection() {
    if (tipsLoading) return _shimmerList(2);
    if (safetyTips.isEmpty)
      return _emptyState('No safety tips yet', Icons.shield_outlined);
    final colours = [_teal, _purple, _green, _orange];
    return Column(
      children: safetyTips.take(2).toList().asMap().entries.map((e) {
        final col = colours[e.key % colours.length];
        return _tipCard(e.value, col);
      }).toList(),
    );
  }

  Widget _tipCard(SafetyTip tip, Color accent) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey[200]!),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.06),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.shield_outlined, color: accent, size: 20),
        ),
        title: Text(
          tip.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _dark,
          ),
        ),
        iconColor: accent,
        collapsedIconColor: Colors.grey[400],
        children: [
          Text(
            tip.content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // VIDEOS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _videosSection() {
    if (videoLoading) return _shimmerList(2, height: 90);
    if (videoInfoList.isEmpty)
      return _emptyState('No videos available', Icons.video_library_outlined);
    return Column(
      children: [
        ...videoInfoList.take(2).map(_videoCard),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final r = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const videosClass()),
            );
            if (r == true) _loadVideoInfo();
          },
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFED8936), Color(0xFFFBBF24)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _orange.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'See All Videos',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _videoCard(VideoInfo v) {
    final id = YoutubePlayer.convertUrlToId(v.url);
    if (id == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => playerClass(videoID: id, title: v.title),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  Image.network(
                    YoutubePlayer.getThumbnail(
                      videoId: id,
                      quality: ThumbnailQuality.medium,
                    ),
                    width: 110,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 110,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.video_library,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.title ?? 'Video',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: _orange,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Watch now',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
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

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: _dark,
    ),
  );

  Widget _rowHeader(
    String title,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    String? badge,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      GestureDetector(
        onTap: onTap,
        child: Text(
          'See all',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );

  Widget _shimmerList(int n, {double height = 80}) => Column(
    children: List.generate(
      n,
      (_) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );

  Widget _shimmerRow() => SizedBox(
    height: 120,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) => Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );

  Widget _emptyState(String msg, IconData icon) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(icon, size: 38, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(msg, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    ),
  );

  Widget _decorCircle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  void _showBottomSheet(String content) => showModalBottomSheet(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(child: Text(content)),
    ),
  );
}

// ── Home page voice alert dialog ─────────────────────────────────────────────
class _HomeVoiceAlertDialog extends StatefulWidget {
  @override
  State<_HomeVoiceAlertDialog> createState() => _HomeVoiceAlertDialogState();
}

class _HomeVoiceAlertDialogState extends State<_HomeVoiceAlertDialog>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  Timer? _auto;
  int _count = 10;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _auto = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _count--);
      if (_count <= 0) { t.cancel(); _dismiss(); }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _auto?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A6B8A), Color(0xFF4FABCB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4FABCB).withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic_rounded, color: Colors.white, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '📩 ALERT SENT',
              style: TextStyle(
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w900, letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Wake phrase detected. SMS sent to your emergency contacts.',
                      style: TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your location was included in the alert.',
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _dismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A6B8A),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'OK — Dismiss ($_count)',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
