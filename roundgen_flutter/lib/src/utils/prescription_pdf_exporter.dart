import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/patient_summary.dart';
import '../models/prescription_data.dart';

class PrescriptionPdfExporter {
  Future<File> export({
    required PatientSummary patient,
    required PrescriptionData prescription,
  }) async {
    final pdf = pw.Document();
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    final exportDate = DateTime.tryParse(prescription.prescribedAt.replaceFirst(' ', 'T'));

    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
        ),
        build: (context) => [
          pw.Text(
            'ROUNDGEN',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Receta medica',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Paciente: ${patient.fullName}'),
          pw.Text('Expediente: ${patient.medicalRecordNumber}'),
          pw.Text('Telefono: ${patient.phone.isEmpty ? 'Sin telefono' : patient.phone}'),
          pw.Text('Correo: ${patient.email.isEmpty ? 'Sin correo' : patient.email}'),
          pw.Text('Fecha: ${exportDate != null ? formatter.format(exportDate) : prescription.prescribedAt}'),
          pw.SizedBox(height: 18),
          pw.Text(
            'Medicamentos prescritos',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          ...prescription.medications.asMap().entries.map(
                (entry) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blueGrey200),
                    borderRadius: pw.BorderRadius.circular(14),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${entry.key + 1}. ${entry.value.name}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Dosis: ${entry.value.dosage}'),
                      pw.Text('Frecuencia: ${entry.value.frequency}'),
                      pw.Text('Duracion: ${entry.value.duration}'),
                      pw.SizedBox(height: 8),
                      pw.Text('Indicaciones:'),
                      pw.Text(entry.value.instructions),
                      if (entry.value.notes.isNotEmpty) ...[
                        pw.SizedBox(height: 8),
                        pw.Text('Notas:'),
                        pw.Text(entry.value.notes),
                      ],
                    ],
                  ),
                ),
              ),
          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColors.blueGrey300),
          pw.SizedBox(height: 8),
          pw.Text('Firma del medico', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 18),
          pw.Text(prescription.doctorName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Firma digital generada desde ROUNDGEN'),
        ],
      ),
    );

    final root = await getApplicationDocumentsDirectory();
    final roundgenDir = Directory('${root.path}${Platform.pathSeparator}roundgen');
    if (!await roundgenDir.exists()) {
      await roundgenDir.create(recursive: true);
    }

    final safeName = patient.fullName
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final file = File('${roundgenDir.path}${Platform.pathSeparator}RECETA_${safeName}_${prescription.id}.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }
}
