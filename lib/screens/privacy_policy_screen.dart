import 'package:flutter/material.dart';

/// Tela de Política de Privacidade
/// 
/// Exibe a política de privacidade completa em conformidade com a LGPD
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidade'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            const Text(
              'Política de Privacidade',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Data de atualização
            Text(
              'Última atualização: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Seção 1: Introdução
            _buildSection(
              title: '1. Introdução',
              content: '''
A Carona Universitária UDF ("nós", "nosso", "aplicativo") respeita a sua privacidade e está comprometida em proteger seus dados pessoais. Esta Política de Privacidade explica como coletamos, usamos, armazenamos e protegemos suas informações pessoais em conformidade com a Lei Geral de Proteção de Dados (LGPD - Lei nº 13.709/2018).

Ao usar nosso aplicativo, você concorda com a coleta e uso de informações conforme descrito nesta política.
              ''',
            ),

            // Seção 2: Dados Coletados
            _buildSection(
              title: '2. Dados Coletados',
              content: '''
Coletamos os seguintes tipos de dados pessoais:

**2.1 Dados de Cadastro:**
- Nome completo
- Endereço de e-mail acadêmico (@cs.udf.edu.br)
- Senha (criptografada)

**2.2 Dados de Perfil:**
- Foto de perfil (opcional)
- Informações sobre veículo (se motorista)

**2.3 Dados de Localização:**
- Localização atual (GPS)
- Endereços de origem e destino
- Histórico de rotas

**2.4 Dados de Uso:**
- Histórico de caronas
- Avaliações e comentários
- Mensagens de chat

**2.5 Dados Técnicos:**
- Endereço IP
- Tipo de dispositivo
- Sistema operacional
- Logs de acesso
              ''',
            ),

            // Seção 3: Finalidade do Tratamento
            _buildSection(
              title: '3. Finalidade do Tratamento',
              content: '''
Utilizamos seus dados pessoais para:

- Fornecer e melhorar nossos serviços de carona solidária
- Autenticar e identificar usuários
- Facilitar a comunicação entre motoristas e passageiros
- Processar solicitações de carona
- Enviar notificações importantes
- Garantir a segurança e prevenir fraudes
- Cumprir obrigações legais
- Gerar relatórios e estatísticas (dados anonimizados)
              ''',
            ),

            // Seção 4: Base Legal
            _buildSection(
              title: '4. Base Legal',
              content: '''
O tratamento de seus dados pessoais é baseado em:

- **Consentimento:** Você fornece consentimento explícito ao usar o aplicativo
- **Execução de contrato:** Necessário para fornecer os serviços de carona
- **Legítimo interesse:** Para garantir segurança e prevenir fraudes
- **Cumprimento de obrigação legal:** Conforme exigido pela LGPD
              ''',
            ),

            // Seção 5: Compartilhamento de Dados
            _buildSection(
              title: '5. Compartilhamento de Dados',
              content: '''
Nós NÃO vendemos, alugamos ou compartilhamos seus dados pessoais com terceiros, exceto:

- **Com outros usuários do aplicativo:** Apenas informações necessárias para a carona (nome, foto, avaliações)
- **Com provedores de serviços:** Firebase (Google), Google Maps, para operação do aplicativo
- **Por exigência legal:** Quando exigido por lei ou ordem judicial

Todos os parceiros são obrigados a manter a confidencialidade dos dados.
              ''',
            ),

            // Seção 6: Segurança dos Dados
            _buildSection(
              title: '6. Segurança dos Dados',
              content: '''
Implementamos medidas técnicas e organizacionais para proteger seus dados:

- Criptografia de senhas e dados sensíveis
- Autenticação de dois fatores (quando disponível)
- Acesso restrito apenas a pessoal autorizado
- Monitoramento de segurança contínuo
- Backup regular dos dados
- Conformidade com padrões de segurança do Firebase

Apesar de nossos esforços, nenhum método de transmissão ou armazenamento é 100% seguro.
              ''',
            ),

            // Seção 7: Retenção de Dados
            _buildSection(
              title: '7. Retenção de Dados',
              content: '''
Mantemos seus dados pessoais apenas pelo tempo necessário:

- **Dados ativos:** Enquanto sua conta estiver ativa
- **Dados após exclusão:** Após solicitação de exclusão, dados são removidos em até 30 dias
- **Dados para fins legais:** Podem ser mantidos conforme exigido por lei
- **Dados anonimizados:** Podem ser mantidos indefinidamente para estatísticas

Você pode solicitar a exclusão de seus dados a qualquer momento.
              ''',
            ),

            // Seção 8: Seus Direitos (LGPD)
            _buildSection(
              title: '8. Seus Direitos conforme a LGPD',
              content: '''
Você tem os seguintes direitos:

**8.1 Direito de Acesso:** Obter confirmação e acesso aos seus dados
**8.2 Direito de Correção:** Solicitar correção de dados incompletos ou desatualizados
**8.3 Direito de Anonimização:** Solicitar anonimização de dados
**8.4 Direito de Portabilidade:** Receber seus dados em formato estruturado
**8.5 Direito de Exclusão:** Solicitar exclusão de dados desnecessários
**8.6 Direito de Revogação:** Revogar consentimento a qualquer momento
**8.7 Direito de Oposição:** Opor-se ao tratamento de dados
**8.8 Direito de Revisão:** Revisar decisões automatizadas

Para exercer seus direitos, entre em contato conosco através do aplicativo ou e-mail.
              ''',
            ),

            // Seção 9: Cookies e Tecnologias Similares
            _buildSection(
              title: '9. Cookies e Armazenamento Local',
              content: '''
O aplicativo utiliza armazenamento local para:

- Manter sessão do usuário
- Armazenar preferências
- Melhorar performance

Você pode limpar os dados do aplicativo a qualquer momento nas configurações do dispositivo.
              ''',
            ),

            // Seção 10: Alterações na Política
            _buildSection(
              title: '10. Alterações nesta Política',
              content: '''
Podemos atualizar esta Política de Privacidade periodicamente. 

Quando houver alterações significativas, notificaremos você através do aplicativo ou por e-mail.

A versão atual é sempre exibida no topo desta página.

É importante revisar esta política regularmente para se manter informado sobre como protegemos seus dados.
              ''',
            ),

            // Seção 11: Contato
            _buildSection(
              title: '11. Contato e Dúvidas',
              content: '''
Se você tiver dúvidas sobre esta Política de Privacidade ou sobre o tratamento de seus dados pessoais, entre em contato:

**E-mail:** suporte@carona-universitaria.udf.edu.br
**Aplicativo:** Através da seção de Suporte no perfil

Responderemos sua solicitação em até 15 (quinze) dias úteis, conforme exigido pela LGPD.
              ''',
            ),

            const SizedBox(height: 32),

            // Botão de Aceitar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true); // Retorna true indicando aceite
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Li e Aceito a Política de Privacidade',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Botão de Recusar
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false); // Retorna false indicando recusa
                },
                child: const Text(
                  'Não Aceito',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

