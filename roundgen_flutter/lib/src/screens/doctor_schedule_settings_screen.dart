import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../models/doctor_schedule_data.dart';
import '../models/doctor_summary_data.dart';
import '../models/room_summary_data.dart';
import '../models/role_type.dart';
import '../services/agenda_service.dart';

class DoctorScheduleSettingsScreen extends StatefulWidget {
  const DoctorScheduleSettingsScreen({
    super.key,
    required this.currentUser,
  });

  final AuthUser currentUser;

  @override
  State<DoctorScheduleSettingsScreen> createState() => _DoctorScheduleSettingsScreenState();
}

class _DoctorScheduleSettingsScreenState extends State<DoctorScheduleSettingsScreen> {
  final AgendaService _agendaService = AgendaService();
  final TextEditingController _slotMinutesController = TextEditingController(text: '30');

  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  List<DoctorSummaryData> _doctors = const [];
  List<RoomSummaryData> _rooms = const [];
  List<DoctorScheduleData> _schedules = const [];

  DoctorSummaryData? _selectedDoctor;
  RoomSummaryData? _selectedRoom;
  DoctorScheduleData? _editingSchedule;
  int _selectedDay = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  bool get _isDoctorSelfService => widget.currentUser.role == RoleType.doctor && widget.currentUser.doctorId != null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _slotMinutesController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final doctors = await _agendaService.loadDoctors();
      DoctorSummaryData? selectedDoctor;
      if (_isDoctorSelfService) {
        for (final doctor in doctors) {
          if (doctor.id == widget.currentUser.doctorId) {
            selectedDoctor = doctor;
            break;
          }
        }
      } else {
        selectedDoctor = doctors.isNotEmpty ? doctors.first : null;
      }
      final rooms = await _agendaService.loadRooms(doctorId: selectedDoctor?.id);
      final fallbackRooms = rooms.isEmpty ? await _agendaService.loadRooms() : rooms;
      final schedules = selectedDoctor == null ? const <DoctorScheduleData>[] : await _agendaService.loadDoctorSchedules(selectedDoctor.id);

