class AssistantActivitySummaryData {
  const AssistantActivitySummaryData({
    this.totalEvents = 0,
    this.patientsCreated = 0,
    this.appointmentsCreated = 0,
    this.messagesSent = 0,
    this.patientMessagesSent = 0,
    this.doctorMessagesSent = 0,
    this.schedulesUpdated = 0,
  });

  final int totalEvents;
  final int patientsCreated;
  final int appointmentsCreated;
  final int messagesSent;
  final int patientMessagesSent;
  final int doctorMessagesSent;
  final int schedulesUpdated;

  factory AssistantActivitySummaryData.fromJson(Map<String, dynamic> json) {
    return AssistantActivitySummaryData(
      totalEvents: (json['total_events'] as num?)?.toInt() ?? 0,
      patientsCreated: (json['patients_created'] as num?)?.toInt() ?? 0,
      appointmentsCreated: (json['appointments_created'] as num?)?.toInt() ?? 0,
      messagesSent: (json['messages_sent'] as num?)?.toInt() ?? 0,
      patientMessagesSent: (json['patient_messages_sent'] as num?)?.toInt() ?? 0,
      doctorMessagesSent: (json['doctor_messages_sent'] as num?)?.toInt() ?? 0,
      schedulesUpdated: (json['schedules_updated'] as num?)?.toInt() ?? 0,
    );
  }
}
