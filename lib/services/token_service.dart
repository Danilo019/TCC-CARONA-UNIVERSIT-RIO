import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/auth_token.dart';
import 'firestore_service.dart';
import 'email_service.dart';

class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final EmailService _emailService = EmailService();

  /// Gera um token único de 6 dígitos
  String _generateToken() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Valida se o email é da UDF
  bool _isValidUDFEmail(String email) {
    return email.endsWith('@cs.udf.edu.br');
  }

  /// Cria um novo token de ativação
  Future<AuthToken> createActivationToken(String email) async {
    try {
      // Valida o email
      if (!_isValidUDFEmail(email)) {
        throw Exception('Apenas emails @cs.udf.edu.br são permitidos');
      }

      // Gera token único
      String token;
      bool isUnique = false;
      int attempts = 0;
      const maxAttempts = 10;

      do {
        token = _generateToken();
        attempts++;
        
        // Verifica se o token já existe no Firestore
        final existingToken = await _firestoreService.getActivationToken(token);
        isUnique = existingToken == null;
        
        if (attempts >= maxAttempts) {
          throw Exception('Não foi possível gerar um token único após $maxAttempts tentativas');
        }
      } while (!isUnique);

      // Cria o token com expiração de 30 minutos
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 30));

      final authToken = AuthToken(
        token: token,
        email: email,
        createdAt: now,
        expiresAt: expiresAt,
      );

      // Salva no Firestore
      await _firestoreService.saveActivationToken(authToken);

      if (kDebugMode) {
        print('✓ Token criado: $token para $email (expira em: $expiresAt)');
      }

      return authToken;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar token: $e');
      }
      rethrow;
    }
  }

  /// Valida um token de ativação (sem marcar como usado)
  /// Use este método para validação inicial antes de navegar para tela de reset
  Future<bool> validateToken(String token, String email) async {
    try {
      // Valida sem marcar como usado (será marcado quando o reset for bem-sucedido)
      final isValid = await _firestoreService.validateTokenOnly(token, email);
      
      if (kDebugMode && isValid) {
        print('✓ Token validado com sucesso (aguardando reset): $token');
      }
      
      return isValid;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao validar token: $e');
      }
      return false;
    }
  }

  /// Marca um token como usado (para ser chamado após reset bem-sucedido)
  /// O backend já marca como usado, mas este método serve como backup
  Future<void> markTokenAsUsed(String token) async {
    try {
      final doc = await _firestoreService.getActivationToken(token);
      if (doc != null && !doc.isUsed) {
        // Usa o método validateAndUseToken para marcar como usado
        // Isso garante que a marcação seja feita corretamente
        await _firestoreService.validateAndUseToken(token, doc.email);
        if (kDebugMode) {
          print('✓ Token marcado como usado (backup): $token');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Erro ao marcar token como usado: $e');
      }
      // Não lança exceção - o backend já marca como usado
    }
  }

  /// Obtém informações de um token
  Future<AuthToken?> getToken(String token) async {
    try {
      return await _firestoreService.getActivationToken(token);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao buscar token: $e');
      }
      return null;
    }
  }

  /// Remove tokens expirados
  Future<void> cleanExpiredTokens() async {
    try {
      await _firestoreService.cleanExpiredTokens();
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao limpar tokens expirados: $e');
      }
    }
  }

  /// Envia email de ativação com token
  /// Usa EmailService para envio real
  Future<bool> sendActivationEmail(String email, String token) async {
    try {
      // Extrai o nome do usuário do email (parte antes do @)
      final userName = email.split('@').first;

      // Envia email real usando EmailService
      final emailSent = await _emailService.sendActivationEmail(
        toEmail: email,
        token: token,
        userName: userName,
      );

      if (emailSent) {
        if (kDebugMode) {
          print('✓ Email de ativação enviado para: $email');
          print('   Token: $token');
          print('   Válido por: 30 minutos');
        }
      } else {
        if (kDebugMode) {
          print('⚠ Email não foi enviado. Verifique a configuração do EmailService.');
          print('💡 Configure EmailJS, Resend ou Mailgun em lib/services/email_service.dart');
        }
      }

      return emailSent;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao enviar email: $e');
      }
      return false;
    }
  }

  /// Cria um token de sessão após ativação bem-sucedida
  Future<String> createSessionToken(String email) async {
    try {
      // Gera um token de sessão mais longo
      final random = Random();
      final sessionToken = base64Encode(
        utf8.encode('${email}_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(10000)}')
      );

      if (kDebugMode) {
        print('✓ Token de sessão criado para: $email');
      }

      return sessionToken;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar token de sessão: $e');
      }
      rethrow;
    }
  }

  /// Valida um token de sessão
  Future<bool> validateSessionToken(String sessionToken) async {
    try {
      // Decodifica o token
      final decoded = utf8.decode(base64Decode(sessionToken));
      final parts = decoded.split('_');
      
      if (parts.length < 3) {
        return false;
      }

      final email = parts[0];
      final timestamp = int.tryParse(parts[1]);
      
      if (timestamp == null) {
        return false;
      }

      // Verifica se o token não expirou (30 minutos)
      final tokenTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(tokenTime);

      if (difference.inMinutes > 30) {
        if (kDebugMode) {
          print('✗ Token de sessão expirado');
        }
        return false;
      }

      // Verifica se é email da UDF
      if (!_isValidUDFEmail(email)) {
        return false;
      }

      if (kDebugMode) {
        print('✓ Token de sessão válido para: $email');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao validar token de sessão: $e');
      }
      return false;
    }
  }

  /// Obtém o email de um token de sessão
  String? getEmailFromSessionToken(String sessionToken) {
    try {
      final decoded = utf8.decode(base64Decode(sessionToken));
      final parts = decoded.split('_');
      return parts.isNotEmpty ? parts[0] : null;
    } catch (e) {
      return null;
    }
  }

  /// Cria um token de reset de senha
  Future<AuthToken> createPasswordResetToken(String email) async {
    try {
      // Valida o email
      if (!_isValidUDFEmail(email)) {
        throw Exception('Apenas emails @cs.udf.edu.br são permitidos');
      }

      // Gera token único
      String token;
      bool isUnique = false;
      int attempts = 0;
      const maxAttempts = 10;

      do {
        token = _generateToken();
        attempts++;
        
        // Verifica se o token já existe no Firestore
        final existingToken = await _firestoreService.getActivationToken(token);
        isUnique = existingToken == null;
        
        if (attempts >= maxAttempts) {
          throw Exception('Não foi possível gerar um token único após $maxAttempts tentativas');
        }
      } while (!isUnique);

      // Cria o token com expiração de 30 minutos
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 30));

      final authToken = AuthToken(
        token: token,
        email: email,
        createdAt: now,
        expiresAt: expiresAt,
      );

      // Salva no Firestore (pode usar o mesmo método de ativação)
      await _firestoreService.saveActivationToken(authToken);

      if (kDebugMode) {
        print('✓ Token de reset de senha criado: $token para $email (expira em: $expiresAt)');
      }

      return authToken;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar token de reset: $e');
      }
      rethrow;
    }
  }

  /// Envia email de reset de senha com token
  /// Usa EmailService para envio real via EmailJS
  Future<bool> sendPasswordResetEmail(String email, String token) async {
    try {
      // Extrai o nome do usuário do email (parte antes do @)
      final userName = email.split('@').first;

      // Como é um app mobile, não precisamos de link web
      // O usuário irá colar o token diretamente no app
      // Mantemos resetLink vazio ou apenas para referência
      final resetLink = ''; // Não usado para app mobile

      // Envia email real usando EmailService
      // Passa o token para que apareça destacado no email
      final emailSent = await _emailService.sendPasswordResetEmail(
        toEmail: email,
        resetLink: resetLink,
        userName: userName,
        token: token, // Token para aparecer no email
      );

      if (emailSent) {
        if (kDebugMode) {
          print('✓ Email de reset de senha enviado para: $email');
          print('   Token: $token');
          print('   Válido por: 30 minutos');
        }
      } else {
        if (kDebugMode) {
          print('⚠ Email não foi enviado. Verifique a configuração do EmailService.');
          print('💡 Configure EmailJS, Resend ou Mailgun em lib/services/email_service.dart');
        }
      }

      return emailSent;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao enviar email de reset: $e');
      }
      return false;
    }
  }
}
