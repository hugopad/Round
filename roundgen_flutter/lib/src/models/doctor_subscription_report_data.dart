import 'doctor_subscription_entry_data.dart';

class DoctorSubscriptionReportData {
  const DoctorSubscriptionReportData({
    required this.doctorId,
    required this.fullName,
    required this.email,
    required this.specialty,
    required this.subscriptionActive,
    required this.subscriptionStatus,
    this.subscriptionPlanName,
    this.subscriptionSourceType,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.subscriptionDaysRemaining = 0,
    this.history = const [],
  });

  final int doctorId;
  final String fullName;
  final String email;
  final String specialty;
  final bool subscriptionActive;
  final String subscriptionStatus;
  final String? subscriptionPlanName;
  final String? subscriptionSourceType;
  final String? subscriptionStartDate;
  final String? subscriptionEndDate;
  final int subscriptionDaysRemaining;
  final List<DoctorSubscriptionEntryData> history;

  factory DoctorSubscriptionReportData.fromJson(Map<String, dynamic> json) {
    final historyRaw = json['history'];
    return DoctorSubscriptionReportData(
      doctorId: int.tryParse('${json['doctor_id'] ?? 0}') ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      specialty: (json['specialty'] ?? '').toString(),
      subscriptionActive: (json['subscription_active'] ?? false).toString() == 'true' || '${json['subscription_active'] ?? ''}' == '1',
      subscriptionStatus: (json['subscription_status'] ?? '').toString(),
      subscriptionPlanName: (json['subscription_plan_name'] ?? '').toString().isEmpty ? null : (json['subscription_plan_name'] ?? '').toString(),
      subscriptionSourceType: (json['subscription_source_type'] ?? '').toString().isEmpty ? null : (json['subscription_source_type'] ?? '').toString(),
      subscriptionStartDate: (json['subscription_start_date'] ?? '').toString().isEmpty ? null : (json['subscription_start_date'] ?? '').toString(),
      subscriptionEndDate: (json['subscription_end_date'] ?? '').toString().isEmpty ? null : (json['subscription_end_date'] ?? '').toString(),
      subscriptionDaysRemaining: int.tryParse('${json['subscription_days_remaining'] ?? 0}') ?? 0,
      history: historyRaw is List
          ? historyRaw.whereType<Map<String, dynamic>>().map(DoctorSubscriptionEntryData.fromJson).toList(growable: false)
          : const [],
    );
  }
}
