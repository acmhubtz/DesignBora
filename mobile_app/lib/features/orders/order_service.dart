import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../models/order_model.dart';
import '../../models/draft_model.dart';

class OrderService {
  final ApiClient _apiClient = ApiClient();

  Future<OrderModel> createOrder(int serviceId) async {
    final response = await _apiClient.dio.post(
      '/orders',
      data: {'serviceId': serviceId},
    );
    return OrderModel.fromJson(response.data['data']);
  }

  Future<OrderModel> markAsPaid(int orderId) async {
    final response = await _apiClient.dio.post('/orders/$orderId/mark-paid');
    return OrderModel.fromJson(response.data['data']);
  }

  Future<OrderModel> startWork(int orderId) async {
    final response = await _apiClient.dio.post('/orders/$orderId/start');
    return OrderModel.fromJson(response.data['data']);
  }

  Future<OrderModel> getOrder(int orderId) async {
    final response = await _apiClient.dio.get('/orders/$orderId');
    return OrderModel.fromJson(response.data['data']);
  }

  Future<List<DraftModel>> getDrafts(int orderId) async {
    final response = await _apiClient.dio.get('/orders/$orderId/drafts');
    final List data = response.data['data'];
    return data.map((json) => DraftModel.fromJson(json)).toList();
  }

  /// Mbunifu anatuma draft ya aina yoyote (picha, PDF, docx, psd, zip, video...).
  /// Inatumia bytes, kwa hiyo inafanya kazi kwenye web, Android na desktop.
  Future<void> submitDraft(
    int orderId, {
    required List<int> bytes,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });

    await _apiClient.dio.post(
      '/orders/$orderId/drafts',
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) onProgress(sent / total);
      },
    );
  }

  /// Inapatikana tu baada ya oda kuwa COMPLETED
  Future<({String url, String fileName})> getDraftDownload(
    int orderId,
    int draftId,
  ) async {
    final response = await _apiClient.dio.get(
      '/orders/$orderId/drafts/$draftId/download',
    );
    final data = response.data['data'] as Map;
    return (url: data['url'] as String, fileName: data['fileName'] as String);
  }

  /// Mteja anafungua mgogoro - pesa inabaki Escrow hadi admin aamue
  Future<void> openDispute(int orderId, String reason) async {
    await _apiClient.dio.post(
      '/orders/$orderId/dispute',
      data: {'reason': reason},
    );
  }

  Future<OrderModel> confirmCompletion(int orderId) async {
    final response = await _apiClient.dio.post(
      '/orders/$orderId/confirm-completion',
    );
    return OrderModel.fromJson(response.data['data']);
  }
}
