class AssistantActivityData {
  const AssistantActivityData({
    required this.id,
    required this.doctorId,
    required this.assistantUserId,
    required this.assistantName,
    required this.activityType,
    required this.activityTitle,
    required this.activityDetails,
    required this.createdAt,
    this.relatedPatientId,
    this.relatedAppointmentId,
    this.relatedMessageId,
  });

  final int id;
  final int doctorId;
  final int assistantUserId;
  final String assistantName;
  final String activityType;
  final String activityTitle;
  final String activityDetails;
  final String createdAt;
  final int? relatedPatientId;
  final int? relatedAppointmentId;
  final int? relatedMessageId;

  factory AssistantActivityData.fromJson(Map<String, dynamic> json) {
    return AssistantActivityData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      doctorId: int.tryParse('${json['doctor_id'] ?? 0}') ?? 0,
      assistantUserId: int.tryParse('${json['assistant_user_id'] ?? 0}') ?? 0,
      assistantName: (json['assistant_name'] ?? '').toString(),
      activityType: (json['activity_type'] ?? '').toString(),
      activityTitle: (json['activity_title'] ?? '').toString(),
      activityDetails: (json['activity_details'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      relatedPatientId: int.tryParse('${json['related_patient_id'] ?? ''}'),
      relatedAppointmentId: int.tryParse('${json['related_appointment_id'] ?? ''}'),
      relatedMessageId: int.tryParse('${json['related_message_id'] ?? ''}'),
    );
  }
}
