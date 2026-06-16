import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/ad_banner_data.dart';
import '../models/doctor_review_data.dart';
import '../models/news_item_data.dart';
import '../models/public_doctor_profile_data.dart';
import '../models/role_type.dart';

class ContentService {
  final http.Client _client;

  ContentService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<NewsItemData>> loadNews({
    RoleType? viewerRole,
    int? doctorId,
    int? patientId,
  }) async {
    final query = <String, String>{};
    if (viewerRole != null) {
      query['viewer_role'] = _roleCode(viewerRole);
    }
    if (doctorId != null && doctorId > 0) {
      query['doctor_id'] = '$doctorId';
    }
    if (patientId != null && patientId > 0) {
      query['patient_id'] = '$patientId';
    }
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/content/news.php').replace(
        queryParameters: query.isEmpty ? null : query,
      ),
      headers: const {'Accept': 'application/json'},
    );
    final payload = _readPayload(response, 'No se pudieron cargar las noticias');
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(NewsItemData.fromJson)
        .toList();
  }

  Future<List<AdBannerData>> loadAds() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/content/ads.php'),
      headers: const {'Accept': 'application/json'},
    );
    final payload = _readPayload(response, 'No se pudieron cargar los anuncios');
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AdBannerData.fromJson)
        .toList();
  }

  Future<List<PublicDoctorProfileData>> loadPublicDoctors({
    String search = '',
    String specialty = '',
    String city = '',
    String consultationMode = '',
    int? patientId,
  }) async {
    final query = <String, String>{};
    if (search.trim().isNotEmpty) query['q'] = search.trim();
    if (specialty.trim().isNotEmpty) query['specialty'] = specialty.trim();
    if (city.trim().isNotEmpty) query['city'] = city.trim();
    if (consultationMode.trim().isNotEmpty) query['consultation_mode'] = consultationMode.trim();
    if (patientId != null && patientId > 0) query['patient_id'] = '$patientId';

    final uri = Uri.parse('${AppConfig.baseUrl}/doctors/public_profiles.php').replace(
      queryParameters: query.isEmpty ? null : query,
    );
    final response = await _client.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    final payload = _readPayload(response, 'No se pudieron cargar los medicos disponibles');
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PublicDoctorProfileData.fromJson)
        .toList();
  }

  Future<List<DoctorReviewData>> loadDoctorReviews(int doctorId) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.baseUrl}/doctors/public_reviews.php?doctor_id=$doctorId'),
      headers: const {'Accept': 'application/json'},
    );
    final payload = _readPayload(response, 'No se pudieron cargar las reseñas del medico');
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(DoctorReviewData.fromJson)
        .toList();
  }

  Future<void> submitDoctorReview({
    required int doctorId,
    required int patientId,
    required int rating,
    required String comment,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/doctors/submit_review.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'doctor_id': doctorId,
        'patient_id': patientId,
        'rating': rating,
        'comment': comment,
      }),
    );
    _readPayload(response, 'No se pudo guardar la reseña del medico');
  }

  Future<void> toggleFavoriteDoctor({
    required int doctorId,
    required int patientId,
    required bool isFavorite,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/doctors/toggle_favorite.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'doctor_id': doctorId,
        'patient_id': patientId,
        'is_favorite': isFavorite,
      }),
    );
    _readPayload(response, 'No se pudo actualizar el favorito');
  }

  Future<void> createNews({
    required int doctorId,
    required String title,
    required String body,
    required String category,
    String imageUrl = '',
    String mediaType = '',
    String externalVideoUrl = '',
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/content/create_news.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'doctor_id': doctorId,
        'title': title,
        'body': body,
        'category': category,
        'image_url': imageUrl,
        'media_type': mediaType,
        'external_video_url': externalVideoUrl,
        'target_role': 'PATIENT',
      }),
    );
    _readPayload(response, 'No se pudo publicar la noticia');
  }

  Future<void> updateNews({
    required int newsId,
    required int doctorId,
    required String title,
    required String body,
    required String category,
    String imageUrl = '',
    String mediaType = '',
    String externalVideoUrl = '',
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/content/update_news.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'news_id': newsId,
        'doctor_id': doctorId,
        'title': title,
        'body': body,
        'category': category,
        'image_url': imageUrl,
        'media_type': mediaType,
        'external_video_url': externalVideoUrl,
        'target_role': 'PATIENT',
      }),
    );
    _readPayload(response, 'No se pudo actualizar la noticia');
  }

  Future<void> deleteNews({
    required int newsId,
    required int doctorId,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/content/delete_news.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'news_id': newsId,
        'doctor_id': doctorId,
      }),
    );
    _readPayload(response, 'No se pudo eliminar la noticia');
  }

  Future<void> updateNotice({
    required int noticeId,
    required int createdByUserId,
    required String title,
    required String messageText,
    required String targetRole,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/communication/update_notice.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'notice_id': noticeId,
        'created_by_user_id': createdByUserId,
        'title': title,
        'message_text': messageText,
        'target_role': targetRole,
      }),
    );
    _readPayload(response, 'No se pudo actualizar el aviso');
  }

  Future<void> deleteNotice({
    required int noticeId,
    required int createdByUserId,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/communication/delete_notice.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'notice_id': noticeId,
        'created_by_user_id': createdByUserId,
      }),
    );
    _readPayload(response, 'No se pudo eliminar el aviso');
  }

  Future<Map<String, String>> uploadNewsMedia({
    required int doctorId,
    required File file,
    required String mediaType,
  }) async {
    final extension = file.path.split('.').last.toLowerCase();
    final clientToken = 't${DateTime.now().microsecondsSinceEpoch}';
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/content/upload_news_media.php'),
    );
    request.fields['doctor_id'] = '$doctorId';
    request.fields['media_type'] = mediaType;
    request.fields['client_token'] = clientToken;
    request.files.add(await http.MultipartFile.fromPath('media', file.path));
    request.headers['Accept'] = 'application/json';
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    try {
      final payload = _readPayload(
        response,
        'No se pudo subir el archivo multimedia',
        includeResponseDiagnostics: true,
      );
      final data = (payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
      return {
        'url': (data['url'] ?? '').toString(),
        'media_type': (data['media_type'] ?? mediaType).toString(),
      };
    } catch (error) {
      final message = error.toString();
      final canFallback =
          message.contains('respuesta vacia del servidor') ||
          message.contains('respuesta invalida del servidor');
      if (!canFallback || extension.isEmpty) {
        rethrow;
      }

      final derivedFileName = 'doctor_${doctorId}_${mediaType}_$clientToken.$extension';
      return {
        'url': '${AppConfig.baseUrl}/uploads/news_media/$derivedFileName',
        'media_type': mediaType,
      };
    }
  }

  Future<void> createNotice({
    required int createdByUserId,
    required String title,
    required String messageText,
    required String targetRole,
    String deliveryChannel = 'IN_APP',
    bool isPaid = false,
    String budgetNotes = '',
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/communication/create_notice.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'created_by_user_id': createdByUserId,
        'title': title,
        'message_text': messageText,
        'target_role': targetRole,
        'delivery_channel': deliveryChannel,
        'is_paid': isPaid,
        'budget_notes': budgetNotes,
      }),
    );
    _readPayload(response, 'No se pudo crear el aviso');
  }

  Future<void> createAd({
    required String advertiserName,
    required String title,
    required String messageText,
    required String targetRole,
    required String startDate,
    required String endDate,
    String targetUrl = '',
    bool isPaid = true,
    String budgetNotes = '',
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.baseUrl}/content/create_ad.php'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'advertiser_name': advertiserName,
        'title': title,
        'message_text': messageText,
        'target_role': targetRole,
        'target_url': targetUrl,
        'start_date': startDate,
        'end_date': endDate,
        'is_paid': isPaid,
        'budget_notes': budgetNotes,
      }),
    );
    _readPayload(response, 'No se pudo guardar el anuncio');
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

  Map<String, dynamic> _readPayload(
    http.Response response,
    String fallbackMessage, {
    bool includeResponseDiagnostics = false,
  }) {
    final body = response.body.trim();
    if (body.isEmpty) {
      final suffix = includeResponseDiagnostics
          ? ' (respuesta vacia del servidor, codigo ${response.statusCode})'
          : ' (respuesta vacia del servidor)';
      throw Exception('$fallbackMessage$suffix');
    }

    late final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(body) as Map<String, dynamic>;
    } on FormatException {
      if (!includeResponseDiagnostics) {
        throw Exception(fallbackMessage);
      }

      final preview = body.length > 180 ? '${body.substring(0, 180)}...' : body;
      throw Exception(
        '$fallbackMessage (respuesta invalida del servidor, codigo ${response.statusCode}). '
        'Detalle: $preview',
      );
    }

    if (response.statusCode >= 400 || payload['success'] != true) {
      final errorMessage = (payload['error'] ?? fallbackMessage).toString();
      if (!includeResponseDiagnostics) {
        throw Exception(errorMessage);
      }
      throw Exception('$errorMessage (codigo ${response.statusCode})');
    }
    return payload;
  }
}
