import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/ride.dart';
import 'location_service.dart';

/// Serviço para gerenciar caronas no Firestore
class RidesService {
  static final RidesService _instance = RidesService._internal();
  factory RidesService() => _instance;
  RidesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection reference para caronas
  CollectionReference get _ridesCollection => _firestore.collection('rides');

  // ===========================================================================
  // OPERAÇÕES DE LEITURA
  // ===========================================================================

  /// Stream de caronas ativas e disponíveis
  Stream<List<Ride>> watchActiveRides() {
    return _ridesCollection
        .where('status', isEqualTo: 'active')
        .where('availableSeats', isGreaterThan: 0)
        .orderBy('dateTime')
        .snapshots()
        .map((snapshot) {
      if (kDebugMode) {
        print('✓ ${snapshot.docs.length} caronas ativas encontradas (stream)');
      }
      
      final rides = snapshot.docs
          .map((doc) {
            try {
              return Ride.fromFirestore(doc);
            } catch (e) {
              if (kDebugMode) {
                print('✗ Erro ao converter documento ${doc.id}: $e');
              }
              return null;
            }
          })
          .whereType<Ride>()
          .toList();
      
      // Ordena por vagas disponíveis
      rides.sort((a, b) {
        if (a.availableSeats != b.availableSeats) {
          return b.availableSeats.compareTo(a.availableSeats);
        }
        return a.dateTime.compareTo(b.dateTime);
      });
      
      return rides;
    });
  }

