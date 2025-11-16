import 'package:flutter/material.dart';
import '../screens/search_ride_screen.dart';

/// Tela dedicada para passageiros
/// 
/// Exibe funcionalidades específicas para passageiros:
/// - Procurar caronas disponíveis
/// - Solicitar caronas
/// - Visualizar caronas em mapa ou lista
/// 
/// Esta tela encapsula a funcionalidade de SearchRideScreen
/// mantendo a mesma estrutura e funcionalidades.
class PassengerScreen extends StatelessWidget {
  const PassengerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Retorna a tela de procurar/solicitar carona diretamente
    // que já possui toda a funcionalidade necessária
    return const SearchRideScreen();
  }
}