      if (!mounted) return;
      setState(() {
        _doctors = doctors;
        _selectedDoctor = selectedDoctor;
        _rooms = fallbackRooms;
        _selectedRoom = fallbackRooms.isNotEmpty ? fallbackRooms.first : null;
        _schedules = schedules;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString().replaceFirst('Exception: ', ''));
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _onDoctorChanged(DoctorSummaryData? doctor) async {
    setState(() {
      _selectedDoctor = doctor;
      _selectedRoom = null;
      _rooms = const [];
      _schedules = const [];
      _loading = true;
      _errorMessage = null;
    });

    try {
      final rooms = await _agendaService.loadRooms(doctorId: doctor?.id);
      final fallbackRooms = rooms.isEmpty ? await _agendaService.loadRooms() : rooms;
      final schedules = doctor == null ? const <DoctorScheduleData>[] : await _agendaService.loadDoctorSchedules(doctor.id);
      if (!mounted) return;
      setState(() {
        _rooms = fallbackRooms;
        _selectedRoom = fallbackRooms.isNotEmpty ? fallbackRooms.first : null;
        _schedules = schedules;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString().replaceFirst('Exception: ', ''));
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _save() async {
    final doctor = _selectedDoctor;
    final room = _selectedRoom;
    final slotMinutes = int.tryParse(_slotMinutesController.text.trim()) ?? 0;

    if (doctor == null || room == null || slotMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona medico, sala y duracion valida.')),
      );
      return;
    }

    final startTotal = _startTime.hour * 60 + _startTime.minute;
    final endTotal = _endTime.hour * 60 + _endTime.minute;
    if (endTotal <= startTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La hora final debe ser mayor que la inicial.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final isEditing = _editingSchedule != null;
      if (!isEditing) {
        await _agendaService.saveDoctorSchedule(
          doctorId: doctor.id,
          roomId: room.id,
          dayOfWeek: _selectedDay,
          startTime: _formatTime(_startTime),
          endTime: _formatTime(_endTime),
          slotMinutes: slotMinutes,
          assistantUserId: widget.currentUser.role == RoleType.assistant ? widget.currentUser.id : null,
        );
      } else {
        await _agendaService.updateDoctorSchedule(
          scheduleId: _editingSchedule!.id,
          doctorId: doctor.id,
          roomId: room.id,
          dayOfWeek: _selectedDay,
          startTime: _formatTime(_startTime),
          endTime: _formatTime(_endTime),
          slotMinutes: slotMinutes,
          assistantUserId: widget.currentUser.role == RoleType.assistant ? widget.currentUser.id : null,
        );
      }
      final schedules = await _agendaService.loadDoctorSchedules(doctor.id);
      if (!mounted) return;
      setState(() {
        _schedules = schedules;
        _editingSchedule = null;
        _selectedDay = 1;
        _startTime = const TimeOfDay(hour: 9, minute: 0);
        _endTime = const TimeOfDay(hour: 17, minute: 0);
        _slotMinutesController.text = '30';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? 'Horario medico actualizado correctamente.' : 'Horario medico guardado correctamente.')),
      );
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

  Future<void> _reloadSchedules() async {
    final doctor = _selectedDoctor;
    if (doctor == null) return;
    final schedules = await _agendaService.loadDoctorSchedules(doctor.id);
    if (!mounted) return;
    setState(() => _schedules = schedules);
  }

  void _startEditing(DoctorScheduleData schedule) {
    final room = _rooms.firstWhere(
      (item) => item.id == schedule.roomId,
      orElse: () => RoomSummaryData(
        id: schedule.roomId,
        name: schedule.roomName,
        roomType: 'CONSULTORIO',
        location: '',
        isActive: true,
      ),
    );
    if (_rooms.every((item) => item.id != room.id)) {
      _rooms = [..._rooms, room];
    }
    setState(() {
      _editingSchedule = schedule;
      _selectedRoom = room;
      _selectedDay = schedule.dayOfWeek;
      _startTime = _parseTime(schedule.startTime);
      _endTime = _parseTime(schedule.endTime);
      _slotMinutesController.text = '${schedule.slotMinutes}';
    });
  }

  void _resetEditor() {
    setState(() {
      _editingSchedule = null;
      _selectedDay = 1;
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 17, minute: 0);
      _slotMinutesController.text = '30';
      if (_rooms.isNotEmpty) {
        _selectedRoom = _rooms.first;
      }
    });
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  Future<void> _deleteSchedule(DoctorScheduleData schedule) async {
    final doctor = _selectedDoctor;
    if (doctor == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Borrar horario'),
            content: Text(
              'Se borrara el bloque ${_dayLabel(schedule.dayOfWeek)} ${schedule.startTime}-${schedule.endTime} en ${schedule.roomName}.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Borrar')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      await _agendaService.deleteDoctorSchedule(
        scheduleId: schedule.id,
        doctorId: doctor.id,
        assistantUserId: widget.currentUser.role == RoleType.assistant ? widget.currentUser.id : null,
      );
      await _reloadSchedules();
      if (_editingSchedule?.id == schedule.id) {
        _resetEditor();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horario borrado correctamente.')),
      );
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

  String _formatTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _dayLabel(int day) {
    switch (day) {
      case 1:
        return 'Lunes';
      case 2:
        return 'Martes';
      case 3:
        return 'Miercoles';
      case 4:
        return 'Jueves';
      case 5:
        return 'Viernes';
      case 6:
        return 'Sabado';
      case 7:
        return 'Domingo';
      default:
        return 'Dia $day';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar horarios medicos')),
      body: _loading && _doctors.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_errorMessage != null) ...[
                  Text(_errorMessage!, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<DoctorSummaryData>(
                  initialValue: _selectedDoctor,
                  decoration: const InputDecoration(labelText: 'Medico'),
                  items: _doctors
                      .map((doctor) => DropdownMenuItem(value: doctor, child: Text('${doctor.fullName} | ${doctor.specialty}')))
                      .toList(),
                  onChanged: _loading || _isDoctorSelfService ? null : _onDoctorChanged,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<RoomSummaryData>(
                  initialValue: _selectedRoom,
                  decoration: const InputDecoration(labelText: 'Sala o consultorio'),
                  items: _rooms
                      .map((room) => DropdownMenuItem(value: room, child: Text('${room.name} | ${room.roomType}')))
                      .toList(),
                  onChanged: _loading ? null : (value) => setState(() => _selectedRoom = value),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _selectedDay,
                  decoration: const InputDecoration(labelText: 'Dia de la semana'),
                  items: List.generate(7, (index) => index + 1)
                      .map((day) => DropdownMenuItem(value: day, child: Text(_dayLabel(day))))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedDay = value ?? 1),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickTime(isStart: true),
                        icon: const Icon(Icons.access_time_rounded),
                        label: Text('Inicio ${_formatTime(_startTime)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickTime(isStart: false),
                        icon: const Icon(Icons.access_time_filled_rounded),
                        label: Text('Fin ${_formatTime(_endTime)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _slotMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duracion por cita (minutos)'),
                ),
                const SizedBox(height: 18),
                if (_editingSchedule != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Estas editando un horario existente.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(onPressed: _saving ? null : _resetEditor, child: const Text('Cancelar'))
                      ],
                    ),
                  ),
                ],
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _saving
                        ? 'Guardando...'
                        : _editingSchedule == null
                            ? 'Guardar horario'
                            : 'Actualizar horario',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Horarios actuales',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (_schedules.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Aun no hay horarios guardados para este medico.'),
                    ),
                  )
                else
                  ..._schedules.map(
                    (schedule) => Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text('${_dayLabel(schedule.dayOfWeek)} | ${schedule.roomName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('${schedule.startTime} - ${schedule.endTime} | ${schedule.slotMinutes} min'),
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'Editar',
                              onPressed: _saving ? null : () => _startEditing(schedule),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              tooltip: 'Borrar',
                              onPressed: _saving ? null : () => _deleteSchedule(schedule),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
