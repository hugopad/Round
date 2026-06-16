import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/auth_user.dart';
import '../models/doctor_summary_data.dart';
import '../models/role_type.dart';
import '../services/agenda_service.dart';
import '../services/patient_service.dart';

class AssistantPatientIntakeScreen extends StatefulWidget {
  const AssistantPatientIntakeScreen({
    super.key,
    required this.currentUser,
  });

  final AuthUser currentUser;

  @override
  State<AssistantPatientIntakeScreen> createState() => _AssistantPatientIntakeScreenState();
}

class _AssistantPatientIntakeScreenState extends State<AssistantPatientIntakeScreen> {
  static const List<String> _satRegimes = [
    '601 | GENERAL DE LEY PERSONAS MORALES',
    '603 | PERSONAS MORALES CON FINES NO LUCRATIVOS',
    '605 | SUELDOS Y SALARIOS E INGRESOS ASIMILADOS A SALARIOS',
    '606 | ARRENDAMIENTO',
    '607 | REGIMEN DE ENAJENACION O ADQUISICION DE BIENES',
    '608 | DEMAS INGRESOS',
    '610 | RESIDENTES EN EL EXTRANJERO SIN ESTABLECIMIENTO PERMANENTE EN MEXICO',
    '611 | INGRESOS POR DIVIDENDOS',
    '612 | PERSONAS FISICAS CON ACTIVIDADES EMPRESARIALES Y PROFESIONALES',
    '614 | INGRESOS POR INTERESES',
    '615 | REGIMEN DE LOS INGRESOS POR OBTENCION DE PREMIOS',
    '616 | SIN OBLIGACIONES FISCALES',
    '620 | SOCIEDADES COOPERATIVAS DE PRODUCCION QUE OPTAN POR DIFERIR SUS INGRESOS',
    '621 | INCORPORACION FISCAL',
    '622 | ACTIVIDADES AGRICOLAS, GANADERAS, SILVICOLAS Y PESQUERAS',
    '623 | OPCIONAL PARA GRUPOS DE SOCIEDADES',
    '624 | COORDINADOS',
    '625 | REGIMEN DE LAS ACTIVIDADES EMPRESARIALES CON INGRESOS A TRAVES DE PLATAFORMAS TECNOLOGICAS',
    '626 | REGIMEN SIMPLIFICADO DE CONFIANZA',
  ];

  static const List<String> _satCfdiUses = [
    'G01 | ADQUISICION DE MERCANCIAS',
    'G02 | DEVOLUCIONES, DESCUENTOS O BONIFICACIONES',
    'G03 | GASTOS EN GENERAL',
    'I01 | CONSTRUCCIONES',
    'I02 | MOBILIARIO Y EQUIPO DE OFICINA POR INVERSIONES',
    'I03 | EQUIPO DE TRANSPORTE',
    'I04 | EQUIPO DE COMPUTO Y ACCESORIOS',
    'I05 | DADOS, TROQUELES, MOLDES, MATRICES Y HERRAMENTAL',
    'I06 | COMUNICACIONES TELEFONICAS',
    'I07 | COMUNICACIONES SATELITALES',
    'I08 | OTRA MAQUINARIA Y EQUIPO',
    'D01 | HONORARIOS MEDICOS, DENTALES Y GASTOS HOSPITALARIOS',
    'D02 | GASTOS MEDICOS POR INCAPACIDAD O DISCAPACIDAD',
    'D03 | GASTOS FUNERALES',
    'D04 | DONATIVOS',
    'D05 | INTERESES REALES EFECTIVAMENTE PAGADOS POR CREDITOS HIPOTECARIOS',
    'D06 | APORTACIONES VOLUNTARIAS AL SAR',
    'D07 | PRIMAS POR SEGUROS DE GASTOS MEDICOS',
    'D08 | GASTOS DE TRANSPORTACION ESCOLAR OBLIGATORIA',
    'D09 | DEPOSITOS EN CUENTAS PARA EL AHORRO, PRIMAS QUE TENGAN COMO BASE PLANES DE PENSIONES',
    'D10 | PAGOS POR SERVICIOS EDUCATIVOS (COLEGIATURAS)',
    'S01 | SIN EFECTOS FISCALES',
    'CP01 | PAGOS',
    'CN01 | NOMINA',
  ];

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _fiscalNameController = TextEditingController();
  final _fiscalRfcController = TextEditingController();
  final _fiscalPostalCodeController = TextEditingController();
  final _accessPasswordController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _currentMedicationController = TextEditingController();
  final _clinicalNotesController = TextEditingController();

  final AgendaService _agendaService = AgendaService();
  final PatientService _patientService = PatientService();

  bool _loadingDoctors = true;
  bool _saving = false;
  String? _errorMessage;
  List<DoctorSummaryData> _doctors = const [];
  final Set<int> _selectedDoctorIds = <int>{};
  bool _createAccess = true;
  bool _createRecord = false;
  bool _showAccessPassword = false;
  String? _selectedFiscalRegime;
  String? _selectedCfdiUse;

