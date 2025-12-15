import 'dart:convert';
import 'package:http/http.dart' as http;

/// Serviço para enviar tokens de verificação/reset por e-mail
/// usando o backend Railway
class EmailTokenService {
  // URL do backend no Railway
  // IMPORTANTE: Substitua pela URL real do seu projeto Railway
  static const String _baseUrl = 'https://seu-projeto.up.railway.app';
  
  // Use esta URL para desenvolvimento local:
  // static const String _baseUrl = 'http://localhost:3000';

  /// Envia token de verificação por e-mail
  /// 
  /// [email] - Email do usuário (deve terminar com @cs.udf.edu.br)
  /// [purpose] - Propósito do token: 'activation' ou 'password_reset'
  /// 
  /// Retorna um Map com:
  /// - success: bool
  /// - message: String
  /// - email: String
  /// - purpose: String
  /// - token: String (apenas em desenvolvimento)
  static Future<Map<String, dynamic>> sendTokenByEmail({
    required String email,
    required String purpose,
  }) async {
    try {
      // Valida email
      if (!email.endsWith('@cs.udf.edu.br')) {
        return {
          'success': false,
          'error': 'invalid_email',
          'message': 'Apenas emails @cs.udf.edu.br são permitidos',
        };
      }

      // Valida purpose
      if (purpose != 'activation' && purpose != 'password_reset') {
        return {
          'success': false,
          'error': 'invalid_purpose',
          'message': 'Purpose deve ser "activation" ou "password_reset"',
        };
      }

      final url = Uri.parse('$_baseUrl/api/send-token-email');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'purpose': purpose,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout ao enviar e-mail. Verifique sua conexão.');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Token enviado por e-mail',
          'email': data['email'],
          'purpose': data['purpose'],
          // Token só vem em modo desenvolvimento
          if (data['token'] != null) 'token': data['token'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'unknown_error',
          'message': data['message'] ?? 'Erro ao enviar token',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'network_error',
        'message': 'Erro de conexão: ${e.toString()}',
      };
    }
  }

  /// Envia token de ativação por e-mail
  static Future<Map<String, dynamic>> sendActivationToken(String email) {
    return sendTokenByEmail(email: email, purpose: 'activation');
  }

  /// Envia token de reset de senha por e-mail
  static Future<Map<String, dynamic>> sendPasswordResetToken(String email) {
    return sendTokenByEmail(email: email, purpose: 'password_reset');
  }

  /// Valida token com o backend
  /// 
  /// [email] - Email do usuário
  /// [token] - Token de 6 dígitos recebido por e-mail
  /// [markAsUsed] - Se deve marcar o token como usado
  static Future<Map<String, dynamic>> validateToken({
    required String email,
    required String token,
    bool markAsUsed = false,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/validate-token');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'token': token,
          'markAsUsed': markAsUsed,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout ao validar token. Verifique sua conexão.');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'isValid': data['isValid'] ?? false,
          'token': data['token'],
          'email': data['email'],
          'purpose': data['purpose'],
          'expiresAt': data['expiresAt'],
        };
      } else {
        return {
          'success': false,
          'isValid': false,
          'error': data['error'] ?? 'unknown_error',
          'message': data['message'] ?? 'Erro ao validar token',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'isValid': false,
        'error': 'network_error',
        'message': 'Erro de conexão: ${e.toString()}',
      };
    }
  }

  /// Redefine senha usando token
  /// 
  /// [email] - Email do usuário
  /// [token] - Token de 6 dígitos recebido por e-mail
  /// [newPassword] - Nova senha (mínimo 8 caracteres)
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      // Valida senha
      if (newPassword.length < 8) {
        return {
          'success': false,
          'error': 'weak_password',
          'message': 'A senha deve ter no mínimo 8 caracteres',
        };
      }

      final url = Uri.parse('$_baseUrl/api/reset-password');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'token': token,
          'newPassword': newPassword,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout ao redefinir senha. Verifique sua conexão.');
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Senha redefinida com sucesso',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'unknown_error',
          'message': data['message'] ?? 'Erro ao redefinir senha',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'network_error',
        'message': 'Erro de conexão: ${e.toString()}',
      };
    }
  }
}
