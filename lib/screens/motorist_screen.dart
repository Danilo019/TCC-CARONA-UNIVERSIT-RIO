import 'package:flutter/material.dart';
import '../screens/offer_ride_screen.dart';

/// Tela dedicada para motoristas
/// 
/// Exibe funcionalidades específicas para motoristas:
/// - Oferecer novas caronas
/// - Gerenciar caronas existentes
/// 
/// Esta tela encapsula a funcionalidade de OfferRideScreen
/// mantendo a mesma estrutura e funcionalidades.
class MotoristScreen extends StatelessWidget {
  const MotoristScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Retorna a tela de oferecer carona diretamente
    // que já possui toda a funcionalidade necessária
    return const OfferRideScreen();
  }
}

