class PortfolioModel {
  final int id;
  final String title;
  final String? description;
  final String thumbnailUrl;

  PortfolioModel({
    required this.id,
    required this.title,
    this.description,
    required this.thumbnailUrl,
  });

  factory PortfolioModel.fromJson(Map<String, dynamic> json) {
    return PortfolioModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      thumbnailUrl: json['thumbnailUrl'],
    );
  }
}
