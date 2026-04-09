import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two-level cache: fast in-memory map + SharedPreferences persistence.
/// 
/// Usage:
///   final json = await CacheService.get('police_stations');
///   await CacheService.set('police_stations', jsonString, const Duration(minutes: 5));
///   await CacheService.invalidate('police_stations');
class CacheService {
  CacheService._();

  static final Map<String, _CacheEntry> _mem = {};

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Returns cached JSON string if it exists and hasn't expired, else null.
  static Future<String?> get(String key) async {
    // 1. Memory hit (fastest)
    final mem = _mem[key];
    if (mem != null && !mem.isExpired) return mem.data;

    // 2. Persistent hit
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('cache_$key');
      final expiry = prefs.getInt('cache_exp_$key') ?? 0;
      if (data != null && DateTime.now().millisecondsSinceEpoch < expiry) {
        _mem[key] = _CacheEntry(data, DateTime.fromMillisecondsSinceEpoch(expiry));
        return data;
      }
    } catch (e) {
      debugPrint('CacheService.get error: $e');
    }
    return null;
  }

  /// Typed helper — decodes the cached JSON automatically.
  static Future<List<dynamic>?> getList(String key) async {
    final raw = await get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  /// Stores [data] in memory and SharedPreferences with the given [ttl].
  static Future<void> set(String key, String data, Duration ttl) async {
    final expiry = DateTime.now().add(ttl);
    _mem[key] = _CacheEntry(data, expiry);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_$key', data);
      await prefs.setInt('cache_exp_$key', expiry.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('CacheService.set error: $e');
    }
  }

  /// Convenience: serialize a List to JSON before storing.
  static Future<void> setList(String key, List<dynamic> data, Duration ttl) =>
      set(key, jsonEncode(data), ttl);

  // ── Invalidate ──────────────────────────────────────────────────────────────

  static Future<void> invalidate(String key) async {
    _mem.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_$key');
      await prefs.remove('cache_exp_$key');
    } catch (_) {}
  }

  /// Alias for [invalidate].
  static Future<void> remove(String key) => invalidate(key);

  static void invalidateAll() => _mem.clear();
}

class _CacheEntry {
  final String data;
  final DateTime expiry;
  _CacheEntry(this.data, this.expiry);
  bool get isExpired => DateTime.now().isAfter(expiry);
}
