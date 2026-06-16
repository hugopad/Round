import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../models/patient_summary.dart';
import '../models/role_type.dart';
import '../services/patient_service.dart';
import 'assistant_patient_intake_page.dart';
import 'patient_detail_screen.dart';

class PatientsModuleScreen extends StatefulWidget {
  const PatientsModuleScreen({
    super.key,
    required this.currentUser,
  });

  final AuthUser currentUser;

  @override
  State<PatientsModuleScreen> createState() => _PatientsModuleScreenState();
}

class _PatientsModuleScreenState extends State<PatientsModuleScreen> {
  late Future<List<PatientSummary>> _future;
  final PatientService _service = PatientService();
  bool _deactivating = false;

  bool get _isAssistant => widget.currentUser.role == RoleType.assistant;
  bool get _canCreatePatient => widget.currentUser.role == RoleType.assistant || widget.currentUser.role == RoleType.doctor;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PatientSummary>> _load() {
    final doctorId = widget.currentUser.role == RoleType.doctor ? widget.currentUser.doctorId : null;
    return _service.loadPatients(doctorId: doctorId);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _openAssistantCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AssistantPatientIntakeScreen(currentUser: widget.currentUser)),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _deactivatePatient(PatientSummary patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dar de baja paciente'),
        content: Text('Se dara de baja a ${patient.fullName} y, si tiene acceso, ya no podra iniciar sesion. Esta accion oculta al paciente de los listados activos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.person_off_rounded),
            label: const Text('Confirmar baja'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deactivating = true);
    try {
      await _service.deactivatePatient(patientId: patient.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${patient.fullName} fue dado de baja.')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _deactivating = false);
      }
    }
  }

  String get _title {
    switch (widget.currentUser.role) {
      case RoleType.admin:
        return 'Pacientes';
      case RoleType.doctor:
        return 'Mis pacientes';
      case RoleType.assistant:
        return 'Pacientes';
      case RoleType.patient:
        return 'Mi ficha';
    }
  }

  String get _subtitle {
    switch (widget.currentUser.role) {
      case RoleType.admin:
        return 'Consulta el listado general de pacientes registrados.';
      case RoleType.doctor:
        return 'Consulta expedientes y recetas por paciente.';
      case RoleType.assistant:
        return 'Consulta datos generales y recetas, registra pacientes nuevos y gestiona bajas administrativas.';
      case RoleType.patient:
        return 'Consulta tu informacion, expediente y recetas.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      floatingActionButton: _canCreatePatient
          ? FloatingActionButton.extended(
              onPressed: _openAssistantCreate,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Nuevo paciente'),
            )
          : null,
      body: Stack(
        children: [
          FutureBuilder<List<PatientSummary>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _StateMessage(
                  title: 'No se pudieron cargar los pacientes',
                  subtitle: '${snapshot.error}'.replaceFirst('Exception: ', ''),
                  actionLabel: 'Reintentar',
                  onPressed: _refresh,
                );
              }

              final patients = snapshot.data ?? const <PatientSummary>[];
              final visiblePatients = widget.currentUser.role == RoleType.patient
                  ? patients.where((patient) => patient.id == widget.currentUser.patientId).toList()
                  : patients;

              if (visiblePatients.isEmpty) {
                return _StateMessage(
                  title: _title,
                  subtitle: _subtitle,
                  actionLabel: 'Actualizar',
                  onPressed: _refresh,
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: visiblePatients.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _HeroCard(title: _title, subtitle: _subtitle);
                    }
                    final patient = visiblePatients[index - 1];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(18),
                        title: Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Expediente: ${patient.medicalRecordNumber}'),
                              Text('Telefono: ${patient.phone}'),
                              Text('Correo: ${patient.email.isEmpty ? 'Sin correo' : patient.email}'),
                              if (!_isAssistant)
                                Text('Tipo de sangre: ${patient.bloodType.isEmpty ? 'Sin dato' : patient.bloodType}'),
                            ],
                          ),
                        ),
                        trailing: _isAssistant
                            ? PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'open') {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PatientDetailScreen(
                                          currentUser: widget.currentUser,
                                          patient: patient,
                                        ),
                                      ),
                                    );
                                  }
                                  if (value == 'deactivate') {
                                    _deactivatePatient(patient);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem<String>(
                                    value: 'open',
                                    child: ListTile(
                                      leading: Icon(Icons.visibility_rounded),
                                      title: Text('Ver paciente'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'deactivate',
                                    child: ListTile(
                                      leading: Icon(Icons.person_off_rounded),
                                      title: Text('Dar de baja'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PatientDetailScreen(
                                currentUser: widget.currentUser,
                                patient: patient,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
          if (_deactivating)
            ColoredBox(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A6774), Color(0xFF2D59C4)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onPressed,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
