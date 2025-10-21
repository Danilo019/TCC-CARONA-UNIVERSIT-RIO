# Guia Completo: Autenticação Microsoft no Flutter

## 📋 Índice
1. [Pré-requisitos](#pré-requisitos)
2. [Configuração no Azure AD](#configuração-no-azure-ad)
3. [Instalação de Dependências](#instalação-de-dependências)
4. [Configuração Android](#configuração-android)
5. [Configuração iOS](#configuração-ios)
6. [Implementação no Flutter](#implementação-no-flutter)
7. [Testando a Autenticação](#testando-a-autenticação)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 Pré-requisitos

Antes de começar, você precisa ter:
- ✅ Uma conta Azure (você pode usar a conta institucional da UDF)
- ✅ Acesso ao Azure Portal (https://portal.azure.com)
- ✅ Flutter instalado e configurado
- ✅ Android Studio ou Xcode configurados

---

## 1️⃣ Configuração no Azure AD

### Passo 1.1: Criar um App Registration no Azure

1. Acesse o [Azure Portal](https://portal.azure.com)
2. No menu lateral, procure por **"Azure Active Directory"** ou **"Microsoft Entra ID"**
3. Clique em **"App registrations"** (Registros de aplicativo)
4. Clique em **"+ New registration"** (Novo registro)

### Passo 1.2: Configurar o Registro

Preencha os campos:

- **Name**: `Carona Universitária - UDF`
- **Supported account types**: Selecione uma das opções:
  - `Accounts in this organizational directory only` (apenas UDF)
  - OU `Accounts in any organizational directory` (qualquer organização)
- **Redirect URI**: 
  - Platform: `Public client/native (mobile & desktop)`
  - URI: `msauth://auth`
  
Clique em **Register**

### Passo 1.3: Copiar as Credenciais

Após criar, você verá a página do app. Copie:

1. **Application (client) ID** - exemplo: `12345678-1234-1234-1234-123456789012`
2. **Directory (tenant) ID** - exemplo: `87654321-4321-4321-4321-210987654321`

**⚠️ IMPORTANTE**: Guarde esses valores, você vai precisar deles!

### Passo 1.4: Configurar Redirect URIs

1. No menu lateral do seu app, clique em **"Authentication"**
2. Em **"Platform configurations"**, clique em **"Add a platform"**
3. Selecione **"Android"**
   - Package name: `com.example.app_carona_novo` (verifique no AndroidManifest.xml)
   - Signature hash: Vamos gerar isso depois
4. Selecione **"iOS/macOS"**
   - Bundle ID: Copie do seu `Info.plist` (geralmente algo como `com.example.appCaronaNovo`)

### Passo 1.5: Configurar Permissões (API Permissions)

1. No menu lateral, clique em **"API permissions"**
2. Clique em **"+ Add a permission"**
3. Selecione **"Microsoft Graph"**
4. Selecione **"Delegated permissions"**
5. Adicione as seguintes permissões:
   - ✅ `User.Read` (ler perfil do usuário)
   - ✅ `email` (acessar email)
   - ✅ `openid` (autenticação básica)
   - ✅ `profile` (perfil básico)
   - ✅ `offline_access` (refresh tokens)
6. Clique em **"Add permissions"**
7. Clique em **"Grant admin consent for [Nome da Organização]"** (se tiver permissão)

---

## 2️⃣ Instalação de Dependências

### Passo 2.1: Adicionar o pacote MSAL

Edite o arquivo `pubspec.yaml` e descomente/adicione:

```yaml
dependencies:
  # ... outras dependências ...
  
  # Microsoft Authentication
  msal_flutter: ^4.0.0
  
  # Útil para URLs
  url_launcher: ^6.2.1
```

### Passo 2.2: Instalar as dependências

```bash
flutter pub get
```

---

## 3️⃣ Configuração Android

### Passo 3.1: Gerar o Signature Hash

Abra o terminal e execute:

```bash
# Para debug (desenvolvimento)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Para release (produção) - se você já tiver um keystore
keytool -list -v -keystore caminho/para/seu/keystore.jks -alias seu_alias
```

Copie o **SHA-1** que aparecer. Exemplo:
```
SHA1: A1:B2:C3:D4:E5:F6:G7:H8:I9:J0:K1:L2:M3:N4:O5:P6:Q7:R8:S9:T0
```

### Passo 3.2: Converter SHA-1 para Signature Hash

Use este site ou ferramenta para converter:
- Site: https://tomeko.net/online_tools/hex_to_base64.php
- Remova os `:` do SHA-1
- Converta de HEX para Base64

Ou use este comando Python:
```python
import base64
import binascii

sha1 = "A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0"  # Sem os ":"
signature_hash = base64.b64encode(binascii.unhexlify(sha1)).decode()
print(signature_hash)
```

### Passo 3.3: Adicionar o Signature Hash no Azure

Volte ao Azure Portal > seu app > Authentication > Android > adicione o Signature Hash

### Passo 3.4: Configurar AndroidManifest.xml

Abra `android/app/src/main/AndroidManifest.xml` e adicione dentro de `<application>`:

```xml
<activity
    android:name="com.microsoft.identity.client.BrowserTabActivity">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:scheme="msauth"
            android:host="com.carona.universitaria"
            android:path="df/WrQM67qwAZFa/4i5uTORfZgI=" />
    </intent-filter>
</activity>
```

**Substitua**:
- `com.example.app_carona_novo` pelo seu package name
- `SEU_SIGNATURE_HASH_AQUI` pelo signature hash gerado

### Passo 3.5: Atualizar build.gradle

Abra `android/app/build.gradle.kts` e verifique se tem:

```kotlin
android {
    defaultConfig {
        minSdk = 21  // MSAL precisa de no mínimo 21
    }
}
```

---

## 4️⃣ Configuração iOS

### Passo 4.1: Configurar Info.plist

Abra `ios/Runner/Info.plist` e adicione antes de `</dict>`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msauth.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        </array>
    </dict>
</array>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>msauthv2</string>
    <string>msauthv3</string>
</array>
```

### Passo 4.2: Verificar versão mínima do iOS

✅ **PRONTO!** O arquivo `ios/Podfile` já foi criado com a versão correta (iOS 12.0)

### Passo 4.3: Instalar CocoaPods

⚠️ **ATENÇÃO WINDOWS**: Este passo só é necessário se você estiver em um Mac. No Windows, pule esta etapa e foque no Android.

```bash
# Execute apenas em Mac/macOS
cd ios
pod install
cd ..
```

---

## 5️⃣ Implementação no Flutter

### Passo 5.1: Atualizar firebase_config.dart

Atualize com suas credenciais reais do Azure:

```dart
// Configurações do Microsoft Azure AD
static const String microsoftClientId = 'SEU_CLIENT_ID_AQUI';  // Application (client) ID
static const String microsoftTenantId = 'SEU_TENANT_ID_AQUI';  // Directory (tenant) ID
// OU use 'organizations' para aceitar qualquer org
// OU use 'common' para aceitar qualquer conta Microsoft

static const String microsoftRedirectUri = 'msauth://com.example.app_carona_novo/SIGNATURE_HASH';
```

**Opções de tenantId**:
- `'organizations'` - Qualquer conta organizacional (Azure AD)
- `'common'` - Qualquer conta Microsoft (pessoal ou organizacional)
- `'consumers'` - Apenas contas pessoais Microsoft
- `'SEU_TENANT_ID'` - Apenas sua organização específica (UDF)

### Passo 5.2: Criar arquivo de configuração MSAL

Crie `lib/config/msal_config.dart`:

```dart
import 'package:msal_flutter/msal_flutter.dart';
import 'firebase_config.dart';

class MsalConfig {
  static MsalFlutter? _msalFlutter;

  static Future<MsalFlutter> getInstance() async {
    if (_msalFlutter != null) return _msalFlutter!;

    _msalFlutter = await MsalFlutter.create(
      clientId: FirebaseConfig.microsoftClientId,
      authority: 'https://login.microsoftonline.com/${FirebaseConfig.microsoftTenantId}',
      // OU para UDF especificamente, se souber o domínio:
      // authority: 'https://login.microsoftonline.com/udf.edu.br',
    );

    return _msalFlutter!;
  }

  static Future<void> dispose() async {
    _msalFlutter = null;
  }
}
```

### Passo 5.3: Atualizar auth_service.dart

Substitua o método `signInWithMicrosoft()`:

```dart
import 'package:msal_flutter/msal_flutter.dart';
import '../config/msal_config.dart';

class AuthService {
  // ... resto do código ...
  
  MsalFlutter? _msalFlutter;

  /// Inicializa o MSAL
  Future<void> _initializeMsal() async {
    if (_msalFlutter == null) {
      _msalFlutter = await MsalConfig.getInstance();
    }
  }

  /// Realiza login com Microsoft
  Future<User?> signInWithMicrosoft() async {
    try {
      // Inicializa MSAL
      await _initializeMsal();

      if (_msalFlutter == null) {
        throw Exception('MSAL não inicializado');
      }

      // Tenta pegar token silenciosamente primeiro (se já logou antes)
      String? accessToken;
      try {
        accessToken = await _msalFlutter!.acquireTokenSilent(
          scopes: _scopes,
        );
        if (kDebugMode) {
          print('Token obtido silenciosamente');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Token silencioso falhou, abrindo navegador: $e');
        }
      }

      // Se não conseguiu token silencioso, abre navegador
      if (accessToken == null) {
        accessToken = await _msalFlutter!.acquireToken(
          scopes: _scopes,
          loginHint: null, // Pode passar um email como hint
        );
      }

      if (accessToken == null) {
        throw Exception('Não foi possível obter token de acesso');
      }

      // Pega informações do usuário
      final account = await _msalFlutter!.getAccount();
      
      if (account == null) {
        throw Exception('Não foi possível obter informações da conta');
      }

      final email = account.username; // Email do usuário

      if (kDebugMode) {
        print('Login Microsoft bem-sucedido');
        print('Email: $email');
        print('Nome: ${account.name}');
      }

      // Agora você precisa autenticar no Firebase com um custom token
      // Ou criar/buscar o usuário no seu backend
      
      // OPÇÃO 1: Se você tiver um backend, envie o accessToken para ele
      // e ele retorna um Firebase custom token
      
      // OPÇÃO 2: Criar usuário no Firebase com email/senha gerado
      // (menos seguro, mas funcional para protótipo)
      
      // Por enquanto, vamos simular que criamos/logamos o usuário
      final firebaseUser = await _signInOrCreateFirebaseUser(email, account.name);
      
      return firebaseUser;
      
    } catch (e) {
      if (kDebugMode) {
        print('Erro no login com Microsoft: $e');
      }
      rethrow;
    }
  }

  /// Cria ou faz login de usuário no Firebase
  /// NOTA: Isso é uma solução temporária. O ideal é ter um backend.
  Future<User?> _signInOrCreateFirebaseUser(String email, String? displayName) async {
    try {
      // Tenta fazer login com senha padrão (não seguro, mas funcional)
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: 'microsoft_auth_temp_password_${email.hashCode}',
      );
      
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        // Cria novo usuário
        try {
          final credential = await _firebaseAuth.createUserWithEmailAndPassword(
            email: email,
            password: 'microsoft_auth_temp_password_${email.hashCode}',
          );
          
          // Atualiza display name
          if (displayName != null && credential.user != null) {
            await credential.user!.updateDisplayName(displayName);
          }
          
          return credential.user;
        } catch (createError) {
          if (kDebugMode) {
            print('Erro ao criar usuário Firebase: $createError');
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  /// Realiza logout
  Future<void> signOut() async {
    try {
      // Logout do Firebase
      await _firebaseAuth.signOut();
      
      // Logout do Microsoft
      if (_msalFlutter != null) {
        await _msalFlutter!.signOut();
      }

      if (kDebugMode) {
        print('Logout realizado com sucesso');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro no logout: $e');
      }
      rethrow;
    }
  }

  /// Limpa cache de autenticação
  Future<void> clearCache() async {
    try {
      if (_msalFlutter != null) {
        // Remove todas as contas
        final accounts = await _msalFlutter!.getAccounts();
        for (final account in accounts) {
          await _msalFlutter!.removeAccount(account: account);
        }
      }
      
      if (kDebugMode) {
        print('Cache limpo');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao limpar cache: $e');
      }
    }
  }
}
```

---

## 6️⃣ Testando a Autenticação

### Passo 6.1: Testar no Android

```bash
flutter run -d android
```

1. Clique no botão de login Microsoft
2. Deve abrir o navegador
3. Faça login com sua conta @udf.edu.br
4. Aceite as permissões solicitadas
5. Deve redirecionar de volta para o app

### Passo 6.2: Testar no iOS

```bash
flutter run -d ios
```

Mesmo processo do Android.

### Passo 6.3: Verificar logs

Preste atenção nos logs do console para ver se há erros.

---

## 7️⃣ Melhorias e Próximos Passos

### Backend para Custom Tokens (RECOMENDADO)

O método acima usa uma senha gerada para criar usuários no Firebase, o que não é ideal para produção.

**Solução profissional**:

1. Crie um backend (Node.js, Python, etc.)
2. No app, envie o `accessToken` do Microsoft para seu backend
3. No backend:
   ```javascript
   // Exemplo Node.js
   const admin = require('firebase-admin');
   
   app.post('/auth/microsoft', async (req, res) => {
     const { accessToken } = req.body;
     
     // Valida o token com Microsoft Graph API
     const userInfo = await fetch('https://graph.microsoft.com/v1.0/me', {
       headers: { 'Authorization': `Bearer ${accessToken}` }
     });
     
     const userData = await userInfo.json();
     
     // Cria custom token do Firebase
     const firebaseToken = await admin.auth().createCustomToken(userData.mail);
     
     res.json({ firebaseToken });
   });
   ```
4. No app, use esse custom token para fazer login no Firebase:
   ```dart
   await _firebaseAuth.signInWithCustomToken(firebaseToken);
   ```

### Renovação automática de tokens

Adicione lógica para renovar tokens quando expirarem:

```dart
Future<String?> getValidToken() async {
  try {
    return await _msalFlutter!.acquireTokenSilent(scopes: _scopes);
  } catch (e) {
    // Token expirou, precisa fazer login novamente
    return await _msalFlutter!.acquireToken(scopes: _scopes);
  }
}
```

---

## 8️⃣ Troubleshooting

### Erro: "AADSTS50011: No reply address is registered"

**Solução**: Verifique se o redirect URI no Azure está correto:
- Deve ser `msauth://com.example.app_carona_novo/SIGNATURE_HASH`
- O signature hash deve estar correto

### Erro: "Package name e signature hash não correspondem"

**Solução**: 
1. Verifique o package name no AndroidManifest.xml
2. Regenere o signature hash
3. Atualize no Azure Portal

### App não redireciona após login

**Solução**:
1. Verifique o AndroidManifest.xml (Android)
2. Verifique o Info.plist (iOS)
3. Certifique-se que o URL scheme está correto

### Erro: "MsalUiRequiredException"

**Solução**: É normal na primeira vez. Significa que precisa abrir o navegador para fazer login.

### Erro ao compilar Android

**Solução**:
1. Verifique se `minSdk` é pelo menos 21
2. Execute `flutter clean && flutter pub get`
3. Execute `cd android && ./gradlew clean && cd ..`

### Erro ao compilar iOS

**Solução**:
1. Execute `cd ios && pod deintegrate && pod install && cd ..`
2. Limpe o build no Xcode: Product > Clean Build Folder
3. Certifique-se que a versão mínima do iOS é 12.0+

---

## 📚 Recursos Úteis

- [Documentação MSAL Flutter](https://pub.dev/packages/msal_flutter)
- [Azure AD Documentation](https://docs.microsoft.com/en-us/azure/active-directory/)
- [Microsoft Graph API](https://docs.microsoft.com/en-us/graph/)
- [Firebase Custom Auth](https://firebase.google.com/docs/auth/admin/create-custom-tokens)

---

## ✅ Checklist Final

- [ ] App registrado no Azure AD
- [ ] Client ID e Tenant ID copiados
- [ ] Redirect URIs configurados
- [ ] Permissões adicionadas no Azure
- [ ] Signature hash gerado e adicionado
- [ ] `msal_flutter` instalado
- [ ] AndroidManifest.xml configurado
- [ ] Info.plist configurado (iOS)
- [ ] firebase_config.dart atualizado com credenciais reais
- [ ] AuthService implementado com MSAL
- [ ] Testado no dispositivo/emulador
- [ ] Login funciona corretamente
- [ ] Logout funciona corretamente
- [ ] Email validado como @udf.edu.br

---

## 📌 **Informações Específicas do Seu Projeto**

### IDs do Projeto:
- **Android Package Name**: `com.carona.universitaria`
- **iOS Bundle ID**: `com.example.appCaronaNovo`

### Arquivos já configurados: ✅
- ✅ `ios/Podfile` - Criado com iOS 12.0
- ✅ `ios/Runner/Info.plist` - Configurado para Microsoft Auth
- ✅ `android/app/src/main/AndroidManifest.xml` - Configurado para Microsoft Auth (aguardando signature hash)

### Próximos passos (Windows - foco em Android):
1. ⚠️ **Pule as etapas de iOS/CocoaPods** (você está no Windows)
2. Execute no PowerShell: `flutter build apk --debug` (para gerar o keystore)
3. Execute no PowerShell: `keytool -list -v -keystore C:\Users\Danil\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android`
4. Copie o SHA1
5. Converta SHA1 para Base64 (signature hash)
6. Substitua `/SEU_SIGNATURE_HASH_AQUI` no AndroidManifest.xml
7. Configure no Azure Portal com **apenas Android** por enquanto
8. Adicione suas credenciais em `lib/config/firebase_config.dart`
9. Teste no emulador/dispositivo Android

---

**Pronto!** 🎉 Agora você tem autenticação Microsoft funcionando no seu app!

Se tiver dúvidas ou erros, consulte a seção de Troubleshooting ou me avise!

