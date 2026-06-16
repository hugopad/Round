import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.instance.initializeFcm();
  } catch (_) {}
  runApp(const RoundgenApp());
}
