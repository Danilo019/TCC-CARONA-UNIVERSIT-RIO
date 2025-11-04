import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../models/vehicle.dart';
import '../services/vehicle_service.dart';

/// Tela para cadastrar ou editar veículo do motorista
class VehicleRegisterScreen extends StatefulWidget {
  final Vehicle? existingVehicle;

  const VehicleRegisterScreen({
    super.key,
    this.existingVehicle,
  });

  @override
  State<VehicleRegisterScreen> createState() => _VehicleRegisterScreenState();
}

class _VehicleRegisterScreenState extends State<VehicleRegisterScreen> {
  final VehicleService _vehicleService = VehicleService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();

  // Estados
  File? _vehiclePhoto;
  File? _cnhPhoto;
  File? _crlvPhoto;
  String? _vehiclePhotoURL;
  String? _cnhPhotoURL;
  String? _crlvPhotoURL;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingVehicle();
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  /// Carrega dados do veículo existente (modo edição)
  void _loadExistingVehicle() {
    if (widget.existingVehicle != null) {
      final vehicle = widget.existingVehicle!;
      _brandController.text = vehicle.brand;
      _modelController.text = vehicle.model;
      _yearController.text = vehicle.year.toString();
      _colorController.text = vehicle.color;
      _plateController.text = vehicle.plate;
      _vehiclePhotoURL = vehicle.vehiclePhotoURL;
      _cnhPhotoURL = vehicle.cnhPhotoURL;
      _crlvPhotoURL = vehicle.crlvPhotoURL;
    }
  }

