import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment_data.dart';
import '../models/auth_user.dart';
import '../services/agenda_service.dart';
import 'assistant_patient_intake_page.dart';
import 'doctor_schedule_settings_screen.dart';

class AssistantOperationsScreen extends StatefulWidget {
  const AssistantOperationsScreen({
    super.key,
    required this.currentUser,
  });

  final AuthUser currentUser;

  @override
  State<AssistantOperationsScreen> createState() => _AssistantOperationsScreenState();
}

class _AssistantOperationsScreenState extends State<AssistantOperationsScreen> {
  final AgendaService _agendaService = AgendaService();

  bool _loading = true;
  String? _errorMessage;
  List<AppointmentData> _appointments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final appointments = await _agendaService.loadAppointments();
      appointments.sort((left, right) => _parseStart(left).compareTo(_parseStart(right)));
      if (!mounted) return;
      setState(() => _appointments = appointments);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _appointments = const [];
        _errorMessage = _friendlyErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').toLowerCase();
    if (raw.contains('clientfailed to fetch') ||
        raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('respuesta vacia del servidor')) {
      return 'No hay conexion disponible con el servidor en este momento. Verifica internet o la API e intenta de nuevo.';
    }
    return 'No pudimos consultar las citas en este momento. Intenta nuevamente en unos minutos.';
  }

  Future<void> _refresh() => _load();

  DateTime _parseStart(AppointmentData appointment) {
    return DateTime.tryParse('${appointment.appointmentDate}T${appointment.startTime}') ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asistencia')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
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
                  Text(
                    'Centro de asistencia',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Alta de pacientes, configuracion de horarios medicos y seguimiento de citas.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ActionCard(
              title: 'Dar de alta paciente',
              subtitle: 'Captura datos administrativos, fiscales y acceso inicial.',
              icon: Icons.person_add_alt_1_rounded,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AssistantPatientIntakeScreen(currentUser: widget.currentUser)),
                );
                if (!mounted) return;
                await _refresh();
              },
            ),
            const SizedBox(height: 12),
            _ActionCard(
              title: 'Configurar horarios medicos',
              subtitle: 'Define sala, dia, horario y duracion de consulta por medico.',
              icon: Icons.schedule_send_rounded,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DoctorScheduleSettingsScreen(currentUser: widget.currentUser)),
                );
                if (!mounted) return;
                await _refresh();
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Citas proximas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No se pudieron cargar las citas por ahora.', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(_errorMessage!),
                    ],
                  ),
                ),
              )
            else if (_loading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_appointments.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No hay citas registradas por ahora.'),
                ),
              )
            else
              ..._appointments.take(20).map(
                (appointment) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(appointment.patientName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${appointment.doctorName} | ${appointment.roomName}'),
                          Text('${DateFormat('dd/MM/yyyy HH:mm').format(_parseStart(appointment))} | ${appointment.status}'),
                          Text(appointment.reason.isEmpty ? 'Sin motivo especificado' : appointment.reason),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: const Color(0xFF2D59C4)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
