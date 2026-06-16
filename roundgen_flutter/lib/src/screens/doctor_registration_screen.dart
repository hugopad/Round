import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/staff_admin_service.dart';

class DoctorRegistrationScreen extends StatefulWidget {
  const DoctorRegistrationScreen({super.key});

  @override
  State<DoctorRegistrationScreen> createState() => _DoctorRegistrationScreenState();
}

class _DoctorRegistrationScreenState extends State<DoctorRegistrationScreen> {
  final StaffAdminService _service = StaffAdminService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  bool _saving = false;
  String _consultationMode = 'AMBAS';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _specialtyController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _saveDoctor() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _specialtyController.text.trim().isEmpty ||
        _licenseController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _stateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa los datos profesionales obligatorios del medico.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final trackingCode = await _service.createDoctor(
        fullName: _nameController.text.trim().toUpperCase(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        specialty: _specialtyController.text.trim().toUpperCase(),
        phone: _phoneController.text.trim(),
        licenseNumber: _licenseController.text.trim().toUpperCase(),
        professionalAddress: _addressController.text.trim().toUpperCase(),
        city: _cityController.text.trim().toUpperCase(),
        stateName: _stateController.text.trim().toUpperCase(),
        consultationMode: _consultationMode,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Solicitud enviada'),
          content: Text(
            'El registro profesional del medico quedo en estatus PENDIENTE.\n\nFolio: $trackingCode\n\nCuando se revise y apruebe, podra ingresar a ROUNDGEN.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro profesional medico')),
      body: ListView(
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
                  'Onboarding profesional',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Registra tu perfil profesional. La solicitud quedara pendiente de revision antes de activar tu acceso.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(_nameController, 'Nombre completo'),
                  _field(_emailController, 'Correo profesional', keyboardType: TextInputType.emailAddress),
                  _field(_passwordController, 'Contrasena inicial', obscure: true),
                  _field(_phoneController, 'Telefono', keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                  _field(_specialtyController, 'Especialidad principal'),
                  _field(_licenseController, 'Cedula profesional', inputFormatters: [LengthLimitingTextInputFormatter(30)]),
                  _field(_addressController, 'Direccion profesional o consultorio'),
                  _field(_cityController, 'Ciudad'),
                  _field(_stateController, 'Estado'),
                  const SizedBox(height: 4),
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
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveDoctor,
                    icon: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_user_rounded),
                    label: Text(_saving ? 'Enviando...' : 'Enviar solicitud profesional'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
