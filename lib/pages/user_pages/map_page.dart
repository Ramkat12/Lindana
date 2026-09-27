// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:http/http.dart' as http;
import 'package:is_project_1/pages/user_pages/location_webservices.dart';
import 'package:is_project_1/services/background_voice_service.dart';
import 'package:is_project_1/services/cache_service.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import 'package:is_project_1/components/custom_bootom_navbar.dart';
import 'package:is_project_1/services/api_service.dart';
import 'package:is_project_1/models/profile_response.dart';
import 'package:share_plus/share_plus.dart';

// ── Haversine helper ──────────────────────────────────────────────────────────
// Pure math — no plugin needed, runs synchronously.
// Returns the great-circle distance in **metres** between two lat/lng points.
//
// Formula breakdown:
//   a = sin²(Δlat/2) + cos(lat1)·cos(lat2)·sin²(Δlng/2)
//   c = 2·atan2(√a, √(1−a))
//   d = R·c      where R = 6 371 000 m (Earth's mean radius)
double _haversineMetres(double lat1, double lng1, double lat2, double lng2) {
  const double R = 6371000.0;
  final double dLat = _deg2rad(lat2 - lat1);
  final double dLng = _deg2rad(lng2 - lng1);
  final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _deg2rad(double deg) => deg * pi / 180.0;

// Friendly distance label  e.g. "340m away"  or  "2.3km away"
String _distLabel(double metres) => metres < 1000
    ? '${metres.toStringAsFixed(0)}m away'
    : '${(metres / 1000).toStringAsFixed(1)}km away';

// ── Models ────────────────────────────────────────────────────────────────────

class PoliceLocation {
  final String name;
  final double latitude;
  final double longitude;

  PoliceLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory PoliceLocation.fromJson(Map<String, dynamic> json) {
    return PoliceLocation(
      name: json['name'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
    );
  }
}

class DangerZone {
  final String name;
  final double latitude;
  final double longitude;
  final String description;
  final double radius; // metres

  DangerZone({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.radius,
  });

  factory DangerZone.fromJson(Map<String, dynamic> json) {
    return DangerZone(
      name: json['location_name'] ?? 'Unknown',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] ?? '',
      radius: (json['radius'] as num?)?.toDouble() ?? 500.0,
    );
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class MapPage extends StatefulWidget {
  final bool triggerPanic;
  const MapPage({super.key, this.triggerPanic = false});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  // ── colours (mirrors homepage palette) ──────────────────────────────────
  static const _teal = Color(0xFF4FABCB);
  static const _red = Color(0xFFE53E3E);
  static const _dark = Color(0xFF1A202C);
  static const _green = Color(0xFF27AE60);

  // ── map ──────────────────────────────────────────────────────────────────
  mp.MapboxMap? mapboxMapController; // kept for future use
  gmaps.GoogleMapController? googleMapController;
  bool isMapReady = false;

  // ── markers / circles ────────────────────────────────────────────────────
  Set<gmaps.Marker> _markers = {};
  Set<gmaps.Circle> _circles = {};

  // 5 km search radius — same constant as the homepage
  static const double _searchRadius = 5000.0;

  // ── data ─────────────────────────────────────────────────────────────────
  List<PoliceLocation> policeLocations = [];
  List<DangerZone> dangerZones = [];
  Set<String> notifiedDangerZones = {};
  String API_BASE_URL =
      dotenv.env['API_BASE_URL'] ?? 'https://dbf2f97222f3.ngrok-free.app';

  // ── location ─────────────────────────────────────────────────────────────
  gl.Position? currentPosition;
  StreamSubscription? userPositionStream;

  // ── real-time tracking ───────────────────────────────────────────────────
  bool isRealTimeTrackingEnabled = false;
  int currentActivityId = 1;
  Timer? gpsLoggingTimer;
  Map<String, dynamic>? activeSharingSession;
  StreamSubscription? _locationUpdateSubscription;
  StreamSubscription? _connectionStatusSubscription;
  Map<String, dynamic>? _lastReceivedLocation;

  // ── emergency ────────────────────────────────────────────────────────────
  List<EmergencyContact> emergencyContacts = [];
  ProfileResponse? profile;
  bool isInPanicMode = false;
  StreamSubscription? accelerometerSubscription;

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadEnv();
    _initializeMapbox();
    _setupPositionTracking();
    _loadEmergencyContacts();
    _initializeWebSocket();
    _loadMapData();
    // Wake phrase → silent alert (NOT panic mode).
    // Panic mode is only triggered by shake or the panic button.
    BackgroundVoiceService.instance.onWakeWordDetected = _sendAlertFromVoice;
    BackgroundVoiceService.instance.startIfEnabled();
    if (widget.triggerPanic) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerPanicMode());
    }
  }

  Future<void> loadEnv() async {
    try {
      await dotenv.load(fileName: '.env');
      setState(() {
        API_BASE_URL =
            dotenv.env['API_BASE_URL'] ?? 'https://d2d35afcbdcd.ngrok-free.app';
      });
    } catch (e) {
      debugPrint('Error loading .env file: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    userPositionStream?.cancel();
    accelerometerSubscription?.cancel();
    gpsLoggingTimer?.cancel();
    _locationUpdateSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    LocationWebSocketService.instance.dispose();
    BackgroundVoiceService.instance.onWakeWordDetected = null;
    super.dispose();
  }

  // ── Voice alert (wake phrase detected) ─────────────────────────────────────
  // SMS is already sent by the background isolate.
  // Shows the same universal popup as the shake alert.
  Future<void> _sendAlertFromVoice() async {
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      pageBuilder: (ctx, _, __) => _VoiceAlertDialog(),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && isInPanicMode) _showPanicScreen();
  }

  // ── data loading ─────────────────────────────────────────────────────────

  Future<void> _loadMapData() async {
    try {
      currentPosition = await gl.Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('Error getting location: $e');
    }

    if (currentPosition != null) {
      await Future.wait([
        _fetchNearbyPoliceLocations(
          currentPosition!.latitude,
          currentPosition!.longitude,
        ),
        _fetchDangerZones(),
      ]);
    } else {
      await _fetchDangerZones();
    }

    _rebuildMapOverlays(); // always rebuild after data arrives
  }

  Future<void> _fetchNearbyPoliceLocations(double lat, double lng) async {
    const cacheKey = 'nearby_police';
    // 1. Show cached data instantly (zero-wait)
    final cached = await CacheService.getList(cacheKey);
    if (cached != null && mounted) {
      setState(() {
        policeLocations = cached.map((j) => PoliceLocation.fromJson(j)).toList();
      });
    }
    // 2. Fetch fresh data in the background
    try {
      final uri = Uri.parse('$API_BASE_URL/nearby-police').replace(
        queryParameters: {
          'latitude': lat.toString(),
          'longitude': lng.toString(),
          'radius': '5000',
        },
      );
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final locations = data['nearby_police'] as List<dynamic>;
        // Cache for 5 minutes
        await CacheService.setList(cacheKey, locations, const Duration(minutes: 5));
        if (mounted) {
          setState(() {
            policeLocations = locations.map((j) => PoliceLocation.fromJson(j)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching nearby police: $e');
    }
  }

  Future<void> _fetchDangerZones() async {
    const cacheKey = 'danger_zones';
    // Show stale data instantly
    final cached = await CacheService.getList(cacheKey);
    if (cached != null && mounted) {
      setState(() {
        dangerZones = cached.map((j) => DangerZone.fromJson(j)).toList();
      });
    }
    try {
      final response = await http
          .get(
            Uri.parse('$API_BASE_URL/danger-zones'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        await CacheService.setList(cacheKey, data, const Duration(minutes: 5));
        if (mounted) {
          setState(() {
            dangerZones = data.map((j) => DangerZone.fromJson(j)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching danger zones: $e');
    }
  }

  // ── Haversine filtering ───────────────────────────────────────────────────
  // Only keep items within _searchRadius of the user.
  // If we have no GPS fix yet, show everything so the map isn't empty.

  double _distTo(double lat, double lng) {
    if (currentPosition == null) return 0;
    return _haversineMetres(
      currentPosition!.latitude,
      currentPosition!.longitude,
      lat,
      lng,
    );
  }

  List<PoliceLocation> get _nearbyPolice {
    if (currentPosition == null) return policeLocations;
    return policeLocations
        .where((p) => _distTo(p.latitude, p.longitude) <= _searchRadius)
        .toList()
      ..sort(
        (a, b) => _distTo(
          a.latitude,
          a.longitude,
        ).compareTo(_distTo(b.latitude, b.longitude)),
      );
  }

  List<DangerZone> get _nearbyDangerZones {
    if (currentPosition == null) return dangerZones;
    return dangerZones
        .where((z) => _distTo(z.latitude, z.longitude) <= _searchRadius)
        .toList()
      ..sort(
        (a, b) => _distTo(
          a.latitude,
          a.longitude,
        ).compareTo(_distTo(b.latitude, b.longitude)),
      );
  }

  // ── Map overlays: markers + 5km perimeter circle ─────────────────────────

  void _rebuildMapOverlays() {
    final Set<gmaps.Marker> markers = {};
    final Set<gmaps.Circle> circles = {};

    // ── 5 km perimeter circle — clearly visible boundary ────────────────
    if (currentPosition != null) {
      // Outer boundary: solid teal stroke + visible fill
      circles.add(
        gmaps.Circle(
          circleId: const gmaps.CircleId('perimeter_5km'),
          center: gmaps.LatLng(
            currentPosition!.latitude,
            currentPosition!.longitude,
          ),
          radius: _searchRadius,
          strokeColor: const Color(0xFF4FABCB),
          strokeWidth: 3,
          fillColor: const Color(0xFF4FABCB).withOpacity(0.12),
        ),
      );
      // Inner accent ring at 2.5 km — gives depth / sense of scale
      circles.add(
        gmaps.Circle(
          circleId: const gmaps.CircleId('inner_ring_2_5km'),
          center: gmaps.LatLng(
            currentPosition!.latitude,
            currentPosition!.longitude,
          ),
          radius: _searchRadius / 2,
          strokeColor: const Color(0xFF4FABCB).withOpacity(0.45),
          strokeWidth: 1,
          fillColor: Colors.transparent,
        ),
      );

      // ── Black pulsating user-location circle ──────────────────────────
      // Outer "pulse" ring — semi-transparent black
      circles.add(
        gmaps.Circle(
          circleId: const gmaps.CircleId('user_pulse'),
          center: gmaps.LatLng(
            currentPosition!.latitude,
            currentPosition!.longitude,
          ),
          radius: 120,
          strokeColor: Colors.black.withOpacity(0.25),
          strokeWidth: 2,
          fillColor: Colors.black.withOpacity(0.08),
        ),
      );
      // Inner solid black dot
      circles.add(
        gmaps.Circle(
          circleId: const gmaps.CircleId('user_dot'),
          center: gmaps.LatLng(
            currentPosition!.latitude,
            currentPosition!.longitude,
          ),
          radius: 40,
          strokeColor: Colors.black,
          strokeWidth: 3,
          fillColor: Colors.black.withOpacity(0.85),
        ),
      );
    }

    // ── Police markers (azure blue) — only within 5 km ──────────────────
    for (final p in _nearbyPolice) {
      final dist = _distTo(p.latitude, p.longitude);
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('police_${p.name}'),
          position: gmaps.LatLng(p.latitude, p.longitude),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueAzure,
          ),
          infoWindow: gmaps.InfoWindow(
            title: p.name,
            snippet: _distLabel(dist),
          ),
        ),
      );
    }

    // ── Danger zone markers (red) — only within 5 km ────────────────────
    for (final z in _nearbyDangerZones) {
      final dist = _distTo(z.latitude, z.longitude);
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
                '${_distLabel(dist)} · radius ${z.radius.toStringAsFixed(0)}m',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });

    // Animate camera to user once map is ready
    if (isMapReady && currentPosition != null) {
      googleMapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(currentPosition!.latitude, currentPosition!.longitude),
          12.0,
        ),
      );
    }
  }

  // ── position tracking ─────────────────────────────────────────────────────

  Future<void> _setupPositionTracking() async {
    try {
      bool svc = await gl.Geolocator.isLocationServiceEnabled();
      if (!svc) {
        debugPrint('Location services disabled');
        return;
      }

      var perm = await gl.Geolocator.checkPermission();
      if (perm == gl.LocationPermission.denied)
        perm = await gl.Geolocator.requestPermission();
      if (perm == gl.LocationPermission.denied ||
          perm == gl.LocationPermission.deniedForever) {
        debugPrint('Location permission denied');
        return;
      }

      userPositionStream?.cancel();
      userPositionStream =
          gl.Geolocator.getPositionStream(
            locationSettings: const gl.LocationSettings(
              accuracy: gl.LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((gl.Position pos) {
            currentPosition = pos;
            // Persist for background isolate (SMS alert uses last known position)
            BackgroundVoiceService.savePositionForBackground(
              pos.latitude, pos.longitude,
            );
            // Move camera with user
            if (googleMapController != null && isMapReady) {
              googleMapController!.animateCamera(
                gmaps.CameraUpdate.newCameraPosition(
                  gmaps.CameraPosition(
                    target: gmaps.LatLng(pos.latitude, pos.longitude),
                    zoom: 15.0,
                  ),
                ),
              );
            }
            // Rebuild overlays so the circle follows the user
            _rebuildMapOverlays();
          }, onError: (e) => debugPrint('Position stream error: $e'));
    } catch (e) {
      debugPrint('Error setting up position tracking: $e');
    }
  }

  // ── real-time tracking ────────────────────────────────────────────────────

  void _toggleRealTimeTracking() async {
    setState(() => isRealTimeTrackingEnabled = !isRealTimeTrackingEnabled);
    if (isRealTimeTrackingEnabled)
      await _startRealTimeTracking();
    else
      await _stopRealTimeTracking();
  }

  Future<void> _startRealTimeTracking() async {
    try {
      gpsLoggingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        if (currentPosition != null) {
          try {
            await ApiService.logGPSLocationRealtime(
              latitude: currentPosition!.latitude,
              longitude: currentPosition!.longitude,
              activityId: currentActivityId,
            );
          } catch (e) {
            debugPrint('GPS log failed: $e');
          }
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Real-time tracking enabled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting tracking: $e');
    }
  }

  Future<void> _stopRealTimeTracking() async {
    gpsLoggingTimer?.cancel();
    gpsLoggingTimer = null;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Real-time tracking disabled'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ── emergency contacts ────────────────────────────────────────────────────

  Future<void> _loadEmergencyContacts() async {
    try {
      final profileData = await ApiService.getProfile();
      List<EmergencyContact> contacts = [];
      if (profileData.roleId == 5) {
        try {
          contacts = await ApiService.getEmergencyContacts();
        } catch (e) {
          debugPrint('Failed to load emergency contacts: $e');
        }
      }
      setState(() {
        profile = profileData;
        emergencyContacts = contacts;
      });
      // ── Persist for background isolate so SMS works when app is closed ──
      await BackgroundVoiceService.saveContactsForBackground(
        contacts.map((c) => c.toJson()).toList(),
      );
      // Also store base URL and token for the isolate
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', API_BASE_URL);
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  // ── websocket ─────────────────────────────────────────────────────────────

  Future<void> _initializeWebSocket() async {
    try {
      final profileData = await ApiService.getProfile();
      final userId = profileData.id;
      await LocationWebSocketService.instance.connect(userId as String);
      _locationUpdateSubscription = LocationWebSocketService
          .instance
          .locationUpdates
          .listen(_handleLocationUpdate);
      _connectionStatusSubscription = LocationWebSocketService
          .instance
          .connectionStatus
          .listen((isConnected) {
            setState(() {});
            if (isConnected && isRealTimeTrackingEnabled)
              _startRealTimeTracking();
          });
    } catch (e) {
      debugPrint('Error initializing WebSocket: $e');
    }
  }

  void _handleLocationUpdate(Map<String, dynamic> locationData) {
    setState(() => _lastReceivedLocation = locationData);
    final data = locationData['data'];
    if (data != null)
      debugPrint('Location update: ${data['latitude']}, ${data['longitude']}');
  }

  // ── location sharing ──────────────────────────────────────────────────────

  Future<void> _shareCurrentLocationRealTime() async {
    try {
      final contactNumbers = emergencyContacts
          .map((c) => c.contactNumber)
          .toList();
      if (contactNumbers.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No emergency contacts available'),
              backgroundColor: Colors.orange,
            ),
          );
        return;
      }
      final selectedHours = await _showDurationSelectionDialog();
      if (selectedHours == null) return;

      final sharingResult = await ApiService.startLocationSharing(
        activityId: currentActivityId,
        contacts: contactNumbers,
        durationHours: selectedHours,
      );
      setState(() {
        activeSharingSession = sharingResult;
        isRealTimeTrackingEnabled = true;
      });
      await _startRealTimeTracking();
      await _sendLocationSharingNotification(sharingResult['share_url']);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Real-time sharing started for $selectedHours hours'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
    }
  }

  Future<int?> _showDurationSelectionDialog() => showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Share Duration'),
      content: const Text('How long to share your location?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 1),
          child: const Text('1 Hour'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 4),
          child: const Text('4 Hours'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 24),
          child: const Text('24 Hours'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  Future<void> _sendLocationSharingNotification(String shareUrl) async {
    final msg =
        'Real-time Location Sharing\n\n${profile?.name ?? 'Someone'} is sharing their live location.\n\nTrack here: $shareUrl\n\nSent: ${DateTime.now()}';
    for (final c in emergencyContacts) {
      try {
        await ApiService.sendLocationSMS(
          phoneNumber: c.contactNumber,
          message: msg,
        );
      } catch (e) {
        debugPrint('Failed to notify ${c.contactName}: $e');
      }
    }
  }

  Future<void> _stopLocationSharing() async {
    setState(() {
      activeSharingSession = null;
      isRealTimeTrackingEnabled = false;
    });
    await _stopRealTimeTracking();
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location sharing stopped'),
          backgroundColor: Colors.orange,
        ),
      );
  }

  Future<void> _shareCurrentLocation() async {
    try {
      final pos = currentPosition ?? await gl.Geolocator.getCurrentPosition();
      final url =
          'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
      await Share.share('Here is my current location: $url');
      if (emergencyContacts.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Share Location'),
            content: const Text('Send to emergency contacts too?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _sendLocationToEmergencyContacts(
                    url,
                    pos.latitude,
                    pos.longitude,
                  );
                },
                child: const Text('Yes'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sharing: $e');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share location.')),
        );
    }
  }

  Future<void> _sendLocationToEmergencyContacts(
    String url,
    double lat,
    double lng,
  ) async {
    final msg =
        'Location Share from ${profile?.name ?? 'Contact'}\n\n$url\n\nLat: $lat  Lng: $lng\n\nSent: ${DateTime.now()}';
    for (final c in emergencyContacts) {
      try {
        await ApiService.sendLocationSMS(
          phoneNumber: c.contactNumber,
          message: msg,
        );
      } catch (e) {
        debugPrint('Failed to send to ${c.contactName}: $e');
      }
    }
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location sent to emergency contacts'),
          backgroundColor: Colors.green,
        ),
      );
  }

  // ── panic ─────────────────────────────────────────────────────────────────

  Future<void> _triggerPanicMode() async {
    if (isInPanicMode) return;
    setState(() => isInPanicMode = true);
    await BackgroundVoiceService.instance.pause();
    if (await Vibration.hasVibrator() ?? false)
      Vibration.vibrate(pattern: [0, 1000, 500, 1000], repeat: 1);
    _showPanicScreen();
  }

  void _showPanicScreen() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: PanicScreen(
          onSendDistress: _sendDistressSignal,
          onCancel: _cancelPanicMode,
        ),
      ),
    );
  }

  Future<void> _sendDistressSignal() async {
    try {
      currentPosition ??= await gl.Geolocator.getCurrentPosition();
      final lat = currentPosition!.latitude;
      final lng = currentPosition!.longitude;
      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      await _sendEmergencyMessages(url, lat, lng);
      _cancelPanicMode();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Distress signal sent'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
    }
  }

  Future<void> _sendEmergencyMessages(
    String url,
    double lat,
    double lng,
  ) async {
    if (emergencyContacts.isEmpty) throw Exception('No emergency contacts');
    final msg =
        'EMERGENCY ALERT\n\n${profile?.name ?? 'Someone'} triggered an alert!\n\nLocation: $lat, $lng\nMap: $url\n\nTime: ${DateTime.now()}';
    for (final c in emergencyContacts) {
      try {
        await ApiService.sendEmergencySMS(
          phoneNumber: c.contactNumber,
          message: msg,
        );
      } catch (e) {
        debugPrint('SMS failed to ${c.contactName}: $e');
      }
    }
  }

  void _cancelPanicMode() {
    setState(() => isInPanicMode = false);
    Vibration.cancel();
    // Restore voice hook to silent alert after panic is cancelled
    BackgroundVoiceService.instance.onWakeWordDetected = _sendAlertFromVoice;
    BackgroundVoiceService.instance.resume();
    if (Navigator.canPop(context)) Navigator.of(context).pop();
  }

  Future<void> _initializeMapbox() async {
    try {
      final token = dotenv.env['MAPBOX_ACCESS_TOKEN'];
      if (token == null || token.isEmpty) return;
      mp.MapboxOptions.setAccessToken(token);
    } catch (e) {
      debugPrint('Mapbox init error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ────────────────────────────────────────────────────
          gmaps.GoogleMap(
            onMapCreated: (controller) {
              googleMapController = controller;
              setState(() => isMapReady = true);
              // Once ready, zoom to user and draw overlays
              if (currentPosition != null) {
                controller.animateCamera(
                  gmaps.CameraUpdate.newLatLngZoom(
                    gmaps.LatLng(
                      currentPosition!.latitude,
                      currentPosition!.longitude,
                    ),
                    12.0,
                  ),
                );
              }
              _rebuildMapOverlays();
            },
            initialCameraPosition: gmaps.CameraPosition(
              target: gmaps.LatLng(
                currentPosition?.latitude ?? 0,
                currentPosition?.longitude ?? 0,
              ),
              zoom: 12.0,
            ),
            markers: _markers, // Haversine-filtered markers only
            circles: _circles, // 5 km perimeter circle
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
          ),

          if (!isMapReady) const Center(child: CircularProgressIndicator()),

          // ── Top bar with gradient (mirrors homepage) ───────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2E86AB),
                    Color(0xFF4FABCB),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Safety Map',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              '${_nearbyPolice.length} police · ${_nearbyDangerZones.length} danger zones within 5 km',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Legend pill
                      _legendPill(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Connection status ──────────────────────────────────────────
          // Positioned below the gradient top bar (~100px) + safe area
          Positioned(
            top: 148,
            left: 16,
            child: _buildConnectionStatusIndicator(),
          ),

          // ── Panic button — right side, below top bar ───────────────────
          Positioned(top: 148, right: 16, child: _buildPanicButton()),

          // ── Live tracking toggle — left side, below connection status ──
          Positioned(top: 200, left: 16, child: _buildRealTimeTrackingButton()),

          // ── Bottom share card ──────────────────────────────────────────
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: _buildShareLocationCard(),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 2),
    );
  }

  // ── Map legend pill ───────────────────────────────────────────────────────

  Widget _legendPill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        const Text(
          'Police',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        const Text(
          'Danger',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  // ── Real-time tracking button ─────────────────────────────────────────────

  // Tapping toggles the 10-second GPS logging loop.
  // Shows pulsing white dot + "LIVE" when active, "GPS OFF" when inactive.
  Widget _buildRealTimeTrackingButton() => GestureDetector(
    onTap: _toggleRealTimeTracking,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isRealTimeTrackingEnabled ? _green : const Color(0xFF4A5568),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (isRealTimeTrackingEnabled ? _green : Colors.black)
                .withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRealTimeTrackingEnabled)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          Icon(
            isRealTimeTrackingEnabled ? Icons.gps_fixed : Icons.gps_off,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isRealTimeTrackingEnabled ? 'LIVE' : 'GPS OFF',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Panic button ──────────────────────────────────────────────────────────

  Widget _buildPanicButton() => GestureDetector(
    onTap: _triggerPanicMode,
    child: Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: _red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _red.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.warning_rounded, color: Colors.white, size: 30),
    ),
  );

  // ── Connection status ─────────────────────────────────────────────────────

  Widget _buildConnectionStatusIndicator() {
    final connected = LocationWebSocketService.instance.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: connected ? _green : _red,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected ? Icons.wifi : Icons.wifi_off,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            connected ? 'Connected' : 'Offline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Share location card ───────────────────────────────────────────────────

  Widget _buildShareLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Active sharing banner ──────────────────────────────────────
          if (activeSharingSession != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _green.withOpacity(0.25)),
              ),
              child: Row(
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
                  const Expanded(
                    child: Text(
                      'Live location sharing active',
                      style: TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _stopLocationSharing,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Stop',
                        style: TextStyle(
                          color: _red,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Real-time tracking status row ─────────────────────────────
          // Shows live GPS status with a toggle button right in the card.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isRealTimeTrackingEnabled
                  ? _green.withOpacity(0.08)
                  : Colors.grey.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRealTimeTrackingEnabled
                    ? _green.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isRealTimeTrackingEnabled ? Icons.gps_fixed : Icons.gps_off,
                  color: isRealTimeTrackingEnabled ? _green : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isRealTimeTrackingEnabled
                            ? 'Real-time GPS tracking ON'
                            : 'Real-time GPS tracking OFF',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: isRealTimeTrackingEnabled
                              ? _green
                              : Colors.grey[600],
                        ),
                      ),
                      Text(
                        isRealTimeTrackingEnabled
                            ? 'Logging your position every 10 seconds'
                            : 'Tap to start broadcasting your location',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleRealTimeTracking,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isRealTimeTrackingEnabled
                          ? _red.withOpacity(0.1)
                          : _green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRealTimeTrackingEnabled
                            ? _red.withOpacity(0.3)
                            : _green.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      isRealTimeTrackingEnabled ? 'Stop' : 'Start',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isRealTimeTrackingEnabled ? _red : _green,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Stats row ─────────────────────────────────────────────────
          Row(
            children: [
              _statChip(
                Icons.local_police_rounded,
                '${_nearbyPolice.length} Police',
                _teal,
              ),
              const SizedBox(width: 10),
              _statChip(
                Icons.warning_amber_rounded,
                '${_nearbyDangerZones.length} Danger Zones',
                _red,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Share row ─────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: _teal,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share Location',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    Text(
                      activeSharingSession != null
                          ? 'Real-time sharing active'
                          : 'Share your current or live location',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'current')
                    _shareCurrentLocation();
                  else if (v == 'realtime')
                    _shareCurrentLocationRealTime();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'current',
                    child: Text('Current Location'),
                  ),
                  const PopupMenuItem(
                    value: 'realtime',
                    child: Text('Real-time Tracking'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E86AB), Color(0xFF4FABCB)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _teal.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Share',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// PANIC SCREEN — unchanged from original
// ══════════════════════════════════════════════════════════════════════════════

class PanicScreen extends StatefulWidget {
  final VoidCallback onSendDistress;
  final VoidCallback onCancel;
  const PanicScreen({
    super.key,
    required this.onSendDistress,
    required this.onCancel,
  });

  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  int tapCount = 0;
  Timer? tapTimer;
  int _secondsLeft = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shakeAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _pulseController.repeat(reverse: true);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          timer.cancel();
          widget.onCancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _shakeController.dispose();
    tapTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    setState(() => tapCount++);
    if (tapCount == 1) {
      tapTimer = Timer(const Duration(seconds: 3), () {
        if (tapCount == 1) widget.onCancel();
      });
    } else if (tapCount >= 2) {
      tapTimer?.cancel();
      widget.onSendDistress();
    }
    _shakeController.forward().then((_) => _shakeController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (_, __) => Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) => Transform.scale(
                      scale: _pulseAnimation.value,
                      child: const Icon(
                        Icons.warning,
                        size: 100,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'EMERGENCY MODE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tapCount == 0
                        ? 'Tap TWICE to send distress signal\nTap ONCE if accidental'
                        : 'Tap AGAIN to confirm\nOr wait 3 seconds to cancel',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Auto-canceling in $_secondsLeft seconds',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _handleTap,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Text(
                          tapCount == 0 ? 'TAP HERE' : 'TAP AGAIN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (tapCount == 0)
                    TextButton(
                      onPressed: widget.onCancel,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Voice Alert Dialog ────────────────────────────────────────────────────────
// Shown in-app when the wake phrase is detected. SMS already sent by background.
class _VoiceAlertDialog extends StatefulWidget {
  @override
  State<_VoiceAlertDialog> createState() => _VoiceAlertDialogState();
}

class _VoiceAlertDialogState extends State<_VoiceAlertDialog>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  Timer? _autoDismiss;
  int _countdown = 10;

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
    _autoDismiss = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) { t.cancel(); _dismiss(); }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _autoDismiss?.cancel();
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
                  width: 72,
                  height: 72,
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
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
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
                        color: Colors.white,
                        fontSize: 13,
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
                  'OK — Dismiss ($_countdown)',
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
