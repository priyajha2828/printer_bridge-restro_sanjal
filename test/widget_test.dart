import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:print_bridge_flutter/core/constants/api_constant.dart';
import 'package:print_bridge_flutter/main.dart';
import 'package:print_bridge_flutter/provider/print_bridge_form_provider.dart';

import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Print bridge form page renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PrintBridgeApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Print Bridge'), findsOneWidget);
    expect(find.text('SERVER'), findsOneWidget);
    expect(find.text('PRINTER'), findsOneWidget);
    expect(find.text('BEHAVIOR'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('required fields show a red asterisk on the label',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PrintBridgeApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final asterisk = find.textContaining('*', findRichText: true);
    expect(asterisk, findsNWidgets(3));

    bool hasLabel(String expected) => tester.any(find.byWidgetPredicate((w) {
          if (w is! RichText) return false;
          return w.text.toPlainText() == expected;
        }));
    expect(hasLabel('* Server URL'), isTrue);
    expect(hasLabel('* Bridge Token'), isTrue);
    expect(hasLabel('* Printer IP'), isTrue);
  });

  testWidgets('log level dropdown renders on a narrow screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PrintBridgeApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final logDropdown = find.byType(DropdownMenu<String>);
    expect(logDropdown, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider is accessible via context.read',
      (WidgetTester tester) async {
    PrintBridgeProvider? captured;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PrintBridgeProvider(),
        child: Builder(
          builder: (context) {
            captured = context.read<PrintBridgeProvider>();
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.status, BridgeStatus.disconnected);
    expect(captured!.config.serverUrl, ApiConstant.baseUrl);
  });
}
