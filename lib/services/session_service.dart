import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Serviço para gerenciar sessão persistente do usuário
class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';

  /// Verifica se o usuário está logado (persistido)
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao verificar sessão: $e');
      }
      return false;
    }
  }

  /// Salva informações da sessão
  Future<void> saveSession({
    required String userId,
    required String email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserId, userId);
      await prefs.setString(_keyUserEmail, email);

      if (kDebugMode) {
        print('✓ Sessão salva: $email');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao salvar sessão: $e');
      }
      rethrow;
    }
  }

  /// Limpa a sessão
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserEmail);

      if (kDebugMode) {
        print('✓ Sessão limpa');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao limpar sessão: $e');
      }
    }
  }

  /// Obtém o ID do usuário salvo
  Future<String?> getSavedUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserId);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao obter userId: $e');
      }
      return null;
    }
  }

  /// Obtém o email do usuário salvo
  Future<String?> getSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserEmail);
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao obter email: $e');
      }
      return null;
    }
  }
}

