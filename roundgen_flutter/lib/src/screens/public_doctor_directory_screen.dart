import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../models/auth_user.dart';
import '../models/doctor_review_data.dart';
import '../models/public_doctor_profile_data.dart';
import '../models/role_type.dart';
import '../models/room_summary_data.dart';
import '../services/agenda_service.dart';
import '../services/content_service.dart';

class PublicDoctorDirectoryScreen extends StatefulWidget {
  const PublicDoctorDirectoryScreen({
    super.key,
    required this.currentUser,
  });

  final AuthUser currentUser;

  @override
  State<PublicDoctorDirectoryScreen> createState() => _PublicDoctorDirectoryScreenState();
}

class _PublicDoctorDirectoryScreenState extends State<PublicDoctorDirectoryScreen> {
  final ContentService _contentService = ContentService();
  final AgendaService _agendaService = AgendaService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  late Future<List<PublicDoctorProfileData>> _future;
  String _search = '';
  String _specialty = '';
  String _city = '';
  String _consultationMode = '';
  bool _favoritesOnly = false;
  final Map<int, Future<String>> _nextAvailabilityCache = {};
  final Map<int, Future<List<String>>> _weeklyAvailabilityCache = {};

  bool get _canReview => widget.currentUser.role == RoleType.patient && widget.currentUser.patientId != null;
  bool get _canBook => widget.currentUser.role == RoleType.patient && widget.currentUser.patientId != null;

