import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/vehicle.dart';
import '../models/vehicle_validation_status.dart';
import '../models/vehicle_thumbnail_type.dart';

/// Serviço para gerenciar veículos no Firestore
class VehicleService {
  static final VehicleService _instance = VehicleService._internal();
  factory VehicleService() => _instance;
  VehicleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection reference para veículos
  CollectionReference get _vehiclesCollection =>
      _firestore.collection('vehicles');

  // ===========================================================================
  // OPERAÇÕES DE LEITURA
  // ===========================================================================

  /// Busca o veículo de um motorista
  Future<Vehicle?> getVehicleByDriver(String driverId) async {
    try {
      final snapshot = await _vehiclesCollection
          .where('driverId', isEqualTo: driverId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return Vehicle.fromFirestore(snapshot.docs.first);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar veículo: $e');
      }
      return null;
    }
  }

  /// Verifica se já existe veículo com a placa informada
  Future<bool> hasPlateConflict(
    String plate, {
    String? excludeVehicleId,
  }) async {
    try {
      final formattedPlate = Vehicle.formatPlate(plate);
      final snapshot = await _vehiclesCollection
          .where('plate', isEqualTo: formattedPlate)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return false;
      }

      final doc = snapshot.docs.first;
      if (excludeVehicleId != null && doc.id == excludeVehicleId) {
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao verificar placa duplicada: $e');
      }
      return false;
    }
  }

  /// Stream do veículo de um motorista
  Stream<Vehicle?> watchVehicleByDriver(String driverId) {
    return _vehiclesCollection
        .where('driverId', isEqualTo: driverId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          try {
            return Vehicle.fromFirestore(snapshot.docs.first);
          } catch (e) {
            if (kDebugMode) {
              print('✗ Erro ao converter veículo: $e');
            }
            return null;
          }
        });
  }

  // ===========================================================================
  // OPERAÇÕES DE ESCRITA
  // ===========================================================================

  /// Cria um novo veículo
  Future<String?> createVehicle(Vehicle vehicle) async {
    try {
      final vehicleMap = vehicle.toMap();
      vehicleMap['createdAt'] = Timestamp.fromDate(vehicle.createdAt);
      if (vehicle.updatedAt != null) {
        vehicleMap['updatedAt'] = Timestamp.fromDate(vehicle.updatedAt!);
      }
      vehicleMap['validationStatus'] = vehicle.validationStatus.asString;
      vehicleMap['thumbnailType'] = vehicle.thumbnailType.asString;

      final docRef = await _vehiclesCollection.add(vehicleMap);

      if (kDebugMode) {
        print('✓ Veículo criado: ${docRef.id}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar veículo: $e');
      }
      return null;
    }
  }

  /// Atualiza um veículo existente
  Future<bool> updateVehicle(Vehicle vehicle) async {
    try {
      final vehicleMap = vehicle.toMap();
      vehicleMap['updatedAt'] = Timestamp.fromDate(DateTime.now());
      vehicleMap['validationStatus'] = vehicle.validationStatus.asString;
      vehicleMap['thumbnailType'] = vehicle.thumbnailType.asString;

      await _vehiclesCollection.doc(vehicle.id).update(vehicleMap);

      if (kDebugMode) {
        print('✓ Veículo atualizado: ${vehicle.id}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao atualizar veículo: $e');
      }
      return false;
    }
  }

  /// Deleta um veículo
  Future<bool> deleteVehicle(String vehicleId) async {
    try {
      await _vehiclesCollection.doc(vehicleId).delete();

      if (kDebugMode) {
        print('✓ Veículo deletado: $vehicleId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao deletar veículo: $e');
      }
      return false;
    }
  }
}
