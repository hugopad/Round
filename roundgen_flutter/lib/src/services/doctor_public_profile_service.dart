import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/doctor_public_profile_config.dart';

class DoctorPublicProfileService {
  final http.Client _client;

  DoctorPublicProfileService({http.Client? client}) : _client = client ?? http.Client();

  Future<DoctorPublicProfileConfig> load(int doctorId) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/doctors/get_public_profile.php?doctor_id=$doctorId'),
      headers: const {'Accept': 'application/json'},
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudo cargar el perfil publico del medico').toString());
    }
    return DoctorPublicProfileConfig.fromJson((payload['data'] ?? <String, dynamic>{}) as Map<String, dynamic>);
  }

  Future<void> save(DoctorPublicProfileConfig config) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/doctors/save_public_profile.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode(config.toJson()),
    );
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudo guardar el perfil publico del medico').toString());
    }
  }

  Future<String> uploadProfileImage({
    required int doctorId,
    required XFile image,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/doctors/upload_public_profile_image.php'),
    );
    request.fields['doctor_id'] = '$doctorId';
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        await image.readAsBytes(),
        filename: image.name,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || payload['success'] != true) {
      throw Exception((payload['error'] ?? 'No se pudo subir la imagen del medico').toString());
    }
    final data = (payload['data'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    return (data['profile_image_url'] ?? '').toString();
  }
}
