class DoctorPublicProfileConfig {
  const DoctorPublicProfileConfig({
    required this.doctorId,
    required this.fullName,
    required this.licenseNumber,
    required this.specialty,
    required this.specialties,
    required this.professionalAddress,
    required this.city,
    required this.stateName,
    required this.consultationMode,
    required this.publicBio,
    required this.consultationFee,
    required this.consultationFeePresential,
    required this.consultationFeeVideo,
    required this.profileImageUrl,
    required this.yearsExperience,
    required this.isPublicProfile,
  });

  final int doctorId;
  final String fullName;
  final String licenseNumber;
  final String specialty;
  final List<String> specialties;
  final String professionalAddress;
  final String city;
  final String stateName;
  final String consultationMode;
  final String publicBio;
  final double consultationFee;
  final double consultationFeePresential;
  final double consultationFeeVideo;
  final String profileImageUrl;
  final int yearsExperience;
  final bool isPublicProfile;

  factory DoctorPublicProfileConfig.fromJson(Map<String, dynamic> json) {
    return DoctorPublicProfileConfig(
      doctorId: int.tryParse('${json['doctor_id'] ?? json['id'] ?? 0}') ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      licenseNumber: (json['license_number'] ?? '').toString(),
      specialty: (json['specialty'] ?? '').toString(),
      specialties: ((json['specialties'] as List<dynamic>? ?? <dynamic>[]))
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      professionalAddress: (json['professional_address'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      stateName: (json['state_name'] ?? '').toString(),
      consultationMode: (json['consultation_mode'] ?? 'AMBAS').toString(),
      publicBio: (json['public_bio'] ?? '').toString(),
      consultationFee: double.tryParse('${json['consultation_fee'] ?? 0}') ?? 0,
      consultationFeePresential: double.tryParse('${json['consultation_fee_presential'] ?? json['consultation_fee'] ?? 0}') ?? 0,
      consultationFeeVideo: double.tryParse('${json['consultation_fee_video'] ?? json['consultation_fee'] ?? 0}') ?? 0,
      profileImageUrl: (json['profile_image_url'] ?? '').toString(),
      yearsExperience: int.tryParse('${json['years_experience'] ?? 0}') ?? 0,
      isPublicProfile: (json['is_public_profile'] ?? false).toString() == 'true' || '${json['is_public_profile']}' == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doctor_id': doctorId,
      'specialty': specialty,
      'specialties': specialties,
      'professional_address': professionalAddress,
      'city': city,
      'state_name': stateName,
      'consultation_mode': consultationMode,
      'public_bio': publicBio,
      'consultation_fee': consultationFee,
      'consultation_fee_presential': consultationFeePresential,
      'consultation_fee_video': consultationFeeVideo,
      'profile_image_url': profileImageUrl,
      'years_experience': yearsExperience,
      'is_public_profile': isPublicProfile,
    };
  }
}
