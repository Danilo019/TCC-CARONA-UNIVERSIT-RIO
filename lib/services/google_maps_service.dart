import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/maps_config.dart';
import '../models/location.dart';
import 'location_service.dart';

/// Modelos para respostas das APIs
class GeocodingResult {
  final String formattedAddress;
  final Location location;

  GeocodingResult({
    required this.formattedAddress,
    required this.location,
  });
}

class Route {
  final double distanceKm;
  final Duration duration;
  final List<Location> waypoints;

  Route({
    required this.distanceKm,
    required this.duration,
    required this.waypoints,
  });
}

class DistanceMatrixResult {
  final double distanceKm;
  final Duration duration;

  DistanceMatrixResult({
    required this.distanceKm,
    required this.duration,
  });
}

/// Serviço para interagir com as APIs do Google Maps
class GoogleMapsService {
  static final GoogleMapsService _instance = GoogleMapsService._internal();
  factory GoogleMapsService() => _instance;
  GoogleMapsService._internal();

  final String _baseUrl = 'https://maps.googleapis.com/maps/api';
  final String _apiKey = MapsConfig.apiKey;

  // ===========================================================================
  // GEOCODING API - Converte endereços em coordenadas e vice-versa
  // ===========================================================================

  /// Converte um endereço em coordenadas (Geocoding)
  Future<GeocodingResult?> geocodeAddress(String address) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocode/json?address=${Uri.encodeComponent(address)}&key=$_apiKey',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final location = result['geometry']['location'];

