import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/appointment_data.dart';
import '../models/auth_user.dart';
import '../models/chat_message_data.dart';
import '../models/news_item_data.dart';
import '../models/role_type.dart';
import 'agenda_service.dart';
import 'chat_service.dart';
import 'content_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final AgendaService _agendaService = AgendaService();
  final ChatService _chatService = ChatService();
  final ContentService _contentService = ContentService();

  bool _initialized = false;
  bool _fcmInitialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        'roundgen_messages',
        'Mensajes ROUNDGEN',
        description: 'Alertas de mensajes nuevos.',
        importance: Importance.high,
      ),
    );
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        'roundgen_appointments',
        'Citas ROUNDGEN',
        description: 'Recordatorios locales de citas medicas.',
        importance: Importance.high,
      ),
    );
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        'roundgen_news',
        'Noticias ROUNDGEN',
        description: 'Avisos locales de noticias y novedades.',
        importance: Importance.defaultImportance,
      ),
    );

    _initialized = true;
  }

  Future<void> initializeFcm() async {
    if (kIsWeb || _fcmInitialized) return;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true, provisional: false);
      await messaging.getToken();
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onForegroundMessage);
      _fcmInitialized = true;
    } catch (_) {
      _fcmInitialized = false;
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await initialize();
    await _plugin.show(
      500000 + DateTime.now().millisecondsSinceEpoch.remainder(100000),
      notification.title ?? 'ROUNDGEN',
      notification.body ?? 'Tienes una nueva notificacion.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'roundgen_messages',
          'Mensajes ROUNDGEN',
          channelDescription: 'Alertas y notificaciones push de ROUNDGEN.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> syncForUser(AuthUser user) async {
    if (kIsWeb) return;

    await initialize();

    try {
      await _syncAppointments(user);
    } catch (_) {}

    try {
      await _syncMessages(user);
    } catch (_) {}

    try {
      await _syncNews();
    } catch (_) {}
  }

  Future<void> _syncAppointments(AuthUser user) async {
    final appointments = await _loadAppointmentsForUser(user);
    final prefs = await SharedPreferences.getInstance();

    for (final appointment in appointments) {
      final appointmentStart = DateTime.tryParse('${appointment.appointmentDate}T${appointment.startTime}');
      if (appointmentStart == null) continue;
      final reminderTime = appointmentStart.subtract(const Duration(hours: 1));
      final now = DateTime.now();
      if (appointmentStart.isBefore(now)) continue;

      final key = 'scheduled_reminder_${user.id}_${appointment.id}';
      if (prefs.getBool(key) == true) continue;

      if (reminderTime.isAfter(now)) {
        await _plugin.zonedSchedule(
          200000 + (user.id * 1000) + appointment.id,
          'Recordatorio de cita',
          _appointmentBody(user, appointment),
          tz.TZDateTime.from(reminderTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'roundgen_appointments',
              'Citas ROUNDGEN',
              channelDescription: 'Recordatorios locales de citas medicas.',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        await prefs.setBool(key, true);
      } else if (appointmentStart.isAfter(now)) {
        await _plugin.show(
          300000 + (user.id * 1000) + appointment.id,
          'Cita proxima',
          _appointmentBody(user, appointment),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'roundgen_appointments',
              'Citas ROUNDGEN',
              channelDescription: 'Recordatorios locales de citas medicas.',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
        await prefs.setBool(key, true);
      }
    }
  }

  Future<void> _syncMessages(AuthUser user) async {
    final messages = await _loadMessagesForUser(user);
    if (messages.isEmpty) return;

    final incoming = messages.where((message) => !_isOwnMessage(user.role, message.senderRole)).toList()
      ..sort((left, right) => left.id.compareTo(right.id));

    if (incoming.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'last_notified_message_${user.id}_${user.role.code}';
    final lastNotified = prefs.getInt(key);
    final latestIncomingId = incoming.last.id;

    if (lastNotified == null) {
      await prefs.setInt(key, latestIncomingId);
      return;
    }

    final freshMessages = incoming.where((message) => message.id > lastNotified).toList();
    if (freshMessages.isEmpty) return;

    final latestMessage = freshMessages.last;
    await _plugin.show(
      100000 + (user.id * 1000) + latestMessage.id,
      'Nuevo mensaje en ROUNDGEN',
      _messageBody(user, latestMessage),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'roundgen_messages',
          'Mensajes ROUNDGEN',
          channelDescription: 'Alertas de mensajes nuevos.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    await prefs.setInt(key, latestIncomingId);
  }

  Future<void> _syncNews() async {
    final news = await _contentService.loadNews();
    final published = news.where((item) => item.isPublished).toList()..sort((a, b) => a.id.compareTo(b.id));
    if (published.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final lastNotified = prefs.getInt('last_notified_news_id');
    final latest = published.last;

    if (lastNotified == null) {
      await prefs.setInt('last_notified_news_id', latest.id);
      return;
    }
    if (latest.id <= lastNotified) return;

    await _plugin.show(
      400000 + latest.id,
      'Nueva noticia en ROUNDGEN',
      _newsBody(latest),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'roundgen_news',
          'Noticias ROUNDGEN',
          channelDescription: 'Avisos locales de noticias y novedades.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
    await prefs.setInt('last_notified_news_id', latest.id);
  }

  Future<List<AppointmentData>> _loadAppointmentsForUser(AuthUser user) {
    switch (user.role) {
      case RoleType.admin:
        return Future.value(const []);
      case RoleType.doctor:
        return _agendaService.loadAppointments(doctorId: user.doctorId);
      case RoleType.assistant:
        return _agendaService.loadAppointments();
      case RoleType.patient:
        return _agendaService.loadAppointments(patientId: user.patientId);
    }
  }

  Future<List<ChatMessageData>> _loadMessagesForUser(AuthUser user) async {
    switch (user.role) {
      case RoleType.admin:
        return const [];
      case RoleType.doctor:
        final doctorMessages = await _chatService.loadMessages(doctorId: user.doctorId);
        final assistantMessages = await _chatService.loadAssistantDoctorMessages(doctorId: user.doctorId);
        return [...doctorMessages, ...assistantMessages]..sort((a, b) => b.id.compareTo(a.id));
      case RoleType.assistant:
        final patientMessages = await _chatService.loadAssistantMessages();
        final doctorMessages = await _chatService.loadAssistantDoctorMessages(assistantUserId: user.id);
        return [...patientMessages, ...doctorMessages]..sort((a, b) => b.id.compareTo(a.id));
      case RoleType.patient:
        final doctorMessages = await _chatService.loadMessages(patientId: user.patientId);
        final assistantMessages = await _chatService.loadAssistantMessages(patientId: user.patientId);
        return [...doctorMessages, ...assistantMessages]..sort((a, b) => b.id.compareTo(a.id));
    }
  }

  bool _isOwnMessage(RoleType role, String senderRole) {
    switch (role) {
      case RoleType.admin:
        return false;
      case RoleType.doctor:
        return senderRole == 'DOCTOR';
      case RoleType.assistant:
        return senderRole == 'SECRETARY';
      case RoleType.patient:
        return senderRole == 'PATIENT';
    }
  }

  String _appointmentBody(AuthUser user, AppointmentData appointment) {
    switch (user.role) {
      case RoleType.admin:
        return 'Hay una cita proxima en ROUNDGEN.';
      case RoleType.doctor:
        return 'En una hora tienes cita con ${appointment.patientName} en ${appointment.roomName}.';
      case RoleType.assistant:
        return 'La cita de ${appointment.patientName} con ${appointment.doctorName} inicia en una hora.';
      case RoleType.patient:
        return 'Tu cita con ${appointment.doctorName} en ${appointment.roomName} es en una hora.';
    }
  }

  String _messageBody(AuthUser user, ChatMessageData message) {
    switch (user.role) {
      case RoleType.admin:
        return message.messageText;
      case RoleType.doctor:
        return message.senderRole == 'SECRETARY'
            ? 'Asistente: ${message.messageText}'
            : '${message.patientName}: ${message.messageText}';
      case RoleType.assistant:
        return message.senderRole == 'DOCTOR'
            ? '${message.doctorName}: ${message.messageText}'
            : '${message.patientName}: ${message.messageText}';
      case RoleType.patient:
        return message.senderRole == 'SECRETARY'
            ? 'Asistente: ${message.messageText}'
            : '${message.doctorName.isEmpty ? 'Tu medico' : message.doctorName}: ${message.messageText}';
    }
  }

  String _newsBody(NewsItemData newsItem) {
    final preview = newsItem.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return preview.length > 90 ? '${preview.substring(0, 90)}...' : preview;
  }
}

