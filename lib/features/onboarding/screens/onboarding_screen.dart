import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/onboarding_page_model.dart';
import '../widgets/onboarding_page_content.dart';
import '../widgets/page_indicator.dart';

/// Tela principal do fluxo de Onboarding
///
/// Gerencia a navegação entre as páginas de introdução do aplicativo,
/// permitindo ao usuário avançar, retroceder ou pular o onboarding.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// Controlador para gerenciar a navegação do PageView
  late PageController _pageController;

  /// Índice da página atual
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Navega para a próxima página ou finaliza o onboarding
  void _onNextPressed() {
    if (_currentPage < OnboardingData.pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  /// Pula o onboarding e vai direto para a tela principal
  void _onSkipPressed() {
    _finishOnboarding();
  }

  /// Finaliza o onboarding e navega para a tela de solicitação de localização
  void _finishOnboarding() {
    // Navega para a tela de Location Request
    Navigator.of(context).pushReplacementNamed('/location-request');
  }

  /// Callback chamado quando o usuário desliza entre páginas
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // PageView com as páginas de onboarding
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: OnboardingData.pageCount,
              itemBuilder: (context, index) {
                return OnboardingPageContent(
                  page: OnboardingData.getPage(index),
                  currentPage: _currentPage,
                  pageCount: OnboardingData.pageCount,
                );
              },
            ),

            // Camada de controles (botões e indicador)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildControlsLayer(),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói a camada de controles (indicador de página e botões)
  Widget _buildControlsLayer() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.1)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 360;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicador de página
                PageIndicator(
                  pageCount: OnboardingData.pageCount,
                  currentPage: _currentPage,
                ),

                SizedBox(height: isSmallScreen ? 16 : 24),

                // Botões de navegação
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botão "Pular"
                    _buildSkipButton(),

                    // Botão "Avançar" ou "Começar"
                    _buildNextButton(),
                  ],
                ),

                SizedBox(height: isSmallScreen ? 8 : 12),

                // Link para Política de Privacidade
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/privacy-policy');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textOnDarkSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Política de Privacidade',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Constrói o botão "Pular"
  Widget _buildSkipButton() {
    // Esconde o botão "Pular" na última página
    if (_currentPage == OnboardingData.pageCount - 1) {
      return const SizedBox(width: 80); // Espaço vazio para manter o layout
    }

    return TextButton(
      onPressed: _onSkipPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textOnDarkSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: const Text(
        'Pular',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  /// Constrói o botão "Avançar" ou "Começar"
  Widget _buildNextButton() {
    final isLastPage = _currentPage == OnboardingData.pageCount - 1;
    final buttonText = isLastPage ? 'Começar' : 'Avançar';

    return ElevatedButton(
      onPressed: _onNextPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentOrange,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 4,
        shadowColor: AppColors.accentOrange.withValues(alpha: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            buttonText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Icon(isLastPage ? Icons.check : Icons.arrow_forward, size: 20),
        ],
      ),
    );
  }
}

/// Variante da tela de onboarding com animações mais elaboradas
class AnimatedOnboardingScreen extends StatefulWidget {
  const AnimatedOnboardingScreen({super.key});

  @override
  State<AnimatedOnboardingScreen> createState() =>
      _AnimatedOnboardingScreenState();
}

class _AnimatedOnboardingScreenState extends State<AnimatedOnboardingScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _animationController.reset();
    _animationController.forward();
  }

  void _finishOnboarding() {
    Navigator.of(context).pushReplacementNamed('/location-request');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: OnboardingData.pageCount,
              itemBuilder: (context, index) {
                return FadeTransition(
                  opacity: _animationController,
                  child: OnboardingPageContent(
                    page: OnboardingData.getPage(index),
                    currentPage: _currentPage,
                    pageCount: OnboardingData.pageCount,
                  ),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Column(
                children: [
                  PageIndicator(
                    pageCount: OnboardingData.pageCount,
                    currentPage: _currentPage,
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentPage < OnboardingData.pageCount - 1)
                          TextButton(
                            onPressed: _finishOnboarding,
                            child: const Text(
                              'Pular',
                              style: TextStyle(color: AppColors.white),
                            ),
                          )
                        else
                          const SizedBox(width: 80),
                        ElevatedButton(
                          onPressed: () {
                            if (_currentPage < OnboardingData.pageCount - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _finishOnboarding();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentOrange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            _currentPage == OnboardingData.pageCount - 1
                                ? 'Começar'
                                : 'Avançar',
                            style: const TextStyle(color: AppColors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
