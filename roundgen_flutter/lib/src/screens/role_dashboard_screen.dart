import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../models/dashboard_module.dart';

class RoleDashboardScreen extends StatelessWidget {
  const RoleDashboardScreen({
    super.key,
    required this.currentUser,
    required this.modules,
    required this.onModuleTap,
  });

  final AuthUser currentUser;
  final List<DashboardModule> modules;
  final ValueChanged<DashboardModule> onModuleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xFF0A6774), Color(0xFF2D59C4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x332D59C4),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Text(
            currentUser.fullName,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Modulos activos',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        ...modules.map(
          (module) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => onModuleTap(module),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(module.icon, color: const Color(0xFF2D59C4)),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(module.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (module.badgeCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D59C4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${module.badgeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(module.subtitle),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
