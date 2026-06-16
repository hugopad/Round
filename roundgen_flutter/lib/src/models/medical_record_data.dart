class MedicalRecordData {
  const MedicalRecordData({
    required this.patientId,
    required this.doctorName,
    required this.allergies,
    required this.chronicConditions,
    required this.currentMedication,
    required this.diagnosis,
    required this.clinicalNotes,
    required this.lastVisitAt,
  });

  final int patientId;
  final String doctorName;
  final String allergies;
  final String chronicConditions;
  final String currentMedication;
  final String diagnosis;
  final String clinicalNotes;
  final String lastVisitAt;

  factory MedicalRecordData.fromJson(Map<String, dynamic> json) {
    return MedicalRecordData(
      patientId: int.tryParse('${json['patient_id'] ?? 0}') ?? 0,
      doctorName: (json['doctor_name'] ?? '').toString(),
      allergies: (json['allergies'] ?? '').toString(),
      chronicConditions: (json['chronic_conditions'] ?? '').toString(),
      currentMedication: (json['current_medication'] ?? '').toString(),
      diagnosis: (json['diagnosis'] ?? '').toString(),
      clinicalNotes: (json['clinical_notes'] ?? '').toString(),
      lastVisitAt: (json['last_visit_at'] ?? '').toString(),
    );
  }

  factory MedicalRecordData.empty(int patientId) {
    return MedicalRecordData(
      patientId: patientId,
      doctorName: '',
      allergies: '',
      chronicConditions: '',
      currentMedication: '',
      diagnosis: '',
      clinicalNotes: '',
      lastVisitAt: '',
    );
  }
}
