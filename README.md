# Carona Universitária UDF 🚗

> Mobilidade colaborativa, segura e sustentável para a comunidade acadêmica.

<div align="center">
  <img src="assets/images/logo_carona_universitária.png" alt="Logo Carona Universitária" width="140"/>
</div>

## 📋 Visão Geral

O **Carona Universitária UDF** é um aplicativo Flutter que conecta estudantes, professores e colaboradores para compartilhamento solidário de caronas. Focado em **segurança**, **sustentabilidade** e **economia**, reduzindo trânsito e emissão de CO₂


# 🚗 TCC - Carona Universitária

Aplicativo mobile de compartilhamento de caronas para estudantes universitários, desenvolvido com **Flutter** e **Firebase**, com backend em **Node.js** hospedado na **Railway**.

---

## ✨ Principais Funcionalidades

- 🔐 **Autenticação Segura**: Firebase Auth + Sistema de verificação por email token (Railway)
- 👤 **Perfil de Usuário**: Edição de dados pessoais e foto de perfil
- 🚗 **Caronas**: Criar, listar e gerenciar caronas como motorista ou passageiro
- 📍 **Geolocalização**: Integração com Google Maps e Distance Matrix
- 💬 **Chat Interno**: Sistema de mensagens entre usuários em tempo real
- 🔔 **Notificações**: Push notifications via Firebase Messaging
- ⭐ **Sistema de Avaliações**: Avaliar usuários e visualizar reputação
- 🎯 **Onboarding Interativo**: Fluxo de boas-vindas com animações
- 📋 **Termos & Privacidade**: Consentimento LGPD integrado
- 🗑️ **Exclusão de Conta**: Deletar dados em conformidade com LGPD
- 🔐 **Segurança**: Criptografia de dados sensíveis e validação robusta

---

## 🛠️ Tecnologias

| Camada | Tecnologia | Versão |
|--------|-----------|--------|
| Frontend | Flutter | ^3.0.0 |
| Backend | Node.js + Express | ^18.0.0 |
| Autenticação | Firebase Auth | Latest |
| Banco de Dados | Firebase Firestore | Latest |
| Armazenamento | Firebase Storage | Latest |
| Notificações | Firebase Cloud Messaging | Latest |
| Deploy Backend | Railway | - |
| Mapas | Google Maps API | Latest |

---

## 📋 Pré-requisitos

- Flutter SDK: `^3.0.0`
- Node.js: `^18.0.0`
- Dart: `^3.0.0`
- Conta Firebase com projeto configurado
- API Key Google Maps (iOS + Android)
- Conta Railway para deploy do backend

---

## 📁 Estrutura do Projeto

```
TCC-CARONA-UNIVERSIT-RIO/
├── lib/
│   ├── core/
│   │   ├── extensions/       # Extensões de widgets e tipos
│   │   ├── helpers/          # Funções auxiliares
│   │   ├── services/         # Serviços compartilhados
│   │   │   ├── consent_service.dart         # 🆕 Gerenciamento de consentimentos
│   │   │   ├── account_deletion_service.dart # 🆕 LGPD compliance
│   │   │   └── email_token_service.dart      # 🆕 Autenticação por token
│   │   └── theme/            # Cores, estilos, tipografia
│   ├── features/
│   │   ├── onboarding/       # 🆕 Sistema de boas-vindas
│   │   │   ├── models/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   │   ├── onboarding_page_content.dart
│   │   │   │   └── wave_clipper.dart
│   │   │   └── onboarding_screen.dart
│   │   ├── auth/             # Autenticação
│   │   ├── home/             # Tela inicial
│   │   ├── chat/             # Sistema de mensagens
│   │   ├── rides/            # Caronas
│   │   ├── profile/          # Perfil do usuário
│   │   ├── ratings/          # 🆕 Avaliações
│   │   └── legal/            # 🆕 Políticas e Termos
│   │       ├── privacy_policy_screen.dart
│   │       ├── terms_of_service_screen.dart
│   │       └── legal_models.dart
│   ├── screens/              # Telas globais
│   └── main.dart
├── backend/
│   ├── src/
│   │   ├── controllers/
│   │   ├── models/
│   │   ├── routes/
│   │   ├── middleware/
│   │   └── services/
│   ├── .env.example
│   ├── package.json
│   └── railway.json
└── assets/
    ├── images/onboarding/    # 🆕 Ilustrações do onboarding
    └── ...
```

---

## 🚀 Começando

### 1️⃣ Clone o repositório

```bash
git clone https://github.com/Danilo019/TCC-CARONA-UNIVERSIT-RIO.git
cd TCC-CARONA-UNIVERSIT-RIO
```

### 2️⃣ Configuração Frontend (Flutter)

```bash
cd lib
flutter pub get
```

#### Configure Firebase

