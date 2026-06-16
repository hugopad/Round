class PrescriptionMedicationItem {
  const PrescriptionMedicationItem({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.instructions,
    required this.notes,
  });

  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final String instructions;
  final String notes;

  factory PrescriptionMedicationItem.fromJson(Map<String, dynamic> json) {
    return PrescriptionMedicationItem(
      name: (json['name'] ?? json['medication_name'] ?? '').toString(),
      dosage: (json['dosage'] ?? '').toString(),
      frequency: (json['frequency'] ?? '').toString(),
      duration: (json['duration'] ?? '').toString(),
      instructions: (json['instructions'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
      'notes': notes,
    };
  }
}

class PrescriptionData {
  const PrescriptionData({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.medications,
    required this.prescribedAt,
  });

  final int id;
  final int patientId;
  final int doctorId;
  final String doctorName;
  final List<PrescriptionMedicationItem> medications;
  final String prescribedAt;

  PrescriptionMedicationItem get primaryMedication =>
      medications.isNotEmpty
          ? medications.first
          : const PrescriptionMedicationItem(
              name: '',
              dosage: '',
              frequency: '',
              duration: '',
              instructions: '',
              notes: '',
            );

  String get medicationName => primaryMedication.name;
  String get dosage => primaryMedication.dosage;
  String get frequency => primaryMedication.frequency;
  String get duration => primaryMedication.duration;
  String get instructions => primaryMedication.instructions;
  String get notes => primaryMedication.notes;

  factory PrescriptionData.fromJson(Map<String, dynamic> json) {
    final rawMedications = json['medications'];
    List<PrescriptionMedicationItem> medications;

    if (rawMedications is List) {
      medications = rawMedications
          .whereType<Map<String, dynamic>>()
          .map(PrescriptionMedicationItem.fromJson)
          .where((item) => item.name.isNotEmpty)
          .toList();
    } else {
      final fallback = PrescriptionMedicationItem(
        name: (json['medication_name'] ?? '').toString(),
        dosage: (json['dosage'] ?? '').toString(),
        frequency: (json['frequency'] ?? '').toString(),
        duration: (json['duration'] ?? '').toString(),
        instructions: (json['instructions'] ?? '').toString(),
        notes: (json['notes'] ?? '').toString(),
      );
      medications = fallback.name.isEmpty ? const [] : [fallback];
    }

    return PrescriptionData(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      patientId: int.tryParse('${json['patient_id'] ?? 0}') ?? 0,
      doctorId: int.tryParse('${json['doctor_id'] ?? 0}') ?? 0,
      doctorName: (json['doctor_name'] ?? '').toString(),
      medications: medications,
      prescribedAt: (json['prescribed_at'] ?? '').toString(),
    );
  }
}
