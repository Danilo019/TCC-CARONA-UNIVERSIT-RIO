import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/vehicle.dart';
import '../services/vehicle_service.dart';
import '../models/vehicle_validation_status.dart';
import '../models/vehicle_thumbnail_type.dart';
import '../models/vehicle_icon_library.dart';

/// Tela para cadastrar ou editar veículo do motorista
class VehicleRegisterScreen extends StatefulWidget {
  final Vehicle? existingVehicle;

  const VehicleRegisterScreen({super.key, this.existingVehicle});

  @override
  State<VehicleRegisterScreen> createState() => _VehicleRegisterScreenState();
}

class _VehicleRegisterScreenState extends State<VehicleRegisterScreen> {
  final VehicleService _vehicleService = VehicleService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();

  // Estados
  VehicleValidationStatus _validationStatus = VehicleValidationStatus.pending;
  VehicleThumbnailType _thumbnailType = VehicleThumbnailType.icon;
  String _selectedIconName = VehicleIconLibrary.defaultKey;
  Color _selectedIconColor = const Color(0xFF607D8B);
  bool _hasCnhDocument = false;
  bool _hasCrlvDocument = false;
  String? _documentNote;
  bool _isLoading = false;
  String? _errorMessage;

  static const List<Color> _iconColorOptions = [
    Color(0xFF607D8B),
    Color(0xFF455A64),
    Color(0xFF1E88E5),
    Color(0xFF1B5E20),
    Color(0xFFF57C00),
    Color(0xFFC62828),
    Color(0xFF6A1B9A),
    Color(0xFF000000),
  ];

  bool get _hasIconSelected => _selectedIconName.isNotEmpty;

  bool get _hasBasicData =>
      _brandController.text.trim().isNotEmpty &&
      _modelController.text.trim().isNotEmpty &&
      _colorController.text.trim().isNotEmpty &&
      _yearController.text.trim().isNotEmpty &&
      _plateController.text.trim().isNotEmpty;

  bool get _hasVisualRepresentation => _hasIconSelected;

