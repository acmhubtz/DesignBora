class SearchResultModel {
  final int serviceId;
  final String serviceTitle;
  final double price;
  final int deliveryDays;
  final int designerId;
  final String designerName;
  final String? designerAvatarUrl;
  final bool verified;
  final double compositeScore;
  final double avgStarRating;

  SearchResultModel({
    required this.serviceId,
    required this.serviceTitle,
    required this.price,
    required this.deliveryDays,
    required this.designerId,
    required this.designerName,
    this.designerAvatarUrl,
    required this.verified,
    required this.compositeScore,
    required this.avgStarRating,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    return SearchResultModel(
      serviceId: json['serviceId'],
      serviceTitle: json['serviceTitle'],
      price: (json['price'] as num).toDouble(),
      deliveryDays: json['deliveryDays'],
      designerId: json['designerId'],
      designerName: json['designerName'] ?? 'Designer',
      designerAvatarUrl: json['designerAvatarUrl'],
      verified: json['verified'] ?? false,
      compositeScore: (json['compositeScore'] as num?)?.toDouble() ?? 0.5,
      avgStarRating: (json['avgStarRating'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
