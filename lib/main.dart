import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:is_project_1/pages/login_page.dart';
import 'package:is_project_1/pages/admin_pages/admin_homepage.dart';
import 'package:is_project_1/pages/legal_aid_pages/legalaid_homepage.dart';
import 'package:is_project_1/pages/user_pages/map_page.dart';
import 'package:is_project_1/pages/user_pages/user_homepage.dart';
import 'package:is_project_1/services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


import 'package:is_project_1/services/background_service.dart'; // Import service
import 'package:is_project_1/services/background_voice_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiService.loadEnv();

  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");

    // Initialize Background Service
    await initializeService();

    // Initialize Background Voice Service
    BackgroundVoiceService.init();

    // Set Mapbox Access Token
    final mapboxToken = dotenv.env["MAPBOX_ACCESS_TOKEN"];
    if (mapboxToken == null || mapboxToken.isEmpty) {
      throw Exception('MAPBOX_ACCESS_TOKEN is missing or empty in .env');
    }
    MapboxOptions.setAccessToken(mapboxToken);

    // Initialize Supabase
    final supabaseUrl = dotenv.env["SUPABASE_URL"];
    final supabaseAnonKey = dotenv.env["SUPABASE_ANON_KEY"];

    if (supabaseUrl == null || supabaseUrl.isEmpty) {
      throw Exception('SUPABASE_URL is missing or empty in .env');
    }

    if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY is missing or empty in .env');
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

    print('Supabase and Mapbox initialized successfully');
  } catch (e) {
    print('Initialization error: $e');
  }

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(), // Use AuthWrapper instead of direct LoginPage
    );
  }
}

// New AuthWrapper class to handle authentication state
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
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final userId = prefs.getString('user_id');

      if (accessToken != null && userId != null) {
        // Check if token is still valid
        if (await _isTokenValid(accessToken)) {
          // Token is valid, decode it to get user role
          final roleId = await _getUserRole(accessToken);
          setState(() {
            initialPage = _getPageByRole(roleId);
            isLoading = false;
          });
          return;
        } else {
          // Token is expired, try to refresh it
          final refreshToken = prefs.getString('refresh_token');
          if (refreshToken != null && await _refreshAccessToken(refreshToken)) {
            // Successfully refreshed, get new role
            final newAccessToken = prefs.getString('access_token');
            final roleId = await _getUserRole(newAccessToken!);
            setState(() {
              initialPage = _getPageByRole(roleId);
              isLoading = false;
            });
            return;
          }
        }
      }

      // No valid token found, go to login
      setState(() {
        initialPage = const LoginPage();
        isLoading = false;
      });
    } catch (e) {
      print('Auth check error: $e');
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

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final decodedPayload = json.decode(decoded);

      final exp = decodedPayload['exp'];
      if (exp == null) return false;

      final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isBefore(expirationDate);
    } catch (e) {
      print('Token validation error: $e');
      return false;
    }
  }

  Future<int> _getUserRole(String token) async {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw Exception('Invalid token');

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final decodedPayload = json.decode(decoded);

      return decodedPayload['role_id'] ?? 0;
    } catch (e) {
      print('Role extraction error: $e');
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
        final responseData = json.decode(response.body);
        await prefs.setString('access_token', responseData['access_token']);
        if (responseData['refresh_token'] != null) {
          await prefs.setString('refresh_token', responseData['refresh_token']);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Token refresh error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return initialPage ?? const MapPage();
  }
}
