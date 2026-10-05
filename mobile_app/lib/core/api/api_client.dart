import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _userNameKey = 'user_name';
  static const _userRoleKey = 'user_role';

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          return handler.next(error);
        },
      ),
    );
  }

  // ---------- Kipindi (session) ----------

  Future<void> saveSession({
    required String token,
    required int userId,
    required String fullName,
    required String role,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId.toString());
    await _storage.write(key: _userNameKey, value: fullName);
    await _storage.write(key: _userRoleKey, value: role);
  }

  /// Kipindi kilichohifadhiwa; null kama hakipo au token imeisha muda
  Future<({String token, int userId, String fullName, String role})?>
  readSession() async {
    final token = await _storage.read(key: _tokenKey);
    final userId = int.tryParse(await _storage.read(key: _userIdKey) ?? '');
    final fullName = await _storage.read(key: _userNameKey);
    final role = await _storage.read(key: _userRoleKey);

    if (token == null || userId == null || fullName == null || role == null) {
      return null;
    }
    if (_isExpired(token)) {
      await clearToken();
      return null;
    }
    return (token: token, userId: userId, fullName: fullName, role: role);
  }

  Future<void> saveUserName(String fullName) async {
    await _storage.write(key: _userNameKey, value: fullName);
  }

  /// Inasoma muda wa kuisha (exp) ndani ya JWT; dakika 1 ya tahadhari
  static bool _isExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload['exp'];
      if (exp is! num) return false;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp - 60;
    } catch (_) {
      return true;
    }
  }

  // ---------- Njia za zamani (bado zinatumika) ----------

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> saveUserId(int userId) async {
    await _storage.write(key: _userIdKey, value: userId.toString());
  }

  Future<int?> getUserId() async {
    final value = await _storage.read(key: _userIdKey);
    return value == null ? null : int.tryParse(value);
  }

  /// Inafuta kipindi chote (inatumika wakati wa logout)
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userNameKey);
    await _storage.delete(key: _userRoleKey);
  }
}
