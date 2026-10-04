class ChatMessageModel {
  final int? id;
  final int senderId;
  final String senderName;
  final String message;
  final String sentAt;

  ChatMessageModel({
    this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.sentAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      senderId: json['senderId'] ?? json['sender']?['id'],
      senderName:
          json['senderName'] ?? json['sender']?['fullName'] ?? 'Mtumiaji',
      message: json['message'] ?? '',
      sentAt: json['sentAt'] ?? '',
    );
  }
}
