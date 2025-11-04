# 🔧 Corrigir Erro no Railway

## ❌ Erro Encontrado

```
X Railpack não conseguiu determinar como construir o aplicativo
X No start command was found
```

## ✅ Solução

### 1. Configurar Root Directory no Railway

No Railway, vá em **Settings** → **Source**:

1. Clique em **"Configure"** ao lado de "Root Directory"
2. Defina como: `backend`
3. Salve

### 2. Adicionar Arquivo de Configuração

Já criamos o arquivo `backend/nixpacks.toml` que especifica:
- Node.js 18
- Comando de build: `npm install`
- Comando de start: `node server.js`

### 3. Verificar Variável de Ambiente

Certifique-se de que a variável `FIREBASE_SERVICE_ACCOUNT` está configurada:

1. Vá em **Variables** no Railway
2. Verifique se `FIREBASE_SERVICE_ACCOUNT` existe
3. O valor deve ser o **JSON completo** do Service Account

**Como copiar o JSON corretamente:**

Você tem o arquivo: `carona-universitiaria-firebase-adminsdk-fbsvc-10185ad2cf.json`

1. Abra o arquivo
2. Selecione **TODO** o conteúdo (Ctrl+A)
3. Copie (Ctrl+C)
4. No Railway, cole no valor da variável `FIREBASE_SERVICE_ACCOUNT`
5. **Importante**: O JSON deve estar em uma linha só, sem quebras

### 4. Redeploy

Após configurar:

1. Vá em **Deployments**
2. Clique nos três pontos (...) do último deploy
3. Selecione **"Redeploy"**

OU

1. Faça um pequeno commit e push para o GitHub
2. Railway fará deploy automático

## 📋 Checklist

- [ ] Root Directory configurado como `backend`
- [ ] Arquivo `backend/nixpacks.toml` existe (já criado)
- [ ] Variável `FIREBASE_SERVICE_ACCOUNT` configurada com JSON completo
- [ ] Redeploy realizado
- [ ] Deploy bem-sucedido (verifique logs)

## 🔍 Verificar se Funcionou

Após o deploy, verifique:

1. **Logs do Deploy** devem mostrar:
   ```
   ✓ Firebase Admin SDK inicializado com sucesso
   🚀 Servidor rodando na porta 3000
   ```

2. **Teste a URL:**
   Acesse: `https://seu-app.railway.app/`
   
   Deve retornar:
   ```json
   {
     "status": "ok",
     "service": "Carona Universitária - Password Reset API",
     "firebaseInitialized": true
   }
   ```

## ⚠️ Se Ainda Não Funcionar

### Opção 1: Configurar Manualmente

1. No Railway, vá em **Settings** → **Deploy**
2. Configure:
   - **Build Command:** `cd backend && npm install`
   - **Start Command:** `cd backend && npm start`

### Opção 2: Verificar Estrutura

Certifique-se de que a estrutura está assim:
```
projeto/
  backend/
    server.js
    package.json
    nixpacks.toml
    ...
```

---

**Status**: ✅ Arquivos de configuração criados - configure o Root Directory e faça redeploy

