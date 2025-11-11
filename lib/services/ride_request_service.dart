import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/ride_request.dart';
import '../services/rides_service.dart';
import '../services/notification_service.dart';

/// Serviço para gerenciar solicitações de carona
class RideRequestService {
  static final RideRequestService _instance = RideRequestService._internal();
  factory RideRequestService() => _instance;
  RideRequestService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RidesService _ridesService = RidesService();
  final NotificationService _notificationService = NotificationService();

  /// Collection reference para solicitações
  CollectionReference get _requestsCollection =>
      _firestore.collection('ride_requests');

  // ===========================================================================
  // OPERAÇÕES DE LEITURA
  // ===========================================================================

  /// Busca todas as solicitações de uma carona
  Future<List<RideRequest>> getRequestsByRide(String rideId) async {
    try {
      final snapshot = await _requestsCollection
          .where('rideId', isEqualTo: rideId)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return RideRequest.fromFirestore(doc);
            } catch (e) {
              if (kDebugMode) {
                print('✗ Erro ao converter solicitação ${doc.id}: $e');
              }
              return null;
            }
          })
          .whereType<RideRequest>()
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar solicitações: $e');
      }
      return [];
    }
  }

  /// Stream de solicitações de uma carona
  Stream<List<RideRequest>> watchRequestsByRide(String rideId) {
    try {
      return _requestsCollection
          .where('rideId', isEqualTo: rideId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) {
                  try {
                    return RideRequest.fromFirestore(doc);
                  } catch (e) {
                    return null;
                  }
                })
                .whereType<RideRequest>()
                .toList();
          })
          .handleError(
            (error) {
              if (kDebugMode) {
                print('✗ Erro no stream de solicitações: $error');
              }
            },
            test: (error) {
              // Captura erros de índice faltando ou outros erros do Firestore
              return true;
            },
          );
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar stream de solicitações: $e');
      }
      // Retorna stream vazio em caso de erro
      return Stream.value(<RideRequest>[]);
    }
  }

  /// Stream de solicitações de um passageiro
  Stream<List<RideRequest>> watchRequestsByPassenger(String passengerId) {
    try {
      return _requestsCollection
          .where('passengerId', isEqualTo: passengerId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) {
                  try {
                    return RideRequest.fromFirestore(doc);
                  } catch (e) {
                    if (kDebugMode) {
                      print('✗ Erro ao converter solicitação ${doc.id}: $e');
                    }
                    return null;
                  }
                })
                .whereType<RideRequest>()
                .toList();
          })
          .handleError((error) {
            if (kDebugMode) {
              print('✗ Erro no stream de solicitações por passageiro: $error');
            }
          }, test: (error) => true);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar stream de solicitações por passageiro: $e');
      }
      return Stream.value(<RideRequest>[]);
    }
  }

  /// Busca todas as solicitações de um passageiro
  Future<List<RideRequest>> getRequestsByPassenger(String passengerId) async {
    try {
      final snapshot = await _requestsCollection
          .where('passengerId', isEqualTo: passengerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return RideRequest.fromFirestore(doc);
            } catch (e) {
              return null;
            }
          })
          .whereType<RideRequest>()
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar solicitações do passageiro: $e');
      }
      return [];
    }
  }

  /// Busca uma solicitação específica
  Future<RideRequest?> getRequestById(String requestId) async {
    try {
      final doc = await _requestsCollection.doc(requestId).get();

      if (!doc.exists) {
        return null;
      }

      return RideRequest.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar solicitação: $e');
      }
      return null;
    }
  }

  // ===========================================================================
  // OPERAÇÕES DE ESCRITA
  // ===========================================================================

  /// Cria uma nova solicitação de carona
  Future<String?> createRequest(RideRequest request) async {
    try {
      // Verifica se já existe uma solicitação pendente do mesmo passageiro
      final existing = await _requestsCollection
          .where('rideId', isEqualTo: request.rideId)
          .where('passengerId', isEqualTo: request.passengerId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (kDebugMode) {
          print('⚠ Solicitação já existe e está pendente');
        }
        return existing.docs.first.id;
      }

      final requestMap = request.toMap();
      requestMap['createdAt'] = Timestamp.fromDate(request.createdAt);
      if (request.updatedAt != null) {
        requestMap['updatedAt'] = Timestamp.fromDate(request.updatedAt!);
      }

      final docRef = await _requestsCollection.add(requestMap);

      if (kDebugMode) {
        print('✓ Solicitação criada: ${docRef.id}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar solicitação: $e');
      }
      return null;
    }
  }

  /// Aceita uma solicitação
  Future<bool> acceptRequest(String requestId) async {
    try {
      final request = await getRequestById(requestId);
      if (request == null) {
        return false;
      }

      // Atualiza status da solicitação
      await _requestsCollection.doc(requestId).update({
        'status': 'accepted',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Reduz vagas disponíveis na carona
      final ride = await _ridesService.getRideById(request.rideId);
      if (ride != null && ride.availableSeats > 0) {
        await _ridesService.reserveSeat(request.rideId);
      }

      try {
        if (ride != null) {
          await _notificationService.refreshRemindersIfEnabled(ride.driverId);
        }
        await _notificationService.refreshRemindersIfEnabled(
          request.passengerId,
        );
      } catch (error) {
        if (kDebugMode) {
          print(
            '⚠ Não foi possível atualizar lembretes após aceitar solicitação: $error',
          );
        }
      }

      // Rejeita outras solicitações pendentes da mesma carona
      // (opcional - pode permitir múltiplas aceitações)

      if (kDebugMode) {
        print('✓ Solicitação aceita: $requestId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao aceitar solicitação: $e');
      }
      return false;
    }
  }

  /// Rejeita uma solicitação
  Future<bool> rejectRequest(String requestId) async {
    try {
      await _requestsCollection.doc(requestId).update({
        'status': 'rejected',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (kDebugMode) {
        print('✓ Solicitação rejeitada: $requestId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao rejeitar solicitação: $e');
      }
      return false;
    }
  }

  /// Cancela uma solicitação (pelo passageiro)
  Future<bool> cancelRequest(String requestId) async {
    try {
      await _requestsCollection.doc(requestId).update({
        'status': 'cancelled',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (kDebugMode) {
        print('✓ Solicitação cancelada: $requestId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao cancelar solicitação: $e');
      }
      return false;
    }
  }
}
