import '../../core/api/api_client.dart';
import '../../models/category_model.dart';
import '../../models/search_result_model.dart';

class CatalogService {
  final ApiClient _apiClient = ApiClient();

  Future<List<CategoryModel>> getTopCategories() async {
    final response = await _apiClient.dio.get('/categories');
    final List data = response.data['data'];
    return data.map((json) => CategoryModel.fromJson(json)).toList();
  }

  Future<List<CategoryModel>> getSubCategories(int parentId) async {
    final response = await _apiClient.dio.get('/categories/$parentId/children');
    final List data = response.data['data'];
    return data.map((json) => CategoryModel.fromJson(json)).toList();
  }

  Future<List<SearchResultModel>> search({
    String? categorySlug,
    String? query,
  }) async {
    final response = await _apiClient.dio.get(
      '/search',
      queryParameters: {'category': ?categorySlug, 'q': ?query},
    );
    final List data = response.data['data'];
    return data.map((json) => SearchResultModel.fromJson(json)).toList();
  }
}