1. Crie um projeto no [Firebase Console](https://console.firebase.google.com)
2. Adicione um app Android e iOS
3. Baixe `google-services.json` (Android) e `GoogleService-Info.plist` (iOS)
4. Coloque os arquivos nas pastas corretas:
   - Android: `android/app/src/main/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`

#### Configure Google Maps API

1. Habilite Google Maps Platform e Distance Matrix API
2. Configure as chaves de API:
   - **Android**: `android/app/src/main/AndroidManifest.xml`
   - **iOS**: `ios/Runner/Info.plist`

### 3️⃣ Configuração Backend (Node.js)

```bash
cd backend
npm install
```

#### Variáveis de Ambiente

Crie `.env` baseado em `.env.example`:

```env
PORT=3000
NODE_ENV=development

# Firebase
FIREBASE_PROJECT_ID=seu-projeto-id
FIREBASE_PRIVATE_KEY=sua-chave-privada
FIREBASE_CLIENT_EMAIL=seu-email-de-servico

# JWT Token
JWT_SECRET=sua-chave-secreta-jwt
JWT_EXPIRES_IN=7d

# Email (para reset de senha e verificação)
SMTP_USER=seu-email@gmail.com
SMTP_PASSWORD=sua-senha-app

# Railway (após deploy)
DATABASE_URL=url-do-banco-producao
```

#### Deploy no Railway

```bash
railway login
railway link  # Conectar ao projeto Railway existente
railway up    # Deploy
```

### 4️⃣ Execute a Aplicação

```bash
flutter run
```

---

## 📚 Documentação

### Autenticação por Email Token (🆕)

O sistema utiliza verificação por email token para segurança adicional:

1. Usuário faz login/registro com email
2. Backend envia token de 6 dígitos via email
3. Usuário insere o token na app
4. Token é validado e JWT é gerado

```dart
// Exemplo de uso
final authService = EmailTokenService();
final result = await authService.verifyEmailToken(
  email: 'user@example.com',
  token: '123456',
);
```

### Sistema de Consentimento (🆕)

Conformidade com LGPD - O usuário deve aceitar Política de Privacidade e Termos de Serviço:

```dart
// Exemplo
final consentService = ConsentService();
await consentService.saveConsent(
  userId: 'user123',
  privacyPolicy: true,
  termsOfService: true,
  timestamp: DateTime.now(),
);
```

### Avaliações (🆕)

```dart
// Avaliar um usuário
await ratingsService.createRating(
  ratedUserId: 'user123',
  rating: 5,
  comment: 'Excelente motorista!',
);
```

### Reset de Senha

Veja [backend/README.md](./backend/README.md) para documentação completa.

---

## ✅ Status de Implementação

- ✅ Autenticação (Firebase Auth + Email Token System)
- ✅ Perfil do usuário e edição
- ✅ Histórico de viagens
- ✅ Criação/listagem de caronas (motorista / passageiro)
- ✅ Geolocalização + Google Maps / Distance Matrix
- ✅ Chat interno (mensagens)
- ✅ Notificações (Firebase Messaging)
- ✅ Exclusão definitiva de conta (LGPD)
- ✅ Onboarding com animações
- ✅ Sistema de Avaliações (usuários + sistema)
- ✅ Token System (Railway Backend)
- ✅ Políticas de Privacidade + Termos integrados
- 🚧 Recomendações inteligentes
- 🚧 Melhorias em acessibilidade

---

## 🛣️ Roadmap

- [x] Autenticação segura com Firebase
- [x] Sistema de caronas básico
- [x] Chat interno
- [x] Notificações push
- [x] Autenticação por Email Token (Railway)
- [x] Onboarding com animações
- [x] Sistema de avaliações
- [ ] Recomendação inteligente de caronas
- [ ] Internacionalização (i18n)
- [ ] Suporte iOS produção / TestFlight
- [ ] Dark mode refinado
- [ ] Monitoramento de performance (Firebase Performance)
- [ ] Geofencing para notificações automáticas

---

## 🔒 Segurança & Privacidade

Este projeto segue as melhores práticas de segurança:

- 🔐 **Autenticação**: Firebase Auth + Email Token Verification
- 🔒 **Criptografia**: Dados sensíveis criptografados em trânsito (HTTPS/TLS)
- 📋 **LGPD Compliant**: Consentimento explícito e exclusão de dados
- 🛡️ **Validação**: Input validation em frontend e backend
- 🚫 **Rate Limiting**: Proteção contra abuso de API
- 🔐 **Secrets**: Variáveis sensíveis em `.env` (nunca commitadas)

**Política de Privacidade**: Veja `lib/features/legal/privacy_policy_screen.dart`
**Termos de Serviço**: Veja `lib/features/legal/terms_of_service_screen.dart`

---

## 🤝 Contribuindo

1. Crie uma branch para sua feature: `git checkout -b feature/minha-feature`
2. Commit suas mudanças: `git commit -m 'Add: descrição da feature'`
3. Push para a branch: `git push origin feature/minha-feature`
4. Abra um Pull Request

---

## 📞 Suporte

- **Issues**: [GitHub Issues](https://github.com/Danilo019/TCC-CARONA-UNIVERSIT-RIO/issues)
- **Pull Requests**: [GitHub Pull Requests](https://github.com/Danilo019/TCC-CARONA-UNIVERSIT-RIO/pulls)

---

## 📄 Licença

Este projeto é licenciado sob a MIT License - veja o arquivo [LICENSE](./LICENSE) para detalhes.

-
## 👥 Autores

- **Danilo Teodoro dos Santos Silva**
- **Victor Kardec de Mello**

## 🎓 Instituição

<p align="center"><strong>Universidade do Distrito Federal (UDF)</strong></p>

---

<p align="center">
  <strong>Mobilidade acadêmica consciente</strong><br/>
  Feito com ❤️ usando Flutter
</p>
