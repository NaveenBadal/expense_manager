import 'package:expense_manager/ui/components/current_field.dart';
import 'package:expense_manager/ui/components/current_button.dart';
import 'package:expense_manager/ui/components/current_sheet.dart';
import 'package:expense_manager/ui/foundation/current_theme.dart';
import 'package:expense_manager/ui/layout/current_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('single-surface field never paints an inner fill', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CurrentTheme.light(),
        home: Scaffold(
          body: CurrentField(
            controller: controller,
            hint: 'Ask about your money',
          ),
        ),
      ),
    );
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.decoration!.filled, isNot(true));
    expect(textField.decoration!.border, InputBorder.none);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation remains bounded at 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: CurrentTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(2),
          ),
          child: CurrentShell(
            destination: RootDestination.ask,
            onDestinationChanged: (_) {},
            child: const SizedBox(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Activity'), findsOneWidget);
  });

  testWidgets('buttons and sheets keep the Current rounded anatomy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CurrentTheme.light(),
        home: Scaffold(
          body: CurrentButton(label: 'Continue', onPressed: () {}),
        ),
      ),
    );
    final decorated = tester
        .widgetList<Container>(find.byType(Container))
        .map((value) => value.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorated.any((value) => value.borderRadius == BorderRadius.circular(16)),
      isTrue,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CurrentTheme.dark(),
        home: const Scaffold(
          body: CurrentSheet(title: 'A calm sheet', child: Text('Content')),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet navigation supports RTL without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: CurrentTheme.dark(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: CurrentShell(
            destination: RootDestination.activity,
            onDestinationChanged: (_) {},
            child: const SizedBox(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Activity'), findsOneWidget);
  });
}
