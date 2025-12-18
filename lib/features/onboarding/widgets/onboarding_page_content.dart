import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/onboarding_page_model.dart';
import 'page_indicator.dart';
import 'wave_clipper.dart';

/// Widget que renderiza o conteúdo de uma página individual do onboarding
///
/// Composto por:
/// - Seção superior: Ilustração
/// - Seção inferior: Painel com gradiente azul oceano, efeito de onda, título e descrição
class OnboardingPageContent extends StatelessWidget {
  /// Modelo de dados da página
  final OnboardingPageModel page;

  /// Índice atual da página (para o indicador)
  final int? currentPage;

  /// Número total de páginas (para o indicador)
  final int? pageCount;

  /// Altura proporcional da seção de ilustração (0.0 a 1.0)
  final double illustrationHeightRatio;

  const OnboardingPageContent({
    super.key,
    required this.page,
    this.currentPage,
    this.pageCount,
    this.illustrationHeightRatio = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final illustrationHeight = screenHeight * illustrationHeightRatio;
        final panelHeight = screenHeight - illustrationHeight;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // Seção Superior: Ilustração
              _buildIllustrationSection(illustrationHeight),

              // Seção Inferior: Painel Informativo com Gradiente
              SizedBox(height: panelHeight, child: _buildInfoPanel(context)),
            ],
          ),
        );
      },
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
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height - 16),
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
      ),
    );
  }

  /// Constrói o painel informativo com gradiente e efeito de onda
  Widget _buildInfoPanel(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula tamanhos responsivos baseados na altura disponível
        final availableHeight = constraints.maxHeight;
        final titleFontSize = (availableHeight * 0.08).clamp(20.0, 28.0);
        final descriptionFontSize = (availableHeight * 0.045).clamp(14.0, 16.0);
        final topPadding = (availableHeight * 0.12).clamp(40.0, 60.0);

        return ClipPath(
          clipper: WaveClipper(waveAmplitude: 35.0, waveFrequency: 1.5),
          child: Container(
            width: double.infinity,
            height: availableHeight,
            decoration: const BoxDecoration(
              gradient: AppColors.onboardingGradient,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, topPadding, 24, 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Título
                  Text(
                    page.title,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textOnDark,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: availableHeight * 0.04),

                  // Descrição
                  Text(
                    page.description,
                    style: TextStyle(
                      fontSize: descriptionFontSize,
                      height: 1.6,
                      color: AppColors.textOnDarkSecondary,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Variante com layout alternativo (ilustração menor, mais espaço para texto)
class CompactOnboardingPageContent extends StatelessWidget {
  final OnboardingPageModel page;

  const CompactOnboardingPageContent({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: WaveClipper(waveAmplitude: 30.0),
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.onboardingGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight;
              final imageHeight = (availableHeight * 0.3).clamp(120.0, 200.0);
              final titleFontSize = (availableHeight * 0.036).clamp(20.0, 26.0);
              final descriptionFontSize = (availableHeight * 0.021).clamp(
                13.0,
                15.0,
              );

              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: availableHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 40,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Ilustração compacta
                        SizedBox(
                          height: imageHeight,
                          child: Image.asset(
                            page.imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.directions_car,
                                size: imageHeight * 0.4,
                                color: AppColors.white,
                              );
                            },
                          ),
                        ),

                        SizedBox(height: availableHeight * 0.04),

                        // Conteúdo textual
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              page.title,
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textOnDark,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: availableHeight * 0.025),
                            Text(
                              page.description,
                              style: TextStyle(
                                fontSize: descriptionFontSize,
                                height: 1.5,
                                color: AppColors.textOnDarkSecondary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
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
