import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background/flutter_background.dart';

/// Owns the one-time `flutter_background` setup for the Android foreground
/// service.
///
/// [ensureInitialized] is safe to call from anywhere and is invoked from the
/// Connect action rather than from `main()`, because the plugin's battery
/// optimisation prompt hijacks the UI and only completes once the user
/// returns from the system settings screen.
class BackgroundBootstrap {
  BackgroundBootstrap._();

  static Future<bool>? _pending;

  /// Runs [onLog] with the outcome so the message reaches the in-app activity
  /// log — the only place diagnostics are visible in a release build.
  static Future<bool> ensureInitialized(
    void Function(bool ok, String message) onLog,
  ) async {
    final pending = _pending;

    if (pending != null) {
      return pending;
    }

    final future = _initialize(onLog);

    _pending = future;

    final ok = await future;

    if (!ok) {
      // Allow the next Connect attempt to retry instead of caching the failure.
      _pending = null;
    }

    return ok;
  }

  /// Whether Android is currently exempting the app from battery optimisation.
  /// Returns false when the plugin cannot answer, which only means the hint is
  /// suppressed.
  static Future<bool> isBatteryExempt() async {
    try {
      return await FlutterBackground.hasPermissions;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _initialize(
    void Function(bool ok, String message) onLog,
  ) async {
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: 'MobileBridge',
      notificationText: 'MobileBridge app is running in the background',
      notificationImportance: AndroidNotificationImportance.normal,
      // Must exist in android/app/src/main/res/drawable, otherwise
      // getIdentifier() returns 0 and Android rejects startForeground().
      notificationIcon: AndroidResource(
        name: 'ic_notification',
        defType: 'drawable',
      ),
      // Opting in makes enableBackgroundExecution() fail outright whenever
      // battery optimisation is not whitelisted. The service is started
      // regardless and the user is told how to whitelist manually.
      shouldRequestBatteryOptimizationsOff: false,
    );

    debugPrint('Print Bridge: configuring background execution...');

    try {
      final initialized = await FlutterBackground.initialize(
        androidConfig: androidConfig,
      ).timeout(const Duration(seconds: 15));

      if (initialized) {
        debugPrint('Print Bridge: background execution initialized.');

        onLog(true, 'Background service configured.');
      } else {
        debugPrint('Print Bridge: background setup was rejected.');

        onLog(false, 'Android rejected the background service setup.');
      }

      return initialized;
    } on PlatformException catch (e) {
      debugPrint('Print Bridge: background setup error ${e.code}: ${e.message}');

      onLog(false, 'Background setup failed (${e.code}): ${e.message}');
    } on TimeoutException {
      debugPrint('Print Bridge: background setup timed out.');

      onLog(false, 'Background setup timed out after 15s.');
    } catch (e) {
      debugPrint('Print Bridge: background setup failed: $e');

      onLog(false, 'Background setup failed: $e');
    }

    return false;
  }
}
