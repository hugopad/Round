import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_user.dart';

class AuthService {
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<AuthUser> login({required String email, required String password}) async {
    try {
      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/auth/login.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      final Map<String, dynamic> payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || payload['success'] != true) {
        throw Exception((payload['error'] ?? 'No se pudo iniciar sesion').toString());
      }

      return AuthUser.fromJson(payload['data'] as Map<String, dynamic>);
    } catch (error) {
      throw Exception(_friendlyError(error, 'No se pudo iniciar sesion'));
    }
  }

  Future<AuthUser> changePassword({
    required AuthUser user,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/auth/change_password.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_id': user.id,
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      final Map<String, dynamic> payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || payload['success'] != true) {
        throw Exception((payload['error'] ?? 'No se pudo cambiar la contrasena').toString());
      }

      return AuthUser(
        id: user.id,
        fullName: user.fullName,
        email: user.email,
        role: user.role,
        doctorId: user.doctorId,
        patientId: user.patientId,
        mustChangePassword: false,
      );
    } catch (error) {
      throw Exception(_friendlyError(error, 'No se pudo cambiar la contrasena'));
    }
  }

  Future<String> requestPasswordReset({required String email}) async {
    try {
      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/auth/request_password_reset.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
        }),
      );

      final Map<String, dynamic> payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400 || payload['success'] != true) {
        throw Exception((payload['error'] ?? 'No se pudo restablecer la contrasena').toString());
      }

      final data = (payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
      final emailSent = data['email_sent'] == true;
      if (!emailSent) {
        final emailError = (data['email_error'] ?? '').toString().trim();
        if (emailError.isNotEmpty) {
          return 'La contrasena temporal se genero, pero el correo no pudo enviarse: $emailError';
        }
        return 'La contrasena temporal se genero, pero el correo no pudo enviarse.';
      }

      return 'Te enviamos una contrasena temporal a tu correo.';
    } catch (error) {
      throw Exception(_friendlyError(error, 'No se pudo restablecer la contrasena'));
    }
  }

  String _friendlyError(Object error, String fallback) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    final lower = raw.toLowerCase();

    if (lower.contains('failed host lookup') || lower.contains('socketfailed host lookup') || lower.contains('no address associated with hostname')) {
      return 'No hay conexion con el servidor de ROUNDGEN. Verifica que el dominio este activo y que tu dispositivo tenga internet.';
    }

    if (lower.contains('clientfailed to fetch') || lower.contains('clientexception') || lower.contains('socketexception')) {
      return 'No se pudo conectar con el servidor de ROUNDGEN. Revisa internet e intenta nuevamente.';
    }

    if (lower.contains('unexpected end of json input') || lower.contains('format') || lower.contains('html')) {
      return 'El servidor respondio de forma invalida. Revisa la API publicada e intenta nuevamente.';
    }

    return raw.isEmpty ? fallback : raw;
  }
}
