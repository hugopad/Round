enum RoleType { admin, doctor, assistant, patient }

extension RoleTypeLabel on RoleType {
  String get code {
    switch (this) {
      case RoleType.admin:
        return 'ADMIN';
      case RoleType.doctor:
        return 'DOCTOR';
      case RoleType.assistant:
        return 'SECRETARY';
      case RoleType.patient:
        return 'PATIENT';
    }
  }

  String get label {
    switch (this) {
      case RoleType.admin:
        return 'Admin';
      case RoleType.doctor:
        return 'Medico';
      case RoleType.assistant:
        return 'Asistente';
      case RoleType.patient:
        return 'Paciente';
    }
  }
}
