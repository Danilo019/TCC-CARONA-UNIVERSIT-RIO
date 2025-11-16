# 🔧 Corrigir Erro: Railpack não detecta o projeto

## ❌ Erro

```
⚠ Script start.sh not found
✖ Railpack could not determine how to build the app.
```

**Problema**: O Railway está usando o sistema antigo "Railpack" em vez de "Nixpacks".

## ✅ Solução

### Opção 1: Forçar Nixpacks via arquivo (Recomendado)

Criei o arquivo `railway.toml` na raiz do projeto que força o Railway a usar Nixpacks.

**Passos:**

1. **Faça commit e push** dos arquivos:
   ```bash
   git add railway.toml backend/
   git commit -m "Configure Railway for Node.js backend"
   git push
   ```

2. **No Railway**, vá em **Settings** → **Deploy**

3. **Configure manualmente** (se necessário):
   - **Build Command**: `cd backend && npm install`
   - **Start Command**: `cd backend && npm start`

### Opção 2: Configurar Root Directory no Railway

1. No Railway, vá em **Settings** → **Source**
2. Procure por **"Root Directory"** ou **"Working Directory"**
3. Configure como: `backend`
4. Salve

### Opção 3: Criar Serviço Separado

Se ainda não funcionar:

1. **Delete o serviço atual** no Railway
2. **Crie um novo serviço**
3. Conecte ao mesmo repositório
4. **IMPORTANTE**: Ao criar, selecione **"Deploy from GitHub repo"**
5. Quando perguntar sobre a pasta, selecione ou digite: `backend`
6. Configure a variável `FIREBASE_SERVICE_ACCOUNT`
7. Faça deploy

## 📋 Arquivos Criados

- ✅ `railway.toml` (raiz) - Configura Railway para usar Nixpacks
- ✅ `backend/nixpacks.toml` - Configuração do Nixpacks
- ✅ `backend/package.json` - Define script `start`
- ✅ `backend/server.js` - Servidor Node.js

## 🔍 Verificar Build

Após configurar, o build deve mostrar:

```
✓ Installing dependencies...
✓ Building...
✓ Starting server...
```

Em vez de:
```
✖ Railpack could not determine...
```

## ⚠️ Se Ainda Falhar

Tente criar um **serviço completamente novo** no Railway:

1. No dashboard do Railway, clique em **"New Project"**
2. Selecione **"Deploy from GitHub repo"**
3. Escolha seu repositório
4. **IMPORTANTE**: Na tela de configuração, procure por **"Root Directory"** ou **"Working Directory"**
5. Configure como: `backend`
6. Configure `FIREBASE_SERVICE_ACCOUNT` em Variables
7. Deploy

---

**Status**: ✅ Arquivo `railway.toml` criado - faça commit e push, depois configure Root Directory

