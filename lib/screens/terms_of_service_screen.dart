import 'package:flutter/material.dart';

/// Tela com os Termos de Uso e Condições do aplicativo.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termos de Uso')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Termos de Uso e Condições',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Última atualização: 01/10/2024',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: '1. Aceite dos Termos',
              content:
                  'Ao utilizar o aplicativo Carona Universitária, você concorda com estes Termos de Uso e se compromete a respeitar as regras descritas aqui.',
            ),
            _buildSection(
              context,
              title: '2. Cadastro e Conta',
              content:
                  'O uso do aplicativo é restrito a estudantes e colaboradores autorizados. Você é responsável por manter os dados do seu cadastro atualizados e por proteger suas credenciais de acesso.',
            ),
            _buildSection(
              context,
              title: '3. Uso do Aplicativo',
              content:
                  'É proibido utilizar o aplicativo para fins ilegais, enviar conteúdo ofensivo ou prejudicar a experiência de outros usuários. Podemos suspender ou encerrar contas que violem esta política.',
            ),
            _buildSection(
              context,
              title: '4. Responsabilidades dos Usuários',
              content:
                  'Motoristas e passageiros são responsáveis por garantir a segurança durante as caronas combinadas. O aplicativo atua apenas como facilitador de conexão entre as partes.',
            ),
            _buildSection(
              context,
              title: '5. Privacidade e Dados',
              content:
                  'O tratamento de dados pessoais segue a Política de Privacidade e a LGPD. Você pode acessar ou solicitar a exclusão dos seus dados em “Configuração e privacidade”.',
            ),
            _buildSection(
              context,
              title: '6. Limitação de Responsabilidade',
              content:
                  'Não nos responsabilizamos por danos ou prejuízos decorrentes de interações entre usuários fora da plataforma.',
            ),
            _buildSection(
              context,
              title: '7. Alterações destes Termos',
              content:
                  'Podemos atualizar estes Termos periodicamente. Notificaremos você sobre alterações significativas pelo aplicativo ou e-mail institucional.',
            ),
            const SizedBox(height: 24),
            Text(
              'Em caso de dúvidas, entre em contato através do suporte do aplicativo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
