// Serviço de autenticação - gerencia login, cadastro, reset de senha e validação de tokens
// Integra Firebase Auth com Cloud Functions para operações seguras

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/firebase_config.dart';
import 'token_service.dart';
import 'firestore_service.dart';
import 'account_deletion_service.dart';
import '../models/auth_user.dart';

// Classe singleton que centraliza todas as operações de autenticação do sistema
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
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
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
  Future<User?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
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

        // Envia email de verificação automaticamente após criar conta
        try {
          await user.sendEmailVerification();
          if (kDebugMode) {
            print(
              '✓ Email de verificação enviado automaticamente para: ${user.email}',
            );
          }
        } catch (e) {
          // Não bloqueia a criação da conta se o envio de email falhar
          if (kDebugMode) {
            print('⚠ Não foi possível enviar email de verificação: $e');
          }
        }

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
  Future<User?> createAccountAfterTokenValidation(
    String email,
    String password,
  ) async {
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

  /// Redefine a senha após validação do token
  /// IMPORTANTE: Este método requer que o usuário esteja autenticado
  /// Para reset sem autenticação, use Firebase Admin SDK ou Cloud Functions
  Future<void> resetPassword(String email, String newPassword) async {
    try {
      if (!isUDFEmail(email)) {
        throw Exception('Apenas emails @cs.udf.edu.br são permitidos');
      }

      // Verifica se há um usuário autenticado
      final currentUser = _firebaseAuth.currentUser;

      if (currentUser != null && currentUser.email == email) {
        // Se o usuário já está autenticado, atualiza a senha diretamente
        await currentUser.updatePassword(newPassword);

        if (kDebugMode) {
          print('✓ Senha atualizada com sucesso para: $email');
        }
      } else {
        // Se não está autenticado, tenta fazer login primeiro
        // NOTA: Isso requer que o usuário ainda saiba a senha antiga
        // Para uma solução completa, você precisaria de um backend com Admin SDK
        throw Exception(
          'Para redefinir a senha, você precisa estar autenticado. '
          'Por favor, faça login primeiro ou use o link de recuperação do Firebase.',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao redefinir senha: $e');
      }
      rethrow;
    }
  }

  /// Redefine a senha usando token via Backend API ou Cloud Functions
  /// Esta solução atualiza a senha diretamente no Firebase Authentication
  /// Fluxo simplificado: validar token → atualizar senha automaticamente
  ///
  /// Tenta primeiro usar Backend API (funciona sem plano Blaze)
  /// Se não configurado, tenta usar Cloud Functions
  Future<void> resetPasswordWithToken(
    String email,
    String token,
    String newPassword,
  ) async {
    try {
      // Verificação básica do token (já foi validado antes, mas valida novamente para segurança)
      final isTokenValid = await _tokenService.validateToken(token, email);

      if (!isTokenValid) {
        throw Exception('Token expirado. Por favor, solicite um novo código.');
      }

      // Tenta primeiro usar Backend API (se configurado)
      // Configure a URL do backend em FirebaseConfig.backendUrl
      final backendUrl = FirebaseConfig.backendUrl;
      if (backendUrl != null && backendUrl.isNotEmpty) {
        try {
          if (kDebugMode) {
            print('📡 Chamando Backend API para reset de senha...');
          }

          final uri = Uri.parse(backendUrl);
          if (!uri.hasScheme) {
            throw Exception(
              'URL do backend inválida. Verifique a configuração em FirebaseConfig.',
            );
          }

          final response = await http
              .post(
                Uri.parse('$backendUrl/api/reset-password'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'email': email,
                  'token': token,
                  'newPassword': newPassword,
                }),
              )
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () {
                  throw Exception(
                    'Tempo esgotado. Verifique sua conexão e tente novamente.',
                  );
                },
              );

          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;

          if (response.statusCode == 200 && responseData['success'] == true) {
            await _tokenService.invalidateToken(token, email);
            if (kDebugMode) {
              print('✓ Senha redefinida com sucesso via Backend API!');
            }
            return;
          } else {
            // Extrai mensagem de erro específica do backend
            final errorMessage =
                responseData['message'] ??
                responseData['error'] ??
                'Erro ao redefinir senha';

            // Trata erros específicos do backend
            if (response.statusCode == 404 ||
                errorMessage.toString().toLowerCase().contains(
                  'não encontrado',
                ) ||
                errorMessage.toString().toLowerCase().contains('not found')) {
              throw Exception(
                'Token invalido ou expirado. Por favor solicite um novo código.',
              );
            } else if (response.statusCode == 403 ||
                errorMessage.toString().toLowerCase().contains('expirado') ||
                errorMessage.toString().toLowerCase().contains('expired')) {
              throw Exception(
                'Token invalido ou expirado. Por favor solicite um novo código.',
              );
            }

            throw Exception(errorMessage);
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠ Erro ao chamar Backend API: $e');
            print('⚠ Tentando Cloud Functions como fallback...');
          }
          // Continua para tentar Cloud Functions
        }
      }

      // Fallback: Tenta usar Cloud Functions
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'resetPassword',
        );

        if (kDebugMode) {
          print('📡 Chamando Cloud Function resetPassword...');
        }

        final result = await callable
            .call({'email': email, 'token': token, 'newPassword': newPassword})
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception(
                  'Tempo esgotado. Verifique sua conexão e tente novamente.',
                );
              },
            );

        if (result.data['success'] == true) {
          if (kDebugMode) {
            print('✓ Senha redefinida com sucesso via Cloud Function!');
          }
          return;
        } else {
          throw Exception(result.data['message'] ?? 'Erro ao redefinir senha');
        }
      } on FirebaseFunctionsException catch (e) {
        // Trata erros específicos da Cloud Function
        String errorMessage = 'Erro ao redefinir senha';

        switch (e.code) {
          case 'not-found':
            errorMessage =
                'Token invalido ou expirado. Por favor solicite um novo código.';
            break;
          case 'permission-denied':
            errorMessage = 'Token já foi usado ou não corresponde ao email.';
            break;
          case 'deadline-exceeded':
            errorMessage = 'Token expirado. Solicite um novo código.';
            break;
          case 'invalid-argument':
            errorMessage =
                e.message ?? 'Dados inválidos. Verifique e tente novamente.';
            break;
          case 'unavailable':
            errorMessage =
                'Serviço temporariamente indisponível. Tente novamente em alguns instantes.';
            break;
          default:
            errorMessage =
                e.message ??
                'Erro ao conectar ao servidor. Verifique sua conexão.';
        }

        throw Exception(errorMessage);
      } catch (e) {
        // Se nenhuma solução está disponível
        if (e.toString().contains('NOT_FOUND') ||
            e.toString().contains('not found')) {
          throw Exception(
            'Serviço de reset não configurado.\n\n'
            'Opções:\n'
            '1. Configure Backend API (ver backend/README.md)\n'
            '2. OU faça deploy de Cloud Functions (ver GUIA_DEPLOY_CLOUD_FUNCTIONS.md)\n\n'
            'Por enquanto, o email do Firebase foi enviado (verifique spam).',
          );
        }
        rethrow;
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao redefinir senha com token: $e');
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

  // ===========================================================================
  // VERIFICAÇÃO DE EMAIL
  // ===========================================================================

  /// Envia email de verificação para o usuário atual
  Future<bool> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      // Verifica se o email já está verificado
      if (user.emailVerified) {
        if (kDebugMode) {
          print('⚠ Email já está verificado');
        }
        return true;
      }

      // Envia email de verificação
      await user.sendEmailVerification();

      if (kDebugMode) {
        print('✓ Email de verificação enviado para: ${user.email}');
      }

      return true;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(
          '✗ Erro ao enviar email de verificação: ${e.code} - ${e.message}',
        );
      }

      String errorMessage = 'Erro ao enviar email de verificação';
      if (e.code == 'too-many-requests') {
        errorMessage =
            'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'Usuário não encontrado';
      }

      throw Exception(errorMessage);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao enviar email de verificação: $e');
      }
      rethrow;
    }
  }

  /// Recarrega dados do usuário atual (útil após verificar email)
  Future<void> reloadUser() async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.reload();

        if (kDebugMode) {
          print('✓ Dados do usuário recarregados');
          print('  Email verificado: ${user.emailVerified}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao recarregar usuário: $e');
      }
      rethrow;
    }
  }

  /// Verifica se o email do usuário atual está verificado
  bool get isEmailVerified {
    return currentUser?.emailVerified ?? false;
  }

  /// Atualiza o perfil do usuário (nome e foto)
  Future<bool> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      // Atualiza no Firebase Auth
      bool updated = false;
      bool shouldReload = false;

      String? normalizedPhotoURL = photoURL;
      final isDataUri = photoURL != null && photoURL.startsWith('data:image');
      final exceedsLimit = photoURL != null && photoURL.length > 2048;
      if (isDataUri || exceedsLimit) {
        if (kDebugMode) {
          print(
            '⚠ Foto de perfil não atualizada no Firebase Auth (formato/tamanho inválido). '
            'Ela será usada apenas via Firestore.',
          );
        }
        normalizedPhotoURL = null;
      }

      if (displayName != null && displayName != user.displayName) {
        await user.updateDisplayName(displayName);
        shouldReload = true;
        updated = true;

        if (kDebugMode) {
          print('✓ Nome atualizado: $displayName');
        }
      }

      final wantsRemovePhoto = photoURL == null;
      if (wantsRemovePhoto && user.photoURL != null) {
        await user.updatePhotoURL(null);
        shouldReload = true;
        updated = true;

        if (kDebugMode) {
          print('✓ Foto de perfil removida do Firebase Auth');
        }
      } else if (normalizedPhotoURL != null &&
          normalizedPhotoURL != user.photoURL) {
        await user.updatePhotoURL(normalizedPhotoURL);
        shouldReload = true;
        updated = true;

        if (kDebugMode) {
          print('✓ Foto de perfil atualizada (Firebase Auth)');
        }
      } else if (photoURL != null && normalizedPhotoURL == null && kDebugMode) {
        print(
          '⚠ Foto de perfil ignorada no Firebase Auth (provavelmente Base64 ou muito grande).',
        );
      }

      // Atualiza no Firestore também
      if (shouldReload) {
        await user.reload(); // Recarrega para obter dados atualizados
      }

      if (updated) {
        final authUser = AuthUser.fromFirebaseUser(user);
        await _firestoreService.saveUser(authUser);
      }

      return updated;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao atualizar perfil: ${e.code} - ${e.message}');
      }

      String errorMessage = 'Erro ao atualizar perfil';
      if (e.code == 'requires-recent-login') {
        errorMessage =
            'Por favor, faça login novamente para atualizar o perfil';
      }

      throw Exception(errorMessage);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao atualizar perfil: $e');
      }
      rethrow;
    }
  }

  // ===========================================================================
  // RECUPERAÇÃO DE SENHA
  // ===========================================================================

  /// Envia email de recuperação de senha usando EmailJS
  /// Cria um token customizado e envia via EmailService
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      // Valida se é email da UDF
      if (!isUDFEmail(email)) {
        throw Exception('Apenas emails @cs.udf.edu.br são permitidos');
      }

      // Tenta verificar se o usuário existe no Firebase Auth
      // Nota: Esta verificação pode falhar mesmo se o usuário existir,
      // então não bloqueamos o envio do email se a verificação falhar
      bool userExists = false;

      if (kDebugMode) {
        print('🔍 Verificando se usuário existe: $email');
      }

      try {
        final methods = await _firebaseAuth.fetchSignInMethodsForEmail(email);

        if (kDebugMode) {
          print('   Métodos de login encontrados: $methods');
        }

        userExists = methods.isNotEmpty;

        if (!userExists) {
          if (kDebugMode) {
            print('⚠ Aviso: fetchSignInMethodsForEmail retornou vazio');
            print('💡 Isso pode acontecer mesmo se o usuário existir');
            print('💡 Continuando com o envio do email...');
          }
        }
      } on FirebaseAuthException catch (e) {
        if (kDebugMode) {
          print(
            '⚠ Erro ao verificar usuário (não bloqueante): ${e.code} - ${e.message}',
          );
          print('💡 Continuando com o envio do email...');
        }
        // Não bloqueia o envio se a verificação falhar
        userExists = false;
      } catch (e) {
        if (kDebugMode) {
          print('⚠ Erro ao verificar usuário (não bloqueante): $e');
          print('💡 Continuando com o envio do email...');
        }
        userExists = false;
      }

      // Se a verificação indicar que o usuário não existe, apenas logamos
      // mas não bloqueamos o envio, pois fetchSignInMethodsForEmail pode falhar
      // mesmo quando o usuário existe (problema conhecido do Firebase)
      if (!userExists) {
        if (kDebugMode) {
          print(
            '💡 Nota: fetchSignInMethodsForEmail pode retornar vazio mesmo se o usuário existir',
          );
          print('💡 Continuando com o envio do email via EmailJS...');
          print(
            '💡 Se o email não chegar, verifique no console do Firebase se o usuário existe',
          );
        }
      }

      // Cria token de reset usando TokenService
      final token = await _tokenService.createPasswordResetToken(email);

      // Envia email via EmailJS
      final emailSent = await _tokenService.sendPasswordResetEmail(
        email,
        token.token,
      );

      if (emailSent) {
        if (kDebugMode) {
          print('✓ Email de recuperação de senha enviado para: $email');
          print('   Token: ${token.token}');
        }
        return true;
      } else {
        throw Exception(
          'Falha ao enviar email. Verifique a configuração do EmailJS.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(
          '✗ Erro ao enviar email de recuperação: ${e.code} - ${e.message}',
        );
      }

      String errorMessage = 'Erro ao enviar email de recuperação';
      if (e.code == 'user-not-found') {
        errorMessage = 'Nenhuma conta encontrada com este email';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Email inválido';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Muitas tentativas. Tente novamente mais tarde.';
      }

      throw Exception(errorMessage);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao enviar email de recuperação: $e');
      }
      rethrow;
    }
  }

  // ===========================================================================
  // EXCLUSÃO DE CONTA (DIREITO AO ESQUECIMENTO LGPD)
  // ===========================================================================

  /// Exclui completamente a conta do usuário e todos os seus dados
  ///
  /// Implementa o direito ao esquecimento (LGPD) e remove:
  /// - Dados do Firestore (usuário, consentimentos, veículos, caronas, etc.)
  /// - Arquivos do Storage (fotos de perfil, documentos, etc.)
  /// - Conta do Firebase Auth
  ///
  /// IMPORTANTE: Esta operação é irreversível!
  ///
  /// Retorna true se a exclusão foi bem-sucedida, false caso contrário
  Future<bool> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      // Importa o serviço de exclusão de conta
      final accountDeletionService = AccountDeletionService();

      // Executa a exclusão completa
      return await accountDeletionService.deleteAccount(user.uid);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao excluir conta: $e');
      }
      rethrow;
    }
  }
}
