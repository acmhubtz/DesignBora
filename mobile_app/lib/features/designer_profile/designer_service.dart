import '../../core/api/api_client.dart';
import '../../models/portfolio_model.dart';
import '../../models/service_model.dart';
import '../../models/review_model.dart';

class DesignerService {
  final ApiClient _apiClient = ApiClient();

  Future<List<PortfolioModel>> getPortfolio(int designerId) async {
    final response = await _apiClient.dio.get(
      '/portfolio/designer/$designerId',
    );
    final List data = response.data['data'];
    return data.map((json) => PortfolioModel.fromJson(json)).toList();
  }

  Future<List<ServiceModel>> getServices(int designerId) async {
    final response = await _apiClient.dio.get('/services/designer/$designerId');
    final List data = response.data['data'];
    return data.map((json) => ServiceModel.fromJson(json)).toList();
  }

  Future<List<ReviewModel>> getReviews(int designerId) async {
    final response = await _apiClient.dio.get('/reviews/designer/$designerId');
    final List data = response.data['data'];
    return data.map((json) => ReviewModel.fromJson(json)).toList();
  }
}
