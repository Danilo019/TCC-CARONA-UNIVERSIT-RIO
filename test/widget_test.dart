import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_carona_novo/main.dart';

void main() {
  testWidgets('SplashScreen UI Test', (WidgetTester tester) async {
    // Constrói o aplicativo e dispara um frame
    await tester.pumpWidget(const MyApp());

    // Verifica se o título "Carona Universitária" aparece na tela
    expect(find.text('Carona Universitária'), findsOneWidget);

    // Verifica se há um indicador de progresso (loading)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
