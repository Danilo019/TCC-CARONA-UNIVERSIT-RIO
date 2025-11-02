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

  const MapWidget({
    super.key,
    this.initialLocation,
    this.rides = const [],
    this.onRideTap,
    this.onMapTap,
    this.showUserLocation = true,
    this.showRideMarkers = true,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _mapController;
  CameraPosition? _initialCameraPosition;

  // Conjunto de marcadores
  final Set<Marker> _markers = {};

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
  }

  /// Atualiza os marcadores no mapa baseado nas caronas
  void _updateMarkers() {
    if (!widget.showRideMarkers) return;

    _markers.clear();

    // Adiciona marcadores para cada carona
    for (var ride in widget.rides) {
      if (!ride.isAvailable) continue;

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
    }

    if (mounted) {
      setState(() {});
    }
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

