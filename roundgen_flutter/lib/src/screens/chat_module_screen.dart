import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/assistant_summary_data.dart';
import '../models/auth_user.dart';
import '../models/chat_message_data.dart';
import '../models/doctor_summary_data.dart';
import '../models/patient_summary.dart';
import '../models/role_type.dart';
import '../services/agenda_service.dart';
import '../services/chat_service.dart';
import '../services/patient_service.dart';

enum _ConversationKind { doctorPatient, assistantPatient, assistantDoctor }

class ChatModuleScreen extends StatefulWidget {
  const ChatModuleScreen({super.key, required this.currentUser});

  final AuthUser currentUser;

  @override
  State<ChatModuleScreen> createState() => _ChatModuleScreenState();
}

class _ChatModuleScreenState extends State<ChatModuleScreen> {
  final ChatService _chatService = ChatService();
  final PatientService _patientService = PatientService();
  final AgendaService _agendaService = AgendaService();

  bool _loading = true;
  String? _errorMessage;

  List<PatientSummary> _patients = const [];
  List<DoctorSummaryData> _doctors = const [];
  List<AssistantSummaryData> _assistants = const [];
  List<_ThreadPreview<PatientSummary>> _doctorPatientPreviews = const [];
  List<_ThreadPreview<PatientSummary>> _assistantPatientPreviews = const [];
  List<_ThreadPreview<AssistantSummaryData>> _doctorAssistantPreviews = const [];
  List<_ThreadPreview<DoctorSummaryData>> _assistantDoctorPreviews = const [];

  PatientSummary? _selfPatient;
  DoctorSummaryData? _selectedPatientDoctor;
  AssistantSummaryData? _defaultAssistant;
  Timer? _refreshTimer;

  bool get _isDoctor => widget.currentUser.role == RoleType.doctor;
  bool get _isAssistant => widget.currentUser.role == RoleType.assistant;
  bool get _isPatient => widget.currentUser.role == RoleType.patient;

  int get _patientDoctorUnreadTotal => _sumUnread(_doctorPatientPreviews);
  int get _patientAssistantUnreadTotal => _defaultAssistant == null
      ? 0
      : _assistantUnreadForAssistant(_defaultAssistant!.id);
  int get _doctorPatientUnreadTotal => _sumUnread(_doctorPatientPreviews);
  int get _doctorAssistantUnreadTotal => _sumUnread(_doctorAssistantPreviews);
  int get _assistantPatientUnreadTotal => _sumUnread(_assistantPatientPreviews);
  int get _assistantDoctorUnreadTotal => _sumUnread(_assistantDoctorPreviews);

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final doctors = await _agendaService.loadDoctors();
      final patients = await (_isDoctor
          ? _patientService.loadPatients(doctorId: widget.currentUser.doctorId)
          : _patientService.loadPatients());

      final visiblePatients = _isPatient
          ? patients.where((patient) => patient.id == widget.currentUser.patientId).toList()
          : patients;

      final selfPatient = _isPatient && visiblePatients.isNotEmpty ? visiblePatients.first : null;
      final preferredDoctorId = selfPatient?.primaryDoctorId;
      final selectedPatientDoctor = _isPatient
          ? doctors.firstWhereOrNull((doctor) => doctor.id == preferredDoctorId) ??
              doctors.firstWhereOrNull((_) => true)
          : null;

      var assistants = await _chatService.loadAssistants(
        doctorId: _isDoctor
            ? widget.currentUser.doctorId
            : selectedPatientDoctor?.id ?? preferredDoctorId,
      );
      if (_isPatient && assistants.isEmpty) {
        assistants = await _chatService.loadAssistants();
      }

      final defaultAssistant = assistants.isNotEmpty ? assistants.first : null;
      final doctorPatientPreviews = _isDoctor
          ? await _loadPatientPreviews(visiblePatients, _ConversationKind.doctorPatient)
          : const <_ThreadPreview<PatientSummary>>[];
      final assistantPatientPreviews = _isAssistant
          ? await _loadPatientPreviews(visiblePatients, _ConversationKind.assistantPatient)
          : const <_ThreadPreview<PatientSummary>>[];
      final doctorAssistantPreviews = _isDoctor
          ? await _loadAssistantPreviews(assistants)
          : const <_ThreadPreview<AssistantSummaryData>>[];
      final assistantDoctorPreviews = _isAssistant
          ? await _loadDoctorPreviews(doctors)
          : const <_ThreadPreview<DoctorSummaryData>>[];

