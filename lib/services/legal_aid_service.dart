import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/legal_aid_requests.dart';

class LegalAidService {
  static String? _baseUrl;
  static bool _isInitialized = false;

  // Initialize the service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await dotenv.load(fileName: ".env");
      _baseUrl =
          dotenv.env['API_BASE_URL'] ?? 'https://d2d35afcbdcd.ngrok-free.app';
    } catch (e) {
      print('Error loading .env file: $e');
      _baseUrl = 'https://d2d35afcbdcd.ngrok-free.app';
    }

    _isInitialized = true;
  }

  // Get base URL, ensure initialization
  static Future<String> get baseUrl async {
    if (!_isInitialized) {
      await initialize();
    }
    return _baseUrl!;
  }

  // Get all legal aid providers
  static Future<List<LegalAidProvider>> getLegalAidProviders() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/legal-aid-providers'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => LegalAidProvider.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load legal aid providers: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching legal aid providers: $e');
    }
  }

  // Get single legal aid provider by ID
  static Future<LegalAidProvider> getLegalAidProvider(String providerId) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/legal-aid-providers/$providerId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return LegalAidProvider.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        throw Exception('Legal aid provider not found');
      } else {
        throw Exception(
          'Failed to load legal aid provider: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching legal aid provider: $e');
    }
  }

  // Create legal aid request
  static Future<LegalAidRequest> createLegalAidRequest({
    required String userId,
    required String providerId,
    required String title,
    required String description,
  }) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/legal-aid-requests'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'legal_aid_provider_id': providerId,
          'title': title,
          'description': description,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return LegalAidRequest.fromJson(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          'Failed to create request: ${errorData['detail'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      throw Exception('Error creating legal aid request: $e');
    }
  }

  // Get user's legal aid requests
  static Future<List<LegalAidRequest>> getUserLegalAidRequests(
    String userId,
  ) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/legal-aid-requests/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => LegalAidRequest.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load user requests: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching user requests: $e');
    }
  }

  // Get provider's legal aid requests
  static Future<List<LegalAidRequest>> getProviderLegalAidRequests(
    String providerId,
  ) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/legal-aid-requests/provider/$providerId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => LegalAidRequest.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load provider requests: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching provider requests: $e');
    }
  }

  // Update request status
  static Future<bool> updateRequestStatus(
    String requestId,
    String status,
  ) async {
    try {
      final url = await baseUrl;
      final response = await http.put(
        Uri.parse('$url/legal-aid-requests/$requestId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          'Failed to update status: ${errorData['detail'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      throw Exception('Error updating request status: $e');
    }
  }

  // Get expertise areas (helper method)
  static Future<List<ExpertiseArea>> getExpertiseAreas() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/expertise-areas'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ExpertiseArea.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load expertise areas: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching expertise areas: $e');
    }
  }
}
