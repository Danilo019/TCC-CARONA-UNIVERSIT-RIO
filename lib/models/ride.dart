import 'location.dart';

/// Modelo para representar uma carona
class Ride {
  final String id;
  final String driverId;
  final String driverName;
  final String? driverPhotoURL;
  final Location origin;
  final Location destination;
  final DateTime dateTime;
  final int maxSeats;
  final int availableSeats;
  final String? description;
  final double? price;
  final String status; // 'active', 'in_progress', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Ride({
    required this.id,
    required this.driverId,
    required this.driverName,
    this.driverPhotoURL,
    required this.origin,
    required this.destination,
    required this.dateTime,
    required this.maxSeats,
    required this.availableSeats,
    this.description,
    this.price,
    this.status = 'active',
    required this.createdAt,
    this.updatedAt,
  });

  /// Cria uma Ride a partir de um DocumentSnapshot do Firestore
  factory Ride.fromFirestore(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Ride(
      id: doc.id,
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      driverPhotoURL: data['driverPhotoURL'],
      origin: Location.fromMap(data['origin'] ?? {}),
      destination: Location.fromMap(data['destination'] ?? {}),
      dateTime: (data['dateTime'] as dynamic).toDate(),
      maxSeats: data['maxSeats'] ?? 1,
      availableSeats: data['availableSeats'] ?? 0,
      description: data['description'],
      price: data['price']?.toDouble(),
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as dynamic).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as dynamic).toDate() 
          : null,
    );
  }

  /// Converte Ride para Map (Firestore)
  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'driverPhotoURL': driverPhotoURL,
      'origin': origin.toMap(),
      'destination': destination.toMap(),
      'dateTime': dateTime,
      'maxSeats': maxSeats,
      'availableSeats': availableSeats,
      'description': description,
      'price': price,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
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
    DateTime? dateTime,
    int? maxSeats,
    int? availableSeats,
    String? description,
    double? price,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Ride(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhotoURL: driverPhotoURL ?? this.driverPhotoURL,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      dateTime: dateTime ?? this.dateTime,
      maxSeats: maxSeats ?? this.maxSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      description: description ?? this.description,
      price: price ?? this.price,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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