      if (!mounted) return;
      setState(() {
        _patients = visiblePatients;
        _doctors = doctors;
        _assistants = assistants;
        _selfPatient = selfPatient;
        _selectedPatientDoctor = selectedPatientDoctor;
        _defaultAssistant = defaultAssistant;
        _doctorPatientPreviews = doctorPatientPreviews;
        _assistantPatientPreviews = assistantPatientPreviews;
        _doctorAssistantPreviews = doctorAssistantPreviews;
        _assistantDoctorPreviews = assistantDoctorPreviews;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendly(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _viewerSenderRole(_ConversationKind kind) {
    switch (kind) {
      case _ConversationKind.doctorPatient:
        return _isDoctor ? 'DOCTOR' : 'PATIENT';
      case _ConversationKind.assistantPatient:
        return _isAssistant ? 'SECRETARY' : 'PATIENT';
      case _ConversationKind.assistantDoctor:
        return _isAssistant ? 'SECRETARY' : 'DOCTOR';
    }
  }

  int _countUnread(List<ChatMessageData> messages, _ConversationKind kind) {
    final viewerRole = _viewerSenderRole(kind);
    return messages.where((message) => !message.isRead && message.senderRole != viewerRole).length;
  }

  int _sumUnread<T>(List<_ThreadPreview<T>> previews) {
    return previews.fold(0, (total, preview) => total + preview.unreadCount);
  }

  int _assistantUnreadForAssistant(int assistantUserId) {
    final preview = _doctorAssistantPreviews.firstWhereOrNull(
      (item) => item.contact.id == assistantUserId,
    );
    return preview?.unreadCount ?? 0;
  }

  Future<List<_ThreadPreview<PatientSummary>>> _loadPatientPreviews(
    List<PatientSummary> patients,
    _ConversationKind kind,
  ) async {
    final previews = <_ThreadPreview<PatientSummary>>[];
    for (final patient in patients) {
      try {
        final messages = kind == _ConversationKind.doctorPatient
            ? await _chatService.loadMessages(
                doctorId: _isDoctor
                    ? widget.currentUser.doctorId
                    : patient.primaryDoctorId ?? _selectedPatientDoctor?.id,
                patientId: patient.id,
              )
            : await _chatService.loadAssistantMessages(patientId: patient.id);
        if (messages.isNotEmpty) {
          previews.add(
            _ThreadPreview(
              contact: patient,
              lastMessage: messages.first,
              totalMessages: messages.length,
              unreadCount: _countUnread(messages, kind),
            ),
          );
        }
      } catch (_) {}
    }
    previews.sort((a, b) => b.lastMessage.sentAt.compareTo(a.lastMessage.sentAt));
    return previews;
  }

  Future<List<_ThreadPreview<AssistantSummaryData>>> _loadAssistantPreviews(
    List<AssistantSummaryData> assistants,
  ) async {
    final previews = <_ThreadPreview<AssistantSummaryData>>[];
    for (final assistant in assistants) {
      try {
        final messages = await _chatService.loadAssistantDoctorMessages(
          doctorId: widget.currentUser.doctorId,
          assistantUserId: assistant.id,
        );
        if (messages.isNotEmpty) {
          previews.add(
            _ThreadPreview(
              contact: assistant,
              lastMessage: messages.first,
              totalMessages: messages.length,
              unreadCount: _countUnread(messages, _ConversationKind.assistantDoctor),
            ),
          );
        }
      } catch (_) {}
    }
    previews.sort((a, b) => b.lastMessage.sentAt.compareTo(a.lastMessage.sentAt));
    return previews;
  }

  Future<List<_ThreadPreview<DoctorSummaryData>>> _loadDoctorPreviews(
    List<DoctorSummaryData> doctors,
  ) async {
    final previews = <_ThreadPreview<DoctorSummaryData>>[];
    for (final doctor in doctors) {
      try {
        final messages = await _chatService.loadAssistantDoctorMessages(
          doctorId: doctor.id,
          assistantUserId: widget.currentUser.id,
        );
        if (messages.isNotEmpty) {
          previews.add(
            _ThreadPreview(
              contact: doctor,
              lastMessage: messages.first,
              totalMessages: messages.length,
              unreadCount: _countUnread(messages, _ConversationKind.assistantDoctor),
            ),
          );
        }
      } catch (_) {}
    }
    previews.sort((a, b) => b.lastMessage.sentAt.compareTo(a.lastMessage.sentAt));
    return previews;
  }

  String _friendly(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) return 'No se pudieron cargar los chats.';
    if (raw.contains('ClientFailed to fetch') ||
        raw.contains('SocketException') ||
        raw.contains('Failed host lookup')) {
      return 'No pudimos conectar con el servidor del chat por ahora.';
    }
    return raw;
  }

  Future<void> _openPatientConversation(PatientSummary patient, _ConversationKind kind) async {
    final doctorId = kind == _ConversationKind.doctorPatient
        ? (_isDoctor ? widget.currentUser.doctorId : (_selectedPatientDoctor?.id ?? patient.primaryDoctorId))
        : null;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ConversationScreen(
          currentUser: widget.currentUser,
          chatService: _chatService,
          title: patient.fullName,
          kind: kind,
          patient: patient,
          doctorId: doctorId,
          assistantUserId: kind == _ConversationKind.assistantPatient
              ? (_isAssistant ? widget.currentUser.id : _defaultAssistant?.id)
              : null,
        ),
      ),
    );
    if (!mounted) return;
    await _bootstrap();
  }

