import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/legal_aid_requests.dart';

class LegalRequestService {
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

  static Future<List<LegalAidRequest>> fetchLegalAidRequests(
    String userId,
  ) async {
    final url = await baseUrl;
    final response = await http.get(
      Uri.parse('$url/api/legal-aid-requests/user/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('=== DEBUG: Full Response ===');
      print('Response type: ${data.runtimeType}');
      print('Response data: $data');

      // Check if response is a list directly
      if (data is List) {
        print('Response is a List with ${data.length} items');
        return data.map((json) => LegalAidRequest.fromJson(json)).toList();
      }

      // Check if response has a 'requests' key
      if (data is Map && data.containsKey('requests')) {
        final requestsData = data['requests'];
        print('Found requests key, type: ${requestsData.runtimeType}');

        if (requestsData is List) {
          print('Requests is a List with ${requestsData.length} items');
          return requestsData
              .map((json) => LegalAidRequest.fromJson(json))
              .toList();
        }
      }

      // Handle null or empty response
      if (data == null) {
        print('Data is null, returning empty list');
        return <LegalAidRequest>[];
      }

      print('=== WARNING: Unexpected response format ===');
      print('Data type: ${data.runtimeType}');
      print('Data: $data');

      return <LegalAidRequest>[];
    } else {
      throw Exception('Failed to load requests: ${response.statusCode}');
    }
  }

  static Future<void> debugFetchLegalAidRequests(String userId) async {
    final url = await baseUrl;
    final response = await http.get(
      Uri.parse('$url/api/legal-aid-requests/user/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      print('=== DEBUG: Full API Response ===');
      print(json.encode(jsonData));

      // Check if legal_aid_provider data is present
      if (jsonData is List && jsonData.isNotEmpty) {
        final firstRequest = jsonData[0];
        print('=== DEBUG: First Request ===');
        print('Has user: ${firstRequest.containsKey('user')}');
        print(
          'Has legal_aid_provider: ${firstRequest.containsKey('legal_aid_provider')}',
        );

        if (firstRequest.containsKey('legal_aid_provider')) {
          print(
            'Legal Aid Provider Data: ${firstRequest['legal_aid_provider']}',
          );
        }
      }
    } else {
      print('Debug failed: ${response.statusCode}');
    }
  }

  // Fetch pending requests for a provider
  static Future<List<LegalAidRequest>> fetchPendingRequestsForProvider(
    String providerId,
  ) async {
    final url = await baseUrl;
    final response = await http.get(
      Uri.parse('$url/api/legal-aid-requests/provider/$providerId/pending'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List jsonData = json.decode(response.body);
      return jsonData.map((item) => LegalAidRequest.fromJson(item)).toList();
    } else {
      throw Exception(
        "Failed to load pending requests: ${response.statusCode}",
      );
    }
  }

  // Fetch accepted requests for a provider with user details
  // Updated fetchAcceptedRequestsForProvider method with better error handling
  static Future<List<LegalAidRequest>> fetchAcceptedRequestsForProvider(
    String providerId,
  ) async {
    final url = await baseUrl;
    final fullUrl = '$url/api/legal-aid-requests/provider/$providerId/accepted';

    print('DEBUG: Attempting to fetch from URL: $fullUrl');

    try {
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {'Content-Type': 'application/json'},
      );

      print('DEBUG: Response status code: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;

        // Handle empty response
        if (responseBody.isEmpty || responseBody == 'null') {
          print('DEBUG: Empty response body, returning empty list');
          return <LegalAidRequest>[];
        }

        try {
          final jsonData = json.decode(responseBody);
          print('DEBUG: Parsed JSON type: ${jsonData.runtimeType}');

          if (jsonData is List) {
            print('DEBUG: JSON is a list with ${jsonData.length} items');
            return jsonData
                .map((item) => LegalAidRequest.fromJson(item))
                .toList();
          } else {
            print('DEBUG: JSON is not a list: $jsonData');
            return <LegalAidRequest>[];
          }
        } catch (jsonError) {
          print('DEBUG: JSON parsing error: $jsonError');
          print('DEBUG: Raw response: $responseBody');
          throw Exception('Failed to parse JSON response: $jsonError');
        }
      } else {
        print('DEBUG: HTTP error ${response.statusCode}: ${response.body}');
        throw Exception(
          "Failed to load accepted requests: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print('DEBUG: Network or other error: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Network error: $e');
      }
    }
  }

  // Fetch processed requests for a provider (accepted/declined)
  static Future<List<LegalAidRequest>> fetchProcessedRequestsForProvider(
    String providerId,
  ) async {
    final url = await baseUrl;
    final response = await http.get(
      Uri.parse('$url/api/legal-aid-requests/provider/$providerId/processed'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List jsonData = json.decode(response.body);
      return jsonData.map((item) => LegalAidRequest.fromJson(item)).toList();
    } else {
      throw Exception(
        "Failed to load processed requests: ${response.statusCode}",
      );
    }
  }

  // Fetch all requests for a provider with user details (includes user info)
  static Future<List<LegalAidRequest>> fetchAllRequestsForProvider(
    String providerId,
  ) async {
    final url = await baseUrl;
    final response = await http.get(
      Uri.parse('$url/api/legal-aid-requests/provider/$providerId/all'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List jsonData = json.decode(response.body);
      return jsonData.map((item) => LegalAidRequest.fromJson(item)).toList();
    } else {
      throw Exception("Failed to load all requests: ${response.statusCode}");
    }
  }

  // Create a new legal aid request
  static Future<LegalAidRequest> createLegalAidRequest({
    required String userId,
    required String legalAidProviderId,
    required String title,
    required String description,
  }) async {
    final url = await baseUrl;
    final response = await http.post(
      Uri.parse('$url/api/legal-aid-requests'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'legal_aid_provider_id': legalAidProviderId,
        'title': title,
        'description': description,
      }),
    );

    if (response.statusCode == 201) {
      final jsonData = json.decode(response.body);
      return LegalAidRequest.fromJson(jsonData);
    } else {
      throw Exception("Failed to create request: ${response.statusCode}");
    }
  }

  // Update request status (for provider actions)
  static Future<LegalAidRequest> updateRequestStatus({
    required String requestId,
    required String status,
  }) async {
    final url = await baseUrl;
    final response = await http.patch(
      Uri.parse('$url/api/legal-aid-requests/$requestId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'status': status}),
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return LegalAidRequest.fromJson(jsonData);
    } else {
      throw Exception("Failed to update request: ${response.statusCode}");
    }
  }

  // Accept a legal aid request
  static Future<LegalAidRequest> acceptRequest({
    required String requestId,
  }) async {
    return await updateRequestStatus(requestId: requestId, status: 'accepted');
  }

  // Decline a legal aid request
  static Future<LegalAidRequest> declineRequest({
    required String requestId,
  }) async {
    return await updateRequestStatus(requestId: requestId, status: 'declined');
  }

  // Complete a legal aid request
  static Future<LegalAidRequest> completeRequest({
    required String requestId,
  }) async {
    return await updateRequestStatus(requestId: requestId, status: 'completed');
  }

  // Rate a completed request
  static Future<void> rateRequest({
    required String requestId,
    required int rating,
    String? comment,
  }) async {
    final url = await baseUrl;
    final response = await http.post(
      Uri.parse('$url/api/legal-aid-requests/$requestId/rate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'rating': rating, 'comment': comment}),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to rate request: ${response.statusCode}");
    }
  }

  // Get request details with user information
  static Future<LegalAidRequest> getRequestDetails(String requestId) async {
    final url = await baseUrl;
    final response = await http.get(
      Uri.parse('$url/api/legal-aid-requests/$requestId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return LegalAidRequest.fromJson(jsonData);
    } else {
      throw Exception("Failed to load request details: ${response.statusCode}");
    }
  }

  // ========== LEGAL AID PROVIDERS ==========

  // Fetch legal aid provider by ID
  static Future<LegalAidProvider> fetchProviderById(String providerId) async {
    final url = await baseUrl;
    final response = await http.get(
      Uri.parse('$url/api/legal-aid-providers/$providerId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return LegalAidProvider.fromJson(jsonData);
    } else {
      throw Exception("Failed to load provider: ${response.statusCode}");
    }
  }

  // Get all legal aid providers
  static Future<List<LegalAidProvider>> fetchAllProviders() async {
    final url = await baseUrl;
    final response = await http.get(
      Uri.parse('$url/api/legal-aid-providers'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List jsonData = json.decode(response.body);
      return jsonData.map((item) => LegalAidProvider.fromJson(item)).toList();
    } else {
      throw Exception("Failed to load providers: ${response.statusCode}");
    }
  }

  // Search providers by expertise area
  static Future<List<LegalAidProvider>> searchProvidersByExpertise(
    String expertiseArea,
  ) async {
    final url = await baseUrl;
    final response = await http.get(
      Uri.parse('$url/api/legal-aid-providers/search?expertise=$expertiseArea'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List jsonData = json.decode(response.body);
      return jsonData.map((item) => LegalAidProvider.fromJson(item)).toList();
    } else {
      throw Exception("Failed to search providers: ${response.statusCode}");
    }
  }

  // ========== USER MANAGEMENT ==========

  // Fetch user details by ID
  static Future<User> fetchUserById(String userId) async {
    final url = await baseUrl;
    final response = await http.get(
      Uri.parse('$url/api/users/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return User.fromJson(jsonData);
    } else {
      throw Exception("Failed to load user: ${response.statusCode}");
    }
  }
}
