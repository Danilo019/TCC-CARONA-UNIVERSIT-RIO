const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

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