  Future<void> _openAssistantDoctorConversation(
    DoctorSummaryData doctor,
    AssistantSummaryData assistant,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ConversationScreen(
          currentUser: widget.currentUser,
          chatService: _chatService,
          title: _isDoctor ? assistant.fullName : doctor.fullName,
          kind: _ConversationKind.assistantDoctor,
          doctorId: doctor.id,
          assistantUserId: assistant.id,
        ),
      ),
    );
    if (!mounted) return;
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(colors: [Color(0xFF0A6774), Color(0xFF2D59C4)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isDoctor
                        ? 'Mensajes del medico'
                        : _isAssistant
                            ? 'Mensajes del asistente'
                            : 'Mensajes del paciente',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isDoctor
                        ? 'Chats separados con pacientes y asistente.'
                        : _isAssistant
                            ? 'Chats separados con pacientes y medicos.'
                            : 'Chats separados con tu medico y con el asistente.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _isPatient
                    ? _buildPatientView()
                    : _isDoctor
                        ? _buildDoctorView()
                        : _buildAssistantView(),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientView() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              tabs: [
                Tab(child: _SectionTabLabel(label: 'Medico', count: _patientDoctorUnreadTotal)),
                Tab(child: _SectionTabLabel(label: 'Asistente', count: _patientAssistantUnreadTotal)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                if (_selfPatient == null)
                  const Center(child: Text('No se encontro tu perfil de paciente.'))
                else
                  Column(
                    children: [
                      if (_doctors.length > 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: DropdownButtonFormField<DoctorSummaryData>(
                            initialValue: _selectedPatientDoctor,
                            decoration: const InputDecoration(labelText: 'Medico'),
                            items: _doctors
                                .map(
                                  (doctor) => DropdownMenuItem(
                                    value: doctor,
                                    child: Text('${doctor.fullName} | ${doctor.specialty}'),
                                  ),
                                )
                                .toList(),
                            onChanged: (doctor) {
                              setState(() => _selectedPatientDoctor = doctor);
                            },
                          ),
                        ),
                      Expanded(
                        child: _selectedPatientDoctor == null
                            ? const Center(child: Text('No tienes un medico disponible por ahora.'))
                            : _ConversationScreen(
                                currentUser: widget.currentUser,
                                chatService: _chatService,
                                title: _selectedPatientDoctor!.fullName,
                                kind: _ConversationKind.doctorPatient,
                                patient: _selfPatient,
                                doctorId: _selectedPatientDoctor!.id,
                                embedded: true,
                              ),
                      ),
                    ],
                  ),
                _selfPatient == null || _defaultAssistant == null
                    ? const Center(child: Text('No hay un asistente disponible por ahora.'))
                    : _ConversationScreen(
                        currentUser: widget.currentUser,
                        chatService: _chatService,
                        title: _defaultAssistant!.fullName,
                        kind: _ConversationKind.assistantPatient,
                        patient: _selfPatient,
                        assistantUserId: _defaultAssistant!.id,
                        embedded: true,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorView() {
    final selfDoctor = _doctors.firstWhereOrNull((doctor) => doctor.id == widget.currentUser.doctorId);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              tabs: [
                Tab(child: _SectionTabLabel(label: 'Pacientes', count: _doctorPatientUnreadTotal)),
                Tab(child: _SectionTabLabel(label: 'Asistente', count: _doctorAssistantUnreadTotal)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _roleSection(
                  previews: _doctorPatientPreviews,
                  contacts: _patients,
                  onPreviewTap: (preview) => _openPatientConversation(
                    preview.contact,
                    _ConversationKind.doctorPatient,
                  ),
                  onNewTap: (patient) => _openPatientConversation(
                    patient,
                    _ConversationKind.doctorPatient,
                  ),
                  previewTitle: (preview) => preview.contact.fullName,
                  previewSubtitle: (preview) => _PreviewContent(preview: preview),
                  newTitle: (patient) => patient.fullName,
                  newSubtitle: (patient) => Text(
                    patient.medicalRecordNumber.isEmpty ? 'Sin folio clinico' : patient.medicalRecordNumber,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                _simpleSection(
                  items: _assistants,
                  title: 'Asistente',
                  subtitle: 'Selecciona un asistente para abrir el chat.',
                  itemTitle: (assistant) => assistant.fullName,
                  itemSubtitle: (assistant) {
                    final preview = _doctorAssistantPreviews.firstWhereOrNull(
                      (item) => item.contact.id == assistant.id,
                    );
                    return preview == null
                        ? Text(assistant.email, style: const TextStyle(color: Color(0xFF64748B)))
                        : _PreviewContent(preview: preview);
                  },
                  onTap: (assistant) {
                    if (selfDoctor != null) {
                      _openAssistantDoctorConversation(selfDoctor, assistant);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantView() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              tabs: [
                Tab(child: _SectionTabLabel(label: 'Pacientes', count: _assistantPatientUnreadTotal)),
                Tab(child: _SectionTabLabel(label: 'Medicos', count: _assistantDoctorUnreadTotal)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _roleSection(
                  previews: _assistantPatientPreviews,
                  contacts: _patients,
                  onPreviewTap: (preview) => _openPatientConversation(
                    preview.contact,
                    _ConversationKind.assistantPatient,
                  ),
                  onNewTap: (patient) => _openPatientConversation(
                    patient,
                    _ConversationKind.assistantPatient,
                  ),
                  previewTitle: (preview) => preview.contact.fullName,
                  previewSubtitle: (preview) => _PreviewContent(preview: preview),
                  newTitle: (patient) => patient.fullName,
                  newSubtitle: (patient) => Text(
                    patient.medicalRecordNumber.isEmpty ? 'Sin folio clinico' : patient.medicalRecordNumber,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                _simpleSection(
                  items: _doctors,
                  title: 'Medicos',
                  subtitle: 'Selecciona un medico para abrir el chat.',
                  itemTitle: (doctor) => doctor.fullName,
                  itemSubtitle: (doctor) {
                    final preview = _assistantDoctorPreviews.firstWhereOrNull(
                      (item) => item.contact.id == doctor.id,
                    );
                    return preview == null
                        ? Text(doctor.specialty, style: const TextStyle(color: Color(0xFF64748B)))
                        : _PreviewContent(preview: preview);
                  },
                  onTap: (doctor) => _openAssistantDoctorConversation(
                    doctor,
                    AssistantSummaryData(
                      id: widget.currentUser.id,
                      fullName: widget.currentUser.fullName,
                      email: widget.currentUser.email,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleSection({
    required List<_ThreadPreview<PatientSummary>> previews,
    required List<PatientSummary> contacts,
    required ValueChanged<_ThreadPreview<PatientSummary>> onPreviewTap,
    required ValueChanged<PatientSummary> onNewTap,
    required String Function(_ThreadPreview<PatientSummary>) previewTitle,
    required Widget Function(_ThreadPreview<PatientSummary>) previewSubtitle,
    required String Function(PatientSummary) newTitle,
    required Widget Function(PatientSummary) newSubtitle,
  }) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Chats activos',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (previews.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Todavia no hay conversaciones activas.'),
            ),
          )
        else
          ...previews.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    previewTitle(item),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: previewSubtitle(item),
                  ),
                  trailing: item.unreadCount > 0
                      ? _UnreadBadge(count: item.unreadCount)
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () => onPreviewTap(item),
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Text(
          'Nuevo chat',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (contacts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No hay contactos disponibles.'),
            ),
          )
        else
          ...contacts.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    newTitle(item),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: newSubtitle(item),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onNewTap(item),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _simpleSection<T>({
    required List<T> items,
    required String title,
    required String subtitle,
    required String Function(T) itemTitle,
    required Widget Function(T) itemSubtitle,
    required ValueChanged<T> onTap,
  }) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(subtitle),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No hay contactos disponibles.'),
            ),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    itemTitle(item),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: itemSubtitle(item),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onTap(item),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConversationScreen extends StatefulWidget {
  const _ConversationScreen({
    required this.currentUser,
    required this.chatService,
    required this.title,
    required this.kind,
    this.patient,
    this.doctorId,
    this.assistantUserId,
    this.embedded = false,
  });

  final AuthUser currentUser;
  final ChatService chatService;
  final String title;
  final _ConversationKind kind;
  final PatientSummary? patient;
  final int? doctorId;
  final int? assistantUserId;
  final bool embedded;

  @override
  State<_ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<_ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  Timer? _pollingTimer;

  bool _loading = true;
  bool _sending = false;
  String? _errorMessage;
  List<ChatMessageData> _messages = const [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || _sending) return;
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  String get _readerRole => switch (widget.kind) {
        _ConversationKind.doctorPatient => widget.currentUser.role == RoleType.doctor ? 'DOCTOR' : 'PATIENT',
        _ConversationKind.assistantPatient => widget.currentUser.role == RoleType.assistant ? 'SECRETARY' : 'PATIENT',
        _ConversationKind.assistantDoctor => widget.currentUser.role == RoleType.assistant ? 'SECRETARY' : 'DOCTOR',
      };

  bool _isMine(ChatMessageData message) {
    return message.senderRole == _readerRole;
  }

  ChatMessageData _markMessageAsRead(ChatMessageData message) {
    return ChatMessageData(
      id: message.id,
      doctorId: message.doctorId,
      patientId: message.patientId,
      doctorName: message.doctorName,
      patientName: message.patientName,
      senderRole: message.senderRole,
      messageText: message.messageText,
      sentAt: message.sentAt,
      isRead: true,
    );
  }

  Future<void> _markCurrentThreadAsRead() async {
    final hasUnreadIncoming = _messages.any((message) => !message.isRead && !_isMine(message));
    if (!hasUnreadIncoming) return;
    await widget.chatService.markThreadAsRead(
      threadType: switch (widget.kind) {
        _ConversationKind.doctorPatient => ChatThreadType.doctorPatient,
        _ConversationKind.assistantPatient => ChatThreadType.assistantPatient,
        _ConversationKind.assistantDoctor => ChatThreadType.assistantDoctor,
      },
      readerRole: _readerRole,
      doctorId: widget.doctorId,
      patientId: widget.patient?.id,
      assistantUserId: widget.assistantUserId,
    );
    if (!mounted) return;
    setState(() {
      _messages = _messages.map((message) => _isMine(message) ? message : _markMessageAsRead(message)).toList();
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      List<ChatMessageData> messages;
      switch (widget.kind) {
        case _ConversationKind.doctorPatient:
          if (widget.patient == null || widget.doctorId == null) {
            throw Exception('No hay un medico asignado para esta conversacion.');
          }
          messages = await widget.chatService.loadMessages(
            doctorId: widget.doctorId,
            patientId: widget.patient!.id,
          );
          break;
        case _ConversationKind.assistantPatient:
          if (widget.patient == null) {
            throw Exception('No hay un paciente ligado a esta conversacion.');
          }
          messages = await widget.chatService.loadAssistantMessages(patientId: widget.patient!.id);
          break;
        case _ConversationKind.assistantDoctor:
          if (widget.doctorId == null || widget.assistantUserId == null) {
            throw Exception('No hay un medico o asistente asignado para esta conversacion.');
          }
          messages = await widget.chatService.loadAssistantDoctorMessages(
            doctorId: widget.doctorId,
            assistantUserId: widget.assistantUserId,
          );
          break;
      }
      if (!mounted) return;
      setState(() => _messages = messages);
      await _markCurrentThreadAsRead();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendly(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final ChatMessageData created;
      switch (widget.kind) {
        case _ConversationKind.doctorPatient:
          if (widget.patient == null || widget.doctorId == null) {
            throw Exception('No hay un medico asignado para esta conversacion.');
          }
          created = await widget.chatService.sendMessage(
            doctorId: widget.doctorId!,
            patientId: widget.patient!.id,
            senderRole: widget.currentUser.role == RoleType.doctor ? 'DOCTOR' : 'PATIENT',
            messageText: text,
          );
          break;
        case _ConversationKind.assistantPatient:
          if (widget.patient == null || widget.assistantUserId == null) {
            throw Exception('No hay un asistente asignado para esta conversacion.');
          }
          created = await widget.chatService.sendAssistantMessage(
            patientId: widget.patient!.id,
            assistantUserId: widget.assistantUserId!,
            senderRole: widget.currentUser.role == RoleType.assistant ? 'SECRETARY' : 'PATIENT',
            messageText: text,
          );
          break;
        case _ConversationKind.assistantDoctor:
          if (widget.doctorId == null || widget.assistantUserId == null) {
            throw Exception('No hay un medico o asistente asignado para esta conversacion.');
          }
          created = await widget.chatService.sendAssistantDoctorMessage(
            doctorId: widget.doctorId!,
            assistantUserId: widget.assistantUserId!,
            senderRole: widget.currentUser.role == RoleType.assistant ? 'SECRETARY' : 'DOCTOR',
            messageText: text,
          );
          break;
      }
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _messages = [created, ..._messages];
        _errorMessage = null;
      });
      await _loadMessages();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendly(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  String _friendly(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) return 'No se pudo completar la accion del chat.';
    if (raw.contains('ClientFailed to fetch') ||
        raw.contains('SocketException') ||
        raw.contains('Failed host lookup')) {
      return 'No pudimos conectar con el servidor del chat por ahora.';
    }
    if (raw.contains('respuesta vacia del servidor')) {
      return 'El servidor del chat no devolvio informacion valida.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF3F8),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: _messages.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Todavia no hay mensajes en esta conversacion.'),
                          ),
                        )
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final mine = _isMine(message);
                            return Align(
                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                constraints: const BoxConstraints(maxWidth: 300),
                                decoration: BoxDecoration(
                                  color: mine ? const Color(0xFFD9FDD3) : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(mine ? 18 : 6),
                                    bottomRight: Radius.circular(mine ? 6 : 18),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(message.messageText),
                                    const SizedBox(height: 6),
                                    Text(
                                      DateFormat('dd/MM HH:mm').format(
                                        DateTime.tryParse(message.sentAt.replaceFirst(' ', 'T')) ?? DateTime.now(),
                                      ),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje para ${widget.title}',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: _sending ? null : _sendMessage,
                icon: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
    if (widget.embedded) return content;
    return Scaffold(appBar: AppBar(title: Text(widget.title)), body: content);
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.preview});

  final _ThreadPreview<dynamic> preview;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            preview.lastMessage.messageText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          DateFormat('dd/MM HH:mm').format(
            DateTime.tryParse(preview.lastMessage.sentAt.replaceFirst(' ', 'T')) ?? DateTime.now(),
          ),
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        if (preview.unreadCount > 0) ...[
          const SizedBox(width: 8),
          _UnreadBadge(count: preview.unreadCount),
        ],
      ],
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A6774),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _SectionTabLabel extends StatelessWidget {
  const _SectionTabLabel({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 8),
          _UnreadBadge(count: count),
        ],
      ],
    );
  }
}

class _ThreadPreview<T> {
  const _ThreadPreview({
    required this.contact,
    required this.lastMessage,
    required this.totalMessages,
    required this.unreadCount,
  });

  final T contact;
  final ChatMessageData lastMessage;
  final int totalMessages;
  final int unreadCount;
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
