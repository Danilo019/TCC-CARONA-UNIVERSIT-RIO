# 🚀 Guia Rápido: Deploy no Railway

## Passo a Passo para Configurar o Sistema de E-mails

### 1️⃣ Preparar Firebase Service Account

#### Opção A: Via Firebase Console (Recomendado)

1. Acesse: https://console.firebase.google.com/
2. Selecione seu projeto: **TCC-CARONA-UNIVERSITÁRIO**
3. Clique no ícone de **⚙️ engrenagem** → **Configurações do projeto**
4. Vá na aba **Contas de serviço**
5. Clique em **Gerar nova chave privada** (botão azul)
6. Salve o arquivo JSON baixado

#### Opção B: Via PowerShell (Para copiar como variável)

No Windows PowerShell, execute:

```powershell
# Navegue até a pasta onde está o arquivo JSON baixado
cd C:\Downloads

# Leia o arquivo e copie para clipboard (minificado)
(Get-Content .\serviceAccountKey.json -Raw) -replace '\s+', ' ' | Set-Clipboard

# Agora você pode colar direto no Railway
```

### 2️⃣ Configurar Variáveis no Railway

1. Acesse: https://railway.app/
2. Selecione seu projeto
3. Clique no serviço **backend**
4. Vá em **Variables** (aba lateral)
5. Clique em **+ New Variable**
6. Adicione as seguintes variáveis:

#### Variável 1: FIREBASE_SERVICE_ACCOUNT
```
Name: FIREBASE_SERVICE_ACCOUNT
Value: [Cole o JSON completo aqui]
```

**Importante:** O JSON deve estar em uma única linha, sem quebras. Exemplo:
```json
{"type":"service_account","project_id":"tcc-carona-universitario","private_key_id":"abc123...","private_key":"-----BEGIN PRIVATE KEY-----\nXXXXX\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk@...","client_id":"123456789"}
```

#### Variável 2: NODE_ENV (Opcional)
```
Name: NODE_ENV
Value: production
```

### 3️⃣ Configurar Firebase Authentication para E-mails

1. Acesse: https://console.firebase.google.com/
2. Selecione seu projeto
3. Vá em **Authentication** (menu lateral)
4. Clique na aba **Templates** (no topo)
5. Configure os templates:

#### Template: Verificação de endereço de e-mail
- **Nome do remetente:** `Carona Universitária UDF`
- **E-mail do remetente:** `noreply@carona-universitaria.firebaseapp.com`
- **Assunto:** `Verifique seu e-mail do app %APP_NAME%`
- **Responder para:** `noreply` (ou deixe vazio)

#### Template: Redefinição de senha
- **Nome do remetente:** `Carona Universitária UDF`
- **E-mail do remetente:** `noreply@carona-universitaria.firebaseapp.com`
- **Assunto:** `Redefinição de senha - %APP_NAME%`

### 4️⃣ (Opcional) Configurar SMTP Customizado

Se você quiser usar um servidor SMTP próprio (Gmail, Outlook, etc):

1. Em **Authentication** → **Templates**
2. Role até o final e clique em **Configurações do SMTP**
3. Configure:
   - **Servidor SMTP:** smtp.gmail.com (ou outro)
   - **Porta:** 587
   - **Nome de usuário:** seu-email@gmail.com
   - **Senha:** senha de aplicativo (não sua senha normal!)

**Para Gmail:**
- Acesse: https://myaccount.google.com/apppasswords
- Crie uma senha de app
- Use essa senha no Firebase

### 5️⃣ Testar o Sistema

#### 5.1. Verificar se Backend Está Rodando

Abra no navegador:
```
https://SEU-PROJETO.up.railway.app/
```

Você deve ver:
```json
{
  "status": "ok",
  "service": "Carona Universitária - Password Reset API",
  "firebaseInitialized": true
}
```

Se `firebaseInitialized` for `false`, revise o passo 2.

#### 5.2. Testar Envio de Token via cURL

No PowerShell:

