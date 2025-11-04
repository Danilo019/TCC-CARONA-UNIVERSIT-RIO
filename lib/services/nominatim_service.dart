import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/location.dart';

/// Resultado de uma busca do Nominatim
class NominatimResult {
  final String displayName;
  final Location location;

  NominatimResult({
    required this.displayName,
    required this.location,
  });
}

/// Serviço para interagir com a API do Nominatim (OpenStreetMap)
/// 
/// A API do Nominatim é gratuita e não requer autenticação, mas tem limites de uso:
/// - Máximo de 1 requisição por segundo
/// - Máximo de 1 milhão de requisições por mês por IP
/// 
/// Para uso comercial, considere usar uma instância própria ou o serviço pago.
class NominatimService {
  static final NominatimService _instance = NominatimService._internal();
  factory NominatimService() => _instance;
  NominatimService._internal();

  // URL base da API pública do Nominatim
  // IMPORTANTE: Para produção, considere usar uma instância própria ou rate limiting
  final String _baseUrl = 'https://nominatim.openstreetmap.org';
  
  // Delay mínimo entre requisições para respeitar rate limiting (1 req/s)
  DateTime? _lastRequestTime;
  static const Duration _minDelay = Duration(milliseconds: 1000);

  /// Aguarda o tempo mínimo entre requisições (rate limiting)
  Future<void> _waitForRateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minDelay) {
        await Future.delayed(_minDelay - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  /// Busca endereços usando autocomplete (search)
  /// 
  /// [query] - Texto de busca
  /// [limit] - Número máximo de resultados (padrão: 10)
  /// [countryCodes] - Códigos de país ISO 3166-1 (ex: ['br'] para Brasil)
  /// 
  /// Retorna lista de resultados ou lista vazia em caso de erro
  Future<List<NominatimResult>> searchAddress({
    required String query,
    int limit = 10,
    List<String>? countryCodes,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      // Aguarda rate limiting
      await _waitForRateLimit();

      // Monta URL da API
      final queryParams = <String, String>{
        'q': query.trim(),
        'format': 'json',
        'limit': limit.toString(),
        'addressdetails': '1',
        'extratags': '0',
        'namedetails': '0',
      };

      // Adiciona filtro de país se fornecido
      if (countryCodes != null && countryCodes.isNotEmpty) {
        queryParams['countrycodes'] = countryCodes.join(',');
      }

      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'CaronaUniversitariaApp/1.0', // Nominatim requer User-Agent
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        return data.map((item) {
          try {
            final lat = (item['lat'] as String?) != null
                ? double.parse(item['lat'] as String)
                : (item['lat'] as num?)?.toDouble() ?? 0.0;
            final lon = (item['lon'] as String?) != null
                ? double.parse(item['lon'] as String)
                : (item['lon'] as num?)?.toDouble() ?? 0.0;

            final displayName = item['display_name'] as String? ?? '';

            return NominatimResult(
              displayName: displayName,
              location: Location(
                latitude: lat,
                longitude: lon,
                address: displayName,
              ),
            );
          } catch (e) {
            if (kDebugMode) {
              print('✗ Erro ao processar resultado do Nominatim: $e');
            }
            return null;
          }
        }).whereType<NominatimResult>().toList();
      } else {
        if (kDebugMode) {
          print('✗ Erro HTTP no Nominatim: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro no Nominatim: $e');
      }
      return [];
    }
  }

  /// Faz reverse geocoding (converte coordenadas em endereço)
  /// 
  /// [location] - Localização com latitude e longitude
  /// 
  /// Retorna o endereço formatado ou null em caso de erro
  Future<NominatimResult?> reverseGeocode(Location location) async {
    try {
      // Aguarda rate limiting
      await _waitForRateLimit();

      final uri = Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
        'lat': location.latitude.toString(),
        'lon': location.longitude.toString(),
        'format': 'json',
        'addressdetails': '1',
      });

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'CaronaUniversitariaApp/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final displayName = data['display_name'] as String? ?? '';

        return NominatimResult(
          displayName: displayName,
          location: location.copyWith(address: displayName),
        );
      } else {
        if (kDebugMode) {
          print('✗ Erro HTTP no Reverse Geocoding: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro no Reverse Geocoding: $e');
      }
      return null;
    }
  }

  /// Converte um NominatimResult para GeocodingResult (compatibilidade com GoogleMapsService)
  /// 
  /// Útil para manter compatibilidade com código existente que usa GeocodingResult
  static NominatimResult? toGeocodingResult(dynamic result) {
    if (result == null) return null;
    
    if (result is NominatimResult) {
      return result;
    }
    
    // Se for GeocodingResult do GoogleMapsService, converte
    // (necessário apenas se quiser usar ambos os serviços)
    return null;
  }
}
