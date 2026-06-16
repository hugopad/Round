import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../models/doctor_subscription_report_data.dart';
import '../models/mercado_pago_config_data.dart';
import '../models/subscription_code_data.dart';
import '../services/subscription_service.dart';

class AdminSubscriptionManagementScreen extends StatefulWidget {
  const AdminSubscriptionManagementScreen({
    super.key,
    required this.currentUser,
  });

  final AuthUser currentUser;

  @override
  State<AdminSubscriptionManagementScreen> createState() => _AdminSubscriptionManagementScreenState();
}

class _AdminSubscriptionManagementScreenState extends State<AdminSubscriptionManagementScreen> {
  final SubscriptionService _service = SubscriptionService();
  final TextEditingController _planNameController = TextEditingController(text: 'Suscripcion mensual');
  final TextEditingController _durationDaysController = TextEditingController(text: '30');
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _publicKeyController = TextEditingController();
  final TextEditingController _accessTokenController = TextEditingController();
  final TextEditingController _webhookSecretController = TextEditingController();
  final TextEditingController _appBaseUrlController = TextEditingController();
  final TextEditingController _successUrlController = TextEditingController();
  final TextEditingController _failureUrlController = TextEditingController();
  final TextEditingController _pendingUrlController = TextEditingController();

  bool _loading = true;
  bool _generating = false;
  bool _savingConfig = false;
  bool _mercadoPagoActive = true;
  String? _errorMessage;
  List<DoctorSubscriptionReportData> _doctors = const [];
  List<SubscriptionCodeData> _codes = const [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _planNameController.dispose();
    _durationDaysController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    _publicKeyController.dispose();
    _accessTokenController.dispose();
    _webhookSecretController.dispose();
    _appBaseUrlController.dispose();
    _successUrlController.dispose();
    _failureUrlController.dispose();
    _pendingUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final report = await _service.loadAdminSubscriptionReport(adminUserId: widget.currentUser.id);
      final paymentConfig = await _service.loadMercadoPagoConfig(adminUserId: widget.currentUser.id);
      if (!mounted) return;
      setState(() {
        _doctors = report.$1;
        _codes = report.$2;
        _publicKeyController.text = paymentConfig.publicKey;
        _accessTokenController.text = paymentConfig.accessToken;
        _webhookSecretController.text = paymentConfig.webhookSecret;
        _appBaseUrlController.text = paymentConfig.appBaseUrl;
        _successUrlController.text = paymentConfig.successUrl;
        _failureUrlController.text = paymentConfig.failureUrl;
        _pendingUrlController.text = paymentConfig.pendingUrl;
        _mercadoPagoActive = paymentConfig.isActive;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateCodes() async {
    final durationDays = int.tryParse(_durationDaysController.text.trim()) ?? 0;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (_planNameController.text.trim().isEmpty || durationDays <= 0 || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa plan, dias y cantidad validos.')));
      return;
    }
    setState(() => _generating = true);
    try {
      final codes = await _service.generateCodes(
        adminUserId: widget.currentUser.id,
        planName: _planNameController.text.trim(),
        durationDays: durationDays,
        quantity: quantity,
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      final message = codes.map((code) => code.code).join('\n');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Codigos generados:\n$message')));
      _quantityController.text = '1';
      await _loadReport();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _saveMercadoPagoConfig() async {
    if (_accessTokenController.text.trim().isEmpty || _appBaseUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Captura al menos Access Token y URL base publica.')));
      return;
    }
    setState(() => _savingConfig = true);
    try {
      await _service.saveMercadoPagoConfig(
        adminUserId: widget.currentUser.id,
        publicKey: _publicKeyController.text.trim(),
        accessToken: _accessTokenController.text.trim(),
        webhookSecret: _webhookSecretController.text.trim(),
        appBaseUrl: _appBaseUrlController.text.trim(),
        successUrl: _successUrlController.text.trim(),
        failureUrl: _failureUrlController.text.trim(),
        pendingUrl: _pendingUrlController.text.trim(),
        isActive: _mercadoPagoActive,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuracion de Mercado Pago guardada.')));
      await _loadReport();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _savingConfig = false);
    }
  }

  Widget _buildDoctorItem(DoctorSubscriptionReportData doctor) {
    final active = doctor.subscriptionActive;
    final color = active ? const Color(0xFF2E7D32) : const Color(0xFFB42318);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(doctor.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  active ? 'Activa' : 'Vencida',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(doctor.email),
          if (doctor.specialty.isNotEmpty) Text(doctor.specialty),
          const SizedBox(height: 8),
          Text('Plan: ${doctor.subscriptionPlanName ?? 'Sin plan'}'),
          Text('Vigencia: ${doctor.subscriptionStartDate ?? '-'} al ${doctor.subscriptionEndDate ?? '-'}'),
          Text('Dias restantes: ${doctor.subscriptionDaysRemaining}'),
          if (doctor.history.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Historico: ${doctor.history.length} registro(s)', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }

  Widget _buildCodeItem(SubscriptionCodeData code) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.qr_code_rounded)),
      title: Text(code.code, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${code.planName} | ${code.durationDays} dias\nUso ${code.redeemedCount}/${code.maxRedemptions} | ${code.status}'),
      isThreeLine: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suscripciones')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(colors: [Color(0xFF0A6774), Color(0xFF2D59C4)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Control de suscripciones',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aqui administras prueba inicial, vigencias historicas y codigos para reactivar medicos.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Generar codigos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(controller: _planNameController, decoration: const InputDecoration(labelText: 'Nombre del plan')),
                  const SizedBox(height: 12),
                  TextField(controller: _durationDaysController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duracion en dias')),
                  const SizedBox(height: 12),
                  TextField(controller: _quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad de codigos')),
                  const SizedBox(height: 12),
                  TextField(controller: _notesController, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas internas')),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _generating ? null : _generateCodes,
                    icon: _generating ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.confirmation_number_rounded),
                    label: Text(_generating ? 'Generando...' : 'Generar codigos'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mercado Pago', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(controller: _publicKeyController, decoration: const InputDecoration(labelText: 'Public Key')),
                  const SizedBox(height: 12),
                  TextField(controller: _accessTokenController, decoration: const InputDecoration(labelText: 'Access Token')),
                  const SizedBox(height: 12),
                  TextField(controller: _webhookSecretController, decoration: const InputDecoration(labelText: 'Webhook Secret')),
                  const SizedBox(height: 12),
                  TextField(controller: _appBaseUrlController, decoration: const InputDecoration(labelText: 'URL base publica, ej. https://tudominio.com')),
                  const SizedBox(height: 12),
                  TextField(controller: _successUrlController, decoration: const InputDecoration(labelText: 'URL success')),
                  const SizedBox(height: 12),
                  TextField(controller: _failureUrlController, decoration: const InputDecoration(labelText: 'URL failure')),
                  const SizedBox(height: 12),
                  TextField(controller: _pendingUrlController, decoration: const InputDecoration(labelText: 'URL pending')),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _mercadoPagoActive,
                    onChanged: (value) => setState(() => _mercadoPagoActive = value),
                    title: const Text('Activar cobros con Mercado Pago'),
                  ),
                  FilledButton.icon(
                    onPressed: _savingConfig ? null : _saveMercadoPagoConfig,
                    icon: _savingConfig ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.savings_rounded),
                    label: Text(_savingConfig ? 'Guardando...' : 'Guardar configuracion'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('No se pudo cargar el reporte', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(_errorMessage!),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _loadReport, child: const Text('Reintentar')),
                  ],
                ),
              ),
            )
          else ...[
            Text('Medicos y vigencias', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (_doctors.isEmpty)
              const Text('No hay medicos registrados por ahora.')
            else
              ..._doctors.map(_buildDoctorItem),
            const SizedBox(height: 18),
            Text('Codigos generados', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _codes.isEmpty
                    ? const Text('Todavia no hay codigos generados.')
                    : Column(children: _codes.map(_buildCodeItem).toList(growable: false)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
