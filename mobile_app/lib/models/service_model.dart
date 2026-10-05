class ServiceModel {
  final int id;
  final String title;
  final String? description;
  final double price;
  final int deliveryDays;
  final bool active;

  ServiceModel({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.deliveryDays,
    this.active = true,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      deliveryDays: json['deliveryDays'],
      active: json['active'] ?? true,
    );
  }
}
