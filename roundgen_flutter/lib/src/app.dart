import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/app_config.dart';
import 'models/auth_user.dart';
import 'models/doctor_subscription_status_data.dart';
import 'models/role_type.dart';
import 'screens/change_password_screen.dart';
import 'screens/doctor_subscription_screen.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/session_service.dart';
import 'theme/roundgen_theme.dart';

class RoundgenApp extends StatefulWidget {
  const RoundgenApp({super.key});

  @override
  State<RoundgenApp> createState() => _RoundgenAppState();
}

class _RoundgenAppState extends State<RoundgenApp> {
  final AuthService _authService = AuthService();
  final SessionService _sessionService = SessionService();
  final NotificationService _notificationService = NotificationService.instance;
  AuthUser? _currentUser;
  bool _isLoading = false;
  bool _isBootstrapping = true;
  String? _errorMessage;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      await _notificationService.initialize();
    } catch (_) {}
    await _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await _sessionService.loadUser();
    if (user != null) {
      await _startNotificationLoop(user);
    }
    if (!mounted) return;
    setState(() {
      _currentUser = user;
      _isBootstrapping = false;
    });
  }

  Future<void> _startNotificationLoop(AuthUser user) async {
    _notificationTimer?.cancel();
    try {
      await _notificationService.syncForUser(user);
    } catch (_) {}
    _notificationTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
      try {
        await _notificationService.syncForUser(user);
      } catch (_) {}
    });
  }

  Future<void> _login(String email, String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.login(email: email, password: password);
      await _sessionService.saveUser(user);
      await _startNotificationLoop(user);
      if (!mounted) return;
      setState(() => _currentUser = user);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString().replaceFirst('Exception: ', ''));
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _changePassword(String currentPassword, String newPassword) async {
    final user = _currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final updatedUser = await _authService.changePassword(
        user: user,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await _sessionService.saveUser(updatedUser);
      await _startNotificationLoop(updatedUser);
      if (!mounted) return;
      setState(() => _currentUser = updatedUser);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString().replaceFirst('Exception: ', ''));
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    _notificationTimer?.cancel();
    await _sessionService.clear();
    if (!mounted) return;
    setState(() {
      _currentUser = null;
      _errorMessage = null;
    });
  }

  Future<void> _handleSubscriptionActivated(AuthUser user, DoctorSubscriptionStatusData status) async {
    final updatedUser = user.copyWith(
      subscriptionActive: status.subscriptionActive,
      subscriptionStatus: status.subscriptionStatus,
      subscriptionPlanName: status.subscriptionPlanName,
      subscriptionStartDate: status.subscriptionStartDate,
      subscriptionEndDate: status.subscriptionEndDate,
      subscriptionDaysRemaining: status.subscriptionDaysRemaining,
    );
    await _sessionService.saveUser(updatedUser);
    if (!mounted) return;
    setState(() => _currentUser = updatedUser);
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (_isBootstrapping) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (_currentUser == null) {
      home = LoginScreen(isLoading: _isLoading, errorMessage: _errorMessage, onLogin: _login);
    } else if (_currentUser!.mustChangePassword) {
      home = ChangePasswordScreen(isLoading: _isLoading, errorMessage: _errorMessage, onSubmit: _changePassword);
    } else if (_currentUser!.role.code == 'DOCTOR' && !_currentUser!.subscriptionActive) {
      home = DoctorSubscriptionScreen(
        currentUser: _currentUser!,
        lockedMode: true,
        onLogout: _logout,
        onSubscriptionActivated: (status) => _handleSubscriptionActivated(_currentUser!, status),
      );
    } else {
      home = HomeShell(currentUser: _currentUser!, onLogout: _logout);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: RoundgenTheme.light(),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }
}