```powershell
# Substitua SEU-PROJETO pela URL do Railway
$url = "https://SEU-PROJETO.up.railway.app/api/send-token-email"

$body = @{
    email = "seu.email@cs.udf.edu.br"
    purpose = "activation"
} | ConvertTo-Json

Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json"
```

#### 5.3. Testar no App Flutter

1. Atualize a URL no arquivo `lib/services/email_token_service.dart`:
   ```dart
   static const String _baseUrl = 'https://SEU-PROJETO.up.railway.app';
   ```

2. Execute o app:
   ```bash
   flutter pub get
   flutter run
   ```

3. Use a tela de exemplo:
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => EmailTokenIntegrationExample(),
     ),
   );
   ```

### 6️⃣ Obter URL do Railway

Se você não sabe a URL do seu projeto:

1. Acesse Railway Dashboard
2. Clique no serviço **backend**
3. Vá em **Settings** (ícone de engrenagem)
4. Role até **Networking**
5. Copie o **Public Domain**

Exemplo: `seu-projeto-production-abcd.up.railway.app`

### 7️⃣ Estrutura de Firestore

O sistema criará automaticamente estas collections:

#### Collection: `activationTokens`
```
Document ID: [6 dígitos do token]
{
  token: "123456",
  email: "usuario@cs.udf.edu.br",
  purpose: "activation" | "password_reset",
  createdAt: Timestamp,
  expiresAt: Timestamp,
  isUsed: false
}
```

#### Collection: `emailLogs`
```
{
  email: "usuario@cs.udf.edu.br",
  token: "123456",
  purpose: "activation",
  subject: "Verifique seu e-mail...",
  sentAt: Timestamp,
  status: "sent"
}
```

### 8️⃣ Monitorar Logs

#### No Railway:

1. Clique no serviço **backend**
2. Vá em **Deployments**
3. Clique no deployment ativo (verde)
4. Role para ver os logs em tempo real

Você verá mensagens como:
```
✓ Firebase Admin SDK inicializado com sucesso
🚀 Servidor rodando na porta 3000
✓ Token criado e e-mail enviado com sucesso: 123456 para usuario@cs.udf.edu.br
```

#### No Firebase Console:

1. Vá em **Firestore Database**
2. Veja as collections `activationTokens` e `emailLogs`
3. Monitore tokens criados e e-mails enviados

### 9️⃣ Troubleshooting

#### ❌ Erro: "Firebase Admin SDK não inicializado"

**Solução:**
- Verifique se adicionou `FIREBASE_SERVICE_ACCOUNT` no Railway
- Confirme que o JSON está completo (começa com `{` e termina com `}`)
- Tente redeployar: Settings → Redeploy

#### ❌ Erro: "Invalid service account"

**Solução:**
- O JSON pode estar malformado
- Copie novamente do Firebase Console
- Certifique-se de não ter espaços extras ou quebras de linha

#### ❌ E-mails não chegam

**Solução:**
- Verifique pasta de spam
- Configure SMTP customizado (passo 4)
- Veja logs no Firebase Console
- Verifique collection `emailLogs` no Firestore

#### ❌ Erro 503: Service Unavailable

**Solução:**
- O Railway pode estar iniciando (aguarde 1-2 minutos)
- Verifique logs no Railway
- Confirme que `package.json` tem todas as dependências

### 🎯 Checklist Final

- [ ] Firebase Service Account configurado no Railway
- [ ] Backend rodando (URL abre e mostra `firebaseInitialized: true`)
- [ ] Templates de e-mail configurados no Firebase
- [ ] URL do Railway atualizada no Flutter (`email_token_service.dart`)
- [ ] Teste de envio de token funcionando
- [ ] E-mails chegando na caixa de entrada
- [ ] Collections criadas no Firestore

### 📞 Suporte

Se ainda tiver problemas:

1. Verifique os logs no Railway (Deployments → View Logs)
2. Confira o Firestore (collections `activationTokens` e `emailLogs`)
3. Teste os endpoints com Postman ou cURL
4. Revise este guia do início

---

**Tudo configurado? Agora você tem um sistema completo de tokens por e-mail! 🎉**
