import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/auth_user.dart';
import '../models/doctor_subscription_entry_data.dart';
import '../models/doctor_subscription_status_data.dart';
import '../models/subscription_code_data.dart';
import '../services/subscription_service.dart';

class DoctorSubscriptionScreen extends StatefulWidget {
  const DoctorSubscriptionScreen({
    super.key,
    required this.currentUser,
    this.lockedMode = false,
    this.onSubscriptionActivated,
    this.onLogout,
  });

  final AuthUser currentUser;
  final bool lockedMode;
  final ValueChanged<DoctorSubscriptionStatusData>? onSubscriptionActivated;
  final VoidCallback? onLogout;

  @override
  State<DoctorSubscriptionScreen> createState() => _DoctorSubscriptionScreenState();
}

class _DoctorSubscriptionScreenState extends State<DoctorSubscriptionScreen> {
  final SubscriptionService _service = SubscriptionService();
  final TextEditingController _codeController = TextEditingController();

  bool _loading = true;
  bool _redeeming = false;
  bool _openingCheckout = false;
  String? _errorMessage;
  DoctorSubscriptionStatusData? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final doctorId = widget.currentUser.doctorId;
    if (doctorId == null || doctorId <= 0) {
      setState(() {
        _loading = false;
        _errorMessage = 'No se encontro el medico asociado a esta sesion.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final status = await _service.loadDoctorSubscriptionStatus(doctorId: doctorId);
      if (!mounted) return;
      setState(() => _status = status);
      if (status.subscriptionActive) {
        widget.onSubscriptionActivated?.call(status);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeem() async {
    final code = _codeController.text.trim();
    final doctorId = widget.currentUser.doctorId;
    if (doctorId == null || doctorId <= 0) return;
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Captura un codigo de suscripcion.')));
      return;
    }

    setState(() => _redeeming = true);
    try {
      final status = await _service.redeemSubscriptionCode(doctorId: doctorId, code: code);
      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _status = status;
        _errorMessage = null;
      });
      widget.onSubscriptionActivated?.call(status);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suscripcion activada correctamente.')));
      await _loadStatus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  Future<void> _startCheckout(String planKey) async {
    final doctorId = widget.currentUser.doctorId;
    if (doctorId == null || doctorId <= 0) return;
    setState(() => _openingCheckout = true);
    try {
      final checkoutUrl = await _service.createSubscriptionCheckout(
        doctorId: doctorId,
        planKey: planKey,
      );
      if (checkoutUrl.isEmpty) {
        throw Exception('No se pudo obtener la liga de pago');
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liga de pago generada',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Abre esta liga en tu navegador para completar el pago en Mercado Pago. Cuando el pago quede aprobado, vuelve a esta pantalla y presiona Reintentar para ver tu codigo.',
                ),
                const SizedBox(height: 16),
                SelectableText(
                  checkoutUrl,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: checkoutUrl));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Liga copiada al portapapeles.')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar liga'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Share.share(checkoutUrl, subject: 'Pago de suscripcion ROUNDGEN'),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Compartir'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _openingCheckout = false);
    }
  }

  Color _statusColor(bool active) => active ? const Color(0xFF2E7D32) : const Color(0xFFB42318);

  String _sourceLabel(String raw) {
    switch (raw.toUpperCase()) {
      case 'TRIAL':
        return 'Prueba';
      case 'CODE':
        return 'Codigo';
      default:
        return raw;
    }
  }

  Widget _buildHistoryItem(DoctorSubscriptionEntryData item) {
    final active = item.status.toUpperCase() == 'ACTIVE';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: _statusColor(active).withValues(alpha: 0.12),
        foregroundColor: _statusColor(active),
        child: Icon(active ? Icons.verified_rounded : Icons.history_toggle_off_rounded),
      ),
      title: Text(item.planName, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${item.startDate} al ${item.endDate}\n${_sourceLabel(item.sourceType)} | ${item.status}${item.notes.isEmpty ? '' : '\n${item.notes}'}'),
      isThreeLine: true,
    );
  }

  Widget _buildGeneratedCodeItem(SubscriptionCodeData code) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.qr_code_rounded)),
      title: Text(code.code, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${code.planName} | ${code.durationDays} dias'),
      trailing: OutlinedButton(
        onPressed: () {
          _codeController.text = code.code;
        },
        child: const Text('Usar'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.lockedMode,
        title: const Text('Suscripcion'),
        actions: [
          if (widget.lockedMode && widget.onLogout != null)
            TextButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Salir'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                colors: status?.subscriptionActive == true
                    ? const [Color(0xFF0A6774), Color(0xFF2D59C4)]
                    : const [Color(0xFF9A3412), Color(0xFFB42318)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lockedMode ? 'Tu acceso necesita suscripcion activa' : 'Estado de suscripcion',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  status == null
                      ? 'Cargando vigencia del medico.'
                      : status.subscriptionActive
                          ? 'Plan actual: ${status.subscriptionPlanName ?? 'Sin nombre'} | Vigencia hasta ${status.subscriptionEndDate ?? '-'}'
                          : 'Tu suscripcion vencio o aun no esta activa. Captura un codigo para reactivar el acceso.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
              ],
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
                    const Text('No se pudo cargar la suscripcion', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(_errorMessage!),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _loadStatus, child: const Text('Reintentar')),
                  ],
                ),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resumen actual', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Text('Estatus: ${status!.subscriptionActive ? 'Activa' : 'Vencida'}'),
                    Text('Plan: ${status.subscriptionPlanName ?? 'Sin plan'}'),
                    Text('Origen: ${status.subscriptionSourceType == null ? '-' : _sourceLabel(status.subscriptionSourceType!)}'),
                    Text('Inicio: ${status.subscriptionStartDate ?? '-'}'),
                    Text('Fin: ${status.subscriptionEndDate ?? '-'}'),
                    Text('Dias restantes: ${status.subscriptionDaysRemaining}'),
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
                    Text('Pagar suscripcion', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _openingCheckout ? null : () => _startCheckout('MONTHLY_30'),
                          icon: const Icon(Icons.payments_rounded),
                          label: Text(_openingCheckout ? 'Abriendo...' : '30 dias | \$99'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openingCheckout ? null : () => _startCheckout('YEARLY_365'),
                          icon: const Icon(Icons.workspace_premium_rounded),
                          label: const Text('365 dias | \$999'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Cuando Mercado Pago apruebe el pago, aqui mismo aparecera el codigo generado para activar la vigencia.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (status.generatedCodes.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Codigos generados por tus pagos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      ...status.generatedCodes.map(_buildGeneratedCodeItem),
                    ],
                  ),
                ),
              ),
            if (status.generatedCodes.isNotEmpty) const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ingresar codigo de suscripcion', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Codigo',
                        hintText: 'RG-ABCD-EFGH-IJKL',
                        prefixIcon: Icon(Icons.confirmation_number_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _redeeming ? null : _redeem,
                      icon: _redeeming
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.verified_rounded),
                      label: Text(_redeeming ? 'Activando...' : 'Activar suscripcion'),
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
                    Text('Historico de suscripciones', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    if (status.history.isEmpty)
                      const Text('Todavia no hay historial disponible.')
                    else
                      ...status.history.map(_buildHistoryItem),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
