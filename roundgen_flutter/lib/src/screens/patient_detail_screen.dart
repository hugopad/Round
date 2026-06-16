import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../models/medical_record_data.dart';
import '../models/patient_summary.dart';
import '../models/prescription_data.dart';
import '../models/role_type.dart';
import '../services/patient_service.dart';
import '../utils/prescription_pdf_exporter.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({
    super.key,
    required this.currentUser,
    required this.patient,
  });

  final AuthUser currentUser;
  final PatientSummary patient;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final PatientService _service = PatientService();
  final PrescriptionPdfExporter _pdfExporter = PrescriptionPdfExporter();
  late Future<_PatientDetailBundle> _future;
  int? _exportingId;

  bool get _isAssistant => widget.currentUser.role == RoleType.assistant;
  bool get _canEditRecord => widget.currentUser.role == RoleType.doctor && widget.currentUser.doctorId != null;
  bool get _canCreatePrescription => widget.currentUser.role == RoleType.doctor && widget.currentUser.doctorId != null;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PatientDetailBundle> _load() async {
    MedicalRecordData record = MedicalRecordData.empty(widget.patient.id);
    List<PrescriptionData> prescriptions = const [];

    if (!_isAssistant) {
      try {
        record = await _service.loadRecord(widget.patient.id);
      } catch (_) {
        record = MedicalRecordData.empty(widget.patient.id);
      }
    }

    try {
      prescriptions = await _service.loadPrescriptions(widget.patient.id);
    } catch (_) {
      prescriptions = const [];
    }

    return _PatientDetailBundle(record: record, prescriptions: prescriptions);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _downloadPdf(PrescriptionData prescription) async {
    setState(() => _exportingId = prescription.id);
    try {
      final file = await _pdfExporter.export(patient: widget.patient, prescription: prescription);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF guardado en ${file.path}')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo generar el PDF de la receta.')));
    } finally {
      if (mounted) {
        setState(() => _exportingId = null);
      }
    }
  }

  Future<void> _showRecordEditor(MedicalRecordData initialRecord) async {
    final allergiesController = TextEditingController(text: initialRecord.allergies);
    final diagnosisController = TextEditingController(text: initialRecord.diagnosis);
    final medicationController = TextEditingController(text: initialRecord.currentMedication);
    final notesController = TextEditingController(text: initialRecord.clinicalNotes);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var savingRecord = false;
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            Future<void> save() async {
              final allergies = allergiesController.text.trim().toUpperCase();
              final diagnosis = diagnosisController.text.trim().toUpperCase();
              final medication = medicationController.text.trim().toUpperCase();
              final notes = notesController.text.trim().toUpperCase();

              if (diagnosis.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El diagnostico es obligatorio.')));
                return;
              }

              setDialogState(() => savingRecord = true);
              try {
                await _service.saveRecord(
                  patientId: widget.patient.id,
                  doctorId: widget.currentUser.doctorId!,
                  allergies: allergies,
                  diagnosis: diagnosis,
                  currentMedication: medication,
                  clinicalNotes: notes,
                );
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => savingRecord = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Crear o actualizar expediente'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: allergiesController,
                      textCapitalization: TextCapitalization.characters,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Alergias'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: diagnosisController,
                      textCapitalization: TextCapitalization.characters,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Diagnostico'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: medicationController,
                      textCapitalization: TextCapitalization.characters,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Medicacion actual'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      textCapitalization: TextCapitalization.characters,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Notas clinicas'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: savingRecord ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: savingRecord ? null : save,
                  icon: savingRecord
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: Text(savingRecord ? 'Guardando...' : 'Guardar expediente'),
                ),
              ],
            );
          },
        );
      },
    );

    allergiesController.dispose();
    diagnosisController.dispose();
    medicationController.dispose();
    notesController.dispose();

    if (saved == true) {
      await _refresh();
    }
  }

  Future<void> _showPrescriptionEditor() async {
    final medications = <_MedicationDraft>[_MedicationDraft()];

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var savingPrescription = false;
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            void addMedication() {
              setDialogState(() => medications.add(_MedicationDraft()));
            }

            void removeMedication(int index) {
              if (medications.length == 1) return;
              medications[index].dispose();
              setDialogState(() => medications.removeAt(index));
            }

            Future<void> save() async {
              final items = medications.map((draft) => draft.toMedicationItem()).toList();

              final hasInvalid = items.any(
                (item) =>
                    item.name.isEmpty ||
                    item.dosage.isEmpty ||
                    item.frequency.isEmpty ||
                    item.duration.isEmpty ||
                    item.instructions.isEmpty,
              );

              if (hasInvalid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Completa todos los campos obligatorios de cada medicamento.')),
                );
                return;
              }

              setDialogState(() => savingPrescription = true);
              try {
                await _service.savePrescription(
                  patientId: widget.patient.id,
                  doctorId: widget.currentUser.doctorId!,
                  medications: items,
                );
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => savingPrescription = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Crear receta'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...medications.asMap().entries.map(
                        (entry) => _MedicationEditorCard(
                          index: entry.key,
                          draft: entry.value,
                          canRemove: medications.length > 1,
                          onRemove: () => removeMedication(entry.key),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: savingPrescription ? null : addMedication,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Agregar medicamento'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: savingPrescription ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: savingPrescription ? null : save,
                  icon: savingPrescription
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.receipt_long_rounded),
                  label: Text(savingPrescription ? 'Guardando...' : 'Guardar receta'),
                ),
              ],
            );
          },
        );
      },
    );

    for (final medication in medications) {
      medication.dispose();
    }

    if (saved == true) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.patient.fullName)),
      body: FutureBuilder<_PatientDetailBundle>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('No se pudo cargar la informacion del paciente', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    const Text('Vuelve a intentarlo en unos momentos.'),
                    const SizedBox(height: 18),
                    ElevatedButton(onPressed: _refresh, child: const Text('Reintentar')),
                  ],
                ),
              ),
            );
          }

          final bundle = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _HeaderCard(patient: widget.patient),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Datos generales',
                  children: [
                    _InfoRow(label: 'Telefono', value: widget.patient.phone.isEmpty ? 'Sin telefono' : widget.patient.phone),
                    _InfoRow(label: 'Correo', value: widget.patient.email.isEmpty ? 'Sin correo' : widget.patient.email),
                    _InfoRow(label: 'Tipo de sangre', value: widget.patient.bloodType.isEmpty ? 'Sin registro' : widget.patient.bloodType),
                    _InfoRow(label: 'Nacimiento', value: widget.patient.birthDate.isEmpty ? 'Sin fecha' : widget.patient.birthDate),
                    _InfoRow(label: 'Notas generales', value: widget.patient.notes.isEmpty ? 'Sin notas' : widget.patient.notes),
                  ],
                ),
                if (!_isAssistant) ...[
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Expediente clinico',
                    action: _canEditRecord
                        ? OutlinedButton.icon(
                            onPressed: () => _showRecordEditor(bundle.record),
                            icon: const Icon(Icons.edit_note_rounded),
                            label: Text(bundle.record.diagnosis.isEmpty ? 'Dar de alta expediente' : 'Actualizar expediente'),
                          )
                        : null,
                    children: [
                      _InfoRow(label: 'Medico principal', value: bundle.record.doctorName.isEmpty ? 'Sin asignar' : bundle.record.doctorName),
                      _InfoRow(label: 'Alergias', value: bundle.record.allergies.isEmpty ? 'Sin registro' : bundle.record.allergies),
                      _InfoRow(label: 'Condiciones cronicas', value: bundle.record.chronicConditions.isEmpty ? 'Sin registro' : bundle.record.chronicConditions),
                      _InfoRow(label: 'Medicacion actual', value: bundle.record.currentMedication.isEmpty ? 'Sin registro' : bundle.record.currentMedication),
                      _InfoRow(label: 'Diagnostico', value: bundle.record.diagnosis.isEmpty ? 'Sin registro' : bundle.record.diagnosis),
                      _InfoRow(label: 'Notas clinicas', value: bundle.record.clinicalNotes.isEmpty ? 'Sin registro' : bundle.record.clinicalNotes),
                      _InfoRow(label: 'Ultima visita', value: bundle.record.lastVisitAt.isEmpty ? 'Sin fecha' : bundle.record.lastVisitAt),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Recetas asignadas',
                  action: _canCreatePrescription
                      ? FilledButton.icon(
                          onPressed: _showPrescriptionEditor,
                          icon: const Icon(Icons.add_card_rounded),
                          label: const Text('Crear receta'),
                        )
                      : null,
                  children: [
                    if (bundle.prescriptions.isEmpty)
                      const Text('Todavia no hay recetas registradas para este paciente.')
                    else
                      ...bundle.prescriptions.map(
                        (prescription) => Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${prescription.medications.length} medicamento${prescription.medications.length == 1 ? '' : 's'} en la receta',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              ...prescription.medications.asMap().entries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${entry.key + 1}. ${entry.value.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text('Dosis: ${entry.value.dosage}'),
                                      Text('Frecuencia: ${entry.value.frequency}'),
                                      Text('Duracion: ${entry.value.duration}'),
                                      Text('Indicaciones: ${entry.value.instructions}'),
                                      if (entry.value.notes.isNotEmpty) Text('Notas: ${entry.value.notes}'),
                                    ],
                                  ),
                                ),
                              ),
                              Text('Medico: ${prescription.doctorName}'),
                              Text('Fecha: ${prescription.prescribedAt}'),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _exportingId == prescription.id ? null : () => _downloadPdf(prescription),
                                icon: _exportingId == prescription.id
                                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.picture_as_pdf_rounded),
                                label: Text(_exportingId == prescription.id ? 'Generando...' : 'Descargar PDF'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PatientDetailBundle {
  const _PatientDetailBundle({required this.record, required this.prescriptions});

  final MedicalRecordData record;
  final List<PrescriptionData> prescriptions;
}

class _MedicationDraft {
  _MedicationDraft()
      : nameController = TextEditingController(),
        dosageController = TextEditingController(),
        frequencyController = TextEditingController(),
        durationController = TextEditingController(),
        instructionsController = TextEditingController(),
        notesController = TextEditingController();

  final TextEditingController nameController;
  final TextEditingController dosageController;
  final TextEditingController frequencyController;
  final TextEditingController durationController;
  final TextEditingController instructionsController;
  final TextEditingController notesController;

  PrescriptionMedicationItem toMedicationItem() {
    return PrescriptionMedicationItem(
      name: nameController.text.trim().toUpperCase(),
      dosage: dosageController.text.trim().toUpperCase(),
      frequency: frequencyController.text.trim().toUpperCase(),
      duration: durationController.text.trim().toUpperCase(),
      instructions: instructionsController.text.trim().toUpperCase(),
      notes: notesController.text.trim().toUpperCase(),
    );
  }

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    instructionsController.dispose();
    notesController.dispose();
  }
}

class _MedicationEditorCard extends StatelessWidget {
  const _MedicationEditorCard({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _MedicationDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        color: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Medicamento ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
              if (canRemove)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Quitar medicamento',
                ),
            ],
          ),
          TextField(
            controller: draft.nameController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Medicamento'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: draft.dosageController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Dosis'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: draft.frequencyController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Frecuencia'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: draft.durationController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Duracion'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: draft.instructionsController,
            textCapitalization: TextCapitalization.characters,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Indicaciones'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: draft.notesController,
            textCapitalization: TextCapitalization.characters,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notas adicionales'),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.patient});

  final PatientSummary patient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(colors: [Color(0xFF0A6774), Color(0xFF2D59C4)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(patient.fullName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Expediente: ${patient.medicalRecordNumber}', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Tag(text: patient.bloodType.isEmpty ? 'Sin tipo sanguineo' : patient.bloodType),
              _Tag(text: patient.birthDate.isEmpty ? 'Sin fecha de nacimiento' : patient.birthDate),
              _Tag(text: patient.phone.isEmpty ? 'Sin telefono' : patient.phone),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}
