import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:is_project_1/models/profile_response.dart';
import 'package:is_project_1/pages/user_pages/location_webservices.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static late final String baseUrl;

  // Get stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> getCurrentProviderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token != null) {
        final decodedToken = JwtDecoder.decode(token);
        return decodedToken['sub']; // This is the provider ID
      }
      return null;
    } catch (e) {
      print('Error getting provider ID: $e');
      return null;
    }
  }

  // Get user profile
  static Future<ProfileResponse> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ProfileResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    } catch (e) {
      throw Exception('Failed to get headers: $e');
    }
  }

  // Get emergency contacts (only for role_id == 5)
  static Future<List<EmergencyContact>> getEmergencyContacts() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // You'll need to create this endpoint in your FastAPI backend
      final response = await http.get(
        Uri.parse('$baseUrl/emergency-contacts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => EmergencyContact.fromJson(json)).toList();
      } else if (response.statusCode == 404) {
        // No emergency contacts found
        return [];
      } else {
        throw Exception(
          'Failed to load emergency contacts: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Logout
  static Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
      }

      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      // Even if logout request fails, clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
  }

  static Future<void> sendEmergencySMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/send-emergency-sms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await getToken()}',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
          'message': message,
          'is_emergency': true,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send emergency SMS: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending emergency SMS: $e');
    }
  }

  /// Send location SMS via Africa's Talking
  static Future<void> sendLocationSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/send-location-sms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await getToken()}',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
          'message': message,
          'is_emergency': false,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send location SMS: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending location SMS: $e');
    }
  }

  static Future<void> logGPSLocation({
    required double latitude,
    required double longitude,
    required int activityId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/gps/log'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'activity_id': activityId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to log GPS location: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error logging GPS location: $e');
      rethrow;
    }
  }

  // Start location sharing
  static Future<Map<String, dynamic>> startLocationSharing({
    required int activityId,
    required List<String> contacts,
    int durationHours = 24,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/gps/share'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'activity_id': activityId,
          'contacts': contacts,
          'duration_hours': durationHours,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to start location sharing: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error starting location sharing: $e');
      rethrow;
    }
  }

  // Get latest location for a user
  static Future<Map<String, dynamic>> getLatestLocation(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/gps/latest/$userId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get latest location: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error getting latest location: $e');
      rethrow;
    }
  }

  static Future<void> logGPSLocationRealtime({
    required double latitude,
    required double longitude,
    required int activityId,
  }) async {
    try {
      // Send to REST API for persistence
      final response = await http.post(
        Uri.parse('$baseUrl/gps/log-realtime'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'activity_id': activityId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to log GPS location: ${response.body}');
      }

      // Also send via WebSocket for real-time updates
      LocationWebSocketService.instance.sendLocationUpdate(
        latitude: latitude,
        longitude: longitude,
        activityId: activityId,
      );
    } catch (e) {
      debugPrint('Error logging GPS location: $e');
      rethrow;
    }
  }

  static Future<void> loadEnv() async {
    try {
      await dotenv.load(fileName: ".env");
      baseUrl =
          dotenv.env['API_BASE_URL'] ?? 'https://284d-102-208-82-84.ngrok-free.app';
    } catch (e) {
      print('Error loading .env file: $e');
      baseUrl =
          '                                                                                                             ';
    }

    /// Get emergency contacts
  }
}
