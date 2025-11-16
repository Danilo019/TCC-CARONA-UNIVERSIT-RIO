import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../components/address_autocomplete.dart';
import '../components/map_widget.dart';
import '../config/maps_config.dart';
import '../models/location.dart';
import '../models/ride.dart';
import '../models/ride_request.dart';
import '../models/vehicle_validation_status.dart';
import '../providers/auth_provider.dart';
import '../services/google_maps_service.dart';
import '../services/location_service.dart';
import '../services/nominatim_service.dart';
import '../services/notification_service.dart';
import '../services/ride_request_service.dart';
import '../services/rides_service.dart';
import '../services/vehicle_service.dart';

/// Tela para oferecer uma nova carona e gerenciar caronas existentes
class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

enum RideDirection { toCampus, fromCampus }

class _OfferRideScreenState extends State<OfferRideScreen>
    with SingleTickerProviderStateMixin {
  final RidesService _ridesService = RidesService();
  final RideRequestService _requestService = RideRequestService();
  final GoogleMapsService _googleMapsService = GoogleMapsService();
  final NotificationService _notificationService = NotificationService();
  final VehicleService _vehicleService = VehicleService();

  late TabController _tabController;

  // Estados das abas (removido - agora usa TabController)

  // Estados do formulário de nova carona
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _descriptionController = TextEditingController();

  Location? _originLocation;
  Location? _destinationLocation;
  final List<Location> _pickupPoints = []; // Pontos de embarque
  List<Location>? _routePoints; // Pontos da rota calculada
  DateTime? _selectedDateTime;
  int _maxSeats = 4;
  int _availableSeats = 4;
  static const int _startRideLeadTimeMinutes = 15;
  static const double _campusDistanceToleranceKm = 0.2;
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  bool _isLoadingRoute = false;
  String? _errorMessage;

  RideDirection _rideDirection = RideDirection.toCampus;

  Location get _campusLocation => MapsConfig.udfCampusLocation;

  bool get _isOriginLocked => _rideDirection == RideDirection.fromCampus;

  bool get _isDestinationLocked => _rideDirection == RideDirection.toCampus;

  // Estados do gerenciamento de caronas
  List<Ride> _myRides = [];
  final Map<String, List<RideRequest>> _requestsByRide = {};
  bool _isLoadingRides = true;
  int _selectedFilter = 0; // 0: Todas, 1: Ativas, 2: Concluídas, 3: Canceladas

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Carrega caronas quando mudar para aba de gerenciamento
      if (_tabController.index == 1 && _myRides.isEmpty) {
        _loadMyRides();
      }
    });
    _applyRideDirection(_rideDirection, shouldNotify: false);
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Carrega localização atual do usuário como sugestão (opcional)
  Future<void> _loadCurrentLocation() async {
    // Não carrega automaticamente - usuário define origem manualmente
    setState(() {
      _isLoadingLocation = false;
    });
  }

  void _applyRideDirection(
    RideDirection direction, {
    bool shouldNotify = true,
  }) {
    final campus = _campusLocation;
    void updater() {
      _rideDirection = direction;
      _errorMessage = null;
      _routePoints = null;
      _pickupPoints.clear();

      final isDestinationLocked = direction == RideDirection.toCampus;
      final isOriginLocked = direction == RideDirection.fromCampus;

      if (isDestinationLocked) {
        _destinationLocation = campus;
        _destinationController.text = campus.address ?? 'Campus UDF';
      } else if (_destinationLocation != null &&
          _destinationLocation == campus) {
        _destinationLocation = null;
        _destinationController.clear();
      }

      if (isOriginLocked) {
        _originLocation = campus;
        _originController.text = campus.address ?? 'Campus UDF';
      } else if (_originLocation != null && _originLocation == campus) {
        _originLocation = null;
        _originController.clear();
      }
    }

    if (shouldNotify) {
      setState(updater);
    } else {
      updater();
    }
  }

  /// Atualiza estado com localização selecionada (texto ou mapa)
  void _applyLocationSelection({
    required bool isOrigin,
    required GeocodingResult result,
  }) {
    if ((isOrigin && _isOriginLocked) || (!isOrigin && _isDestinationLocked)) {
      return;
    }

    final updatedLocation = result.location.copyWith(
      address: result.formattedAddress,
    );

    setState(() {
      if (isOrigin) {
        _originLocation = updatedLocation;
        _originController.text = result.formattedAddress;
      } else {
        _destinationLocation = updatedLocation;
        _destinationController.text = result.formattedAddress;
      }

      // Sempre que origem ou destino mudarem, invalidamos rota e pontos anteriores
      _routePoints = null;
      _pickupPoints.clear();
      _errorMessage = null;
    });
  }

  /// Limpa seleção quando usuário altera o texto manualmente
  void _handleLocationEdition({required bool isOrigin}) {
    if ((isOrigin && _isOriginLocked) || (!isOrigin && _isDestinationLocked)) {
      return;
    }

    final hasLocation = isOrigin
        ? _originLocation != null
        : _destinationLocation != null;

    if (!hasLocation) {
      return;
    }

    setState(() {
      if (isOrigin) {
        _originLocation = null;
      } else {
        _destinationLocation = null;
      }
      _routePoints = null;
      _pickupPoints.clear();
    });
  }

  /// Limpa completamente a seleção e o campo associado
  void _clearLocation({required bool isOrigin}) {
    if ((isOrigin && _isOriginLocked) || (!isOrigin && _isDestinationLocked)) {
      return;
    }

    setState(() {
      if (isOrigin) {
        _originLocation = null;
        _originController.clear();
      } else {
        _destinationLocation = null;
        _destinationController.clear();
      }
      _routePoints = null;
      _pickupPoints.clear();
    });
  }

  /// Abre seletor no mapa e aplica resultado
  Future<void> _handleMapSelection({required bool isOrigin}) async {
    if ((isOrigin && _isOriginLocked) || (!isOrigin && _isDestinationLocked)) {
      return;
    }

    final title = isOrigin ? 'Origem' : 'Destino';
    final initialLocation = isOrigin
        ? _originLocation ?? _destinationLocation
        : _destinationLocation ?? _originLocation;

    final result = await _showMapPicker(
      title: title,
      initialLocation: initialLocation,
    );

    if (result != null && mounted) {
      _applyLocationSelection(isOrigin: isOrigin, result: result);
    }
  }

  /// Mostra mapa interativo para selecionar localização e retorna resultado
  Future<GeocodingResult?> _showMapPicker({
    required String title,
    Location? initialLocation,
  }) {
    return showDialog<GeocodingResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _MapLocationPicker(title: title, initialLocation: initialLocation),
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

    if (_isOriginLocked) {
      final distanceToCampus =
          LocationService.calculateDistanceBetweenLocations(
            _originLocation!,
            _campusLocation,
          );
      if (distanceToCampus > _campusDistanceToleranceKm) {
        _showError('A origem deve ser o campus da UDF.');
        return;
      }
    }

    if (_isDestinationLocked) {
      final distanceToCampus =
          LocationService.calculateDistanceBetweenLocations(
            _destinationLocation!,
            _campusLocation,
          );
      if (distanceToCampus > _campusDistanceToleranceKm) {
        _showError('O destino deve ser o campus da UDF.');
        return;
      }
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

      final vehicle = await _vehicleService.getVehicleByDriver(user.uid);
      if (vehicle == null) {
        await _showVehicleStatusDialog(
          title: 'Cadastre seu veículo',
          message:
              'Para oferecer caronas, cadastre seu veículo e aguarde a validação.',
        );
        return;
      }

      if (!vehicle.isComplete) {
        await _showVehicleStatusDialog(
          title: 'Cadastro incompleto',
          message:
              'Conclua todas as informações e documentos do seu veículo antes de oferecer uma carona.',
        );
        return;
      }

      if (vehicle.validationStatus != VehicleValidationStatus.approved) {
        await _showVehicleStatusDialog(
          title: 'Veículo em validação',
          message:
              'Seu veículo ainda não foi aprovado. Assim que a validação for concluída você poderá oferecer caronas.',
        );
        return;
      }

      final ride = Ride(
        id: '', // Será gerado pelo Firestore
        driverId: user.uid,
        driverName: user.displayNameOrEmail,
        driverPhotoURL: user.photoURL,
        origin: _originLocation!,
        destination: _destinationLocation!,
        pickupPoints: _pickupPoints,
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
        try {
          await _notificationService.refreshRemindersIfEnabled(user.uid);
        } catch (error) {
          if (kDebugMode) {
            print('⚠ Falha ao atualizar lembretes após criar carona: $error');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Carona criada com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          Navigator.of(context).pop(true);
        }
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

  /// Adiciona ponto de embarque no mapa
  Future<void> _addPickupPoint() async {
    if (_originLocation == null || _destinationLocation == null) {
      _showError('Defina origem e destino primeiro');
      return;
    }

    Location? selectedLocation;

    await showDialog<Location>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Selecionar Ponto de Embarque'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                body: Stack(
                  children: [
                    // Mapa
                    MapWidget(
                      initialLocation: _originLocation,
                      rides: const [],
                      showUserLocation: true,
                      showRideMarkers: false,
                      onMapTap: (location) {
                        selectedLocation = location;
                        setDialogState(() {});
                      },
                    ),

                    // Instruções no topo
                    Positioned(
                      top: 10,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedLocation == null
                                    ? 'Toque no mapa para selecionar um ponto'
                                    : 'Ponto selecionado. Toque novamente para alterar.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Marcador central (selecionado) - só aparece após seleção
                    if (selectedLocation != null)
                      Center(
                        child: IgnorePointer(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.orange.withValues(alpha: 0.7),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.place,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Botão de confirmar na parte inferior
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        children: [
                          if (selectedLocation != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: Colors.orange[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Lat: ${selectedLocation!.latitude.toStringAsFixed(6)}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          'Lng: ${selectedLocation!.longitude.toStringAsFixed(6)}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: selectedLocation == null
                                  ? null
                                  : () async {
                                      if (selectedLocation != null) {
                                        // Mostra loading
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );

                                        final geocodeResult =
                                            await _googleMapsService
                                                .reverseGeocode(
                                                  selectedLocation!,
                                                );

                                        if (mounted) {
                                          Navigator.pop(
                                            context,
                                          ); // Fecha loading

                                          final finalLocation =
                                              geocodeResult?.location ??
                                              selectedLocation!;
                                          final address =
                                              geocodeResult?.formattedAddress ??
                                              '${finalLocation.latitude.toStringAsFixed(6)}, ${finalLocation.longitude.toStringAsFixed(6)}';

                                          setState(() {
                                            _pickupPoints.add(
                                              finalLocation.copyWith(
                                                address: address,
                                              ),
                                            );
                                            _routePoints =
                                                null; // Limpa rota para recalcular
                                          });

                                          Navigator.pop(
                                            context,
                                          ); // Fecha diálogo do mapa

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Ponto de embarque adicionado: $address',
                                              ),
                                              backgroundColor: Colors.green,
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedLocation == null
                                    ? Colors.grey
                                    : const Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                selectedLocation == null
                                    ? 'Selecione um ponto no mapa'
                                    : 'Confirmar Ponto de Embarque',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Calcula e exibe rota no mapa
  Future<void> _showRoute() async {
    if (_originLocation == null || _destinationLocation == null) {
      _showError('Defina origem e destino primeiro');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoadingRoute = true;
      _errorMessage = null;
    });

    try {
      if (kDebugMode) {
        print('🔍 Calculando rota...');
        print(
          '  Origem: ${_originLocation!.latitude}, ${_originLocation!.longitude}',
        );
        print(
          '  Destino: ${_destinationLocation!.latitude}, ${_destinationLocation!.longitude}',
        );
        print('  Pontos de embarque: ${_pickupPoints.length}');
      }

      final route = await _googleMapsService.getDirections(
        origin: _originLocation!,
        destination: _destinationLocation!,
        waypoints: _pickupPoints.isNotEmpty ? _pickupPoints : null,
      );

      if (!mounted) return;

      if (route != null && route.waypoints.isNotEmpty) {
        if (kDebugMode) {
          print(
            '✓ Rota calculada com sucesso: ${route.distanceKm.toStringAsFixed(2)} km',
          );
        }

        setState(() {
          _routePoints = route.waypoints;
          _isLoadingRoute = false;
          _errorMessage = null;
        });

        // Mostra informações da rota
        final distance = route.distanceKm;
        final duration = route.duration;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rota calculada: ${distance.toStringAsFixed(1)} km • ${duration.inMinutes} min',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        if (kDebugMode) {
          print('✗ Não foi possível calcular a rota - route é null ou vazio');
        }

        setState(() {
          _isLoadingRoute = false;
          _routePoints = null;
        });

        // Mostra mensagem informando que usou cálculo local
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rota estimada (cálculo local)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'API não disponível. Distância e tempo são estimados.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('✗ Erro ao calcular rota: $e');
        print('  Stack trace: $stackTrace');
      }

      if (!mounted) return;

      setState(() {
        _isLoadingRoute = false;
        _routePoints = null;
      });

      // Mostra mensagem de erro com detalhes
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Erro ao calcular rota',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Verifique sua conexão e tente novamente.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
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

  Future<void> _showVehicleStatusDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushNamed('/vehicle-register');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('Atualizar veículo'),
          ),
        ],
      ),
    );
  }

  /// Carrega caronas do motorista
  Future<void> _loadMyRides() async {
    setState(() {
      _isLoadingRides = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        setState(() {
          _isLoadingRides = false;
        });
        return;
      }

      // Busca todas as caronas do motorista via stream
      final ridesStream = _ridesService.watchRidesByDriver(user.uid);

      ridesStream.listen((rides) {
        if (mounted) {
          setState(() {
            _myRides = rides;
            _loadRequestsForRides(rides);
            _isLoadingRides = false;
          });
        }
      });

      // Força atualização inicial (o stream já vai atualizar depois)
      if (mounted) {
        setState(() {
          _isLoadingRides = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao carregar caronas: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingRides = false;
        });
      }
    }
  }

  /// Carrega solicitações para cada carona
  void _loadRequestsForRides(List<Ride> rides) {
    for (final ride in rides) {
      _requestService.watchRequestsByRide(ride.id).listen((requests) {
        if (mounted) {
          setState(() {
            _requestsByRide[ride.id] = requests;
          });
        }
      });
    }
  }

  /// Filtra caronas baseado no filtro selecionado
  List<Ride> _getFilteredRides() {
    List<Ride> filtered = List.from(_myRides);

    switch (_selectedFilter) {
      case 1: // Ativas
        filtered = filtered.where((r) => r.status == 'active').toList();
        break;
      case 2: // Concluídas
        filtered = filtered.where((r) => r.status == 'completed').toList();
        break;
      case 3: // Canceladas
        filtered = filtered.where((r) => r.status == 'cancelled').toList();
        break;
    }

    // Ordena por data (mais recente primeiro)
    filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return filtered;
  }

  /// Aceita uma solicitação
  Future<void> _acceptRequest(RideRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aceitar Solicitação'),
        content: Text(
          'Deseja aceitar a solicitação de ${request.passengerName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('Aceitar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _requestService.acceptRequest(request.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitação aceita com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadMyRides(); // Recarrega
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao aceitar solicitação'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Rejeita uma solicitação
  Future<void> _rejectRequest(RideRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeitar Solicitação'),
        content: Text(
          'Deseja rejeitar a solicitação de ${request.passengerName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _requestService.rejectRequest(request.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitação rejeitada'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadMyRides(); // Recarrega
        }
      }
    }
  }

  /// Abre navegação externa permitindo escolher o app de navegação
  Future<void> _launchNavigation(Ride ride) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Abrir navegação',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.map_outlined,
                    color: Color(0xFF4285F4),
                  ),
                  title: const Text('Google Maps'),
                  subtitle: const Text(
                    'Traçar rota com origem e destino da carona',
                  ),
                  onTap: () => Navigator.pop(context, 'google'),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(
                    Icons.alt_route,
                    color: Color(0xFF1C8AE4),
                  ),
                  title: const Text('Waze'),
                  subtitle: const Text('Abrir rota no Waze'),
                  onTap: () => Navigator.pop(context, 'waze'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || choice == null) {
      return;
    }

    bool success = false;

    if (choice == 'google') {
      success = await _googleMapsService.launchNavigation(
        origin: ride.origin,
        destination: ride.destination,
      );
    } else if (choice == 'waze') {
      success = await _googleMapsService.launchWazeNavigation(
        destination: ride.destination,
      );
    }

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir a navegação'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Finaliza uma carona
  Future<void> _completeRide(Ride ride) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Carona'),
        content: const Text(
          'Deseja finalizar esta carona? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _ridesService.completeRide(ride.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Carona finalizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadMyRides(); // Recarrega
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao finalizar carona'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Inicia uma carona
  Future<void> _startRide(
    Ride ride, {
    required List<RideRequest> passengers,
  }) async {
    final canStart = _canStartRide(ride, passengersCount: passengers.length);
    if (!canStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para iniciar a viagem é necessário ter ao menos um passageiro confirmado '
            'e aguardar a janela de $_startRideLeadTimeMinutes minutos antes da partida.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar Viagem'),
        content: Text(
          'Deseja iniciar a viagem para ${ride.destination.address ?? 'o destino'} agora? '
          'Os passageiros serão notificados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final success = await _ridesService.startRide(ride.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viagem iniciada! Notificando passageiros...'),
          backgroundColor: Colors.green,
        ),
      );

      // Atualiza lembretes para motorista e passageiros
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final driverId = authProvider.user?.uid;
        if (driverId != null) {
          await _notificationService.refreshRemindersIfEnabled(driverId);
        }
        for (final request in passengers) {
          await _notificationService.refreshRemindersIfEnabled(
            request.passengerId,
          );
        }
      } catch (error) {
        if (kDebugMode) {
          print('⚠ Falha ao atualizar lembretes após iniciar viagem: $error');
        }
      }

      await _launchNavigation(ride);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Após encerrar a navegação, retorne ao app para finalizar a viagem.',
          ),
          backgroundColor: Color(0xFF1976D2),
        ),
      );

      await _loadMyRides();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível iniciar a viagem. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _canStartRide(Ride ride, {required int passengersCount}) {
    if (ride.status != 'active') {
      return false;
    }

    final now = DateTime.now();
    final startWindow = _startButtonAvailableAt(ride);
    final isWithinAllowedWindow = now.isAfter(startWindow);
    final hasPassengers = passengersCount > 0;

    return hasPassengers && isWithinAllowedWindow;
  }

  DateTime _startButtonAvailableAt(Ride ride) {
    return ride.dateTime.subtract(Duration(minutes: _startRideLeadTimeMinutes));
  }

  bool _isWithinStartWindow(Ride ride) {
    final now = DateTime.now();
    return now.isAfter(_startButtonAvailableAt(ride));
  }

  int _minutesUntilStartWindow(Ride ride) {
    final now = DateTime.now();
    final availability = _startButtonAvailableAt(ride);
    final diff = availability.difference(now).inMinutes;
    return diff > 0 ? diff : 0;
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.add_road), text: 'Nova Carona'),
            Tab(icon: Icon(Icons.manage_history), text: 'Minhas Caronas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNewRideTab(), _buildMyRidesTab()],
      ),
    );
  }

  /// Aba de nova carona
  Widget _buildNewRideTab() {
    return _isLoadingLocation
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDirectionSelector(),
                  const SizedBox(height: 20),

                  // Preview do mapa
                  if (_originLocation != null ||
                      _destinationLocation != null ||
                      _routePoints != null) ...[
                    Container(
                      height: 250,
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
                          initialLocation:
                              _originLocation ?? _destinationLocation,
                          rides: const [],
                          showUserLocation: false,
                          showRideMarkers: false,
                          routePoints: _routePoints,
                          pickupPoints: _pickupPoints,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Origem
                  _buildLocationPicker(
                    isOrigin: true,
                    controller: _originController,
                    label: 'Origem',
                    icon: Icons.location_on,
                    color: Colors.green,
                    location: _originLocation,
                    isLocked: _isOriginLocked,
                  ),

                  const SizedBox(height: 20),

                  // Destino
                  _buildLocationPicker(
                    isOrigin: false,
                    controller: _destinationController,
                    label: 'Destino',
                    icon: Icons.location_city,
                    color: Colors.red,
                    location: _destinationLocation,
                    isLocked: _isDestinationLocked,
                  ),

                  const SizedBox(height: 16),

                  // Botão para adicionar ponto de embarque
                  if (_originLocation != null &&
                      _destinationLocation != null) ...[
                    OutlinedButton.icon(
                      onPressed: _addPickupPoint,
                      icon: const Icon(Icons.add_location),
                      label: const Text('Adicionar Ponto de Embarque'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2196F3),
                        side: const BorderSide(color: Color(0xFF2196F3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Pontos de embarque adicionados
                  if (_pickupPoints.isNotEmpty) ...[
                    ..._pickupPoints.asMap().entries.map((entry) {
                      final index = entry.key;
                      final point = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            point.address ?? 'Ponto de Embarque ${index + 1}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _pickupPoints.removeAt(index);
                                _routePoints =
                                    null; // Limpa rota quando remove ponto
                              });
                            },
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],

                  // Botão Ver Rota
                  if (_originLocation != null &&
                      _destinationLocation != null) ...[
                    ElevatedButton.icon(
                      onPressed: _isLoadingRoute ? null : _showRoute,
                      icon: _isLoadingRoute
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.route),
                      label: const Text('Ver Rota'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else
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
          );
  }

  /// Campo completo com autocomplete e seleção no mapa
  Widget _buildDirectionSelector() {
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
          const Text(
            'Sentido da carona',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.school, size: 18),
                    SizedBox(width: 8),
                    Text('Indo para a UDF'),
                  ],
                ),
                selected: _rideDirection == RideDirection.toCampus,
                onSelected: (selected) {
                  if (selected) {
                    _applyRideDirection(RideDirection.toCampus);
                  }
                },
              ),
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.directions_car, size: 18),
                    SizedBox(width: 8),
                    Text('Saindo da UDF'),
                  ],
                ),
                selected: _rideDirection == RideDirection.fromCampus,
                onSelected: (selected) {
                  if (selected) {
                    _applyRideDirection(RideDirection.fromCampus);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPicker({
    required bool isOrigin,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required Location? location,
    required bool isLocked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AddressAutocomplete(
          label: label,
          hintText: 'Digite o endereço ou selecione no mapa',
          prefixIcon: icon,
          controller: controller,
          countryCodes: const ['br'],
          enabled: !isLocked,
          showClearButton: !isLocked,
          onAddressSelected: (result) {
            final geocodingResult = GeocodingResult(
              formattedAddress: result.displayName,
              location: result.location,
            );
            _applyLocationSelection(
              isOrigin: isOrigin,
              result: geocodingResult,
            );
          },
          onQueryChanged: isLocked
              ? null
              : (_) => _handleLocationEdition(isOrigin: isOrigin),
          onClear: isLocked ? null : () => _clearLocation(isOrigin: isOrigin),
        ),
        const SizedBox(height: 8),
        if (isLocked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF2196F3), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Este ponto é fixo no campus da UDF para este sentido de carona.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _handleMapSelection(isOrigin: isOrigin),
                icon: const Icon(Icons.map),
                label: const Text('Selecionar no mapa'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2196F3),
                  side: const BorderSide(color: Color(0xFF2196F3)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              if (location != null)
                TextButton.icon(
                  onPressed: () => _clearLocation(isOrigin: isOrigin),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Limpar seleção'),
                ),
            ],
          ),
        if (location != null) ...[
          const SizedBox(height: 8),
          _buildLocationPreview(location: location, color: color),
        ],
      ],
    );
  }

  /// Mostra resumo da localização selecionada
  Widget _buildLocationPreview({
    required Location location,
    required Color color,
  }) {
    final address =
        location.address ??
        '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Lat: ${location.latitude.toStringAsFixed(6)} | '
            'Lng: ${location.longitude.toStringAsFixed(6)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
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
                        ? DateFormat(
                            "dd/MM/yyyy 'às' HH:mm",
                          ).format(_selectedDateTime!)
                        : 'Toque para selecionar',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedDateTime != null
                          ? Colors.black87
                          : Colors.grey[400],
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

  /// Aba de minhas caronas
  Widget _buildMyRidesTab() {
    return Column(
      children: [
        // Filtros
        _buildFilters(),

        // Lista de caronas
        Expanded(
          child: _isLoadingRides
              ? const Center(child: CircularProgressIndicator())
              : _getFilteredRides().isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadMyRides,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _getFilteredRides().length,
                    itemBuilder: (context, index) {
                      final ride = _getFilteredRides()[index];
                      return _buildRideCard(ride);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  /// Filtros
  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(0, 'Todas', Icons.all_inclusive),
            const SizedBox(width: 8),
            _buildFilterChip(1, 'Ativas', Icons.check_circle),
            const SizedBox(width: 8),
            _buildFilterChip(2, 'Concluídas', Icons.done_all),
            const SizedBox(width: 8),
            _buildFilterChip(3, 'Canceladas', Icons.cancel),
          ],
        ),
      ),
    );
  }

  /// Chip de filtro
  Widget _buildFilterChip(int index, String label, IconData icon) {
    final isSelected = _selectedFilter == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2196F3) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2196F3) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card de carona
  Widget _buildRideCard(Ride ride) {
    final timeStr = DateFormat('dd/MM/yyyy às HH:mm').format(ride.dateTime);
    final requests = _requestsByRide[ride.id] ?? [];
    final pendingRequests = requests.where((r) => r.isPending).toList();
    final acceptedRequests = requests.where((r) => r.isAccepted).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(ride.status).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getStatusIcon(ride.status),
            color: _getStatusColor(ride.status),
          ),
        ),
        title: Text(
          '${ride.origin.address?.split(',').first ?? 'Origem'} → ${ride.destination.address?.split(',').first ?? 'Destino'}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(timeStr),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Detalhes da carona
                _buildDetailRow(
                  Icons.location_on,
                  Colors.green,
                  'Origem',
                  ride.origin.address ?? 'Não informada',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.location_city,
                  Colors.red,
                  'Destino',
                  ride.destination.address ?? 'Não informado',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.people, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${ride.availableSeats}/${ride.maxSeats} vagas disponíveis',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),

                const Divider(height: 32),

                // Solicitações pendentes
                if (pendingRequests.isNotEmpty) ...[
                  const Text(
                    'Solicitações Pendentes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...pendingRequests.map(
                    (request) => _buildRequestCard(
                      request,
                      onAccept: () => _acceptRequest(request),
                      onReject: () => _rejectRequest(request),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Passageiros confirmados
                if (acceptedRequests.isNotEmpty) ...[
                  const Text(
                    'Passageiros Confirmados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...acceptedRequests.map(
                    (request) => _buildPassengerCard(request),
                  ),
                  const SizedBox(height: 16),
                ],

                // Ações
                if (ride.status == 'active' ||
                    ride.status == 'in_progress') ...[
                  if (ride.status == 'active' && acceptedRequests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildInfoBanner(
                        icon: Icons.person_add_alt_1,
                        backgroundColor: Colors.orange.shade50,
                        foregroundColor: Colors.orange.shade700,
                        title: 'Aguardando passageiros confirmados',
                        subtitle:
                            'Aceite pelo menos um passageiro para liberar o botão "Iniciar viagem".',
                      ),
                    ),
                  if (ride.status == 'active' &&
                      acceptedRequests.isNotEmpty &&
                      !_isWithinStartWindow(ride))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildInfoBanner(
                        icon: Icons.schedule,
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                        title:
                            'Botão disponível $_startRideLeadTimeMinutes minutos antes',
                        subtitle:
                            'Ele aparecerá por volta das ${DateFormat('HH:mm').format(_startButtonAvailableAt(ride))} '
                            '(${_minutesUntilStartWindow(ride)} min restantes).',
                      ),
                    ),
                  if (_canStartRide(
                        ride,
                        passengersCount: acceptedRequests.length,
                      ) &&
                      ride.status == 'active')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _startRide(ride, passengers: acceptedRequests),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Iniciar viagem'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchNavigation(ride),
                          icon: const Icon(Icons.navigation),
                          label: const Text('Navegação'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2196F3),
                            side: const BorderSide(color: Color(0xFF2196F3)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _completeRide(ride),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Finalizar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (ride.status == 'in_progress') ...[
                  const SizedBox(height: 16),
                  _buildInfoBanner(
                    icon: Icons.directions_car_filled,
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    title: 'Viagem em andamento',
                    subtitle: ride.startedAt != null
                        ? 'Iniciada às ${DateFormat('HH:mm').format(ride.startedAt!)}. '
                              'Finalize no app ao término do trajeto.'
                        : 'Finalize no app assim que concluir o trajeto com os passageiros.',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: foregroundColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Linha de detalhe
  Widget _buildDetailRow(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  /// Card de solicitação
  Widget _buildRequestCard(
    RideRequest request, {
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.orange[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: request.passengerPhotoURL != null
              ? NetworkImage(request.passengerPhotoURL!)
              : null,
          child: request.passengerPhotoURL == null
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(request.passengerName),
        subtitle: request.message != null ? Text(request.message!) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: onAccept,
              tooltip: 'Aceitar',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: onReject,
              tooltip: 'Rejeitar',
            ),
          ],
        ),
      ),
    );
  }

  /// Card de passageiro confirmado
  Widget _buildPassengerCard(RideRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.green[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: request.passengerPhotoURL != null
              ? NetworkImage(request.passengerPhotoURL!)
              : null,
          child: request.passengerPhotoURL == null
              ? const Icon(Icons.person)
              : null,
        ),
        title: Text(request.passengerName),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  /// Estado vazio
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma carona encontrada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ofereça sua primeira carona!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Cor do status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Ícone do status
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}

/// Diálogo de seleção de localização no mapa
class _MapLocationPicker extends StatefulWidget {
  final String title;
  final Location? initialLocation;

  const _MapLocationPicker({required this.title, this.initialLocation});

  @override
  State<_MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<_MapLocationPicker> {
  final GoogleMapsService _googleMapsService = GoogleMapsService();
  final TextEditingController _searchController = TextEditingController();

  GoogleMapController? _mapController;
  CameraPosition? _initialCamera;
  Location? _currentSelection;
  String? _addressPreview;
  bool _isReverseGeocoding = false;
  Timer? _reverseTimer;
  LatLng? _pendingTarget;

  @override
  void initState() {
    super.initState();

    final fallbackLocation =
        widget.initialLocation ??
        Location(
          latitude: MapsConfig.defaultLatitude,
          longitude: MapsConfig.defaultLongitude,
        );

    _initialCamera = CameraPosition(
      target: LatLng(fallbackLocation.latitude, fallbackLocation.longitude),
      zoom: MapsConfig.defaultZoom,
    );

    _currentSelection = fallbackLocation;
    _addressPreview = fallbackLocation.address;

    if (fallbackLocation.address != null) {
      _searchController.text = fallbackLocation.address!;
    } else {
      _scheduleReverseGeocoding(fallbackLocation);
    }
  }

  @override
  void dispose() {
    _reverseTimer?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _scheduleReverseGeocoding(Location location) {
    _reverseTimer?.cancel();

    setState(() {
      _isReverseGeocoding = true;
      _currentSelection = location;
    });

    _reverseTimer = Timer(const Duration(milliseconds: 400), () async {
      final result = await _googleMapsService.reverseGeocode(location);
      if (!mounted) return;

      setState(() {
        _isReverseGeocoding = false;
        if (result != null) {
          _currentSelection = result.location;
          _addressPreview = result.formattedAddress;
        } else {
          _currentSelection = location;
          _addressPreview =
              '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
        }
      });
    });
  }

  void _onCameraMove(CameraPosition position) {
    _pendingTarget = position.target;
  }

  void _onCameraIdle() {
    if (_pendingTarget == null) {
      return;
    }

    final newLocation = Location(
      latitude: _pendingTarget!.latitude,
      longitude: _pendingTarget!.longitude,
    );

    _scheduleReverseGeocoding(newLocation);
  }

  void _onAddressSelected(NominatimResult result) {
    final location = result.location.copyWith(address: result.displayName);
    final target = LatLng(location.latitude, location.longitude);

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, MapsConfig.defaultZoom),
    );

    setState(() {
      _currentSelection = location;
      _addressPreview = result.displayName;
      _pendingTarget = target;
      _isReverseGeocoding = false;
    });
  }

  void _confirmSelection() {
    if (_currentSelection == null) {
      return;
    }

    final location = _currentSelection!;
    final address =
        _addressPreview ??
        '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';

    Navigator.of(context).pop(
      GeocodingResult(
        formattedAddress: address,
        location: location.copyWith(address: address),
      ),
    );
  }

  Widget _buildUnsupportedContent(String message, [String? detail]) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildUnsupportedContent(
        'Mapa indisponível na Web',
        'O Google Maps só está disponível nos aplicativos móveis.',
      );
    }

    if (!MapsConfig.isApiKeyConfigured) {
      return _buildUnsupportedContent(
        'API Key do Google Maps não configurada',
        'Configure a chave em lib/config/maps_config.dart antes de selecionar no mapa.',
      );
    }

    if (_initialCamera == null) {
      return _buildUnsupportedContent('Carregando mapa...');
    }

    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Selecionar ${widget.title} no mapa'),
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _initialCamera!,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                onCameraMove: _onCameraMove,
                onCameraIdle: _onCameraIdle,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                compassEnabled: true,
                zoomControlsEnabled: true,
                mapType: MapType.normal,
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: AddressAutocomplete(
                        label: 'Buscar endereço',
                        hintText: 'Digite um endereço ou ponto de referência',
                        prefixIcon: Icons.search,
                        controller: _searchController,
                        countryCodes: const ['br'],
                        onAddressSelected: _onAddressSelected,
                        onQueryChanged: (_) {},
                        onClear: () {},
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Icon(
                      Icons.location_on,
                      color: Colors.red.shade600,
                      size: 48,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _addressPreview ??
                                  'Centralize o mapa no ponto desejado ou busque um endereço.',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (_currentSelection != null)
                              Text(
                                'Lat: ${_currentSelection!.latitude.toStringAsFixed(6)} | '
                                'Lng: ${_currentSelection!.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            if (_isReverseGeocoding) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: const [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Buscando endereço...',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _currentSelection == null
                              ? null
                              : _confirmSelection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: const Text('Confirmar localização'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
