import 'package:flutter/material.dart';
import 'package:app_carona_novo/utils/colors.dart';
import 'package:app_carona_novo/utils/styles.dart';

class MessageScreen extends StatelessWidget {
  const MessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryWhite),
          onPressed: () {
            // Implementar navegação de volta
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Mensagens',
          style: AppTextStyles.appBarTitle,
        ),
      ),
      backgroundColor: AppColors.darkBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Placeholder para a imagem
              Image.asset(
                'assets/images/icon_transp.png', // Substitua pelo caminho da sua imagem
                height: 200,
              ),
              const SizedBox(height: 40),
              const Text(
                'Está tudo atualizado!',
                textAlign: TextAlign.center,
                style: AppTextStyles.messageTitle,
              ),
              const SizedBox(height: 10),
              const Text(
                'Nenhuma nova mensagem disponível no momento, volte em breve para descobrir novas ofertas',
                textAlign: TextAlign.center,
                style: AppTextStyles.messageBody,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

