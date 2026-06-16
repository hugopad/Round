import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import 'admin_subscription_management_screen.dart';
import 'doctor_professional_requests_screen.dart';

class AdminOperationsScreen extends StatelessWidget {
  const AdminOperationsScreen({
    super.key,
    required this.currentUser,
  });

  final AuthUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(
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
                  'Centro administrativo',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aqui se revisan y aprueban los registros profesionales medicos pendientes.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DoctorProfessionalRequestsScreen(currentUser: currentUser)),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0xFFE8F0FF),
                      child: Icon(Icons.fact_check_rounded, color: Color(0xFF2D59C4)),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aprobar medicos',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 6),
                          Text('Revisa solicitudes, aprueba o rechaza registros profesionales.'),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AdminSubscriptionManagementScreen(currentUser: currentUser)),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0xFFE8F0FF),
                      child: Icon(Icons.workspace_premium_rounded, color: Color(0xFF2D59C4)),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Suscripciones',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 6),
                          Text('Controla pruebas, vigencias historicas y codigos de renovacion para medicos.'),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
