import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/firebase_config.dart';
import 'token_service.dart';
import 'firestore_service.dart';
import '../models/auth_user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final TokenService _tokenService = TokenService();
  final FirestoreService _firestoreService = FirestoreService();
  String? _currentSessionToken;

  // Getters
  User? get currentUser => _firebaseAuth.currentUser;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  bool get isSignedIn => currentUser != null;
  String? get currentSessionToken => _currentSessionToken;

  /// Inicializa o serviço de autenticação
  Future<void> initialize() async {
    try {
      // Aguarda o Firebase ser inicializado
      await _firebaseAuth.authStateChanges().first;

      if (kDebugMode) {
        print('✓ AuthService inicializado com sucesso');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao inicializar AuthService: $e');
      }
      rethrow;
    }
  }

  /// Verifica se o email é da UDF
  bool isUDFEmail(String email) {
    return FirebaseConfig.isUDFEmail(email);
  }

  // ===========================================================================
  // AUTENTICAÇÃO COM EMAIL E SENHA
  // ===========================================================================

  /// Realiza login com email e senha
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      if (!isUDFEmail(email)) {
        throw Exception('Apenas emails @cs.udf.edu.br são permitidos');
      }

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // Atualiza lastSignIn no Firestore
        await _firestoreService.updateLastSignIn(user.uid);
        
        if (kDebugMode) {
          print('✓ Login bem-sucedido: ${user.email}');
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('✗ Erro no login: ${e.code} - ${e.message}');
      }
      
      String errorMessage = 'Erro ao fazer login';
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        errorMessage = 'Email ou senha incorretos';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Email inválido';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Conta desabilitada';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Muitas tentativas. Tente novamente mais tarde.';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro no login: $e');
      }
      rethrow;
    }
  }

  /// Cria conta com email e senha
  Future<User?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      if (!isUDFEmail(email)) {
        throw Exception('Apenas emails @cs.udf.edu.br são permitidos');
      }

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // Salva perfil no Firestore
        final authUser = AuthUser(
          uid: user.uid,
          email: user.email!,
          displayName: user.displayName ?? email.split('@').first,
          photoURL: user.photoURL,
          emailVerified: user.emailVerified,
          creationTime: user.metadata.creationTime,
          lastSignInTime: user.metadata.lastSignInTime,
        );
        
        await _firestoreService.saveUser(authUser);
        
        if (kDebugMode) {
          print('✓ Conta criada: ${user.email}');
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar conta: ${e.code} - ${e.message}');
      }
      
      String errorMessage = 'Erro ao criar conta';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Este email já está em uso';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Email inválido';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Senha muito fraca';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage = 'Operação não permitida';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar conta: $e');
      }
      rethrow;
    }
  }

  /// Cria conta após validação de token
  Future<User?> createAccountAfterTokenValidation(String email, String password) async {
    try {
      // Cria conta no Firebase Auth
      final user = await createUserWithEmailAndPassword(email, password);
      
      if (user != null && kDebugMode) {
        print('✓ Conta criada após validação de token: ${user.email}');
      }
      
      return user;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar conta pós-validação: $e');
      }
      rethrow;
    }
  }

  /// Cria um token de ativação para um email
  Future<String> createActivationToken(String email) async {
    try {
      if (!isUDFEmail(email)) {
        throw Exception('Apenas emails @cs.udf.edu.br são permitidos');
      }

      final token = await _tokenService.createActivationToken(email);
      return token.token;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar token de ativação: $e');
      }
      rethrow;
    }
  }

  /// Valida um token de ativação
  Future<bool> validateActivationToken(String token, String email) async {
    try {
      return await _tokenService.validateToken(token, email);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao validar token de ativação: $e');
      }
      return false;
    }
  }

  /// Envia email de ativação
  Future<bool> sendActivationEmail(String email, String token) async {
    try {
      return await _tokenService.sendActivationEmail(email, token);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao enviar email de ativação: $e');
      }
      return false;
    }
  }

  /// Cria um token de sessão após ativação
  Future<String> createSessionToken(String email) async {
    try {
      return await _tokenService.createSessionToken(email);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar token de sessão: $e');
      }
      rethrow;
    }
  }

  /// Verifica se o usuário está autenticado via token
  Future<bool> isAuthenticated() async {
    if (_currentSessionToken == null) {
      return false;
    }

    try {
      return await _tokenService.validateSessionToken(_currentSessionToken!);
    } catch (e) {
      return false;
    }
  }

  /// Realiza logout
  Future<void> signOut() async {
    try {
      // Limpa o token de sessão
      _currentSessionToken = null;
      
      // Logout do Firebase
      await _firebaseAuth.signOut();

      if (kDebugMode) {
        print('✓ Logout realizado com sucesso');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro no logout: $e');
      }
      rethrow;
    }
  }

  /// Limpa cache de autenticação
  Future<void> clearCache() async {
    try {
      // No Firebase Authentication, não há cache específico para limpar
      // Apenas fazemos logout se necessário
      if (_firebaseAuth.currentUser != null) {
        await _firebaseAuth.signOut();
      }
      
      if (kDebugMode) {
        print('✓ Cache limpo');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Erro ao limpar cache: $e');
      }
    }
  }

  /// Obtém informações do usuário atual
  Map<String, dynamic>? getCurrentUserInfo() {
    final user = currentUser;
    if (user == null) return null;

    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'emailVerified': user.emailVerified,
      'creationTime': user.metadata.creationTime?.toIso8601String(),
      'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
    };
  }


  /// Força refresh do token
  Future<void> refreshToken() async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.reload();
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao refresh token: $e');
      }
    }
  }

  /// Obtém token de ID do Firebase (token real e verificável)
  Future<String?> getIdToken() async {
    try {
      final user = currentUser;
      if (user == null) return null;
      
      return await user.getIdToken();
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao obter token ID: $e');
      }
      return null;
    }
  }
}
