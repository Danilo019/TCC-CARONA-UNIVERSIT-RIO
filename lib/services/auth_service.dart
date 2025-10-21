import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:aad_oauth/aad_oauth.dart';
import '../config/firebase_config.dart';
import '../config/aad_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  AadOAuth? _aadOAuth;
  bool _isInitialized = false;

  // Configurações do Microsoft Azure AD (usando configurações centralizadas)
  static const String _clientId = FirebaseConfig.microsoftClientId;

  // Getters
  User? get currentUser => _firebaseAuth.currentUser;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  bool get isSignedIn => currentUser != null;

  /// Inicializa o serviço de autenticação
  Future<void> initialize() async {
    try {
      // Aguarda o Firebase ser inicializado
      await _firebaseAuth.authStateChanges().first;
      
      // Inicializa AAD OAuth apenas em plataformas móveis
      if (!kIsWeb) {
        _aadOAuth = AadConfig.getOAuthInstance();
      }
      _isInitialized = true;

      if (kDebugMode) {
        print('✓ AuthService inicializado com sucesso (Web: $kIsWeb)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao inicializar AuthService: $e');
      }
      rethrow;
    }
  }

  /// Realiza login com Microsoft usando AAD OAuth
  Future<User?> signInWithMicrosoft() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Web não suporta aad_oauth
      if (kIsWeb) {
        throw Exception('Login com Microsoft não está disponível na web no momento. Use o aplicativo Android/iOS.');
      }

      if (_aadOAuth == null) {
        throw Exception('AAD OAuth não foi inicializado');
      }

      if (kDebugMode) {
        print('Iniciando login com Microsoft...');
      }

      // Realiza login com Azure AD
      await _aadOAuth!.login();
      
      // Verifica se está autenticado
      final hasToken = await _aadOAuth!.getAccessToken();
      
      if (hasToken == null || hasToken.isEmpty) {
        throw Exception('Não foi possível obter token de acesso');
      }

      // Obtém informações do usuário
      final accountInfo = await _getUserInfo();
      
      if (accountInfo == null) {
        throw Exception('Não foi possível obter informações da conta');
      }

      final email = accountInfo['email'] as String?;
      final displayName = accountInfo['name'] as String?;

      if (email == null || email.isEmpty) {
        throw Exception('Email não encontrado na conta Microsoft');
      }

      if (kDebugMode) {
        print('✓ Login Microsoft bem-sucedido');
        print('  Email: $email');
        print('  Nome: $displayName');
      }

      // Autentica no Firebase
      final firebaseUser = await _signInOrCreateFirebaseUser(email, displayName);
      
      return firebaseUser;
      
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro no login com Microsoft: $e');
      }
      rethrow;
    }
  }

  /// Obtém informações do usuário do Microsoft Graph
  Future<Map<String, dynamic>?> _getUserInfo() async {
    try {
      if (_aadOAuth == null) return null;
      final token = await _aadOAuth!.getAccessToken();
      
      if (token == null) {
        return null;
      }

      // Em uma implementação real, você faria uma chamada à Microsoft Graph API aqui
      // Por enquanto, vamos retornar informações básicas do token
      // Você pode usar o pacote http para fazer a chamada à API
      
      // Exemplo (implementar depois):
      // final response = await http.get(
      //   Uri.parse('https://graph.microsoft.com/v1.0/me'),
      //   headers: {'Authorization': 'Bearer $token'},
      // );
      
      // Por enquanto, retorna null para usar informações básicas
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao obter info do usuário: $e');
      }
      return null;
    }
  }

  /// Cria ou faz login de usuário no Firebase
  /// NOTA: Isso é uma solução temporária. O ideal é ter um backend.
  Future<User?> _signInOrCreateFirebaseUser(String email, String? displayName) async {
    try {
      // Gera uma senha baseada no email (não seguro, mas funcional para desenvolvimento)
      final password = _generatePasswordFromEmail(email);
      
      // Tenta fazer login
      try {
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        if (kDebugMode) {
          print('✓ Login Firebase bem-sucedido');
        }
        
        return credential.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          // Usuário não existe, cria novo
          if (kDebugMode) {
            print('Criando novo usuário no Firebase...');
          }
          
          final credential = await _firebaseAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          
          // Atualiza display name
          if (displayName != null && credential.user != null) {
            await credential.user!.updateDisplayName(displayName);
            await credential.user!.reload();
          }
          
          if (kDebugMode) {
            print('✓ Usuário criado no Firebase');
          }
          
          return credential.user;
        }
        rethrow;
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao autenticar no Firebase: $e');
      }
      rethrow;
    }
  }

  /// Gera uma senha determinística baseada no email
  /// IMPORTANTE: Isso é apenas para desenvolvimento. Em produção, use custom tokens.
  String _generatePasswordFromEmail(String email) {
    // Gera um hash simples do email
    // Em produção, implemente um backend que gere Firebase custom tokens
    return 'MSAuth_${email.hashCode}_${_clientId.hashCode}';
  }

  /// Verifica se o email é da UDF
  bool isUDFEmail(String email) {
    return FirebaseConfig.isUDFEmail(email);
  }

  /// Realiza login com Microsoft e valida se é email da UDF
  Future<User?> signInWithUDFMicrosoft() async {
    try {
      final user = await signInWithMicrosoft();
      
      if (user != null && user.email != null) {
        if (isUDFEmail(user.email!)) {
          if (kDebugMode) {
            print('✓ Login autorizado: ${user.email}');
          }
          return user;
        } else {
          // Se não for email da UDF, faz logout
          if (kDebugMode) {
            print('✗ Email não é da UDF: ${user.email}');
          }
          await signOut();
          throw Exception('Apenas emails da UDF (@cs.udf.edu.br) são permitidos');
        }
      }
      
      return user;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro no login UDF: $e');
      }
      rethrow;
    }
  }

  /// Realiza logout
  Future<void> signOut() async {
    try {
      // Logout do Firebase
      await _firebaseAuth.signOut();
      
      // Logout do Microsoft
      if (_isInitialized && _aadOAuth != null) {
        try {
          await _aadOAuth!.logout();
          if (kDebugMode) {
            print('✓ Logout Microsoft realizado');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠ Erro no logout Microsoft: $e');
          }
        }
      }

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
      if (_isInitialized && _aadOAuth != null) {
        await _aadOAuth!.logout();
        if (kDebugMode) {
          print('✓ Cache AAD limpo');
        }
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

  /// Verifica se o usuário está autenticado
  Future<bool> isAuthenticated() async {
    await _firebaseAuth.authStateChanges().first;
    return isSignedIn;
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

  /// Obtém token de acesso do Microsoft (útil para chamadas à Microsoft Graph API)
  Future<String?> getMicrosoftAccessToken() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (_aadOAuth == null) return null;
      return await _aadOAuth!.getAccessToken();
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao obter token Microsoft: $e');
      }
      return null;
    }
  }

  /// Verifica se há token válido
  Future<bool> hasCachedAccountInformation() async {
    try {
      if (!_isInitialized || _aadOAuth == null) {
        return false;
      }
      return await _aadOAuth!.hasCachedAccountInformation;
    } catch (e) {
      return false;
    }
  }
}
