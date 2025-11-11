import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ride.dart';
import 'consent_service.dart';
import 'ride_request_service.dart';
import 'rides_service.dart';

/// Serviço responsável por centralizar a coleta e exportação de dados do usuário
/// para atender aos direitos de acesso e portabilidade (Art. 18 / LGPD).
class UserDataService {
  UserDataService._internal();

  static final UserDataService _instance = UserDataService._internal();

  factory UserDataService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RidesService _ridesService = RidesService();
  final RideRequestService _rideRequestService = RideRequestService();

  /// Nome da coleção para registrar eventos de auditoria de privacidade.
  static const String _privacyAuditCollection = 'privacy_audit';

  /// Monta um snapshot completo dos dados do usuário em formato serializável.
  Future<Map<String, dynamic>> buildUserDataSnapshot(String userId) async {
    final stopwatch = Stopwatch()..start();

    try {
      final errors = <String>[];

      final profile = await _safeFetchMap(
        () => _fetchUserProfile(userId),
        errors,
        'Perfil',
      );
      final vehicles = await _safeFetchList(
        () => _fetchVehicles(userId),
        errors,
        'Veículos',
      );
      final ridesAsDriver = await _safeFetchList(
        () => _fetchRidesAsDriver(userId),
        errors,
        'Caronas como motorista',
      );
      final rideRequests = await _safeFetchList(
        () => _fetchRideRequests(userId),
        errors,
        'Solicitações de carona',
      );
      final ridesAsPassenger = await _safeFetchList(
        () => _fetchRidesAsPassenger(userId),
        errors,
        'Caronas como passageiro',
      );
      final evaluations =
          await _safeFetchMap(
            () => _fetchEvaluations(userId),
            errors,
            'Avaliações',
          ) ??
          <String, dynamic>{
            'asAuthor': <Map<String, dynamic>>[],
            'asTarget': <Map<String, dynamic>>[],
          };
      final consents = await _safeFetchList(
        () => _fetchConsents(userId),
        errors,
        'Consentimentos',
      );

      final now = DateTime.now().toUtc();

      return <String, dynamic>{
        'metadata': {
          'generatedAt': now.toIso8601String(),
          'timezone': now.timeZoneOffset.inHours,
          'app': 'Carona Universitária',
          'privacyPolicyVersion': ConsentService.currentPrivacyPolicyVersion,
          'termsVersion': ConsentService.currentTermsOfServiceVersion,
          'generationMs': stopwatch.elapsedMilliseconds,
          if (errors.isNotEmpty) 'errors': errors,
        },
        'profile': _normalizeValue(profile),
        'vehicles': vehicles.map(_normalizeValue).toList(),
        'rides': {
          'asDriver': ridesAsDriver.map(_normalizeValue).toList(),
          'asPassenger': ridesAsPassenger.map(_normalizeValue).toList(),
        },
        'rideRequests': rideRequests.map(_normalizeValue).toList(),
        'evaluations': {
          'asAuthor': (evaluations['asAuthor'] as List<Map<String, dynamic>>)
              .map(_normalizeValue)
              .toList(),
          'asTarget': (evaluations['asTarget'] as List<Map<String, dynamic>>)
              .map(_normalizeValue)
              .toList(),
        },
        'consents': consents.map(_normalizeValue).toList(),
      };
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('✗ UserDataService.buildUserDataSnapshot error: $error');
        print(stackTrace);
      }
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Exporta os dados do usuário para um arquivo JSON e registra auditoria.
  ///
  /// Retorna o caminho completo do arquivo gerado.
  Future<String> exportUserData({
    required String userId,
    required String email,
  }) async {
    final data = await buildUserDataSnapshot(userId);

    final directory = await getApplicationDocumentsDirectory();
    final sanitizedEmail = email.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final fileName =
        'carona_universitaria_dados_${sanitizedEmail}_$timestamp.json';
    final file = File('${directory.path}/$fileName');

    final encoder = const JsonEncoder.withIndent('  ');
    final payload = encoder.convert(data);

    await file.writeAsString(payload);

    await _registerAuditEvent(
      userId: userId,
      email: email,
      eventType: _AuditEventType.export,
      payloadSize: payload.length,
      fileName: fileName,
      filePath: file.path,
    );

    return file.path;
  }

  /// Registra um evento de acesso ou exportação para fins de auditoria (Art. 37).
  Future<void> _registerAuditEvent({
    required String userId,
    required String email,
    required _AuditEventType eventType,
    required int payloadSize,
    required String fileName,
    required String filePath,
  }) async {
    try {
      await _firestore.collection(_privacyAuditCollection).add({
        'userId': userId,
        'email': email,
        'eventType': describeEnum(eventType),
        'createdAt': FieldValue.serverTimestamp(),
        'payloadSize': payloadSize,
        'fileName': fileName,
        'filePath': filePath,
        'policyVersion': ConsentService.currentPrivacyPolicyVersion,
      });
    } catch (error) {
      if (kDebugMode) {
        print('⚠ Falha ao registrar auditoria de exportação: $error');
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) {
      return null;
    }

    final data = doc.data() ?? <String, dynamic>{};

    data['id'] = doc.id;
    data['emailVerified'] = (_auth.currentUser?.uid == userId)
        ? _auth.currentUser?.emailVerified
        : data['emailVerified'];

    return data;
  }

  Future<List<Map<String, dynamic>>> _fetchVehicles(String userId) async {
    final snapshot = await _firestore
        .collection('vehicles')
        .where('driverId', isEqualTo: userId)
        .get();
    return snapshot.docs.map(_documentToMap).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchRidesAsDriver(String userId) async {
    final snapshot = await _firestore
        .collection('rides')
        .where('driverId', isEqualTo: userId)
        .orderBy('dateTime', descending: true)
        .limit(200)
        .get();
    return snapshot.docs.map(_documentToMap).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchRideRequests(String userId) async {
    final snapshot = await _firestore
        .collection('ride_requests')
        .where('passengerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
    return snapshot.docs.map(_documentToMap).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchRidesAsPassenger(
    String userId,
  ) async {
    final requests = await _rideRequestService.getRequestsByPassenger(userId);
    final rideIds = requests.map((request) => request.rideId).toSet().toList();

    if (rideIds.isEmpty) {
      return [];
    }

    final rides = await _ridesService.getRidesByIds(rideIds);
    return rides.map(_rideToMap).toList();
  }

  Future<Map<String, dynamic>> _fetchEvaluations(String userId) async {
    final asAuthorSnapshot = await _firestore
        .collection('avaliacoes')
        .where('avaliador_usuario_id', isEqualTo: userId)
        .orderBy('data_avaliacao', descending: true)
        .limit(200)
        .get();

    final asTargetSnapshot = await _firestore
        .collection('avaliacoes')
        .where('avaliado_usuario_id', isEqualTo: userId)
        .orderBy('data_avaliacao', descending: true)
        .limit(200)
        .get();

    return {
      'asAuthor': asAuthorSnapshot.docs.map(_documentToMap).toList(),
      'asTarget': asTargetSnapshot.docs.map(_documentToMap).toList(),
    };
  }

  Future<List<Map<String, dynamic>>> _fetchConsents(String userId) async {
    final snapshot = await _firestore
        .collection('consents')
        .where('userId', isEqualTo: userId)
        .orderBy('acceptedAt', descending: true)
        .get();
    return snapshot.docs.map(_documentToMap).toList();
  }

  Future<Map<String, dynamic>?> _safeFetchMap(
    Future<Map<String, dynamic>?> Function() fetch,
    List<String> errors,
    String section,
  ) async {
    try {
      return await fetch();
    } on FirebaseException catch (error) {
      _handleFirebaseException(error, errors, section);
      return null;
    } catch (error, stackTrace) {
      _handleGenericError(error, stackTrace, errors, section);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _safeFetchList(
    Future<List<Map<String, dynamic>>> Function() fetch,
    List<String> errors,
    String section,
  ) async {
    try {
      return await fetch();
    } on FirebaseException catch (error) {
      _handleFirebaseException(error, errors, section);
      return <Map<String, dynamic>>[];
    } catch (error, stackTrace) {
      _handleGenericError(error, stackTrace, errors, section);
      return <Map<String, dynamic>>[];
    }
  }

  void _handleFirebaseException(
    FirebaseException error,
    List<String> errors,
    String section,
  ) {
    final message = error.code == 'permission-denied'
        ? '$section: permissão negada pelas regras de segurança.'
        : '$section: ${error.message ?? error.code}.';
    errors.add(message);

    if (kDebugMode) {
      print('⚠ UserDataService -> $section falhou: $message');
    }
  }

  void _handleGenericError(
    Object error,
    StackTrace stackTrace,
    List<String> errors,
    String section,
  ) {
    errors.add('$section: erro inesperado.');

    if (kDebugMode) {
      print('✗ UserDataService -> $section erro: $error');
      print(stackTrace);
    }
  }

  Map<String, dynamic> _documentToMap(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    data['id'] = doc.id;
    return data;
  }

  Map<String, dynamic> _rideToMap(Ride ride) {
    return {
      'id': ride.id,
      'driverId': ride.driverId,
      'driverName': ride.driverName,
      'driverPhotoURL': ride.driverPhotoURL,
      'origin': ride.origin.toMap(),
      'destination': ride.destination.toMap(),
      'pickupPoints': ride.pickupPoints.map((point) => point.toMap()).toList(),
      'dateTime': ride.dateTime.toIso8601String(),
      'maxSeats': ride.maxSeats,
      'availableSeats': ride.availableSeats,
      'description': ride.description,
      'price': ride.price,
      'status': ride.status,
      'createdAt': ride.createdAt.toIso8601String(),
      'updatedAt': ride.updatedAt?.toIso8601String(),
    };
  }

  dynamic _normalizeValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }

    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }

    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }

    if (value is List) {
      return value.map(_normalizeValue).toList();
    }

    if (value is Map<String, dynamic>) {
      return value.map(
        (key, dynamic val) => MapEntry(key, _normalizeValue(val)),
      );
    }

    return value;
  }
}

enum _AuditEventType { export }
