import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/doctor_public_profile_config.dart';
import '../services/doctor_public_profile_service.dart';

class DoctorPublicProfileScreen extends StatefulWidget {
  const DoctorPublicProfileScreen({
    super.key,
    required this.doctorId,
  });

  final int doctorId;

  @override
  State<DoctorPublicProfileScreen> createState() => _DoctorPublicProfileScreenState();
}

class _DoctorPublicProfileScreenState extends State<DoctorPublicProfileScreen> {
  final DoctorPublicProfileService _service = DoctorPublicProfileService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _specialtiesController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _feePresentialController = TextEditingController();
  final TextEditingController _feeVideoController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _yearsController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingImage = false;
  bool _isPublic = true;
  String _consultationMode = 'AMBAS';
  String? _errorMessage;
  String _doctorName = '';
  String _licenseNumber = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _specialtyController.dispose();
    _specialtiesController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _bioController.dispose();
    _feeController.dispose();
    _feePresentialController.dispose();
    _feeVideoController.dispose();
    _imageUrlController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _service.load(widget.doctorId);
      _doctorName = profile.fullName;
      _licenseNumber = profile.licenseNumber;
      _specialtyController.text = profile.specialty;
      _specialtiesController.text = (profile.specialties.isEmpty ? [profile.specialty] : profile.specialties).join(', ');
      _addressController.text = profile.professionalAddress;
      _cityController.text = profile.city;
      _stateController.text = profile.stateName;
      _bioController.text = profile.publicBio;
      _feeController.text = profile.consultationFee <= 0 ? '' : profile.consultationFee.toStringAsFixed(2);
      _feePresentialController.text = profile.consultationFeePresential <= 0 ? '' : profile.consultationFeePresential.toStringAsFixed(2);
      _feeVideoController.text = profile.consultationFeeVideo <= 0 ? '' : profile.consultationFeeVideo.toStringAsFixed(2);
      _imageUrlController.text = profile.profileImageUrl;
      _yearsController.text = '${profile.yearsExperience}';
      _consultationMode = profile.consultationMode.isEmpty ? 'AMBAS' : profile.consultationMode;
      _isPublic = profile.isPublicProfile;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final specialty = _specialtyController.text.trim();
    final specialties = _specialtiesController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    final stateName = _stateController.text.trim();
    final bio = _bioController.text.trim();
    final imageUrl = _imageUrlController.text.trim();
    final fee = double.tryParse(_feeController.text.trim()) ?? 0;
    final feePresential = double.tryParse(_feePresentialController.text.trim()) ?? fee;
    final feeVideo = double.tryParse(_feeVideoController.text.trim()) ?? fee;
    final years = int.tryParse(_yearsController.text.trim()) ?? 0;

    if (specialty.isEmpty || specialties.isEmpty || address.isEmpty || city.isEmpty || stateName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa especialidad principal, especialidades, direccion profesional, ciudad y estado.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.save(
        DoctorPublicProfileConfig(
          doctorId: widget.doctorId,
          fullName: _doctorName,
          licenseNumber: _licenseNumber,
          specialty: specialty,
          specialties: specialties,
          professionalAddress: address,
          city: city,
          stateName: stateName,
          consultationMode: _consultationMode,
          publicBio: bio,
          consultationFee: fee,
          consultationFeePresential: feePresential,
          consultationFeeVideo: feeVideo,
          profileImageUrl: imageUrl,
          yearsExperience: years,
          isPublicProfile: _isPublic,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil publico actualizado.')),
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

  Future<void> _pickAndUploadImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (image == null) {
        return;
      }

      setState(() => _uploadingImage = true);
      final uploadedUrl = await _service.uploadProfileImage(
        doctorId: widget.doctorId,
        image: image,
      );
      if (!mounted) return;
      setState(() => _imageUrlController.text = uploadedUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen profesional actualizada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil publico medico')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                        _doctorName.isEmpty ? 'Perfil publico profesional' : _doctorName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _licenseNumber.isEmpty ? 'Completa tu perfil para el directorio publico.' : 'Cedula profesional: $_licenseNumber',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Text(_errorMessage!, style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                ],
                TextField(controller: _specialtyController, decoration: const InputDecoration(labelText: 'Especialidad visible')),
                const SizedBox(height: 14),
                TextField(
                  controller: _specialtiesController,
                  decoration: const InputDecoration(labelText: 'Especialidades (separadas por coma)'),
                ),
                const SizedBox(height: 14),
                TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Direccion profesional')),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Ciudad'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _stateController, decoration: const InputDecoration(labelText: 'Estado'))),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _consultationMode,
                  decoration: const InputDecoration(labelText: 'Modalidad de consulta'),
                  items: const [
                    DropdownMenuItem(value: 'PRESENCIAL', child: Text('Presencial')),
                    DropdownMenuItem(value: 'VIDEOLLAMADA', child: Text('Videollamada')),
                    DropdownMenuItem(value: 'AMBAS', child: Text('Ambas')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _consultationMode = value);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _feeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Costo base referencia'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _yearsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Anos de experiencia'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _feePresentialController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Costo presencial'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _feeVideoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Costo videollamada'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _imageUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'URL de foto profesional'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _uploadingImage ? null : _pickAndUploadImage,
                  icon: _uploadingImage
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_library_rounded),
                  label: Text(_uploadingImage ? 'Subiendo imagen...' : 'Seleccionar foto y subirla'),
                ),
                if (_imageUrlController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.network(
                      _imageUrlController.text.trim(),
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Text('No se pudo cargar la imagen'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _bioController,
                  minLines: 4,
                  maxLines: 7,
                  decoration: const InputDecoration(labelText: 'Biografia publica'),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: _isPublic,
                  onChanged: (value) => setState(() => _isPublic = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar este perfil en el directorio publico'),
                  subtitle: const Text('Si lo desactivas, dejaras de aparecer en la busqueda de pacientes.'),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Guardando...' : 'Guardar perfil publico'),
                ),
              ],
            ),
    );
  }
}
