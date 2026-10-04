import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../models/designer_me_model.dart';
import '../../models/order_model.dart';
import '../../models/service_model.dart';
import '../../models/portfolio_model.dart';
import '../../models/category_model.dart';

class DesignerDashboardService {
  final ApiClient _apiClient = ApiClient();

  Future<DesignerMeModel> getMyProfile() async {
    final response = await _apiClient.dio.get('/designers/me');
    return DesignerMeModel.fromJson(response.data['data']);
  }

  Future<List<OrderModel>> getMyOrders() async {
    final response = await _apiClient.dio.get('/orders/mine/designer');
    final List data = response.data['data'];
    return data.map((json) => OrderModel.fromJson(json)).toList();
  }

  Future<List<ServiceModel>> getMyServices(int designerId) async {
    final response = await _apiClient.dio.get('/services/designer/$designerId');
    final List data = response.data['data'];
    return data.map((json) => ServiceModel.fromJson(json)).toList();
  }

  Future<List<PortfolioModel>> getMyPortfolio(int designerId) async {
    final response = await _apiClient.dio.get(
      '/portfolio/designer/$designerId',
    );
    final List data = response.data['data'];
    return data.map((json) => PortfolioModel.fromJson(json)).toList();
  }

  Future<List<CategoryModel>> getAllCategoriesFlat() async {
    final topResponse = await _apiClient.dio.get('/categories');
    final List topData = topResponse.data['data'];
    final topCategories = topData
        .map((json) => CategoryModel.fromJson(json))
        .toList();

    final List<CategoryModel> allCategories = [];
    for (final top in topCategories) {
      final childrenResponse = await _apiClient.dio.get(
        '/categories/${top.id}/children',
      );
      final List childrenData = childrenResponse.data['data'];
      if (childrenData.isEmpty) {
        allCategories.add(top);
      } else {
        allCategories.addAll(
          childrenData.map((json) => CategoryModel.fromJson(json)),
        );
      }
    }
    return allCategories;
  }

  Future<ServiceModel> createService({
    required int categoryId,
    required String title,
    String? description,
    required double price,
    required int deliveryDays,
  }) async {
    final response = await _apiClient.dio.post(
      '/services',
      data: {
        'categoryId': categoryId,
        'title': title,
        'description': description,
        'price': price,
        'deliveryDays': deliveryDays,
      },
    );
    return ServiceModel.fromJson(response.data['data']);
  }

  /// Inafanya kazi kwenye web, Android na desktop (inatumia bytes, si path ya faili)
  Future<PortfolioModel> createPortfolioItem({
    required int categoryId,
    required String title,
    String? description,
    required XFile imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final formData = FormData.fromMap({
      'categoryId': categoryId,
      'title': title,
      'description': description ?? '',
      'file': MultipartFile.fromBytes(bytes, filename: imageFile.name),
    });

    final response = await _apiClient.dio.post(
      '/portfolio',
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) onProgress(sent / total);
      },
    );
    return PortfolioModel.fromJson(response.data['data']);
  }
}
