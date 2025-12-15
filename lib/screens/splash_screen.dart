import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;

/// Tela de Splash Screen inicial do aplicativo
///
/// Exibe o logo e nome do aplicativo por 3 segundos,
/// depois navega automaticamente baseado no estado de autenticação.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Configurar animações
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    // Iniciar animação
    _animationController.forward();

    // Verificar autenticação e navegar
    _checkAuthAndNavigate();
  }

  /// Verifica estado de autenticação e navega
  Future<void> _checkAuthAndNavigate() async {
    // Aguarda um pouco para a animação
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Verifica se há usuário autenticado
    final authProvider = Provider.of<app_auth.AuthProvider>(
      context,
      listen: false,
    );

    // Aguarda AuthProvider inicializar completamente
    while (authProvider.status == app_auth.AuthStatus.loading ||
        authProvider.status == app_auth.AuthStatus.initial) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    if (!mounted) return;

    // Verifica se Firebase Auth tem usuário
    final currentUser = authProvider.user;

    if (mounted) {
      // Se está autenticado, vai direto para Home
      if (currentUser != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // Se não está autenticado, vai para onboarding
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D47A1), // Azul escuro
              Color(0xFF1976D2), // Azul médio
              Color(0xFF42A5F5), // Azul claro
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calcula tamanhos responsivos baseados na altura disponível
              final availableHeight = constraints.maxHeight;
              final logoSize = (availableHeight * 0.18).clamp(100.0, 150.0);
              final titleFontSize = (availableHeight * 0.045).clamp(24.0, 42.0);
              final subtitleFontSize = (availableHeight * 0.018).clamp(
                12.0,
                16.0,
              );
              final iconSize = (logoSize * 0.53).clamp(50.0, 80.0);

              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: availableHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Espaçamento superior flexível
                        const Spacer(flex: 2),

                        // Logo animado
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              width: logoSize,
                              height: logoSize,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.directions_car,
                                size: iconSize,
                                color: const Color(0xFF1976D2),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: availableHeight * 0.04),

                        // Nome do aplicativo
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                Text(
                                  'Carona Universitária',
                                  style: TextStyle(
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: availableHeight * 0.015),
                                Text(
                                  'Conectando estudantes',
                                  style: TextStyle(
                                    fontSize: subtitleFontSize,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: availableHeight * 0.06),

                        // Indicador de carregamento
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 3,
                            ),
                          ),
                        ),

                        // Espaçamento inferior flexível
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Variante simples da Splash Screen sem animações
class SimpleSplashScreen extends StatefulWidget {
  const SimpleSplashScreen({super.key});

  @override
  State<SimpleSplashScreen> createState() => _SimpleSplashScreenState();
}

class _SimpleSplashScreenState extends State<SimpleSplashScreen> {
  @override
  void initState() {
    super.initState();

    // Navegar para onboarding após 3 segundos
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final iconSize = (constraints.maxHeight * 0.12).clamp(
                60.0,
                100.0,
              );
              final fontSize = (constraints.maxHeight * 0.042).clamp(
                24.0,
                36.0,
              );

              return Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: iconSize,
                          color: Colors.white,
                        ),
                        SizedBox(height: constraints.maxHeight * 0.025),
                        Text(
                          'Carona Universitária',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
