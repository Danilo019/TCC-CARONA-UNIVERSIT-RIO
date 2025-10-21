import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
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
            color: const Color(0x800E4A8C), // Overlay azul escuro semi-transparente
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ícone do globo
                      const Icon(
                        Icons.public_outlined,
                        size: 60,
                        color: Colors.white,
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Título principal
                      const Text(
                        'Bem-vindo!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Subtítulo
                      const Text(
                        'Acesse com sua conta acadêmica para começar.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 60),
                      
                      // Botão principal de login
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
                            onTap: _isLoading ? null : _handleMicrosoftLogin,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isLoading)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.school_outlined,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      _isLoading ? 'Entrando...' : 'Entrar com E-mail Acadêmico',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Realiza login com Microsoft usando autenticação real
  Future<void> _handleMicrosoftLogin() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Realiza login com Microsoft (apenas emails @cs.udf.edu.br)
      final user = await _authService.signInWithUDFMicrosoft();

      if (user != null && mounted) {
        // Login bem-sucedido
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bem-vindo, ${user.displayName ?? user.email}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Aguarda um pouco para mostrar a mensagem
        await Future.delayed(const Duration(milliseconds: 500));

        // Navega para a tela principal
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      // Tratamento de erros específicos
      String errorMessage = 'Erro ao fazer login';
      
      if (e.toString().contains('UDF')) {
        errorMessage = 'Apenas emails da UDF (@cs.udf.edu.br) são permitidos';
      } else if (e.toString().contains('cancelado')) {
        errorMessage = 'Login cancelado';
      } else {
        errorMessage = 'Erro no login: ${e.toString()}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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
