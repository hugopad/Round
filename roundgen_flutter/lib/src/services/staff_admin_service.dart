import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/assistant_activity_data.dart';
import '../models/assistant_activity_summary_data.dart';
import '../models/doctor_professional_request_summary_data.dart';
import '../models/assistant_summary_data.dart';
import '../models/doctor_professional_request_data.dart';

class StaffAdminService {
  final http.Client _client;

  StaffAdminService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> createDoctor({
    required String fullName,
    required String email,
    required String password,
    required String specialty,
    required String phone,
    required String licenseNumber,
    required String professionalAddress,
    required String city,
    required String stateName,
    required String consultationMode,
  }) async {
    final payload = await _send(
      endpoint: '/doctors/register_professional.php',
      body: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'specialty': specialty,
        'phone': phone,
        'license_number': licenseNumber,
        'professional_address': professionalAddress,
        'city': city,
        'state_name': stateName,
        'consultation_mode': consultationMode,
      },
      fallbackMessage: 'No se pudo registrar la solicitud profesional del medico',
    );
    return (payload['tracking_code'] ?? '').toString();
  }

  Future<void> createAssistantAccess({
    required int doctorId,
    required String fullName,
    required String email,
    required String password,
    required String phone,
  }) async {
    await _send(
      endpoint: '/assistants/create.php',
      body: {
        'doctor_id': doctorId,
        'full_name': fullName,
        'email': email,
        'password': password,
        'phone': phone,
      },
      fallbackMessage: 'No se pudo crear el acceso del asistente',
    );
  }

  Future<List<AssistantSummaryData>> loadAssistants({
    int? doctorId,
    bool unassignedOnly = false,
    bool all = false,
  }) async {
    final query = <String, String>{};
    if (doctorId != null && doctorId > 0) {
      query['doctor_id'] = '$doctorId';
    }
    if (unassignedOnly) {
      query['unassigned_only'] = '1';
    }
    if (all) {
      query['all'] = '1';
    }
    final uri = Uri.parse('${AppConfig.baseUrl}/assistants/list.php').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'});
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudieron cargar los asistentes').toString());
    }
    final data = payload['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AssistantSummaryData.fromJson)
        .toList(growable: false);
  }

  Future<void> assignExistingAssistant({
    required int doctorId,
    required int assistantUserId,
  }) async {
    await _send(
      endpoint: '/assistants/assign.php',
      body: {
        'doctor_id': doctorId,
        'assistant_user_id': assistantUserId,
      },
      fallbackMessage: 'No se pudo asignar el asistente al medico',
    );
  }

  Future<void> unassignAssistant({
    required int doctorId,
    required int assistantUserId,
  }) async {
    await _send(
      endpoint: '/assistants/unassign.php',
      body: {
        'doctor_id': doctorId,
        'assistant_user_id': assistantUserId,
      },
      fallbackMessage: 'No se pudo desasignar el asistente',
    );
  }

  Future<List<AssistantActivityData>> loadAssistantActivity({
    required int doctorId,
    int? assistantUserId,
    String? activityType,
    int limit = 40,
  }) async {
    final query = <String, String>{
      'doctor_id': '$doctorId',
      'limit': '$limit',
    };
    if (assistantUserId != null && assistantUserId > 0) {
      query['assistant_user_id'] = '$assistantUserId';
    }
    if (activityType != null && activityType.trim().isNotEmpty) {
      query['activity_type'] = activityType.trim().toUpperCase();
    }
    final uri = Uri.parse('${AppConfig.baseUrl}/assistants/activity.php').replace(queryParameters: query);
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'});
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudo cargar la actividad del equipo').toString());
    }
    final data = payload['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AssistantActivityData.fromJson)
        .toList(growable: false);
  }

  Future<AssistantActivitySummaryData> loadAssistantActivitySummary({
    required int doctorId,
    int? assistantUserId,
  }) async {
    final query = <String, String>{
      'doctor_id': '$doctorId',
    };
    if (assistantUserId != null && assistantUserId > 0) {
      query['assistant_user_id'] = '$assistantUserId';
    }
    final uri = Uri.parse('${AppConfig.baseUrl}/assistants/activity_summary.php').replace(queryParameters: query);
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'});
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudo cargar el resumen del equipo').toString());
    }
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      return const AssistantActivitySummaryData();
    }
    return AssistantActivitySummaryData.fromJson(data);
  }

  Future<List<DoctorProfessionalRequestData>> loadDoctorProfessionalRequests() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/doctors/professional_requests.php'),
      headers: const {'Accept': 'application/json'},
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudieron cargar las solicitudes medicas').toString());
    }
    final data = payload['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(DoctorProfessionalRequestData.fromJson)
        .toList(growable: false);
  }

  Future<DoctorProfessionalRequestSummaryData> loadDoctorProfessionalRequestsSummary() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/doctors/professional_requests_summary.php'),
      headers: const {'Accept': 'application/json'},
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudo cargar el resumen de solicitudes medicas').toString());
    }
    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      return const DoctorProfessionalRequestSummaryData();
    }
    return DoctorProfessionalRequestSummaryData.fromJson(data);
  }

  Future<void> reviewDoctorProfessionalRequest({
    required int requestId,
    required int reviewerUserId,
    required String action,
    String reviewNotes = '',
  }) async {
    await _send(
      endpoint: '/doctors/review_professional_request.php',
      body: {
        'request_id': requestId,
        'reviewer_user_id': reviewerUserId,
        'action': action,
        'review_notes': reviewNotes,
      },
      fallbackMessage: 'No se pudo revisar la solicitud medica',
    );
  }

  Future<Map<String, dynamic>> _send({required String endpoint, required Map<String, dynamic> body, required String fallbackMessage}) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode(body),
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? fallbackMessage).toString());
    }
    return (payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
  }
}
