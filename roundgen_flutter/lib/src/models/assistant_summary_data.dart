class AssistantSummaryData {
  const AssistantSummaryData({
    required this.id,
    required this.fullName,
    required this.email,
    this.doctorId,
  });

  final int id;
  final String fullName;
  final String email;
  final int? doctorId;

  factory AssistantSummaryData.fromJson(Map<String, dynamic> json) {
    return AssistantSummaryData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      doctorId: int.tryParse('${json['doctor_id'] ?? ''}'),
    );
  }
}
