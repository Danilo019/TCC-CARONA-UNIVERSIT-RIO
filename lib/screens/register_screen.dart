import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:email_validator/email_validator.dart';
import '../services/token_service.dart';
import '../services/auth_service.dart';
import '../services/consent_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _tokenController = TextEditingController();
  final _tokenService = TokenService();
  final _authService = AuthService();
  final _consentService = ConsentService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isEmailSent = false;
  bool _acceptedPrivacyPolicy = false; // Checkbox de aceite da política

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background_android.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            color: const Color(0x800E4A8C),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Ícone de cadastro
                        const Icon(
                          Icons.person_add_outlined,
                          size: 60,
                          color: Colors.white,
                        ),

                        const SizedBox(height: 40),

                        // Título principal
                        const Text(
                          'Criar Conta',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Subtítulo
                        Text(
                          _isEmailSent
                              ? 'Verifique seu e-mail acadêmico e digite o código de ativação'
                              : 'Preencha os dados para criar sua conta acadêmica',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 40),

                        if (!_isEmailSent) ...[
                          // Formulário de cadastro
                          _buildRegisterForm(),
                        ] else ...[
                          // Formulário de verificação
                          _buildVerificationForm(),
                        ],

                        const SizedBox(height: 40),

                        // Link para voltar ao login
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Já tem uma conta? Faça login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        // Campo de email
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'E-mail Acadêmico',
              hintText: 'seu-usuario@cs.udf.edu.br',
              labelStyle: TextStyle(color: Colors.white70),
              hintStyle: TextStyle(color: Colors.white54),
              prefixIcon: Icon(Icons.email_outlined, color: Colors.white70),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Digite seu e-mail acadêmico';
              }

              if (!EmailValidator.validate(value)) {
                return 'Digite um e-mail válido';
              }

              if (!value.endsWith('@cs.udf.edu.br')) {
                return 'Apenas emails @cs.udf.edu.br são permitidos';
              }

              return null;
            },
          ),
        ),

        const SizedBox(height: 16),

        // Campo de senha
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Senha',
              hintText: 'Digite sua senha',
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Digite sua senha';
              }

              if (value.length < 6) {
                return 'A senha deve ter pelo menos 6 caracteres';
              }

              return null;
            },
          ),
        ),

        const SizedBox(height: 16),

        // Campo de confirmação de senha
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Confirmar Senha',
              hintText: 'Digite sua senha novamente',
              labelStyle: const TextStyle(color: Colors.white70),
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirme sua senha';
              }

              if (value != _passwordController.text) {
                return 'As senhas não coincidem';
              }

              return null;
            },
          ),
        ),

        const SizedBox(height: 16),

        // Informação sobre o processo
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Após o cadastro, você receberá um código de ativação no seu e-mail acadêmico',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Checkbox de aceite da Política de Privacidade
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptedPrivacyPolicy,
                onChanged: (value) {
                  setState(() {
                    _acceptedPrivacyPolicy = value ?? false;
                  });
                },
                activeColor: Colors.white,
                checkColor: const Color(0xFF1A365D),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    // Abre a tela de política e aguarda resultado
                    final accepted =
                        await Navigator.of(context).pushNamed('/privacy-policy')
                            as bool?;
                    if (accepted == true && mounted) {
                      setState(() {
                        _acceptedPrivacyPolicy = true;
                      });
                    }
                  },
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: 'Eu aceito a '),
                        TextSpan(
                          text: 'Política de Privacidade',
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' e concordo com o tratamento de meus dados pessoais conforme a LGPD.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Botão de cadastro
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1A365D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isLoading ? null : _handleRegister,
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Criar Conta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationForm() {
    return Column(
      children: [
        // Informação sobre o email
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined, color: Colors.blue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Código enviado para: ${_emailController.text}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Campo de token
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: TextFormField(
            controller: _tokenController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'Código de Verificação',
              hintText: '123456',
              labelStyle: TextStyle(color: Colors.white70),
              hintStyle: TextStyle(color: Colors.white54),
              prefixIcon: Icon(Icons.security_outlined, color: Colors.white70),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Digite o código de verificação';
              }

              if (value.length != 6) {
                return 'O código deve ter 6 dígitos';
              }

              if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                return 'Digite apenas números';
              }

              return null;
            },
          ),
        ),

        const SizedBox(height: 24),

        // Checkbox de aceite da Política de Privacidade (também na etapa de verificação)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptedPrivacyPolicy,
                onChanged: (value) {
                  setState(() {
                    _acceptedPrivacyPolicy = value ?? false;
                  });
                },
                activeColor: Colors.white,
                checkColor: const Color(0xFF1A365D),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    // Abre a tela de política e aguarda resultado
                    final accepted =
                        await Navigator.of(context).pushNamed('/privacy-policy')
                            as bool?;
                    if (accepted == true && mounted) {
                      setState(() {
                        _acceptedPrivacyPolicy = true;
                      });
                    }
                  },
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: 'Eu aceito a '),
                        TextSpan(
                          text: 'Política de Privacidade',
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' e concordo com o tratamento de meus dados pessoais conforme a LGPD.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Botão de verificação
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1A365D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isLoading ? null : _handleVerification,
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Verificar Código',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Botão para reenviar código
        TextButton(
          onPressed: _isLoading ? null : _handleResendCode,
          child: Text(
            _isLoading ? 'Reenviando...' : 'Reenviar Código',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Valida aceite da política de privacidade
    if (!_acceptedPrivacyPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Você precisa aceitar a Política de Privacidade para continuar',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();

      // Cria o token de ativação
      final token = await _tokenService.createActivationToken(email);

      // Envia o email com o token
      final emailSent = await _tokenService.sendActivationEmail(
        email,
        token.token,
      );

      // Em desenvolvimento, permite avançar mesmo sem envio de email
      final canProceed = emailSent || kDebugMode;
      
      if (canProceed) {
        if (kDebugMode) {
          if (emailSent) {
            print('✓ Email enviado com sucesso, mudando para tela de verificação');
          } else {
            print('⚠ Email não enviado (modo debug), mas permitindo avançar');
            print('💡 Token gerado: ${token.token}');
          }
        }
        
        setState(() {
          _isEmailSent = true;
        });

        if (kDebugMode) {
          print('✓ Estado atualizado: _isEmailSent = $_isEmailSent');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                emailSent
                    ? 'Código enviado para $email'
                    : 'Código: ${token.token} (Email não configurado)',
              ),
              backgroundColor: emailSent ? Colors.green : Colors.orange,
              duration: Duration(seconds: emailSent ? 3 : 8),
            ),
          );
        }
      } else {
        throw Exception('Falha ao enviar email');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleVerification() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Valida aceite da política de privacidade também na etapa de verificação
    if (!_acceptedPrivacyPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Você precisa aceitar a Política de Privacidade para continuar',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = _tokenController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Valida o token
      final isValid = await _tokenService.validateToken(token, email);

      if (!isValid) {
        throw Exception('Código inválido ou expirado');
      }

      // Cria conta no Firebase Auth após validação do token
      final user = await _authService.createAccountAfterTokenValidation(
        email,
        password,
      );

      if (user != null) {
        await _tokenService.invalidateToken(token, email);

        // Salva consentimento da política de privacidade
        final consentSaved = await _consentService.savePrivacyPolicyConsent(
          userId: user.uid,
          email: email,
          accepted: true,
          version: ConsentService.currentPrivacyPolicyVersion,
        );

        if (kDebugMode) {
          if (consentSaved) {
            print(
              '✓ Consentimento da política de privacidade salvo com sucesso',
            );
          } else {
            print('✗ Erro ao salvar consentimento da política de privacidade');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conta criada com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Aguarda um pouco para mostrar a mensagem
          await Future.delayed(const Duration(milliseconds: 500));

          // Navega para a tela de login
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResendCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();

      // Cria um novo token
      final token = await _tokenService.createActivationToken(email);

      // Envia o email novamente
      final emailSent = await _tokenService.sendActivationEmail(
        email,
        token.token,
      );

      if (emailSent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Novo código enviado para $email'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Limpa o campo de token
        _tokenController.clear();
      } else {
        throw Exception('Falha ao reenviar código');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reenviar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
