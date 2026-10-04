class ProfileModel {
  final int id;
  final String fullName;
  final String? email;
  final String phone;
  final String role;
  final String? avatarUrl;

  ProfileModel({
    required this.id,
    required this.fullName,
    this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
  });

  bool get isDesigner => role == 'DESIGNER';

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      fullName: json['fullName'] ?? '',
      email: json['email'],
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      avatarUrl: json['avatarUrl'],
    );
  }
}
