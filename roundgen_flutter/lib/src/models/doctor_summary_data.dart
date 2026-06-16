class DoctorSummaryData {
  const DoctorSummaryData({
    required this.id,
    required this.fullName,
    required this.licenseNumber,
    required this.specialty,
  });

  final int id;
  final String fullName;
  final String licenseNumber;
  final String specialty;

  factory DoctorSummaryData.fromJson(Map<String, dynamic> json) {
    return DoctorSummaryData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      licenseNumber: (json['license_number'] ?? '').toString(),
      specialty: (json['specialty'] ?? '').toString(),
    );
  }
}
