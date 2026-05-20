// Widget test for the Folio home screen.
//
// Verifies that the initial state (no document loaded) shows the expected
// placeholder UI. HomeScreen viene montata direttamente per saltare lo splash.

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio/folio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('home screen shows branding and open-document button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [FlutterQuillLocalizations.delegate],
        home: HomeScreen(),
      ),
    );
    await tester.pump();

    // Il titolo dell'app è visibile nell'header.
    expect(find.text('Folio'), findsOneWidget);

    // Il messaggio di stato vuoto è visibile quando non ci sono documenti.
    expect(find.text('Nessun documento recente'), findsOneWidget);

    // Il pulsante per aprire un documento è presente.
    expect(find.byIcon(Icons.folder_open_outlined), findsWidgets);
  });
}
