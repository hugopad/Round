import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../models/ad_banner_data.dart';
import '../models/auth_user.dart';
import '../models/medical_calculator_data.dart';
import '../models/news_item_data.dart';
import '../models/role_type.dart';
import '../services/content_service.dart';

class NewsModuleScreen extends StatefulWidget {
  const NewsModuleScreen({
    super.key,
    required this.currentUser,
  });

  final AuthUser currentUser;

  @override
  State<NewsModuleScreen> createState() => _NewsModuleScreenState();
}

class _NewsModuleScreenState extends State<NewsModuleScreen> {
  final ContentService _contentService = ContentService();
  final ImagePicker _imagePicker = ImagePicker();
  late Future<_ContentBundle> _future;

  final List<MedicalCalculatorData> _calculators = const [
    MedicalCalculatorData(
      id: 'imc',
      title: 'Calculadora de IMC',
      summary: 'Relaciona peso y talla para estimar rango corporal saludable.',
      formula: 'IMC = PESO (KG) / TALLA (M)^2',
      interpretation: 'MENOR DE 18.5: BAJO PESO | 18.5 A 24.9: NORMAL | 25 A 29.9: SOBREPESO | 30 O MAS: OBESIDAD',
    ),
    MedicalCalculatorData(
      id: 'agua',
      title: 'Calculadora de hidratacion diaria',
      summary: 'Ayuda a estimar la cantidad orientativa de agua al dia.',
      formula: 'AGUA (ML) = PESO (KG) X 35',
      interpretation: 'AJUSTAR SEGUN CLIMA, EJERCICIO, EMBARAZO O INDICACION MEDICA',
    ),
    MedicalCalculatorData(
      id: 'medicacion',
      title: 'Calculadora de frecuencia de medicacion',
      summary: 'Sirve para planear tomas cada 8, 12 o 24 horas.',
      formula: '24 HORAS / NUMERO DE TOMAS = INTERVALO ENTRE DOSIS',
      interpretation: 'USAR SOLO COMO APOYO; LA INDICACION FINAL LA DEFINE EL MEDICO',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ContentBundle> _load() async {
    final rawNews = await _contentService.loadNews(
      viewerRole: widget.currentUser.role,
      doctorId: widget.currentUser.doctorId,
      patientId: widget.currentUser.patientId,
    );
    final news = _normalizeNews(rawNews);
    try {
      final ads = await _contentService.loadAds();
      return _ContentBundle(news: news, ads: ads);
    } catch (error) {
      return _ContentBundle(
        news: news,
        ads: const [],
        adsWarning: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  List<NewsItemData> _normalizeNews(List<NewsItemData> source) {
    final filtered = source.where((news) {
      final haystack = '${news.title} ${news.body} ${news.doctorName}'.toLowerCase();
      return !haystack.contains('medicalcorp');
    }).toList();

    final hasRoundgenWelcome = filtered.any((news) {
      final haystack = '${news.title} ${news.body}'.toLowerCase();
      return haystack.contains('bienvenida a roundgen') || haystack.contains('bienvenido a roundgen');
    });

    if (!hasRoundgenWelcome) {
      filtered.insert(
        0,
        NewsItemData(
          id: -1,
          sourceType: 'system',
          sourceRecordId: -1,
          createdByUserId: null,
          doctorId: null,
          doctorName: 'ROUNDGEN',
          title: 'Bienvenida a ROUNDGEN',
          body:
              'Te damos la bienvenida a ROUNDGEN, tu espacio para agenda medica, comunicacion con tu equipo de salud, seguimiento de citas, noticias y herramientas clinicas en un solo lugar.',
          category: 'Bienvenida',
          imageUrl: '',
          mediaType: '',
          externalVideoUrl: '',
          targetRole: 'ALL',
          isPublished: true,
          publishedAt: DateTime.now().toIso8601String(),
        ),
      );
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = widget.currentUser.role == RoleType.doctor;
    final isAdmin = widget.currentUser.role == RoleType.admin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noticias y calculadoras'),
        actions: [
          if (widget.currentUser.role == RoleType.doctor && widget.currentUser.doctorId != null)
            IconButton(
              tooltip: 'Publicar noticia',
              onPressed: _openCreateNews,
              icon: const Icon(Icons.post_add_rounded),
            ),
        ],
      ),
      body: FutureBuilder<_ContentBundle>(
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
                    Text('No se pudo cargar el contenido', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text('${snapshot.error}'.replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    ElevatedButton(onPressed: _refresh, child: const Text('Reintentar')),
                  ],
                ),
              ),
            );
          }

          final bundle = snapshot.data!;
          final visibleNews = isDoctor && widget.currentUser.doctorId != null
              ? bundle.news.where((news) => news.doctorId == widget.currentUser.doctorId).toList()
              : bundle.news;
          return RefreshIndicator(
            onRefresh: _refresh,
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
                        'Noticias para ROUNDGEN',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Calculadoras medicas, noticias actualizadas y anuncios para el paciente.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Encuentra doctores cerca de ti',
                  actionLabel: 'Ver recomendaciones',
                  onTap: () => _showInfoDialog(
                    context,
                    title: 'Encuentra doctores cerca de ti',
                    body: 'Puedes buscar medicos por zona, especialidad, consultorio y disponibilidad.\n\nRecomendaciones:\n- FILTRAR POR ESPECIALIDAD\n- REVISAR UBICACION Y HORARIO\n- CONFIRMAR CITA O DISPONIBILIDAD\n- VALIDAR CEDULA Y EXPERIENCIA',
                  ),
                  child: const Text('Busca por especialidad, ubicacion, horario y disponibilidad para seguimiento o segunda opinion.'),
                ),
                const SizedBox(height: 16),
                Text('Calculadoras medicas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ..._calculators.map(
                  (calculator) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SectionCard(
                      title: calculator.title,
                      actionLabel: 'Ver formula',
                      footnote: calculator.formula,
                      onTap: () => _showInfoDialog(
                        context,
                        title: calculator.title,
                        body: '${calculator.summary}\n\nFormula:\n${calculator.formula}\n\nInterpretacion:\n${calculator.interpretation}',
                      ),
                      child: Text(calculator.summary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isDoctor ? 'Mis noticias publicadas' : 'Noticias actualizadas',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (visibleNews.isEmpty)
                  _SectionCard(
                    title: 'Sin noticias publicadas',
                    actionLabel: widget.currentUser.role == RoleType.doctor ? 'Publicar ahora' : 'Actualizar',
                    onTap: widget.currentUser.role == RoleType.doctor ? _openCreateNews : _refresh,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentUser.role == RoleType.doctor
                              ? 'Todavia no has publicado noticias para tus pacientes. Puedes comenzar desde aqui.'
                              : 'Por ahora no hay noticias publicadas por tus medicos asignados.',
                        ),
                        const SizedBox(height: 14),
                        widget.currentUser.role == RoleType.doctor
                            ? FilledButton.icon(
                                onPressed: _openCreateNews,
                                icon: const Icon(Icons.post_add_rounded),
                                label: const Text('Publicar noticia'),
                              )
                            : OutlinedButton.icon(
                                onPressed: _refresh,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Reintentar'),
                              ),
                      ],
                    ),
                  ),
                if (isDoctor && visibleNews.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Has publicado ${visibleNews.length} noticia${visibleNews.length == 1 ? '' : 's'} para tus pacientes.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF475467),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ...visibleNews.map(
                  (news) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SectionCard(
                      title: news.title,
                      actionLabel: 'Abrir noticia',
                      footnote: '${news.category} | ${_formatDate(news.publishedAt)}${news.doctorName.isEmpty ? '' : ' | ${news.doctorName}'}',
                      onTap: () => _showNewsDetail(news),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_shouldShowImagePreview(news))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _NewsImagePreview(url: news.imageUrl),
                            ),
                          if (_shouldShowVideoPreview(news))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _shouldShowEmbeddedVideo(news)
                                  ? _EmbeddedVideoPlayer(
                                      videoUrl: news.imageUrl,
                                      compact: true,
                                      onExpand: () => _openVideoViewer(news.imageUrl),
                                    )
                                  : _VideoPreviewCard(
                                      videoUrl: news.externalVideoUrl.isNotEmpty ? news.externalVideoUrl : news.imageUrl,
                                    ),
                            ),
                          if (news.mediaType.isNotEmpty || news.externalVideoUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (news.mediaType.isNotEmpty)
                                    Chip(
                                      avatar: Icon(
                                        news.mediaType == 'video' ? Icons.video_library_rounded : Icons.image_rounded,
                                        size: 18,
                                      ),
                                      label: Text(news.mediaType == 'video' ? 'Video adjunto' : 'Imagen adjunta'),
                                    ),
                                  if (news.externalVideoUrl.isNotEmpty)
                                    const Chip(
                                      avatar: Icon(Icons.link_rounded, size: 18),
                                      label: Text('Link a video'),
                                    ),
                                ],
                              ),
                            ),
                          Text(news.body, maxLines: 4, overflow: TextOverflow.ellipsis),
                          if (isDoctor) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _openNewsEditor(editingNews: news),
                                  icon: const Icon(Icons.edit_rounded),
                                  label: const Text('Editar'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _deleteNews(news),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  label: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          ],
                          if (isAdmin && news.sourceType == 'notice' && news.createdByUserId == widget.currentUser.id) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _openNoticeEditor(news),
                                  icon: const Icon(Icons.edit_rounded),
                                  label: const Text('Editar aviso'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _deleteNotice(news),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  label: const Text('Eliminar aviso'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Barra de anuncios', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (bundle.adsWarning != null && bundle.adsWarning!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SectionCard(
                      title: 'Anuncios no disponibles',
                      actionLabel: 'Reintentar',
                      onTap: _refresh,
                      child: Text(bundle.adsWarning!),
                    ),
                  ),
                if (bundle.ads.isEmpty)
                  _SectionCard(
                    title: 'Sin anuncios activos',
                    actionLabel: 'Actualizar',
                    onTap: _refresh,
                    child: const Text('Por ahora no hay anuncios o promociones disponibles.'),
                  ),
                ...bundle.ads.map(
                  (ad) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SectionCard(
                      title: ad.title.isEmpty ? ad.advertiserName : ad.title,
                      actionLabel: ad.targetUrl.isEmpty ? 'Ver detalle' : 'Ver enlace',
                      footnote: ad.advertiserType,
                      onTap: () => _showInfoDialog(
                        context,
                        title: ad.advertiserName,
                        body: '${ad.messageText}\n\nEnlace: ${ad.targetUrl.isEmpty ? 'Sin enlace' : ad.targetUrl}',
                      ),
                      child: Text(ad.messageText),
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

  Future<void> _openCreateNews() async {
    await _openNewsEditor();
  }

  Future<void> _openNewsEditor({NewsItemData? editingNews}) async {
    final doctorId = widget.currentUser.doctorId;
    if (doctorId == null) return;
    final isEditing = editingNews != null;
    final titleController = TextEditingController(text: editingNews?.title ?? '');
    final bodyController = TextEditingController(text: editingNews?.body ?? '');
    final categoryController = TextEditingController(text: editingNews?.category.isNotEmpty == true ? editingNews!.category : 'Actualizacion');
    final imageUrlController = TextEditingController(text: editingNews != null && editingNews.mediaType != 'video' ? editingNews.imageUrl : '');
    final externalVideoUrlController = TextEditingController(text: editingNews?.externalVideoUrl ?? '');
    String uploadedMediaUrl = editingNews?.imageUrl ?? '';
    String uploadedMediaType = editingNews?.mediaType ?? '';
    String mediaLabel = editingNews == null
        ? 'Sin archivo adjunto'
        : editingNews.mediaType == 'video'
            ? 'Video actual cargado'
            : editingNews.imageUrl.isNotEmpty
                ? 'Imagen actual cargada'
                : 'Sin archivo adjunto';
    var saving = false;
    var uploadingMedia = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(isEditing ? 'Editar noticia publicada' : 'Publicar noticia para pacientes'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titulo'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(labelText: 'URL de imagen (opcional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: externalVideoUrlController,
                    decoration: const InputDecoration(labelText: 'Link a video (opcional)'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Archivo multimedia',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(mediaLabel),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: uploadingMedia
                                  ? null
                                  : () async {
                                      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
                                      if (file == null) return;
                                      final pickedFile = File(file.path);
                                      final bytes = await pickedFile.length();
                                      if (bytes > 3 * 1024 * 1024) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('La imagen no puede pesar mas de 3 MB.')),
                                        );
                                        return;
                                      }
                                      setDialogState(() => uploadingMedia = true);
                                      try {
                                        final uploaded = await _contentService.uploadNewsMedia(
                                          doctorId: doctorId,
                                          file: pickedFile,
                                          mediaType: 'image',
                                        );
                                        if (!mounted) return;
                                        setDialogState(() {
                                          uploadedMediaUrl = uploaded['url'] ?? '';
                                          uploadedMediaType = uploaded['media_type'] ?? 'image';
                                          mediaLabel = 'Imagen cargada correctamente';
                                        });
                                      } catch (error) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                                        );
                                      } finally {
                                        if (dialogContext.mounted) {
                                          setDialogState(() => uploadingMedia = false);
                                        }
                                      }
                                    },
                              icon: uploadingMedia ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image_rounded),
                              label: const Text('Cargar imagen'),
                            ),
                            OutlinedButton.icon(
                              onPressed: uploadingMedia
                                  ? null
                                  : () async {
                                      final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
                                      if (file == null) return;
                                      final pickedFile = File(file.path);
                                      final bytes = await pickedFile.length();
                                      if (bytes > 3 * 1024 * 1024) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('El video no puede pesar mas de 3 MB.')),
                                        );
                                        return;
                                      }
                                      setDialogState(() => uploadingMedia = true);
                                      try {
                                        final uploaded = await _contentService.uploadNewsMedia(
                                          doctorId: doctorId,
                                          file: pickedFile,
                                          mediaType: 'video',
                                        );
                                        if (!mounted) return;
                                        setDialogState(() {
                                          uploadedMediaUrl = uploaded['url'] ?? '';
                                          uploadedMediaType = uploaded['media_type'] ?? 'video';
                                          mediaLabel = 'Video cargado correctamente';
                                        });
                                      } catch (error) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                                        );
                                      } finally {
                                        if (dialogContext.mounted) {
                                          setDialogState(() => uploadingMedia = false);
                                        }
                                      }
                                    },
                              icon: uploadingMedia ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.video_library_rounded),
                              label: const Text('Cargar video'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: 'Contenido'),
                  ),
                ],
              ),
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
                        if (titleController.text.trim().isEmpty || bodyController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Titulo y contenido son obligatorios.')),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          if (isEditing) {
                            await _contentService.updateNews(
                              newsId: editingNews.id,
                              doctorId: doctorId,
                              title: titleController.text.trim(),
                              body: bodyController.text.trim(),
                              category: categoryController.text.trim().isEmpty ? 'Actualizacion' : categoryController.text.trim(),
                              imageUrl: uploadedMediaUrl.isNotEmpty ? uploadedMediaUrl : imageUrlController.text.trim(),
                              mediaType: uploadedMediaType,
                              externalVideoUrl: externalVideoUrlController.text.trim(),
                            );
                          } else {
                            await _contentService.createNews(
                              doctorId: doctorId,
                              title: titleController.text.trim(),
                              body: bodyController.text.trim(),
                              category: categoryController.text.trim().isEmpty ? 'Actualizacion' : categoryController.text.trim(),
                              imageUrl: uploadedMediaUrl.isNotEmpty ? uploadedMediaUrl : imageUrlController.text.trim(),
                              mediaType: uploadedMediaType,
                              externalVideoUrl: externalVideoUrlController.text.trim(),
                            );
                          }
                          if (!mounted) return;
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isEditing ? 'Noticia actualizada correctamente.' : 'Noticia publicada para tus pacientes.')),
                          );
                          await _refresh();
                        } catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                          );
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: Text(
                  saving
                      ? (isEditing ? 'Guardando...' : 'Publicando...')
                      : (isEditing ? 'Guardar cambios' : 'Publicar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteNews(NewsItemData news) async {
    final doctorId = widget.currentUser.doctorId;
    if (doctorId == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar noticia'),
            content: Text('Se eliminara la noticia "${news.title}".'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await _contentService.deleteNews(newsId: news.id, doctorId: doctorId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Noticia eliminada.')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openNoticeEditor(NewsItemData news) async {
    final titleController = TextEditingController(text: news.title);
    final bodyController = TextEditingController(text: news.body);
    var selectedTargetRole = news.targetRole.isEmpty ? 'PATIENT' : news.targetRole.toUpperCase();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Editar aviso general'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titulo'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedTargetRole,
                    decoration: const InputDecoration(labelText: 'Dirigido a'),
                    items: const [
                      DropdownMenuItem(value: 'PATIENT', child: Text('Pacientes')),
                      DropdownMenuItem(value: 'DOCTOR', child: Text('Medicos')),
                      DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                    ],
                    onChanged: saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setDialogState(() => selectedTargetRole = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: 'Contenido del aviso'),
                  ),
                ],
              ),
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
                        if (titleController.text.trim().isEmpty || bodyController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Titulo y contenido son obligatorios.')),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await _contentService.updateNotice(
                            noticeId: news.sourceRecordId,
                            createdByUserId: widget.currentUser.id,
                            title: titleController.text.trim(),
                            messageText: bodyController.text.trim(),
                            targetRole: selectedTargetRole,
                          );
                          if (!mounted) return;
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Aviso actualizado correctamente.')),
                          );
                          await _refresh();
                        } catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
                          );
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: Text(saving ? 'Guardando...' : 'Guardar cambios'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteNotice(NewsItemData news) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar aviso'),
            content: Text('Se eliminara el aviso "${news.title}".'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await _contentService.deleteNotice(
        noticeId: news.sourceRecordId,
        createdByUserId: widget.currentUser.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aviso eliminado.')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed == null) return raw;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  bool _shouldShowImagePreview(NewsItemData news) {
    return news.imageUrl.isNotEmpty && news.mediaType != 'video';
  }

  bool _shouldShowVideoPreview(NewsItemData news) {
    return news.mediaType == 'video' || news.externalVideoUrl.isNotEmpty;
  }

  bool _shouldShowEmbeddedVideo(NewsItemData news) {
    return news.mediaType == 'video' && news.externalVideoUrl.isEmpty && news.imageUrl.isNotEmpty;
  }

  Future<void> _showNewsDetail(NewsItemData news) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(news.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_shouldShowImagePreview(news)) ...[
                _NewsImagePreview(url: news.imageUrl),
                const SizedBox(height: 14),
              ],
              if (_shouldShowVideoPreview(news)) ...[
                _shouldShowEmbeddedVideo(news)
                    ? _EmbeddedVideoPlayer(
                        videoUrl: news.imageUrl,
                        onExpand: () => _openVideoViewer(news.imageUrl),
                      )
                    : _VideoPreviewCard(
                        videoUrl: news.externalVideoUrl.isNotEmpty ? news.externalVideoUrl : news.imageUrl,
                      ),
                const SizedBox(height: 14),
              ],
              if (news.doctorName.isNotEmpty) ...[
                Text(
                  'Publicado por ${news.doctorName}',
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(news.body),
              if (widget.currentUser.role == RoleType.doctor && widget.currentUser.doctorId == news.doctorId) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _openNewsEditor(editingNews: news);
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Editar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _deleteNews(news);
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Eliminar'),
                    ),
                  ],
                ),
              ],
              if (news.externalVideoUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        news.externalVideoUrl,
                        style: const TextStyle(
                          color: Color(0xFF2D59C4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: news.externalVideoUrl));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link de video copiado.')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, {required String title, required String body}) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Future<void> _openVideoViewer(String videoUrl) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: const Color(0xFF020617),
          appBar: AppBar(
            backgroundColor: const Color(0xFF020617),
            foregroundColor: Colors.white,
            title: const Text('Video'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _EmbeddedVideoPlayer(videoUrl: videoUrl),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsImagePreview extends StatelessWidget {
  const _NewsImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFE2E8F0),
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, size: 32, color: Color(0xFF64748B)),
                SizedBox(height: 8),
                Text('No se pudo cargar la imagen'),
              ],
            ),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: const Color(0xFFF8FAFC),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }
}

