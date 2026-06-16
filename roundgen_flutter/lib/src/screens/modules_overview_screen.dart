import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../models/dashboard_module.dart';

class ModulesOverviewScreen extends StatelessWidget {
  const ModulesOverviewScreen({
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
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.92,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => onModuleTap(module),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0A6774), Color(0xFF2D59C4)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(module.icon, color: Colors.white),
                      ),
                      const Spacer(),
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
                  const Spacer(),
                  Text(
                    module.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(module.subtitle),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
