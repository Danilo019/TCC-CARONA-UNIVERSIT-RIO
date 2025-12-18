import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/email_token_service.dart';

/// Tela para solicitar e validar token de e-mail
class EmailTokenVerificationScreen extends StatefulWidget {
  final String email;
  final String purpose; // 'activation' ou 'password_reset'

  const EmailTokenVerificationScreen({
    Key? key,
    required this.email,
    this.purpose = 'activation',
  }) : super(key: key);

  @override
  State<EmailTokenVerificationScreen> createState() =>
      _EmailTokenVerificationScreenState();
}

class _EmailTokenVerificationScreenState
    extends State<EmailTokenVerificationScreen> {
  final _tokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _tokenSent = false;
  String? _errorMessage;
  String? _successMessage;
  String? _debugToken; // Para desenvolvimento

  @override
  void initState() {
    super.initState();
    // Envia token automaticamente ao abrir a tela
    _sendToken();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  /// Envia token por e-mail
  Future<void> _sendToken() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      _debugToken = null;
    });

    try {
      final result = await EmailTokenService.sendTokenByEmail(
        email: widget.email,
        purpose: widget.purpose,
      );

      if (result['success'] == true) {
        setState(() {
          _tokenSent = true;
          _successMessage = 'Código enviado para ${widget.email}';
          // Em desenvolvimento, pode mostrar o token
          if (result['token'] != null) {
            _debugToken = result['token'];
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _successMessage!,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Erro ao enviar código';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage!),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Valida token digitado
  Future<void> _validateToken() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await EmailTokenService.validateToken(
        email: widget.email,
        token: _tokenController.text.trim(),
        markAsUsed: true,
      );

      if (result['success'] == true && result['isValid'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Código validado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );

          // Retorna sucesso
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Código inválido';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPurposeActivation = widget.purpose == 'activation';
    final title = isPurposeActivation
        ? 'Verificação de E-mail'
        : 'Redefinição de Senha';
    final description = isPurposeActivation
        ? 'Digite o código de 6 dígitos enviado para seu e-mail'
        : 'Digite o código de 6 dígitos enviado para seu e-mail para redefinir sua senha';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: isPurposeActivation ? Colors.green : Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ícone
              Icon(
                isPurposeActivation ? Icons.email : Icons.lock_reset,
                size: 80,
                color: isPurposeActivation ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 24),

              // Título
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Descrição
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Email
              Text(
                widget.email,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Token em DEBUG (apenas desenvolvimento)
              if (_debugToken != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '🔧 DEBUG - Token gerado:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _debugToken!,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_debugToken != null) const SizedBox(height: 24),

              // Campo de token
              TextFormField(
                controller: _tokenController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: 'Código de Verificação',
                  hintText: '000000',
                  prefixIcon: const Icon(Icons.pin),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite o código';
                  }
                  if (value.length != 6) {
                    return 'O código deve ter 6 dígitos';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              // Mensagem de erro
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 16),

              // Botão validar
              ElevatedButton(
                onPressed: _isLoading ? null : _validateToken,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isPurposeActivation ? Colors.green : Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Validar Código',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Botão reenviar
              TextButton(
                onPressed: _isLoading ? null : _sendToken,
                child: const Text('Reenviar código'),
              ),
              const SizedBox(height: 8),

              // Info
              Text(
                'O código expira em 30 minutos',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
