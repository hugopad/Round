import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/doctor_subscription_report_data.dart';
import '../models/doctor_subscription_status_data.dart';
import '../models/mercado_pago_config_data.dart';
import '../models/subscription_code_data.dart';

class SubscriptionService {
  final http.Client _client;

  SubscriptionService({http.Client? client}) : _client = client ?? http.Client();

  Future<(List<DoctorSubscriptionReportData>, List<SubscriptionCodeData>)> loadAdminSubscriptionReport({
    required int adminUserId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/subscriptions/report.php').replace(
      queryParameters: {'admin_user_id': '$adminUserId'},
    );
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'});
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudo cargar el reporte de suscripciones').toString());
    }
    final data = payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final doctorsRaw = data['doctors'];
    final codesRaw = data['codes'];
    final doctors = doctorsRaw is List
        ? doctorsRaw.whereType<Map<String, dynamic>>().map(DoctorSubscriptionReportData.fromJson).toList(growable: false)
        : const <DoctorSubscriptionReportData>[];
    final codes = codesRaw is List
        ? codesRaw.whereType<Map<String, dynamic>>().map(SubscriptionCodeData.fromJson).toList(growable: false)
        : const <SubscriptionCodeData>[];
    return (doctors, codes);
  }

  Future<List<SubscriptionCodeData>> generateCodes({
    required int adminUserId,
    required String planName,
    required int durationDays,
    required int quantity,
    String notes = '',
    String? expiresAt,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/subscriptions/generate_code.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'admin_user_id': adminUserId,
        'plan_name': planName,
        'duration_days': durationDays,
        'quantity': quantity,
        'notes': notes,
        'expires_at': expiresAt,
      }),
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudieron generar los codigos').toString());
    }
    final data = payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final codesRaw = data['codes'];
    if (codesRaw is! List) return const [];
    return codesRaw.whereType<Map<String, dynamic>>().map(SubscriptionCodeData.fromJson).toList(growable: false);
  }

  Future<DoctorSubscriptionStatusData> loadDoctorSubscriptionStatus({
    required int doctorId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/subscriptions/status.php').replace(
      queryParameters: {'doctor_id': '$doctorId'},
    );
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'});
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudo cargar la suscripcion').toString());
    }
    final data = payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return DoctorSubscriptionStatusData.fromJson(data);
  }

  Future<DoctorSubscriptionStatusData> redeemSubscriptionCode({
    required int doctorId,
    required String code,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/subscriptions/redeem_code.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'doctor_id': doctorId,
        'code': code.trim().toUpperCase(),
      }),
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudo activar la suscripcion').toString());
    }
    final data = payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return DoctorSubscriptionStatusData.fromJson(data);
  }

  Future<MercadoPagoConfigData> loadMercadoPagoConfig({
    required int adminUserId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/subscriptions/payment_config.php').replace(
      queryParameters: {'admin_user_id': '$adminUserId'},
    );
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'});
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudo cargar la configuracion de Mercado Pago').toString());
    }
    return MercadoPagoConfigData.fromJson(payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  Future<void> saveMercadoPagoConfig({
    required int adminUserId,
    required String publicKey,
    required String accessToken,
    required String webhookSecret,
    required String appBaseUrl,
    required String successUrl,
    required String failureUrl,
    required String pendingUrl,
    required bool isActive,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/subscriptions/save_payment_config.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'admin_user_id': adminUserId,
        'public_key': publicKey,
        'access_token': accessToken,
        'webhook_secret': webhookSecret,
        'app_base_url': appBaseUrl,
        'success_url': successUrl,
        'failure_url': failureUrl,
        'pending_url': pendingUrl,
        'is_active': isActive ? 1 : 0,
      }),
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudo guardar la configuracion de pagos').toString());
    }
  }

  Future<String> createSubscriptionCheckout({
    required int doctorId,
    required String planKey,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/subscriptions/create_payment_checkout.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'doctor_id': doctorId,
        'plan_key': planKey,
      }),
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudo iniciar el pago').toString());
    }
    final data = payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return (data['checkout_url'] ?? '').toString();
  }
}
