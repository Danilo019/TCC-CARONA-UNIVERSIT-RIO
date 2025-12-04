// Serviço responsável por gerenciar caronas no Firestore
// Implementa operações CRUD e consultas geoespaciais usando geohash

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/ride.dart';
import '../utils/geohash_utils.dart';
import 'location_service.dart';

// Classe singleton para gerenciamento completo de caronas
// Inclui filtros por localização, motorista, data e disponibilidade
class RidesService {
  static final RidesService _instance = RidesService._internal();
  factory RidesService() => _instance;
  RidesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _defaultLimit = 100;
  static const int _nearbyQueryLimit = 50;
  static const int _geohashPrecision = 7;
  static const Duration _driverConflictWindow = Duration(hours: 2);

  /// Collection reference para caronas
  CollectionReference get _ridesCollection => _firestore.collection('rides');

  Query _activeRidesQuery() {
    return _ridesCollection
        .where('status', isEqualTo: 'active')
        .where('isAvailable', isEqualTo: true)
        .orderBy('availableSeats', descending: true)
        .orderBy('dateTime');
  }

  // ===========================================================================
  // OPERAÇÕES DE LEITURA
  // ===========================================================================

  /// Stream de caronas ativas e disponíveis
  Stream<List<Ride>> watchActiveRides() {
    return _activeRidesQuery().limit(_defaultLimit).snapshots().map((snapshot) {
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
  Future<List<Ride>> getActiveRides({int limit = _defaultLimit}) async {
    try {
      final snapshot = await _activeRidesQuery().limit(limit).get();

      final rides = _mapSnapshotToRides(snapshot.docs);

      if (kDebugMode) {
        print('✓ ${rides.length} caronas ativas encontradas');
      }

      return rides;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        throw Exception(
          'Índices do Firestore ausentes para consulta de caronas ativas. '
          'Execute firebase deploy --only firestore:indexes após aplicar firestore.indexes.json.',
        );
      }
      rethrow;
    }
  }

  /// Busca caronas por motorista
  Stream<List<Ride>> watchRidesByDriver(String driverId) {
    return _ridesCollection
        .where('driverId', isEqualTo: driverId)
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Ride.fromFirestore(doc)).toList();
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

  /// Busca múltiplas caronas por uma lista de IDs
  Future<List<Ride>> getRidesByIds(List<String> rideIds) async {
    if (rideIds.isEmpty) {
      return [];
    }

    final uniqueIds = rideIds.toSet().toList();
    final Map<String, Ride> ridesMap = {};

    const int batchSize = 10; // Limite do Firestore para whereIn

    for (var i = 0; i < uniqueIds.length; i += batchSize) {
      final endIndex = i + batchSize < uniqueIds.length
          ? i + batchSize
          : uniqueIds.length;
      final chunk = uniqueIds.sublist(i, endIndex);

      try {
        final snapshot = await _ridesCollection
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final ride in _mapSnapshotToRides(snapshot.docs)) {
          ridesMap[ride.id] = ride;
        }
      } catch (e) {
        if (kDebugMode) {
          print('✗ Erro ao buscar caronas por IDs ($chunk): $e');
        }
      }
    }

    final rides = ridesMap.values.toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return rides;
  }

  List<Ride> _mapSnapshotToRides(List<QueryDocumentSnapshot> docs) {
    final rides = docs
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

    rides.sort((a, b) {
      if (a.availableSeats != b.availableSeats) {
        return b.availableSeats.compareTo(a.availableSeats);
      }
      return a.dateTime.compareTo(b.dateTime);
    });

    return rides;
  }

  Future<void> _ensureNoDriverConflict({
    required String driverId,
    required DateTime dateTime,
    String? ignoreRideId,
  }) async {
    final startWindow = Timestamp.fromDate(
      dateTime.subtract(_driverConflictWindow),
    );
    final endWindow = Timestamp.fromDate(dateTime.add(_driverConflictWindow));

    final snapshot = await _ridesCollection
        .where('driverId', isEqualTo: driverId)
        .where('dateTime', isGreaterThanOrEqualTo: startWindow)
        .where('dateTime', isLessThanOrEqualTo: endWindow)
        .get();

    final hasConflict = snapshot.docs.any((doc) {
      if (ignoreRideId != null && doc.id == ignoreRideId) {
        return false;
      }

      final data = doc.data() as Map<String, dynamic>? ?? {};
      final status = (data['status'] as String?) ?? 'active';

      return status == 'active' || status == 'in_progress';
    });

    if (hasConflict) {
      throw Exception(
        'Já existe uma carona agendada para este motorista no intervalo de 2 horas. '
        'Ajuste o horário para evitar conflitos.',
      );
    }
  }

  /// Busca caronas próximas a uma localização (raio em km)
  Future<List<Ride>> getNearbyRides(
    double latitude,
    double longitude, {
    double radiusKm = 10.0,
  }) async {
    try {
      final hashes = GeohashUtils.hashesForRadius(
        latitude,
        longitude,
        radiusKm,
      );
      final results = <String, _RideDistance>{};

      for (final hash in hashes) {
        final snapshot = await _activeRidesQuery()
            .where('originGeoHash', isGreaterThanOrEqualTo: hash)
            .where('originGeoHash', isLessThanOrEqualTo: '$hash\uf8ff')
            .limit(_nearbyQueryLimit)
            .get();

        for (final doc in snapshot.docs) {
          try {
            final ride = Ride.fromFirestore(doc);
            final distance = LocationService.calculateDistance(
              latitude,
              longitude,
              ride.origin.latitude,
              ride.origin.longitude,
            );

            if (distance <= radiusKm) {
              final existing = results[ride.id];
              if (existing == null || distance < existing.distance) {
                results[ride.id] = _RideDistance(
                  ride: ride,
                  distance: distance,
                );
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('✗ Erro ao converter carona geolocalizada ${doc.id}: $e');
            }
          }
        }
      }

      final sorted = results.values.toList()
        ..sort((a, b) {
          if ((a.distance - b.distance).abs() > 0.001) {
            return a.distance.compareTo(b.distance);
          }
          if (a.ride.availableSeats != b.ride.availableSeats) {
            return b.ride.availableSeats.compareTo(a.ride.availableSeats);
          }
          return a.ride.dateTime.compareTo(b.ride.dateTime);
        });

      if (kDebugMode) {
        print(
          '✓ ${sorted.length} caronas próximas encontradas dentro de ${radiusKm}km',
        );
      }

      return sorted.map((entry) => entry.ride).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        throw Exception(
          'Índices do Firestore ausentes para consulta geoespacial. '
          'Execute firebase deploy --only firestore:indexes.',
        );
      }
      if (kDebugMode) {
        print(
          '✗ Erro do Firestore em getNearbyRides: ${e.code} - ${e.message}',
        );
      }
      return [];
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
      await _ensureNoDriverConflict(
        driverId: ride.driverId,
        dateTime: ride.dateTime,
      );

      // Converte DateTime para Timestamp do Firestore
      final rideMap = ride.toMap();
      rideMap['dateTime'] = Timestamp.fromDate(ride.dateTime);
      rideMap['createdAt'] = Timestamp.fromDate(ride.createdAt);
      if (ride.updatedAt != null) {
        rideMap['updatedAt'] = Timestamp.fromDate(ride.updatedAt!);
      }
      rideMap['isAvailable'] =
          ride.status == 'active' && ride.availableSeats > 0;
      if (rideMap['startedAt'] == null) {
        rideMap.remove('startedAt');
      }

      final originGeoPoint = ride.origin.toGeoPoint();
      final originGeoHash = GeohashUtils.encode(
        ride.origin.latitude,
        ride.origin.longitude,
        precision: _geohashPrecision,
      );
      rideMap['originGeoPoint'] = originGeoPoint;
      rideMap['originGeoHash'] = originGeoHash;

      if (kDebugMode) {
        print('📝 Criando carona:');
        print('  Driver: ${ride.driverName}');
        print(
          '  Origem: ${ride.origin.address ?? '${ride.origin.latitude}, ${ride.origin.longitude}'}',
        );
        print(
          '  Destino: ${ride.destination.address ?? '${ride.destination.latitude}, ${ride.destination.longitude}'}',
        );
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
      await _ensureNoDriverConflict(
        driverId: ride.driverId,
        dateTime: ride.dateTime,
        ignoreRideId: ride.id,
      );

      final originGeoPoint = ride.origin.toGeoPoint();
      final originGeoHash = GeohashUtils.encode(
        ride.origin.latitude,
        ride.origin.longitude,
        precision: _geohashPrecision,
      );

      final rideMap = ride
          .copyWith(
            originGeoPoint: originGeoPoint,
            originGeoHash: originGeoHash,
          )
          .toMap();

      rideMap['dateTime'] = Timestamp.fromDate(ride.dateTime);
      rideMap.remove('createdAt');
      rideMap['updatedAt'] = FieldValue.serverTimestamp();
      rideMap['isAvailable'] =
          ride.status == 'active' && ride.availableSeats > 0;
      if (rideMap['startedAt'] == null) {
        rideMap.remove('startedAt');
      }

      await _ridesCollection.doc(ride.id).update(rideMap);

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
        'isAvailable': false,
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
    return _firestore
        .runTransaction((transaction) async {
          final rideRef = _ridesCollection.doc(rideId);
          final snapshot = await transaction.get(rideRef);

          if (!snapshot.exists) {
            if (kDebugMode) {
              print('✗ Carona não encontrada para reserva: $rideId');
            }
            return false;
          }

          final ride = Ride.fromFirestore(snapshot);

          if (!ride.isAvailable || ride.availableSeats <= 0) {
            if (kDebugMode) {
              print('✗ Não há vagas disponíveis na carona $rideId');
            }
            return false;
          }

          final newSeats = ride.availableSeats - 1;

          transaction.update(rideRef, {
            'availableSeats': FieldValue.increment(-1),
            'isAvailable': ride.status == 'active' && newSeats > 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (kDebugMode) {
            print('✓ Vaga reservada na carona: $rideId');
          }

          return true;
        })
        .catchError((error) {
          if (kDebugMode) {
            print('✗ Erro ao reservar vaga: $error');
          }
          return false;
        });
  }

  /// Libera uma vaga em uma carona
  Future<bool> releaseSeat(String rideId) async {
    return _firestore
        .runTransaction((transaction) async {
          final rideRef = _ridesCollection.doc(rideId);
          final snapshot = await transaction.get(rideRef);

          if (!snapshot.exists) {
            if (kDebugMode) {
              print('✗ Carona não encontrada para liberação: $rideId');
            }
            return false;
          }

          final ride = Ride.fromFirestore(snapshot);

          if (ride.availableSeats >= ride.maxSeats) {
            if (kDebugMode) {
              print('✗ Limite máximo de vagas atingido para $rideId');
            }
            return false;
          }

          final newSeats = ride.availableSeats + 1;

          transaction.update(rideRef, {
            'availableSeats': FieldValue.increment(1),
            'isAvailable': ride.status == 'active' && newSeats > 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (kDebugMode) {
            print('✓ Vaga liberada na carona: $rideId');
          }

          return true;
        })
        .catchError((error) {
          if (kDebugMode) {
            print('✗ Erro ao liberar vaga: $error');
          }
          return false;
        });
  }

  /// Finaliza uma carona
  Future<bool> completeRide(String rideId) async {
    try {
      await _ridesCollection.doc(rideId).update({
        'status': 'completed',
        'isAvailable': false,
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

  /// Inicia uma carona
  Future<bool> startRide(String rideId) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final rideRef = _ridesCollection.doc(rideId);
        final snapshot = await transaction.get(rideRef);

        if (!snapshot.exists) {
          if (kDebugMode) {
            print('✗ Carona não encontrada para iniciar: $rideId');
          }
          return false;
        }

        final ride = Ride.fromFirestore(snapshot);
        if (ride.status != 'active') {
          if (kDebugMode) {
            print(
              '✗ Carona não pode ser iniciada. Status atual: ${ride.status}',
            );
          }
          return false;
        }

        transaction.update(rideRef, {
          'status': 'in_progress',
          'isAvailable': false,
          'startedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print('✓ Carona iniciada: $rideId');
        }

        return true;
      });
    } catch (error) {
      if (kDebugMode) {
        print('✗ Erro ao iniciar carona: $error');
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

class _RideDistance {
  final Ride ride;
  final double distance;

  const _RideDistance({required this.ride, required this.distance});
}
