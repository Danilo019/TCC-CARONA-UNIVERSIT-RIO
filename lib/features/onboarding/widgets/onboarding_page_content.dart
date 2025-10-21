import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/onboarding_page_model.dart';
import 'wave_clipper.dart';

/// Widget que renderiza o conteúdo de uma página individual do onboarding
/// 
/// Composto por:
/// - Seção superior: Ilustração
/// - Seção inferior: Painel com gradiente azul oceano, efeito de onda, título e descrição
class OnboardingPageContent extends StatelessWidget {
  /// Modelo de dados da página
  final OnboardingPageModel page;

  /// Altura proporcional da seção de ilustração (0.0 a 1.0)
  final double illustrationHeightRatio;

  const OnboardingPageContent({
    super.key,
    required this.page,
    this.illustrationHeightRatio = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final illustrationHeight = screenHeight * illustrationHeightRatio;

    return Column(
      children: [
        // Seção Superior: Ilustração
        _buildIllustrationSection(illustrationHeight),
        
        // Seção Inferior: Painel Informativo com Gradiente
        Expanded(
          child: _buildInfoPanel(context),
        ),
      ],
    );
  }

  /// Constrói a seção de ilustração
  Widget _buildIllustrationSection(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppColors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Image.asset(
            page.imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback caso a imagem não seja encontrada
              return Icon(
                Icons.directions_car,
                size: 120,
                color: AppColors.oceanMediumBlue,
              );
            },
          ),
        ),
      ),
    );
  }

  /// Constrói o painel informativo com gradiente e efeito de onda
  Widget _buildInfoPanel(BuildContext context) {
    return ClipPath(
      clipper: WaveClipper(
        waveAmplitude: 35.0,
        waveFrequency: 1.5,
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.onboardingGradient,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Título
              Text(
                page.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textOnDark,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Descrição
              Text(
                page.description,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: AppColors.textOnDarkSecondary,
                  letterSpacing: 0.2,
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

/// Variante com layout alternativo (ilustração menor, mais espaço para texto)
class CompactOnboardingPageContent extends StatelessWidget {
  final OnboardingPageModel page;

  const CompactOnboardingPageContent({
    super.key,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: WaveClipper(waveAmplitude: 30.0),
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.onboardingGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Ilustração compacta
                SizedBox(
                  height: 200,
                  child: Image.asset(
                    page.imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.directions_car,
                        size: 80,
                        color: AppColors.white,
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Conteúdo textual
                Column(
                  children: [
                    Text(
                      page.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textOnDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      page.description,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.textOnDarkSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

