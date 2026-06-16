import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/assistant_activity_data.dart';
import '../models/assistant_activity_summary_data.dart';
import '../models/assistant_summary_data.dart';
import '../services/staff_admin_service.dart';

class DoctorTeamManagementScreen extends StatefulWidget {
  const DoctorTeamManagementScreen({
    super.key,
    required this.doctorId,
  });

  final int doctorId;

  @override
  State<DoctorTeamManagementScreen> createState() => _DoctorTeamManagementScreenState();
}

class _DoctorTeamManagementScreenState extends State<DoctorTeamManagementScreen> {
  static const Map<String, String> _activityTypeLabels = {
    'ALL': 'Todo',
    'PATIENT_CREATED': 'Altas',
    'APPOINTMENT_CREATED': 'Citas',
    'PATIENT_MESSAGE_SENT': 'Mensajes a pacientes',
    'DOCTOR_MESSAGE_SENT': 'Mensajes a medico',
    'SCHEDULE_UPDATED': 'Horarios',
  };

  final StaffAdminService _service = StaffAdminService();

  final _assistantNameController = TextEditingController();
  final _assistantEmailController = TextEditingController();
  final _assistantPasswordController = TextEditingController();
  final _assistantPhoneController = TextEditingController();

  bool _savingAssistant = false;
  bool _loadingLists = true;
  bool _updatingTeam = false;
  List<AssistantSummaryData> _teamAssistants = const [];
  List<AssistantActivityData> _activityLog = const [];
  AssistantActivitySummaryData _activitySummary = const AssistantActivitySummaryData();
  int? _selectedAssistantFilterUserId;
  String _selectedActivityType = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadAssistants();
  }

  @override
  void dispose() {
    _assistantNameController.dispose();
    _assistantEmailController.dispose();
    _assistantPasswordController.dispose();
    _assistantPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAssistants() async {
    setState(() => _loadingLists = true);
    try {
      final results = await Future.wait([
        _service.loadAssistants(doctorId: widget.doctorId),
        _service.loadAssistantActivitySummary(
          doctorId: widget.doctorId,
          assistantUserId: _selectedAssistantFilterUserId,
        ),
        _service.loadAssistantActivity(
          doctorId: widget.doctorId,
          assistantUserId: _selectedAssistantFilterUserId,
          activityType: _selectedActivityType == 'ALL' ? null : _selectedActivityType,
        ),
      ]);
      if (!mounted) return;
      final teamAssistants = results[0] as List<AssistantSummaryData>;
      final activitySummary = results[1] as AssistantActivitySummaryData;
      final activityLog = results[2] as List<AssistantActivityData>;
      setState(() {
        _teamAssistants = teamAssistants;
        _activitySummary = activitySummary;
        _activityLog = activityLog;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loadingLists = false);
    }
  }

  Future<void> _createAssistant() async {
    if (_assistantNameController.text.trim().isEmpty || _assistantEmailController.text.trim().isEmpty || _assistantPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa nombre, correo y contrasena del asistente.')));
      return;
    }
    setState(() => _savingAssistant = true);
    try {
      await _service.createAssistantAccess(
        doctorId: widget.doctorId,
        fullName: _assistantNameController.text.trim().toUpperCase(),
        email: _assistantEmailController.text.trim(),
        password: _assistantPasswordController.text.trim(),
        phone: _assistantPhoneController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acceso de asistente creado correctamente.')));
      _assistantNameController.clear();
      _assistantEmailController.clear();
      _assistantPasswordController.clear();
      _assistantPhoneController.clear();
      await _loadAssistants();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _savingAssistant = false);
    }
  }

  Future<void> _unassignAssistant(AssistantSummaryData assistant) async {
    setState(() => _updatingTeam = true);
    try {
      await _service.unassignAssistant(
        doctorId: widget.doctorId,
        assistantUserId: assistant.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${assistant.fullName} se desasigno de tu equipo.')),
      );
      await _loadAssistants();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _updatingTeam = false);
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool obscure = false, TextInputType keyboardType = TextInputType.text, List<TextInputFormatter>? inputFormatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  String _formatActivityDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
  }

  Future<void> _applyActivityFilters({
    int? assistantUserId,
    String? activityType,
  }) async {
    setState(() {
      _selectedAssistantFilterUserId = assistantUserId;
      _selectedActivityType = activityType ?? _selectedActivityType;
    });
    await _loadAssistants();
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String helper,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(helper, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipo del medico')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(colors: [Color(0xFF0A6774), Color(0xFF2D59C4)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gestion de equipo', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Desde aqui el medico crea y administra solo a los asistentes de su propio equipo.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Crear acceso de asistente', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _buildTextField(_assistantNameController, 'Nombre completo'),
                  _buildTextField(_assistantEmailController, 'Correo', keyboardType: TextInputType.emailAddress),
                  _buildTextField(_assistantPasswordController, 'Contrasena inicial', obscure: true),
                  _buildTextField(_assistantPhoneController, 'Telefono', keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                  FilledButton.icon(
                    onPressed: _savingAssistant ? null : _createAssistant,
                    icon: _savingAssistant ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.support_agent_rounded),
                    label: Text(_savingAssistant ? 'Guardando...' : 'Crear acceso de asistente'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mi equipo actual', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  if (_loadingLists)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  else if (_teamAssistants.isEmpty)
                    const Text('Todavia no tienes asistentes asignados.')
                  else
                    ..._teamAssistants.map(
                      (assistant) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.support_agent_rounded)),
                        title: Text(assistant.fullName),
                        subtitle: Text(assistant.email),
                        trailing: OutlinedButton(
                          onPressed: _updatingTeam ? null : () => _unassignAssistant(assistant),
                          child: const Text('Desasignar'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Actividad del equipo', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  const Text('Aqui puedes ver que asistentes han dado de alta pacientes, gestionado citas y enviado mensajes.'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSummaryCard(
                        context: context,
                        title: 'Altas',
                        value: '${_activitySummary.patientsCreated}',
                        icon: Icons.person_add_alt_1_rounded,
                        color: const Color(0xFF1976D2),
                        helper: 'Pacientes registrados',
                      ),
                      _buildSummaryCard(
                        context: context,
                        title: 'Citas',
                        value: '${_activitySummary.appointmentsCreated}',
                        icon: Icons.event_available_rounded,
                        color: const Color(0xFF2E7D32),
                        helper: 'Citas gestionadas',
                      ),
                      _buildSummaryCard(
                        context: context,
                        title: 'Mensajes',
                        value: '${_activitySummary.messagesSent}',
                        icon: Icons.mark_chat_unread_rounded,
                        color: const Color(0xFF00838F),
                        helper: '${_activitySummary.patientMessagesSent} a pacientes y ${_activitySummary.doctorMessagesSent} a medicos',
                      ),
                      _buildSummaryCard(
                        context: context,
                        title: 'Horarios',
                        value: '${_activitySummary.schedulesUpdated}',
                        icon: Icons.schedule_rounded,
                        color: const Color(0xFF6A1B9A),
                        helper: '${_activitySummary.totalEvents} movimientos registrados',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedAssistantFilterUserId,
                    decoration: const InputDecoration(labelText: 'Filtrar por asistente'),
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(value: null, child: Text('Todos los asistentes')),
                      ..._teamAssistants.map(
                        (assistant) => DropdownMenuItem<int?>(
                          value: assistant.id,
                          child: Text(assistant.fullName),
                        ),
                      ),
                    ],
                    onChanged: _loadingLists
                        ? null
                        : (value) => _applyActivityFilters(
                              assistantUserId: value,
                              activityType: _selectedActivityType,
                            ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _activityTypeLabels.entries.map((entry) {
                      final selected = _selectedActivityType == entry.key;
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: selected,
                        onSelected: _loadingLists
                            ? null
                            : (_) => _applyActivityFilters(
                                  assistantUserId: _selectedAssistantFilterUserId,
                                  activityType: entry.key,
                                ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingLists)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  else if (_activityLog.isEmpty)
                    const Text('Todavia no hay actividad registrada en tu equipo.')
                  else
                    ..._activityLog.map(
                      (activity) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.history_rounded)),
                        title: Text(activity.activityTitle),
                        subtitle: Text(
                          '${activity.assistantName}\n${activity.activityDetails.isEmpty ? activity.activityType : activity.activityDetails}\n${_formatActivityDate(activity.createdAt)}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
