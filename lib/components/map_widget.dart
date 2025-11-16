import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../config/maps_config.dart';
import '../models/location.dart';
import '../models/ride.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Widget customizado para exibir mapa do Google Maps com caronas
class MapWidget extends StatefulWidget {
  final Location? initialLocation;
  final List<Ride> rides;
  final Function(Ride)? onRideTap;
  final Function(Location)? onMapTap;
  final bool showUserLocation;
  final bool showRideMarkers;
  final List<Location>? routePoints; // Pontos da rota para exibir como polyline
  final List<Location>? pickupPoints; // Pontos de embarque para exibir como marcadores especiais

  const MapWidget({
    super.key,
    this.initialLocation,
    this.rides = const [],
    this.onRideTap,
    this.onMapTap,
    this.showUserLocation = true,
    this.showRideMarkers = true,
    this.routePoints,
    this.pickupPoints,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _mapController;
  CameraPosition? _initialCameraPosition;

  // Conjunto de marcadores
  final Set<Marker> _markers = {};
  // Conjunto de polylines (rotas)
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeCameraPosition();
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Atualiza marcadores quando a lista de caronas mudar
    if (widget.rides != oldWidget.rides) {
      _updateMarkers();
    }

    // Atualiza rota quando mudar
    if (widget.routePoints != oldWidget.routePoints) {
      _updateRoute();
    }

    // Move a câmera se a localização inicial mudou
    if (widget.initialLocation != oldWidget.initialLocation) {
      _moveToLocation(widget.initialLocation);
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// Inicializa a posição inicial da câmera
  void _initializeCameraPosition() {
    if (widget.initialLocation != null) {
      _initialCameraPosition = CameraPosition(
        target: LatLng(
          widget.initialLocation!.latitude,
          widget.initialLocation!.longitude,
        ),
        zoom: MapsConfig.defaultZoom,
      );
    } else {
      // Usa localização padrão (Campus UDF)
      _initialCameraPosition = const CameraPosition(
        target: LatLng(
          MapsConfig.defaultLatitude,
          MapsConfig.defaultLongitude,
        ),
        zoom: MapsConfig.defaultZoom,
      );
    }
    
    // Atualiza marcadores após inicializar
    _updateMarkers();
    _updateRoute();
  }

  /// Atualiza os marcadores no mapa baseado nas caronas
  void _updateMarkers() {
    if (!widget.showRideMarkers) {
      if (kDebugMode) {
        print('📍 Marcadores de caronas desabilitados');
      }
      return;
    }

    _markers.clear();

    if (kDebugMode) {
      print('📍 Atualizando marcadores: ${widget.rides.length} caronas');
    }

    // Adiciona marcadores para cada carona
    int markersAdded = 0;
    for (var ride in widget.rides) {
      // Verifica se a carona está disponível
      if (!ride.isAvailable) {
        if (kDebugMode) {
          print('  ⏭ Pulando carona ${ride.id}: status=${ride.status}, vagas=${ride.availableSeats}');
        }
        continue;
      }

      // Verifica se a localização é válida
      if (!ride.origin.isValid) {
        if (kDebugMode) {
          print('  ⚠ Localização inválida para carona ${ride.id}');
        }
        continue;
      }

      final marker = Marker(
        markerId: MarkerId(ride.id),
        position: LatLng(
          ride.origin.latitude,
          ride.origin.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        onTap: () {
          if (widget.onRideTap != null) {
            widget.onRideTap!(ride);
          }
        },
        infoWindow: InfoWindow(
          title: ride.driverName,
          snippet: '${ride.availableSeats} vagas disponíveis',
        ),
      );

      _markers.add(marker);
      markersAdded++;
    }

    if (kDebugMode) {
      print('✓ $markersAdded marcadores adicionados ao mapa');
    }

    if (mounted) {
      setState(() {});
    }
  }

  /// Atualiza a rota no mapa (polyline)
  void _updateRoute() {
    _polylines.clear();

    if (widget.routePoints == null || widget.routePoints!.isEmpty) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    // Converte pontos da rota para LatLng
    final points = widget.routePoints!
        .map((location) => LatLng(location.latitude, location.longitude))
        .toList();

    // Cria polyline da rota
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: points,
      color: const Color(0xFF2196F3),
      width: 5,
      patterns: [],
    );

    _polylines.add(polyline);

    // Adiciona marcadores para pontos de embarque
    if (widget.pickupPoints != null && widget.pickupPoints!.isNotEmpty) {
      int pickupIndex = 0;
      for (var pickupPoint in widget.pickupPoints!) {
        final marker = Marker(
          markerId: MarkerId('pickup_$pickupIndex'),
          position: LatLng(pickupPoint.latitude, pickupPoint.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: 'Ponto de Embarque ${pickupIndex + 1}',
            snippet: pickupPoint.address ?? '',
          ),
        );
        _markers.add(marker);
        pickupIndex++;
      }
    }

    // Adiciona marcadores para origem e destino se a rota está sendo exibida
    if (widget.routePoints!.isNotEmpty) {
      final origin = widget.routePoints!.first;
      final destination = widget.routePoints!.last;

      // Marcador de origem
      _markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(origin.latitude, origin.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Origem',
            snippet: origin.address ?? '',
          ),
        ),
      );

      // Marcador de destino
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destination.latitude, destination.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destino',
            snippet: destination.address ?? '',
          ),
        ),
      );

      // Ajusta câmera para mostrar toda a rota
      _fitBounds();
    }

    if (mounted) {
      setState(() {});
    }
  }

  /// Ajusta a câmera para mostrar toda a rota
  void _fitBounds() {
    if (_mapController == null || widget.routePoints == null || widget.routePoints!.isEmpty) {
      return;
    }

    final points = widget.routePoints!
        .map((location) => LatLng(location.latitude, location.longitude))
        .toList();

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  /// Move a câmera para uma localização específica
  void _moveToLocation(Location? location) {
    if (location == null || _mapController == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        MapsConfig.defaultZoom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Google Maps não suportado na web
    if (kIsWeb) {
      return _buildErrorWidget(
        'Mapa não disponível na web',
        'O Google Maps está disponível apenas em dispositivos móveis.',
      );
    }

    // Verifica se a API Key está configurada
    if (!MapsConfig.isApiKeyConfigured) {
      return _buildErrorWidget(
        'API Key do Google Maps não configurada',
        'Configure a API Key em lib/config/maps_config.dart',
      );
    }

    // Verifica se temos localização inicial válida
    if (_initialCameraPosition == null) {
      return _buildErrorWidget(
        'Carregando mapa...',
        null,
      );
    }

    return GoogleMap(
      initialCameraPosition: _initialCameraPosition!,
      onMapCreated: (controller) {
        _mapController = controller;
        if (kDebugMode) {
          print('✓ Mapa do Google Maps criado com sucesso');
        }
      },
      onCameraMoveStarted: () {
        if (kDebugMode) {
          print('📍 Câmera do mapa movida');
        }
      },
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: widget.showUserLocation,
      myLocationButtonEnabled: widget.showUserLocation,
      zoomControlsEnabled: true,
      mapType: MapType.normal,
      compassEnabled: true,
      onTap: (LatLng position) {
        if (widget.onMapTap != null) {
          widget.onMapTap!(
            Location(
              latitude: position.latitude,
              longitude: position.longitude,
            ),
          );
        }
      },
    );
  }

  /// Widget de erro ou loading
  Widget _buildErrorWidget(String message, String? detail) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  detail,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

