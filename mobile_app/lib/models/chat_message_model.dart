class ChatMessageModel {
  final int? id;
  final int senderId;
  final String senderName;
  final String message;
  final String sentAt;

  // Faili la chat (maelezo/mfano) - si draft
  final int? attachmentId;
  final String? attachmentName;
  final int? attachmentSize;
  final String? attachmentType;
  final String? attachmentUrl;

  ChatMessageModel({
    this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.sentAt,
    this.attachmentId,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentType,
    this.attachmentUrl,
  });

  bool get hasAttachment => attachmentUrl != null && attachmentName != null;

  bool get isImage {
    final t = attachmentType ?? '';
    final n = (attachmentName ?? '').toLowerCase();
    return t.startsWith('image/') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif');
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      senderId: json['senderId'] ?? json['sender']?['id'],
      senderName:
          json['senderName'] ?? json['sender']?['fullName'] ?? 'Mtumiaji',
      message: json['message'] ?? '',
      sentAt: json['sentAt'] ?? '',
      attachmentId: (json['attachmentId'] as num?)?.toInt(),
      attachmentName: json['attachmentName'],
      attachmentSize: (json['attachmentSize'] as num?)?.toInt(),
      attachmentType: json['attachmentType'],
      attachmentUrl: json['attachmentUrl'],
    );
  }
}
