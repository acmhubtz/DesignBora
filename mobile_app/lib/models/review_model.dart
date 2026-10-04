class ReviewModel {
  final int id;
  final int starRating;
  final String? comment;
  final String createdAt;

  ReviewModel({
    required this.id,
    required this.starRating,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'],
      starRating: json['starRating'],
      comment: json['comment'],
      createdAt: json['createdAt'] ?? '',
    );
  }
}
