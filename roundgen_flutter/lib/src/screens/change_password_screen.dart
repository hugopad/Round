import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
  });

  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function(String currentPassword, String newPassword) onSubmit;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
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
                      Text(
                        'Actualiza tu contrasena',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Por seguridad debes definir una nueva contrasena antes de continuar en ROUNDGEN.',
                        style: theme.textTheme.bodyLarge?.copyWith(color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _currentPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Contrasena actual'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Nueva contrasena'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Confirmar nueva contrasena'),
                      ),
                      if (widget.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          widget.errorMessage!,
                          style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: widget.isLoading
                            ? null
                            : () {
                                if (_newPasswordController.text.trim().length < 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('La nueva contrasena debe tener al menos 6 caracteres.')),
                                  );
                                  return;
                                }
                                if (_newPasswordController.text != _confirmPasswordController.text) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('La confirmacion de contrasena no coincide.')),
                                  );
                                  return;
                                }
                                widget.onSubmit(
                                  _currentPasswordController.text,
                                  _newPasswordController.text,
                                );
                              },
                        child: widget.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Guardar nueva contrasena'),
                      ),
                    ],
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
