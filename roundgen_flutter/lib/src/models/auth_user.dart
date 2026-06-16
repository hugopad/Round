import 'role_type.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.doctorId,
    this.patientId,
    this.mustChangePassword = false,
    this.subscriptionActive = true,
    this.subscriptionStatus,
    this.subscriptionPlanName,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.subscriptionDaysRemaining = 0,
  });

  final int id;
  final String fullName;
  final String email;
  final RoleType role;
  final int? doctorId;
  final int? patientId;
  final bool mustChangePassword;
  final bool subscriptionActive;
  final String? subscriptionStatus;
  final String? subscriptionPlanName;
  final String? subscriptionStartDate;
  final String? subscriptionEndDate;
  final int subscriptionDaysRemaining;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final roleRaw = (json['role'] ?? '').toString().toUpperCase();
    final role = switch (roleRaw) {
      'ADMIN' => RoleType.admin,
      'DOCTOR' => RoleType.doctor,
      'SECRETARY' => RoleType.assistant,
      _ => RoleType.patient,
    };

    return AuthUser(
      id: int.tryParse('${json['user_id'] ?? json['id'] ?? 0}') ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: role,
      doctorId: int.tryParse('${json['doctor_id'] ?? ''}'),
      patientId: int.tryParse('${json['patient_id'] ?? ''}'),
      mustChangePassword: (json['must_change_password'] ?? false).toString() == 'true' || '${json['must_change_password'] ?? ''}' == '1',
      subscriptionActive: role == RoleType.doctor
          ? ((json['subscription_active'] ?? true).toString() == 'true' || '${json['subscription_active'] ?? ''}' == '1')
          : true,
      subscriptionStatus: (json['subscription_status'] ?? '').toString().isEmpty ? null : (json['subscription_status'] ?? '').toString(),
      subscriptionPlanName: (json['subscription_plan_name'] ?? '').toString().isEmpty ? null : (json['subscription_plan_name'] ?? '').toString(),
      subscriptionStartDate: (json['subscription_start_date'] ?? '').toString().isEmpty ? null : (json['subscription_start_date'] ?? '').toString(),
      subscriptionEndDate: (json['subscription_end_date'] ?? '').toString().isEmpty ? null : (json['subscription_end_date'] ?? '').toString(),
      subscriptionDaysRemaining: int.tryParse('${json['subscription_days_remaining'] ?? 0}') ?? 0,
    );
  }

  AuthUser copyWith({
    int? id,
    String? fullName,
    String? email,
    RoleType? role,
    int? doctorId,
    int? patientId,
    bool? mustChangePassword,
    bool? subscriptionActive,
    String? subscriptionStatus,
    String? subscriptionPlanName,
    String? subscriptionStartDate,
    String? subscriptionEndDate,
    int? subscriptionDaysRemaining,
  }) {
    return AuthUser(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionPlanName: subscriptionPlanName ?? this.subscriptionPlanName,
      subscriptionStartDate: subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      subscriptionDaysRemaining: subscriptionDaysRemaining ?? this.subscriptionDaysRemaining,
    );
  }
}
