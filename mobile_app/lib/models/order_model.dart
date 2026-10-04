class OrderModel {
  final int id;
  final String status;
  final double grossAmount;
  final double platformFee;
  final double netAmount;
  final String? expectedDeliveryAt;
  final String? designerName;
  final String? customerName;
  final String? serviceTitle;
  final String? customerPhone;
  final String? designerPhone;
  final String? customerAvatarUrl;
  final String? designerAvatarUrl;

  OrderModel({
    required this.id,
    required this.status,
    required this.grossAmount,
    required this.platformFee,
    required this.netAmount,
    this.expectedDeliveryAt,
    this.designerName,
    this.customerName,
    this.serviceTitle,
    this.customerPhone,
    this.designerPhone,
    this.customerAvatarUrl,
    this.designerAvatarUrl,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    Map? asMap(Object? value) => value is Map ? value : null;

    final service = asMap(json['service']);
    final designer = asMap(json['designer']);
    final designerUser = asMap(designer?['user']);
    final customer = asMap(json['customer']);
    final serviceDesigner = asMap(service?['designer']);

    return OrderModel(
      id: json['id'],
      status: json['status'],
      grossAmount: (json['grossAmount'] as num).toDouble(),
      platformFee: (json['platformFee'] as num).toDouble(),
      netAmount: (json['netAmount'] as num).toDouble(),
      expectedDeliveryAt: json['expectedDeliveryAt'],
      designerName:
          json['designerName'] ??
          designerUser?['fullName'] ??
          designer?['fullName'] ??
          designer?['displayName'] ??
          serviceDesigner?['fullName'],
      customerName: json['customerName'] ?? customer?['fullName'],
      serviceTitle: json['serviceTitle'] ?? service?['title'],
      customerPhone: customer?['phone'],
      designerPhone: designerUser?['phone'],
      customerAvatarUrl: customer?['avatarUrl'],
      designerAvatarUrl: designerUser?['avatarUrl'],
    );
  }
}
