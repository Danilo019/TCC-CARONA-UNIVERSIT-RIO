import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/auth_user.dart';
import '../models/auth_token.dart';

/// Serviço para operações com Firestore
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _tokensCollection => _firestore.collection('activationTokens');
  CollectionReference get _ridesCollection => _firestore.collection('rides');

  // ===========================================================================
  // OPERAÇÕES COM USUÁRIOS
  // ===========================================================================

  /// Salva ou atualiza um usuário no Firestore
  Future<void> saveUser(AuthUser user) async {
    try {
      await _usersCollection.doc(user.uid).set(
        {
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'emailVerified': user.emailVerified,
          'createdAt': user.creationTime ?? FieldValue.serverTimestamp(),
          'lastSignIn': user.lastSignInTime ?? FieldValue.serverTimestamp(),
          'isActive': true,
        },
        SetOptions(merge: true),
      );

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
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (displayName != null) {
        updateData['displayName'] = displayName;
      }
      
      if (photoURL != null) {
        updateData['photoURL'] = photoURL;
      }

      if (updateData.isEmpty) {
        if (kDebugMode) {
          print('⚠ Nenhum dado para atualizar');
        }
        return;
      }

      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _usersCollection.doc(uid).update(updateData);

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
  // OPERAÇÕES COM TOKENS
  // ===========================================================================

  /// Salva um token de ativação no Firestore
  Future<void> saveActivationToken(AuthToken token) async {
    try {
      await _tokensCollection.doc(token.token).set({
        'token': token.token,
        'email': token.email,
        'createdAt': Timestamp.fromDate(token.createdAt),
        'expiresAt': Timestamp.fromDate(token.expiresAt),
        'isUsed': token.isUsed,
        'userId': token.userId,
      });

      if (kDebugMode) {
        print('✓ Token salvo no Firestore: ${token.token}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao salvar token: $e');
      }
      rethrow;
    }
  }

  /// Busca um token de ativação
  Future<AuthToken?> getActivationToken(String token) async {
    try {
      final doc = await _tokensCollection.doc(token).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      return AuthToken(
        token: data['token'] ?? '',
        email: data['email'] ?? '',
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        expiresAt: (data['expiresAt'] as Timestamp).toDate(),
        isUsed: data['isUsed'] ?? false,
        userId: data['userId'],
      );
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar token: $e');
      }
      return null;
    }
  }

  /// Valida e marca um token como usado
  Future<bool> validateAndUseToken(String token, String email) async {
    try {
      final doc = await _tokensCollection.doc(token).get();

      if (!doc.exists) {
        if (kDebugMode) {
          print('✗ Token não encontrado: $token');
        }
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Verifica email
      if (data['email'] != email) {
        if (kDebugMode) {
          print('✗ Email não confere: ${data['email']} != $email');
        }
        return false;
      }

      // Verifica se já foi usado
      if (data['isUsed'] == true) {
        if (kDebugMode) {
          print('✗ Token já usado: $token');
        }
        return false;
      }

      // Verifica expiração
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        if (kDebugMode) {
          print('✗ Token expirado: $token');
        }
        return false;
      }

      // Marca como usado
      await _tokensCollection.doc(token).update({
        'isUsed': true,
      });

      if (kDebugMode) {
        print('✓ Token validado e marcado como usado: $token');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao validar token: $e');
      }
      return false;
    }
  }

  /// Remove tokens expirados
  Future<void> cleanExpiredTokens() async {
    try {
      final now = Timestamp.now();
      final querySnapshot = await _tokensCollection
          .where('expiresAt', isLessThan: now)
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (kDebugMode) {
        print('✓ Tokens expirados removidos: ${querySnapshot.docs.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao limpar tokens expirados: $e');
      }
    }
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

