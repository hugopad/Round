import 'package:flutter/material.dart';

import 'doctor_registration_screen.dart';
import 'password_reset_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.onLogin,
  });

  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function(String email, String password) onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openDoctorRegistration() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DoctorRegistrationScreen()),
    );
  }

  Future<void> _openPasswordReset() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PasswordResetScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F7FB), Color(0xFFE8F0FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 72,
                          width: 72,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF0A6774), Color(0xFF2D59C4)],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'R',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'ROUNDGEN',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Acceso centralizado para admin, medico, asistente y paciente.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contrasena',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword ? 'Mostrar contrasena' : 'Ocultar contrasena',
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: const Color(0xFF0A6774),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: widget.isLoading ? null : _openPasswordReset,
                            child: const Text('Olvide mi contrasena'),
                          ),
                        ),
                        if (widget.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            widget.errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFB42318),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: widget.isLoading
                              ? null
                              : () => widget.onLogin(
                                    _emailController.text,
                                    _passwordController.text,
                                  ),
                          child: widget.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Entrar'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: widget.isLoading ? null : _openDoctorRegistration,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Registrar medico'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
