class FirebaseConfig {
  // Configurações do Firebase para diferentes ambientes
  
  // Configurações para desenvolvimento
  static const Map<String, dynamic> development = {
    'apiKey': 'AIzaSyD-gR7ZV9EkQKpfRUwPdnXyB4NLb7Kj8QM',
    'authDomain': 'carona-universitiaria.firebaseapp.com',
    'projectId': 'carona-universitiaria',
    'storageBucket': 'carona-universitiaria.firebasestorage.app',
    'messagingSenderId': '83995365801',
    'appId': '1:83995365801:android:23b104d813b51cdbc4f4b8',
  };

  // Configurações para produção
  static const Map<String, dynamic> production = {
    'apiKey': 'SUA_API_KEY_PRODUCTION',
    'authDomain': 'seu-projeto-prod.firebaseapp.com',
    'projectId': 'seu-projeto-prod',
    'storageBucket': 'seu-projeto-prod.appspot.com',
    'messagingSenderId': '987654321',
    'appId': '1:987654321:android:fedcba654321',
  };

  // Configurações do Microsoft Azure AD
  static const String microsoftClientId = '369b4e14-e96e-4710-9d72-d3413a315cb5';
  static const String microsoftTenantId = 'common'; // Usar 'common' para multi-tenant
  // URI de redirecionamento para aplicativo móvel
  static const String microsoftRedirectUri = 'msauth://com.carona.universitaria/df%2FWrQM67qwAZFa%2F4i5uTORfZgI%3D';
  // URI de redirecionamento para web
  static const String microsoftWebRedirectUri = 'https://carona-universitiaria.firebaseapp.com/__/auth/handler';
  
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

  // Método para obter configurações baseado no ambiente
  static Map<String, dynamic> getConfig({bool isProduction = false}) {
    return isProduction ? production : development;
  }

  // Verifica se um email é da UDF
  static bool isUDFEmail(String email) {
    return udfEmailDomains.any((domain) => email.endsWith(domain));
  }
}
