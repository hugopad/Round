class SubscriptionCodeData {
  const SubscriptionCodeData({
    required this.id,
    required this.code,
    required this.planName,
    required this.durationDays,
    required this.maxRedemptions,
    required this.redeemedCount,
    required this.status,
    this.expiresAt,
    required this.notes,
    required this.createdAt,
  });

  final int id;
  final String code;
  final String planName;
  final int durationDays;
  final int maxRedemptions;
  final int redeemedCount;
  final String status;
  final String? expiresAt;
  final String notes;
  final String createdAt;

  factory SubscriptionCodeData.fromJson(Map<String, dynamic> json) {
    final expiresAtRaw = (json['expires_at'] ?? '').toString();
    return SubscriptionCodeData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      code: (json['code'] ?? '').toString(),
      planName: (json['plan_name'] ?? '').toString(),
      durationDays: int.tryParse('${json['duration_days'] ?? 0}') ?? 0,
      maxRedemptions: int.tryParse('${json['max_redemptions'] ?? 0}') ?? 0,
      redeemedCount: int.tryParse('${json['redeemed_count'] ?? 0}') ?? 0,
      status: (json['status'] ?? '').toString(),
      expiresAt: expiresAtRaw.isEmpty ? null : expiresAtRaw,
      notes: (json['notes'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
