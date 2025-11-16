import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/auth_token.dart';
import 'email_service.dart';

class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  final EmailService _emailService = EmailService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Valida se o email é da UDF
  bool _isValidUDFEmail(String email) {
    return email.endsWith('@cs.udf.edu.br');
  }

  Future<AuthToken> _issueToken({
    required String email,
    required String purpose,
  }) async {
    try {
      if (!_isValidUDFEmail(email)) {
        throw Exception('Apenas emails @cs.udf.edu.br são permitidos');
      }

      final callable = _functions.httpsCallable('issueActivationToken');
      final result = await callable
          .call({'email': email, 'purpose': purpose})
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Tempo esgotado ao gerar token. Verifique sua conexão e tente novamente.',
              );
            },
          );

      final rawData = result.data;
      if (rawData is! Map) {
        throw Exception('Resposta inválida da Cloud Function ao gerar token.');
      }

      final data = Map<String, dynamic>.from(rawData);
      final createdAtMillis = (data['createdAt'] as num?)?.toInt();
      final expiresAtMillis = (data['expiresAt'] as num?)?.toInt();

      if (createdAtMillis == null || expiresAtMillis == null) {
        throw Exception(
          'Resposta incompleta da Cloud Function ao gerar token.',
        );
      }

      return AuthToken(
        token: data['token'] as String? ?? '',
        email: data['email'] as String? ?? email,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMillis),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMillis),
        isUsed: data['isUsed'] as bool? ?? false,
        userId: data['userId'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '✗ Erro na Cloud Function issueActivationToken: ${e.code} - ${e.message}',
        );
      }

      if (e.code == 'unimplemented' ||
          e.code == 'internal' ||
          e.code == 'unavailable') {
        throw Exception(
          e.message ??
              'Cloud Function não disponível. Verifique o deploy do backend.',
        );
      }

      throw Exception(e.message ?? 'Erro ao gerar token. Tente novamente.');
    }
  }

  /// Cria um novo token de ativação
  Future<AuthToken> createActivationToken(String email) async {
    try {
      final token = await _issueToken(email: email, purpose: 'activation');

      if (kDebugMode) {
        print('✓ Token criado via Cloud Function: ${token.token} para $email');
      }

      return token;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao criar token: $e');
      }
      rethrow;
    }
  }

  /// Valida um token de ativação (sem marcar como usado)
  /// Use este método para validação inicial antes de navegar para tela de reset
  Future<bool> validateToken(
    String token,
    String email, {
    bool markAsUsed = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('validateActivationToken');
      final result = await callable
          .call({'token': token, 'email': email, 'markAsUsed': markAsUsed})
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Tempo esgotado ao validar token. Verifique sua conexão e tente novamente.',
              );
            },
          );

      final rawData = result.data;
      if (rawData is! Map) {
        throw Exception(
          'Resposta inválida da Cloud Function ao validar token.',
        );
      }

      final data = Map<String, dynamic>.from(rawData);
      final isValid = data['isValid'] == true;

      if (kDebugMode && isValid) {
        print('✓ Token validado com sucesso via Cloud Function: $token');
      }

      return isValid;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          '✗ Erro na Cloud Function validateActivationToken: ${e.code} - ${e.message}',
        );
      }

      // Erros esperados de validação retornam false
      if (e.code == 'not-found' ||
          e.code == 'permission-denied' ||
          e.code == 'deadline-exceeded' ||
          e.code == 'invalid-argument') {
        return false;
      }

      // Função não configurada ou indisponível - repassa erro para UI orientar setup
      if (e.code == 'unimplemented' ||
          e.code == 'internal' ||
          e.code == 'unavailable') {
        throw Exception(
          e.message ??
              'Cloud Function não disponível. Verifique o deploy do backend.',
        );
      }

      throw Exception(e.message ?? 'Erro ao validar token. Tente novamente.');
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro genérico ao validar token: $e');
      }
      rethrow;
    }
  }

  /// Invalida um token marcando-o como usado
  Future<void> invalidateToken(String token, String email) async {
    try {
      await validateToken(token, email, markAsUsed: true);
    } catch (e) {
      if (kDebugMode) {
        print('⚠ Não foi possível invalidar o token $token: $e');
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
          print(
            '⚠ Email não foi enviado. Verifique a configuração do EmailService.',
          );
          print(
            '💡 Configure EmailJS, Resend ou Mailgun em lib/services/email_service.dart',
          );
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
        utf8.encode(
          '${email}_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(10000)}',
        ),
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
      final token = await _issueToken(email: email, purpose: 'password_reset');

      if (kDebugMode) {
        print(
          '✓ Token de reset de senha criado via Cloud Function: ${token.token} para $email',
        );
      }

      return token;
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
          print(
            '⚠ Email não foi enviado. Verifique a configuração do EmailService.',
          );
          print(
            '💡 Configure EmailJS, Resend ou Mailgun em lib/services/email_service.dart',
          );
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
