import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/auth_token.dart';
import 'firestore_service.dart';

class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  final FirestoreService _firestoreService = FirestoreService();

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

  /// Valida um token de ativação
  Future<bool> validateToken(String token, String email) async {
    try {
      // Usa o FirestoreService para validar e marcar como usado
      final isValid = await _firestoreService.validateAndUseToken(token, email);
      
      if (kDebugMode && isValid) {
        print('✓ Token validado com sucesso: $token');
      }
      
      return isValid;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao validar token: $e');
      }
      return false;
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

  /// Simula o envio de email com token
  /// Em produção, isso seria feito pelo backend
  Future<bool> sendActivationEmail(String email, String token) async {
    try {
      // Simula delay de envio
      await Future.delayed(const Duration(seconds: 1));

      if (kDebugMode) {
        print('📧 Email enviado para $email com token: $token');
        print('📧 Conteúdo do email:');
        print('   Assunto: Ativação da conta - Carona Universitária');
        print('   Token: $token');
        print('   Válido por: 30 minutos');
      }

      // Em produção, fazer chamada para API de envio de email
      // final response = await http.post(
      //   Uri.parse('$_baseUrl/send-activation-email'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({
      //     'email': email,
      //     'token': token,
      //   }),
      // );

      // return response.statusCode == 200;

      // Por enquanto, sempre retorna sucesso (simulação)
      return true;
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
}
