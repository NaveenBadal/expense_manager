import 'package:fund_flow/ui/components/current_field.dart';
import 'package:fund_flow/ui/components/current_button.dart';
import 'package:fund_flow/ui/components/current_sheet.dart';
import 'package:fund_flow/ui/foundation/current_theme.dart';
import 'package:fund_flow/ui/layout/chat_shell.dart';
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
          child: ChatShell(
            chat: const SizedBox(),
            activityBuilder: (_) => const SizedBox(),
            activityLabel: '12 transactions',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel('Open activity. 12 transactions'),
      findsOneWidget,
    );
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
          child: ChatShell(
            chat: const SizedBox(),
            activityBuilder: (_) => const SizedBox(),
            activityLabel: 'Activity',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // Wide layouts show the record as a permanent panel, so there is no
    // pull-up handle to find.
    expect(find.bySemanticsLabel('Open activity. Activity'), findsNothing);
  });
}