class _VideoPreviewCard extends StatelessWidget {
  const _VideoPreviewCard({required this.videoUrl});

  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vista previa de video',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  videoUrl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmbeddedVideoPlayer extends StatefulWidget {
  const _EmbeddedVideoPlayer({
    required this.videoUrl,
    this.compact = false,
    this.onExpand,
  });

  final String videoUrl;
  final bool compact;
  final VoidCallback? onExpand;

  @override
  State<_EmbeddedVideoPlayer> createState() => _EmbeddedVideoPlayerState();
}

class _EmbeddedVideoPlayerState extends State<_EmbeddedVideoPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  var _isReady = false;
  var _showPoster = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      final initializeFuture = controller.initialize();
      setState(() {
        _controller = controller;
        _initializeFuture = initializeFuture;
      });
      await initializeFuture;
      if (!mounted) return;
      controller.pause();
      controller.seekTo(Duration.zero);
      setState(() => _isReady = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'No se pudo reproducir el video.');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _VideoPreviewCard(videoUrl: widget.videoUrl);
    }

    final controller = _controller;
    final initializeFuture = _initializeFuture;
    if (controller == null || initializeFuture == null) {
      return Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: const Color(0xFF020617),
        child: FutureBuilder<void>(
          future: initializeFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done || !_isReady) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                    if (_showPoster)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.10),
                                Colors.black.withOpacity(0.38),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    if (_showPoster)
                      GestureDetector(
                        onTap: () async {
                          if (widget.compact && widget.onExpand != null) {
                            widget.onExpand!();
                            return;
                          }
                          await controller.play();
                          if (!mounted) return;
                          setState(() => _showPoster = false);
                        },
                        child: Container(
                          height: widget.compact ? 68 : 84,
                          width: widget.compact ? 68 : 84,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.40),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.compact ? Icons.open_in_full_rounded : Icons.play_arrow_rounded,
                            size: widget.compact ? 38 : 46,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (widget.onExpand != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.black.withOpacity(0.38),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: widget.onExpand,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.open_in_full_rounded, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () {
                          if (controller.value.isPlaying) {
                            controller.pause();
                          } else {
                            controller.play();
                          }
                          setState(() {
                            _showPoster = false;
                          });
                        },
                        icon: Icon(
                          controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        ),
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Color(0xFF60A5FA),
                            bufferedColor: Color(0xFF334155),
                            backgroundColor: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (!widget.compact) ...[
                        const SizedBox(width: 12),
                        Text(
                          _formatDuration(controller.value.position),
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.compact)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Video adjunto',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    return hours > 0 ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class _ContentBundle {
  const _ContentBundle({
    required this.news,
    required this.ads,
    this.adsWarning,
  });

  final List<NewsItemData> news;
  final List<AdBannerData> ads;
  final String? adsWarning;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.actionLabel,
    required this.onTap,
    required this.child,
    this.footnote,
  });

  final String title;
  final Widget child;
  final String actionLabel;
  final VoidCallback onTap;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              child,
              if (footnote != null && footnote!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(footnote!, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(actionLabel, style: const TextStyle(color: Color(0xFF2D59C4), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
