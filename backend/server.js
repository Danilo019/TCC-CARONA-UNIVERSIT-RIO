const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

// Carrega variáveis de ambiente
require('dotenv').config();

const app = express();
// Railway e outras plataformas definem PORT automaticamente
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Inicializa Firebase Admin SDK
// IMPORTANTE: Configure FIREBASE_SERVICE_ACCOUNT como variável de ambiente
// ou use um arquivo de credenciais
let firebaseInitialized = false;

try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    // Usa credenciais de variável de ambiente (JSON string)
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    firebaseInitialized = true;
    console.log('✓ Firebase Admin SDK inicializado com sucesso');
  } else if (process.env.FIREBASE_PROJECT_ID) {
    // Usa Application Default Credentials (para produção)
    admin.initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID,
    });
    firebaseInitialized = true;
    console.log('✓ Firebase Admin SDK inicializado com Application Default Credentials');
  } else {
    console.warn('⚠ Firebase Admin SDK não inicializado - configure FIREBASE_SERVICE_ACCOUNT');
  }
} catch (error) {
  console.error('✗ Erro ao inicializar Firebase Admin SDK:', error.message);
}

// Configura Nodemailer para envio de e-mails
// Use variáveis de ambiente para configurar SMTP
let transporter = null;
try {
  // Tenta configurar com Gmail (ou outro provedor SMTP)
  if (process.env.SMTP_USER && process.env.SMTP_PASS) {
    transporter = nodemailer.createTransport({
      service: process.env.SMTP_SERVICE || 'gmail',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS, // Use App Password para Gmail
      },
    });
    console.log('✓ Nodemailer configurado com sucesso');
  } else {
    console.warn('⚠ SMTP não configurado - e-mails não serão enviados');
    console.warn('💡 Configure SMTP_USER e SMTP_PASS no Railway');
  }
} catch (error) {
  console.error('✗ Erro ao configurar Nodemailer:', error.message);
}

// Rota de health check
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Carona Universitária - Password Reset API',
    firebaseInitialized: firebaseInitialized,
  });
});

// Rota para criar tokens de ativação/reset
app.post('/api/issue-token', async (req, res) => {
  try {
    if (!firebaseInitialized) {
      return res.status(503).json({
        success: false,
        error: 'Firebase Admin SDK não inicializado',
        message: 'Configure FIREBASE_SERVICE_ACCOUNT',
      });
    }

    const { email, purpose = 'activation' } = req.body;

    // Validação de entrada
    if (!email) {
      return res.status(400).json({
        success: false,
        error: 'missing_email',
        message: 'Email é obrigatório',
      });
    }

    // Valida formato do email
    if (!email.endsWith('@cs.udf.edu.br')) {
      return res.status(400).json({
        success: false,
        error: 'invalid_email',
        message: 'Apenas emails @cs.udf.edu.br são permitidos',
      });
    }

    // Valida purpose
    if (purpose !== 'activation' && purpose !== 'password_reset') {
      return res.status(400).json({
        success: false,
        error: 'invalid_purpose',
        message: 'Purpose inválido. Use "activation" ou "password_reset"',
      });
    }

    const firestore = admin.firestore();
    const TOKEN_VALIDITY_MINUTES = 30;
    const TOKEN_ATTEMPTS = 10;

    // Função para gerar token de 6 dígitos
    const generateSixDigitToken = () => {
      const token = Math.floor(100000 + Math.random() * 900000);
      return token.toString();
    };

    // Tenta gerar token único
    for (let attempt = 0; attempt < TOKEN_ATTEMPTS; attempt++) {
      const token = generateSixDigitToken();
      const tokenRef = firestore.collection('activationTokens').doc(token);
      const tokenDoc = await tokenRef.get();

      if (tokenDoc.exists) {
        continue; // Token já existe, tenta outro
      }

      const createdAt = admin.firestore.Timestamp.now();
      const expiresAt = admin.firestore.Timestamp.fromMillis(
        createdAt.toMillis() + TOKEN_VALIDITY_MINUTES * 60 * 1000
      );

      // Cria o token
      await tokenRef.set({
        token,
        email,
        purpose,
        createdAt,
        expiresAt,
        isUsed: false,
      });

      console.log(`✓ Token criado com sucesso: ${token} para ${email}`);

      return res.json({
        success: true,
        token,
        email,
        purpose,
        isUsed: false,
        createdAt: createdAt.toMillis(),
        expiresAt: expiresAt.toMillis(),
      });
    }

    // Se chegou aqui, não conseguiu gerar token único
    return res.status(500).json({
      success: false,
      error: 'resource_exhausted',
      message: 'Não foi possível gerar um token único. Tente novamente.',
    });
  } catch (error) {
    console.error('✗ Erro ao criar token:', error);
    return res.status(500).json({
      success: false,
      error: 'internal_error',
      message: 'Erro ao criar token. Tente novamente mais tarde.',
    });
  }
});

