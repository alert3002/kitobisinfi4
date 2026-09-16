import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/ad_ids.dart';
import '../models/app_release.dart';

class ApiService {
  ApiService({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? kApiBaseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
                followRedirects: true,
                headers: const {
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;

  Future<bool> get isOnline async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<AdIds> fetchAds({required bool android}) async {
    try {
      final response = await _dio.get('/api/ads/');
      final list = response.data is Map
          ? (response.data['results'] as List? ?? const [])
          : (response.data as List? ?? const []);
      if (list.isEmpty) return AdIds.off;
      final json = list.first as Map<String, dynamic>;
      final enabled =
          json['ads_enabled'] == true || json['is_active'] == true;
      if (!enabled) return AdIds.off;
      String pick(String key, String platformKey) {
        final platform = (json[platformKey] as String?)?.trim() ?? '';
        final general = (json[key] as String?)?.trim() ?? '';
        return platform.isNotEmpty ? platform : general;
      }

      String unit(String raw, String fallback) {
        final id = raw.trim();
        if (id.isEmpty || id.contains('~')) return fallback;
        return id;
      }

      final test = AdIds.test(android: android);
      return AdIds(
        adsEnabled: true,
        bannerId: unit(
          pick('banner_id', android ? 'android_banner_id' : 'ios_banner_id'),
          test.bannerId,
        ),
        interstitialId: unit(
          pick(
            'interstitial_id',
            android ? 'android_interstitial_id' : 'ios_interstitial_id',
          ),
          test.interstitialId,
        ),
      );
    } catch (e) {
      debugPrint('Ads API: $e');
      return AdIds.off;
    }
  }

  Future<List<Map<String, dynamic>>> fetchClasses() async {
    try {
      final response = await _dio.get('/api/classes/');
      final data = response.data;
      if (data is Map && data['results'] is List) {
        return (data['results'] as List).cast<Map<String, dynamic>>();
      }
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Classes API: $e');
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> fetchGradeBooks(int grade) async {
    final response = await _dio.get(
      '/api/books/',
      queryParameters: {'grade': grade},
    );
    final data = response.data;
    if (data is Map && data['results'] is List) {
      return (data['results'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return const [];
  }

  Future<AppRelease?> fetchAppRelease() async {
    try {
      final response = await _dio.get('/api/app/');
      final data = response.data;
      if (data is Map && data.isNotEmpty && data['version_code'] != null) {
        return AppRelease.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint('App API: $e');
    }
    return null;
  }

  Future<List<AppNotice>> fetchNotices(int grade) async {
    try {
      final response = await _dio.get(
        '/api/notices/',
        queryParameters: {'grade': grade},
      );
      final rows = _asMaps(response.data);
      return rows.map(AppNotice.fromJson).where((n) => n.id > 0).toList();
    } catch (e) {
      debugPrint('Notices API: $e');
    }
    return const [];
  }

  List<Map<String, dynamic>> _asMaps(dynamic data) {
    if (data is Map && data['results'] is List) {
      return (data['results'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return const [];
  }
}

bool get isAndroidPhone => !kIsWeb && Platform.isAndroid;
bool get isMobileAdsPlatform =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);
