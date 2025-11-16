import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para representar uma solicitação de carona
class RideRequest {
  final String id;
  final String rideId; // ID da carona
  final String passengerId; // ID do passageiro
  final String passengerName; // Nome do passageiro
  final String? passengerPhotoURL; // Foto do passageiro
  final String status; // 'pending', 'accepted', 'rejected', 'cancelled'
  final String? message; // Mensagem opcional do passageiro
  final DateTime createdAt;
  final DateTime? updatedAt;

  const RideRequest({
    required this.id,
    required this.rideId,
    required this.passengerId,
    required this.passengerName,
    this.passengerPhotoURL,
    this.status = 'pending',
    this.message,
    required this.createdAt,
    this.updatedAt,
  });

  /// Cria uma RideRequest a partir de um DocumentSnapshot do Firestore
  factory RideRequest.fromFirestore(dynamic doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      DateTime parseDateTime(dynamic value) {
        if (value == null) return DateTime.now();
        if (value is DateTime) return value;
        if (value is Timestamp) return value.toDate();
        if (value.toString().contains('Timestamp')) {
          return (value as dynamic).toDate();
        }
        return DateTime.now();
      }
      
      return RideRequest(
        id: doc.id,
        rideId: data['rideId'] ?? '',
        passengerId: data['passengerId'] ?? '',
        passengerName: data['passengerName'] ?? '',
        passengerPhotoURL: data['passengerPhotoURL'],
        status: data['status'] ?? 'pending',
        message: data['message'],
        createdAt: parseDateTime(data['createdAt']),
        updatedAt: data['updatedAt'] != null 
            ? parseDateTime(data['updatedAt']) 
            : null,
      );
    } catch (e) {
      throw Exception('Erro ao converter documento ${doc.id}: $e');
    }
  }

  /// Converte RideRequest para Map (Firestore)
  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhotoURL': passengerPhotoURL,
      'status': status,
      'message': message,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  /// Cria uma cópia da solicitação com campos atualizados
  RideRequest copyWith({
    String? id,
    String? rideId,
    String? passengerId,
    String? passengerName,
    String? passengerPhotoURL,
    String? status,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RideRequest(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhotoURL: passengerPhotoURL ?? this.passengerPhotoURL,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Verifica se a solicitação está pendente
  bool get isPending => status == 'pending';
  
  /// Verifica se a solicitação foi aceita
  bool get isAccepted => status == 'accepted';
  
  /// Verifica se a solicitação foi rejeitada
  bool get isRejected => status == 'rejected';

  @override
  String toString() {
    return 'RideRequest(id: $id, ride: $rideId, passenger: $passengerName, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RideRequest && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
