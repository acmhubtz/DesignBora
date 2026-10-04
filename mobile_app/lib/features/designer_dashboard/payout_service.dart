import '../../core/api/api_client.dart';

class PayoutItem {
  final int id;
  final int orderId;
  final double amount;
  final String status; // PENDING | PROCESSING | PROCESSED | FAILED
  final String? channel; // MOBILE | BANK
  final String? destination;
  final String? failureReason;

  PayoutItem({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.status,
    this.channel,
    this.destination,
    this.failureReason,
  });

  factory PayoutItem.fromJson(Map<String, dynamic> json) => PayoutItem(
    id: json['id'],
    orderId: json['orderId'],
    amount: (json['amount'] as num).toDouble(),
    status: json['status'] ?? 'PENDING',
    channel: json['channel'],
    destination: json['destination'],
    failureReason: json['failureReason'],
  );
}

class MyPayouts {
  final String payoutMethod; // MOBILE | BANK
  final String? payoutPhone;
  final String? bankName;
  final String? bankBic;
  final String? accountNumber;
  final String? accountName;
  final bool ready;
  final double totalPaid;
  final double pendingAmount;
  final List<PayoutItem> payouts;

  MyPayouts({
    required this.payoutMethod,
    this.payoutPhone,
    this.bankName,
    this.bankBic,
    this.accountNumber,
    this.accountName,
    required this.ready,
    required this.totalPaid,
    required this.pendingAmount,
    required this.payouts,
  });

  bool get isBank => payoutMethod == 'BANK';

  factory MyPayouts.fromJson(Map<String, dynamic> json) {
    final list = json['payouts'];
    return MyPayouts(
      payoutMethod: json['payoutMethod'] ?? 'MOBILE',
      payoutPhone: json['payoutPhone'],
      bankName: json['bankName'],
      bankBic: json['bankBic'],
      accountNumber: json['accountNumber'],
      accountName: json['accountName'],
      ready: json['ready'] == true,
      totalPaid: (json['totalPaid'] as num? ?? 0).toDouble(),
      pendingAmount: (json['pendingAmount'] as num? ?? 0).toDouble(),
      payouts: list is List
          ? list
                .whereType<Map<String, dynamic>>()
                .map(PayoutItem.fromJson)
                .toList()
          : const [],
    );
  }
}

class BankOption {
  final String name;
  final String bic;
  BankOption(this.name, this.bic);
}

class PayoutService {
  final ApiClient _apiClient = ApiClient();

  Future<MyPayouts> getMine() async {
    final response = await _apiClient.dio.get('/payouts/me');
    return MyPayouts.fromJson(response.data['data']);
  }

  Future<List<BankOption>> getBanks() async {
    final response = await _apiClient.dio.get('/payouts/banks');
    final List data = response.data['data'];
    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (b) => BankOption(
            b['name']?.toString() ?? '',
            b['bic']?.toString() ?? '',
          ),
        )
        .where((b) => b.bic.isNotEmpty)
        .toList();
  }

  Future<MyPayouts> setMobile(String phone) async {
    final response = await _apiClient.dio.put(
      '/payouts/me/method',
      data: {'method': 'MOBILE', 'phone': phone},
    );
    return MyPayouts.fromJson(response.data['data']);
  }

  Future<MyPayouts> setBank({
    required String bic,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final response = await _apiClient.dio.put(
      '/payouts/me/method',
      data: {
        'method': 'BANK',
        'bic': bic,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName,
      },
    );
    return MyPayouts.fromJson(response.data['data']);
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
