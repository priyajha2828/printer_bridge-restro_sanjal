import 'dart:async';

import 'package:flutter/material.dart';
import '../resources/custom_color.dart';
import '../resources/custom_widgets.dart';


/// In-app splash: logo fades and scales in, then the app moves on to [next].
///
/// Usage in main.dart:
///   home: const SplashScreen(next: PrintBridgeFormPage()),
class SplashScreen extends StatefulWidget {
  final Widget next;
  final Duration duration;

  const SplashScreen({
    super.key,
    required this.next,
    this.duration = const Duration(milliseconds: 2500),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    _timer = Timer(widget.duration, _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => widget.next,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final logoSize = (width * 0.55).clamp(180.0, 300.0);

    return Scaffold(
      backgroundColor: AppColors.splashBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Image.asset(
                      AppAssets.splash,
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.print_rounded,
                        size: logoSize * 0.5,
                        color: AppColors.splashAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            FadeTransition(
              opacity: _fade,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.splashAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}