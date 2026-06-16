import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/appointment_creation_result.dart';
import '../models/appointment_data.dart';
import '../models/doctor_schedule_data.dart';
import '../models/doctor_summary_data.dart';
import '../models/room_summary_data.dart';

class AgendaService {
  final http.Client _client;

  AgendaService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<DoctorSummaryData>> loadDoctors() async {
    final payload = await _readPayload(
      await _client.get(
        Uri.parse('${AppConfig.baseUrl}/doctors/list.php'),
        headers: const {'Accept': 'application/json'},
      ),
      'No se pudieron cargar los medicos',
      allowEmptySuccess: true,
    );
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(DoctorSummaryData.fromJson)
        .toList();
  }

  Future<List<RoomSummaryData>> loadRooms({int? doctorId}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/agenda/rooms.php').replace(
      queryParameters: doctorId != null ? {'doctor_id': '$doctorId'} : null,
    );
    final payload = await _readPayload(
      await _client.get(uri, headers: const {'Accept': 'application/json'}),
      'No se pudieron cargar las salas',
      allowEmptySuccess: true,
    );
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(RoomSummaryData.fromJson)
        .toList();
  }

  Future<List<String>> loadAvailableSlots({
    required int doctorId,
    required int roomId,
    required String date,
    int? excludeAppointmentId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/agenda/available_slots.php').replace(
      queryParameters: {
        'doctor_id': '$doctorId',
        'room_id': '$roomId',
        'date': date,
        if (excludeAppointmentId != null) 'exclude_appointment_id': '$excludeAppointmentId',
      },
    );
    final payload = await _readPayload(
      await _client.get(uri, headers: const {'Accept': 'application/json'}),
      'No se pudieron cargar los horarios',
      allowEmptySuccess: true,
    );
    return (payload['data'] as List<dynamic>? ?? <dynamic>[]).map((item) => item.toString()).toList();
  }

  Future<List<AppointmentData>> loadAppointments({int? doctorId, int? patientId}) async {
    final query = <String, String>{};
    if (doctorId != null) query['doctor_id'] = '$doctorId';
    if (patientId != null) query['patient_id'] = '$patientId';
    final uri = Uri.parse('${AppConfig.baseUrl}/agenda/appointments.php').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final payload = await _readPayload(
      await _client.get(uri, headers: const {'Accept': 'application/json'}),
      'No se pudieron cargar las citas',
      allowEmptySuccess: true,
    );
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AppointmentData.fromJson)
        .toList();
  }

  Future<List<DoctorScheduleData>> loadDoctorSchedules(int doctorId) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/agenda/doctor_schedules.php').replace(
      queryParameters: {'doctor_id': '$doctorId'},
    );
    final payload = await _readPayload(
      await _client.get(uri, headers: const {'Accept': 'application/json'}),
      'No se pudieron cargar los horarios del medico',
      allowEmptySuccess: true,
    );
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(DoctorScheduleData.fromJson)
        .toList();
  }

  Future<void> saveDoctorSchedule({
    required int doctorId,
    required int roomId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    required int slotMinutes,
    int? assistantUserId,
  }) async {
    await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/agenda/save_doctor_schedule.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'doctor_id': doctorId,
          'room_id': roomId,
          'assistant_user_id': assistantUserId,
          'day_of_week': dayOfWeek,
          'start_time': startTime,
          'end_time': endTime,
          'slot_minutes': slotMinutes,
        }),
      ),
      'No se pudo guardar el horario del medico',
    );
  }

  Future<void> updateDoctorSchedule({
    required int scheduleId,
    required int doctorId,
    required int roomId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    required int slotMinutes,
    int? assistantUserId,
  }) async {
    await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/agenda/update_doctor_schedule.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'schedule_id': scheduleId,
          'doctor_id': doctorId,
          'room_id': roomId,
          'assistant_user_id': assistantUserId,
          'day_of_week': dayOfWeek,
          'start_time': startTime,
          'end_time': endTime,
          'slot_minutes': slotMinutes,
        }),
      ),
      'No se pudo actualizar el horario del medico',
    );
  }

  Future<void> deleteDoctorSchedule({
    required int scheduleId,
    required int doctorId,
    int? assistantUserId,
  }) async {
    await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/agenda/delete_doctor_schedule.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'schedule_id': scheduleId,
          'doctor_id': doctorId,
          'assistant_user_id': assistantUserId,
        }),
      ),
      'No se pudo borrar el horario del medico',
    );
  }

  Future<AppointmentCreationResult> createAppointment({
    required int patientId,
    required int doctorId,
    required int roomId,
    required String appointmentDate,
    required String startTime,
    required String reason,
    int? assistantUserId,
  }) async {
    final payload = await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/agenda/create_appointment.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'patient_id': patientId,
          'doctor_id': doctorId,
          'room_id': roomId,
          'assistant_user_id': assistantUserId,
          'appointment_date': appointmentDate,
          'start_time': startTime,
          'reason': reason,
        }),
      ),
      'No se pudo crear la cita',
    );
    return AppointmentCreationResult.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<AppointmentCreationResult> updateAppointment({
    required int appointmentId,
    required int patientId,
    required int doctorId,
    required int roomId,
    required String appointmentDate,
    required String startTime,
    required String reason,
    int? assistantUserId,
  }) async {
    final payload = await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/agenda/update_appointment.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'appointment_id': appointmentId,
          'patient_id': patientId,
          'doctor_id': doctorId,
          'room_id': roomId,
          'assistant_user_id': assistantUserId,
          'appointment_date': appointmentDate,
          'start_time': startTime,
          'reason': reason,
        }),
      ),
      'No se pudo actualizar la cita',
    );
    return AppointmentCreationResult.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<AppointmentCreationResult> cancelAppointment({
    required int appointmentId,
    required int doctorId,
    required int patientId,
    int? assistantUserId,
  }) async {
    final payload = await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/agenda/cancel_appointment.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'appointment_id': appointmentId,
          'doctor_id': doctorId,
          'patient_id': patientId,
          'assistant_user_id': assistantUserId,
        }),
      ),
      'No se pudo cancelar la cita',
    );
    return AppointmentCreationResult.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<AppointmentCreationResult> updateAppointmentStatus({
    required int appointmentId,
    required int doctorId,
    required int patientId,
    required String status,
    int? assistantUserId,
  }) async {
    final payload = await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/agenda/update_appointment_status.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'appointment_id': appointmentId,
          'doctor_id': doctorId,
          'patient_id': patientId,
          'status': status,
          'assistant_user_id': assistantUserId,
        }),
      ),
      'No se pudo actualizar el estatus de la cita',
    );
    return AppointmentCreationResult.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _readPayload(
    http.Response response,
    String fallbackMessage, {
    bool allowEmptySuccess = false,
  }) async {
    final body = response.body.trim();
    if (body.isEmpty) {
      if (allowEmptySuccess && response.statusCode < 400) {
        return <String, dynamic>{'success': true, 'data': const []};
      }
      throw Exception('$fallbackMessage (respuesta vacia del servidor)');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      final cleanSnippet = body
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final snippet = cleanSnippet.length > 180
          ? '${cleanSnippet.substring(0, 180)}...'
          : cleanSnippet;
      throw Exception(snippet.isEmpty ? fallbackMessage : '$fallbackMessage: $snippet');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception(fallbackMessage);
    }
    if (response.statusCode >= 400 || decoded['success'] != true) {
      throw Exception((decoded['error'] ?? fallbackMessage).toString());
    }
    return decoded;
  }
}
