import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_user.dart';
import '../models/role_type.dart';

class SessionService {
  static const _userKey = 'roundgen_current_user';

  Future<void> saveUser(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _userKey,
      jsonEncode({
        'user_id': user.id,
        'full_name': user.fullName,
        'email': user.email,
        'role': _roleCode(user.role),
        'doctor_id': user.doctorId,
        'patient_id': user.patientId,
        'must_change_password': user.mustChangePassword,
        'subscription_active': user.subscriptionActive,
        'subscription_status': user.subscriptionStatus,
        'subscription_plan_name': user.subscriptionPlanName,
        'subscription_start_date': user.subscriptionStartDate,
        'subscription_end_date': user.subscriptionEndDate,
        'subscription_days_remaining': user.subscriptionDaysRemaining,
      }),
    );
  }

  Future<AuthUser?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return AuthUser.fromJson(decoded);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  String _roleCode(RoleType role) {
    switch (role) {
      case RoleType.admin:
        return 'ADMIN';
      case RoleType.doctor:
        return 'DOCTOR';
      case RoleType.assistant:
        return 'SECRETARY';
      case RoleType.patient:
        return 'PATIENT';
    }
  }
}
