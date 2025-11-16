import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/location.dart';

/// Configurações para Google Maps
class MapsConfig {
  // API Key do Google Maps (lê do .env)
  // IMPORTANTE: Configure no arquivo .env a variável GOOGLE_MAPS_API_KEY
  // Obtenha sua API Key no Google Cloud Console
  // https://console.cloud.google.com/google/maps-apis
  static String get apiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ??
      (kDebugMode ? 'AIzaSyDsdoPF0ImH-GjHmRUiCQx9S4sYx-qqMEc' : '');

  // Configuração padrão do mapa
  static const double defaultZoom = 14.0;
  static const double minZoom = 10.0;
  static const double maxZoom = 20.0;

  // Localização padrão (coordenadas aproximadas do Campus da UDF - Asa Sul)
  // Centro Universitário do Distrito Federal - Asa Sul, Brasília - DF
  static const double defaultLatitude = -15.801043;
  static const double defaultLongitude = -47.901468;

  static const String _udfAddress =
      'UDF - Centro Universitário (Campus Sede), Asa Sul, Brasília - DF, Brasil';

  static const Location _udfCampusLocation = Location(
    latitude: defaultLatitude,
    longitude: defaultLongitude,
    address: _udfAddress,
  );

  /// Localização padrão do campus da UDF (Latitude/Longitude/Endereço)
  static Location get udfCampusLocation => _udfCampusLocation;

  /// Verifica se a API Key foi configurada
  static bool get isApiKeyConfigured {
    final key = apiKey;
    return key.isNotEmpty &&
        key != 'SUA_API_KEY_AQUI' &&
        !key.contains('SUA_API_KEY');
  }

  /// Retorna configuração completa do mapa
  static Map<String, dynamic> getMapConfig() {
    return {
      'apiKey': apiKey,
      'defaultZoom': defaultZoom,
      'minZoom': minZoom,
      'maxZoom': maxZoom,
      'defaultLatitude': defaultLatitude,
      'defaultLongitude': defaultLongitude,
    };
  }
}
