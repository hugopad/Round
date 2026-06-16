import 'package:flutter/material.dart';

class DashboardModule {
  const DashboardModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badgeCount = 0,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int badgeCount;

  DashboardModule copyWith({
    String? title,
    String? subtitle,
    IconData? icon,
    int? badgeCount,
  }) {
    return DashboardModule(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
      badgeCount: badgeCount ?? this.badgeCount,
    );
  }
}