          return GeocodingResult(
            formattedAddress: result['formatted_address'],
            location: Location(
              latitude: (location['lat'] as num).toDouble(),
              longitude: (location['lng'] as num).toDouble(),
              address: result['formatted_address'],
            ),
          );
        } else {
          if (kDebugMode) {
            print('✗ Geocoding falhou: ${data['status']}');
          }
          return null;
        }
      } else {
        if (kDebugMode) {
          print('✗ Erro HTTP no Geocoding: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro no Geocoding: $e');
      }
      return null;
    }
  }

  /// Converte coordenadas em endereço (Reverse Geocoding)
  /// Tenta usar API primeiro, se falhar retorna coordenadas sem endereço formatado
  Future<GeocodingResult?> reverseGeocode(Location location) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocode/json?latlng=${location.latitude},${location.longitude}&key=$_apiKey',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];

          return GeocodingResult(
            formattedAddress: result['formatted_address'],
            location: location.copyWith(
              address: result['formatted_address'],
            ),
          );
        } else {
          // Fallback: retorna coordenadas sem endereço formatado
          if (kDebugMode) {
            final status = data['status'] as String;
            if (status == 'REQUEST_DENIED') {
              print('⚠ Reverse Geocoding requer billing. Usando apenas coordenadas.');
            } else {
              print('✗ Reverse Geocoding falhou: $status');
            }
          }
          // Retorna localização com coordenadas (sem endereço formatado)
          return GeocodingResult(
            formattedAddress: '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
            location: location,
          );
        }
      } else {
        // Fallback: retorna coordenadas
        return GeocodingResult(
          formattedAddress: '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
          location: location,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Reverse Geocoding falhou, usando coordenadas: $e');
      }
      // Fallback: retorna coordenadas
      return GeocodingResult(
        formattedAddress: '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
        location: location,
      );
    }
  }

  /// Converte múltiplos endereços em coordenadas
  Future<List<GeocodingResult>> geocodeAddresses(List<String> addresses) async {
    final results = <GeocodingResult>[];

    for (final address in addresses) {
      final result = await geocodeAddress(address);
      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  // ===========================================================================
  // DIRECTIONS API - Calcula rotas entre dois pontos
  // ===========================================================================

  /// Obtém rota entre origem e destino
  Future<Route?> getDirections({
    required Location origin,
    required Location destination,
    String travelMode = 'driving', // driving, walking, bicycling, transit
    bool avoidHighways = false,
    bool avoidTolls = false,
  }) async {
    try {
      final avoid = <String>[];
      
      if (avoidHighways) avoid.add('highways');
      if (avoidTolls) avoid.add('tolls');

      final avoidParam = avoid.isNotEmpty ? '&avoid=${avoid.join('|')}' : '';
      
      final url = Uri.parse(
        '$_baseUrl/directions/json?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=$travelMode'
        '$avoidParam'
        '&key=$_apiKey',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Distância total em km
          final distance = (leg['distance']['value'] as int) / 1000.0;

          // Duração total
          final durationSeconds = leg['duration']['value'] as int;
          final duration = Duration(seconds: durationSeconds);

          // Waypoints da rota
          final waypointsList = <Location>[];
          
          // Decodifica polyline (simplificado - na prática, use um decoder)
          // Por enquanto, retorna apenas origem e destino
          waypointsList.add(origin);
          
          // Pode decodificar polyline aqui para obter todos os pontos
          // Por simplicidade, retornamos apenas origem e destino
          
          waypointsList.add(destination);

          return Route(
            distanceKm: distance,
            duration: duration,
            waypoints: waypointsList,
          );
        } else {
          if (kDebugMode) {
            print('✗ Directions falhou: ${data['status']}');
          }
          return null;
        }
      } else {
        if (kDebugMode) {
          print('✗ Erro HTTP no Directions: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro no Directions: $e');
      }
      return null;
    }
  }

  // ===========================================================================
  // DISTANCE MATRIX API - Calcula distância e tempo entre múltiplos pontos
  // ===========================================================================

  /// Calcula distância e tempo entre origem e destino
  /// Usa cálculo local (Haversine) como fallback quando API não está disponível
  /// Não requer billing do Google Cloud
  Future<DistanceMatrixResult?> getDistanceMatrix({
    required Location origin,
    required Location destination,
    String travelMode = 'driving',
  }) async {
    // Tenta usar API do Google primeiro (se billing estiver configurado)
    try {
      final result = await _getDistanceMatrixFromAPI(origin, destination, travelMode);
      if (result != null) {
        return result;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ API não disponível, usando cálculo local: $e');
      }
    }

    // Fallback: usa cálculo local (não requer billing)
    return _calculateDistanceLocal(origin, destination, travelMode);
  }

  /// Calcula distância usando API do Google (requer billing ativo)
  Future<DistanceMatrixResult?> _getDistanceMatrixFromAPI(
    Location origin,
    Location destination,
    String travelMode,
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/distancematrix/json?origins=${origin.latitude},${origin.longitude}'
        '&destinations=${destination.latitude},${destination.longitude}'
        '&mode=$travelMode'
        '&key=$_apiKey',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['rows'].isNotEmpty) {
          final row = data['rows'][0];
          
          if (row['elements'].isNotEmpty) {
            final element = row['elements'][0];

            if (element['status'] == 'OK') {
              // Distância em km
              final distance = (element['distance']['value'] as int) / 1000.0;

              // Duração
              final durationSeconds = element['duration']['value'] as int;
              final duration = Duration(seconds: durationSeconds);

              return DistanceMatrixResult(
                distanceKm: distance,
                duration: duration,
              );
            }
          }
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao usar API: $e');
      }
      return null;
    }
  }

  /// Calcula distância localmente usando fórmula de Haversine (não requer billing)
  DistanceMatrixResult _calculateDistanceLocal(
    Location origin,
    Location destination,
    String travelMode,
  ) {
    // Usa Geolocator para calcular distância (Haversine)
    final distanceKm = LocationService.calculateDistance(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );

    // Estima tempo baseado em velocidade média do modo de transporte
    // Valores aproximados em km/h:
    final double averageSpeed;
    switch (travelMode) {
      case 'walking':
        averageSpeed = 5.0; // 5 km/h - caminhada
        break;
      case 'bicycling':
        averageSpeed = 15.0; // 15 km/h - bicicleta
        break;
      case 'transit':
        averageSpeed = 25.0; // 25 km/h - transporte público (média)
        break;
      case 'driving':
      default:
        averageSpeed = 40.0; // 40 km/h - carro (considera trânsito)
        break;
    }

    // Calcula tempo estimado: tempo = distância / velocidade
    final hours = distanceKm / averageSpeed;
    final duration = Duration(
      seconds: (hours * 3600).round(),
    );

    if (kDebugMode) {
      print('✓ Distância calculada localmente: ${distanceKm.toStringAsFixed(2)} km');
      print('✓ Tempo estimado: ${duration.inMinutes} min (modo: $travelMode)');
    }

    return DistanceMatrixResult(
      distanceKm: distanceKm,
      duration: duration,
    );
  }

  /// Calcula distâncias de múltiplas origens para múltiplos destinos
  Future<Map<String, DistanceMatrixResult?>> getDistanceMatrixMultiple({
    required List<Location> origins,
    required List<Location> destinations,
    String travelMode = 'driving',
  }) async {
    final results = <String, DistanceMatrixResult?>{};

    for (final origin in origins) {
      for (final destination in destinations) {
        final key = '${origin.latitude},${origin.longitude}_${destination.latitude},${destination.longitude}';
        results[key] = await getDistanceMatrix(
          origin: origin,
          destination: destination,
          travelMode: travelMode,
        );
      }
    }

    return results;
  }

  /// Obtém distância mais próxima de uma lista de destinos
  Future<Location?> findNearestDestination({
    required Location origin,
    required List<Location> destinations,
    String travelMode = 'driving',
  }) async {
    Location? nearest;
    double? minDistance;

    for (final destination in destinations) {
      final result = await getDistanceMatrix(
        origin: origin,
        destination: destination,
        travelMode: travelMode,
      );

      if (result != null && (minDistance == null || result.distanceKm < minDistance)) {
        minDistance = result.distanceKm;
        nearest = destination;
      }
    }

    return nearest;
  }
}

