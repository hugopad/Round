class CreatePatientResult {
  const CreatePatientResult({
    required this.id,
    required this.medicalRecordNumber,
    required this.fullName,
    required this.recordCreated,
    required this.accessCreated,
    required this.assignedDoctors,
    required this.emailSent,
    required this.emailError,
    required this.apkUrl,
  });

  final int id;
  final String medicalRecordNumber;
  final String fullName;
  final bool recordCreated;
  final bool accessCreated;
  final List<int> assignedDoctors;
  final bool emailSent;
  final String emailError;
  final String apkUrl;

  factory CreatePatientResult.fromJson(Map<String, dynamic> json) {
    return CreatePatientResult(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      medicalRecordNumber: (json['medical_record_number'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      recordCreated: (json['record_created'] ?? false).toString() == 'true',
      accessCreated: (json['access_created'] ?? false).toString() == 'true',
      assignedDoctors: (json['assigned_doctors'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => int.tryParse('$value') ?? 0)
          .where((value) => value > 0)
          .toList(),
      emailSent: (json['email_sent'] ?? false).toString() == 'true',
      emailError: (json['email_error'] ?? '').toString(),
      apkUrl: (json['apk_url'] ?? '').toString(),
    );
  }
}