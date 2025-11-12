import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/auth_user.dart';

/// Serviço para operações com Firestore
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _ridesCollection => _firestore.collection('rides');

  // ===========================================================================
  // OPERAÇÕES COM USUÁRIOS
  // ===========================================================================

  /// Salva ou atualiza um usuário no Firestore
  Future<void> saveUser(AuthUser user) async {
    try {
      await _usersCollection.doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'emailVerified': user.emailVerified,
        'createdAt': user.creationTime ?? FieldValue.serverTimestamp(),
        'lastSignIn': user.lastSignInTime ?? FieldValue.serverTimestamp(),
        'isActive': true,
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('✓ Usuário salvo no Firestore: ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao salvar usuário: $e');
      }
      rethrow;
    }
  }

  /// Busca um usuário pelo UID
  Future<AuthUser?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      return AuthUser(
        uid: uid,
        email: data['email'] ?? '',
        displayName: data['displayName'],
        photoURL: data['photoURL'],
        emailVerified: data['emailVerified'] ?? false,
        creationTime: (data['createdAt'] as Timestamp?)?.toDate(),
        lastSignInTime: (data['lastSignIn'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar usuário: $e');
      }
      return null;
    }
  }

  /// Atualiza apenas o lastSignIn de um usuário (ou cria se não existir)
  Future<void> updateLastSignIn(String uid) async {
    try {
      // Usa set com merge:true para criar ou atualizar
      await _usersCollection.doc(uid).set({
        'lastSignIn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('✓ LastSignIn atualizado: $uid');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao atualizar lastSignIn: $e');
      }
      rethrow;
    }
  }

  /// Atualiza informações do perfil do usuário
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? photoURL,
    bool removePhoto = false,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (displayName != null) {
        updateData['displayName'] = displayName;
      }

      if (removePhoto) {
        updateData['photoURL'] = FieldValue.delete();
        updateData['photoURLBase64'] = FieldValue.delete();
      } else if (photoURL != null) {
        updateData['photoURL'] = photoURL;
        if (photoURL.startsWith('data:image')) {
          updateData['photoURLBase64'] = photoURL;
        } else {
          updateData['photoURLBase64'] = FieldValue.delete();
        }
      }

      if (updateData.isEmpty) {
        if (kDebugMode) {
          print('⚠ Nenhum dado para atualizar');
        }
        return;
      }

      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _usersCollection.doc(uid).set(
        updateData,
        SetOptions(merge: true),
      );

      if (kDebugMode) {
        print('✓ Perfil atualizado: $uid');
        print('  Dados: $updateData');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao atualizar perfil: $e');
      }
      rethrow;
    }
  }

  /// Stream de mudanças em um usuário específico
  Stream<AuthUser?> watchUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return AuthUser(
        uid: uid,
        email: data['email'] ?? '',
        displayName: data['displayName'],
        photoURL: data['photoURL'],
        emailVerified: data['emailVerified'] ?? false,
        creationTime: (data['createdAt'] as Timestamp?)?.toDate(),
        lastSignInTime: (data['lastSignIn'] as Timestamp?)?.toDate(),
      );
    });
  }

  // ===========================================================================
  // OPERAÇÕES COM CARONAS (para o futuro)
  // ===========================================================================

  /// Busca caronas ativas
  Stream<QuerySnapshot> watchActiveRides() {
    return _ridesCollection
        .where('status', isEqualTo: 'active')
        .where('seatsAvailable', isGreaterThan: 0)
        .orderBy('seatsAvailable')
        .orderBy('dateTime')
        .snapshots();
  }

  /// Cria uma nova carona
  Future<void> createRide(Map<String, dynamic> rideData) async {
    try {
      await _ridesCollection.add({
        ...rideData,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      if (kDebugMode) {
        print('✓ Carona criada no Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar carona: $e');
      }
      rethrow;
    }
  }

  // ===========================================================================
  // UTILITÁRIOS
  // ===========================================================================

  /// Limpa cache do Firestore
  Future<void> clearCache() async {
    await _firestore.clearPersistence();
    if (kDebugMode) {
      print('✓ Cache do Firestore limpo');
    }
  }
}
