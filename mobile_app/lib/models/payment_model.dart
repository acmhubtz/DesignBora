class PaymentModel {
  final int id;
  final int orderId;
  final String method; // MOBILE | CARD
  final String? provider;
  final String status; // PENDING | SUCCESS | FAILED
  final double amount;
  final String? checkoutUrl;
  final String? failureReason;

  PaymentModel({
    required this.id,
    required this.orderId,
    required this.method,
    this.provider,
    required this.status,
    required this.amount,
    this.checkoutUrl,
    this.failureReason,
  });

  bool get isPending => status == 'PENDING';
  bool get isSuccess => status == 'SUCCESS';
  bool get isFailed => status == 'FAILED';

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'],
      orderId: json['orderId'],
      method: json['method'],
      provider: json['provider'],
      status: json['status'],
      amount: (json['amount'] as num).toDouble(),
      checkoutUrl: json['checkoutUrl'],
      failureReason: json['failureReason'],
    );
  }
}
