import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../models/profile_model.dart';

class ProfileService {
  final ApiClient _apiClient = ApiClient();

  Future<ProfileModel> getMe() async {
    final response = await _apiClient.dio.get('/users/me');
    return ProfileModel.fromJson(response.data['data']);
  }

  Future<ProfileModel> updateMe({
    required String fullName,
    String? email,
  }) async {
    final response = await _apiClient.dio.put(
      '/users/me',
      data: {'fullName': fullName, 'email': email},
    );
    return ProfileModel.fromJson(response.data['data']);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.dio.post(
      '/users/me/password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<ProfileModel> uploadAvatar(XFile file) async {
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: file.name),
    });
    final response = await _apiClient.dio.post(
      '/users/me/avatar',
      data: formData,
    );
    return ProfileModel.fromJson(response.data['data']);
  }

  Future<ProfileModel> removeAvatar() async {
    final response = await _apiClient.dio.delete('/users/me/avatar');
    return ProfileModel.fromJson(response.data['data']);
  }

  /// Ujumbe wa kosa kutoka backend (kama upo)
  static String? errorMessage(Object e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data != null && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return null;
  }
}
