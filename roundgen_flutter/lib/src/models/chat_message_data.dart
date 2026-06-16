class ChatMessageData {
  const ChatMessageData({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.doctorName,
    required this.patientName,
    required this.senderRole,
    required this.messageText,
    required this.sentAt,
    required this.isRead,
  });

  final int id;
  final int doctorId;
  final int patientId;
  final String doctorName;
  final String patientName;
  final String senderRole;
  final String messageText;
  final String sentAt;
  final bool isRead;

  factory ChatMessageData.fromJson(Map<String, dynamic> json) {
    return ChatMessageData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      doctorId: int.tryParse('${json['doctor_id'] ?? 0}') ?? 0,
      patientId: int.tryParse('${json['patient_id'] ?? 0}') ?? 0,
      doctorName: (json['doctor_name'] ?? '').toString(),
      patientName: (json['patient_name'] ?? '').toString(),
      senderRole: (json['sender_role'] ?? '').toString(),
      messageText: (json['message_text'] ?? '').toString(),
      sentAt: (json['sent_at'] ?? '').toString(),
      isRead: (json['is_read'] ?? false).toString() == 'true' || json['is_read'] == 1,
    );
  }
}
