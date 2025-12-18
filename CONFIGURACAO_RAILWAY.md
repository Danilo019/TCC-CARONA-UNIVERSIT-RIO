# ⚙️ Configuração do Backend Railway

## 🚀 Status do Sistema

✅ **Backend atualizado** com endpoint `/api/send-token-email`  
✅ **Flutter integrado** - `EmailService` usa Railway automaticamente  
✅ **Índice Firestore** corrigido para queries de caronas do motorista  

---

## 📋 Configuração Necessária

### 1. Firebase Service Account no Railway

1. Baixe o JSON do Firebase:
   - https://console.firebase.google.com/
   - Projeto → ⚙️ Configurações → Contas de serviço
   - **Gerar nova chave privada**

2. No Railway (https://railway.app):
   - Seu projeto → Variables
   - **+ New Variable**
   - Nome: `FIREBASE_SERVICE_ACCOUNT`
   - Valor: Cole o JSON completo (em uma linha)

### 2. Configurar SMTP para Envio de E-mails (OBRIGATÓRIO)

**Sem isso, os e-mails NÃO serão enviados!**

#### Opção A: Gmail (Recomendado para teste)

1. Acesse: https://myaccount.google.com/apppasswords
2. Crie uma "Senha de app" (não use sua senha normal)
3. No Railway, adicione as variáveis com PLACEHOLDERS (não comite valores reais):

```
SMTP_SERVICE=gmail
SMTP_USER=<YOUR_GMAIL_ADDRESS>
SMTP_PASS=<YOUR_GMAIL_APP_PASSWORD>
```

#### Opção B: Outlook/Hotmail

```
SMTP_SERVICE=hotmail
SMTP_USER=<YOUR_HOTMAIL_ADDRESS>
SMTP_PASS=<YOUR_OUTLOOK_APP_PASSWORD>
```

#### Opção C: SMTP Customizado

```
SMTP_SERVICE=smtp
SMTP_HOST=<YOUR_SMTP_HOST>
SMTP_PORT=<YOUR_SMTP_PORT>
SMTP_USER=<YOUR_SMTP_USERNAME>
SMTP_PASS=<YOUR_SMTP_PASSWORD>
```

### 2. Deploy dos Índices Firestore

Execute para criar os índices necessários:

```powershell
firebase deploy --only firestore:indexes
```

Ou crie manualmente clicando no link do erro:
https://console.firebase.google.com/v1/r/project/carona-universitiaria/firestore/indexes

---

## 🧪 Testar Sistema

### Verificar se Backend está rodando:

```powershell
# PowerShell
$url = "https://tcc-carona-universit-rio-production.up.railway.app/"
Invoke-RestMethod -Uri $url
```

Deve retornar:
```json
{
  "status": "ok",
  "firebaseInitialized": true
}
```

### Testar envio de e-mail:

O app agora usa automaticamente o Railway. Basta:
1. Executar o app: `flutter run`
2. Tentar recuperar senha
3. Verificar logs no console

---

## 🐛 Solução de Problemas

### ❌ "Firebase Admin SDK não inicializado"
→ Configure `FIREBASE_SERVICE_ACCOUNT` no Railway

### ❌ "The query requires an index"
→ Execute: `firebase deploy --only firestore:indexes`

### ❌ E-mail não chega
→ Verifique:
1. Railway Dashboard → Logs
2. Firebase Console → Firestore → `emailLogs`
3. Pasta de spam

---

## 📊 Como Funciona Agora

1. **App solicita recuperação de senha**
2. **EmailService tenta Railway primeiro** (automático)
3. **Railway gera token de 6 dígitos**
4. **Firebase envia e-mail** via Authentication
5. **Usuário recebe e-mail** com código
6. **App valida código** via Railway

**Token:** 6 dígitos, válido por 30 minutos, uso único

---

## 🔗 Links Úteis

- **Railway Dashboard:** https://railway.app/dashboard
- **Firebase Console:** https://console.firebase.google.com/
- **Firestore Indexes:** https://console.firebase.google.com/project/carona-universitiaria/firestore/indexes

---

**Sistema configurado! Agora os e-mails serão enviados via Railway.** 📧✅

> Importante: Nunca commite credenciais reais em arquivos `.md`, `.env` ou código.
> Use variáveis de ambiente no Railway e mantenha somente exemplos com placeholders.
