import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../models/user_model.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  Future<UserModel> login(String phone, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {'phone': phone, 'password': password},
      );

      final data = response.data['data'];
      final user = UserModel.fromJson(data);
      await _saveSession(user);
      return user;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserModel> register({
    required String fullName,
    required String phone,
    String? email,
    required String password,
    required String role,
    String? accountType,
    String? companyName,
    String? companyRegNumber,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/register',
        data: {
          'fullName': fullName,
          'phone': phone,
          'email': email,
          'password': password,
          'role': role,
          'accountType': ?accountType,
          'companyName': ?companyName,
          'companyRegNumber': ?companyRegNumber,
        },
      );

      final data = response.data['data'];
      final user = UserModel.fromJson(data);
      await _saveSession(user);
      return user;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    await _apiClient.clearToken();
  }

  Future<void> _saveSession(UserModel user) async {
    await _apiClient.saveSession(
      token: user.token,
      userId: user.userId,
      fullName: user.fullName,
      role: user.role,
    );
  }

  String _handleError(DioException e) {
    if (e.response != null && e.response?.data is Map) {
      final message = e.response?.data['message'];
      if (message != null) return message.toString();
    }
    return 'Hitilafu imetokea. Angalia mtandao wako.';
  }
}
