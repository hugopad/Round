class AppointmentCreationResult {
  const AppointmentCreationResult({
    required this.id,
    required this.alertMessage,
  });

  final int id;
  final String alertMessage;

  factory AppointmentCreationResult.fromJson(Map<String, dynamic> json) {
    return AppointmentCreationResult(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      alertMessage: (json['alert_message'] ?? '').toString(),
    );
  }
}
