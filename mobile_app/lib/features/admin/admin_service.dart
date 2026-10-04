import '../../core/api/api_client.dart';

class AdminDocument {
  final int id;
  final String documentType;
  final String status;
  final String? uploadedAt;
  final String extension;

  AdminDocument({
    required this.id,
    required this.documentType,
    required this.status,
    this.uploadedAt,
    required this.extension,
  });

  factory AdminDocument.fromJson(Map<String, dynamic> json) => AdminDocument(
    id: json['id'],
    documentType: json['documentType'] ?? 'OTHER',
    status: json['status'] ?? 'PENDING',
    uploadedAt: json['uploadedAt']?.toString(),
    extension: json['extension'] ?? '',
  );
}

class AdminDesigner {
  final int designerId;
  final String fullName;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final String? accountType;
  final String? companyName;
  final String? companyRegNumber;
  final String verificationStatus;
  final String? verificationNote;
  final String? createdAt;
  final List<AdminDocument> documents;

  AdminDesigner({
    required this.designerId,
    required this.fullName,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.accountType,
    this.companyName,
    this.companyRegNumber,
    required this.verificationStatus,
    this.verificationNote,
    this.createdAt,
    required this.documents,
  });

  factory AdminDesigner.fromJson(Map<String, dynamic> json) {
    final docs = json['documents'];
    return AdminDesigner(
      designerId: json['designerId'],
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      avatarUrl: json['avatarUrl'],
      accountType: json['accountType'],
      companyName: json['companyName'],
      companyRegNumber: json['companyRegNumber'],
      verificationStatus: json['verificationStatus'] ?? 'PENDING',
      verificationNote: json['verificationNote'],
      createdAt: json['createdAt']?.toString(),
      documents: docs is List
          ? docs
                .whereType<Map<String, dynamic>>()
                .map(AdminDocument.fromJson)
                .toList()
          : const [],
    );
  }
}

class AdminStats {
  final int pending;
  final int verified;
  final int rejected;

  AdminStats({
    required this.pending,
    required this.verified,
    required this.rejected,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
    pending: (json['pending'] as num? ?? 0).toInt(),
    verified: (json['verified'] as num? ?? 0).toInt(),
    rejected: (json['rejected'] as num? ?? 0).toInt(),
  );
}

class AdminService {
  final ApiClient _apiClient = ApiClient();

  Future<AdminStats> getStats() async {
    final response = await _apiClient.dio.get('/admin/verification/stats');
    return AdminStats.fromJson(response.data['data']);
  }

  Future<List<AdminDesigner>> getDesigners(String status) async {
    final response = await _apiClient.dio.get(
      '/admin/verification/designers',
      queryParameters: {'status': status},
    );
    final List data = response.data['data'];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AdminDesigner.fromJson)
        .toList();
  }

  Future<void> approve(int designerId) async {
    await _apiClient.dio.post(
      '/admin/verification/designers/$designerId/approve',
    );
  }

  Future<void> reject(int designerId, String reason) async {
    await _apiClient.dio.post(
      '/admin/verification/designers/$designerId/reject',
      data: {'reason': reason},
    );
  }

  /// Kiungo cha muda (dakika 5) cha kufungua nyaraka kwenye kivinjari
  Future<String> documentLink(int documentId) async {
    final response = await _apiClient.dio.post(
      '/verification-documents/$documentId/link',
    );
    return response.data['data']['url'] as String;
  }

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
