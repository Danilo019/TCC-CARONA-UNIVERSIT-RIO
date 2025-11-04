const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Inicializa Admin SDK (se ainda não foi inicializado)
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Cloud Function para redefinir senha usando token customizado
 * 
 * Recebe: { email, token, newPassword }
 * Retorna: { success: true }
 * 
 * Valida o token no Firestore e atualiza a senha usando Admin SDK
 */
exports.resetPassword = functions.https.onCall(async (data, context) => {
  try {
    const { email, token, newPassword } = data;

    // Validação de entrada
    if (!email || !token || !newPassword) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email, token e nova senha são obrigatórios'
      );
    }

    // Valida formato do email
    if (!email.endsWith('@cs.udf.edu.br')) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Apenas emails @cs.udf.edu.br são permitidos'
      );
    }

    // Valida força da senha (mínimo 8 caracteres)
    if (newPassword.length < 8) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'A senha deve ter no mínimo 8 caracteres'
      );
    }

    // 1. Busca token no Firestore
    const tokenDoc = await admin.firestore()
      .collection('activationTokens')
      .doc(token)
      .get();

    if (!tokenDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Token inválido ou não encontrado'
      );
    }

    const tokenData = tokenDoc.data();

    // 2. Valida token
    if (tokenData.email !== email) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Token não corresponde ao email informado'
      );
    }

    if (tokenData.isUsed === true) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Token já foi usado'
      );
    }

    // Verifica expiração
    const expiresAt = tokenData.expiresAt.toMillis();
    if (Date.now() > expiresAt) {
      throw new functions.https.HttpsError(
        'deadline-exceeded',
        'Token expirado. Solicite um novo código.'
      );
    }

    // 3. Busca usuário no Firebase Auth
    let user;
    try {
      user = await admin.auth().getUserByEmail(email);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        throw new functions.https.HttpsError(
          'not-found',
          'Usuário não encontrado com este email'
        );
      }
      throw error;
    }

    // 4. Atualiza senha usando Admin SDK
    await admin.auth().updateUser(user.uid, {
      password: newPassword
    });

    // 5. Marca token como usado
    await admin.firestore()
      .collection('activationTokens')
      .doc(token)
      .update({
        isUsed: true
      });

    // Log de sucesso (sem senha)
    functions.logger.info(`Senha redefinida com sucesso para: ${email}`);

    return {
      success: true,
      message: 'Senha redefinida com sucesso!'
    };

  } catch (error) {
    // Se já é um HttpsError, relança
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    // Outros erros
    functions.logger.error('Erro ao redefinir senha:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Erro ao redefinir senha. Tente novamente mais tarde.'
    );
  }
});

