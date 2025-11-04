import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/token_service.dart';
import '../services/firestore_service.dart';
import '../utils/password_validator.dart';
import '../widgets/password_strength_indicator.dart';

/// Tela para definir nova senha após validação do token
/// Implementa validação de força de senha, segurança e conformidade LGPD
class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String token; // Token já validado

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.token,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  final TokenService _tokenService = TokenService();
  final FirestoreService _firestoreService = FirestoreService();
  
  bool _isLoading = false;
  bool _passwordReset = false;
  String? _errorMessage;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  PasswordStrength _currentStrength = PasswordStrength.veryWeak;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onPasswordChanged);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    final password = _newPasswordController.text;
    if (password.isNotEmpty) {
      final result = PasswordValidator.validatePassword(password);
      setState(() {
        _currentStrength = result.strength;
      });
    } else {
      setState(() {
        _currentStrength = PasswordStrength.veryWeak;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Nova Senha'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Ícone
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset,
                    size: 40,
                    color: Color(0xFF2196F3),
                  ),
                ),

                const SizedBox(height: 24),

                // Título
                if (!_passwordReset)
                  const Text(
                    'Defina sua nova senha',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  const Text(
                    'Senha redefinida!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),

                const SizedBox(height: 12),

                // Descrição
                if (!_passwordReset)
                  Text(
                    'Email: ${widget.email}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 60,
                          color: Colors.green[700],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sua senha foi redefinida com sucesso!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Campos de senha (só mostra se ainda não resetou)
                if (!_passwordReset) ...[
                  // Campo Nova Senha
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    enabled: !_isLoading,
                    inputFormatters: [
                      // Não permite copiar/colar senha por segurança
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Nova Senha',
                      hintText: 'Digite sua nova senha',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Digite a nova senha';
                      }
                      
                      final validation = PasswordValidator.validatePassword(value);
                      if (!validation.isValid) {
                        return validation.message ?? 'Senha não atende aos requisitos';
                      }
                      
                      // Verifica se contém informações pessoais
                      if (PasswordValidator.containsPersonalInfo(value, widget.email)) {
                        return 'A senha não deve conter informações do seu email';
                      }
                      
                      return null;
                    },
                  ),

                  // Indicador de força da senha
                  if (_newPasswordController.text.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    PasswordStrengthIndicator(
                      strength: _currentStrength,
                      showLabel: true,
                    ),
                  ],

                  // Requisitos da senha
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A senha deve conter:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRequirement('Mínimo de 8 caracteres', _newPasswordController.text.length >= 8),
                        _buildRequirement('1 letra maiúscula', _newPasswordController.text.contains(RegExp(r'[A-Z]'))),
                        _buildRequirement('1 número', _newPasswordController.text.contains(RegExp(r'[0-9]'))),
                        _buildRequirement('1 caractere especial (!@#\$%&*)', _newPasswordController.text.contains(RegExp(r'[!@#$%&*]'))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Campo Confirmar Senha
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    enabled: !_isLoading,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Confirmar Nova Senha',
                      hintText: 'Digite novamente',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirme a senha';
                      }
                      if (value != _newPasswordController.text) {
                        return 'As senhas não coincidem';
                      }
                      return null;
                    },
                  ),

                  // Aviso de segurança LGPD
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.security, size: 20, color: Colors.grey[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sua senha é criptografada e tratada conforme a LGPD. Nunca compartilhe sua senha.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botão de redefinir
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleResetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Redefinir Senha',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],

                // Botão para voltar ao login (só mostra após reset)
                if (_passwordReset) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Voltar para Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                // Mensagem de erro
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool satisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            satisfied ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: satisfied ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: satisfied ? Colors.green[700] : Colors.grey[600],
              decoration: satisfied ? null : TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  /// Redefine a senha após validação do token
  Future<void> _handleResetPassword() async {
    // Valida formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validação adicional de força da senha
    final validation = PasswordValidator.validatePassword(newPassword);
    if (!validation.isValid) {
      setState(() {
        _errorMessage = validation.message ?? 'A senha não atende aos requisitos mínimos de segurança.';
      });
      return;
    }

    // Verifica se as senhas coincidem
    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'As senhas não coincidem';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Valida o token antes de redefinir
      final tokenInfo = await _tokenService.getToken(widget.token);
      
      if (tokenInfo == null) {
        throw Exception('Token inválido ou expirado. Por favor, solicite um novo código.');
      }
      
      if (tokenInfo.email != widget.email) {
        throw Exception('Token não corresponde ao email informado.');
      }
      
      if (tokenInfo.isExpired) {
        throw Exception('Token expirado. Por favor, solicite um novo código.');
      }

      // 2. Tenta redefinir a senha
      try {
        await _authService.resetPasswordWithToken(
          widget.email,
          widget.token,
          newPassword,
        );
        
        // Se chegou aqui, o reset foi direto (futuro com Cloud Functions)
        await _invalidateToken();
        
        if (mounted) {
          setState(() {
            _passwordReset = true;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Senha redefinida com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Aguarda um pouco e volta para login
          await Future.delayed(const Duration(seconds: 2));
          
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          }
        }
      } catch (e) {
        // Se a Cloud Function não está implementada, mostra instruções
        if (e.toString().contains('Cloud Function não encontrada') || 
            e.toString().contains('NOT_FOUND')) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF2196F3)),
                    SizedBox(width: 8),
                    Expanded(child: Text('Configuração Necessária')),
                  ],
                ),
                content: const SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Para reset direto de senha, você precisa fazer deploy da Cloud Function.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Siga o guia: GUIA_DEPLOY_CLOUD_FUNCTIONS.md\n\n'
                        'Após o deploy, a senha será atualizada automaticamente após validar o código.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendi'),
                  ),
                ],
              ),
            );
          }
          return;
        }
        rethrow;
      }
    } catch (e) {
      // Tratamento de erros específicos
      String errorMessage = 'Erro ao redefinir senha';
      
      if (e.toString().contains('Token inválido') || e.toString().contains('Token expirado')) {
        errorMessage = 'Token inválido ou expirado. Por favor, solicite um novo código.';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'A senha deve atender aos requisitos mínimos de segurança.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Erro ao conectar ao servidor. Verifique sua conexão e tente novamente.';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
      } else {
        errorMessage = 'Erro ao redefinir senha: ${e.toString()}';
      }
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
          _isLoading = false;
        });
      }
    }
  }

  /// Invalida o token após uso bem-sucedido
  Future<void> _invalidateToken() async {
    try {
      // Garante que o token está marcado como usado
      final tokenInfo = await _tokenService.getToken(widget.token);
      if (tokenInfo != null && !tokenInfo.isUsed) {
        // Marca como usado através do FirestoreService
        await _firestoreService.validateAndUseToken(widget.token, widget.email);
      }
    } catch (e) {
      // Log silencioso - não bloqueia o fluxo se falhar
      if (mounted) {
        debugPrint('Aviso: Não foi possível invalidar token: $e');
      }
    }
  }
}
