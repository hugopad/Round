import 'package:flutter/material.dart';

import '../models/doctor_access_email_config.dart';
import '../services/doctor_email_config_service.dart';

class DoctorEmailConfigScreen extends StatefulWidget {
  const DoctorEmailConfigScreen({
    super.key,
    required this.doctorId,
  });

  final int doctorId;

  @override
  State<DoctorEmailConfigScreen> createState() => _DoctorEmailConfigScreenState();
}

class _DoctorEmailConfigScreenState extends State<DoctorEmailConfigScreen> {
  final DoctorEmailConfigService _service = DoctorEmailConfigService();
  final TextEditingController _senderNameController = TextEditingController();
  final TextEditingController _senderEmailController = TextEditingController();
  final TextEditingController _replyToEmailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _apkUrlController = TextEditingController();
  final TextEditingController _smtpHostController = TextEditingController();
  final TextEditingController _smtpPortController = TextEditingController();
  final TextEditingController _smtpUsernameController = TextEditingController();
  final TextEditingController _smtpPasswordController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _attachApk = true;
  bool _isActive = true;
  bool _obscurePassword = true;
  String _smtpEncryption = 'tls';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _senderNameController.dispose();
    _senderEmailController.dispose();
    _replyToEmailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    _apkUrlController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUsernameController.dispose();
    _smtpPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final config = await _service.load(widget.doctorId);
      _senderNameController.text = config.senderName;
      _senderEmailController.text = config.senderEmail;
      _replyToEmailController.text = config.replyToEmail;
      _subjectController.text = config.accessSubject;
      _messageController.text = config.accessMessage;
      _apkUrlController.text = config.apkUrl;
      _smtpHostController.text = config.smtpHost;
      _smtpPortController.text = '${config.smtpPort}';
      _smtpUsernameController.text = config.smtpUsername;
      _smtpPasswordController.text = config.smtpPassword;
      _smtpEncryption = config.smtpEncryption.isEmpty ? 'tls' : config.smtpEncryption;
      _attachApk = config.attachApk;
      _isActive = config.isActive;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final senderName = _senderNameController.text.trim();
    final senderEmail = _senderEmailController.text.trim();
    final replyToEmail = _replyToEmailController.text.trim();
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    final apkUrl = _apkUrlController.text.trim();
    final smtpHost = _smtpHostController.text.trim();
    final smtpPort = int.tryParse(_smtpPortController.text.trim()) ?? 0;
    final smtpUsername = _smtpUsernameController.text.trim();
    final smtpPassword = _smtpPasswordController.text;

    if (senderName.isEmpty || senderEmail.isEmpty || subject.isEmpty || message.isEmpty || apkUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa remitente, correo, asunto, mensaje y liga del APK.')),
      );
      return;
    }

    if (smtpHost.isEmpty || smtpPort <= 0 || smtpUsername.isEmpty || smtpPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa host, puerto, usuario y contrasena SMTP.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.save(
        DoctorAccessEmailConfig(
          doctorId: widget.doctorId,
          senderName: senderName,
          senderEmail: senderEmail,
          replyToEmail: replyToEmail,
          accessSubject: subject,
          accessMessage: message,
          apkUrl: apkUrl,
          attachApk: _attachApk,
          isActive: _isActive,
          smtpHost: smtpHost,
          smtpPort: smtpPort,
          smtpUsername: smtpUsername,
          smtpPassword: smtpPassword,
          smtpEncryption: _smtpEncryption,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuracion SMTP guardada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
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
                        'Configuracion SMTP',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Configura el servidor SMTP del medico y el contenido del correo de acceso del paciente.',
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
                Text('Servidor SMTP', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: _smtpHostController,
                  decoration: const InputDecoration(labelText: 'Host SMTP'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _smtpPortController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Puerto SMTP'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _smtpUsernameController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Usuario SMTP'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _smtpPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contrasena SMTP',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _smtpEncryption,
                  decoration: const InputDecoration(labelText: 'Cifrado SMTP'),
                  items: const [
                    DropdownMenuItem(value: 'tls', child: Text('TLS / STARTTLS')),
                    DropdownMenuItem(value: 'ssl', child: Text('SSL')),
                    DropdownMenuItem(value: 'none', child: Text('Sin cifrado')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _smtpEncryption = value);
                  },
                ),
                const SizedBox(height: 20),
                Text('Correo de acceso', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: _senderNameController,
                  decoration: const InputDecoration(labelText: 'Nombre del remitente'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _senderEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo remitente visible'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _replyToEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo reply-to'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(labelText: 'Asunto del acceso'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _messageController,
                  minLines: 4,
                  maxLines: 7,
                  decoration: const InputDecoration(labelText: 'Mensaje base del correo'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _apkUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Liga publica del APK'),
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  value: _attachApk,
                  onChanged: (value) => setState(() => _attachApk = value),
                  title: const Text('Intentar adjuntar APK'),
                  subtitle: const Text('Si el archivo existe en el servidor, se adjuntara; si no, se enviara la liga.'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile.adaptive(
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text('Usar esta configuracion SMTP'),
                  subtitle: const Text('Si se desactiva, se usara la configuracion general de ROUNDGEN.'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Guardando...' : 'Guardar configuracion SMTP'),
                ),
              ],
            ),
    );
  }
}
