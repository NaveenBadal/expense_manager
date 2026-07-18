import 'package:expense_manager/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh journey reaches the three calm destinations', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    if (find.text('Get started').evaluate().isNotEmpty) {
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect or continue later'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check messages or skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Fund Flow'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Ask'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Activity'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('You'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
