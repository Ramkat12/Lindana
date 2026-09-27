import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:is_project_1/pages/admin_pages/admin_homepage.dart';
import 'package:is_project_1/pages/legal_aid_pages/legalaid_homepage.dart';
import 'package:is_project_1/pages/login_page.dart';
import 'package:is_project_1/pages/user_pages/map_page.dart';
import 'package:is_project_1/pages/user_pages/user_homepage.dart';
import 'package:is_project_1/services/api_service.dart';
import 'package:is_project_1/services/background_service.dart';
import 'package:is_project_1/services/background_voice_service.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:is_project_1/services/local_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Global navigator key — lets us show dialogs from anywhere (any page) ────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiService.loadEnv();

  try {
    await dotenv.load(fileName: '.env');
    await initializeService();
    // Start the global shake detector service immediately
    FlutterBackgroundService().startService();
    BackgroundVoiceService.init();

    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (mapboxToken != null && mapboxToken.isNotEmpty) {
      MapboxOptions.setAccessToken(mapboxToken);
    }

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (supabaseUrl != null &&
        supabaseUrl.isNotEmpty &&
        supabaseAnonKey != null &&
        supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    }
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  // ── Universal shake → open Panic Mode ─────────────────────────────
  bool isPanicDebounce = false;
  FlutterBackgroundService().on('onShakeDetected').listen((_) {
    if (isPanicDebounce) return;
    isPanicDebounce = true;
    Future.delayed(const Duration(seconds: 15), () => isPanicDebounce = false);

    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      Navigator.of(ctx).push(
        MaterialPageRoute(
          builder: (context) => const MapPage(triggerPanic: true),
        ),
      );
    }
  });

  runApp(const MyApp());
}

// ─────────────────────────────────────────────────────────────────────────────

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: const AuthWrapper(),
    );
  }
}

// ── Auth wrapper ──────────────────────────────────────────────────────────────
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool isLoading = true;
  Widget? initialPage;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      // 1. Try to load user session from the local SQLite database
      final localSession = await LocalDatabaseService.instance.getSession();

      if (localSession != null) {
        final accessToken = localSession['access_token'] as String?;
        final roleId = localSession['role_id'] as int?;

        if (accessToken != null && roleId != null) {
          if (await _isTokenValid(accessToken)) {
            setState(() {
              initialPage = _getPageByRole(roleId);
              isLoading = false;
            });
            // Update in-memory and SQLite cache in background
            ApiService.getProfile().catchError((e) {
              debugPrint('Background profile refresh failed: $e');
            });
            return;
          } else {
            final refreshToken = localSession['refresh_token'] as String?;
            if (refreshToken != null && await _refreshAccessToken(refreshToken)) {
              final updatedSession = await LocalDatabaseService.instance.getSession();
              if (updatedSession != null) {
                final newRoleId = updatedSession['role_id'] as int? ?? roleId;
                setState(() {
                  initialPage = _getPageByRole(newRoleId);
                  isLoading = false;
                });
                return;
              }
            }
          }
        }
      }

      // 2. Legacy fallback: check SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final userId = prefs.getString('user_id');

      if (accessToken != null && userId != null) {
        if (await _isTokenValid(accessToken)) {
          final roleId = await _getUserRole(accessToken);
          setState(() {
            initialPage = _getPageByRole(roleId);
            isLoading = false;
          });
          // Cache the profile details to local SQLite in background
          ApiService.getProfile().catchError((e) {
            debugPrint('Background profile caching failed: $e');
          });
          return;
        } else {
          final refreshToken = prefs.getString('refresh_token');
          if (refreshToken != null && await _refreshAccessToken(refreshToken)) {
            final newAccessToken = prefs.getString('access_token')!;
            final roleId = await _getUserRole(newAccessToken);
            setState(() {
              initialPage = _getPageByRole(roleId);
              isLoading = false;
            });
            return;
          }
        }
      }

      setState(() {
        initialPage = const LoginPage();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Auth check error: $e');
      setState(() {
        initialPage = const LoginPage();
        isLoading = false;
      });
    }
  }

  Future<bool> _isTokenValid(String token) async {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final exp = json.decode(decoded)['exp'];
      if (exp == null) return false;
      return DateTime.now().isBefore(
        DateTime.fromMillisecondsSinceEpoch(exp * 1000),
      );
    } catch (_) {
      return false;
    }
  }

  Future<int> _getUserRole(String token) async {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw Exception('Invalid token');
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return json.decode(decoded)['role_id'] ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Widget _getPageByRole(int roleId) {
    switch (roleId) {
      case 4:
        return const AdminHomepage();
      case 6:
        return const LegalAidHomepage();
      default:
        return const UserHomepage();
    }
  }

  Future<bool> _refreshAccessToken(String refreshToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl =
          dotenv.env['API_BASE_URL'] ??
          'https://284d-102-208-82-84.ngrok-free.app';

      final response = await http.post(
        Uri.parse('$baseUrl/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccessToken = data['access_token'];
        final newRefreshToken = data['refresh_token'] ?? refreshToken;

        await prefs.setString('access_token', newAccessToken);
        await prefs.setString('refresh_token', newRefreshToken);

        // Update tokens in local SQLite database session
        try {
          await LocalDatabaseService.instance.updateTokens(newAccessToken, newRefreshToken);
        } catch (dbErr) {
          print('LocalDatabase update tokens error: $dbErr');
        }

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return initialPage ?? const UserHomepage();
  }
}
