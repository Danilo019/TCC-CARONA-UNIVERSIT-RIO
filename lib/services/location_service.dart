import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import '../models/location.dart';

/// Serviço para gerenciar permissões e obter localização do dispositivo
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  LocationPermission? _lastPermissionStatus;

  // Getters
  Position? get currentPosition => _currentPosition;
  LocationPermission? get lastPermissionStatus => _lastPermissionStatus;
  bool get hasLocation => _currentPosition != null;

  // ===========================================================================
  // PERMISSÕES
  // ===========================================================================

  /// Verifica e solicita permissão de localização
  Future<bool> requestLocationPermission() async {
    try {
      // Verifica se o serviço de localização está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('✗ Serviço de localização desabilitado');
        }
        return false;
      }

      // Verifica status da permissão
      _lastPermissionStatus = await Geolocator.checkPermission();
      
      if (_lastPermissionStatus == LocationPermission.denied) {
        // Solicita permissão
        _lastPermissionStatus = await Geolocator.requestPermission();
      }

      if (_lastPermissionStatus == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('✗ Permissão de localização negada permanentemente');
        }
        return false;
      }

      if (_lastPermissionStatus == LocationPermission.whileInUse ||
          _lastPermissionStatus == LocationPermission.always) {
        if (kDebugMode) {
          print('✓ Permissão de localização concedida');
        }
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao solicitar permissão: $e');
      }
      return false;
    }
  }

  /// Verifica se a permissão já foi concedida
  Future<bool> hasLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      _lastPermissionStatus = await Geolocator.checkPermission();
      
      return _lastPermissionStatus == LocationPermission.whileInUse ||
             _lastPermissionStatus == LocationPermission.always;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao verificar permissão: $e');
      }
      return false;
    }
  }

  /// Abre as configurações do app para o usuário habilitar a permissão
  Future<bool> openLocationSettings() async {
    try {
      // Primeiro tenta abrir as configurações de localização do sistema
      try {
        final opened = await Geolocator.openLocationSettings();
        if (opened) return true;
      } catch (_) {
        // Ignora e tenta abrir as configurações do app
      }

      // Fallback: abre as configurações do app
      return await openAppSettings();
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao abrir configurações: $e');
      }
      return false;
    }
  }

  // ===========================================================================
  // LOCALIZAÇÃO
  // ===========================================================================

  /// Obtém a localização atual do dispositivo
  Future<Position?> getCurrentLocation() async {
    try {
      // Verifica permissão primeiro
      bool hasPermission = await hasLocationPermission();
      if (!hasPermission) {
        bool granted = await requestLocationPermission();
        if (!granted) {
          if (kDebugMode) {
            print('✗ Sem permissão para obter localização');
          }
          return null;
        }
      }

      // Obtém localização atual
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (kDebugMode) {
        print('✓ Localização obtida: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      }

      return _currentPosition;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao obter localização: $e');
      }
      return null;
    }
  }

  /// Obtém localização em formato customizado
  Future<Location?> getCurrentLocationModel() async {
    try {
      final position = await getCurrentLocation();
      if (position == null) return null;

      return Location(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao obter modelo de localização: $e');
      }
      return null;
    }
  }

  /// Monitora mudanças na localização (stream)
  Stream<Position> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Atualiza a cada 10 metros
      ),
    );
  }

  /// Calcula a distância entre duas coordenadas (em km)
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    ) / 1000; // Converte de metros para km
  }

  /// Calcula a distância entre duas localizações
  static double calculateDistanceBetweenLocations(Location start, Location end) {
    return calculateDistance(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  /// Limpa a localização em cache
  void clearLocation() {
    _currentPosition = null;
  }

  /// Obtém último status de permissão
  bool get isPermissionGranted {
    return _lastPermissionStatus == LocationPermission.whileInUse ||
           _lastPermissionStatus == LocationPermission.always;
  }

  /// Verifica se o serviço de localização está habilitado
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      return false;
    }
  }
}

