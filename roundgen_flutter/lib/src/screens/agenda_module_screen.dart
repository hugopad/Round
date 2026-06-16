import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment_data.dart';
import '../models/auth_user.dart';
import '../models/doctor_summary_data.dart';
import '../models/patient_summary.dart';
import '../models/room_summary_data.dart';
import '../models/role_type.dart';
import '../services/agenda_service.dart';
import '../services/content_service.dart';
import '../services/patient_service.dart';

enum _AgendaCalendarMode { month, week, day }

class AgendaModuleScreen extends StatefulWidget {
  const AgendaModuleScreen({
    super.key,
    required this.currentUser,
  });

  final AuthUser currentUser;

  @override
  State<AgendaModuleScreen> createState() => _AgendaModuleScreenState();
}

class _AgendaModuleScreenState extends State<AgendaModuleScreen> {
  final AgendaService _agendaService = AgendaService();
  final PatientService _patientService = PatientService();
  final ContentService _contentService = ContentService();
  final TextEditingController _reasonController = TextEditingController(text: 'CONTROL GENERAL');
  final ScrollController _timelineVerticalController = ScrollController();

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  List<DoctorSummaryData> _doctors = const [];
  List<PatientSummary> _patients = const [];
  List<RoomSummaryData> _rooms = const [];
  List<String> _slots = const [];
  List<DateTime> _availableDays = const [];
  List<AppointmentData> _weeklyAppointments = const [];
  bool _showBookingForm = false;
  AppointmentData? _editingAppointment;
  _AgendaCalendarMode _calendarMode = _AgendaCalendarMode.month;

