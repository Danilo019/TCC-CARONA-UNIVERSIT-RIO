import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:flutter/material.dart';
import 'firebase_config.dart';

class AadConfig {
  static final navigatorKey = GlobalKey<NavigatorState>();
  
  static Config getConfig() {
    return Config(
      tenant: FirebaseConfig.microsoftTenantId,
      clientId: FirebaseConfig.microsoftClientId,
      scope: FirebaseConfig.microsoftScopes.join(' '),
      redirectUri: FirebaseConfig.microsoftRedirectUri,
      navigatorKey: navigatorKey,
      // Para Android
      webUseRedirect: false,
    );
  }

  static AadOAuth getOAuthInstance() {
    return AadOAuth(getConfig());
  }
}

