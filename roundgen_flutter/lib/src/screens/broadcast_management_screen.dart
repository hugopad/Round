import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/auth_user.dart';
import '../services/content_service.dart';

class BroadcastManagementScreen extends StatefulWidget {
  const BroadcastManagementScreen({
    super.key,
    required this.currentUser,
  });

  final AuthUser currentUser;

  @override
  State<BroadcastManagementScreen> createState() => _BroadcastManagementScreenState();
}

class _BroadcastManagementScreenState extends State<BroadcastManagementScreen> {
  final ContentService _contentService = ContentService();
  bool _sendingNotice = false;
  bool _savingAd = false;

  Future<void> _openNoticeComposer() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final budgetNotesController = TextEditingController();
    var targetRole = 'PATIENT';
    var isPaid = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Nuevo aviso segmentado'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titulo'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: targetRole,
                    decoration: const InputDecoration(labelText: 'Audiencia'),
                    items: const [
                      DropdownMenuItem(value: 'PATIENT', child: Text('Solo pacientes')),
                      DropdownMenuItem(value: 'DOCTOR', child: Text('Solo medicos')),
                      DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                    ],
                    onChanged: (value) => setDialogState(() => targetRole = value ?? 'PATIENT'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    minLines: 4,
                    maxLines: 7,
                    decoration: const InputDecoration(labelText: 'Mensaje'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publicidad pagada'),
                    subtitle: const Text('Activa esta opcion si el aviso forma parte de una campaña pagada.'),
                    value: isPaid,
                    onChanged: (value) => setDialogState(() => isPaid = value),
                  ),
                  if (isPaid) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: budgetNotesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Notas de inversion / campaña'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _sendingNotice ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _sendingNotice
                    ? null
                    : () async {
                        if (titleController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Titulo y mensaje son obligatorios.')),
                          );
                          return;
                        }
                        setDialogState(() => _sendingNotice = true);
                        try {
                          await _contentService.createNotice(
                            createdByUserId: widget.currentUser.id,
                            title: titleController.text.trim(),
                            messageText: messageController.text.trim(),
                            targetRole: targetRole,
                            isPaid: isPaid,
                            budgetNotes: budgetNotesController.text.trim(),
                          );
                          if (!mounted) return;
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Aviso guardado con audiencia segmentada.')),
                          );
                        } catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                          );
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => _sendingNotice = false);
                          }
                        }
                      },
                child: Text(_sendingNotice ? 'Guardando...' : 'Guardar aviso'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAdComposer() async {
    final advertiserController = TextEditingController();
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final urlController = TextEditingController();
    final budgetNotesController = TextEditingController();
    final formatter = DateFormat('yyyy-MM-dd');
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 30));
    var targetRole = 'PATIENT';

    Future<void> pickDate({
      required bool isStart,
      required void Function(void Function()) setDialogState,
    }) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: isStart ? startDate : endDate,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 730)),
      );
      if (picked == null) return;
      setDialogState(() {
        if (isStart) {
          startDate = picked;
          if (endDate.isBefore(startDate)) {
            endDate = startDate;
          }
        } else {
          endDate = picked;
        }
      });
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Nueva publicidad pagada'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: advertiserController,
                    decoration: const InputDecoration(labelText: 'Anunciante'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titulo'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: targetRole,
                    decoration: const InputDecoration(labelText: 'Audiencia'),
                    items: const [
                      DropdownMenuItem(value: 'PATIENT', child: Text('Solo pacientes')),
                      DropdownMenuItem(value: 'DOCTOR', child: Text('Solo medicos')),
                      DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                    ],
                    onChanged: (value) => setDialogState(() => targetRole = value ?? 'PATIENT'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Mensaje del anuncio'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(labelText: 'URL destino (opcional)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickDate(isStart: true, setDialogState: setDialogState),
                          child: Text('Inicio ${formatter.format(startDate)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => pickDate(isStart: false, setDialogState: setDialogState),
                          child: Text('Fin ${formatter.format(endDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: budgetNotesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notas de campaña / presupuesto'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _savingAd ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _savingAd
                    ? null
                    : () async {
                        if (advertiserController.text.trim().isEmpty ||
                            titleController.text.trim().isEmpty ||
                            messageController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Anunciante, titulo y mensaje son obligatorios.')),
                          );
                          return;
                        }
                        setDialogState(() => _savingAd = true);
                        try {
                          await _contentService.createAd(
                            advertiserName: advertiserController.text.trim(),
                            title: titleController.text.trim(),
                            messageText: messageController.text.trim(),
                            targetRole: targetRole,
                            startDate: formatter.format(startDate),
                            endDate: formatter.format(endDate),
                            targetUrl: urlController.text.trim(),
                            budgetNotes: budgetNotesController.text.trim(),
                          );
                          if (!mounted) return;
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Publicidad guardada correctamente.')),
                          );
                        } catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                          );
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => _savingAd = false);
                          }
                        }
                      },
                child: Text(_savingAd ? 'Guardando...' : 'Guardar publicidad'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Difusion y publicidad')),
      body: ListView(
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
                  'Centro de difusion',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Segmenta avisos solo para medicos o solo para pacientes y prepara campañas pagadas.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ActionCard(
            title: 'Aviso segmentado',
            subtitle: 'Crea un aviso interno dirigido a medicos, pacientes o ambos.',
            icon: Icons.notifications_active_rounded,
            onTap: _openNoticeComposer,
          ),
          const SizedBox(height: 14),
          _ActionCard(
            title: 'Publicidad pagada',
            subtitle: 'Registra banners o campañas con audiencia definida y vigencia.',
            icon: Icons.campaign_rounded,
            onTap: _openAdComposer,
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFE8F0FF),
                child: Icon(icon, color: const Color(0xFF2D59C4)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
