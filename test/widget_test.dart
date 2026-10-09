import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:apptest/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('affiche les profils disponibles au démarrage', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('BTP PLATFORM'), findsOneWidget);
    expect(find.text('Je suis Client'), findsOneWidget);
    expect(find.text('Je suis Entrepreneur'), findsOneWidget);
    expect(find.text('Je suis Technicien'), findsOneWidget);
  });

  testWidgets('quitter un formulaire après une saisie ne lève pas d’erreur', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Je suis Client'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'retirer');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('BTP PLATFORM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mettre à jour le journal ferme le formulaire sans erreur', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'user_role': 'technicien'});
    await tester.pumpWidget(const MyApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(
          '/project/detail',
          arguments: {
            'id': '1',
            'name': 'Chantier test',
            'code': 'BTP-AB12',
            'location': 'Site',
            'entrepreneurId': '2',
            'progress': 10,
          },
        );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ajouter une mise à jour'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Avancement test');
    await tester.drag(find.byType(Slider), const Offset(50, 0));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Journal du chantier'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
