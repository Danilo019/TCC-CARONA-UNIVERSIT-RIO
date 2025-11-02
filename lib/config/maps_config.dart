/// Configurações para Google Maps
class MapsConfig {
  // API Key do Google Maps
  // IMPORTANTE: Substitua pela sua API Key obtida no Google Cloud Console
  // https://console.cloud.google.com/google/maps-apis
  static const String apiKey = 'AIzaSyDsdoPF0ImH-GjHmRUiCQx9S4sYx-qqMEc';

  // Configuração padrão do mapa
  static const double defaultZoom = 14.0;
  static const double minZoom = 10.0;
  static const double maxZoom = 20.0;
  
  // Localização padrão (coordenadas aproximadas do Campus da UDF)
  // Faculdade UDF - Águas Claras, Brasília - DF
  static const double defaultLatitude = -15.8404;
  static const double defaultLongitude = -47.9000;

  /// Verifica se a API Key foi configurada
  static bool get isApiKeyConfigured {
    return apiKey.isNotEmpty && apiKey != 'SUA_API_KEY_AQUI';
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

