// Cloud Functions para Firebase - gerencia tokens de ativação e reset de senha
// Executa operações privilegiadas usando Firebase Admin SDK

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Inicializa Admin SDK (se ainda não foi inicializado)
if (!admin.apps.length) {
  admin.initializeApp();
}

const TOKEN_ATTEMPTS = 10;
const TOKEN_VALIDITY_MINUTES = 30;

const generateSixDigitToken = () => {
  const token = Math.floor(100000 + Math.random() * 900000);
  return token.toString();
};

// Função cloud que gera tokens de 6 dígitos para ativação de conta ou reset de senha
// Valida email institucional e garante unicidade do token
exports.issueActivationToken = functions.https.onCall(async (data, context) => {
  try {
    const { email, purpose = 'activation' } = data;

    if (!email || typeof email !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email é obrigatório.'
      );
    }

    if (!email.endsWith('@cs.udf.edu.br')) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Apenas emails @cs.udf.edu.br são permitidos.'
      );
    }

    if (purpose !== 'activation' && purpose !== 'password_reset') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Purpose inválido. Use "activation" ou "password_reset".'
      );
    }

    const tokensCollection = admin.firestore().collection('activationTokens');
    const createdAt = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      createdAt.toMillis() + TOKEN_VALIDITY_MINUTES * 60 * 1000
    );

    for (let attempt = 0; attempt < TOKEN_ATTEMPTS; attempt += 1) {
      const token = generateSixDigitToken();
      const docRef = tokensCollection.doc(token);
      const snapshot = await docRef.get();

      if (snapshot.exists) {
        continue;
      }

      await docRef.set({
        token,
        email,
        purpose,
        createdAt,
        expiresAt,
        isUsed: false,
      });

      functions.logger.info('Token emitido com sucesso', {
        email,
        purpose,
        expiresAt: expiresAt.toMillis(),
      });

      return {
        token,
        email,
        purpose,
        isUsed: false,
        createdAt: createdAt.toMillis(),
        expiresAt: expiresAt.toMillis(),
      };
    }

    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Não foi possível gerar um token único. Tente novamente.'
    );
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    functions.logger.error('Erro ao emitir token:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Erro ao gerar token. Tente novamente mais tarde.'
    );
  }
});

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

/**
 * Cloud Function para validar tokens de ativação/reset.
 *
 * Recebe: { email, token, markAsUsed? }
 * Retorna: { isValid: boolean, expiresAt?: number }
 *
 * Opcionalmente marca o token como usado quando markAsUsed = true.
 */
exports.validateActivationToken = functions.https.onCall(async (data, context) => {
  try {
    const { email, token, markAsUsed = false } = data;

    if (!email || !token) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email e token são obrigatórios'
      );
    }

    if (typeof email !== 'string' || typeof token !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email e token devem ser strings'
      );
    }

    if (!email.endsWith('@cs.udf.edu.br')) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Apenas emails @cs.udf.edu.br são permitidos'
      );
    }

    // Busca token no Firestore
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

    const expiresAt = tokenData.expiresAt.toMillis();
    if (Date.now() > expiresAt) {
      throw new functions.https.HttpsError(
        'deadline-exceeded',
        'Token expirado. Solicite um novo código.'
      );
    }

    if (markAsUsed === true) {
      await tokenDoc.ref.update({
        isUsed: true,
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    functions.logger.info('Token validado com sucesso', {
      email,
      token,
      markAsUsed,
    });

    return {
      isValid: true,
      expiresAt,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    functions.logger.error('Erro ao validar token:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Erro ao validar token. Tente novamente mais tarde.'
    );
  }
});

/**
 * Dispara notificação quando uma nova carona é criada.
 */
exports.onRideCreated = functions.firestore
  .document('rides/{rideId}')
  .onCreate(async (snap, context) => {
    try {
      const ride = snap.data();
      if (!ride) {
        return;
      }

      if (ride.status !== 'active' || ride.availableSeats <= 0) {
        return;
      }

      const origin = ride.origin?.address || 'Origem não informada';
      const destination = ride.destination?.address || 'Destino não informado';
      const dateTime = ride.dateTime?.toDate
        ? ride.dateTime.toDate()
        : ride.dateTime
        ? new Date(ride.dateTime)
        : null;

      const formattedTime = dateTime
        ? `${dateTime.getHours().toString().padStart(2, '0')}:${dateTime
            .getMinutes()
            .toString()
            .padStart(2, '0')}`
        : '';

      await admin.messaging().send({
        topic: 'new_rides',
        notification: {
          title: 'Nova carona disponível',
          body: formattedTime
            ? `${origin} → ${destination} às ${formattedTime}`
            : `${origin} → ${destination}`,
        },
        data: {
          rideId: snap.id,
          driverId: ride.driverId || '',
        },
      });
    } catch (error) {
      functions.logger.error('Erro ao enviar notificação de nova carona', error);
    }
  });

