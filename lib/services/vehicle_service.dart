import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/vehicle.dart';

/// Serviço para gerenciar veículos no Firestore
class VehicleService {
  static final VehicleService _instance = VehicleService._internal();
  factory VehicleService() => _instance;
  VehicleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Collection reference para veículos
  CollectionReference get _vehiclesCollection => _firestore.collection('vehicles');

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

  // ===========================================================================
  // UPLOAD DE IMAGENS
  // ===========================================================================

  /// Faz upload de uma imagem para o Firebase Storage
  /// 
  /// [file] - Arquivo de imagem
  /// [path] - Caminho no Storage (ex: 'vehicles/photo.jpg')
  /// 
  /// Retorna a URL da imagem ou null em caso de erro
  Future<String?> uploadImage(File file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadURL = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        print('✓ Imagem enviada: $downloadURL');
      }

      return downloadURL;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao fazer upload da imagem: $e');
      }
      return null;
    }
  }

  /// Faz upload da foto do veículo
  Future<String?> uploadVehiclePhoto(File file, String driverId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'vehicles/$driverId/vehicle_$timestamp.jpg';
    return uploadImage(file, path);
  }

  /// Faz upload da foto da CNH
  Future<String?> uploadCnhPhoto(File file, String driverId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'documents/$driverId/cnh_$timestamp.jpg';
    return uploadImage(file, path);
  }

  /// Faz upload da foto do CRLV
  Future<String?> uploadCrlvPhoto(File file, String driverId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'documents/$driverId/crlv_$timestamp.jpg';
    return uploadImage(file, path);
  }

  /// Deleta uma imagem do Storage
  Future<bool> deleteImage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();

      if (kDebugMode) {
        print('✓ Imagem deletada do Storage');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao deletar imagem: $e');
      }
      return false;
    }
  }
}