// Rota para validar tokens
app.post('/api/validate-token', async (req, res) => {
  try {
    if (!firebaseInitialized) {
      return res.status(503).json({
        success: false,
        error: 'Firebase Admin SDK não inicializado',
        message: 'Configure FIREBASE_SERVICE_ACCOUNT',
      });
    }

    const { email, token, markAsUsed = false } = req.body;

    // Validação de entrada
    if (!email || !token) {
      return res.status(400).json({
        success: false,
        error: 'missing_fields',
        message: 'Email e token são obrigatórios',
      });
    }

    // Valida formato do email
    if (!email.endsWith('@cs.udf.edu.br')) {
      return res.status(400).json({
        success: false,
        error: 'invalid_email',
        message: 'Apenas emails @cs.udf.edu.br são permitidos',
      });
    }

    const firestore = admin.firestore();
    const tokenRef = firestore.collection('activationTokens').doc(token);
    const tokenDoc = await tokenRef.get();

    if (!tokenDoc.exists) {
      return res.status(404).json({
        success: false,
        isValid: false,
        error: 'token_not_found',
        message: 'Token inválido ou não encontrado',
      });
    }

    const tokenData = tokenDoc.data();

    // Valida correspondência do email
    if (tokenData.email !== email) {
      return res.status(403).json({
        success: false,
        isValid: false,
        error: 'token_mismatch',
        message: 'Token não corresponde ao email informado',
      });
    }

    // Verifica se já foi usado
    if (tokenData.isUsed === true) {
      return res.status(403).json({
        success: false,
        isValid: false,
        error: 'token_used',
        message: 'Token já foi usado',
      });
    }

    // Verifica expiração
    const expiresAt = tokenData.expiresAt.toMillis();
    if (Date.now() > expiresAt) {
      return res.status(403).json({
        success: false,
        isValid: false,
        error: 'token_expired',
        message: 'Token expirado. Solicite um novo código.',
      });
    }

    // Se markAsUsed=true, marca o token como usado
    if (markAsUsed) {
      await tokenRef.update({
        isUsed: true,
      });
      console.log(`✓ Token marcado como usado: ${token} para ${email}`);
    }

    console.log(`✓ Token validado com sucesso: ${token} para ${email}`);

    return res.json({
      success: true,
      isValid: true,
      token: tokenData.token,
      email: tokenData.email,
      purpose: tokenData.purpose,
      expiresAt: expiresAt,
    });
  } catch (error) {
    console.error('✗ Erro ao validar token:', error);
    return res.status(500).json({
      success: false,
      isValid: false,
      error: 'internal_error',
      message: 'Erro ao validar token. Tente novamente mais tarde.',
    });
  }
});

