import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  // Configurações do Firebase para diferentes ambientes
  // Agora lê de variáveis de ambiente (.env) com fallback para valores padrão
  
  // Configurações para desenvolvimento (lê do .env)
  static Map<String, dynamic> get development => {
    'apiKey': dotenv.env['FIREBASE_API_KEY_DEV'] ?? 
              (kDebugMode ? 'AIzaSyD-gR7ZV9EkQKpfRUwPdnXyB4NLb7Kj8QM' : ''),
    'authDomain': dotenv.env['FIREBASE_AUTH_DOMAIN_DEV'] ?? 
                  'carona-universitiaria.firebaseapp.com',
    'projectId': dotenv.env['FIREBASE_PROJECT_ID_DEV'] ?? 
                 'carona-universitiaria',
    'storageBucket': dotenv.env['FIREBASE_STORAGE_BUCKET_DEV'] ?? 
                     'carona-universitiaria.firebasestorage.app',
    'messagingSenderId': dotenv.env['FIREBASE_MESSAGING_SENDER_ID_DEV'] ?? 
                         '83995365801',
    'appId': dotenv.env['FIREBASE_APP_ID_DEV'] ?? 
             '1:83995365801:android:23b104d813b51cdbc4f4b8',
  };

  // Configurações para produção (lê do .env)
  static Map<String, dynamic> get production => {
    'apiKey': dotenv.env['FIREBASE_API_KEY_PROD'] ?? 
              'SUA_API_KEY_PRODUCTION',
    'authDomain': dotenv.env['FIREBASE_AUTH_DOMAIN_PROD'] ?? 
                  'seu-projeto-prod.firebaseapp.com',
    'projectId': dotenv.env['FIREBASE_PROJECT_ID_PROD'] ?? 
                 'seu-projeto-prod',
    'storageBucket': dotenv.env['FIREBASE_STORAGE_BUCKET_PROD'] ?? 
                     'seu-projeto-prod.appspot.com',
    'messagingSenderId': dotenv.env['FIREBASE_MESSAGING_SENDER_ID_PROD'] ?? 
                         '987654321',
    'appId': dotenv.env['FIREBASE_APP_ID_PROD'] ?? 
             '1:987654321:android:fedcba654321',
  };

  // Configurações do Microsoft Azure AD (lê do .env)
  static String get microsoftClientId => 
      dotenv.env['MICROSOFT_CLIENT_ID'] ?? 
      '369b4e14-e96e-4710-9d72-d3413a315cb5';
  
  static String get microsoftTenantId => 
      dotenv.env['MICROSOFT_TENANT_ID'] ?? 
      'common'; // Usar 'common' para multi-tenant
  
  // URI de redirecionamento para aplicativo móvel
  static String get microsoftRedirectUri => 
      dotenv.env['MICROSOFT_REDIRECT_URI'] ?? 
      'msauth://com.carona.universitaria/df%2FWrQM67qwAZFa%2F4i5uTORfZgI%3D';
  
  // URI de redirecionamento para web
  static String get microsoftWebRedirectUri => 
      dotenv.env['MICROSOFT_WEB_REDIRECT_URI'] ?? 
      'https://carona-universitiaria.firebaseapp.com/__/auth/handler';
  
  // Scopes necessários para Microsoft Graph
  static const List<String> microsoftScopes = [
    'openid',
    'profile',
    'email',
    'User.Read',
    'offline_access',
  ];

  // Configurações específicas da UDF
  static const List<String> udfEmailDomains = [
    '@cs.udf.edu.br',
  ];

  // URL do backend para reset de senha (sem plano Blaze)
  // Lê do .env com fallback para valor padrão
  // Configure após fazer deploy do backend (ver backend/README.md)
  // Exemplos:
  // - Heroku: 'https://carona-universitaria-backend.herokuapp.com'
  // - Vercel: 'https://carona-universitaria-backend.vercel.app'
  // - Railway: 'https://carona-universitaria-backend.railway.app'
  static String? get backendUrl => 
      dotenv.env['BACKEND_URL'] ?? 
      'https://tcc-carona-universit-rio-production.up.railway.app';

  // Método para obter configurações baseado no ambiente
  static Map<String, dynamic> getConfig({bool isProduction = false}) {
    return isProduction ? production : development;
  }

  // Verifica se um email é da UDF
  static bool isUDFEmail(String email) {
    return udfEmailDomains.any((domain) => email.endsWith(domain));
  }
}
