class DoctorProfessionalRequestData {
  const DoctorProfessionalRequestData({
    required this.id,
    required this.trackingCode,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.specialty,
    required this.licenseNumber,
    required this.professionalAddress,
    required this.city,
    required this.stateName,
    required this.consultationMode,
    required this.status,
    required this.reviewNotes,
    required this.reviewedByUserId,
    required this.reviewedByName,
    required this.reviewedAt,
    required this.createdAt,
  });

  final int id;
  final String trackingCode;
  final String fullName;
  final String email;
  final String phone;
  final String specialty;
  final String licenseNumber;
  final String professionalAddress;
  final String city;
  final String stateName;
  final String consultationMode;
  final String status;
  final String reviewNotes;
  final int? reviewedByUserId;
  final String reviewedByName;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  bool get isPending => status.toUpperCase() == 'PENDIENTE';

  factory DoctorProfessionalRequestData.fromJson(Map<String, dynamic> json) {
    return DoctorProfessionalRequestData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      trackingCode: (json['tracking_code'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      specialty: (json['specialty'] ?? '').toString(),
      licenseNumber: (json['license_number'] ?? '').toString(),
      professionalAddress: (json['professional_address'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      stateName: (json['state_name'] ?? '').toString(),
      consultationMode: (json['consultation_mode'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      reviewNotes: (json['review_notes'] ?? '').toString(),
      reviewedByUserId: int.tryParse('${json['reviewed_by_user_id'] ?? ''}'),
      reviewedByName: (json['reviewed_by_name'] ?? '').toString(),
      reviewedAt: DateTime.tryParse((json['reviewed_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}
