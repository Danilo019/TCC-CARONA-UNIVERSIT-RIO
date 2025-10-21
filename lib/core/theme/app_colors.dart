import 'package:flutter/material.dart';

/// Constantes de cores do aplicativo Carona Uni
/// 
/// Define a paleta de cores global do aplicativo, incluindo
/// o gradiente azul oceano utilizado nas telas de onboarding.
class AppColors {
  AppColors._(); // Construtor privado para evitar instanciação

  // Cores principais do gradiente azul oceano
  static const Color oceanDarkBlue = Color(0xFF0D47A1); // Azul escuro profundo
  static const Color oceanMediumBlue = Color(0xFF1976D2); // Azul médio
  static const Color oceanLightBlue = Color(0xFF42A5F5); // Azul claro oceano
  static const Color oceanSkyBlue = Color(0xFF64B5F6); // Azul céu claro

  // Cores de texto sobre fundo azul
  static const Color textOnDark = Color(0xFFFFFFFF); // Branco para texto principal
  static const Color textOnDarkSecondary = Color(0xFFE3F2FD); // Branco azulado para texto secundário

  // Cores de destaque
  static const Color accentOrange = Color(0xFFFF6F00); // Laranja vibrante para indicadores ativos
  static const Color accentAmber = Color(0xFFFFB300); // Âmbar para botões de ação

  // Cores neutras
  static const Color white = Color(0xFFFFFFFF);
  static const Color whiteTransparent = Color(0x80FFFFFF); // Branco 50% transparente
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF9E9E9E);

  // Gradiente principal do onboarding
  static const LinearGradient onboardingGradient = LinearGradient(
    colors: [oceanDarkBlue, oceanMediumBlue, oceanLightBlue],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.5, 1.0],
  );

  // Gradiente alternativo (mais suave)
  static const LinearGradient onboardingSoftGradient = LinearGradient(
    colors: [oceanMediumBlue, oceanLightBlue, oceanSkyBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.6, 1.0],
  );
}

