import 'package:RestroSanjalBridge/page/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:RestroSanjalBridge/page/print_bridge_form_page.dart';
import 'package:RestroSanjalBridge/provider/print_bridge_form_provider.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No platform calls are awaited here. FlutterBackground.initialize() can
  // block for as long as the user stays on the Android "ignore battery
  // optimizations" settings screen, so awaiting it before runApp() leaves a
  // released APK stuck on a blank window. It is set up lazily on Connect
  // instead, where the outcome is reported in the activity log.
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
          home: const SplashScreen(next: PrintBridgeFormPage()),
      ),
    );
  }
}