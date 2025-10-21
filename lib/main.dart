import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'screens/location_request_screen.dart';
import 'screens/home_screen.dart';
import 'components/login_page.dart';
import 'providers/auth_provider.dart';
import 'config/firebase_config.dart';
import 'config/aad_config.dart';


void main() async {
  // Garante que os bindings do Flutter foram inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Define a orientação preferencial para retrato (vertical)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inicializa o Firebase
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: FirebaseConfig.development['apiKey'],
        authDomain: FirebaseConfig.development['authDomain'],
        projectId: FirebaseConfig.development['projectId'],
        storageBucket: FirebaseConfig.development['storageBucket'],
        messagingSenderId: FirebaseConfig.development['messagingSenderId'],
        appId: FirebaseConfig.development['appId'],
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const CaronaUniApp());
}

class CaronaUniApp extends StatelessWidget {
  const CaronaUniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Carona Universitária',
        debugShowCheckedModeBanner: false,
        navigatorKey: AadConfig.navigatorKey,
        
        // Tema do aplicativo
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: const Color(0xFF2196F3),
          fontFamily: 'Roboto',
          useMaterial3: false, // Desabilitado temporariamente devido ao caminho com acentos
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3),
            brightness: Brightness.light,
          ),
        ),

        // Tela inicial: Splash Screen
        home: const SplashScreen(),

        // Rotas do aplicativo
        // Sequência: Splash → Onboarding → Location Request → Login → Home
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/location-request': (context) => const LocationRequestScreen(),
          '/login': (context) => const LoginPage(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}


