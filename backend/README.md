# 🔧 Backend para Reset de Senha - Carona Universitária

Backend simples em Node.js/Express para reset de senha usando Firebase Admin SDK.

## ✅ Vantagens

- ✅ **Funciona sem plano Blaze** (plano Spark é suficiente)
- ✅ **Gratuito** (pode hospedar no Heroku, Vercel, Railway)
- ✅ **Atualiza senha diretamente** no Firebase Authentication
- ✅ **Seguro** (valida token antes de atualizar)

## 📋 Pré-requisitos

1. Node.js 18+ instalado
2. Conta Firebase (plano Spark é suficiente)
3. Service Account Key do Firebase

## 🔧 Configuração Local

### 1. Instalar Dependências

```bash
cd backend
npm install
```

### 2. Obter Service Account Key

1. Acesse: https://console.firebase.google.com/project/carona-universitiaria/settings/serviceaccounts/adminsdk
2. Clique em "Gerar nova chave privada"
3. Baixe o arquivo JSON

### 3. Configurar Variáveis de Ambiente

Crie um arquivo `.env` na pasta `backend`:

```env
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"carona-universitiaria",...}
PORT=3000
```

**Ou** salve o JSON em `serviceAccountKey.json` e atualize `server.js` para usar:

```javascript
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
```

### 4. Executar Localmente

```bash
npm start
```

O servidor estará disponível em: `http://localhost:3000`

## 🚀 Deploy em Produção

### Opção 1: Heroku (Gratuito)

```bash
# Instalar Heroku CLI
npm install -g heroku

# Login
heroku login

# Criar app
heroku create carona-universitaria-backend

# Adicionar variável de ambiente
heroku config:set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'

# Deploy
git push heroku main
```

### Opção 2: Vercel (Gratuito)

1. Instale Vercel CLI: `npm install -g vercel`
2. Execute: `vercel`
3. Configure `FIREBASE_SERVICE_ACCOUNT` nas variáveis de ambiente no dashboard

### Opção 3: Railway (Gratuito com créditos)

1. Acesse: https://railway.app
2. Conecte seu repositório
3. Configure `FIREBASE_SERVICE_ACCOUNT` nas variáveis de ambiente

## 📡 Endpoint

### POST `/api/reset-password`

**Body:**
```json
{
  "email": "usuario@cs.udf.edu.br",
  "token": "123456",
  "newPassword": "NovaSenha123!"
}
```

**Response (Sucesso):**
```json
{
  "success": true,
  "message": "Senha redefinida com sucesso!"
}
```

**Response (Erro):**
```json
{
  "success": false,
  "error": "token_expired",
  "message": "Token expirado. Solicite um novo código."
}
```

## 🔒 Segurança

- ✅ Valida token antes de atualizar senha
- ✅ Valida formato de email
- ✅ Valida força da senha
- ✅ Marca token como usado após reset
- ✅ CORS configurado

## 📝 Nota

Este backend é uma alternativa simples para Cloud Functions. Para produção em escala, considere usar Cloud Functions quando possível atualizar para o plano Blaze.

