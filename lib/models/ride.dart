import 'package:cloud_firestore/cloud_firestore.dart';
import 'location.dart';

/// Modelo para representar uma carona
class Ride {
  final String id;
  final String driverId;
  final String driverName;
  final String? driverPhotoURL;
  final Location origin;
  final Location destination;
  final List<Location> pickupPoints; // Pontos de embarque definidos pelo motorista
  final DateTime dateTime;
  final int maxSeats;
  final int availableSeats;
  final String? description;
  final double? price;
  final String status; // 'active', 'in_progress', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final GeoPoint? originGeoPoint;
  final String? originGeoHash;

  const Ride({
    required this.id,
    required this.driverId,
    required this.driverName,
    this.driverPhotoURL,
    required this.origin,
    required this.destination,
    this.pickupPoints = const [],
    required this.dateTime,
    required this.maxSeats,
    required this.availableSeats,
    this.description,
    this.price,
    this.status = 'active',
    required this.createdAt,
    this.updatedAt,
    this.originGeoPoint,
    this.originGeoHash,
  });

  /// Cria uma Ride a partir de um DocumentSnapshot do Firestore
  factory Ride.fromFirestore(dynamic doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      // Helper para converter Timestamp para DateTime
      DateTime parseDateTime(dynamic value) {
        if (value == null) return DateTime.now();
        if (value is DateTime) return value;
        if (value is Timestamp) return value.toDate();
        if (value.toString().contains('Timestamp')) {
          return (value as dynamic).toDate();
        }
        // Fallback: tenta parsear como string ou retorna agora
        return DateTime.now();
      }
      
      // Parse pickup points
      List<Location> pickupPoints = [];
      if (data['pickupPoints'] != null && data['pickupPoints'] is List) {
        pickupPoints = (data['pickupPoints'] as List)
            .map((item) => Location.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      
      final ride = Ride(
        id: doc.id,
        driverId: data['driverId'] ?? '',
        driverName: data['driverName'] ?? '',
        driverPhotoURL: data['driverPhotoURL'],
        origin: Location.fromMap(data['origin'] ?? {}),
        destination: Location.fromMap(data['destination'] ?? {}),
        pickupPoints: pickupPoints,
        dateTime: parseDateTime(data['dateTime']),
        maxSeats: (data['maxSeats'] as num?)?.toInt() ?? 1,
        availableSeats: (data['availableSeats'] as num?)?.toInt() ?? 0,
        description: data['description'],
        price: data['price']?.toDouble(),
        status: data['status'] ?? 'active',
        createdAt: parseDateTime(data['createdAt']),
        updatedAt: data['updatedAt'] != null 
            ? parseDateTime(data['updatedAt']) 
            : null,
        originGeoPoint: data['originGeoPoint'] is GeoPoint ? data['originGeoPoint'] as GeoPoint : null,
        originGeoHash: data['originGeoHash'] as String?,
      );
      
      return ride;
    } catch (e) {
      // Em caso de erro, retorna uma carona inválida que será filtrada
      // Isso evita que um erro em um documento quebre toda a query
      throw Exception('Erro ao converter documento ${doc.id}: $e');
    }
  }

  /// Converte Ride para Map (Firestore)
  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'driverPhotoURL': driverPhotoURL,
      'origin': origin.toMap(),
      'destination': destination.toMap(),
      'pickupPoints': pickupPoints.map((point) => point.toMap()).toList(),
      'dateTime': dateTime,
      'maxSeats': maxSeats,
      'availableSeats': availableSeats,
      'description': description,
      'price': price,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'originGeoPoint': originGeoPoint,
      'originGeoHash': originGeoHash,
      'isAvailable': status == 'active' && availableSeats > 0,
    };
  }

  /// Cria uma cópia da carona com campos atualizados
  Ride copyWith({
    String? id,
    String? driverId,
    String? driverName,
    String? driverPhotoURL,
    Location? origin,
    Location? destination,
    List<Location>? pickupPoints,
    DateTime? dateTime,
    int? maxSeats,
    int? availableSeats,
    String? description,
    double? price,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    GeoPoint? originGeoPoint,
    String? originGeoHash,
  }) {
    return Ride(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhotoURL: driverPhotoURL ?? this.driverPhotoURL,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      pickupPoints: pickupPoints ?? this.pickupPoints,
      dateTime: dateTime ?? this.dateTime,
      maxSeats: maxSeats ?? this.maxSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      description: description ?? this.description,
      price: price ?? this.price,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      originGeoPoint: originGeoPoint ?? this.originGeoPoint,
      originGeoHash: originGeoHash ?? this.originGeoHash,
    );
  }

  /// Verifica se a carona está disponível
  bool get isAvailable {
    return status == 'active' && availableSeats > 0;
  }

  /// Verifica se a carona já passou
  bool get isPast {
    return dateTime.isBefore(DateTime.now());
  }

  @override
  String toString() {
    return 'Ride(id: $id, driver: $driverName, seats: $availableSeats/$maxSeats, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ride && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

