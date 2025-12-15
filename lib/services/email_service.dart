import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Serviço para envio de emails
/// Suporta múltiplos provedores:
/// 1. EmailJS (gratuito até 200 emails/mês)
/// 2. Resend (gratuito até 3000 emails/mês)
/// 3. Mailgun (gratuito até 5000 emails/mês)
class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  // Configurações do provedor de email
  // Altere via variáveis de ambiente: EMAIL_PROVIDER = 'emailjs'|'resend'|'mailgun'
  // Em desenvolvimento, carregue variáveis com flutter_dotenv (já usado no projeto)
  final String _provider = dotenv.env['EMAIL_PROVIDER'] ?? 'emailjs';

  // ==============================CONFIGURAÇÕES POR PROVEDOR=====================
  // EmailJS
  final String emailjsServiceId = dotenv.env['EMAILJS_SERVICE_ID'] ?? '';
  final String emailjsTemplateId = dotenv.env['EMAILJS_TEMPLATE_ID'] ?? '';
  final String emailjsPublicKey = dotenv.env['EMAILJS_PUBLIC_KEY'] ?? '';
  // Private key (não comite chaves privadas no repositório!)
  final String emailjsPrivateKey = dotenv.env['EMAILJS_PRIVATE_KEY'] ?? '';

  // Resend
  final String? resendApiKey = dotenv.env['RESEND_API_KEY'];

  // Mailgun
  final String? mailgunApiKey = dotenv.env['MAILGUN_API_KEY'];
  final String? mailgunDomain = dotenv.env['MAILGUN_DOMAIN'];

  // Backend URL (Railway)
  String get backendUrl => 
      dotenv.env['BACKEND_URL'] ?? 
      'https://tcc-carona-universit-rio-production.up.railway.app';

  // HTTP Client (reutilizável)
  final http.Client httpClient = http.Client();

  // ===========================================================================
  // ENVIO DE EMAILS
  // ===========================================================================

  /// Envia email de ativação com token
  Future<bool> sendActivationEmail({
    required String toEmail,
    required String token,
    required String userName,
  }) async {
    try {
      final subject = 'Ativação da Conta - Carona Universitária';
      final htmlBody = _buildActivationEmailHtml(token, userName);
      final textBody = _buildActivationEmailText(token, userName);

      switch (_provider) {
        case 'emailjs':
          return await _sendViaEmailJS(
            toEmail: toEmail,
            subject: subject,
            htmlBody: htmlBody,
            textBody: textBody,
            token: token,
          );
        case 'resend':
          return await _sendViaResend(
            toEmail: toEmail,
            subject: subject,
            htmlBody: htmlBody,
            textBody: textBody,
          );
        case 'mailgun':
          return await _sendViaMailgun(
            toEmail: toEmail,
            subject: subject,
            htmlBody: htmlBody,
            textBody: textBody,
          );
        default:
          throw Exception('Provedor de email não configurado: $_provider');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao enviar email: $e');
      }
      return false;
    }
  }

  /// Envia email de recuperação de senha
  Future<bool> sendPasswordResetEmail({
    required String toEmail,
    required String resetLink,
    required String userName,
    String? token,
  }) async {
    try {
      final subject = 'Recuperação de Senha - Carona Universitária';
      final htmlBody = _buildPasswordResetEmailHtml(userName, token);
      final textBody = _buildPasswordResetEmailText(userName, token);

      switch (_provider) {
        case 'emailjs':
          return await _sendViaEmailJS(
            toEmail: toEmail,
            subject: subject,
            htmlBody: htmlBody,
            textBody: textBody,
            token: token,
            resetLink: resetLink,
          );
        case 'resend':
          return await _sendViaResend(
            toEmail: toEmail,
            subject: subject,
            htmlBody: htmlBody,
            textBody: textBody,
          );
        case 'mailgun':
          return await _sendViaMailgun(
            toEmail: toEmail,
            subject: subject,
            htmlBody: htmlBody,
            textBody: textBody,
          );
        default:
          throw Exception('Provedor de email não configurado: $_provider');
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao enviar email de recuperação: $e');
      }
      return false;
    }
  }

  // ===========================================================================
  // IMPLEMENTAÇÃO POR PROVEDOR
  // ===========================================================================

  /// Envia via EmailJS
  Future<bool> _sendViaEmailJS({
    required String toEmail,
    required String subject,
    required String htmlBody,
    required String textBody,
    String? token,
    String? resetLink,
  }) async {
    // Valida se as credenciais estão configuradas
    if (emailjsServiceId.isEmpty ||
        emailjsTemplateId.isEmpty ||
        emailjsPublicKey.isEmpty) {
      if (kDebugMode) {
        print('⚠ EmailJS não configurado completamente.');
        print('   Service ID: ${emailjsServiceId.isEmpty ? "NÃO CONFIGURADO" : emailjsServiceId}');
        print('   Template ID: ${emailjsTemplateId.isEmpty ? "NÃO CONFIGURADO" : emailjsTemplateId}');
        print('   Public Key: ${emailjsPublicKey.isEmpty ? "NÃO CONFIGURADO" : "✓ Configurado"}');
        print('💡 Verifique se preencheu todas as constantes em email_service.dart');
      }
      return false;
    }

    try {
      final url = 'https://api.emailjs.com/api/v1.0/email/send';
      
      // Extrai o nome do usuário do email (parte antes do @)
      final userName = toEmail.split('@').first;
      
      // Prepara os parâmetros do template
      // IMPORTANTE: Os nomes das variáveis devem corresponder ao template no EmailJS
      // Variáveis disponíveis: {{user_name}}, {{token}}, {{to_email}}
      final templateParams = {
        'to_email': toEmail,
        'user_name': userName,
        'token': token ?? '',
        'subject': subject,
        'message': htmlBody, // HTML completo (fallback caso o template não use as variáveis)
        'reset_link': resetLink ?? '',
        'reply_to': 'noreply@carona-universitaria.app',
      };
      
      if (kDebugMode) {
        print('📧 Enviando email via EmailJS...');
        print('   Para: $toEmail');
        print('   Service ID: $emailjsServiceId');
        print('   Template ID: $emailjsTemplateId');
        print('   Token: ${token ?? "N/A"}');
      }
      
      // Prepara o body da requisição
      final requestBody = {
        'service_id': emailjsServiceId,
        'template_id': emailjsTemplateId,
        'user_id': emailjsPublicKey,
        'template_params': templateParams,
      };
      
      // Adiciona Private Key ao body como 'accessToken' (necessário em strict mode)
      // Segundo a documentação do EmailJS, a Private Key deve ser enviada no body, não como header
      if (emailjsPrivateKey.isNotEmpty) {
        requestBody['accessToken'] = emailjsPrivateKey;
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      final responseBody = response.body;
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✓ Email enviado via EmailJS para: $toEmail');
          print('   Resposta: $responseBody');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('✗ Erro ao enviar via EmailJS:');
          print('   Status: ${response.statusCode}');
          print('   Resposta: $responseBody');
          
          // Mensagens de erro comuns
          if (response.statusCode == 400) {
            print('   💡 Erro 400: Verifique se os template_params correspondem ao template');
            print('   💡 Verifique se o template no EmailJS usa as variáveis: {{to_email}}, {{user_name}}, {{token}}, {{message}}');
          } else if (response.statusCode == 403) {
            print('   💡 Erro 403: EmailJS está em "strict mode"');
            if (responseBody.contains('private key')) {
              print('   💡 SOLUÇÃO: Você precisa configurar uma Private Key');
              print('   💡 1. Acesse: https://dashboard.emailjs.com/admin/account');
              print('   💡 2. Vá em "API Keys" → "Add New Key"');
              print('   💡 3. Crie uma Private Key');
              print('   💡 4. Cole a Private Key em emailjsPrivateKey no código');
              print('   💡 OU desative strict mode em: Dashboard → Security');
            } else {
              print('   💡 Verifique se ativou "Allow emails from external domains"');
              print('   💡 Acesse: Dashboard → Security → Allow emails from external domains');
            }
          } else if (response.statusCode == 401) {
            print('   💡 Erro 401: Verifique se o Public Key está correto');
          }
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao enviar via EmailJS: $e');
        print('   💡 Verifique sua conexão com a internet');
        print('   💡 Verifique se as configurações estão corretas');
      }
      return false;
    }
  }

  /// Envia via Resend
  Future<bool> _sendViaResend({
    required String toEmail,
    required String subject,
    required String htmlBody,
    required String textBody,
  }) async {
    if (resendApiKey == null) {
      if (kDebugMode) {
        print('⚠ Resend não configurado. Configure resendApiKey');
      }
      return false;
    }

    try {
      final url = 'https://api.resend.com/emails';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $resendApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'Carona Universitária <noreply@carona-universitaria.app>',
          'to': [toEmail],
          'subject': subject,
          'html': htmlBody,
          'text': textBody,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✓ Email enviado via Resend para: $toEmail');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('✗ Erro ao enviar via Resend: ${response.statusCode} - ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao enviar via Resend: $e');
      }
      return false;
    }
  }

  /// Envia via Mailgun
  Future<bool> _sendViaMailgun({
    required String toEmail,
    required String subject,
    required String htmlBody,
    required String textBody,
  }) async {
    if (mailgunApiKey == null || mailgunDomain == null) {
      if (kDebugMode) {
        print('⚠ Mailgun não configurado. Configure mailgunApiKey e mailgunDomain');
      }
      return false;
    }

    try {
      final url = 'https://api.mailgun.net/v3/$mailgunDomain/messages';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('api:$mailgunApiKey'))}',
        },
        body: {
          'from': 'Carona Universitária <noreply@$mailgunDomain>',
          'to': toEmail,
          'subject': subject,
          'html': htmlBody,
          'text': textBody,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) {
          print('✓ Email enviado via Mailgun para: $toEmail');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('✗ Erro ao enviar via Mailgun: ${response.statusCode} - ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Erro ao enviar via Mailgun: $e');
      }
      return false;
    }
  }

  // ===========================================================================
  // TEMPLATES DE EMAIL
  // ===========================================================================

  String _buildActivationEmailHtml(String token, String userName) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #2196F3 0%, #1976D2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
    .token-box { background: white; padding: 20px; border-radius: 8px; text-align: center; margin: 20px 0; border: 2px dashed #2196F3; }
    .token { font-size: 32px; font-weight: bold; color: #2196F3; letter-spacing: 5px; }
    .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🚗 Carona Universitária</h1>
    </div>
    <div class="content">
      <h2>Olá, ${userName.split(' ').first}!</h2>
      <p>Bem-vindo ao Carona Universitária! Para ativar sua conta, use o código abaixo:</p>
      
      <div class="token-box">
        <div class="token">$token</div>
        <p style="margin-top: 10px; color: #666;">Este código é válido por <strong>30 minutos</strong></p>
      </div>
      
      <p>Digite este código no aplicativo para concluir seu cadastro.</p>
      
      <p style="margin-top: 30px;">Se você não solicitou este código, ignore este email.</p>
    </div>
    <div class="footer">
      <p>© ${DateTime.now().year} Carona Universitária - Todos os direitos reservados</p>
      <p>Este é um email automático, por favor não responda.</p>
    </div>
  </div>
</body>
</html>
''';
  }

  String _buildActivationEmailText(String token, String userName) {
    return '''
Olá, ${userName.split(' ').first}!

Bem-vindo ao Carona Universitária!

Para ativar sua conta, use o código abaixo:

$token

Este código é válido por 30 minutos.

Digite este código no aplicativo para concluir seu cadastro.

Se você não solicitou este código, ignore este email.

© ${DateTime.now().year} Carona Universitária
''';
  }

  String _buildPasswordResetEmailHtml(String userName, String? token) {
    final tokenDisplay = token ?? 'NÃO DISPONÍVEL';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #2196F3 0%, #1976D2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
    .token-box { background: #fff; border: 3px solid #2196F3; border-radius: 10px; padding: 25px; margin: 25px 0; text-align: center; }
    .token-code { font-size: 36px; font-weight: bold; color: #2196F3; letter-spacing: 8px; font-family: 'Courier New', monospace; margin: 15px 0; }
    .instructions { background: #E3F2FD; border-left: 4px solid #2196F3; padding: 15px; margin: 20px 0; border-radius: 5px; }
    .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
    .warning { margin-top: 30px; color: #666; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🔐 Recuperação de Senha</h1>
    </div>
    <div class="content">
      <h2>Olá, ${userName.split(' ').first}!</h2>
      <p>Recebemos uma solicitação para redefinir sua senha.</p>
      
      <div class="token-box">
        <p style="margin: 0 0 10px 0; font-weight: bold; color: #333;">Seu código de recuperação:</p>
        <div class="token-code">$tokenDisplay</div>
        <p style="margin: 10px 0 0 0; color: #666; font-size: 14px;">Copie este código e cole no aplicativo</p>
      </div>
      
      <div class="instructions">
        <p style="margin: 0 0 10px 0; font-weight: bold; color: #1976D2;">📱 Como usar:</p>
        <ol style="margin: 0; padding-left: 20px; color: #333;">
          <li>Abra o aplicativo Carona Universitária</li>
          <li>Vá até a tela de recuperação de senha</li>
          <li>Cole o código acima no campo indicado</li>
          <li>Defina sua nova senha</li>
        </ol>
      </div>
      
      <p class="warning">
        ⚠️ <strong>Este código é válido por 30 minutos.</strong><br>
        Se você não solicitou esta recuperação, ignore este email.
      </p>
    </div>
    <div class="footer">
      <p>© ${DateTime.now().year} Carona Universitária - Todos os direitos reservados</p>
      <p>Este é um email automático, por favor não responda.</p>
    </div>
  </div>
</body>
</html>
''';
  }

  String _buildPasswordResetEmailText(String userName, String? token) {
    final tokenDisplay = token ?? 'NÃO DISPONÍVEL';
    return '''
Olá, ${userName.split(' ').first}!

Recebemos uma solicitação para redefinir sua senha.

Seu código de recuperação é:
$tokenDisplay

COMO USAR:
1. Abra o aplicativo Carona Universitária
2. Vá até a tela de recuperação de senha
3. Cole o código acima no campo indicado
4. Defina sua nova senha

⚠️ Este código é válido por 30 minutos.

Se você não solicitou esta recuperação, ignore este email.

© ${DateTime.now().year} Carona Universitária - Todos os direitos reservados
Este é um email automático, por favor não responda.
''';
  }
}

