class DoctorScheduleData {
  const DoctorScheduleData({
    required this.id,
    required this.doctorId,
    required this.roomId,
    required this.roomName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.slotMinutes,
    required this.isActive,
  });

  final int id;
  final int doctorId;
  final int roomId;
  final String roomName;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final int slotMinutes;
  final bool isActive;

  factory DoctorScheduleData.fromJson(Map<String, dynamic> json) {
    return DoctorScheduleData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      doctorId: int.tryParse('${json['doctor_id'] ?? 0}') ?? 0,
      roomId: int.tryParse('${json['room_id'] ?? 0}') ?? 0,
      roomName: (json['room_name'] ?? '').toString(),
      dayOfWeek: int.tryParse('${json['day_of_week'] ?? 0}') ?? 0,
      startTime: (json['start_time'] ?? '').toString(),
      endTime: (json['end_time'] ?? '').toString(),
      slotMinutes: int.tryParse('${json['slot_minutes'] ?? 0}') ?? 0,
      isActive: (json['is_active'] ?? false).toString() == 'true' || json['is_active'] == 1,
    );
  }
}
