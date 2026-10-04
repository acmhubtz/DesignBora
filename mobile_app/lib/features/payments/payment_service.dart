import '../../core/api/api_client.dart';
import '../../models/payment_model.dart';

class PaymentService {
  final ApiClient _apiClient = ApiClient();

  Future<PaymentModel> initiate({
    required int orderId,
    required String method,
    String? provider,
    String? phone,
  }) async {
    final response = await _apiClient.dio.post(
      '/orders/$orderId/payments',
      data: {'method': method, 'provider': ?provider, 'phone': ?phone},
    );
    return PaymentModel.fromJson(response.data['data']);
  }

  Future<PaymentModel> getPayment(int paymentId) async {
    final response = await _apiClient.dio.get('/payments/$paymentId');
    return PaymentModel.fromJson(response.data['data']);
  }
}
