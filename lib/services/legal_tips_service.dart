import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:is_project_1/models/legal_tips_models.dart';
import 'package:is_project_1/services/api_service.dart';
import 'package:is_project_1/services/cache_service.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;
  ApiResponse({required this.success, this.data, this.error, this.statusCode});
}

class LegalTipsService {
  // ── Dynamic base URL — reads from .env every time ──────────────────────────
  String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://d2d35afcbdcd.ngrok-free.app';

  Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    if (token == null) throw Exception('Missing auth token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<String> _fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      String mimeType = 'image/jpeg';
      final ext = file.path.split('.').last.toLowerCase();
      switch (ext) {
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
      }
      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      throw Exception('Error converting image to base64: $e');
    }
  }

  // ── Create ─────────────────────────────────────────────────────────────────
  Future<ApiResponse<LegalTip>> createLegalTip({
    required String title,
    required String description,
    File? imageFile,
    TipStatus status = TipStatus.draft,
    required String legalAidProviderId,
  }) async {
    try {
      String? imageBase64;
      if (imageFile != null) imageBase64 = await _fileToBase64(imageFile);

      final request = CreateLegalTipRequest(
        title: title,
        description: description,
        imageBase64: imageBase64,
        status: status,
        legalAidProviderId: legalAidProviderId,
      );

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/legal-tips/create'),
        headers: await _headers(),
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse<LegalTip>(
          success: true,
          data: LegalTip.fromJson(jsonDecode(response.body)),
        );
      } else {
        final error = jsonDecode(response.body);
        return ApiResponse<LegalTip>(
          success: false,
          error: error['detail'] ?? 'Failed to create legal tip',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<LegalTip>(success: false, error: 'Network error: $e');
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────
  Future<ApiResponse<LegalTip>> updateLegalTip({
    required String tipId,
    String? title,
    String? description,
    File? imageFile,
    bool? removeImage,
    TipStatus? status,
  }) async {
    try {
      String? imageBase64;
      if (removeImage == true) {
        imageBase64 = '';
      } else if (imageFile != null) {
        imageBase64 = await _fileToBase64(imageFile);
      }

      final request = UpdateLegalTipRequest(
        title: title,
        description: description,
        imageBase64: imageBase64,
        status: status,
      );

      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/legal-tips/$tipId/update'),
        headers: await _headers(),
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        return ApiResponse<LegalTip>(
          success: true,
          data: LegalTip.fromJson(jsonDecode(response.body)),
        );
      } else {
        final error = jsonDecode(response.body);
        return ApiResponse<LegalTip>(
          success: false,
          error: error['detail'] ?? 'Failed to update legal tip',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<LegalTip>(success: false, error: 'Network error: $e');
    }
  }

  // ── Get all ────────────────────────────────────────────────────────────────
  Future<ApiResponse<List<LegalTip>>> getLegalTips({
    int skip = 0,
    int limit = 100,
    TipStatus? statusFilter,
    String? providerId,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'skip': skip.toString(),
        'limit': limit.toString(),
      };
      if (statusFilter != null)
        queryParams['status_filter'] = statusFilter.toString().split('.').last;
      if (providerId != null) queryParams['provider_id'] = providerId;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse(
        '$baseUrl/api/v1/legal-tips',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _headers());

      if (response.statusCode == 200) {
        final tips = (jsonDecode(response.body) as List)
            .map((j) => LegalTip.fromJson(j))
            .toList();
        return ApiResponse<List<LegalTip>>(success: true, data: tips);
      } else {
        final error = jsonDecode(response.body);
        return ApiResponse<List<LegalTip>>(
          success: false,
          error: error['detail'] ?? 'Failed to fetch legal tips',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<List<LegalTip>>(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  // ── Get specific tip ───────────────────────────────────────────────────────
  Future<ApiResponse<LegalTip>> getLegalTip(String tipId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/legal-tips/$tipId'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        return ApiResponse<LegalTip>(
          success: true,
          data: LegalTip.fromJson(jsonDecode(response.body)),
        );
      } else {
        final error = jsonDecode(response.body);
        return ApiResponse<LegalTip>(
          success: false,
          error: error['detail'] ?? 'Failed to fetch legal tip',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<LegalTip>(success: false, error: 'Network error: $e');
    }
  }

  // ── Update status ──────────────────────────────────────────────────────────
  Future<ApiResponse<LegalTip>> updateTipStatus({
    required String tipId,
    required TipStatus status,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/v1/legal-tips/$tipId/status'),
        headers: await _headers(),
        body: jsonEncode({'new_status': status.toString().split('.').last}),
      );

      if (response.statusCode == 200) {
        return ApiResponse<LegalTip>(
          success: true,
          data: LegalTip.fromJson(jsonDecode(response.body)),
        );
      } else {
        final error = jsonDecode(response.body);
        return ApiResponse<LegalTip>(
          success: false,
          error: error['detail'] ?? 'Failed to update tip status',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<LegalTip>(success: false, error: 'Network error: $e');
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<ApiResponse<void>> deleteLegalTip(String tipId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/legal-tips/$tipId'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        return ApiResponse<void>(success: true);
      } else {
        final error = jsonDecode(response.body);
        return ApiResponse<void>(
          success: false,
          error: error['detail'] ?? 'Failed to delete legal tip',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<void>(success: false, error: 'Network error: $e');
    }
  }

  // ── Get by provider ────────────────────────────────────────────────────────
  Future<ApiResponse<List<LegalTip>>> getTipsByProvider({
    required String providerId,
    int skip = 0,
    int limit = 100,
    TipStatus? statusFilter,
  }) async {
    try {
      final queryParams = <String, String>{
        'skip': skip.toString(),
        'limit': limit.toString(),
      };
      if (statusFilter != null)
        queryParams['status_filter'] = statusFilter.toString().split('.').last;

      final uri = Uri.parse(
        '$baseUrl/api/v1/legal-tips/provider/$providerId',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _headers());

      if (response.statusCode == 200) {
        final tips = (jsonDecode(response.body) as List)
            .map((j) => LegalTip.fromJson(j))
            .toList();
        return ApiResponse<List<LegalTip>>(success: true, data: tips);
      } else {
        final error = jsonDecode(response.body);
        return ApiResponse<List<LegalTip>>(
          success: false,
          error: error['detail'] ?? 'Failed to fetch provider tips',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<List<LegalTip>>(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  // ── Get recent published — cache-first, 10-minute TTL ─────────────────────
  Future<ApiResponse<List<LegalTip>>> getRecentPublishedTips({
    int limit = 10,
  }) async {
    final cacheKey = 'legal_tips_published_$limit';
    // Return cached instantly
    final cached = await CacheService.getList(cacheKey);
    if (cached != null) {
      final tips = cached
          .map((j) => LegalTip.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      return ApiResponse<List<LegalTip>>(success: true, data: tips);
    }
    try {
      final response = await http
          .get(
            Uri.parse(
                '$baseUrl/api/v1/legal-tips/published/recent?limit=$limit'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body) as List;
        await CacheService.setList(
            cacheKey, raw, const Duration(minutes: 10));
        final tips = raw.map((j) => LegalTip.fromJson(j)).toList();
        return ApiResponse<List<LegalTip>>(success: true, data: tips);
      } else {
        final error = jsonDecode(response.body);
        return ApiResponse<List<LegalTip>>(
          success: false,
          error: error['detail'] ?? 'Failed to fetch recent tips',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<List<LegalTip>>(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  // ── Upload base64 image ────────────────────────────────────────────────────
  Future<ApiResponse<String>> uploadBase64Image({
    required String base64Data,
    String? filename,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/legal-tips/upload-base64-image'),
        headers: await _headers(),
        body: jsonEncode({'image_data': base64Data, 'filename': filename}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse<String>(success: true, data: data['image_url']);
      } else {
        final error = jsonDecode(response.body);
        return ApiResponse<String>(
          success: false,
          error: error['detail'] ?? 'Failed to upload image',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<String>(success: false, error: 'Network error: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Future<ApiResponse<LegalTip>> publishTip(String tipId) =>
      updateTipStatus(tipId: tipId, status: TipStatus.published);

  Future<ApiResponse<LegalTip>> saveAsDraft(String tipId) =>
      updateTipStatus(tipId: tipId, status: TipStatus.draft);

  Future<ApiResponse<LegalTip>> archiveTip(String tipId) =>
      updateTipStatus(tipId: tipId, status: TipStatus.archived);
}
