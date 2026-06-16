import 'doctor_subscription_entry_data.dart';
import 'subscription_code_data.dart';

class DoctorSubscriptionStatusData {
  const DoctorSubscriptionStatusData({
    required this.doctorId,
    required this.doctorName,
    required this.doctorEmail,
    required this.subscriptionActive,
    required this.subscriptionStatus,
    this.subscriptionPlanName,
    this.subscriptionSourceType,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.subscriptionDaysRemaining = 0,
    this.generatedCodes = const [],
    this.history = const [],
  });

  final int doctorId;
  final String doctorName;
  final String doctorEmail;
  final bool subscriptionActive;
  final String subscriptionStatus;
  final String? subscriptionPlanName;
  final String? subscriptionSourceType;
  final String? subscriptionStartDate;
  final String? subscriptionEndDate;
  final int subscriptionDaysRemaining;
  final List<SubscriptionCodeData> generatedCodes;
  final List<DoctorSubscriptionEntryData> history;

  factory DoctorSubscriptionStatusData.fromJson(Map<String, dynamic> json) {
    final historyRaw = json['history'];
    final generatedCodesRaw = json['generated_codes'];
    return DoctorSubscriptionStatusData(
      doctorId: int.tryParse('${json['doctor_id'] ?? 0}') ?? 0,
      doctorName: (json['doctor_name'] ?? '').toString(),
      doctorEmail: (json['doctor_email'] ?? '').toString(),
      subscriptionActive: (json['subscription_active'] ?? false).toString() == 'true' || '${json['subscription_active'] ?? ''}' == '1',
      subscriptionStatus: (json['subscription_status'] ?? '').toString(),
      subscriptionPlanName: (json['subscription_plan_name'] ?? '').toString().isEmpty ? null : (json['subscription_plan_name'] ?? '').toString(),
      subscriptionSourceType: (json['subscription_source_type'] ?? '').toString().isEmpty ? null : (json['subscription_source_type'] ?? '').toString(),
      subscriptionStartDate: (json['subscription_start_date'] ?? '').toString().isEmpty ? null : (json['subscription_start_date'] ?? '').toString(),
      subscriptionEndDate: (json['subscription_end_date'] ?? '').toString().isEmpty ? null : (json['subscription_end_date'] ?? '').toString(),
      subscriptionDaysRemaining: int.tryParse('${json['subscription_days_remaining'] ?? 0}') ?? 0,
      generatedCodes: generatedCodesRaw is List
          ? generatedCodesRaw.whereType<Map<String, dynamic>>().map(SubscriptionCodeData.fromJson).toList(growable: false)
          : const [],
      history: historyRaw is List
          ? historyRaw.whereType<Map<String, dynamic>>().map(DoctorSubscriptionEntryData.fromJson).toList(growable: false)
          : const [],
    );
  }
}