// Rota para enviar token por e-mail
app.post('/api/send-token-email', async (req, res) => {
  try {
    if (!firebaseInitialized) {
      return res.status(503).json({
        success: false,
        error: 'Firebase Admin SDK não inicializado',
        message: 'Configure FIREBASE_SERVICE_ACCOUNT',
      });
    }

    const { email, purpose = 'activation' } = req.body;

    // Validação de entrada
    if (!email) {
      return res.status(400).json({
        success: false,
        error: 'missing_email',
        message: 'Email é obrigatório',
      });
    }

    // Valida formato do email
    if (!email.endsWith('@cs.udf.edu.br')) {
      return res.status(400).json({
        success: false,
        error: 'invalid_email',
        message: 'Apenas emails @cs.udf.edu.br são permitidos',
      });
    }

    // Valida purpose
    if (purpose !== 'activation' && purpose !== 'password_reset') {
      return res.status(400).json({
        success: false,
        error: 'invalid_purpose',
        message: 'Purpose inválido. Use "activation" ou "password_reset"',
      });
    }

    const firestore = admin.firestore();
    const TOKEN_VALIDITY_MINUTES = 30;
    const TOKEN_ATTEMPTS = 10;

    // Função para gerar token de 6 dígitos
    const generateSixDigitToken = () => {
      const token = Math.floor(100000 + Math.random() * 900000);
      return token.toString();
    };

    // Tenta gerar token único
    let token = null;
    for (let attempt = 0; attempt < TOKEN_ATTEMPTS; attempt++) {
      const candidateToken = generateSixDigitToken();
      const tokenRef = firestore.collection('activationTokens').doc(candidateToken);
      const tokenDoc = await tokenRef.get();

      if (tokenDoc.exists) {
        continue; // Token já existe, tenta outro
      }

      const createdAt = admin.firestore.Timestamp.now();
      const expiresAt = admin.firestore.Timestamp.fromMillis(
        createdAt.toMillis() + TOKEN_VALIDITY_MINUTES * 60 * 1000
      );

      // Cria o token
      await tokenRef.set({
        token: candidateToken,
        email,
        purpose,
        createdAt,
        expiresAt,
        isUsed: false,
      });

      token = candidateToken;
      break;
    }

    if (!token) {
      return res.status(500).json({
        success: false,
        error: 'resource_exhausted',
        message: 'Não foi possível gerar um token único. Tente novamente.',
      });
    }

    // Configurações de e-mail
    const emailSubject = purpose === 'activation' 
      ? 'Verifique seu e-mail do app Carona Universitária UDF'
      : 'Redefinição de senha - Carona Universitária UDF';

    const emailBody = purpose === 'activation'
      ? `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
    .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 5px 5px; }
    .token { font-size: 32px; font-weight: bold; color: #4CAF50; text-align: center; padding: 20px; background-color: white; border-radius: 5px; margin: 20px 0; letter-spacing: 5px; }
    .footer { text-align: center; margin-top: 20px; font-size: 12px; color: #666; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Carona Universitária UDF</h1>
    </div>
    <div class="content">
      <h2>Verificação de E-mail</h2>
      <p>Olá,</p>
      <p>Você solicitou a verificação do seu e-mail no app <strong>Carona Universitária UDF</strong>.</p>
      <p>Use o código abaixo para confirmar seu endereço de e-mail:</p>
      <div class="token">${token}</div>
      <p><strong>Este código expira em ${TOKEN_VALIDITY_MINUTES} minutos.</strong></p>
      <p>Se você não solicitou esta verificação, ignore este e-mail.</p>
      <div class="footer">
        <p>Equipe do app Carona Universitária UDF</p>
        <p>Universidade UDF</p>
      </div>
    </div>
  </div>
</body>
</html>
      `
      : `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #FF5722; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
    .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 5px 5px; }
    .token { font-size: 32px; font-weight: bold; color: #FF5722; text-align: center; padding: 20px; background-color: white; border-radius: 5px; margin: 20px 0; letter-spacing: 5px; }
    .footer { text-align: center; margin-top: 20px; font-size: 12px; color: #666; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Carona Universitária UDF</h1>
    </div>
    <div class="content">
      <h2>Redefinição de Senha</h2>
      <p>Olá,</p>
      <p>Você solicitou a redefinição de senha no app <strong>Carona Universitária UDF</strong>.</p>
      <p>Use o código abaixo para redefinir sua senha:</p>
      <div class="token">${token}</div>
      <p><strong>Este código expira em ${TOKEN_VALIDITY_MINUTES} minutos.</strong></p>
      <p>Se você não solicitou esta redefinição, ignore este e-mail e sua senha permanecerá inalterada.</p>
      <div class="footer">
        <p>Equipe do app Carona Universitária UDF</p>
        <p>Universidade UDF</p>
      </div>
    </div>
  </div>
</body>
</html>
      `;

    // Envia e-mail usando Firebase Auth Action Mail
    const actionCodeSettings = {
      url: 'https://carona-universitaria.firebaseapp.com/__/auth/action?mode=verifyEmail',
      handleCodeInApp: true,
    };

    // Busca ou cria usuário no Firebase Auth
    let user;
    try {
      user = await admin.auth().getUserByEmail(email);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        // Se for activation e usuário não existe, podemos criar temporariamente
        if (purpose === 'activation') {
          return res.status(404).json({
            success: false,
            error: 'user_not_found',
            message: 'Usuário deve ser criado primeiro antes de enviar token de ativação',
          });
        }
        return res.status(404).json({
          success: false,
          error: 'user_not_found',
          message: 'Usuário não encontrado',
        });
      }
      throw error;
    }

    // Tenta enviar e-mail real usando Nodemailer
    let emailSent = false;
    let emailError = null;

    if (transporter) {
      try {
        const mailOptions = {
          from: `"Carona Universitária UDF" <${process.env.SMTP_USER}>`,
          to: email,
          subject: emailSubject,
          html: emailBody,
        };

        await transporter.sendMail(mailOptions);
        emailSent = true;
        console.log(`✓ E-mail enviado com sucesso para: ${email}`);
      } catch (error) {
        console.error(`✗ Erro ao enviar e-mail: ${error.message}`);
        emailError = error.message;
        // Continua mesmo se falhar, pois o token já foi criado
      }
    } else {
      console.warn('⚠ SMTP não configurado - e-mail não foi enviado');
      emailError = 'SMTP não configurado no servidor';
    }
    
    // Salva log no Firestore
    await firestore.collection('emailLogs').add({
      email,
      token,
      purpose,
      subject: emailSubject,
      sentAt: admin.firestore.Timestamp.now(),
      status: emailSent ? 'sent' : 'failed',
      error: emailError || null,
    });

    console.log(`✓ Token criado: ${token} para ${email}`);
    if (!emailSent) {
      console.warn(`⚠ E-mail não foi enviado. Configure SMTP no Railway.`);
    }

    return res.json({
      success: true,
      message: emailSent 
        ? 'Token gerado e enviado por e-mail com sucesso'
        : 'Token gerado (e-mail não enviado - configure SMTP)',
      email,
      purpose,
      emailSent,
      // Retorna o token em desenvolvimento OU se o email não foi enviado
      ...(process.env.NODE_ENV !== 'production' || !emailSent ? { token } : {}),
    });
  } catch (error) {
    console.error('✗ Erro ao enviar token por e-mail:', error);
    return res.status(500).json({
      success: false,
      error: 'internal_error',
      message: 'Erro ao enviar token. Tente novamente mais tarde.',
      details: error.message,
    });
  }
});

