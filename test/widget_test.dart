// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:guardsys/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Základní test aplikace', (WidgetTester tester) async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBhYvnXKG0KUUH5Ejzhjz2vd4pATLglDMQ",
        appId: "1:361238420936:android:69c21f5b0727734b5c34fd",
        messagingSenderId: "361238420936",
        projectId: "lapdiary2",
        storageBucket: "lapdiary2.appspot.com",
      ),
    );

    // Sestavení aplikace
    await tester.pumpWidget(const MyApp());

    // Ověření, že se zobrazuje hlavní stránka
    expect(find.text('Guard System'), findsOneWidget);

    // Ověření, že se zobrazují všechny tlačítka v navigaci
    expect(find.text('Pauzovačka'), findsOneWidget);
    expect(find.text('Domů'), findsOneWidget);
    expect(find.text('Zprávy'), findsOneWidget);
  });
}
