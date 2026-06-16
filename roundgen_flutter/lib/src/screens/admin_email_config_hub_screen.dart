import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../models/doctor_summary_data.dart';
import '../services/agenda_service.dart';
import 'doctor_email_config_screen.dart';

class AdminEmailConfigHubScreen extends StatefulWidget {
  const AdminEmailConfigHubScreen({
    super.key,
    required this.currentUser,
  });

  final AuthUser currentUser;

  @override
  State<AdminEmailConfigHubScreen> createState() => _AdminEmailConfigHubScreenState();
}

class _AdminEmailConfigHubScreenState extends State<AdminEmailConfigHubScreen> {
  final AgendaService _agendaService = AgendaService();
  bool _loading = true;
  String? _errorMessage;
  List<DoctorSummaryData> _doctors = const [];

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
      final doctors = await _agendaService.loadDoctors();
      if (!mounted) return;
      setState(() => _doctors = doctors);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SMTP de accesos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                        'Configuracion de correos por medico',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Como admin puedes abrir la configuracion SMTP del medico que corresponda.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Text(_errorMessage!, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                ],
                if (_doctors.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No hay medicos disponibles por ahora.'),
                    ),
                  )
                else
                  ..._doctors.map(
                    (doctor) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(doctor.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(doctor.specialty),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DoctorEmailConfigScreen(doctorId: doctor.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
