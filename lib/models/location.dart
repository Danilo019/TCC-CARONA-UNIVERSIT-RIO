import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para representar uma localização geográfica
class Location {
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime? timestamp;

  const Location({
    required this.latitude,
    required this.longitude,
    this.address,
    this.timestamp,
  });

  /// Cria uma Location a partir de um Map (Firestore)
  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'],
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as dynamic).toDate() 
          : null,
    );
  }

  /// Converte Location para Map (Firestore)
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'timestamp': timestamp,
    };
  }

  /// Converte Location para GeoPoint do Firestore
  GeoPoint toGeoPoint() {
    return GeoPoint(latitude, longitude);
  }

  /// Cria uma cópia da localização com campos atualizados
  Location copyWith({
    double? latitude,
    double? longitude,
    String? address,
    DateTime? timestamp,
  }) {
    return Location(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Verifica se a localização é válida
  bool get isValid {
    return latitude >= -90 && 
           latitude <= 90 && 
           longitude >= -180 && 
           longitude <= 180;
  }

  @override
  String toString() {
    return 'Location(lat: $latitude, lng: $longitude, address: $address)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Location &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^ longitude.hashCode;
  }
}