  /// Seleciona foto (veículo, CNH ou CRLV)
  Future<void> _pickImage(ImageType type) async {
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Selecionar fonte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Câmera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeria'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (image != null) {
        setState(() {
          final file = File(image.path);
          switch (type) {
            case ImageType.vehicle:
              _vehiclePhoto = file;
              _vehiclePhotoURL = null; // Limpa URL antiga
              break;
            case ImageType.cnh:
              _cnhPhoto = file;
              _cnhPhotoURL = null;
              break;
            case ImageType.crlv:
              _crlvPhoto = file;
              _crlvPhotoURL = null;
              break;
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao selecionar imagem: $e');
      }
      _showError('Erro ao selecionar imagem: $e');
    }
  }

  /// Submete o formulário
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validações adicionais
    if (_vehiclePhoto == null && _vehiclePhotoURL == null) {
      _showError('Por favor, adicione uma foto do veículo');
      return;
    }

    if (_cnhPhoto == null && _cnhPhotoURL == null) {
      _showError('Por favor, adicione uma foto da CNH');
      return;
    }

    if (_crlvPhoto == null && _crlvPhotoURL == null) {
      _showError('Por favor, adicione uma foto do CRLV');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        _showError('Usuário não autenticado');
        return;
      }

      String? vehiclePhotoUrl = _vehiclePhotoURL;
      String? cnhPhotoUrl = _cnhPhotoURL;
      String? crlvPhotoUrl = _crlvPhotoURL;

      // Faz upload das novas fotos
      if (_vehiclePhoto != null) {
        vehiclePhotoUrl = await _vehicleService.uploadVehiclePhoto(
          _vehiclePhoto!,
          user.uid,
        );
        if (vehiclePhotoUrl == null) {
          _showError('Erro ao enviar foto do veículo');
          return;
        }
      }

      if (_cnhPhoto != null) {
        cnhPhotoUrl = await _vehicleService.uploadCnhPhoto(
          _cnhPhoto!,
          user.uid,
        );
        if (cnhPhotoUrl == null) {
          _showError('Erro ao enviar foto da CNH');
          return;
        }
      }

      if (_crlvPhoto != null) {
        crlvPhotoUrl = await _vehicleService.uploadCrlvPhoto(
          _crlvPhoto!,
          user.uid,
        );
        if (crlvPhotoUrl == null) {
          _showError('Erro ao enviar foto do CRLV');
          return;
        }
      }

      // Cria ou atualiza veículo
      final vehicle = Vehicle(
        id: widget.existingVehicle?.id ?? '',
        driverId: user.uid,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        year: int.parse(_yearController.text.trim()),
        color: _colorController.text.trim(),
        plate: Vehicle.formatPlate(_plateController.text.trim()),
        vehiclePhotoURL: vehiclePhotoUrl,
        cnhPhotoURL: cnhPhotoUrl,
        crlvPhotoURL: crlvPhotoUrl,
        createdAt: widget.existingVehicle?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool success;
      if (widget.existingVehicle != null) {
        success = await _vehicleService.updateVehicle(vehicle);
      } else {
        final vehicleId = await _vehicleService.createVehicle(vehicle);
        success = vehicleId != null;
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingVehicle != null
                  ? 'Veículo atualizado com sucesso!'
                  : 'Veículo cadastrado com sucesso!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pop(true);
      } else {
        _showError('Erro ao salvar veículo');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao salvar veículo: $e');
      }
      _showError('Erro ao salvar veículo: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Exibe mensagem de erro
  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.existingVehicle != null ? 'Editar Veículo' : 'Cadastrar Veículo',
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Foto do veículo
              _buildImageSection(
                title: 'Foto do Veículo',
                image: _vehiclePhoto,
                imageUrl: _vehiclePhotoURL,
                onTap: () => _pickImage(ImageType.vehicle),
                required: true,
              ),

              const SizedBox(height: 24),

              // Campos do veículo
              _buildTextField(
                controller: _brandController,
                label: 'Marca',
                hint: 'Ex: Toyota',
                icon: Icons.directions_car,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'A marca é obrigatória';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _modelController,
                label: 'Modelo',
                hint: 'Ex: Corolla',
                icon: Icons.label,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O modelo é obrigatório';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _yearController,
                      label: 'Ano',
                      hint: '2020',
                      icon: Icons.calendar_today,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'O ano é obrigatório';
                        }
                        final year = int.tryParse(value.trim());
                        if (year == null) {
                          return 'Ano inválido';
                        }
                        if (!Vehicle.isValidYear(year)) {
                          return 'Ano deve estar entre 1980 e ${DateTime.now().year}';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _colorController,
                      label: 'Cor',
                      hint: 'Ex: Branco',
                      icon: Icons.palette,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'A cor é obrigatória';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _plateController,
                label: 'Placa',
                hint: 'AAA-0A00 ou AAA0A00',
                icon: Icons.confirmation_number,
                textInputFormatter: [
                  UpperCaseTextFormatter(),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9-]')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'A placa é obrigatória';
                  }
                  if (!Vehicle.isValidPlate(value.trim())) {
                    return 'Placa inválida. Use formato AAA-0000 ou AAA0A00';
                  }
                  return null;
                },
                onChanged: (value) {
                  // Formata automaticamente
                  if (value.length == 3 && !value.contains('-')) {
                    _plateController.value = TextEditingValue(
                      text: '$value-',
                      selection: TextSelection.collapsed(offset: 4),
                    );
                  }
                },
              ),

              const SizedBox(height: 32),

              // Documentos
              const Text(
                'Documentos Obrigatórios',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 16),

              // CNH
              _buildImageSection(
                title: 'CNH (Carteira Nacional de Habilitação)',
                image: _cnhPhoto,
                imageUrl: _cnhPhotoURL,
                onTap: () => _pickImage(ImageType.cnh),
                required: true,
              ),

              const SizedBox(height: 24),

              // CRLV
              _buildImageSection(
                title: 'CRLV (Certificado de Registro e Licenciamento)',
                image: _crlvPhoto,
                imageUrl: _crlvPhotoURL,
                onTap: () => _pickImage(ImageType.crlv),
                required: true,
              ),

              const SizedBox(height: 32),

              // Mensagem de erro
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 16),

              // Botão de salvar
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.existingVehicle != null ? 'Atualizar' : 'Cadastrar',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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

  /// Campo de texto
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? textInputFormatter,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: keyboardType,
      inputFormatters: textInputFormatter,
      validator: validator,
      onChanged: onChanged,
    );
  }

  /// Seção de imagem
  Widget _buildImageSection({
    required String title,
    required File? image,
    required String? imageUrl,
    required VoidCallback onTap,
    required bool required,
  }) {
    final hasImage = image != null || imageUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? Colors.green : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: image != null
                        ? Image.file(
                            image,
                            fit: BoxFit.cover,
                          )
                        : imageUrl != null
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.error, size: 48),
                                  );
                                },
                              )
                            : null,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toque para adicionar foto',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                if (title.contains('Veículo')) {
                  _vehiclePhoto = null;
                  _vehiclePhotoURL = null;
                } else if (title.contains('CNH')) {
                  _cnhPhoto = null;
                  _cnhPhotoURL = null;
                } else if (title.contains('CRLV')) {
                  _crlvPhoto = null;
                  _crlvPhotoURL = null;
                }
              });
            },
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Remover foto', style: TextStyle(color: Colors.red)),
          ),
        ],
      ],
    );
  }
}

/// Enum para tipo de imagem
enum ImageType {
  vehicle,
  cnh,
  crlv,
}

/// Formatter para converter texto para maiúsculo
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
