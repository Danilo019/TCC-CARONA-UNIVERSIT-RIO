# Configuração do Firebase e Microsoft Authentication

Este documento contém as instruções para configurar a autenticação Microsoft com Firebase no aplicativo Carona Universitária.

## 📋 Pré-requisitos

1. Conta no Google Firebase
2. Conta no Microsoft Azure AD
3. Projeto Flutter configurado
4. Android Studio / VS Code com Flutter SDK

## 🔥 Configuração do Firebase

### 1. Criar Projeto no Firebase

1. Acesse [Firebase Console](https://console.firebase.google.com/)
2. Clique em "Criar um projeto"
3. Digite o nome: "Carona Universitária"
4. Ative/desative o Google Analytics conforme necessário
5. Clique em "Criar projeto"

### 2. Adicionar Aplicativo Android

1. No painel do projeto, clique no ícone Android
2. Digite o nome do pacote: `com.example.app_carona_novo`
3. Apelido do app: `Carona Universitária`
4. Assinatura do certificado SHA-1 (opcional para desenvolvimento)
5. Clique em "Registrar app"

### 3. Baixar arquivo de configuração

1. Baixe o arquivo `google-services.json`
2. Coloque em `android/app/google-services.json`

### 4. Habilitar Authentication

1. No menu lateral, clique em "Authentication"
2. Clique em "Começar"
3. Vá para a aba "Sign-in method"
4. Clique em "Microsoft" e ative
5. Copie o Client ID e Client Secret do Microsoft Azure

## 🔐 Configuração do Microsoft Azure AD

### 1. Registrar Aplicativo no Azure

1. Acesse [Azure Portal](https://portal.azure.com/)
2. Vá para "Azure Active Directory"
3. Clique em "Registros de aplicativo"
4. Clique em "Novo registro"
5. Nome: "Carona Universitária"
6. Tipos de conta: "Contas neste diretório organizacional apenas"
7. URI de redirecionamento: `msauth://auth` (para Android)
8. Clique em "Registrar"

### 2. Configurar Permissões

1. No painel do aplicativo, vá para "Permissões de API"
2. Clique em "Adicionar uma permissão"
3. Selecione "Microsoft Graph"
4. Adicione as permissões:
   - `openid`
   - `profile`
   - `email`
   - `User.Read`
   - `offline_access`

### 3. Obter Credenciais

1. No painel do aplicativo, vá para "Visão geral"
2. Copie o "ID do aplicativo (cliente)"
3. Copie o "ID do diretório (locatário)"

## ⚙️ Configuração do Código

### 1. Atualizar Configurações

Edite o arquivo `lib/config/firebase_config.dart`:

```dart
class FirebaseConfig {
  // Substitua pelos valores reais do seu projeto
  static const String microsoftClientId = 'SEU_CLIENT_ID_REAL';
  static const String microsoftTenantId = 'SEU_TENANT_ID_REAL';
  
  // ... resto das configurações
}
```

### 2. Configurar Android

Edite o arquivo `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        applicationId "com.example.app_carona_novo"
        minSdkVersion 21
        targetSdkVersion 34
        // ... outras configurações
    }
}
```

### 3. Configurar Permissões

Adicione ao arquivo `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## 📱 Configuração Específica da UDF

### Domínios de Email Permitidos

O aplicativo está configurado para aceitar apenas emails dos domínios:
- `@udf.edu.br`
- `@cs.udf.edu.br`

### Validação Automática

O sistema automaticamente:
1. Autentica via Microsoft
2. Verifica se o email é da UDF
3. Permite acesso apenas para emails válidos da UDF

## 🚀 Testando a Autenticação

### 1. Executar o App

```bash
flutter run
```

### 2. Testar Login

1. Abra o aplicativo
2. Clique em "Entrar com E-mail Acadêmico"
3. Use um email da UDF para testar
4. Verifique se o login é bem-sucedido

### 3. Verificar Logs

Os logs de debug mostrarão:
- Inicialização do AuthService
- Tentativas de login
- Erros de autenticação
- Validação de email

## 🔧 Solução de Problemas

### Erro: "Client ID não encontrado"
- Verifique se o Client ID está correto no `firebase_config.dart`

### Erro: "Email não é da UDF"
- Confirme que o email usado termina com `@udf.edu.br` ou `@cs.udf.edu.br`

### Erro: "Firebase não inicializado"
- Verifique se o `google-services.json` está no local correto
- Confirme se o Firebase foi inicializado no `main.dart`

### Erro de Permissões
- Verifique se todas as permissões foram adicionadas no Azure AD
- Confirme se o aplicativo está registrado corretamente

## 📞 Suporte

Para problemas específicos da UDF:
- Entre em contato com o TI da universidade
- Verifique as configurações de Azure AD da instituição

## 📝 Notas Importantes

1. **Segurança**: Nunca commite credenciais reais no repositório
2. **Ambiente**: Use diferentes configurações para desenvolvimento e produção
3. **Testes**: Teste sempre com emails reais da UDF
4. **Backup**: Mantenha backup das configurações importantes

## 🔄 Próximos Passos

Após a configuração inicial:
1. Implementar logout automático
2. Adicionar refresh de token
3. Implementar cache de autenticação
4. Adicionar tratamento de erros específicos
5. Implementar recuperação de senha via Microsoft
