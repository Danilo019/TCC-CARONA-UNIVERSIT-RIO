# Carona Universitária UDF 🚗

> Mobilidade colaborativa, segura e sustentável para a comunidade acadêmica.

<div align="center">
  <img src="assets/images/logo_carona_universitária.png" alt="Logo Carona Universitária" width="140"/>
</div>

## 📋 Visão Geral

O **Carona Universitária UDF** é um aplicativo Flutter que conecta estudantes, professores e colaboradores para compartilhamento solidário de caronas. Focado em **segurança**, **sustentabilidade** e **economia**, reduzindo trânsito e emissão de CO₂.

**Status atual** (parcialmente implementado):
- ✅ Autenticação (Firebase Auth)
- ✅ Perfil do usuário e edição básica
- ✅ Histórico de viagens
- ✅ Criação/listagem de caronas (motorista / passageiro)
- ✅ Geolocalização + Google Maps / Distance Matrix
- ✅ Chat interno (mensagens) e contador de não lidas
- ✅ Notificações (Firebase Messaging)
- ✅ Exclusão definitiva de conta (LGPD)
- 🚧 Sistema de avaliação / reputação
- 🚧 Recomendações inteligentes
- 🚧 Melhorias em acessibilidade e internacionalização

## 🎯 Principais Funcionalidades

- Cadastro validado e seguro (domínio institucional)
- Geolocalização para encontrar e exibir caronas no mapa
- Canal de mensagens interno
- Histórico de viagens
- Notificações push
- Exclusão de conta (Direito ao Esquecimento / LGPD)
- Estrutura preparada para avaliações e reputação

## 🧱 Arquitetura / Estrutura

```
lib/
  core/           # Helpers e infra comum
  features/       # Módulos funcionais
  screens/        # Telas principais (home, perfil, viagens...)
  widgets/        # Componentes reutilizáveis
  services/       # Integrações (Firebase, Maps, localização)
  providers/      # Estado (Provider)
  models/         # Modelos de domínio
backend/
  server.js       # API Node (reset de senha)
  package.json    # Dependências backend
android/          # Configuração Android / build / keystore
ios/              # Projeto iOS (in progress)
```

## 🛠️ Tecnologias

| Categoria | Stack |
|-----------|-------|
| Mobile | Flutter (Dart) |
| Backend | Node.js + Express |
| Auth / Dados | Firebase Auth, Firestore, Storage, Functions |
| Push | Firebase Cloud Messaging + flutter_local_notifications |
| Mapas | google_maps_flutter + Distance Matrix API |
| Localização | geolocator + permission_handler |
| Estado | Provider |
| Compartilhamento | share_plus |
| Persistência local | shared_preferences |
| Build Infra | Railway (Nixpacks) |
| Versionamento | Git + GitHub |

## � Requisitos

| Item | Versão recomendada |
|------|--------------------|
| Flutter SDK | 3.35.x |
| Dart | 3.9.x |
| Android SDK | API 21+ (min) |
| Node.js (backend) | 18.x |
| Firebase Project | Criado em console.firebase.google.com |

## 🚀 Instalação (Frontend)

```bash
git clone https://github.com/Danilo019/TCC-CARONA-UNIVERSIT-RIO.git
cd TCC-CARONA-UNIVERSIT-RIO
flutter pub get
flutter run
```

Se necessário gerar novamente `firebase_options.dart`:
```bash
flutter pub add firebase_core
flutterfire configure
```

## 🌐 Backend (Reset de Senha)

```bash
cd backend
npm install
# Variáveis de ambiente:
# FIREBASE_SERVICE_ACCOUNT (JSON string) OU FIREBASE_PROJECT_ID
npm start
```

Endpoints:
- `GET /` Health check
- `POST /api/reset-password` Redefinição de senha com token + email

## 🔐 Variáveis de Ambiente (Exemplo .env)

```
GOOGLE_MAPS_API_KEY=SEU_TOKEN_AQUI
FIREBASE_WEB_API_KEY=SEU_TOKEN_AQUI
FIREBASE_PROJECT_ID=carona-udf
```

Backend (Railway):
```
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"..."}
```

## 📲 Build Android

Gerar APK universal:
```bash
flutter build apk --release
```

Split por ABI (menor tamanho):
```bash
flutter build apk --release --split-per-abi
```

App Bundle (Play Store):
```bash
flutter build appbundle --release
```

Keystore (exemplo Windows):
```bash
keytool -genkey -v -keystore C:\chaves\carona-release.keystore -alias carona_release -keyalg RSA -keysize 2048 -validity 10000
```

Arquivo `android/key.properties` (não versionar):
```
storePassword=MINHA_SENHA
keyPassword=MINHA_SENHA
keyAlias=carona_release
storeFile=C:/chaves/carona-release.keystore
```

## 🧪 Testes

```bash
flutter test
```

## 🛡️ Segurança & Privacidade

- Senhas armazenadas pelo Firebase Auth
- Tokens temporários para reset de senha
- Exclusão definitiva de conta remove registros pessoais
- Restrições de email institucional (@cs.udf.edu.br)
- Uso de HTTPS via Firebase / Railway

## �️ Roadmap

- [ ] Sistema de avaliação/reputação
- [ ] Recomendação inteligente de caronas
- [ ] Internacionalização (i18n)
- [ ] Suporte iOS produção / TestFlight
- [ ] Dark mode refinado
- [ ] Monitoramento de performance (Firebase Performance)

## 🤝 Contribuição

1. Fork & branch: `feature/nova-feature`
2. Commits seguindo convenção: `feat:`, `fix:`, `chore:`, `docs:`
3. Pull Request descrevendo contexto, prints, testes
4. Código analisado por lint (`flutter analyze` / `flutter test`)

## 📄 Licença

Este projeto está licenciado sob os termos do arquivo `LICENSE`.

## 👥 Autores

- **Danilo Teodoro dos Santos Silva**
- **Victor Kardec de Mello**

## 🎓 Instituição

**Universidade do Distrito Federal (UDF)**

---

<div align="center">
  <strong>Mobilidade acadêmica consciente</strong><br/>
  Feito com ❤️ usando Flutter
</div>