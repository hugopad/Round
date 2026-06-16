class AppointmentData {
  const AppointmentData({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.roomId,
    required this.patientName,
    required this.doctorName,
    required this.roomName,
    required this.appointmentDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.reason,
  });

  final int id;
  final int patientId;
  final int doctorId;
  final int roomId;
  final String patientName;
  final String doctorName;
  final String roomName;
  final String appointmentDate;
  final String startTime;
  final String endTime;
  final String status;
  final String reason;

  factory AppointmentData.fromJson(Map<String, dynamic> json) {
    return AppointmentData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      patientId: int.tryParse('${json['patient_id'] ?? 0}') ?? 0,
      doctorId: int.tryParse('${json['doctor_id'] ?? 0}') ?? 0,
      roomId: int.tryParse('${json['room_id'] ?? 0}') ?? 0,
      patientName: (json['patient_name'] ?? '').toString(),
      doctorName: (json['doctor_name'] ?? '').toString(),
      roomName: (json['room_name'] ?? '').toString(),
      appointmentDate: (json['appointment_date'] ?? '').toString(),
      startTime: (json['start_time'] ?? '').toString(),
      endTime: (json['end_time'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
    );
  }
}