  DoctorSummaryData? _selectedDoctor;
  PatientSummary? _selectedPatient;
  RoomSummaryData? _selectedRoom;
  String? _selectedSlot;
  late DateTime _selectedDate;
  late DateTime _calendarMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _calendarMonth = DateTime(now.year, now.month, 1);
    _showBookingForm = _isPatientRole;
    _bootstrap();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _timelineVerticalController.dispose();
    super.dispose();
  }

  bool get _isPatientRole => widget.currentUser.role == RoleType.patient;
  bool get _isDoctorRole => widget.currentUser.role == RoleType.doctor;
  bool get _isAssistantRole => widget.currentUser.role == RoleType.assistant;
  int? get _activeDoctorId => _isDoctorRole ? widget.currentUser.doctorId : _selectedDoctor?.id;

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final loadedDoctors = await _loadDoctorsSafely();
      final doctors = [...loadedDoctors];
      DoctorSummaryData? selectedDoctor;
      if (_isDoctorRole && widget.currentUser.doctorId != null) {
        selectedDoctor = doctors.firstWhereOrNull((doctor) => doctor.id == widget.currentUser.doctorId);
        selectedDoctor ??= DoctorSummaryData(
          id: widget.currentUser.doctorId!,
          fullName: widget.currentUser.fullName,
          licenseNumber: '',
          specialty: 'MEDICINA GENERAL',
        );
        if (!doctors.any((doctor) => doctor.id == selectedDoctor!.id)) {
          doctors.insert(0, selectedDoctor);
        }
      }
      selectedDoctor ??= doctors.isNotEmpty ? doctors.first : null;

      final patients = await _loadPatientsForDoctor(selectedDoctor?.id);
      final selectedPatient = _resolvePatient(patients);
      final rooms = await _loadRoomsForDoctor(selectedDoctor?.id);
      final selectedRoom = rooms.isNotEmpty ? rooms.first : null;
      final availableDays = await _loadAvailableDays(selectedDoctor?.id, selectedRoom?.id);
      final selectedDate = _resolveDate(availableDays);
      final slots = await _loadSlotsForDate(selectedDoctor?.id, selectedRoom?.id, selectedDate);
      final weeklyAppointments = await _loadCalendarAppointments(selectedDoctor?.id);
      final focusedDate = _resolveUpcomingAppointmentDate(selectedDate, weeklyAppointments);

      if (!mounted) return;
      setState(() {
        _doctors = doctors;
        _selectedDoctor = selectedDoctor;
        _patients = patients;
        _selectedPatient = selectedPatient;
        _rooms = rooms;
        _selectedRoom = selectedRoom;
        _availableDays = availableDays;
        _selectedDate = focusedDate;
        _calendarMonth = DateTime(focusedDate.year, focusedDate.month, 1);
        _slots = slots;
        _selectedSlot = slots.isNotEmpty ? slots.first : null;
        _weeklyAppointments = weeklyAppointments;
        _editingAppointment = null;
      });
      _scheduleTimelineJump();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(error, 'No se pudo cargar la agenda por ahora.'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<List<DoctorSummaryData>> _loadDoctorsSafely() async {
    try {
      final doctors = await _agendaService.loadDoctors();
      if (doctors.isNotEmpty || !_isPatientRole) {
        return doctors;
      }
    } catch (_) {}

    if (_isPatientRole) {
      try {
        final publicDoctors = await _contentService.loadPublicDoctors(
          patientId: widget.currentUser.patientId,
        );
        return publicDoctors
            .map(
              (doctor) => DoctorSummaryData(
                id: doctor.id,
                fullName: doctor.fullName,
                licenseNumber: doctor.licenseNumber,
                specialty: doctor.specialty.isEmpty
                    ? (doctor.specialties.isNotEmpty ? doctor.specialties.first : 'MEDICINA GENERAL')
                    : doctor.specialty,
              ),
            )
            .toList();
      } catch (_) {}
    }

    return const [];
  }

  Future<List<PatientSummary>> _loadPatientsForDoctor(int? doctorId) async {
    if (_isPatientRole) {
      final allPatients = await _patientService.loadPatients();
      return allPatients.where((patient) => patient.id == widget.currentUser.patientId).toList();
    }

    if (_isAssistantRole) {
      if (doctorId == null) {
        return _patientService.loadPatients();
      }
      final doctorPatients = await _patientService.loadPatients(doctorId: doctorId);
      if (doctorPatients.isNotEmpty) {
        return doctorPatients;
      }
      return _patientService.loadPatients();
    }

    return _patientService.loadPatients(doctorId: doctorId);
  }

  Future<List<RoomSummaryData>> _loadRoomsForDoctor(int? doctorId) async {
    if (doctorId == null) {
      return _agendaService.loadRooms();
    }

    final doctorRooms = await _agendaService.loadRooms(doctorId: doctorId);
    if (doctorRooms.isNotEmpty || !_isAssistantRole) {
      return doctorRooms;
    }

    return _agendaService.loadRooms();
  }

  Future<List<String>> _loadSlotsForDate(int? doctorId, int? roomId, DateTime date) async {
    if (doctorId == null || roomId == null) return const [];
    try {
      return await _agendaService.loadAvailableSlots(
        doctorId: doctorId,
        roomId: roomId,
        date: DateFormat('yyyy-MM-dd').format(date),
        excludeAppointmentId: _editingAppointment?.id,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<List<DateTime>> _loadAvailableDays(int? doctorId, int? roomId) async {
    if (doctorId == null || roomId == null) return const [];
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final days = <DateTime>[];
    for (var offset = 0; offset < 21 && days.length < 7; offset++) {
      final candidate = start.add(Duration(days: offset));
      final slots = await _loadSlotsForDate(doctorId, roomId, candidate);
      if (slots.isNotEmpty) {
        days.add(candidate);
      }
    }
    return days;
  }

  DateTime _resolveDate(List<DateTime> availableDays) {
    if (availableDays.isEmpty) {
      return _selectedDate;
    }
    final current = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return availableDays.firstWhereOrNull((day) => DateUtils.isSameDay(day, current)) ?? availableDays.first;
  }

  DateTime _resolveFocusedDate(DateTime fallback, List<AppointmentData> appointments) {
    final normalizedFallback = DateTime(fallback.year, fallback.month, fallback.day);
    final matchingCurrent = appointments.firstWhereOrNull((appointment) {
      final date = DateTime.tryParse(appointment.appointmentDate);
      return date != null && DateUtils.isSameDay(date, normalizedFallback);
    });
    if (matchingCurrent != null) {
      return normalizedFallback;
    }

    final appointmentDates = appointments
        .map((appointment) => DateTime.tryParse(appointment.appointmentDate))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toList()
      ..sort((a, b) => a.compareTo(b));

    if (appointmentDates.isEmpty) {
      return normalizedFallback;
    }

    final sameMonthDates = appointmentDates.where((date) {
      return date.year == _calendarMonth.year && date.month == _calendarMonth.month;
    }).toList();

    if (sameMonthDates.isNotEmpty) {
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);
      final upcomingSameMonth = sameMonthDates.where((date) => !date.isBefore(normalizedToday)).toList();
      final focused = upcomingSameMonth.isNotEmpty ? upcomingSameMonth.first : sameMonthDates.first;
      return DateTime(focused.year, focused.month, focused.day);
    }

    final first = appointmentDates.first;
    return DateTime(first.year, first.month, first.day);
  }

  DateTime _resolveUpcomingAppointmentDate(DateTime fallback, List<AppointmentData> appointments) {
    final normalizedFallback = _normalizeDate(fallback);
    final appointmentDates = appointments
        .map((appointment) => DateTime.tryParse(appointment.appointmentDate))
        .whereType<DateTime>()
        .map(_normalizeDate)
        .toSet()
        .toList()
      ..sort((a, b) => a.compareTo(b));

    if (appointmentDates.isEmpty) {
      return normalizedFallback;
    }

    final today = _normalizeDate(DateTime.now());
    final upcoming = appointmentDates.firstWhereOrNull((date) => !date.isBefore(today));
    return upcoming ?? appointmentDates.first;
  }

  DateTime _normalizeDate(DateTime value) => DateTime(value.year, value.month, value.day);

  bool _dateHasAppointments(DateTime value, [List<AppointmentData>? source]) {
    final normalized = _normalizeDate(value);
    final appointments = source ?? _weeklyAppointments;
    return appointments.any((appointment) {
      final date = DateTime.tryParse(appointment.appointmentDate);
      return date != null && DateUtils.isSameDay(_normalizeDate(date), normalized);
    });
  }

  bool _weekHasAppointments(DateTime value, [List<AppointmentData>? source]) {
    final normalized = _normalizeDate(value);
    final weekStart = normalized.subtract(Duration(days: normalized.weekday % 7));
    final appointments = source ?? _weeklyAppointments;
    return List.generate(7, (index) => weekStart.add(Duration(days: index)))
        .any((day) => _dateHasAppointments(day, appointments));
  }

  DateTime _resolveCalendarAnchorForMode(
    DateTime fallback,
    List<AppointmentData> appointments, {
    _AgendaCalendarMode? mode,
  }) {
    final effectiveMode = mode ?? _calendarMode;
    final normalizedFallback = _normalizeDate(fallback);
    final today = _normalizeDate(DateTime.now());
    final fallbackWeekStart = normalizedFallback.subtract(Duration(days: normalizedFallback.weekday % 7));
    final fallbackWeekEnd = fallbackWeekStart.add(const Duration(days: 6));
    if (appointments.isEmpty) return normalizedFallback;

    if (effectiveMode == _AgendaCalendarMode.day &&
        !normalizedFallback.isBefore(today) &&
        _dateHasAppointments(normalizedFallback, appointments)) {
      return normalizedFallback;
    }

    if (effectiveMode == _AgendaCalendarMode.week &&
        !fallbackWeekEnd.isBefore(today) &&
        _weekHasAppointments(normalizedFallback, appointments)) {
      return normalizedFallback;
    }

    return _resolveFocusedDate(normalizedFallback, appointments);
  }

  Future<List<AppointmentData>> _loadCalendarAppointments(int? doctorId) async {
    try {
      final effectiveDoctorId = _isDoctorRole ? (widget.currentUser.doctorId ?? doctorId ?? _selectedDoctor?.id) : doctorId;
      var appointments = await _agendaService.loadAppointments(
        doctorId: effectiveDoctorId,
        patientId: _isPatientRole ? widget.currentUser.patientId : null,
      );

      if (!_isPatientRole && effectiveDoctorId != null && appointments.isEmpty) {
        final fallbackAppointments = await _agendaService.loadAppointments(
          patientId: _isPatientRole ? widget.currentUser.patientId : null,
        );
        appointments = fallbackAppointments.where((appointment) => appointment.doctorId == effectiveDoctorId).toList();
      }

      appointments.sort((a, b) {
        final dateCompare = a.appointmentDate.compareTo(b.appointmentDate);
        if (dateCompare != 0) return dateCompare;
        return a.startTime.compareTo(b.startTime);
      });
      return appointments;
    } catch (_) {
      return const [];
    }
  }

  PatientSummary? _resolvePatient(List<PatientSummary> patients) {
    if (patients.isEmpty) return null;
    if (_isPatientRole && widget.currentUser.patientId != null) {
      return patients.firstWhereOrNull((patient) => patient.id == widget.currentUser.patientId);
    }
    return patients.first;
  }

  Future<void> _onDoctorChanged(DoctorSummaryData? doctor) async {
    setState(() {
      _selectedDoctor = doctor;
      _selectedPatient = null;
      _selectedRoom = null;
      _selectedSlot = null;
      _patients = const [];
      _rooms = const [];
      _slots = const [];
      _availableDays = const [];
      _weeklyAppointments = const [];
      _loading = true;
      _errorMessage = null;
    });

    try {
      final patients = await _loadPatientsForDoctor(doctor?.id);
      final rooms = await _loadRoomsForDoctor(doctor?.id);
      final selectedRoom = rooms.isNotEmpty ? rooms.first : null;
      final availableDays = await _loadAvailableDays(doctor?.id, selectedRoom?.id);
      final selectedDate = _resolveDate(availableDays);
      final slots = await _loadSlotsForDate(doctor?.id, selectedRoom?.id, selectedDate);
      final weeklyAppointments = await _loadCalendarAppointments(doctor?.id);
      final focusedDate = _resolveUpcomingAppointmentDate(selectedDate, weeklyAppointments);

      if (!mounted) return;
      setState(() {
        _patients = patients;
        _selectedPatient = _resolvePatient(patients);
        _rooms = rooms;
        _selectedRoom = selectedRoom;
        _availableDays = availableDays;
        _selectedDate = focusedDate;
        _calendarMonth = DateTime(focusedDate.year, focusedDate.month, 1);
        _slots = slots;
        _selectedSlot = slots.isNotEmpty ? slots.first : null;
        _weeklyAppointments = weeklyAppointments;
      });
      _scheduleTimelineJump();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(error, 'No se pudo actualizar la agenda.'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _onRoomChanged(RoomSummaryData? room) async {
    setState(() {
      _selectedRoom = room;
      _selectedSlot = null;
      _slots = const [];
      _availableDays = const [];
      _loading = true;
      _errorMessage = null;
    });

    try {
      final availableDays = await _loadAvailableDays(_activeDoctorId, room?.id);
      final selectedDate = _resolveDate(availableDays);
      final slots = await _loadSlotsForDate(_activeDoctorId, room?.id, selectedDate);
      if (!mounted) return;
      setState(() {
        _availableDays = availableDays;
        _selectedDate = selectedDate;
        _slots = slots;
        _selectedSlot = slots.isNotEmpty ? slots.first : null;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _onDatePicked() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: const Locale('es', 'MX'),
    );
    if (picked == null) return;
    await _setDateIfAvailable(picked);
  }

  Future<void> _setDateIfAvailable(DateTime date) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final slots = await _loadSlotsForDate(_activeDoctorId, _selectedRoom?.id, date);
      if (!mounted) return;
      if (slots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay disponibilidad en ese dia para el medico y consultorio seleccionados.')),
        );
        return;
      }
      final normalized = DateTime(date.year, date.month, date.day);
      final alreadyListed = _availableDays.any((day) => DateUtils.isSameDay(day, normalized));
      final updatedDays = alreadyListed ? _availableDays : ([..._availableDays, normalized]..sort((a, b) => a.compareTo(b)));
      setState(() {
        _availableDays = updatedDays;
        _selectedDate = normalized;
        _slots = slots;
        _selectedSlot = slots.first;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveAppointment() async {
    final doctor = _selectedDoctor;
    final patient = _selectedPatient;
    final room = _selectedRoom;
    final slot = _selectedSlot;

    if (doctor == null || patient == null || room == null || slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa medico, paciente, sala y hora.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final isEditing = _editingAppointment != null;
      final result = isEditing
          ? await _agendaService.updateAppointment(
              appointmentId: _editingAppointment!.id,
              patientId: patient.id,
              doctorId: doctor.id,
              roomId: room.id,
              appointmentDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
              startTime: slot,
              reason: _reasonController.text.trim().isEmpty ? 'CONTROL GENERAL' : _reasonController.text.trim(),
              assistantUserId: _isAssistantRole ? widget.currentUser.id : null,
            )
          : await _agendaService.createAppointment(
              patientId: patient.id,
              doctorId: doctor.id,
              roomId: room.id,
              appointmentDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
              startTime: slot,
              reason: _reasonController.text.trim().isEmpty ? 'CONTROL GENERAL' : _reasonController.text.trim(),
              assistantUserId: _isAssistantRole ? widget.currentUser.id : null,
            );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alertMessage.isEmpty
                ? (isEditing ? 'La cita se actualizo correctamente.' : 'Cita creada correctamente.')
                : result.alertMessage,
          ),
        ),
      );
      final availableDays = await _loadAvailableDays(doctor.id, room.id);
      final selectedDate = _resolveDate(availableDays);
      final slots = await _loadSlotsForDate(doctor.id, room.id, selectedDate);
      final weeklyAppointments = await _loadCalendarAppointments(_activeDoctorId);
      if (!mounted) return;
      setState(() {
        _availableDays = availableDays;
        _selectedDate = selectedDate;
        _slots = slots;
        _selectedSlot = slots.isNotEmpty ? slots.first : null;
        _weeklyAppointments = weeklyAppointments;
        _editingAppointment = null;
        if (!_isPatientRole) {
          _showBookingForm = false;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyError(
              error,
              _editingAppointment != null ? 'No se pudo actualizar la cita.' : 'No se pudo crear la cita.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _resetEditingMode() {
    setState(() {
      _editingAppointment = null;
    });
  }

  Future<void> _cancelAppointment(AppointmentData appointment) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancelar cita'),
            content: Text(
              'Se cancelara la cita de ${appointment.patientName} del ${_formatAppointmentDate(appointment.appointmentDate)} a las ${appointment.startTime.substring(0, 5)}. Esta accion se reflejara en la agenda y en el chat con el paciente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Volver'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cancelar cita'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _saving = true);
    try {
      final result = await _agendaService.cancelAppointment(
        appointmentId: appointment.id,
        doctorId: appointment.doctorId,
        patientId: appointment.patientId,
        assistantUserId: _isAssistantRole ? widget.currentUser.id : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alertMessage.isEmpty ? 'La cita se cancelo correctamente.' : result.alertMessage,
          ),
        ),
      );

      final doctorId = _activeDoctorId;
      final roomId = _selectedRoom?.id;
      final availableDays = await _loadAvailableDays(doctorId, roomId);
      final selectedDate = _resolveDate(availableDays);
      final slots = await _loadSlotsForDate(doctorId, roomId, selectedDate);
      final weeklyAppointments = await _loadCalendarAppointments(doctorId);

      if (!mounted) return;
      setState(() {
        _availableDays = availableDays;
        _selectedDate = selectedDate;
        _slots = slots;
        _selectedSlot = slots.isNotEmpty ? slots.first : null;
        _weeklyAppointments = weeklyAppointments;
        if (_editingAppointment?.id == appointment.id) {
          _editingAppointment = null;
        }
        if (!_isPatientRole) {
          _showBookingForm = false;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error, 'No se pudo cancelar la cita.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _friendlyError(Object error, String fallback) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) return fallback;
    if (raw.contains('ClientFailed to fetch') || raw.contains('SocketException')) {
      return 'No pudimos conectar con el servidor por ahora.';
    }
    if (raw.contains('respuesta vacia del servidor')) {
      return '$fallback Revisa el endpoint del servidor.';
    }
    return raw;
  }

  String _statusLabel(String value) {
    final normalized = value.toUpperCase();
    switch (normalized) {
      case 'COMPLETED':
        return 'COMPLETA';
      case 'PENDING':
      case 'SCHEDULED':
        return 'PENDIENTE';
      case 'CANCELLED':
        return 'CANCELADA';
      default:
        return value.toUpperCase();
    }
  }

  Color _statusColor(String value) {
    final normalized = _statusLabel(value);
    switch (normalized) {
      case 'COMPLETA':
        return const Color(0xFF15803D);
      case 'CANCELADA':
        return const Color(0xFFB42318);
      case 'PENDIENTE':
      default:
        return const Color(0xFF1D4ED8);
    }
  }

  Color _statusTint(String value) {
    final normalized = _statusLabel(value);
    switch (normalized) {
      case 'COMPLETA':
        return const Color(0xFFD1FAE5);
      case 'CANCELADA':
        return const Color(0xFFFEE4E2);
      case 'PENDIENTE':
      default:
        return const Color(0xFFDBEAFE);
    }
  }

  String _formatAppointmentDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return DateFormat('EEE dd/MM', 'es_MX').format(date);
  }

  String _appointmentDisplayName(AppointmentData appointment) {
    final patientName = appointment.patientName.trim();
    if (patientName.isNotEmpty) {
      return patientName;
    }
    final reason = appointment.reason.trim();
    if (reason.isNotEmpty) {
      return reason;
    }
    return 'PACIENTE';
  }

  DateTime get _monthStart => DateTime(_calendarMonth.year, _calendarMonth.month, 1);

  DateTime get _monthGridStart => _monthStart.subtract(Duration(days: _monthStart.weekday % 7));

  List<DateTime> get _monthGridDays =>
      List.generate(42, (index) => _monthGridStart.add(Duration(days: index)));

  DateTime get _selectedWeekStart {
    final normalized = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return normalized.subtract(Duration(days: normalized.weekday % 7));
  }

  List<DateTime> get _selectedWeekDays =>
      List.generate(7, (index) => _selectedWeekStart.add(Duration(days: index)));

  Future<void> _changeCalendarMonth(int delta) async {
    setState(() {
      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + delta, 1);
      _loading = true;
      _errorMessage = null;
    });

    try {
      final calendarAppointments = await _loadCalendarAppointments(_activeDoctorId);
      final focusedDate = _resolveCalendarAnchorForMode(_selectedDate, calendarAppointments);
      if (!mounted) return;
      setState(() {
        _selectedDate = focusedDate;
        _weeklyAppointments = calendarAppointments;
      });
      _scheduleTimelineJump();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(error, 'No se pudo actualizar el calendario.'));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<AppointmentData> _appointmentsForDay(DateTime day) {
    return _weeklyAppointments.where((appointment) {
      final date = DateTime.tryParse(appointment.appointmentDate);
      return date != null &&
          date.year == day.year &&
          date.month == day.month &&
          date.day == day.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void _scheduleTimelineJump() {
    Future<void> performJump() async {
      if (!_timelineVerticalController.hasClients) return;

      final appointments = _calendarMode == _AgendaCalendarMode.day
          ? _appointmentsForDay(_selectedDate)
          : (_calendarMode == _AgendaCalendarMode.week
              ? [
                  for (final day in _selectedWeekDays) ..._appointmentsForDay(day),
                ]
              : const <AppointmentData>[]);

      if (appointments.isEmpty) {
        _timelineVerticalController.jumpTo(0);
        return;
      }

      const hourHeight = 76.0;
      final startHour = _timelineStartHourFor(appointments);
      final earliestMinutes = appointments
          .map((appointment) => _minutesOfDay(appointment.startTime))
          .reduce((value, element) => value < element ? value : element);
      final topOffset = (((earliestMinutes - (startHour * 60)) / 60) * hourHeight) - 120;
      final safeOffset = topOffset.clamp(0.0, _timelineVerticalController.position.maxScrollExtent).toDouble();
      _timelineVerticalController.jumpTo(safeOffset);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      performJump();
      Future.delayed(const Duration(milliseconds: 180), performJump);
    });
  }

  Future<void> _loadAppointmentIntoForm(AppointmentData appointment) async {
    final doctor = _doctors.firstWhereOrNull((item) => item.id == appointment.doctorId);
    if (doctor == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron los datos del medico para precargar la cita.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _showBookingForm = true;
      _errorMessage = null;
      _editingAppointment = appointment;
    });

    try {
      final patients = await _loadPatientsForDoctor(doctor.id);
      final rooms = await _loadRoomsForDoctor(doctor.id);
      final patient = patients.firstWhereOrNull((item) => item.id == appointment.patientId) ?? _resolvePatient(patients);
      final room = rooms.firstWhereOrNull((item) => item.id == appointment.roomId) ?? (rooms.isNotEmpty ? rooms.first : null);
      final appointmentDate = DateTime.tryParse(appointment.appointmentDate) ?? _selectedDate;
      final availableDays = room == null ? const <DateTime>[] : await _loadAvailableDays(doctor.id, room.id);
      final slots = room == null ? const <String>[] : await _loadSlotsForDate(doctor.id, room.id, appointmentDate);
      final selectedSlot = slots.contains(appointment.startTime.substring(0, 5))
          ? appointment.startTime.substring(0, 5)
          : (slots.isNotEmpty ? slots.first : null);

      if (!mounted) return;
      setState(() {
        _selectedDoctor = doctor;
        _patients = patients;
        _selectedPatient = patient;
        _rooms = rooms;
        _selectedRoom = room;
        _availableDays = availableDays;
        _selectedDate = DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day);
        _slots = slots;
        _selectedSlot = selectedSlot;
        _reasonController.text = appointment.reason;
      });

      if (selectedSlot == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se cargaron los datos, pero ese horario ya no esta libre.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateAppointmentStatus(AppointmentData appointment, String status) async {
    setState(() => _saving = true);
    try {
      final result = await _agendaService.updateAppointmentStatus(
        appointmentId: appointment.id,
        doctorId: appointment.doctorId,
        patientId: appointment.patientId,
        status: status,
        assistantUserId: _isAssistantRole ? widget.currentUser.id : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.alertMessage.isEmpty ? 'La cita se actualizo correctamente.' : result.alertMessage,
          ),
        ),
      );
      final weeklyAppointments = await _loadCalendarAppointments(_activeDoctorId);
      if (!mounted) return;
      setState(() {
        _weeklyAppointments = weeklyAppointments;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error, 'No se pudo actualizar el estatus de la cita.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openAppointmentDetail(AppointmentData appointment) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _appointmentDisplayName(appointment),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text('Medico: ${appointment.doctorName}'),
            Text('Fecha: ${_formatAppointmentDate(appointment.appointmentDate)}'),
            Text('Hora: ${appointment.startTime.substring(0, 5)} - ${appointment.endTime.substring(0, 5)}'),
            Text('Consultorio: ${appointment.roomName}'),
            Text('Estatus: ${_statusLabel(appointment.status)}'),
            const SizedBox(height: 8),
            Text('Motivo: ${appointment.reason}'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _statusLabel(appointment.status) == 'PENDIENTE'
                      ? null
                      : () => Navigator.of(context).pop('pending'),
                  icon: const Icon(Icons.schedule_rounded),
                  label: const Text('Pendiente'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _statusLabel(appointment.status) == 'COMPLETA'
                      ? null
                      : () => Navigator.of(context).pop('completed'),
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('Completa'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop('edit'),
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Editar o reprogramar'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop('reuse'),
              icon: const Icon(Icons.content_copy_rounded),
              label: const Text('Usar como base para nueva cita'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop('cancel'),
              icon: const Icon(Icons.event_busy_rounded),
              label: const Text('Cancelar cita'),
            ),
          ],
        ),
      ),
    );

    if (action == 'edit' || action == 'reuse') {
      await _loadAppointmentIntoForm(appointment);
      if (action == 'reuse' && mounted) {
        setState(() => _editingAppointment = null);
      }
    } else if (action == 'pending') {
      await _updateAppointmentStatus(appointment, 'PENDING');
    } else if (action == 'completed') {
      await _updateAppointmentStatus(appointment, 'COMPLETED');
    } else if (action == 'cancel') {
      await _cancelAppointment(appointment);
    }
  }

  Widget _buildCalendarView() {
    final labels = const ['Domingo', 'Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado'];

    return ListView(
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
                'Agenda mensual',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Visualiza tus citas del mes y crea nuevas desde aqui.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              SegmentedButton<_AgendaCalendarMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _AgendaCalendarMode.month, label: Text('Mes')),
                  ButtonSegment(value: _AgendaCalendarMode.week, label: Text('Semana')),
                  ButtonSegment(value: _AgendaCalendarMode.day, label: Text('Dia')),
                ],
                selected: {_calendarMode},
                onSelectionChanged: (selection) {
                  final nextMode = selection.first;
                  final nextDate = _resolveCalendarAnchorForMode(
                    _selectedDate,
                    _weeklyAppointments,
                    mode: nextMode,
                  );
                  setState(() {
                    _calendarMode = nextMode;
                    _selectedDate = nextDate;
                  });
                  _scheduleTimelineJump();
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => _changeCalendarMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy', 'es_MX').format(_calendarMonth).toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _changeCalendarMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => setState(() => _showBookingForm = true),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuevo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _bootstrap,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
        ],
        if (_calendarMode == _AgendaCalendarMode.month)
          _buildMonthGrid(labels)
        else if (_calendarMode == _AgendaCalendarMode.week)
          _buildWeekGrid(labels)
        else
          _buildDayAgenda(),
      ],
    );
  }

  Widget _buildMonthGrid(List<String> labels) {
    final monthDays = _monthGridDays;
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: List.generate(
                7,
                (index) => Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: monthDays.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: constraints.maxWidth < 500 ? 0.55 : 0.82,
              ),
              itemBuilder: (context, index) {
                final day = monthDays[index];
                return _buildCalendarCell(
                  day: day,
                  isCurrentMonth: day.month == _calendarMonth.month,
                  compact: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekGrid(List<String> labels) {
    final weekDays = _selectedWeekDays;
    return _buildTimelineGrid(
      days: weekDays,
      dayNameBuilder: (day) => labels[day.weekday % 7],
      showMonthBadge: false,
    );
  }

  Widget _buildDayAgenda() {
    return _buildTimelineGrid(
      days: [_selectedDate],
      dayNameBuilder: (day) => DateFormat('EEE', 'es_MX').format(day),
      showMonthBadge: true,
    );
  }

  Widget _buildTimelineGrid({
    required List<DateTime> days,
    required String Function(DateTime day) dayNameBuilder,
    required bool showMonthBadge,
  }) {
    final allAppointments = [
      for (final day in days) ..._appointmentsForDay(day),
    ];
    final startHour = _timelineStartHourFor(allAppointments);
    final endHour = _timelineEndHourFor(allAppointments);
    const hourHeight = 76.0;
    const timeColumnWidth = 64.0;
    final dayColumnWidth = days.length == 1 ? 300.0 : 146.0;
    final contentHeight = (endHour - startHour) * hourHeight;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: timeColumnWidth + (dayColumnWidth * days.length),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: timeColumnWidth),
                  for (final day in days)
                    SizedBox(
                      width: dayColumnWidth,
                      child: InkWell(
                        onTap: () => setState(() => _selectedDate = day),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                          decoration: BoxDecoration(
                            color: DateUtils.isSameDay(day, _selectedDate)
                                ? const Color(0x1A60A5FA)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: DateUtils.isSameDay(day, _selectedDate)
                                  ? const Color(0xFF60A5FA)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd', 'es_MX').format(day),
                                style: TextStyle(
                                  color: DateUtils.isSameDay(day, _selectedDate)
                                      ? const Color(0xFFA5C8FF)
                                      : const Color(0xFF818CF8),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                dayNameBuilder(day),
                                style: TextStyle(
                                  color: DateUtils.isSameDay(day, _selectedDate)
                                      ? const Color(0xFFA5C8FF)
                                      : const Color(0xFF818CF8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_appointmentsForDay(day).isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF60A5FA).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.35)),
                                  ),
                                  child: Text(
                                    '${_appointmentsForDay(day).length} cita${_appointmentsForDay(day).length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      color: Color(0xFFA5C8FF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              if (showMonthBadge)
                                Text(
                                  DateFormat('MMMM', 'es_MX').format(day),
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 620,
                child: SingleChildScrollView(
                  controller: _timelineVerticalController,
                  child: SizedBox(
                    height: contentHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: timeColumnWidth,
                          child: Stack(
                            children: [
                              for (var hour = startHour; hour < endHour; hour++)
                                Positioned(
                                  top: (hour - startHour) * hourHeight - 8,
                                  left: 0,
                                  right: 8,
                                  child: Text(
                                    _formatTimelineHour(hour),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (final day in days) _buildTimelineDayColumn(day, startHour, endHour, hourHeight, dayColumnWidth),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineDayColumn(
    DateTime day,
    int startHour,
    int endHour,
    double hourHeight,
    double columnWidth,
  ) {
    final appointments = _appointmentsForDay(day);
    final contentHeight = (endHour - startHour) * hourHeight;

    return SizedBox(
      width: columnWidth,
      child: Stack(
        children: [
          for (var hour = startHour; hour < endHour; hour++)
            Positioned(
              top: (hour - startHour) * hourHeight,
              left: 0,
              right: 0,
              child: Container(
                height: hourHeight,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white12),
                    left: BorderSide(color: Colors.white10),
                  ),
                ),
              ),
            ),
          for (var half = 0; half < ((endHour - startHour) * 2); half++)
            if (half.isOdd)
              Positioned(
                top: (half * (hourHeight / 2)),
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 1),
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
          for (final appointment in appointments)
            _buildTimelineAppointmentCard(
              appointment: appointment,
              startHour: startHour,
              hourHeight: hourHeight,
              columnWidth: columnWidth,
              contentHeight: contentHeight,
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineAppointmentCard({
    required AppointmentData appointment,
    required int startHour,
    required double hourHeight,
    required double columnWidth,
    required double contentHeight,
  }) {
    final startMinutes = _minutesOfDay(appointment.startTime);
    final endMinutes = _minutesOfDay(appointment.endTime);
    final top = ((startMinutes - (startHour * 60)) / 60) * hourHeight;
    final durationMinutes = (endMinutes - startMinutes).clamp(30, 240);
    final height = (durationMinutes / 60) * hourHeight;
    final safeTop = top.clamp(0.0, contentHeight - 32).toDouble();
    final safeHeight = height.clamp(42.0, contentHeight - safeTop).toDouble();

    return Positioned(
      top: safeTop,
      left: 6,
      right: 10,
      child: InkWell(
        onTap: () => _openAppointmentDetail(appointment),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: safeHeight,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: _statusColor(appointment.status).withOpacity(0.86),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFA5C8FF).withOpacity(0.65),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  appointment.startTime.substring(0, 5),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _appointmentDisplayName(appointment),
                maxLines: safeHeight < 70 ? 1 : 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.08,
                ),
              ),
              if (safeHeight >= 72) ...[
                const SizedBox(height: 4),
                Text(
                  '${appointment.startTime.substring(0, 5)} - ${appointment.endTime.substring(0, 5)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
              if (safeHeight >= 92) ...[
                const SizedBox(height: 2),
                Text(
                  appointment.roomName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarCell({
    required DateTime day,
    required bool isCurrentMonth,
    required bool compact,
  }) {
    final appointments = _appointmentsForDay(day);
    final isToday = DateUtils.isSameDay(day, DateTime.now());
    final isSelected = DateUtils.isSameDay(day, _selectedDate);
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = day;
          if (compact) {
            _calendarMode = _AgendaCalendarMode.day;
          }
        });
        _scheduleTimelineJump();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCurrentMonth ? const Color(0xFF1F2937) : const Color(0xFF161E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF60A5FA)
                : (isToday ? const Color(0xFF60A5FA) : Colors.white10),
            width: isSelected || isToday ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd').format(day),
              style: TextStyle(
                color: isToday
                    ? const Color(0xFF60A5FA)
                    : (isCurrentMonth ? Colors.white : Colors.white38),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: appointments.isEmpty
                  ? const SizedBox.shrink()
                  : compact
                      ? _buildCompactAppointmentPreview(appointments)
                      : ListView.separated(
                          itemCount: appointments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, appointmentIndex) {
                            final appointment = appointments[appointmentIndex];
                            return InkWell(
                              onTap: () => _openAppointmentDetail(appointment),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _statusColor(appointment.status),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${appointment.startTime.substring(0, 5)} ${_appointmentDisplayName(appointment)}',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAppointmentPreview(List<AppointmentData> appointments) {
    final visibleAppointments = appointments.take(2).toList();
    final remaining = appointments.length - visibleAppointments.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final appointment in visibleAppointments) ...[
          InkWell(
            onTap: () => _openAppointmentDetail(appointment),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor(appointment.status),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${appointment.startTime.substring(0, 5)} ${_appointmentDisplayName(appointment)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (appointment != visibleAppointments.last) const SizedBox(height: 6),
        ],
        if (remaining > 0) ...[
          const SizedBox(height: 6),
          Text(
            '+$remaining cita(s) mas',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  int _minutesOfDay(String timeValue) {
    final clean = timeValue.trim();
    final parts = clean.split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return (hour * 60) + minute;
  }

  int _timelineStartHourFor(List<AppointmentData> appointments) => 6;

  int _timelineEndHourFor(List<AppointmentData> appointments) => 23;

  String _formatTimelineHour(int hour) {
    final normalized = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final suffix = hour >= 12 ? 'PM' : 'AM';
    return '$normalized $suffix';
  }

  Widget _buildBookingFormView() {
    final dateLabel = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final showWeeklyAgenda = _isDoctorRole || _isAssistantRole;

    return ListView(
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
                _editingAppointment != null
                    ? 'Reprogramar cita'
                    : (_isPatientRole ? 'Programar cita' : 'Gestion de agenda'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _editingAppointment != null
                    ? 'Ajusta fecha, consultorio u horario y guarda los cambios.'
                    : (_isPatientRole
                        ? 'Selecciona medico, sala y horario disponible.'
                        : 'Asigna citas con disponibilidad real por medico y consultorio.'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              if (!_isPatientRole) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showBookingForm = false),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text('Ver agenda'),
                    ),
                    if (_editingAppointment != null)
                      TextButton.icon(
                        onPressed: _saving ? null : _resetEditingMode,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancelar edicion'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Text(_errorMessage!, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
        ],
        if (!_isDoctorRole) ...[
          DropdownButtonFormField<DoctorSummaryData>(
            initialValue: _selectedDoctor,
            decoration: const InputDecoration(labelText: 'Medico'),
            items: _doctors.map((doctor) => DropdownMenuItem(value: doctor, child: Text('${doctor.fullName} | ${doctor.specialty}'))).toList(),
            onChanged: _loading ? null : _onDoctorChanged,
          ),
          const SizedBox(height: 14),
        ] else if (_selectedDoctor != null) ...[
          _LockedField(label: 'Medico', value: _selectedDoctor!.fullName),
          const SizedBox(height: 14),
        ],
        if (!_isPatientRole) ...[
          DropdownButtonFormField<PatientSummary>(
            initialValue: _selectedPatient,
            decoration: const InputDecoration(labelText: 'Paciente'),
            items: _patients.map((patient) => DropdownMenuItem(value: patient, child: Text(patient.fullName))).toList(),
            onChanged: _loading ? null : (value) => setState(() => _selectedPatient = value),
          ),
          const SizedBox(height: 14),
        ] else if (_selectedPatient != null) ...[
          _LockedField(label: 'Paciente', value: _selectedPatient!.fullName),
          const SizedBox(height: 14),
        ],
        DropdownButtonFormField<RoomSummaryData>(
          initialValue: _selectedRoom,
          decoration: const InputDecoration(labelText: 'Sala o consultorio'),
          items: _rooms.map((room) => DropdownMenuItem(value: room, child: Text('${room.name} | ${room.roomType}'))).toList(),
          onChanged: _loading ? null : _onRoomChanged,
        ),
        const SizedBox(height: 14),
        if (_availableDays.isNotEmpty) ...[
          Text('Selecciona el dia', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _availableDays.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == _availableDays.length) {
                  return OutlinedButton.icon(
                    onPressed: _loading ? null : _onDatePicked,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('Otro dia'),
                  );
                }
                final day = _availableDays[index];
                final selected = DateUtils.isSameDay(day, _selectedDate);
                return ChoiceChip(
                  label: Text(DateFormat('dd/MM').format(day)),
                  selected: selected,
                  onSelected: _loading ? null : (_) => _setDateIfAvailable(day),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _LockedField(label: 'Fecha seleccionada', value: dateLabel),
        ] else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Sin dias disponibles', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text('No encontramos dias con horario libre para el medico y consultorio seleccionados.'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _reasonController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
        const SizedBox(height: 18),
        Text('Horarios disponibles', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        else if (_slots.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Sin horarios disponibles', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text('No hay espacios libres para ese medico y consultorio en la fecha elegida.'),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _slots.map((slot) => ChoiceChip(label: Text(slot), selected: _selectedSlot == slot, onSelected: (_) => setState(() => _selectedSlot = slot))).toList(),
          ),
        const SizedBox(height: 14),
        _LockedField(label: 'Hora seleccionada', value: _selectedSlot ?? 'Selecciona un horario disponible'),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _saving || _slots.isEmpty ? null : _saveAppointment,
          icon: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.event_available_rounded),
          label: Text(
            _saving
                ? 'Guardando...'
                : (_editingAppointment != null ? 'Guardar cambios' : 'Confirmar cita'),
          ),
        ),
        if (showWeeklyAgenda) ...[
          const SizedBox(height: 28),
          Text('Agenda semanal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (_weeklyAppointments.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Sin citas esta semana', style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    Text('Cuando se registren citas para esta semana apareceran aqui.'),
                  ],
                ),
              ),
            )
          else
            ..._weeklyAppointments.map(
              (appointment) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => _openAppointmentDetail(appointment),
                  leading: CircleAvatar(
                    backgroundColor: _statusTint(appointment.status),
                    child: Icon(
                      Icons.event_note_rounded,
                      color: _statusColor(appointment.status),
                    ),
                  ),
                  title: Text('${_formatAppointmentDate(appointment.appointmentDate)} | ${appointment.startTime.substring(0, 5)}'),
                  subtitle: Text(
                    '${_appointmentDisplayName(appointment)} | ${appointment.roomName}\n${_statusLabel(appointment.status)} | ${appointment.reason}',
                  ),
                  isThreeLine: true,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusTint(appointment.status),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(appointment.status),
                      style: TextStyle(
                        color: _statusColor(appointment.status),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isPatientRole ? 'Citas' : 'Agenda'),
        actions: !_isPatientRole
            ? [
                TextButton.icon(
                  onPressed: () => setState(() => _showBookingForm = !_showBookingForm),
                  icon: Icon(_showBookingForm ? Icons.calendar_view_week_rounded : Icons.add_rounded),
                  label: Text(_showBookingForm ? 'Agenda' : 'Nuevo'),
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: _loading && _doctors.isEmpty && _patients.isEmpty && _rooms.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : (_isPatientRole || _showBookingForm) ? _buildBookingFormView() : _buildCalendarView(),
    );
  }
}

class _LockedField extends StatelessWidget {
  const _LockedField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value),
    );
  }
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
