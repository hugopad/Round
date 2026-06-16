class PatientSummary {
  const PatientSummary({
    required this.id,
    required this.medicalRecordNumber,
    required this.fullName,
    required this.birthDate,
    required this.bloodType,
    required this.phone,
    required this.email,
    required this.notes,
    required this.isActive,
    this.primaryDoctorId,
    this.primaryDoctorName = '',
  });

  final int id;
  final String medicalRecordNumber;
  final String fullName;
  final String birthDate;
  final String bloodType;
  final String phone;
  final String email;
  final String notes;
  final bool isActive;
  final int? primaryDoctorId;
  final String primaryDoctorName;

  factory PatientSummary.fromJson(Map<String, dynamic> json) {
    return PatientSummary(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      medicalRecordNumber: (json['medical_record_number'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      birthDate: (json['birth_date'] ?? '').toString(),
      bloodType: (json['blood_type'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      isActive: json['is_active'] == null ? true : json['is_active'] == true || '${json['is_active']}' == '1',
      primaryDoctorId: int.tryParse('${json['primary_doctor_id'] ?? ''}'),
      primaryDoctorName: (json['primary_doctor_name'] ?? '').toString(),
    );
  }
}
