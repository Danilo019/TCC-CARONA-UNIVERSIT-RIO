# 📍 Como Configurar Root Directory no Railway

## 🎯 Passo a Passo Visual

### 1. Na Tela de Settings

Você está na tela de **Settings** do projeto `TCC-CARONA-UNIVERSIT-RIO`.

### 2. Encontrar a Seção "Source Repo"

Na página de Settings, procure pela seção **"Source Repo"**.

Você verá:
- Repositório conectado: `Danilo019/TCC-CARONA-UNIVERSIT-RIO`
- Botões: "Edit" e "Disconnect"

### 3. Adicionar Root Directory

**Logo abaixo** do repositório conectado, você verá um link que diz:

**"Add Root Directory (used for build and deploy steps. Docs)"**

1. **Clique neste link** "Add Root Directory"
2. Um campo de texto aparecerá
3. Digite: `backend`
4. **Salve** ou pressione Enter

### 4. Verificar se Funcionou

Após adicionar, você verá algo como:

```
Root Directory: backend
```

Com um botão de editar ao lado.

## 🔍 Se Não Aparecer o Link

Se você não ver o link "Add Root Directory", tente:

### Opção 1: Clicar em "Edit" ao lado do Repositório

1. Clique no ícone de **"Edit"** (lápis) ao lado do repositório
2. Procure por "Root Directory" nas opções
3. Configure como `backend`

### Opção 2: Ir em "Build" Settings

Na barra lateral direita, clique em **"Build"**:

1. Procure por **"Root Directory"** ou **"Working Directory"**
2. Configure como `backend`
3. Salve

### Opção 3: Configurar via Variável de Ambiente

Se ainda não aparecer, podemos configurar via arquivo de configuração:

1. Crie um arquivo `railway.toml` na raiz do projeto (já criado)
2. Ou configure via código no Railway

## 📝 Alternativa: Configurar via Arquivo

Se preferir, podemos criar um arquivo de configuração que o Railway detecta automaticamente.

---

**Status**: ✅ Clique no link "Add Root Directory" logo abaixo do repositório conectado

