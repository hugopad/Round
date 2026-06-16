import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/doctor_access_email_config.dart';

class DoctorEmailConfigService {
  final http.Client _client;

  DoctorEmailConfigService({http.Client? client}) : _client = client ?? http.Client();

  Future<DoctorAccessEmailConfig> load(int doctorId) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/doctors/get_access_email_config.php').replace(
      queryParameters: {'doctor_id': '$doctorId'},
    );
    final payload = await _readPayload(
      await _client.get(uri, headers: const {'Accept': 'application/json'}),
      'No se pudo cargar la configuracion SMTP',
    );
    return DoctorAccessEmailConfig.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<void> save(DoctorAccessEmailConfig config) async {
    await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/doctors/save_access_email_config.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(config.toJson()),
      ),
      'No se pudo guardar la configuracion SMTP',
    );
  }

  Future<Map<String, dynamic>> _readPayload(http.Response response, String fallbackMessage) async {
    final body = response.body.trim();
    if (body.isEmpty) {
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
      throw Exception(cleanSnippet.isEmpty ? fallbackMessage : '$fallbackMessage: $cleanSnippet');
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
