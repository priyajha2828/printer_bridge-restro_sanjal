import 'package:flutter/material.dart';
import 'package:print_bridge_flutter/page/print_bridge_form_page.dart';
import 'package:print_bridge_flutter/provider/print_bridge_form_provider.dart';
import 'package:provider/provider.dart';


void main() {
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
