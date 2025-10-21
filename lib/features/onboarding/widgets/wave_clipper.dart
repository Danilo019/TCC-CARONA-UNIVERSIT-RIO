import 'package:flutter/material.dart';

/// CustomClipper que cria um efeito de onda na parte superior de um container
/// 
/// Utilizado no painel inferior das telas de onboarding para criar
/// uma transição visual suave entre a ilustração e o conteúdo informativo.
class WaveClipper extends CustomClipper<Path> {
  /// Amplitude da onda (altura do pico)
  final double waveAmplitude;

  /// Frequência da onda (número de ondulações)
  final double waveFrequency;

  WaveClipper({
    this.waveAmplitude = 30.0,
    this.waveFrequency = 1.5,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    
    // Começa no canto superior esquerdo, mas deslocado pela amplitude
    path.lineTo(0, waveAmplitude);

    // Cria a curva de onda usando quadraticBezierTo
    // Primeira curva (subida)
    path.quadraticBezierTo(
      size.width * 0.25,
      0,
      size.width * 0.5,
      waveAmplitude * 0.5,
    );

    // Segunda curva (descida e subida)
    path.quadraticBezierTo(
      size.width * 0.75,
      waveAmplitude * waveFrequency,
      size.width,
      waveAmplitude * 0.3,
    );

    // Completa o retângulo
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return oldClipper is WaveClipper &&
        (oldClipper.waveAmplitude != waveAmplitude ||
            oldClipper.waveFrequency != waveFrequency);
  }
}

/// Variante alternativa com onda mais suave e simétrica
class SmoothWaveClipper extends CustomClipper<Path> {
  final double waveHeight;

  SmoothWaveClipper({this.waveHeight = 40.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    
    path.lineTo(0, waveHeight);

    // Curva suave usando cubic bezier para maior controle
    final firstControlPoint = Offset(size.width * 0.25, 0);
    final firstEndPoint = Offset(size.width * 0.5, waveHeight * 0.5);
    
    final secondControlPoint = Offset(size.width * 0.75, waveHeight);
    final secondEndPoint = Offset(size.width, waveHeight * 0.2);

    path.cubicTo(
      firstControlPoint.dx, firstControlPoint.dy,
      firstEndPoint.dx, firstEndPoint.dy,
      size.width * 0.5, firstEndPoint.dy,
    );

    path.cubicTo(
      secondControlPoint.dx, secondControlPoint.dy,
      secondEndPoint.dx, secondEndPoint.dy,
      size.width, secondEndPoint.dy,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return oldClipper is SmoothWaveClipper &&
        oldClipper.waveHeight != waveHeight;
  }
}

