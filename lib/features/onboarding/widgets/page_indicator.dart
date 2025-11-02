import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Widget de indicador de página para o onboarding
/// 
/// Exibe pontos que representam cada página, destacando a página atual
/// com uma cor diferente e animação suave de transição.
class PageIndicator extends StatelessWidget {
  /// Número total de páginas
  final int pageCount;

  /// Índice da página atual (0-indexed)
  final int currentPage;

  /// Cor do indicador ativo
  final Color activeColor;

  /// Cor do indicador inativo
  final Color inactiveColor;

  /// Tamanho do ponto indicador
  final double dotSize;

  /// Espaçamento entre os pontos
  final double spacing;

  const PageIndicator({
    super.key,
    required this.pageCount,
    required this.currentPage,
    this.activeColor = AppColors.accentOrange,
    this.inactiveColor = AppColors.whiteTransparent,
    this.dotSize = 10.0,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => _buildDot(index),
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = index == currentPage;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(horizontal: spacing / 2),
      width: isActive ? dotSize * 2.5 : dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: isActive ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(dotSize / 2),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
    );
  }
}

/// Variante do indicador com estilo circular preenchido
class CircularPageIndicator extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final Color activeColor;
  final Color inactiveColor;
  final double size;

  const CircularPageIndicator({
    super.key,
    required this.pageCount,
    required this.currentPage,
    this.activeColor = AppColors.accentOrange,
    this.inactiveColor = AppColors.whiteTransparent,
    this.size = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? activeColor : inactiveColor,
            border: Border.all(
              color: isActive ? activeColor : AppColors.white.withValues(alpha: 0.5),
              width: isActive ? 2 : 1,
            ),
          ),
        );
      }),
    );
  }
}

