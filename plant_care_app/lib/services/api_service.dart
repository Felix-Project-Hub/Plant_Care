// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../utils/session.dart';

class ApiService {
  static Uri _auth(String path) => Uri.parse('${AppConfig.baseUrl}$path');
  static Uri _psw(String path) => Uri.parse('${AppConfig.pswBaseUrl}$path');
  static Uri _hp(String path) => Uri.parse('${AppConfig.homepageBaseUrl}$path');
  static Uri _plant(String path) => Uri.parse('${AppConfig.plantBaseUrl}$path');
  static Uri _ai(String path) => Uri.parse('${AppConfig.aiBaseUrl}$path');

  static Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };

  static Future<http.Response> _post(
    Uri url, {
    Object? body,
    bool auth = true,
    bool retryOn401 = true,
  }) async {
    try {
      final headers = Map<String, String>.from(_jsonHeaders);
      final token = Session.accessToken;
      if (auth && token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final res = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 401 && retryOn401 && Session.refreshToken != null) {
        final ok = await _refreshTokens();
        if (ok) {
          return _post(url, body: body, auth: auth, retryOn401: false);
        }
      }

      return res;
    } on SocketException {
      throw ApiException(message: 'No internet connection', code: 0);
    } on TimeoutException {
      throw ApiException(message: 'Request timed out', code: 408);
    } catch (e) {
      throw ApiException(message: 'Network error: $e', code: 0);
    }
  }

  static Future<bool> _refreshTokens() async {
    final refreshToken = Session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final res = await _post(
      _auth('/refresh'),
      auth: false,
      retryOn401: false,
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return false;

    final data = _jsonAny(res);
    if (data is! Map<String, dynamic>) return false;
    final accessToken = data['access_token']?.toString();
    final newRefreshToken = data['refresh_token']?.toString();
    final accessExpiresAtRaw = data['access_expires_at']?.toString();
    final accessExpiresAt =
        accessExpiresAtRaw == null ? null : DateTime.tryParse(accessExpiresAtRaw);
    if (accessToken == null ||
        newRefreshToken == null ||
        accessExpiresAt == null ||
        accessToken.isEmpty ||
        newRefreshToken.isEmpty) {
      return false;
    }
    await Session.setTokens(
      accessToken: accessToken,
      refreshToken: newRefreshToken,
      accessExpiresAt: accessExpiresAt,
    );
    return true;
  }

  // ======================================================
  //                      Auth
  // ======================================================

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final res = await _post(
      _auth('/login'),
      auth: false,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _json(res);
    final user = data['user'] as Map<String, dynamic>?;
    final tokens = data['tokens'] as Map<String, dynamic>?;
    if (user == null || tokens == null) {
      throw ApiException(message: 'Invalid server response', code: res.statusCode);
    }
    final accessToken = tokens['access_token']?.toString();
    final refreshToken = tokens['refresh_token']?.toString();
    final accessExpiresAtRaw = tokens['access_expires_at']?.toString();
    final accessExpiresAt =
        accessExpiresAtRaw == null ? null : DateTime.tryParse(accessExpiresAtRaw);
    if (accessToken == null ||
        refreshToken == null ||
        accessExpiresAt == null ||
        accessToken.isEmpty ||
        refreshToken.isEmpty) {
      throw ApiException(message: 'Invalid token response', code: res.statusCode);
    }
    await Session.setAuth(
      email: (user['email'] ?? email).toString(),
      name: user['name']?.toString(),
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessExpiresAt: accessExpiresAt,
    );
  }

  static Future<void> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String birthday, // YYYYMMDD
  }) async {
    final res = await _post(
      _auth('/register'),
      auth: false,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'birthday': birthday,
      }),
    );
    final data = _json(res);
    final user = data['user'] as Map<String, dynamic>?;
    final tokens = data['tokens'] as Map<String, dynamic>?;
    if (user == null || tokens == null) {
      throw ApiException(message: 'Invalid server response', code: res.statusCode);
    }
    final accessToken = tokens['access_token']?.toString();
    final refreshToken = tokens['refresh_token']?.toString();
    final accessExpiresAtRaw = tokens['access_expires_at']?.toString();
    final accessExpiresAt =
        accessExpiresAtRaw == null ? null : DateTime.tryParse(accessExpiresAtRaw);
    if (accessToken == null ||
        refreshToken == null ||
        accessExpiresAt == null ||
        accessToken.isEmpty ||
        refreshToken.isEmpty) {
      throw ApiException(message: 'Invalid token response', code: res.statusCode);
    }
    await Session.setAuth(
      email: (user['email'] ?? email).toString(),
      name: user['name']?.toString(),
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessExpiresAt: accessExpiresAt,
    );
  }

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final res = await _post(
      _psw('/found_psw'),
      auth: false,
      body: jsonEncode({'email': email}),
    );
    return _json(res);
  }

  // ======================================================
  //                     Homepage
  // ======================================================

  /// 公告列表：POST /search_announcements（不需 body）
  static Future<List<Map<String, dynamic>>> searchAnnouncements() async {
    final res = await _post(
      _hp('/search_announcements'),
      auth: false,
      body: jsonEncode({}), // 後端不需要，但維持 JSON
    );
    final data = _jsonAny(res);
    if (data is Map<String, dynamic>) {
      final list = (data['results'] as List?) ?? const [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ======================================================
  //                       Plant
  // ======================================================

  /// 取得使用者的植物資訊：POST /get_plant_info
  static Future<List<Map<String, dynamic>>> getPlantInfo() async {
    final email = Session.email;
    if (email == null || email.isEmpty) {
      throw ApiException(message: 'Unauthorized', code: 401);
    }
    final res = await _post(
      _plant('/get_plant_info'),
      body: jsonEncode({'email': email}),
    );
    final data = _jsonAny(res);
    if (data is Map<String, dynamic>) {
      final list = (data['results'] as List?) ?? const [];
      final normalized = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(_normalizePlant)
          .toList();
      return normalized;
    }
    if (data is List) {
      return data
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(_normalizePlant)
          .toList();
    }
    return [];
  }

  static Map<String, dynamic> _normalizePlant(Map<String, dynamic> p) {
    final t = p['task'];
    if (t is String) {
      dynamic decoded;
      try {
        decoded = jsonDecode(t);
        if (decoded is String) decoded = jsonDecode(decoded);
      } catch (_) {
        decoded = null;
      }
      if (decoded is Map) {
        p['task'] = Map<String, dynamic>.from(decoded);
      }
    }
    return p;
  }

  /// 建立植物
  static Future<Map<String, dynamic>> createPlant({
    required String plantVariety,
    required String plantName,
    required String plantState, // seedling/growing/stable
    required String setupTime, // YYYYMMDD
  }) async {
    final email = Session.email;
    if (email == null || email.isEmpty) {
      throw ApiException(message: 'Unauthorized', code: 401);
    }
    final state = plantState.trim().toLowerCase();

    final url = _plant('/create_plant');
    final payload = {
      'plant_variety': plantVariety.trim(),
      'plant_name': plantName.trim(),
      'plant_state': state,
      'setup_time': setupTime.trim(),
      'email': email.trim(),
    };

    final res = await _post(url, body: jsonEncode(payload));

    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      data = res.body;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Request failed';
      if (data is Map<String, dynamic>) {
        msg = data['message']?.toString() ?? data['error']?.toString() ?? msg;
      } else if (data is String && data.isNotEmpty) {
        msg = data;
      }
      throw ApiException(message: msg, code: res.statusCode);
    }
    if (data is Map<String, dynamic>) return data;
    return {'message': 'OK', 'data': data};
  }

  /// 初始化植物（拿任務）
  static Future<bool> initializePlant({
    required String uuid,
    required String todayState,
    required String lastWateringTime, // YYYYMMDDhhmmss
  }) async {
    final email = Session.email;
    if (email == null || email.isEmpty) {
      throw ApiException(message: 'Unauthorized', code: 401);
    }
    final url = _plant('/initialize_plant');
    final payload = {
      'uuid': uuid,
      'email': email,
      'today_state': todayState,
      'last_watering_time': lastWateringTime,
    };

    final res = await _post(url, body: jsonEncode(payload));

    return res.statusCode >= 200 && res.statusCode < 300;
  }

  /// ✅ NEW: 更新任務狀態（整包 task 送回去）
  /// API: /update_plant_task
  /// body: { uuid, email, task: { task_1: {...}, ... } }
  static Future<bool> updatePlantTask({
    required String uuid,
    required Map<String, dynamic> task,
  }) async {
    final email = Session.email;
    if (email == null || email.isEmpty) {
      throw ApiException(message: 'Unauthorized', code: 401);
    }
    final url = _plant('/update_plant_task');

    final payload = {'uuid': uuid, 'email': email, 'task': task};

    final res = await _post(url, body: jsonEncode(payload));

    if (res.statusCode < 200 || res.statusCode >= 300) return false;

    // ✅ 有些後端即使失敗也回 200，所以額外看 message
    try {
      final data = jsonDecode(res.body);
      if (data is Map && data['message'] != null) {
        final msg = data['message'].toString().toLowerCase();
        if (msg.contains('fail') || msg.contains('error')) return false;
      }
    } catch (_) {}

    return true;
  }

  static Future<Map<String, dynamic>> generateTasks({
    required String plantVariety,
    required String plantState,
    int count = 6,
  }) async {
    final res = await _post(
      _ai('/generate_tasks'),
      body: jsonEncode({
        'plant_variety': plantVariety,
        'plant_state': plantState,
        'count': count,
        'locale': 'zh-TW',
      }),
    );
    return _json(res);
  }

  // ======================================================
  //                      Helpers
  // ======================================================

  /// 嚴格 Map 輸出；非 2xx 丟 ApiException(message)
  static Map<String, dynamic> _json(http.Response res) {
    Map<String, dynamic> data;
    try {
      final body = res.body.isEmpty ? '{}' : res.body;
      data = Map<String, dynamic>.from(jsonDecode(body) as Map);
    } catch (_) {
      data = {'message': 'Invalid server response'};
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        message:
            data['message']?.toString() ?? data['detail']?.toString() ?? 'Request failed',
        code: res.statusCode,
      );
    }
    return data;
  }

  /// 寬鬆任何型別輸出；非 2xx 丟 ApiException(message)
  static dynamic _jsonAny(http.Response res) {
    dynamic data;
    try {
      final body = res.body.isEmpty ? 'null' : res.body;
      data = jsonDecode(body);
    } catch (_) {
      data = res.body;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Request failed';
      if (data is Map<String, dynamic>) {
        msg = data['message']?.toString() ?? msg;
      } else if (data is String && data.isNotEmpty) {
        msg = data.length > 200 ? data.substring(0, 200) : data;
      }
      throw ApiException(message: msg, code: res.statusCode);
    }
    return data;
  }

  static dynamic tryDecodeJson(String s) => jsonDecode(s);
}

class ApiException implements Exception {
  final String message;
  final int code;
  ApiException({required this.message, required this.code});
  @override
  String toString() => 'ApiException($code): $message';
}
