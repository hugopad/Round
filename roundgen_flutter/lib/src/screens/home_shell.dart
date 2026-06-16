import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../models/chat_message_data.dart';
import '../models/dashboard_module.dart';
import '../models/doctor_summary_data.dart';
import '../models/patient_summary.dart';
import '../models/role_type.dart';
import '../services/agenda_service.dart';
import '../services/chat_service.dart';
import '../services/patient_service.dart';
import 'agenda_module_screen.dart';
import 'admin_email_config_hub_screen.dart';
import 'admin_operations_screen.dart';
import 'assistant_operations_screen.dart';
import 'assistant_patient_intake_page.dart';
import 'broadcast_management_screen.dart';
import 'chat_module_screen.dart';
import 'doctor_public_profile_screen.dart';
import 'doctor_schedule_settings_screen.dart';
import 'doctor_subscription_screen.dart';
import 'doctor_team_management_screen.dart';
import 'modules_overview_screen.dart';
import 'news_module_screen.dart';
import 'admin_subscription_management_screen.dart';
import 'patients_module_screen.dart';
import 'public_doctor_directory_screen.dart';
import 'role_dashboard_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

  final AuthUser currentUser;
  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final ChatService _chatService = ChatService();
  final PatientService _patientService = PatientService();
  final AgendaService _agendaService = AgendaService();
  Timer? _messageRefreshTimer;
  int _messageUnreadCount = 0;

  List<DashboardModule> _modulesForRole(RoleType role) {
    switch (role) {
      case RoleType.admin:
        return const [
          DashboardModule(title: 'Admin', subtitle: 'Aprobacion de medicos y control administrativo.', icon: Icons.admin_panel_settings_rounded),
          DashboardModule(title: 'Suscripciones', subtitle: 'Codigos, vigencias e historico de medicos.', icon: Icons.workspace_premium_rounded),
          DashboardModule(title: 'Noticias', subtitle: 'Gestiona avisos generales y contenido visible.', icon: Icons.newspaper_rounded),
          DashboardModule(title: 'Correo accesos', subtitle: 'Configura el correo SMTP por medico.', icon: Icons.alternate_email_rounded),
          DashboardModule(title: 'Difusion', subtitle: 'Avisos segmentados y publicidad pagada.', icon: Icons.campaign_rounded),
        ];
      case RoleType.doctor:
        return const [
          DashboardModule(title: 'Pacientes', subtitle: 'Consulta pacientes, expedientes y recetas.', icon: Icons.groups_rounded),
          DashboardModule(title: 'Agenda', subtitle: 'Calendario, citas y disponibilidad.', icon: Icons.calendar_month_rounded),
          DashboardModule(title: 'Horarios', subtitle: 'Configura, edita y borra tus bloques disponibles.', icon: Icons.schedule_rounded),
          DashboardModule(title: 'Mensajes', subtitle: 'Conversaciones tipo chat clinico.', icon: Icons.chat_bubble_rounded),
          DashboardModule(title: 'Noticias', subtitle: 'Calculadoras medicas y contenido actualizado.', icon: Icons.newspaper_rounded),
          DashboardModule(title: 'Suscripcion', subtitle: 'Consulta vigencia e ingresa codigos de renovacion.', icon: Icons.workspace_premium_rounded),
          DashboardModule(title: 'Perfil publico', subtitle: 'Edita tu ficha profesional visible para pacientes.', icon: Icons.badge_rounded),
          DashboardModule(title: 'Equipo', subtitle: 'Crea accesos para asistentes.', icon: Icons.manage_accounts_rounded),
        ];
      case RoleType.assistant:
        return const [
          DashboardModule(title: 'Pacientes', subtitle: 'Lista general, alta y recetas por paciente.', icon: Icons.groups_rounded),
          DashboardModule(title: 'Agenda', subtitle: 'Disponibilidad por medico, sala y horario.', icon: Icons.event_note_rounded),
          DashboardModule(title: 'Asistencia', subtitle: 'Alta, horarios medicos y seguimiento de citas.', icon: Icons.support_agent_rounded),
          DashboardModule(title: 'Mensajes', subtitle: 'Comunicacion con pacientes y medicos.', icon: Icons.mark_chat_read_rounded),
        ];
      case RoleType.patient:
        return const [
          DashboardModule(title: 'Pacientes', subtitle: 'Consulta tu expediente y tus recetas.', icon: Icons.description_rounded),
          DashboardModule(title: 'Citas', subtitle: 'Agenda por disponibilidad del medico.', icon: Icons.schedule_rounded),
          DashboardModule(title: 'Doctores', subtitle: 'Explora perfiles publicos aprobados y encuentra especialistas.', icon: Icons.local_hospital_rounded),
          DashboardModule(title: 'Mensajes', subtitle: 'Chat y envio de estudios.', icon: Icons.forum_rounded),
          DashboardModule(title: 'Noticias', subtitle: 'Contenido publicado por tus medicos asignados.', icon: Icons.newspaper_rounded),
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshUnreadCount();
    _messageRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      _refreshUnreadCount();
    });
  }

  @override
  void dispose() {
    _messageRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnreadCount() async {
    if (widget.currentUser.role == RoleType.admin) {
      if (!mounted) return;
      setState(() => _messageUnreadCount = 0);
      return;
    }
    try {
      final count = await _loadUnreadCount();
      if (!mounted) return;
      setState(() => _messageUnreadCount = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _messageUnreadCount = 0);
    }
  }

  Future<int> _loadUnreadCount() async {
    if (widget.currentUser.role == RoleType.doctor) {
      return _loadDoctorUnreadCount();
    }
    if (widget.currentUser.role == RoleType.assistant) {
      return _loadAssistantUnreadCount();
    }
    return _loadPatientUnreadCount();
  }

  Future<int> _loadDoctorUnreadCount() async {
    final doctorId = widget.currentUser.doctorId;
    if (doctorId == null || doctorId <= 0) return 0;
    final patients = await _patientService.loadPatients(doctorId: doctorId);
    final assistants = await _chatService.loadAssistants(doctorId: doctorId);
    var unread = 0;
    for (final patient in patients) {
      try {
        final messages = await _chatService.loadMessages(doctorId: doctorId, patientId: patient.id);
        unread += _countUnread(messages, 'DOCTOR');
      } catch (_) {}
    }
    for (final assistant in assistants) {
      try {
        final messages = await _chatService.loadAssistantDoctorMessages(
          doctorId: doctorId,
          assistantUserId: assistant.id,
        );
        unread += _countUnread(messages, 'DOCTOR');
      } catch (_) {}
    }
    return unread;
  }

  Future<int> _loadAssistantUnreadCount() async {
    final patients = await _patientService.loadPatients();
    final doctors = await _agendaService.loadDoctors();
    var unread = 0;
    for (final patient in patients) {
      try {
        final messages = await _chatService.loadAssistantMessages(patientId: patient.id);
        unread += _countUnread(messages, 'SECRETARY');
      } catch (_) {}
    }
    for (final doctor in doctors) {
      try {
        final messages = await _chatService.loadAssistantDoctorMessages(
          doctorId: doctor.id,
          assistantUserId: widget.currentUser.id,
        );
        unread += _countUnread(messages, 'SECRETARY');
      } catch (_) {}
    }
    return unread;
  }

  Future<int> _loadPatientUnreadCount() async {
    final patients = await _patientService.loadPatients();
    PatientSummary? selfPatient;
    for (final patient in patients) {
      if (patient.id == widget.currentUser.patientId) {
        selfPatient = patient;
        break;
      }
    }
    if (selfPatient == null) return 0;
    final doctors = await _agendaService.loadDoctors();
    DoctorSummaryData? selectedDoctor;
    for (final doctor in doctors) {
      if (doctor.id == selfPatient.primaryDoctorId) {
        selectedDoctor = doctor;
        break;
      }
    }
    selectedDoctor ??= doctors.isNotEmpty ? doctors.first : null;
    var unread = 0;
    if (selectedDoctor != null) {
      try {
        final doctorMessages = await _chatService.loadMessages(
          doctorId: selectedDoctor.id,
          patientId: selfPatient.id,
        );
        unread += _countUnread(doctorMessages, 'PATIENT');
      } catch (_) {}
    }
    final assistants = await _chatService.loadAssistants(
      doctorId: selectedDoctor?.id ?? selfPatient.primaryDoctorId,
    );
    if (assistants.isNotEmpty) {
      try {
        final assistantMessages = await _chatService.loadAssistantMessages(patientId: selfPatient.id);
        unread += _countUnread(assistantMessages, 'PATIENT');
      } catch (_) {}
    }
    return unread;
  }

  int _countUnread(List<ChatMessageData> messages, String viewerRole) {
    return messages.where((message) => !message.isRead && message.senderRole != viewerRole).length;
  }

  List<DashboardModule> _modulesWithBadges(List<DashboardModule> modules) {
    return modules
        .map(
          (module) => module.title == 'Mensajes'
              ? module.copyWith(badgeCount: _messageUnreadCount)
              : module,
        )
        .toList();
  }

  void _openModule(DashboardModule module) {
    final opensPatients = module.title == 'Pacientes' || module.title == 'Recetas';
    final opensAgenda = module.title == 'Agenda' || module.title == 'Citas';
    final opensSchedules = module.title == 'Horarios';
    final opensChat = module.title == 'Mensajes';
    final opensNews = module.title == 'Noticias';
    final opensAdmin = module.title == 'Admin';
    final opensBroadcast = module.title == 'Difusion';
    final opensAssistant = module.title == 'Asistencia';
    final opensDoctorProfile = module.title == 'Perfil publico';
    final opensDoctorEmailConfig = module.title == 'Correo accesos';
    final opensTeam = module.title == 'Equipo';
    final opensDoctorDirectory = module.title == 'Doctores';
    final opensSubscriptions = module.title == 'Suscripciones' || module.title == 'Suscripcion';

    if (opensPatients) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientsModuleScreen(currentUser: widget.currentUser)));
      return;
    }
    if (opensAgenda) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AgendaModuleScreen(currentUser: widget.currentUser)));
      return;
    }
    if (opensSchedules) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DoctorScheduleSettingsScreen(currentUser: widget.currentUser)));
      return;
    }
    if (opensAdmin && widget.currentUser.role == RoleType.admin) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminOperationsScreen(currentUser: widget.currentUser)));
      return;
    }
    if (opensBroadcast && widget.currentUser.role == RoleType.admin) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BroadcastManagementScreen(currentUser: widget.currentUser)));
      return;
    }
    if (opensSubscriptions && widget.currentUser.role == RoleType.admin) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminSubscriptionManagementScreen(currentUser: widget.currentUser)));
      return;
    }
    if (opensAssistant) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AssistantOperationsScreen(currentUser: widget.currentUser)));
      return;
    }
    if (opensChat) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatModuleScreen(currentUser: widget.currentUser)));
      return;
    }
    if (opensNews) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewsModuleScreen(currentUser: widget.currentUser)));
      return;
    }
    if (opensDoctorDirectory) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicDoctorDirectoryScreen(currentUser: widget.currentUser)));
      return;
    }
    if (opensDoctorProfile && widget.currentUser.doctorId != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DoctorPublicProfileScreen(doctorId: widget.currentUser.doctorId!)));
      return;
    }
    if (opensDoctorEmailConfig && widget.currentUser.role == RoleType.admin) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminEmailConfigHubScreen(currentUser: widget.currentUser)));
      return;
    }
    if (opensTeam && widget.currentUser.role == RoleType.doctor) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DoctorTeamManagementScreen(doctorId: widget.currentUser.doctorId!)));
      return;
    }
    if (opensSubscriptions && widget.currentUser.role == RoleType.doctor) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DoctorSubscriptionScreen(currentUser: widget.currentUser)));
      return;
    }
    if (widget.currentUser.role == RoleType.assistant) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AssistantPatientIntakeScreen(currentUser: widget.currentUser)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${module.title} sera el siguiente modulo a migrar en Flutter.')));
  }

  @override
  Widget build(BuildContext context) {
    final modules = _modulesWithBadges(_modulesForRole(widget.currentUser.role));
    final pages = [
      RoleDashboardScreen(currentUser: widget.currentUser, modules: modules, onModuleTap: _openModule),
      ModulesOverviewScreen(currentUser: widget.currentUser, modules: modules, onModuleTap: _openModule),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('ROUNDGEN | ${widget.currentUser.role.label}'),
        actions: [
          TextButton.icon(onPressed: widget.onLogout, icon: const Icon(Icons.logout_rounded), label: const Text('Salir')),
          const SizedBox(width: 8),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_rounded), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.widgets_rounded), label: 'Modulos'),
        ],
      ),
    );
  }
}
