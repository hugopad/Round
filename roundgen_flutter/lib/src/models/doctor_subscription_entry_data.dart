class DoctorSubscriptionEntryData {
  const DoctorSubscriptionEntryData({
    required this.id,
    required this.planName,
    required this.sourceType,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.notes,
    required this.createdAt,
  });

  final int id;
  final String planName;
  final String sourceType;
  final String startDate;
  final String endDate;
  final String status;
  final String notes;
  final String createdAt;

  factory DoctorSubscriptionEntryData.fromJson(Map<String, dynamic> json) {
    return DoctorSubscriptionEntryData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      planName: (json['plan_name'] ?? '').toString(),
      sourceType: (json['source_type'] ?? '').toString(),
      startDate: (json['start_date'] ?? '').toString(),
      endDate: (json['end_date'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