// Rota para reset de senha
app.post('/api/reset-password', async (req, res) => {
  try {
    if (!firebaseInitialized) {
      return res.status(503).json({
        success: false,
        error: 'Firebase Admin SDK não inicializado',
        message: 'Configure FIREBASE_SERVICE_ACCOUNT',
      });
    }

    const { email, token, newPassword } = req.body;

    // Validação de entrada
    if (!email || !token || !newPassword) {
      return res.status(400).json({
        success: false,
        error: 'missing_fields',
        message: 'Email, token e nova senha são obrigatórios',
      });
    }

    // Valida formato do email
    if (!email.endsWith('@cs.udf.edu.br')) {
      return res.status(400).json({
        success: false,
        error: 'invalid_email',
        message: 'Apenas emails @cs.udf.edu.br são permitidos',
      });
    }

    // Valida força da senha
    if (newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        error: 'weak_password',
        message: 'A senha deve ter no mínimo 8 caracteres',
      });
    }

    // 1. Busca token no Firestore
    const firestore = admin.firestore();
    const tokenDoc = await firestore.collection('activationTokens').doc(token).get();

    if (!tokenDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'token_not_found',
        message: 'Token inválido ou não encontrado',
      });
    }

    const tokenData = tokenDoc.data();

    // 2. Valida token
    if (tokenData.email !== email) {
      return res.status(403).json({
        success: false,
        error: 'token_mismatch',
        message: 'Token não corresponde ao email informado',
      });
    }

    if (tokenData.isUsed === true) {
      return res.status(403).json({
        success: false,
        error: 'token_used',
        message: 'Token já foi usado',
      });
    }
    // Verifica expiração
    const expiresAt = tokenData.expiresAt.toMillis();
    if (Date.now() > expiresAt) {
      return res.status(403).json({
        success: false,
        error: 'token_expired',
        message: 'Token expirado. Solicite um novo código.',
      });
    }
    // 3. Busca usuário no Firebase Auth
    let user;
    try {
      user = await admin.auth().getUserByEmail(email);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        return res.status(404).json({
          success: false,
          error: 'user_not_found',
          message: 'Usuário não encontrado com este email',
        });
      }
      throw error;
    }

    // 4. Atualiza senha usando Admin SDK
    await admin.auth().updateUser(user.uid, {
      password: newPassword,
    });

    // 5. Marca token como usado
    await firestore.collection('activationTokens').doc(token).update({
      isUsed: true,
    });

    console.log(`✓ Senha redefinida com sucesso para: ${email}`);

    return res.json({
      success: true,
      message: 'Senha redefinida com sucesso!',
    });
  } catch (error) {
    console.error('✗ Erro ao redefinir senha:', error);
    return res.status(500).json({
      success: false,
      error: 'internal_error',
      message: 'Erro ao redefinir senha. Tente novamente mais tarde.',
    });
  }
});

// Inicia servidor
app.listen(PORT, () => {
  console.log(`🚀 Servidor rodando na porta ${PORT}`);
  console.log(`📡 Endpoint: http://localhost:${PORT}/api/reset-password`);
  console.log(`💡 Para produção, configure as variáveis de ambiente`);
});

