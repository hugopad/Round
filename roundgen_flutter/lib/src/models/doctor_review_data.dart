class DoctorReviewData {
  const DoctorReviewData({
    required this.id,
    required this.rating,
    required this.comment,
    required this.patientName,
    required this.createdAt,
  });

  final int id;
  final int rating;
  final String comment;
  final String patientName;
  final String createdAt;

  factory DoctorReviewData.fromJson(Map<String, dynamic> json) {
    return DoctorReviewData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      rating: int.tryParse('${json['rating'] ?? 0}') ?? 0,
      comment: (json['comment'] ?? '').toString(),
      patientName: (json['patient_name'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