  bool get _isDoctor => widget.currentUser.role == RoleType.doctor;

  String get _screenTitle => _isDoctor ? 'Alta de paciente' : 'Alta administrativa';

  String get _heroTitle => _isDoctor ? 'Alta por medico' : 'Alta por asistente';

  String get _heroSubtitle => _isDoctor
      ? 'Registra pacientes, envia su acceso por correo y deja listo su expediente inicial.'
      : 'Registro administrativo con datos generales, SAT, medicos asignados y expediente inicial opcional.';

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _fiscalNameController.dispose();
    _fiscalRfcController.dispose();
    _fiscalPostalCodeController.dispose();
    _accessPasswordController.dispose();
    _allergiesController.dispose();
    _diagnosisController.dispose();
    _currentMedicationController.dispose();
    _clinicalNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _loadingDoctors = true;
      _errorMessage = null;
    });

    try {
      final doctors = await _agendaService.loadDoctors();
      final visibleDoctors = _isDoctor && widget.currentUser.doctorId != null
          ? doctors.where((doctor) => doctor.id == widget.currentUser.doctorId).toList()
          : doctors;
      if (!mounted) return;
      setState(() {
        _doctors = visibleDoctors;
        if (_isDoctor && widget.currentUser.doctorId != null) {
          _selectedDoctorIds
            ..clear()
            ..add(widget.currentUser.doctorId!);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString().replaceFirst('Exception: ', ''));
    }

    if (!mounted) return;
    setState(() => _loadingDoctors = false);
  }

  String _upper(String value) => value.trim().toUpperCase();
  String _digits(String value) => value.replaceAll(RegExp(r'\D+'), '');
  String _satCode(String? value) => (value ?? '').split('|').first.trim().toUpperCase();
  bool get _hasAnyFiscalData =>
      _fiscalNameController.text.trim().isNotEmpty ||
      _fiscalRfcController.text.trim().isNotEmpty ||
      _fiscalPostalCodeController.text.trim().isNotEmpty ||
      _selectedFiscalRegime != null ||
      _selectedCfdiUse != null;

  String? _validateRfc(String? value) {
    final rfc = _upper(value ?? '');
    if (rfc.isEmpty) {
      return _hasAnyFiscalData ? 'Captura el RFC' : null;
    }
    if (rfc.length < 12 || rfc.length > 13) return 'El RFC debe tener 12 o 13 caracteres';
    if (!RegExp(r'^[A-Z&]{3,4}[0-9]{6}[A-Z0-9]{3}$').hasMatch(rfc)) {
      return 'Captura un RFC valido';
    }
    return null;
  }

  String? _validatePostalCode(String? value) {
    final postalCode = _digits(value ?? '');
    if (postalCode.isEmpty) {
      return _hasAnyFiscalData ? 'Captura el codigo postal fiscal' : null;
    }
    if (postalCode.length != 5) return 'El codigo postal debe tener 5 digitos';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedDoctorIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un medico.')),
      );
      return;
    }
    if (_hasAnyFiscalData && (_selectedFiscalRegime == null || _selectedCfdiUse == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Si capturas datos fiscales, completa regimen fiscal y uso CFDI.')),
      );
      return;
    }
    if (_createAccess && _accessPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contrasena inicial es obligatoria si se crea acceso.')),
      );
      return;
    }
    if (_createRecord && _diagnosisController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captura el diagnostico inicial para crear el expediente.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await _patientService.createManagedPatient(
        actorUserId: widget.currentUser.id,
        intakeMode: _isDoctor ? 'DOCTOR' : 'ASSISTANT',
        fullName: _upper(_fullNameController.text),
        phone: _digits(_phoneController.text),
        email: _emailController.text.trim(),
        address: _upper(_addressController.text),
        fiscalName: _upper(_fiscalNameController.text),
        fiscalRfc: _upper(_fiscalRfcController.text),
        fiscalRegime: _satCode(_selectedFiscalRegime),
        fiscalPostalCode: _digits(_fiscalPostalCodeController.text),
        fiscalCfdiUse: _satCode(_selectedCfdiUse),
        doctorIds: _selectedDoctorIds.toList(),
        createAccess: _createAccess,
        accessPassword: _accessPasswordController.text.trim(),
        createRecord: _createRecord,
        allergies: _upper(_allergiesController.text),
        diagnosis: _upper(_diagnosisController.text),
        currentMedication: _upper(_currentMedicationController.text),
        clinicalNotes: _upper(_clinicalNotesController.text),
      );

      if (!mounted) return;
      final successMessage = result.emailSent
          ? 'Paciente creado y acceso enviado por correo.'
          : result.emailError.isNotEmpty
              ? 'Paciente creado. Folio ${result.medicalRecordNumber}. Error al enviar correo: ${result.emailError}'
              : 'Paciente creado. Folio ${result.medicalRecordNumber}.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      _formKey.currentState!.reset();
      _fullNameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _addressController.clear();
      _fiscalNameController.clear();
      _fiscalRfcController.clear();
      _fiscalPostalCodeController.clear();
      _accessPasswordController.clear();
      _allergiesController.clear();
      _diagnosisController.clear();
      _currentMedicationController.clear();
      _clinicalNotesController.clear();
      setState(() {
        _selectedDoctorIds.clear();
        if (_isDoctor && widget.currentUser.doctorId != null) {
          _selectedDoctorIds.add(widget.currentUser.doctorId!);
        }
        _createAccess = true;
        _createRecord = false;
        _showAccessPassword = false;
        _selectedFiscalRegime = null;
        _selectedCfdiUse = null;
      });
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
      appBar: AppBar(title: Text(_screenTitle)),
      body: _loadingDoctors
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
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
                          _heroTitle,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _heroSubtitle,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _fullNameController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Nombre completo'),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Captura el nombre completo' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Telefono'),
                    validator: (value) => _digits(value ?? '').isEmpty ? 'Captura el telefono' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo'),
                    validator: (value) => (value == null || !value.contains('@')) ? 'Captura un correo valido' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Direccion'),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Captura la direccion' : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Datos fiscales SAT',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fiscalNameController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Razon social o nombre fiscal (opcional)'),
                    validator: (value) =>
                        _hasAnyFiscalData && (value == null || value.trim().isEmpty) ? 'Captura el nombre fiscal' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _fiscalRfcController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [LengthLimitingTextInputFormatter(13)],
                    decoration: const InputDecoration(labelText: 'RFC (opcional)'),
                    validator: _validateRfc,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFiscalRegime,
                    decoration: const InputDecoration(labelText: 'Regimen fiscal (opcional)'),
                    items: _satRegimes
                        .map((regime) => DropdownMenuItem<String>(value: regime, child: Text(regime)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedFiscalRegime = value),
                    validator: (value) => _hasAnyFiscalData && (value == null || value.isEmpty)
                        ? 'Selecciona el regimen fiscal'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _fiscalPostalCodeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                    decoration: const InputDecoration(labelText: 'Codigo postal fiscal (opcional)'),
                    validator: _validatePostalCode,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCfdiUse,
                    decoration: const InputDecoration(labelText: 'Uso CFDI (opcional)'),
                    items: _satCfdiUses
                        .map((use) => DropdownMenuItem<String>(value: use, child: Text(use)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCfdiUse = value),
                    validator: (value) => _hasAnyFiscalData && (value == null || value.isEmpty)
                        ? 'Selecciona el uso CFDI'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isDoctor ? 'Medico responsable' : 'Medicos asignados',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ..._doctors.map(
                    (doctor) => CheckboxListTile(
                      value: _selectedDoctorIds.contains(doctor.id),
                      title: Text(doctor.fullName),
                      subtitle: Text(doctor.specialty),
                      onChanged: _isDoctor
                          ? null
                          : (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedDoctorIds.add(doctor.id);
                                } else {
                                  _selectedDoctorIds.remove(doctor.id);
                                }
                              });
                            },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _createRecord,
                    title: const Text('Crear expediente inicial'),
                    subtitle: const Text('Permite dejar listo el expediente clinico desde el alta.'),
                    onChanged: (value) => setState(() => _createRecord = value),
                  ),
                  if (_createRecord) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _allergiesController,
                      textCapitalization: TextCapitalization.characters,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Alergias'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _diagnosisController,
                      textCapitalization: TextCapitalization.characters,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Diagnostico inicial'),
                      validator: (value) => _createRecord && (value == null || value.trim().isEmpty) ? 'Captura el diagnostico inicial' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _currentMedicationController,
                      textCapitalization: TextCapitalization.characters,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Medicacion actual'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clinicalNotesController,
                      textCapitalization: TextCapitalization.characters,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Notas clinicas iniciales'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _createAccess,
                    title: const Text('Crear acceso inicial'),
                    subtitle: const Text('Envia por correo el acceso y la liga de la APK.'),
                    onChanged: (value) => setState(() => _createAccess = value),
                  ),
                  if (_createAccess) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _accessPasswordController,
                      obscureText: !_showAccessPassword,
                      decoration: InputDecoration(
                        labelText: 'Contrasena inicial',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _showAccessPassword = !_showAccessPassword),
                          icon: Icon(
                            _showAccessPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                      validator: (value) => _createAccess && (value == null || value.trim().isEmpty) ? 'Captura la contrasena inicial' : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(_saving ? 'Guardando...' : 'Crear paciente'),
                  ),
                ],
              ),
            ),
    );
  }
}
