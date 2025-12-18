import 'package:flutter/material.dart';
import '../services/email_token_service.dart';
import 'email_token_verification_screen.dart';

/// Exemplo de como integrar o sistema de tokens de e-mail
/// no fluxo de registro ou reset de senha
class EmailTokenIntegrationExample extends StatefulWidget {
  const EmailTokenIntegrationExample({Key? key}) : super(key: key);

  @override
  State<EmailTokenIntegrationExample> createState() =>
      _EmailTokenIntegrationExampleState();
}

class _EmailTokenIntegrationExampleState
    extends State<EmailTokenIntegrationExample> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Exemplo 1: Fluxo de Ativação de Conta
  Future<void> _handleAccountActivation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      // 1. Cria usuário no Firebase (se ainda não existe)
      // ... seu código de criação de usuário ...

      // 2. Navega para tela de verificação de e-mail
      final verified = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmailTokenVerificationScreen(
            email: email,
            purpose: 'activation',
          ),
        ),
      );

      if (verified == true) {
        // 3. E-mail verificado com sucesso!
        _showSuccessDialog('Conta ativada com sucesso!');
      }
    } catch (e) {
      _showErrorDialog('Erro ao ativar conta: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Exemplo 2: Fluxo de Reset de Senha
  Future<void> _handlePasswordReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      // 1. Navega para tela de verificação com token de reset
      final verified = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmailTokenVerificationScreen(
            email: email,
            purpose: 'password_reset',
          ),
        ),
      );

      if (verified == true) {
        // 2. Token validado, agora pede nova senha
        final newPassword = await _showNewPasswordDialog();

        if (newPassword != null && newPassword.isNotEmpty) {
          // 3. Redefine a senha
          await _resetPasswordWithToken(email, newPassword);
        }
      }
    } catch (e) {
      _showErrorDialog('Erro ao redefinir senha: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Exemplo 3: Enviar token sem navegar para outra tela
  Future<void> _sendTokenInline() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      // Envia token
      final result = await EmailTokenService.sendActivationToken(email);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código enviado para $email'),
            backgroundColor: Colors.green,
          ),
        );

        // Aqui você pode mostrar um dialog ou campo para digitar o token
        final token = await _showTokenInputDialog();

        if (token != null) {
          // Valida o token
          final validationResult = await EmailTokenService.validateToken(
            email: email,
            token: token,
            markAsUsed: true,
          );

          if (validationResult['isValid'] == true) {
            _showSuccessDialog('E-mail verificado com sucesso!');
          } else {
            _showErrorDialog(
                validationResult['message'] ?? 'Token inválido');
          }
        }
      } else {
        _showErrorDialog(result['message'] ?? 'Erro ao enviar código');
      }
    } catch (e) {
      _showErrorDialog('Erro: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Redefine senha usando token
  Future<void> _resetPasswordWithToken(
      String email, String newPassword) async {
    // Aqui você precisa do token que foi validado anteriormente
    // Você pode armazená-lo em um campo ou state
    
    // Por exemplo, se você tiver o token:
    // final result = await EmailTokenService.resetPassword(
    //   email: email,
    //   token: _validatedToken,
    //   newPassword: newPassword,
    // );
    
    _showSuccessDialog('Senha redefinida com sucesso!');
  }

  /// Mostra dialog para digitar token
  Future<String?> _showTokenInputDialog() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Digite o código'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Código de 6 dígitos',
            hintText: '000000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Validar'),
          ),
        ],
      ),
    );
  }

  /// Mostra dialog para digitar nova senha
  Future<String?> _showNewPasswordDialog() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Digite sua nova senha (mínimo 8 caracteres):',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nova senha',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length >= 8) {
                Navigator.pop(context, controller.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Senha deve ter no mínimo 8 caracteres'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Sucesso'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Erro'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema de Tokens de E-mail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Exemplos de Integração',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Campo de e-mail
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  hintText: 'seu.email@cs.udf.edu.br',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite seu e-mail';
                  }
                  if (!value.endsWith('@cs.udf.edu.br')) {
                    return 'Use e-mail institucional @cs.udf.edu.br';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Exemplo 1: Ativação de Conta
              const Text(
                '1. Ativação de Conta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Envia token e abre tela de verificação',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleAccountActivation,
                icon: const Icon(Icons.verified_user),
                label: const Text('Ativar Conta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),

              // Exemplo 2: Reset de Senha
              const Text(
                '2. Reset de Senha',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Envia token e permite redefinir senha',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handlePasswordReset,
                icon: const Icon(Icons.lock_reset),
                label: const Text('Redefinir Senha'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),

              // Exemplo 3: Token Inline
              const Text(
                '3. Verificação Inline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Envia token e valida sem sair da tela',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendTokenInline,
                icon: const Icon(Icons.send),
                label: const Text('Enviar Token'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 32),

              // Loading indicator
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(),
                ),

              // Informações adicionais
              const Divider(height: 48),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Informações Importantes',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('• Apenas e-mails @cs.udf.edu.br'),
                      const Text('• Tokens válidos por 30 minutos'),
                      const Text('• Códigos de 6 dígitos'),
                      const Text('• Uso único por token'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
