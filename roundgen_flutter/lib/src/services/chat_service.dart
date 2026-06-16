import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/assistant_summary_data.dart';
import '../models/chat_message_data.dart';

enum ChatThreadType { doctorPatient, assistantPatient, assistantDoctor }

class ChatService {
  final http.Client _client;

  ChatService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<AssistantSummaryData>> loadAssistants({int? doctorId}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/assistants/list.php').replace(
      queryParameters: doctorId != null ? {'doctor_id': '$doctorId'} : null,
    );
    final payload = await _readPayload(
      await _client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      ),
      'No se pudieron cargar los asistentes',
      allowEmptySuccess: true,
    );
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AssistantSummaryData.fromJson)
        .toList();
  }

  Future<List<ChatMessageData>> loadMessages({int? doctorId, int? patientId}) async {
    final query = <String, String>{};
    if (doctorId != null) query['doctor_id'] = '$doctorId';
    if (patientId != null) query['patient_id'] = '$patientId';

    final uri = Uri.parse('${AppConfig.baseUrl}/communication/messages.php').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final payload = await _readPayload(
      await _client.get(uri, headers: const {'Accept': 'application/json'}),
      'No se pudieron cargar los mensajes',
      allowEmptySuccess: true,
    );
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessageData.fromJson)
        .toList();
  }

  Future<List<ChatMessageData>> loadAssistantMessages({int? patientId}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/communication/secretary_messages.php').replace(
      queryParameters: patientId != null ? {'patient_id': '$patientId'} : null,
    );
    final payload = await _readPayload(
      await _client.get(uri, headers: const {'Accept': 'application/json'}),
      'No se pudieron cargar los mensajes del asistente',
      allowEmptySuccess: true,
    );
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => ChatMessageData(
            id: int.tryParse('${json['id'] ?? 0}') ?? 0,
            doctorId: 0,
            patientId: int.tryParse('${json['patient_id'] ?? 0}') ?? 0,
            doctorName: '',
            patientName: (json['patient_name'] ?? '').toString(),
            senderRole: (json['sender_role'] ?? '').toString(),
            messageText: (json['message_text'] ?? '').toString(),
            sentAt: (json['sent_at'] ?? '').toString(),
            isRead: (json['is_read'] ?? false).toString() == 'true' || json['is_read'] == 1,
          ),
        )
        .toList();
  }

  Future<List<ChatMessageData>> loadAssistantDoctorMessages({int? doctorId, int? assistantUserId}) async {
    final query = <String, String>{};
    if (doctorId != null) query['doctor_id'] = '$doctorId';
    if (assistantUserId != null) query['assistant_user_id'] = '$assistantUserId';
    final uri = Uri.parse('${AppConfig.baseUrl}/communication/assistant_doctor_messages.php').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final payload = await _readPayload(
      await _client.get(uri, headers: const {'Accept': 'application/json'}),
      'No se pudieron cargar los mensajes del medico con asistente',
      allowEmptySuccess: true,
    );
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => ChatMessageData(
            id: int.tryParse('${json['id'] ?? 0}') ?? 0,
            doctorId: int.tryParse('${json['doctor_id'] ?? 0}') ?? 0,
            patientId: int.tryParse('${json['assistant_user_id'] ?? 0}') ?? 0,
            doctorName: (json['doctor_name'] ?? '').toString(),
            patientName: (json['assistant_name'] ?? '').toString(),
            senderRole: (json['sender_role'] ?? '').toString(),
            messageText: (json['message_text'] ?? '').toString(),
            sentAt: (json['sent_at'] ?? '').toString(),
            isRead: (json['is_read'] ?? false).toString() == 'true' || json['is_read'] == 1,
          ),
        )
        .toList();
  }

  Future<ChatMessageData> sendMessage({
    required int doctorId,
    required int patientId,
    required String senderRole,
    required String messageText,
  }) async {
    final payload = await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/communication/send_message.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'doctor_id': doctorId,
          'patient_id': patientId,
          'sender_role': senderRole,
          'message_text': messageText,
        }),
      ),
      'No se pudo enviar el mensaje',
    );
    final data = payload['data'] as Map<String, dynamic>;
    return ChatMessageData(
      id: int.tryParse('${data['id'] ?? 0}') ?? 0,
      doctorId: doctorId,
      patientId: patientId,
      doctorName: '',
      patientName: '',
      senderRole: senderRole,
      messageText: messageText,
      sentAt: DateTime.now().toIso8601String(),
      isRead: false,
    );
  }

  Future<ChatMessageData> sendAssistantMessage({
    required int patientId,
    required int assistantUserId,
    required String senderRole,
    required String messageText,
  }) async {
    final payload = await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/communication/send_secretary_message.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'patient_id': patientId,
          'secretary_user_id': assistantUserId,
          'sender_role': senderRole,
          'message_text': messageText,
        }),
      ),
      'No se pudo enviar el mensaje del asistente',
    );
    final data = payload['data'] as Map<String, dynamic>;
    return ChatMessageData(
      id: int.tryParse('${data['id'] ?? 0}') ?? 0,
      doctorId: 0,
      patientId: patientId,
      doctorName: '',
      patientName: '',
      senderRole: senderRole,
      messageText: messageText,
      sentAt: DateTime.now().toIso8601String(),
      isRead: false,
    );
  }

  Future<ChatMessageData> sendAssistantDoctorMessage({
    required int doctorId,
    required int assistantUserId,
    required String senderRole,
    required String messageText,
  }) async {
    final payload = await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/communication/send_assistant_doctor_message.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'doctor_id': doctorId,
          'assistant_user_id': assistantUserId,
          'sender_role': senderRole,
          'message_text': messageText,
        }),
      ),
      'No se pudo enviar el mensaje entre medico y asistente',
    );
    final data = payload['data'] as Map<String, dynamic>;
    return ChatMessageData(
      id: int.tryParse('${data['id'] ?? 0}') ?? 0,
      doctorId: doctorId,
      patientId: assistantUserId,
      doctorName: '',
      patientName: '',
      senderRole: senderRole,
      messageText: messageText,
      sentAt: DateTime.now().toIso8601String(),
      isRead: false,
    );
  }

  Future<void> markThreadAsRead({
    required ChatThreadType threadType,
    required String readerRole,
    int? doctorId,
    int? patientId,
    int? assistantUserId,
  }) async {
    await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/communication/mark_read.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'thread_type': switch (threadType) {
            ChatThreadType.doctorPatient => 'DOCTOR_PATIENT',
            ChatThreadType.assistantPatient => 'ASSISTANT_PATIENT',
            ChatThreadType.assistantDoctor => 'ASSISTANT_DOCTOR',
          },
          'reader_role': readerRole,
          'doctor_id': doctorId,
          'patient_id': patientId,
          'assistant_user_id': assistantUserId,
        }),
      ),
      'No se pudieron actualizar los mensajes leidos',
      allowEmptySuccess: true,
    );
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
