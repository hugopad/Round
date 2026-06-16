import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/create_patient_result.dart';
import '../models/medical_record_data.dart';
import '../models/patient_summary.dart';
import '../models/prescription_data.dart';

class PatientService {
  final http.Client _client;

  PatientService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PatientSummary>> loadPatients({int? doctorId}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/patients/list.php').replace(
      queryParameters: doctorId != null ? {'doctor_id': '$doctorId'} : null,
    );
    final payload = await _readPayload(
      await _client.get(uri, headers: const {'Accept': 'application/json'}),
      'No se pudieron cargar los pacientes',
      allowEmptySuccess: true,
    );
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PatientSummary.fromJson)
        .where((patient) => patient.isActive)
        .toList();
  }

  Future<MedicalRecordData> loadRecord(int patientId) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/patients/record.php').replace(
      queryParameters: {'patient_id': '$patientId'},
    );
    final payload = await _readPayload(
      await _client.get(uri, headers: const {'Accept': 'application/json'}),
      'No se pudo cargar el expediente',
      allowEmptySuccess: true,
    );
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return MedicalRecordData.fromJson(data);
    }
    return MedicalRecordData.empty(patientId);
  }

  Future<List<PrescriptionData>> loadPrescriptions(int patientId) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/patients/prescriptions.php').replace(
      queryParameters: {'patient_id': '$patientId'},
    );
    final payload = await _readPayload(
      await _client.get(uri, headers: const {'Accept': 'application/json'}),
      'No se pudieron cargar las recetas',
      allowEmptySuccess: true,
    );
    return (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PrescriptionData.fromJson)
        .toList();
  }

  Future<CreatePatientResult> createManagedPatient({
    required int actorUserId,
    required String intakeMode,
    required String fullName,
    required String phone,
    required String email,
    required String address,
    required String fiscalName,
    required String fiscalRfc,
    required String fiscalRegime,
    required String fiscalPostalCode,
    required String fiscalCfdiUse,
    required List<int> doctorIds,
    required bool createAccess,
    required String accessPassword,
    required bool createRecord,
    required String allergies,
    required String diagnosis,
    required String currentMedication,
    required String clinicalNotes,
  }) async {
    final payload = await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/patients/create.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'full_name': fullName,
          'assistant_user_id': intakeMode == 'ASSISTANT' ? actorUserId : 0,
          'actor_user_id': actorUserId,
          'phone': phone,
          'email': email,
          'address': address,
          'intake_mode': intakeMode,
          'fiscal_name': fiscalName,
          'fiscal_rfc': fiscalRfc,
          'fiscal_regime': fiscalRegime,
          'fiscal_postal_code': fiscalPostalCode,
          'fiscal_cfdi_use': fiscalCfdiUse,
          'doctor_ids': doctorIds,
          'create_access': createAccess,
          'access_password': accessPassword,
          'create_record': createRecord,
          'allergies': allergies,
          'diagnosis': diagnosis,
          'current_medication': currentMedication,
          'clinical_notes': clinicalNotes,
        }),
      ),
      'No se pudo crear el paciente',
    );
    return CreatePatientResult.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<void> deactivatePatient({required int patientId}) async {
    await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/patients/deactivate.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'patient_id': patientId}),
      ),
      'No se pudo dar de baja al paciente',
    );
  }

  Future<void> saveRecord({
    required int patientId,
    required int doctorId,
    required String allergies,
    required String diagnosis,
    required String currentMedication,
    required String clinicalNotes,
  }) async {
    await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/patients/save_record.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'patient_id': patientId,
          'doctor_id': doctorId,
          'allergies': allergies,
          'diagnosis': diagnosis,
          'current_medication': currentMedication,
          'clinical_notes': clinicalNotes,
        }),
      ),
      'No se pudo guardar el expediente',
    );
  }

  Future<void> savePrescription({
    required int patientId,
    required int doctorId,
    required List<PrescriptionMedicationItem> medications,
  }) async {
    final cleanedMedications = medications
        .map(
          (item) => PrescriptionMedicationItem(
            name: item.name.trim().toUpperCase(),
            dosage: item.dosage.trim().toUpperCase(),
            frequency: item.frequency.trim().toUpperCase(),
            duration: item.duration.trim().toUpperCase(),
            instructions: item.instructions.trim().toUpperCase(),
            notes: item.notes.trim().toUpperCase(),
          ),
        )
        .where(
          (item) =>
              item.name.isNotEmpty &&
              item.dosage.isNotEmpty &&
              item.frequency.isNotEmpty &&
              item.duration.isNotEmpty &&
              item.instructions.isNotEmpty,
        )
        .toList();

    if (cleanedMedications.isEmpty) {
      throw Exception('Agrega al menos un medicamento completo a la receta.');
    }

    await _readPayload(
      await _client.post(
        Uri.parse('${AppConfig.baseUrl}/patients/save_prescription.php'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'patient_id': patientId,
          'doctor_id': doctorId,
          'medications': cleanedMedications.map((item) => item.toJson()).toList(),
        }),
      ),
      'No se pudo guardar la receta',
    );
  }

  Future<Map<String, dynamic>> _readPayload(
    http.Response response,
    String fallbackMessage, {
    bool allowEmptySuccess = false,
  }) async {
    final body = response.body.trim();
    if (body.isEmpty) {
      if (allowEmptySuccess && response.statusCode < 400) {
        return <String, dynamic>{'success': true, 'data': const []};
      }
      throw Exception('$fallbackMessage (respuesta vacia del servidor)');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      final cleanSnippet = body
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final snippet = cleanSnippet.length > 180
          ? '${cleanSnippet.substring(0, 180)}...'
          : cleanSnippet;
      throw Exception(snippet.isEmpty ? fallbackMessage : '$fallbackMessage: $snippet');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception(fallbackMessage);
    }
    if (response.statusCode >= 400 || decoded['success'] != true) {
      throw Exception((decoded['error'] ?? fallbackMessage).toString());
    }
    return decoded;
  }
}
