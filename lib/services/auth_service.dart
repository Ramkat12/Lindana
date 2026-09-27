import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:is_project_1/services/local_database_service.dart';

class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';

  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://284d-102-208-82-84.ngrok-free.app';

  // Check if user is currently logged in
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_accessTokenKey);

      if (accessToken == null) return false;

      return await _isTokenValid(accessToken);
    } catch (e) {
      print('Login check error: $e');
      return false;
    }
  }

  // Get current user ID
  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Get current user role
  static Future<int?> getCurrentUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_accessTokenKey);

      if (accessToken == null) return null;

      if (await _isTokenValid(accessToken)) {
        return _extractRoleFromToken(accessToken);
      } else {
        // Try to refresh token
        final refreshToken = prefs.getString(_refreshTokenKey);
        if (refreshToken != null && await refreshAccessToken()) {
          final newAccessToken = prefs.getString(_accessTokenKey);
          return _extractRoleFromToken(newAccessToken!);
        }
      }
      return null;
    } catch (e) {
      print('Role extraction error: $e');
      return null;
    }
  }

  // Get valid access token (refreshes if needed)
  static Future<String?> getValidAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_accessTokenKey);

      if (accessToken == null) return null;

      if (await _isTokenValid(accessToken)) {
        return accessToken;
      } else {
        // Try to refresh token
        final refreshToken = prefs.getString(_refreshTokenKey);
        if (refreshToken != null && await refreshAccessToken()) {
          return prefs.getString(_accessTokenKey);
        }
      }
      return null;
    } catch (e) {
      print('Token retrieval error: $e');
      return null;
    }
  }

  // Store tokens after login
  static Future<void> storeTokens(
    String accessToken,
    String refreshToken,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);

    // Extract and store user ID
    try {
      final userId = _extractUserIdFromToken(accessToken);
      await prefs.setString(_userIdKey, userId);
    } catch (e) {
      print('Error storing user ID: $e');
    }
  }

  // Refresh access token
  static Future<bool> refreshAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);

      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        await prefs.setString(_accessTokenKey, responseData['access_token']);

        // Update refresh token if provided
        if (responseData['refresh_token'] != null) {
          await prefs.setString(
            _refreshTokenKey,
            responseData['refresh_token'],
          );
        }

        return true;
      }

      return false;
    } catch (e) {
      print('Token refresh error: $e');
      return false;
    }
  }

  // Logout user
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);

    // Clear local SQLite user session and cached contacts
    try {
      await LocalDatabaseService.instance.clearSession();
      await LocalDatabaseService.instance.clearLocalEmergencyContacts();
    } catch (e) {
      print('LocalDatabase clear error: $e');
    }
  }

  // Private helper methods
  static Future<bool> _isTokenValid(String token) async {
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
      // Add 5 minute buffer before actual expiration
      return DateTime.now().isBefore(
        expirationDate.subtract(const Duration(minutes: 5)),
      );
    } catch (e) {
      print('Token validation error: $e');
      return false;
    }
  }

  static int _extractRoleFromToken(String token) {
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
      rethrow;
    }
  }

  static String _extractUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw Exception('Invalid token');

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final decodedPayload = json.decode(decoded);

      return decodedPayload['sub'] ?? '';
    } catch (e) {
      print('User ID extraction error: $e');
      rethrow;
    }
  }

  // Make authenticated API requests
  static Future<http.Response?> authenticatedRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final token = await getValidAccessToken();
      if (token == null) return null;

      final requestHeaders = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ...?headers,
      };

      final uri = Uri.parse('$baseUrl$endpoint');

      switch (method.toUpperCase()) {
        case 'GET':
          return await http.get(uri, headers: requestHeaders);
        case 'POST':
          return await http.post(
            uri,
            headers: requestHeaders,
            body: body != null ? json.encode(body) : null,
          );
        case 'PUT':
          return await http.put(
            uri,
            headers: requestHeaders,
            body: body != null ? json.encode(body) : null,
          );
        case 'DELETE':
          return await http.delete(uri, headers: requestHeaders);
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } catch (e) {
      print('Authenticated request error: $e');
      return null;
    }
  }
}
