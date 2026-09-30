import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:print_bridge_flutter/page/print_bridge_form_page.dart';
import 'package:print_bridge_flutter/provider/print_bridge_form_provider.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure the Android foreground-service notification.
  const androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: 'MobileBridge',
    notificationText: 'MobileBridge app is running in the background',
    notificationImportance: AndroidNotificationImportance.normal,
    notificationIcon: AndroidResource(
      name: 'ic_notification',
      defType: 'drawable',
    ),
  );

  // Initialize flutter_background before starting the Flutter application.
  final initialized = await FlutterBackground.initialize(
    androidConfig: androidConfig,
  );

  if (!initialized) {
    debugPrint(
      'Print Bridge: failed to initialize background execution.',
    );
  } else {
    debugPrint(
      'Print Bridge: background execution initialized.',
    );
  }

  runApp(const PrintBridgeApp());
}

class PrintBridgeApp extends StatelessWidget {
  const PrintBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PrintBridgeProvider(),
      child: MaterialApp(
        title: 'Print Bridge',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF2F6FED),
          scaffoldBackgroundColor: const Color(0xFFF4F6F8),
          fontFamily: 'Roboto',
        ),
        home: const PrintBridgeFormPage(),
      ),
    );
  }
}