  bool get _isVehicleReady =>
      _hasVisualRepresentation &&
      _hasCnhDocument &&
      _hasCrlvDocument &&
      _hasBasicData;

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
      _validationStatus = vehicle.validationStatus;
      _thumbnailType = vehicle.thumbnailType;
      if (_thumbnailType == VehicleThumbnailType.icon) {
        _selectedIconName = vehicle.iconName ?? VehicleIconLibrary.defaultKey;
        _selectedIconColor = Color(
          vehicle.iconColorValue ?? const Color(0xFF607D8B).value,
        );
      } else {
        _thumbnailType = VehicleThumbnailType.icon;
      }
      _hasCnhDocument = vehicle.hasCnhDocument;
      _hasCrlvDocument = vehicle.hasCrlvDocument;
      _documentNote = vehicle.documentNote;
    } else {
      _validationStatus = VehicleValidationStatus.pending;
      _thumbnailType = VehicleThumbnailType.icon;
      _selectedIconName = VehicleIconLibrary.defaultKey;
      _selectedIconColor = const Color(0xFF607D8B);
      _hasCnhDocument = false;
      _hasCrlvDocument = false;
      _documentNote = null;
    }
  }

  /// Submete o formulário
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasIconSelected) {
      _showError('Selecione um ícone para representar o veículo');
      return;
    }

    if (!_hasCnhDocument) {
      _showError('Confirme o envio/validação da CNH');
      return;
    }

    if (!_hasCrlvDocument) {
      _showError('Confirme o envio/validação do CRLV');
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

      final normalizedPlate = Vehicle.formatPlate(_plateController.text.trim());
      final hasConflict = await _vehicleService.hasPlateConflict(
        normalizedPlate,
        excludeVehicleId: widget.existingVehicle?.id,
      );
      if (hasConflict) {
        _showError('Já existe um veículo cadastrado com esta placa.');
        return;
      }

      final previousStatus =
          widget.existingVehicle?.validationStatus ??
          VehicleValidationStatus.pending;
      final VehicleValidationStatus newStatus =
          previousStatus == VehicleValidationStatus.approved && _isVehicleReady
          ? VehicleValidationStatus.approved
          : VehicleValidationStatus.pending;

      final vehicle = Vehicle(
        id: widget.existingVehicle?.id ?? '',
        driverId: user.uid,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        year: int.parse(_yearController.text.trim()),
        color: _colorController.text.trim(),
        plate: normalizedPlate,
        vehiclePhotoURL: null,
        hasCnhDocument: _hasCnhDocument,
        hasCrlvDocument: _hasCrlvDocument,
        documentNote: _documentNote?.trim().isNotEmpty == true
            ? _documentNote!.trim()
            : null,
        validationStatus: newStatus,
        thumbnailType: VehicleThumbnailType.icon,
        iconName: _selectedIconName,
        iconColorValue: _selectedIconColor.value,
        createdAt: widget.existingVehicle?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final bool success = widget.existingVehicle != null
          ? await _vehicleService.updateVehicle(vehicle)
          : (await _vehicleService.createVehicle(vehicle)) != null;

      if (!success) {
        _showError('Erro ao salvar veículo');
        return;
      }

      if (!mounted) return;

      setState(() {
        _validationStatus = newStatus;
      });

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

      if (newStatus != VehicleValidationStatus.approved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cadastro enviado para validação. Aguarde a aprovação para oferecer caronas.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      Navigator.of(context).pop(true);
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
        _isLoading = false;
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

  Widget _buildValidationStatusCard() {
    final statusColor = _statusColor(_validationStatus);
    final statusDescription = _statusDescription(_validationStatus);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  _validationStatus.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              statusDescription,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            _buildChecklistItem('Dados do veículo preenchidos', _hasBasicData),
            _buildChecklistItem(
              'Ícone e cor selecionados',
              _hasVisualRepresentation,
            ),
            _buildChecklistItem('CNH validada/enviada', _hasCnhDocument),
            _buildChecklistItem('CRLV validado/enviado', _hasCrlvDocument),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Representação do veículo',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Atualmente o envio de fotos está desativado. Escolha um ícone e uma cor que representem seu carro.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildIconSelector() {
    final previewColor = _selectedIconColor.withOpacity(0.15);
    final iconData = VehicleIconLibrary.resolve(_selectedIconName);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ícone do veículo',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: previewColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(iconData, color: _selectedIconColor, size: 42),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Selecione um ícone que represente o modelo do seu carro e personalize a cor para combiná-lo com a pintura real.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Modelo',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VehicleIconLibrary.keys.map((key) {
                final isSelected = _selectedIconName == key;
                return ChoiceChip(
                  label: Icon(
                    VehicleIconLibrary.resolve(key),
                    color: isSelected ? Colors.white : Colors.grey[700],
                    size: 28,
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedIconName = key;
                    });
                  },
                  selectedColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: Colors.grey[100],
                  labelPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Cor',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _iconColorOptions.map((color) {
                final isSelected = _selectedIconColor.value == color.value;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIconColor = color;
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documentos obrigatórios',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Enquanto o envio digital estiver indisponível, marque abaixo quando os documentos forem entregues ou validados pela coordenação.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: _hasCnhDocument,
              onChanged: (value) {
                setState(() {
                  _hasCnhDocument = value;
                });
              },
              title: const Text('CNH verificada'),
              subtitle: const Text('Confirmo que a CNH foi enviada/validada.'),
            ),
            SwitchListTile.adaptive(
              value: _hasCrlvDocument,
              onChanged: (value) {
                setState(() {
                  _hasCrlvDocument = value;
                });
              },
              title: const Text('CRLV verificado'),
              subtitle: const Text('Confirmo que o CRLV foi enviado/validado.'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _documentNote,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                hintText: 'Ex: Entreguei a CNH na secretaria em 12/09.',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _documentNote = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(String label, bool isComplete) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isComplete ? Colors.green : Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isComplete ? Colors.black87 : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(VehicleValidationStatus status) {
    switch (status) {
      case VehicleValidationStatus.approved:
        return Colors.green;
      case VehicleValidationStatus.rejected:
        return Colors.red;
      case VehicleValidationStatus.pending:
        return const Color(0xFFFB8C00); // laranja
    }
  }

  String _statusDescription(VehicleValidationStatus status) {
    switch (status) {
      case VehicleValidationStatus.approved:
        return 'Veículo aprovado. Você pode oferecer caronas normalmente.';
      case VehicleValidationStatus.rejected:
        return 'Seu veículo foi reprovado. Atualize os dados e documentos para nova análise.';
      case VehicleValidationStatus.pending:
        return 'Conclua os itens abaixo para concluir o cadastro e passar pela validação.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.existingVehicle != null
              ? 'Editar Veículo'
              : 'Cadastrar Veículo',
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
              _buildValidationStatusCard(),
              const SizedBox(height: 20),
              _buildThumbnailTypeSelector(),
              const SizedBox(height: 20),
              _buildIconSelector(),

              const SizedBox(height: 24),

              _buildDocumentSection(),

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
                  if (value.length == 3 && !value.contains('-')) {
                    _plateController.value = TextEditingValue(
                      text: '$value-',
                      selection: TextSelection.collapsed(offset: 4),
                    );
                  }
                },
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          widget.existingVehicle != null
                              ? 'Atualizar'
                              : 'Cadastrar',
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: keyboardType,
      inputFormatters: textInputFormatter,
      validator: validator,
      onChanged: onChanged,
    );
  }
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
