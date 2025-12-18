// Serviço de integração com Google Maps APIs
// Implementa geocoding, reverse geocoding, rotas e cálculo de distâncias

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/maps_config.dart';
import '../models/location.dart';
import 'location_service.dart';

/// Modelos para respostas das APIs
class GeocodingResult {
  final String formattedAddress;
  final Location location;

  GeocodingResult({required this.formattedAddress, required this.location});
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

  DistanceMatrixResult({required this.distanceKm, required this.duration});
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

      final response = await http.get(url).timeout(const Duration(seconds: 10));

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

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];

          return GeocodingResult(
            formattedAddress: result['formatted_address'],
            location: location.copyWith(address: result['formatted_address']),
          );
        } else {
          // Fallback: retorna coordenadas sem endereço formatado
          if (kDebugMode) {
            final status = data['status'] as String;
            if (status == 'REQUEST_DENIED') {
              print(
                '⚠ Reverse Geocoding requer billing. Usando apenas coordenadas.',
              );
            } else {
              print('✗ Reverse Geocoding falhou: $status');
            }
          }
          // Retorna localização com coordenadas (sem endereço formatado)
          return GeocodingResult(
            formattedAddress:
                '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
            location: location,
          );
        }
      } else {
        // Fallback: retorna coordenadas
        return GeocodingResult(
          formattedAddress:
              '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
          location: location,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Reverse Geocoding falhou, usando coordenadas: $e');
      }
      // Fallback: retorna coordenadas
      return GeocodingResult(
        formattedAddress:
            '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
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

  /// Obtém rota entre origem e destino, com pontos intermediários opcionais
  Future<Route?> getDirections({
    required Location origin,
    required Location destination,
    List<Location>? waypoints, // Pontos intermediários (pontos de embarque)
    String travelMode = 'driving', // driving, walking, bicycling, transit
    bool avoidHighways = false,
    bool avoidTolls = false,
  }) async {
    try {
      final avoid = <String>[];

      if (avoidHighways) avoid.add('highways');
      if (avoidTolls) avoid.add('tolls');

      final avoidParam = avoid.isNotEmpty ? '&avoid=${avoid.join('|')}' : '';

      // Constrói parâmetro de waypoints
      String waypointsParam = '';
      if (waypoints != null && waypoints.isNotEmpty) {
        final waypointsStr = waypoints
            .map((wp) => '${wp.latitude},${wp.longitude}')
            .join('|');
        waypointsParam = '&waypoints=$waypointsStr';
      }

      final url = Uri.parse(
        '$_baseUrl/directions/json?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '$waypointsParam'
        '&mode=$travelMode'
        '$avoidParam'
        '&key=$_apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'] as List;

          // Soma distância e duração de todas as pernas
          double totalDistance = 0;
          int totalDurationSeconds = 0;

          for (var leg in legs) {
            totalDistance += (leg['distance']['value'] as int) / 1000.0;
            totalDurationSeconds += leg['duration']['value'] as int;
          }

          final duration = Duration(seconds: totalDurationSeconds);

          // Extrai waypoints da polyline (pontos da rota)
          final waypointsList = <Location>[];

          // Adiciona origem
          waypointsList.add(origin);

          // Adiciona pontos intermediários se houver
          if (waypoints != null && waypoints.isNotEmpty) {
            waypointsList.addAll(waypoints);
          }

          // Adiciona destino
          waypointsList.add(destination);

          // Tenta decodificar polyline para obter pontos da rota completa
          // Por enquanto, retornamos os waypoints principais
          if (route['overview_polyline'] != null) {
            final encodedPolyline =
                route['overview_polyline']['points'] as String;
            // Decodifica polyline (usando algoritmo simplificado)
            final decodedPoints = _decodePolyline(encodedPolyline);
            if (decodedPoints.isNotEmpty) {
              // Combina waypoints principais com pontos da polyline
              waypointsList.clear();
              waypointsList.addAll(decodedPoints);
            }
          }

          return Route(
            distanceKm: totalDistance,
            duration: duration,
            waypoints: waypointsList,
          );
        } else {
          if (kDebugMode) {
            print('✗ Directions falhou: ${data['status']}');
          }

          // Se a API não está disponível (REQUEST_DENIED, etc), usa cálculo local
          final status = data['status'] as String;
          if (status == 'REQUEST_DENIED' ||
              status == 'OVER_QUERY_LIMIT' ||
              status == 'ZERO_RESULTS' ||
              status == 'NOT_FOUND') {
            if (kDebugMode) {
              print(
                '⚠ API retornou: $status - usando cálculo local de rota como fallback',
              );
            }
            return _calculateRouteLocal(origin, destination, waypoints);
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

  /// Decodifica polyline do Google Maps para lista de coordenadas
  List<Location> _decodePolyline(String encoded) {
    final points = <Location>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;

      // Decodifica latitude
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int deltaLat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      // Decodifica longitude
      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);

      int deltaLng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(Location(latitude: lat / 1e5, longitude: lng / 1e5));
    }

    return points;
  }

  /// Calcula rota localmente quando API não está disponível (fallback)
  Route _calculateRouteLocal(
    Location origin,
    Location destination,
    List<Location>? waypoints,
  ) {
    final waypointsList = <Location>[];

    // Adiciona origem
    waypointsList.add(origin);

    // Adiciona pontos intermediários se houver
    if (waypoints != null && waypoints.isNotEmpty) {
      waypointsList.addAll(waypoints);
    }

    // Adiciona destino
    waypointsList.add(destination);

    // Calcula distância total (linha reta entre pontos)
    double totalDistance = 0;
    for (int i = 0; i < waypointsList.length - 1; i++) {
      final distance = LocationService.calculateDistance(
        waypointsList[i].latitude,
        waypointsList[i].longitude,
        waypointsList[i + 1].latitude,
        waypointsList[i + 1].longitude,
      );
      totalDistance += distance;
    }

    // Estima tempo (assumindo velocidade média de 40 km/h considerando curvas e trânsito)
    // Multiplica por 1.3 para considerar que estradas não são linha reta
    final estimatedDistance = totalDistance * 1.3;
    final averageSpeed = 40.0; // km/h
    final hours = estimatedDistance / averageSpeed;
    final duration = Duration(seconds: (hours * 3600).round());

    if (kDebugMode) {
      print(
        '✓ Rota calculada localmente: ${estimatedDistance.toStringAsFixed(2)} km (estimado)',
      );
      print('✓ Tempo estimado: ${duration.inMinutes} min');
    }

    return Route(
      distanceKm: estimatedDistance,
      duration: duration,
      waypoints: waypointsList,
    );
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
      final result = await _getDistanceMatrixFromAPI(
        origin,
        destination,
        travelMode,
      );
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

      final response = await http.get(url).timeout(const Duration(seconds: 10));

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
    final duration = Duration(seconds: (hours * 3600).round());

    if (kDebugMode) {
      print(
        '✓ Distância calculada localmente: ${distanceKm.toStringAsFixed(2)} km',
      );
      print('✓ Tempo estimado: ${duration.inMinutes} min (modo: $travelMode)');
    }

    return DistanceMatrixResult(distanceKm: distanceKm, duration: duration);
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
        final key =
            '${origin.latitude},${origin.longitude}_${destination.latitude},${destination.longitude}';
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

      if (result != null &&
          (minDistance == null || result.distanceKm < minDistance)) {
        minDistance = result.distanceKm;
        nearest = destination;
      }
    }

    return nearest;
  }

  // ===========================================================================
  // NAVEGAÇÃO EXTERNA - Abre Google Maps para navegação
  // ===========================================================================

  /// Abre navegação no Google Maps usando origem e destino
  /// Usa a origem definida na carona, não a localização atual do usuário
  Future<bool> launchNavigation({
    required Location origin,
    required Location destination,
  }) async {
    try {
      // Formata coordenadas para URL do Google Maps
      final originStr = '${origin.latitude},${origin.longitude}';
      final destinationStr = '${destination.latitude},${destination.longitude}';

      Uri? deepLink;
      late final Uri fallbackUrl;

      if (Platform.isAndroid) {
        // Abre diretamente o modo navegação turn-by-turn
        deepLink = Uri.parse('google.navigation:q=$destinationStr&mode=d');
        fallbackUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&origin=$originStr&destination=$destinationStr&travelmode=driving',
        );
      } else if (Platform.isIOS) {
        // Precisa do esquema do Google Maps (se instalado); fallback para Apple Maps
        deepLink = Uri.parse(
          'comgooglemaps://?saddr=$originStr&daddr=$destinationStr&directionsmode=driving',
        );
        fallbackUrl = Uri.parse(
          'https://maps.apple.com/?saddr=$originStr&daddr=$destinationStr&dirflg=d',
        );
      } else {
        fallbackUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&origin=$originStr&destination=$destinationStr&travelmode=driving',
        );
      }

      if (kDebugMode) {
        print('🧭 Abrindo navegação...');
        print('  Origem: $originStr');
        print('  Destino: $destinationStr');
      }

      Future<bool> tryLaunch(Uri uri, {bool enableJs = false}) async {
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
            webViewConfiguration: enableJs
                ? const WebViewConfiguration(enableJavaScript: true)
                : const WebViewConfiguration(),
          );
          if (kDebugMode) {
            if (launched) {
              print('✓ Navegação aberta com $uri');
            } else {
              print('✗ Falha ao abrir navegação: $uri');
            }
          }
          return launched;
        } catch (e) {
          if (kDebugMode) {
            print('✗ Erro ao tentar abrir $uri: $e');
          }
          return false;
        }
      }

      if (deepLink != null && await tryLaunch(deepLink)) {
        return true;
      }

      if (await tryLaunch(fallbackUrl, enableJs: true)) {
        return true;
      }

      if (kDebugMode) {
        print('✗ Nenhuma URL de navegação disponível');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao abrir navegação: $e');
      }
      return false;
    }
  }

  /// Abre navegação no Waze utilizando apenas o destino
  Future<bool> launchWazeNavigation({required Location destination}) async {
    try {
      final destinationStr = '${destination.latitude},${destination.longitude}';

      final Uri wazeUri = Uri.parse('waze://?ll=$destinationStr&navigate=yes');

      Future<bool> tryLaunch(Uri uri) async {
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (kDebugMode) {
            if (launched) {
              print('✓ Navegação aberta no Waze com $uri');
            } else {
              print('✗ Falha ao abrir Waze: $uri');
            }
          }
          return launched;
        } catch (e) {
          if (kDebugMode) {
            print('✗ Erro ao tentar abrir Waze com $uri: $e');
          }
          return false;
        }
      }

      if (await tryLaunch(wazeUri)) {
        return true;
      }

      Uri? storeUri;

      if (Platform.isAndroid) {
        storeUri = Uri.parse('market://details?id=com.waze');
      } else if (Platform.isIOS) {
        storeUri = Uri.parse('itms-apps://itunes.apple.com/app/id323229106');
      }

      if (storeUri != null && await tryLaunch(storeUri)) {
        return true;
      }

      final fallbackStore = Uri.parse(
        'https://www.waze.com/ul?ll=$destinationStr&navigate=yes',
      );

      if (await tryLaunch(fallbackStore)) {
        return true;
      }

      if (kDebugMode) {
        print('✗ Nenhuma URL válida para Waze');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao abrir Waze: $e');
      }
      return false;
    }
  }
}
