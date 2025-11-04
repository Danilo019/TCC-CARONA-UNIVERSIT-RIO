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

    // Verifica expiração (antes de tudo)
    const expiresAt = tokenData.expiresAt.toMillis();
    if (Date.now() > expiresAt) {
      return res.status(403).json({
        success: false,
        error: 'token_expired',
        message: 'Token expirado. Solicite um novo código.',
      });
    }

    // Permite usar token mesmo se já foi usado na validação inicial
    // O token foi validado antes de navegar para tela de reset, mas não foi usado para reset ainda
    // Se o token já foi usado mas o email corresponde e não expirou, ainda permite
    if (tokenData.isUsed === true) {
      console.log('⚠ Token já foi marcado como usado (pode ser da validação inicial), mas permitindo reset se email corresponde e não expirou');
      // Continua o processo - o token será marcado como usado novamente após reset bem-sucedido
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

