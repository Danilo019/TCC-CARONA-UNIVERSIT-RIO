import 'package:flutter/material.dart';
import 'package:app_carona_novo/components/login_page.dart';
import 'package:app_carona_novo/screens/location_request_screen.dart';
import 'package:app_carona_novo/screens/splash_screen.dart';
import 'package:app_carona_novo/screens/messages/message_screen.dart'; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/location-request': (context) => const LocationRequestScreen(),
        '/login': (context) => const LoginPage(),
        '/messages': (context) => const MessageScreen(),  
      },
    );
  }
}