  /// Busca todas as caronas ativas
  Future<List<Ride>> getActiveRides() async {
    try {
      // Query simplificada - usando apenas um orderBy para evitar necessidade de índice composto
      // Filtra por status e vagas disponíveis, ordena por data
      final snapshot = await _ridesCollection
          .where('status', isEqualTo: 'active')
          .where('availableSeats', isGreaterThan: 0)
          .orderBy('dateTime')
          .get();

      final rides = snapshot.docs
          .map((doc) {
            try {
              return Ride.fromFirestore(doc);
            } catch (e) {
              if (kDebugMode) {
                print('✗ Erro ao converter documento ${doc.id}: $e');
                print('  Dados: ${doc.data()}');
              }
              return null;
            }
          })
          .whereType<Ride>()
          .toList();

      // Ordena por vagas disponíveis (em memória)
      rides.sort((a, b) {
        if (a.availableSeats != b.availableSeats) {
          return b.availableSeats.compareTo(a.availableSeats); // Mais vagas primeiro
        }
        return a.dateTime.compareTo(b.dateTime); // Depois por data
      });

      if (kDebugMode) {
        print('✓ ${rides.length} caronas ativas encontradas');
        if (rides.isNotEmpty) {
          print('  Primeira carona: ${rides.first.driverName} - ${rides.first.availableSeats} vagas');
        }
      }

      return rides;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar caronas ativas: $e');
        print('  Tentando query alternativa...');
      }
      
      // Fallback: busca sem filtros e filtra em memória
      try {
        final snapshot = await _ridesCollection
            .where('status', isEqualTo: 'active')
            .get();
        
        final rides = snapshot.docs
            .map((doc) {
              try {
                final ride = Ride.fromFirestore(doc);
                return ride.availableSeats > 0 ? ride : null;
              } catch (e) {
                return null;
              }
            })
            .whereType<Ride>()
            .toList();
        
        rides.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        
        if (kDebugMode) {
          print('✓ ${rides.length} caronas encontradas (fallback)');
        }
        
        return rides;
      } catch (e2) {
        if (kDebugMode) {
          print('✗ Erro na query fallback: $e2');
        }
        return [];
      }
    }
  }

  /// Busca caronas por motorista
  Stream<List<Ride>> watchRidesByDriver(String driverId) {
    return _ridesCollection
        .where('driverId', isEqualTo: driverId)
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Ride.fromFirestore(doc))
          .toList();
    });
  }

  /// Busca uma carona específica por ID
  Future<Ride?> getRideById(String rideId) async {
    try {
      final doc = await _ridesCollection.doc(rideId).get();
      
      if (!doc.exists) {
        return null;
      }

      return Ride.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar carona: $e');
      }
      return null;
    }
  }

  /// Busca caronas próximas a uma localização (raio em km)
  Future<List<Ride>> getNearbyRides(
    double latitude,
    double longitude, {
    double radiusKm = 10.0,
  }) async {
    try {
      // Busca todas as caronas ativas e filtra por distância
      final allRides = await getActiveRides();
      
      final nearbyRides = allRides.where((ride) {
        final distance = LocationService.calculateDistance(
          latitude,
          longitude,
          ride.origin.latitude,
          ride.origin.longitude,
        );
        return distance <= radiusKm;
      }).toList();

      if (kDebugMode) {
        print('✓ ${nearbyRides.length} caronas próximas encontradas');
      }

      return nearbyRides;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar caronas próximas: $e');
      }
      return [];
    }
  }

  // ===========================================================================
  // OPERAÇÕES DE ESCRITA
  // ===========================================================================

  /// Cria uma nova carona
  Future<String?> createRide(Ride ride) async {
    try {
      // Converte DateTime para Timestamp do Firestore
      final rideMap = ride.toMap();
      rideMap['dateTime'] = Timestamp.fromDate(ride.dateTime);
      rideMap['createdAt'] = Timestamp.fromDate(ride.createdAt);
      if (ride.updatedAt != null) {
        rideMap['updatedAt'] = Timestamp.fromDate(ride.updatedAt!);
      }
      
      if (kDebugMode) {
        print('📝 Criando carona:');
        print('  Driver: ${ride.driverName}');
        print('  Origem: ${ride.origin.address ?? '${ride.origin.latitude}, ${ride.origin.longitude}'}');
        print('  Destino: ${ride.destination.address ?? '${ride.destination.latitude}, ${ride.destination.longitude}'}');
        print('  Vagas: ${ride.availableSeats}/${ride.maxSeats}');
        print('  Status: ${ride.status}');
        print('  Data/Hora: ${ride.dateTime}');
      }
      
      final docRef = await _ridesCollection.add(rideMap);
      
      if (kDebugMode) {
        print('✓ Carona criada com sucesso: ${docRef.id}');
      }

      return docRef.id;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('✗ Erro ao criar carona: $e');
        print('  Stack trace: $stackTrace');
      }
      return null;
    }
  }

  /// Atualiza uma carona existente
  Future<bool> updateRide(Ride ride) async {
    try {
      await _ridesCollection.doc(ride.id).update({
        ...ride.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✓ Carona atualizada: ${ride.id}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao atualizar carona: $e');
      }
      return false;
    }
  }

  /// Cancela uma carona
  Future<bool> cancelRide(String rideId) async {
    try {
      await _ridesCollection.doc(rideId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✓ Carona cancelada: $rideId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao cancelar carona: $e');
      }
      return false;
    }
  }

  /// Reserva uma vaga em uma carona
  Future<bool> reserveSeat(String rideId) async {
    try {
      final ride = await getRideById(rideId);
      
      if (ride == null || ride.availableSeats <= 0) {
        if (kDebugMode) {
          print('✗ Não há vagas disponíveis na carona');
        }
        return false;
      }

      await _ridesCollection.doc(rideId).update({
        'availableSeats': ride.availableSeats - 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✓ Vaga reservada na carona: $rideId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao reservar vaga: $e');
      }
      return false;
    }
  }

  /// Libera uma vaga em uma carona
  Future<bool> releaseSeat(String rideId) async {
    try {
      final ride = await getRideById(rideId);
      
      if (ride == null || ride.availableSeats >= ride.maxSeats) {
        if (kDebugMode) {
          print('✗ Impossível liberar vaga');
        }
        return false;
      }

      await _ridesCollection.doc(rideId).update({
        'availableSeats': ride.availableSeats + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✓ Vaga liberada na carona: $rideId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao liberar vaga: $e');
      }
      return false;
    }
  }

  /// Finaliza uma carona
  Future<bool> completeRide(String rideId) async {
    try {
      await _ridesCollection.doc(rideId).update({
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✓ Carona finalizada: $rideId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao finalizar carona: $e');
      }
      return false;
    }
  }

  /// Remove uma carona permanentemente
  Future<bool> deleteRide(String rideId) async {
    try {
      await _ridesCollection.doc(rideId).delete();

      if (kDebugMode) {
        print('✓ Carona removida: $rideId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao remover carona: $e');
      }
      return false;
    }
  }
}

