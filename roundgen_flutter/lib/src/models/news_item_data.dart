class NewsItemData {
  const NewsItemData({
    required this.id,
    required this.sourceType,
    required this.sourceRecordId,
    required this.createdByUserId,
    required this.doctorId,
    required this.doctorName,
    required this.title,
    required this.body,
    required this.category,
    required this.imageUrl,
    required this.mediaType,
    required this.externalVideoUrl,
    required this.targetRole,
    required this.isPublished,
    required this.publishedAt,
  });

  final int id;
  final String sourceType;
  final int sourceRecordId;
  final int? createdByUserId;
  final int? doctorId;
  final String doctorName;
  final String title;
  final String body;
  final String category;
  final String imageUrl;
  final String mediaType;
  final String externalVideoUrl;
  final String targetRole;
  final bool isPublished;
  final String publishedAt;

  factory NewsItemData.fromJson(Map<String, dynamic> json) {
    return NewsItemData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      sourceType: (json['source_type'] ?? 'news').toString(),
      sourceRecordId: int.tryParse('${json['source_record_id'] ?? json['id'] ?? 0}') ?? 0,
      createdByUserId: int.tryParse('${json['created_by_user_id'] ?? ''}'),
      doctorId: int.tryParse('${json['doctor_id'] ?? ''}'),
      doctorName: (json['doctor_name'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      mediaType: (json['media_type'] ?? '').toString(),
      externalVideoUrl: (json['external_video_url'] ?? '').toString(),
      targetRole: (json['target_role'] ?? '').toString(),
      isPublished: (json['is_published'] ?? false).toString() == 'true' || json['is_published'] == 1,
      publishedAt: (json['published_at'] ?? '').toString(),
    );
  }
}
