import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../models/auth_user.dart';
import '../services/notification_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final SessionService _sessionService = SessionService();
  final NotificationService _notificationService = NotificationService();

  AuthStatus _status = AuthStatus.initial;
  AuthUser? _user;
  String? _errorMessage;

  // Getters
  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _user != null;
  bool get isLoading => _status == AuthStatus.loading;

  AuthProvider() {
    _initializeAuth();
  }

  /// Inicializa o serviço de autenticação
  Future<void> _initializeAuth() async {
    try {
      _setStatus(AuthStatus.loading);

      await _authService.initialize();

      // Verifica se já existe um usuário autenticado
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        _user = AuthUser.fromFirebaseUser(currentUser);
        _setStatus(AuthStatus.authenticated);

        // Salva sessão persistentemente
        await _sessionService.saveSession(
          userId: currentUser.uid,
          email: currentUser.email ?? '',
        );

        await _notificationService.syncPreferencesForUser(_user);
      } else {
        _setStatus(AuthStatus.unauthenticated);
      }

      // Escuta mudanças no estado de autenticação
      _authService.authStateChanges.listen(_onAuthStateChanged);
    } catch (e) {
      _setError('Erro ao inicializar autenticação: $e');
    }
  }

  /// Callback para mudanças no estado de autenticação
  void _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser != null) {
      _user = AuthUser.fromFirebaseUser(firebaseUser);
      _setStatus(AuthStatus.authenticated);

      // Salva sessão persistentemente
      await _sessionService.saveSession(
        userId: firebaseUser.uid,
        email: firebaseUser.email ?? '',
      );

      await _notificationService.syncPreferencesForUser(_user);
    } else {
      _user = null;
      _setStatus(AuthStatus.unauthenticated);

      // Limpa sessão
      await _sessionService.clearSession();
    }
  }

  /// Realiza logout
  Future<void> signOut() async {
    try {
      _setStatus(AuthStatus.loading);
      _clearError();

      final userId = _user?.uid;
      await _notificationService.clearDeviceState(userId);
      await _authService.signOut();

      _user = null;
      _setStatus(AuthStatus.unauthenticated);

      if (kDebugMode) {
        print('Logout realizado com sucesso');
      }
    } catch (e) {
      _setError('Erro no logout: $e');
    }
  }

  /// Limpa cache de autenticação
  Future<void> clearCache() async {
    try {
      await _authService.clearCache();
      if (kDebugMode) {
        print('Cache limpo com sucesso');
      }
    } catch (e) {
      _setError('Erro ao limpar cache: $e');
    }
  }

  /// Exclui completamente a conta do usuário (Direito ao Esquecimento)
  Future<void> deleteAccount() async {
    try {
      if (_user == null) {
        _setError('Nenhum usuário autenticado para exclusão');
        return;
      }

      _setStatus(AuthStatus.loading);
      _clearError();

      final deleted = await _authService.deleteAccount();

      if (!deleted) {
        _setError(
          'Não foi possível excluir a conta. Tente novamente mais tarde.',
        );
        return;
      }

      await _sessionService.clearSession();
      _user = null;
      _setStatus(AuthStatus.unauthenticated);
    } catch (e) {
      final message = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : '$e';
      _setError('Erro ao excluir conta: $message');
      rethrow;
    }
  }

  /// Verifica se o usuário está autenticado
  Future<bool> checkAuthStatus() async {
    try {
      final isAuth = await _authService.isAuthenticated();

      if (isAuth && _user == null) {
        // Se está autenticado mas não temos dados do usuário, atualiza
        final firebaseUser = _authService.currentUser;
        if (firebaseUser != null) {
          _user = AuthUser.fromFirebaseUser(firebaseUser);
          _setStatus(AuthStatus.authenticated);
        }
      }

      return isAuth;
    } catch (e) {
      _setError('Erro ao verificar status: $e');
      return false;
    }
  }

  /// Força refresh do token
  Future<void> refreshToken() async {
    try {
      await _authService.refreshToken();

      // Atualiza dados do usuário
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        _user = AuthUser.fromFirebaseUser(firebaseUser);
        notifyListeners();
      }
    } catch (e) {
      _setError('Erro ao refresh token: $e');
    }
  }

  /// Recarrega dados do usuário (útil após verificar email)
  Future<void> refreshUser() async {
    try {
      await _authService.reloadUser();

      // Atualiza dados do usuário
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        _user = AuthUser.fromFirebaseUser(firebaseUser);
        notifyListeners();
      }
    } catch (e) {
      _setError('Erro ao recarregar usuário: $e');
    }
  }

  /// Define o status e notifica listeners
  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  /// Define erro e notifica listeners
  void _setError(String error) {
    _errorMessage = error;
    _status = AuthStatus.error;
    notifyListeners();

    if (kDebugMode) {
      print('AuthProvider Error: $error');
    }
  }

  /// Limpa erro
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpa erro manualmente
  void clearError() {
    _clearError();
  }

  /// Obtém informações do usuário atual
  Map<String, dynamic>? getCurrentUserInfo() {
    return _user?.toMap();
  }

  /// Verifica se o email é da UDF
  bool isUDFEmail(String email) {
    return _authService.isUDFEmail(email);
  }
}
