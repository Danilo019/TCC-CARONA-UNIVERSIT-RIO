import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../models/ride.dart';
import '../models/location.dart';
import '../services/rides_service.dart';
import '../services/google_maps_service.dart';
import '../services/location_service.dart';
import '../components/map_widget.dart';

/// Tela para oferecer uma nova carona
class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  final RidesService _ridesService = RidesService();
  final GoogleMapsService _googleMapsService = GoogleMapsService();
  final LocationService _locationService = LocationService();
  
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  Location? _originLocation;
  Location? _destinationLocation;
  DateTime? _selectedDateTime;
  int _maxSeats = 4;
  int _availableSeats = 4;
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Carrega localização atual do usuário como origem padrão
  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        _originLocation = Location(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        );

        // Faz reverse geocoding
        final geocodeResult = await _googleMapsService.reverseGeocode(_originLocation!);
        
        if (mounted) {
          setState(() {
            _originLocation = geocodeResult?.location ?? _originLocation;
            _originController.text = geocodeResult?.formattedAddress ?? 'Localização atual';
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _errorMessage = 'Erro ao carregar localização: $e';
        });
      }
    }
  }

  /// Busca endereço para origem
  Future<void> _searchOrigin() async {
    // Pergunta se quer buscar por texto ou no mapa
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecionar Origem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Buscar por texto'),
              onTap: () => Navigator.pop(context, 'text'),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Selecionar no mapa'),
              onTap: () => Navigator.pop(context, 'map'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (choice == 'text' && mounted) {
      // Busca por texto
      final result = await showDialog<GeocodingResult>(
        context: context,
        builder: (context) => _SearchAddressDialog(title: 'Origem'),
      );

      if (result != null && mounted) {
        setState(() {
          _originLocation = result.location;
          _originController.text = result.formattedAddress;
        });
      }
    } else if (choice == 'map' && mounted) {
      // Seleciona no mapa
      await _showMapPicker('Origem');
    }
  }

  /// Busca endereço para destino
  Future<void> _searchDestination() async {
    // Pergunta se quer buscar por texto ou no mapa
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecionar Destino'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Buscar por texto'),
              onTap: () => Navigator.pop(context, 'text'),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Selecionar no mapa'),
              onTap: () => Navigator.pop(context, 'map'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (choice == 'text' && mounted) {
      // Busca por texto
      final result = await showDialog<GeocodingResult>(
        context: context,
        builder: (context) => _SearchAddressDialog(title: 'Destino'),
      );

      if (result != null && mounted) {
        setState(() {
          _destinationLocation = result.location;
          _destinationController.text = result.formattedAddress;
        });
      }
    } else if (choice == 'map' && mounted) {
      // Seleciona no mapa
      await _showMapPicker('Destino');
    }
  }
  
  /// Mostra mapa interativo para selecionar localização
  Future<void> _showMapPicker(String title) async {
    Location? selectedLocation;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding: EdgeInsets.zero,
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Scaffold(
                appBar: AppBar(
                  title: Text('Selecione $title no mapa'),
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                ),
                body: Stack(
                  children: [
                    MapWidget(
                      initialLocation: _originLocation ?? _destinationLocation,
                      rides: const [],
                      showUserLocation: true,
                      showRideMarkers: false,
                      onMapTap: (location) {
                        selectedLocation = location;
                        setDialogState(() {});
                      },
                    ),
                    // Marcador no centro para indicar seleção
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withValues(alpha: 0.6),
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Botão de confirmar
                    Positioned(
                      bottom: 30,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: selectedLocation == null
                              ? null
                              : () async {
                                  // Faz reverse geocoding para obter endereço
                                  if (selectedLocation != null) {
                                    final geocodeResult = await _googleMapsService
                                        .reverseGeocode(selectedLocation!);
                                    
                                    if (mounted) {
                                      final finalLocation = geocodeResult?.location ?? selectedLocation!;
                                      final address = geocodeResult?.formattedAddress ?? 
                                          '${finalLocation.latitude.toStringAsFixed(6)}, ${finalLocation.longitude.toStringAsFixed(6)}';
                                      
                                      setState(() {
                                        if (title == 'Origem') {
                                          _originLocation = finalLocation;
                                          _originController.text = address;
                                        } else {
                                          _destinationLocation = finalLocation;
                                          _destinationController.text = address;
                                        }
                                      });
                                      
                                      if (mounted) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Confirmar Localização',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Seleciona data e hora da carona
  Future<void> _selectDateTime() async {
    // Seleciona data
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF2196F3),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    // Seleciona hora
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF2196F3),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null && mounted) {
      setState(() {
        _selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  /// Submete o formulário e cria a carona
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_originLocation == null || _destinationLocation == null) {
      _showError('Por favor, selecione origem e destino');
      return;
    }

    if (_selectedDateTime == null) {
      _showError('Por favor, selecione data e hora');
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

      final ride = Ride(
        id: '', // Será gerado pelo Firestore
        driverId: user.uid,
        driverName: user.displayNameOrEmail,
        driverPhotoURL: user.photoURL,
        origin: _originLocation!,
        destination: _destinationLocation!,
        dateTime: _selectedDateTime!,
        maxSeats: _maxSeats,
        availableSeats: _availableSeats,
        description: _descriptionController.text.isNotEmpty 
            ? _descriptionController.text 
            : null,
        status: 'active',
        createdAt: DateTime.now(),
      );

      final rideId = await _ridesService.createRide(ride);

      if (rideId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Carona criada com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Volta para a tela anterior
        Navigator.of(context).pop(true);
      } else {
        _showError('Erro ao criar carona');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar carona: $e');
      }
      _showError('Erro ao criar carona: $e');
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
        title: const Text('Oferecer Carona'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Preview do mapa
                    if (_originLocation != null || _destinationLocation != null) ...[
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: MapWidget(
                            initialLocation: _originLocation ?? _destinationLocation,
                            rides: const [],
                            showUserLocation: false,
                            showRideMarkers: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Origem
                    _buildLocationField(
                      controller: _originController,
                      label: 'Origem',
                      icon: Icons.location_on,
                      color: Colors.green,
                      onTap: _searchOrigin,
                    ),

                    const SizedBox(height: 16),

                    // Destino
                    _buildLocationField(
                      controller: _destinationController,
                      label: 'Destino',
                      icon: Icons.location_city,
                      color: Colors.red,
                      onTap: _searchDestination,
                    ),

                    const SizedBox(height: 24),

                    // Data e hora
                    _buildDateTimeField(),

                    const SizedBox(height: 24),

                    // Vagas
                    _buildSeatsSelector(),

                    const SizedBox(height: 24),

                    // Descrição
                    _buildDescriptionField(),

                    const SizedBox(height: 32),

                    // Botão de enviar
                    _buildSubmitButton(),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  /// Campo de localização
  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.text.isEmpty ? 'Toque para buscar' : controller.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: controller.text.isEmpty ? Colors.grey[400] : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  /// Campo de data e hora
  Widget _buildDateTimeField() {
    return InkWell(
      onTap: _selectDateTime,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFF2196F3), size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data e Hora',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedDateTime != null
                        ? DateFormat("dd/MM/yyyy 'às' HH:mm").format(_selectedDateTime!)
                        : 'Toque para selecionar',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedDateTime != null ? Colors.black87 : Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// Seletor de vagas
  Widget _buildSeatsSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.people, color: Color(0xFF2196F3), size: 28),
              SizedBox(width: 16),
              Text(
                'Vagas Disponíveis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSeatButton(1),
              _buildSeatButton(2),
              _buildSeatButton(3),
              _buildSeatButton(4),
            ],
          ),
        ],
      ),
    );
  }

  /// Botão de seleção de vagas
  Widget _buildSeatButton(int seats) {
    final isSelected = _availableSeats == seats;
    
    return InkWell(
      onTap: () {
        setState(() {
          _maxSeats = seats;
          _availableSeats = seats;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2196F3) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              '$seats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Campo de descrição
  Widget _buildDescriptionField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description, color: Color(0xFF2196F3), size: 28),
              SizedBox(width: 16),
              Text(
                'Descrição (Opcional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ex: Vou direto para o campus, horário flexível',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2196F3)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  /// Botão de enviar
  Widget _buildSubmitButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
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
            : const Text(
                'Publicar Carona',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

/// Diálogo de busca de endereço
class _SearchAddressDialog extends StatefulWidget {
  final String title;

  const _SearchAddressDialog({required this.title});

  @override
  State<_SearchAddressDialog> createState() => _SearchAddressDialogState();
}

class _SearchAddressDialogState extends State<_SearchAddressDialog> {
  final GoogleMapsService _googleMapsService = GoogleMapsService();
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<GeocodingResult> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final result = await _googleMapsService.geocodeAddress(query);
      
      if (result != null && mounted) {
        setState(() {
          _results = [result];
          _isSearching = false;
        });
      } else if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Buscar ${widget.title}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Digite o endereço',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _results = [];
                          });
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _searchAddress(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _results.isEmpty && !_isSearching
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Digite um endereço para buscar'
                            : 'Nenhum resultado encontrado',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.red),
                          title: Text(result.formattedAddress),
                          onTap: () {
                            Navigator.of(context).pop(result);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

