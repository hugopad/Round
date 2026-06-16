import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/auth_user.dart';
import '../models/doctor_professional_request_data.dart';
import '../models/doctor_professional_request_summary_data.dart';
import '../services/staff_admin_service.dart';

class DoctorProfessionalRequestsScreen extends StatefulWidget {
  const DoctorProfessionalRequestsScreen({
    super.key,
    required this.currentUser,
  });

  final AuthUser currentUser;

  @override
  State<DoctorProfessionalRequestsScreen> createState() => _DoctorProfessionalRequestsScreenState();
}

class _DoctorProfessionalRequestsScreenState extends State<DoctorProfessionalRequestsScreen> {
  final StaffAdminService _service = StaffAdminService();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  static const String _filterAll = 'ALL';
  static const String _filterPending = 'PENDING';
  static const String _filterApprovedToday = 'APPROVED_TODAY';
  static const String _filterRejectedToday = 'REJECTED_TODAY';
  static const String _sortNewest = 'NEWEST';
  static const String _sortOldest = 'OLDEST';
  static const String _sortApproved = 'APPROVED';
  static const String _sortRejected = 'REJECTED';

  bool _loading = true;
  bool _processing = false;
  String? _errorMessage;
  List<DoctorProfessionalRequestData> _requests = const [];
  DoctorProfessionalRequestSummaryData _summary = const DoctorProfessionalRequestSummaryData();
  String _selectedSummaryFilter = _filterAll;
  String _selectedSort = _sortNewest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.loadDoctorProfessionalRequests(),
        _service.loadDoctorProfessionalRequestsSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0] as List<DoctorProfessionalRequestData>;
        _summary = results[1] as DoctorProfessionalRequestSummaryData;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(DoctorProfessionalRequestData request, String action) async {
    _notesController.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action == 'APPROVE' ? 'Aprobar solicitud' : 'Rechazar solicitud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              action == 'APPROVE'
                  ? 'Se creara el acceso del medico ${request.fullName} y su solicitud pasara a APROBADA.'
                  : 'La solicitud de ${request.fullName} pasara a RECHAZADA.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas de revision',
                hintText: 'Opcional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action == 'APPROVE' ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      await _service.reviewDoctorProfessionalRequest(
        requestId: request.id,
        reviewerUserId: widget.currentUser.id,
        action: action,
        reviewNotes: _notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'APPROVE' ? 'Solicitud aprobada y medico activado.' : 'Solicitud rechazada.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  bool _matchesSearch(DoctorProfessionalRequestData item, String searchQuery) {
    if (searchQuery.isEmpty) return true;
    final searchable = [
      item.fullName,
      item.email,
      item.licenseNumber,
      item.trackingCode,
      item.specialty,
    ].join(' ').toLowerCase();
    return searchable.contains(searchQuery);
  }

  int _compareByCreatedDesc(DoctorProfessionalRequestData left, DoctorProfessionalRequestData right) {
    final leftDate = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightDate = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightDate.compareTo(leftDate);
  }

  int _compareByCreatedAsc(DoctorProfessionalRequestData left, DoctorProfessionalRequestData right) {
    final leftDate = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightDate = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return leftDate.compareTo(rightDate);
  }

  List<DoctorProfessionalRequestData> _applySort(List<DoctorProfessionalRequestData> items) {
    final sorted = [...items];
    switch (_selectedSort) {
      case _sortOldest:
        sorted.sort(_compareByCreatedAsc);
        return sorted;
      case _sortApproved:
        sorted
          ..sort(_compareByCreatedDesc)
          ..sort((left, right) {
            final leftApproved = left.status.toUpperCase() == 'APROBADO' ? 0 : 1;
            final rightApproved = right.status.toUpperCase() == 'APROBADO' ? 0 : 1;
            return leftApproved.compareTo(rightApproved);
          });
        return sorted;
      case _sortRejected:
        sorted
          ..sort(_compareByCreatedDesc)
          ..sort((left, right) {
            final leftRejected = left.status.toUpperCase() == 'RECHAZADO' ? 0 : 1;
            final rightRejected = right.status.toUpperCase() == 'RECHAZADO' ? 0 : 1;
            return leftRejected.compareTo(rightRejected);
          });
        return sorted;
      case _sortNewest:
      default:
        sorted.sort(_compareByCreatedDesc);
        return sorted;
    }
  }

  ({
    List<DoctorProfessionalRequestData> pending,
    List<DoctorProfessionalRequestData> reviewed,
    String filterLabel,
  }) _currentViewLists() {
    final now = DateTime.now();
    final searchQuery = _searchController.text.trim().toLowerCase();
    final pending = _requests.where((item) => item.isPending).toList(growable: false);
    final reviewed = _requests.where((item) => !item.isPending).toList(growable: false);
    final approvedToday = reviewed
        .where(
          (item) =>
              item.status.toUpperCase() == 'APROBADO' &&
              item.reviewedAt != null &&
              item.reviewedAt!.year == now.year &&
              item.reviewedAt!.month == now.month &&
              item.reviewedAt!.day == now.day,
        )
        .toList(growable: false);
    final rejectedToday = reviewed
        .where(
          (item) =>
              item.status.toUpperCase() == 'RECHAZADO' &&
              item.reviewedAt != null &&
              item.reviewedAt!.year == now.year &&
              item.reviewedAt!.month == now.month &&
              item.reviewedAt!.day == now.day,
        )
        .toList(growable: false);

    final visiblePending = switch (_selectedSummaryFilter) {
      _filterAll || _filterPending => pending,
      _ => const <DoctorProfessionalRequestData>[],
    };

    final visibleReviewed = switch (_selectedSummaryFilter) {
      _filterAll => reviewed,
      _filterApprovedToday => approvedToday,
      _filterRejectedToday => rejectedToday,
      _ => const <DoctorProfessionalRequestData>[],
    };

    final filteredPending = visiblePending.where((item) => _matchesSearch(item, searchQuery)).toList(growable: false);
    final filteredReviewed = visibleReviewed.where((item) => _matchesSearch(item, searchQuery)).toList(growable: false);

    final filterLabel = switch (_selectedSummaryFilter) {
      _filterPending => 'Mostrando solo pendientes',
      _filterApprovedToday => 'Mostrando solo aprobadas hoy',
      _filterRejectedToday => 'Mostrando solo rechazadas hoy',
      _ => 'Mostrando todas las solicitudes',
    };

    return (
      pending: _applySort(filteredPending),
      reviewed: _applySort(filteredReviewed),
      filterLabel: filterLabel,
    );
  }

  String _csvEscape(String value) {
    final normalized = value.replaceAll('"', '""');
    return '"$normalized"';
  }

  Future<void> _exportCurrentView() async {
    final view = _currentViewLists();
    final rows = [...view.pending.map((item) => ('Pendiente', item)), ...view.reviewed.map((item) => ('Revision', item))];
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay solicitudes para exportar con el filtro actual.')),
      );
      return;
    }

    final buffer = StringBuffer()
      ..writeln('seccion,folio,nombre,correo,telefono,especialidad,cedula,consultorio,ciudad,estado,modalidad,status,notas,solicitud_enviada,revisada_en,revisada_por');

    for (final row in rows) {
      final item = row.$2;
      buffer.writeln([
        _csvEscape(row.$1),
        _csvEscape(item.trackingCode),
        _csvEscape(item.fullName),
        _csvEscape(item.email),
        _csvEscape(item.phone),
        _csvEscape(item.specialty),
        _csvEscape(item.licenseNumber),
        _csvEscape(item.professionalAddress),
        _csvEscape(item.city),
        _csvEscape(item.stateName),
        _csvEscape(item.consultationMode),
        _csvEscape(item.status),
        _csvEscape(item.reviewNotes),
        _csvEscape(item.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt!) : ''),
        _csvEscape(item.reviewedAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(item.reviewedAt!) : ''),
        _csvEscape(item.reviewedByName),
      ].join(','));
    }

    await Share.share(
      buffer.toString(),
      subject: 'Solicitudes medicas ROUNDGEN',
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String helper,
    required IconData icon,
    required Color color,
    required String filterKey,
  }) {
    final selected = _selectedSummaryFilter == filterKey;
    return Container(
      width: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? color : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            setState(() {
              _selectedSummaryFilter = selected ? _filterAll : filterKey;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: selected ? 0.16 : 0.10),
                  blurRadius: selected ? 22 : 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  foregroundColor: color,
                  child: Icon(icon),
                ),
                const SizedBox(height: 14),
                Text(
                  value,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(helper),
                const SizedBox(height: 8),
                Text(
                  selected ? 'Filtro activo' : 'Toca para filtrar',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text.trim().toLowerCase();
    final view = _currentViewLists();
    final sortedPending = view.pending;
    final sortedReviewed = view.reviewed;
    final filterLabel = view.filterLabel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes medicas'),
        actions: [
          IconButton(
            onPressed: (_loading || _processing) ? null : _exportCurrentView,
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
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
                        'Revision profesional',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aprueba o rechaza solicitudes medicas pendientes antes de activar accesos.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(_errorMessage!),
                    ),
                  )
                else if (_loading)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSummaryCard(
                        title: 'Pendientes',
                        value: '${_summary.pendingTotal}',
                        helper: 'Solicitudes por revisar',
                        icon: Icons.hourglass_top_rounded,
                        color: const Color(0xFFB54708),
                        filterKey: _filterPending,
                      ),
                      _buildSummaryCard(
                        title: 'Aprobadas hoy',
                        value: '${_summary.approvedToday}',
                        helper: 'Activaciones del dia',
                        icon: Icons.verified_rounded,
                        color: const Color(0xFF027A48),
                        filterKey: _filterApprovedToday,
                      ),
                      _buildSummaryCard(
                        title: 'Rechazadas hoy',
                        value: '${_summary.rejectedToday}',
                        helper: 'Solicitudes descartadas hoy',
                        icon: Icons.cancel_rounded,
                        color: const Color(0xFFB42318),
                        filterKey: _filterRejectedToday,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          filterLabel,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (_selectedSummaryFilter != _filterAll)
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _selectedSummaryFilter = _filterAll);
                          },
                          icon: const Icon(Icons.filter_alt_off_rounded),
                          label: const Text('Limpiar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Buscar por nombre, correo, cedula o folio',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSort,
                    decoration: const InputDecoration(
                      labelText: 'Ordenar solicitudes',
                      prefixIcon: Icon(Icons.sort_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: _sortNewest, child: Text('Mas recientes primero')),
                      DropdownMenuItem(value: _sortOldest, child: Text('Mas antiguas primero')),
                      DropdownMenuItem(value: _sortApproved, child: Text('Priorizar aprobadas')),
                      DropdownMenuItem(value: _sortRejected, child: Text('Priorizar rechazadas')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedSort = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  Text('Pendientes', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  if (sortedPending.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('No hay solicitudes pendientes con el filtro actual.'),
                      ),
                    )
                  else
                    ...sortedPending.map(_buildCard),
                  const SizedBox(height: 20),
                  Text('Historial de revision', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  if (sortedReviewed.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('No hay solicitudes para el filtro seleccionado.'),
                      ),
                    )
                  else
                    ...sortedReviewed.map(_buildCard),
                ],
              ],
            ),
          ),
          if (_processing)
            ColoredBox(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(DoctorProfessionalRequestData request) {
    final createdLabel = request.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt!) : 'Sin fecha';
    final statusColor = switch (request.status.toUpperCase()) {
      'APROBADO' => const Color(0xFF027A48),
      'RECHAZADO' => const Color(0xFFB42318),
      _ => const Color(0xFFB54708),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(request.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(request.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Folio: ${request.trackingCode}'),
            Text('Especialidad: ${request.specialty}'),
            Text('Cedula: ${request.licenseNumber}'),
            Text('Correo: ${request.email}'),
            if (request.phone.isNotEmpty) Text('Telefono: ${request.phone}'),
            Text('Consultorio: ${request.professionalAddress}, ${request.city}, ${request.stateName}'),
            Text('Modalidad: ${request.consultationMode}'),
            Text('Solicitud enviada: $createdLabel'),
            if (!request.isPending && request.reviewedAt != null)
              Text(
                'Revisada: ${DateFormat('dd/MM/yyyy HH:mm').format(request.reviewedAt!)}'
                '${request.reviewedByName.isEmpty ? '' : ' por ${request.reviewedByName}'}',
              ),
            if (request.reviewNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Notas: ${request.reviewNotes}'),
            ],
            if (request.isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _review(request, 'REJECT'),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _review(request, 'APPROVE'),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Aprobar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
