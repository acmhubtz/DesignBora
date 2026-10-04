class DesignerMeModel {
  final int designerId;
  final String displayName;
  final String accountType;
  final String verificationStatus;
  final bool verified;
  final double compositeScore;
  final double avgStarRating;
  final int completedOrders;

  DesignerMeModel({
    required this.designerId,
    required this.displayName,
    required this.accountType,
    required this.verificationStatus,
    required this.verified,
    required this.compositeScore,
    required this.avgStarRating,
    required this.completedOrders,
  });

  factory DesignerMeModel.fromJson(Map<String, dynamic> json) {
    return DesignerMeModel(
      designerId: json['designerId'],
      displayName: json['displayName'] ?? 'Designer',
      accountType: json['accountType'] ?? 'INDIVIDUAL',
      verificationStatus: json['verificationStatus'] ?? 'PENDING',
      verified: json['verified'] ?? false,
      compositeScore: (json['compositeScore'] as num?)?.toDouble() ?? 0.5,
      avgStarRating: (json['avgStarRating'] as num?)?.toDouble() ?? 0.0,
      completedOrders: json['completedOrders'] ?? 0,
    );
  }
}