  @override
  void initState() {
    super.initState();
    _future = _loadDoctors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _specialtyController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<List<PublicDoctorProfileData>> _loadDoctors() {
    return _contentService.loadPublicDoctors(
      search: _search,
      specialty: _specialty,
      city: _city,
      consultationMode: _consultationMode,
      patientId: widget.currentUser.patientId,
    );
  }

  Future<void> _refresh() async {
    final future = _loadDoctors();
    setState(() {
      _future = future;
      _nextAvailabilityCache.clear();
      _weeklyAvailabilityCache.clear();
    });
    await future;
  }

  Future<void> _toggleFavorite(PublicDoctorProfileData doctor) async {
    final patientId = widget.currentUser.patientId;
    if (patientId == null) return;
    final nextValue = !doctor.isFavorite;
    try {
      await _contentService.toggleFavoriteDoctor(
        doctorId: doctor.id,
        patientId: patientId,
        isFavorite: nextValue,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(nextValue ? 'Medico guardado en favoritos.' : 'Medico quitado de favoritos.')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error, 'No se pudo actualizar el favorito.'))),
      );
    }
  }

  void _applyFilters() {
    setState(() {
      _search = _searchController.text.trim();
      _specialty = _specialtyController.text.trim();
      _city = _cityController.text.trim();
      _future = _loadDoctors();
      _nextAvailabilityCache.clear();
      _weeklyAvailabilityCache.clear();
    });
  }

  Future<List<DateTime>> _loadBookableDays(int doctorId, int roomId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final days = <DateTime>[];
    for (var offset = 0; offset < 30 && days.length < 10; offset++) {
      final candidate = start.add(Duration(days: offset));
      final slots = await _agendaService.loadAvailableSlots(
        doctorId: doctorId,
        roomId: roomId,
        date: DateFormat('yyyy-MM-dd').format(candidate),
      );
      if (slots.isNotEmpty) {
        days.add(candidate);
      }
    }
    return days;
  }

  Future<String> _loadNextAvailability(PublicDoctorProfileData doctor) async {
    try {
      final rooms = await _agendaService.loadRooms(doctorId: doctor.id);
      if (rooms.isEmpty) {
        return 'Sin disponibilidad publicada';
      }

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      DateTime? bestDateTime;
      RoomSummaryData? bestRoom;

      for (final room in rooms) {
        for (var offset = 0; offset < 30; offset++) {
          final candidate = start.add(Duration(days: offset));
          final slots = await _agendaService.loadAvailableSlots(
            doctorId: doctor.id,
            roomId: room.id,
            date: DateFormat('yyyy-MM-dd').format(candidate),
          );
          if (slots.isEmpty) {
            continue;
          }

          final firstSlot = slots.first;
          final slotDateTime = DateTime(
            candidate.year,
            candidate.month,
            candidate.day,
            int.tryParse(firstSlot.split(':').first) ?? 0,
            int.tryParse(firstSlot.split(':').last) ?? 0,
          );

          if (bestDateTime == null || slotDateTime.isBefore(bestDateTime)) {
            bestDateTime = slotDateTime;
            bestRoom = room;
          }
          break;
        }
      }

      if (bestDateTime == null || bestRoom == null) {
        return 'Sin disponibilidad publicada';
      }

      return '${DateFormat('EEE dd/MM', 'es_MX').format(bestDateTime)} | ${DateFormat('HH:mm').format(bestDateTime)} | ${bestRoom.name}';
    } catch (_) {
      return 'Disponibilidad por confirmar';
    }
  }

  Future<String> _nextAvailabilityFor(PublicDoctorProfileData doctor) {
    return _nextAvailabilityCache.putIfAbsent(doctor.id, () => _loadNextAvailability(doctor));
  }

  Future<List<String>> _loadWeeklyAvailability(PublicDoctorProfileData doctor) async {
    try {
      final rooms = await _agendaService.loadRooms(doctorId: doctor.id);
      if (rooms.isEmpty) {
        return const [];
      }

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final items = <String>[];

      for (var offset = 0; offset < 7; offset++) {
        final candidate = start.add(Duration(days: offset));
        DateTime? bestDateTime;
        RoomSummaryData? bestRoom;

        for (final room in rooms) {
          final slots = await _agendaService.loadAvailableSlots(
            doctorId: doctor.id,
            roomId: room.id,
            date: DateFormat('yyyy-MM-dd').format(candidate),
          );
          if (slots.isEmpty) {
            continue;
          }

          final firstSlot = slots.first;
          final slotDateTime = DateTime(
            candidate.year,
            candidate.month,
            candidate.day,
            int.tryParse(firstSlot.split(':').first) ?? 0,
            int.tryParse(firstSlot.split(':').last) ?? 0,
          );

          if (bestDateTime == null || slotDateTime.isBefore(bestDateTime)) {
            bestDateTime = slotDateTime;
            bestRoom = room;
          }
        }

        if (bestDateTime != null && bestRoom != null) {
          items.add(
            '${DateFormat('EEE dd/MM', 'es_MX').format(bestDateTime)} | ${DateFormat('HH:mm').format(bestDateTime)} | ${bestRoom.name}',
          );
        }
      }

      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> _weeklyAvailabilityFor(PublicDoctorProfileData doctor) {
    return _weeklyAvailabilityCache.putIfAbsent(doctor.id, () => _loadWeeklyAvailability(doctor));
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

  Future<void> _shareDoctorProfile(PublicDoctorProfileData doctor) async {
    final shareUrl = AppConfig.doctorPublicProfileUrl(doctor.id);
    final specialties = (doctor.specialties.isEmpty ? [doctor.specialty] : doctor.specialties).join(', ');
    final message = StringBuffer()
      ..writeln('Te comparto el perfil medico de ${doctor.fullName} en ${AppConfig.appName}.')
      ..writeln()
      ..writeln('Especialidades: $specialties')
      ..writeln('Modalidad: ${doctor.consultationMode}')
      ..writeln('Ubicacion: ${doctor.locationLabel}')
      ..writeln()
      ..writeln('Ver perfil: $shareUrl');

    await Share.share(
      message.toString(),
      subject: 'Perfil medico de ${doctor.fullName}',
    );
  }

  Future<void> _openDoctorDetail(PublicDoctorProfileData doctor) async {
    final reviews = await _contentService.loadDoctorReviews(doctor.id);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFFD8E4FF),
                      backgroundImage: doctor.profileImageUrl.trim().isNotEmpty ? NetworkImage(doctor.profileImageUrl.trim()) : null,
                      child: doctor.profileImageUrl.trim().isEmpty
                          ? Text(
                              doctor.fullName.isEmpty ? 'M' : doctor.fullName.characters.first.toUpperCase(),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doctor.fullName, style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text((doctor.specialties.isEmpty ? [doctor.specialty] : doctor.specialties).join(' | ')),
                          const SizedBox(height: 6),
                          _RatingRow(rating: doctor.averageRating, reviewCount: doctor.reviewCount),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Ubicacion: ${doctor.locationLabel}'),
                const SizedBox(height: 6),
                Text('Modalidad: ${doctor.consultationMode}'),
                if (doctor.publicBio.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(doctor.publicBio),
                ],
                const SizedBox(height: 12),
                if (doctor.consultationFeePresential > 0) Text('Presencial: \$${doctor.consultationFeePresential.toStringAsFixed(2)}'),
                if (doctor.consultationFeeVideo > 0) Text('Videollamada: \$${doctor.consultationFeeVideo.toStringAsFixed(2)}'),
                if (doctor.consultationFee <= 0 && doctor.consultationFeePresential <= 0 && doctor.consultationFeeVideo <= 0)
                  const Text('Costo por definir'),
                const SizedBox(height: 12),
                FutureBuilder<List<String>>(
                  future: _weeklyAvailabilityFor(doctor),
                  builder: (context, weeklySnapshot) {
                    final items = weeklySnapshot.data ?? const <String>[];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Disponibilidad de la semana', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            if (weeklySnapshot.connectionState == ConnectionState.waiting)
                              const Text('Consultando horarios...')
                            else if (items.isEmpty)
                              const Text('No hay horarios visibles para los proximos 7 dias.')
                            else
                              ...items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(item),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Resenas', style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton.filledTonal(
                      onPressed: () => _shareDoctorProfile(doctor),
                      icon: const Icon(Icons.share_rounded),
                      tooltip: 'Compartir perfil',
                    ),
                    const SizedBox(width: 8),
                    if (widget.currentUser.role == RoleType.patient)
                      IconButton.filledTonal(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _toggleFavorite(doctor);
                        },
                        icon: Icon(doctor.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                        tooltip: doctor.isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos',
                      ),
                    if (widget.currentUser.role == RoleType.patient && (_canBook || _canReview)) const SizedBox(width: 8),
                    if (_canBook)
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _openBookingComposer(doctor);
                        },
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: const Text('Reservar cita'),
                      ),
                    if (_canBook && _canReview) const SizedBox(width: 8),
                    if (_canReview)
                      FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _openReviewComposer(doctor);
                        },
                        icon: const Icon(Icons.rate_review_rounded),
                        label: const Text('Calificar'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (reviews.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Todavia no hay resenas publicadas para este medico.'),
                    ),
                  )
                else
                  ...reviews.map(
                    (review) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(review.patientName, style: const TextStyle(fontWeight: FontWeight.w700))),
                                _StarsCompact(value: review.rating.toDouble()),
                              ],
                            ),
                            if (review.comment.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(review.comment),
                            ],
                            const SizedBox(height: 8),
                            Text(review.createdAt, style: Theme.of(sheetContext).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openReviewComposer(PublicDoctorProfileData doctor) async {
    final commentController = TextEditingController();
    int rating = 5;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Calificar a ${doctor.fullName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selecciona una calificacion y, si quieres, agrega un comentario.'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        onPressed: saving ? null : () => setDialogState(() => rating = star),
                        icon: Icon(
                          star <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFF5B000),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Comentario'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          try {
                            await _contentService.submitDoctorReview(
                              doctorId: doctor.id,
                              patientId: widget.currentUser.patientId!,
                              rating: rating,
                              comment: commentController.text.trim(),
                            );
                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tu resena fue guardada.')),
                            );
                            await _refresh();
                          } catch (error) {
                            if (!mounted) return;
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                            );
                          }
                        },
                  child: Text(saving ? 'Guardando...' : 'Guardar resena'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openBookingComposer(PublicDoctorProfileData doctor) async {
    final reasonController = TextEditingController(text: 'VALORACION INICIAL');
    RoomSummaryData? selectedRoom;
    List<RoomSummaryData> rooms = const [];
    List<DateTime> availableDays = const [];
    DateTime? selectedDate;
    List<String> slots = const [];
    String? selectedSlot;
    bool loading = true;
    bool saving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        Future<void> refreshForRoom(StateSetter setDialogState, RoomSummaryData? room) async {
          setDialogState(() {
            selectedRoom = room;
            selectedDate = null;
            selectedSlot = null;
            availableDays = const [];
            slots = const [];
            loading = true;
            errorMessage = null;
          });
          if (room == null) {
            setDialogState(() => loading = false);
            return;
          }
          try {
            availableDays = await _loadBookableDays(doctor.id, room.id);
            selectedDate = availableDays.isNotEmpty ? availableDays.first : null;
            if (selectedDate != null) {
              slots = await _agendaService.loadAvailableSlots(
                doctorId: doctor.id,
                roomId: room.id,
                date: DateFormat('yyyy-MM-dd').format(selectedDate!),
              );
              selectedSlot = slots.isNotEmpty ? slots.first : null;
            }
          } catch (error) {
            errorMessage = _friendlyError(error, 'No se pudo actualizar la disponibilidad.');
          } finally {
            setDialogState(() => loading = false);
          }
        }

        Future<void> refreshForDate(StateSetter setDialogState, DateTime date) async {
          if (selectedRoom == null) return;
          setDialogState(() {
            loading = true;
            errorMessage = null;
          });
          try {
            final nextSlots = await _agendaService.loadAvailableSlots(
              doctorId: doctor.id,
              roomId: selectedRoom!.id,
              date: DateFormat('yyyy-MM-dd').format(date),
            );
            if (nextSlots.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ese dia ya no tiene horarios disponibles.')),
                );
              }
              return;
            }
            setDialogState(() {
              selectedDate = date;
              slots = nextSlots;
              selectedSlot = nextSlots.first;
            });
          } catch (error) {
            setDialogState(() {
              errorMessage = _friendlyError(error, 'No se pudo cargar ese dia.');
            });
          } finally {
            setDialogState(() => loading = false);
          }
        }

        Future<void> createBooking(StateSetter setDialogState) async {
          if (selectedRoom == null || selectedDate == null || selectedSlot == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selecciona consultorio, dia y horario.')),
            );
            return;
          }
          setDialogState(() {
            saving = true;
            errorMessage = null;
          });
          try {
            final result = await _agendaService.createAppointment(
              patientId: widget.currentUser.patientId!,
              doctorId: doctor.id,
              roomId: selectedRoom!.id,
              appointmentDate: DateFormat('yyyy-MM-dd').format(selectedDate!),
              startTime: selectedSlot!,
              reason: reasonController.text.trim().isEmpty ? 'VALORACION INICIAL' : reasonController.text.trim(),
            );
            if (!mounted) return;
            Navigator.of(dialogContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.alertMessage.isEmpty ? 'La cita quedo confirmada.' : result.alertMessage)),
            );
          } catch (error) {
            setDialogState(() {
              errorMessage = _friendlyError(error, 'No se pudo crear la cita.');
              saving = false;
            });
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (loading && rooms.isEmpty && errorMessage == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!dialogContext.mounted) return;
                try {
                  rooms = await _agendaService.loadRooms(doctorId: doctor.id);
                  selectedRoom = rooms.isNotEmpty ? rooms.first : null;
                  if (selectedRoom != null) {
                    availableDays = await _loadBookableDays(doctor.id, selectedRoom!.id);
                    selectedDate = availableDays.isNotEmpty ? availableDays.first : null;
                    if (selectedDate != null) {
                      slots = await _agendaService.loadAvailableSlots(
                        doctorId: doctor.id,
                        roomId: selectedRoom!.id,
                        date: DateFormat('yyyy-MM-dd').format(selectedDate!),
                      );
                      selectedSlot = slots.isNotEmpty ? slots.first : null;
                    }
                  }
                } catch (error) {
                  errorMessage = _friendlyError(error, 'No se pudo cargar la disponibilidad publica.');
                } finally {
                  if (dialogContext.mounted) {
                    setDialogState(() => loading = false);
                  }
                }
              });
            }

            return AlertDialog(
              title: Text('Reservar con ${doctor.fullName}'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selecciona un consultorio y un horario realmente disponible del medico.'),
                      const SizedBox(height: 14),
                      if (errorMessage != null) ...[
                        Text(errorMessage!, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                      ],
                      DropdownButtonFormField<RoomSummaryData>(
                        initialValue: selectedRoom,
                        decoration: const InputDecoration(labelText: 'Consultorio'),
                        items: rooms
                            .map(
                              (room) => DropdownMenuItem<RoomSummaryData>(
                                value: room,
                                child: Text('${room.name} | ${room.roomType}'),
                              ),
                            )
                            .toList(),
                        onChanged: loading || saving ? null : (room) => refreshForRoom(setDialogState, room),
                      ),
                      const SizedBox(height: 14),
                      if (availableDays.isNotEmpty) ...[
                        const Text('Dias disponibles', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableDays
                              .map(
                                (day) => ChoiceChip(
                                  label: Text(DateFormat('EEE dd/MM', 'es_MX').format(day)),
                                  selected: selectedDate != null && DateUtils.isSameDay(day, selectedDate),
                                  onSelected: loading || saving ? null : (_) => refreshForDate(setDialogState, day),
                                ),
                              )
                              .toList(),
                        ),
                      ] else if (!loading) ...[
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Este medico no tiene dias publicos disponibles en este momento.'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Text('Horarios disponibles', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      if (loading)
                        const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                      else if (slots.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No hay horarios disponibles para el dia seleccionado.'),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: slots
                              .map(
                                (slot) => ChoiceChip(
                                  label: Text(slot),
                                  selected: selectedSlot == slot,
                                  onSelected: saving ? null : (_) => setDialogState(() => selectedSlot = slot),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: reasonController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Motivo de la cita'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: saving || loading || selectedSlot == null ? null : () => createBooking(setDialogState),
                  icon: saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.event_available_rounded),
                  label: Text(saving ? 'Confirmando...' : 'Confirmar cita'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Directorio medico')),
      body: FutureBuilder<List<PublicDoctorProfileData>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No se pudo cargar el directorio medico',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text('${snapshot.error}'.replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    ElevatedButton(onPressed: _refresh, child: const Text('Reintentar')),
                  ],
                ),
              ),
            );
          }

          final allDoctors = snapshot.data ?? const <PublicDoctorProfileData>[];
          final doctors = _favoritesOnly ? allDoctors.where((doctor) => doctor.isFavorite).toList() : allDoctors;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
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
                        'Encuentra medicos aprobados',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Explora perfiles publicos con experiencia, costo, modalidad, disponibilidad y resenas reales de pacientes.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(labelText: 'Buscar por nombre', prefixIcon: Icon(Icons.search_rounded)),
                  onSubmitted: (_) => _applyFilters(),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _specialtyController,
                        decoration: const InputDecoration(labelText: 'Especialidad'),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'Ciudad'),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _consultationMode.isEmpty ? '' : _consultationMode,
                  decoration: const InputDecoration(labelText: 'Modalidad'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Todas')),
                    DropdownMenuItem(value: 'PRESENCIAL', child: Text('Presencial')),
                    DropdownMenuItem(value: 'VIDEOLLAMADA', child: Text('Videollamada')),
                    DropdownMenuItem(value: 'AMBAS', child: Text('Ambas')),
                  ],
                  onChanged: (value) {
                    _consultationMode = value ?? '';
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Aplicar filtros'),
                ),
                const SizedBox(height: 16),
                if (widget.currentUser.role == RoleType.patient)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FilterChip(
                      label: const Text('Solo favoritos'),
                      selected: _favoritesOnly,
                      onSelected: (value) => setState(() => _favoritesOnly = value),
                    ),
                  ),
                if (doctors.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No hay medicos publicos que coincidan con la busqueda.'),
                    ),
                  )
                else
                  ...doctors.map(
                    (doctor) => Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openDoctorDetail(doctor),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundColor: const Color(0xFFD8E4FF),
                                    backgroundImage: doctor.profileImageUrl.trim().isNotEmpty ? NetworkImage(doctor.profileImageUrl.trim()) : null,
                                    child: doctor.profileImageUrl.trim().isEmpty
                                        ? Text(
                                            doctor.fullName.isEmpty ? 'M' : doctor.fullName.characters.first.toUpperCase(),
                                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(doctor.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                                        const SizedBox(height: 4),
                                        Text((doctor.specialties.isEmpty ? [doctor.specialty] : doctor.specialties).join(' | '), style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            Chip(label: Text('Cedula ${doctor.licenseNumber}')),
                                            Chip(label: Text(doctor.consultationMode)),
                                            if (doctor.yearsExperience > 0) Chip(label: Text('${doctor.yearsExperience} anos exp.')),
                                            if (doctor.isFavorite) const Chip(label: Text('Favorito')),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _RatingRow(rating: doctor.averageRating, reviewCount: doctor.reviewCount),
                              const SizedBox(height: 12),
                              FutureBuilder<String>(
                                future: _nextAvailabilityFor(doctor),
                                builder: (context, availabilitySnapshot) {
                                  final label = availabilitySnapshot.data ?? 'Consultando disponibilidad...';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F3FF),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.event_available_rounded, size: 18, color: Color(0xFF145DA0)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Proxima disponibilidad: $label',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Text('Ubicacion: ${doctor.locationLabel}'),
                              const SizedBox(height: 8),
                              FutureBuilder<List<String>>(
                                future: _weeklyAvailabilityFor(doctor),
                                builder: (context, weeklySnapshot) {
                                  final items = weeklySnapshot.data ?? const <String>[];
                                  final preview = items.take(2).toList();
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F7FB),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Semana visible', style: TextStyle(fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 6),
                                        if (weeklySnapshot.connectionState == ConnectionState.waiting)
                                          const Text('Consultando...')
                                        else if (preview.isEmpty)
                                          const Text('Sin espacios publicados')
                                        else
                                          ...preview.map(
                                            (item) => Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(item),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              if (doctor.publicBio.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(doctor.publicBio),
                              ],
                              if (doctor.consultationFee > 0) ...[
                                const SizedBox(height: 8),
                                Text('Consulta desde: \$${doctor.consultationFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              ],
                              if (doctor.consultationFeePresential > 0 || doctor.consultationFeeVideo > 0) ...[
                                const SizedBox(height: 8),
                                if (doctor.consultationFeePresential > 0) Text('Presencial: \$${doctor.consultationFeePresential.toStringAsFixed(2)}'),
                                if (doctor.consultationFeeVideo > 0) Text('Videollamada: \$${doctor.consultationFeeVideo.toStringAsFixed(2)}'),
                              ],
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _shareDoctorProfile(doctor),
                                  icon: const Icon(Icons.share_rounded),
                                  label: const Text('Compartir perfil'),
                                ),
                              ),
                              if (widget.currentUser.role == RoleType.patient)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton.filledTonal(
                                    onPressed: () => _toggleFavorite(doctor),
                                    icon: Icon(doctor.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                                    tooltip: doctor.isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.rating,
    required this.reviewCount,
  });

  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StarsCompact(value: rating),
        const SizedBox(width: 8),
        Text(
          reviewCount > 0 ? '${rating.toStringAsFixed(1)} | $reviewCount resenas' : 'Sin resenas todavia',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _StarsCompact extends StatelessWidget {
  const _StarsCompact({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final star = index + 1;
        final icon = value >= star
            ? Icons.star_rounded
            : value >= star - 0.5
                ? Icons.star_half_rounded
                : Icons.star_border_rounded;
        return Icon(icon, size: 18, color: const Color(0xFFF5B000));
      }),
    );
  }
}
