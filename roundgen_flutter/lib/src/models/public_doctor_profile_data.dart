class PublicDoctorProfileData {
  const PublicDoctorProfileData({
    required this.id,
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
    required this.averageRating,
    required this.reviewCount,
    required this.isFavorite,
  });

  final int id;
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
  final double averageRating;
  final int reviewCount;
  final bool isFavorite;

  String get locationLabel {
    final pieces = [professionalAddress, city, stateName].where((item) => item.trim().isNotEmpty).toList();
    return pieces.isEmpty ? 'Ubicacion pendiente' : pieces.join(', ');
  }

  factory PublicDoctorProfileData.fromJson(Map<String, dynamic> json) {
    return PublicDoctorProfileData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
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
      consultationMode: (json['consultation_mode'] ?? '').toString(),
      publicBio: (json['public_bio'] ?? '').toString(),
      consultationFee: double.tryParse('${json['consultation_fee'] ?? 0}') ?? 0,
      consultationFeePresential: double.tryParse('${json['consultation_fee_presential'] ?? json['consultation_fee'] ?? 0}') ?? 0,
      consultationFeeVideo: double.tryParse('${json['consultation_fee_video'] ?? json['consultation_fee'] ?? 0}') ?? 0,
      profileImageUrl: (json['profile_image_url'] ?? '').toString(),
      yearsExperience: int.tryParse('${json['years_experience'] ?? 0}') ?? 0,
      averageRating: double.tryParse('${json['average_rating'] ?? 0}') ?? 0,
      reviewCount: int.tryParse('${json['review_count'] ?? 0}') ?? 0,
      isFavorite: ['true', '1'].contains((json['is_favorite'] ?? false).toString().toLowerCase()),
    );
  }
}
