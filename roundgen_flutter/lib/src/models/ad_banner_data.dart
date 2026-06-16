class AdBannerData {
  const AdBannerData({
    required this.id,
    required this.advertiserName,
    required this.advertiserType,
    required this.title,
    required this.messageText,
    required this.targetUrl,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  final int id;
  final String advertiserName;
  final String advertiserType;
  final String title;
  final String messageText;
  final String targetUrl;
  final String startDate;
  final String endDate;
  final bool isActive;

  factory AdBannerData.fromJson(Map<String, dynamic> json) {
    return AdBannerData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      advertiserName: (json['advertiser_name'] ?? '').toString(),
      advertiserType: (json['advertiser_type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      messageText: (json['message_text'] ?? '').toString(),
      targetUrl: (json['target_url'] ?? '').toString(),
      startDate: (json['start_date'] ?? '').toString(),
      endDate: (json['end_date'] ?? '').toString(),
      isActive: (json['is_active'] ?? false).toString() == 'true' || json['is_active'] == 1,
    );
  }
}
