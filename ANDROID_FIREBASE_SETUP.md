# 🔧 Configuração do Firebase para Android

## ✅ Configuração Implementada

### 1. **Arquivo build.gradle.kts (nível do projeto)**
```kotlin
plugins {
    // Add the dependency for the Google services Gradle plugin
    id("com.google.gms.google-services") version "4.4.4" apply false
}
```

### 2. **Arquivo build.gradle.kts (nível do app)**
```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.4.0"))
    
    // Firebase Analytics
    implementation("com.google.firebase:firebase-analytics")
    
    // Firebase Authentication
    implementation("com.google.firebase:firebase-auth")
    
    // Firebase Core
    implementation("com.google.firebase:firebase-core")
}
```

## 📋 Próximos Passos

### **Passo 1: Criar Projeto no Firebase**
1. Acesse [Firebase Console](https://console.firebase.google.com/)
2. Clique em "Criar um projeto"
3. Nome: "Carona Universitária UDF"
4. Ative o Google Analytics (opcional)

### **Passo 2: Adicionar App Android**
1. No painel do projeto, clique no ícone Android
2. **Nome do pacote**: `com.example.app_carona_novo`
3. **Apelido do app**: `Carona Universitária`
4. **Assinatura do certificado SHA-1**: (opcional para desenvolvimento)
5. Clique em "Registrar app"

### **Passo 3: Baixar google-services.json**
1. Baixe o arquivo `google-services.json`
2. **IMPORTANTE**: Coloque em `android/app/google-services.json`
3. **NÃO** coloque em `android/google-services.json`

### **Passo 4: Habilitar Authentication**
1. No menu lateral, clique em "Authentication"
2. Clique em "Começar"
3. Vá para a aba "Sign-in method"
4. Clique em "Microsoft" e ative
5. Configure com suas credenciais do Azure AD

## 🔍 Verificação da Configuração

### **Estrutura de Arquivos Correta:**
```
android/
├── build.gradle.kts ✅ (configurado)
└── app/
    ├── build.gradle.kts ✅ (configurado)
    └── google-services.json ⏳ (você precisa baixar)
```

### **Verificar se está funcionando:**
```bash
# Navegar para o diretório do projeto
cd "C:\Users\Danil\OneDrive\Área de Trabalho\tcc_carona\TCC-CARONA-UNIVERSIT-RIO"

# Limpar e sincronizar
flutter clean
flutter pub get

# Executar o app
flutter run
```

## 🚨 Problemas Comuns

### **Erro: "google-services.json not found"**
- Verifique se o arquivo está em `android/app/google-services.json`
- Não está em `android/google-services.json`

### **Erro: "Plugin not found"**
- Verifique se adicionou o plugin no `build.gradle.kts`
- Execute `flutter clean` e `flutter pub get`

### **Erro: "Package name mismatch"**
- Verifique se o package name no Firebase é `com.example.app_carona_novo`
- Deve ser igual ao `applicationId` no `build.gradle.kts`

## 📱 Testando a Configuração

### **1. Verificar se o Firebase está funcionando:**
```dart
// No seu código Flutter
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}
```

### **2. Testar Authentication:**
```dart
// Teste básico de autenticação
import 'package:firebase_auth/firebase_auth.dart';

FirebaseAuth auth = FirebaseAuth.instance;
// Teste de conectividade
```

## 🔧 Configurações Adicionais

### **Para Produção:**
1. **Mudar package name** para algo único (ex: `com.udf.carona`)
2. **Configurar signing** para release
3. **Adicionar SHA-1** do certificado de produção

### **Para Desenvolvimento:**
1. **Usar package name** atual: `com.example.app_carona_novo`
2. **SHA-1 do debug** (opcional)
3. **Testar com emulador** ou dispositivo físico

## 📞 Suporte

Se encontrar problemas:
1. Verifique se o `google-services.json` está no local correto
2. Confirme se o package name está igual no Firebase e no código
3. Execute `flutter clean` e `flutter pub get`
4. Verifique se o Firebase está ativo no console

---

**Após baixar o google-services.json, execute `flutter run` para testar!**

