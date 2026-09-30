import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/print_bridge_config.dart';
import '../core/background/background_bootstrap.dart';
import '../services/print_bridge_services.dart';

enum BridgeStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String message;

  LogEntry(this.time, this.level, this.message);
}

/// App-wide state: holds configuration, drives the connect/poll lifecycle,
/// tracks network printer discovery, and provides a rolling activity log.
class PrintBridgeProvider extends ChangeNotifier {
  BridgeConfig _config = const BridgeConfig();

  BridgeStatus _status = BridgeStatus.disconnected;

  final List<LogEntry> _logs = [];

  Timer? _pollTimer;
  PrintBridgeService? _service;

  int _jobsPrinted = 0;

  bool _loaded = false;
  bool _isPolling = false;
  bool _isDiscovering = false;

  List<String> _discoveredPrinters = [];

  String _discoveryProgress = '';

  int _consecutiveErrors = 0;

  /// Prevents starting the Android foreground service more than once.
  bool _backgroundExecutionEnabled = false;

  // --- Notification watchdog -------------------------------------------------
  // On Android 14+ the user can swipe away a foreground-service notification
  // (the service keeps running). While connected we check every 5 seconds and,
  // if no notification of this app is showing, post our own ONGOING
  // notification (same text). Ongoing notifications that are not tied to a
  // foreground service cannot be swiped away, on any Android version.
  // No service restart is needed, so Android 12+ background-start limits
  // do not apply.
  static const int _statusNotifId = 7791;
  static const String _statusChannelId = 'print_bridge_status';
  static const String _statusTitle = 'RestroSanjalBridge';
  static const String _statusBody =
      'RestroSanjalBridge app is running in the background';

  final FlutterLocalNotificationsPlugin _notifPlugin =
  FlutterLocalNotificationsPlugin();
  bool _notifPluginReady = false;
  Timer? _notifWatchdog;
  bool _checkingNotification = false;

  static const _prefsPrefix = 'print_bridge_config.';

  static const _fields = [
    'serverUrl',
    'bridgeToken',
    'clientId',
    'printerIp',
    'printerPort',
    'pollInterval',
    'logLevel',
  ];

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  BridgeConfig get config => _config;

  BridgeStatus get status => _status;

  List<LogEntry> get logs => List.unmodifiable(_logs.reversed);

  int get jobsPrinted => _jobsPrinted;

  bool get loaded => _loaded;

  bool get isConnected => _status == BridgeStatus.connected;

  bool get isBusy => _status == BridgeStatus.connecting;

  bool get isDiscovering => _isDiscovering;

  List<String> get discoveredPrinters => _discoveredPrinters;

  String get discoveryProgress => _discoveryProgress;

  bool get isBackgroundExecutionEnabled => _backgroundExecutionEnabled;

  // ===========================================================================
  // CONFIGURATION
  // ===========================================================================

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();

    final map = <String, String>{};

    for (final key in _fields) {
      final value = prefs.getString('$_prefsPrefix$key');

      if (value != null) {
        map[key] = value;
      }
    }

    if (map.isNotEmpty) {
      _config = BridgeConfig.fromMap(map);
    }

    _loaded = true;

    notifyListeners();
  }

  Future<void> saveConfig(BridgeConfig newConfig) async {
    _config = newConfig;

    final prefs = await SharedPreferences.getInstance();

    for (final entry in newConfig.toMap().entries) {
      await prefs.setString(
        '$_prefsPrefix${entry.key}',
        entry.value,
      );
    }

    if (_service != null) {
      _service = _createService();
    }

    notifyListeners();
  }

  // ===========================================================================
  // SERVICE FACTORY
  // ===========================================================================

  PrintBridgeService _createService() {
    return PrintBridgeService(
      config: _config,
      onLog: _addLog,
      clientIdFallback: () => 'flutter-client',
    );
  }

  // ===========================================================================
  // LOGGING
  // ===========================================================================

  void _addLog(LogLevel level, String message) {
    _logs.add(LogEntry(DateTime.now(), level, message));

    if (_logs.length > 300) {
      _logs.removeAt(0);
    }

    notifyListeners();
  }

  // ===========================================================================
  // ANDROID BACKGROUND EXECUTION
  // ===========================================================================

  /// Asks for the runtime notification permission (required on Android 13+).
  /// Without it the foreground service runs but its notification is hidden.
  Future<void> _ensureNotificationPermission() async {
    try {
      var status = await Permission.notification.status;

      if (!status.isGranted) {
        status = await Permission.notification.request();
      }

      if (status.isGranted) {
        return;
      }

      if (status.isPermanentlyDenied) {
        _addLog(
          LogLevel.warn,
          'Notification permission is permanently denied. Enable it in '
              'Settings > Apps > Print Bridge > Notifications to see the '
              'background notification.',
        );
      } else {
        _addLog(
          LogLevel.warn,
          'Notification permission denied. The background notification '
              'will not be shown.',
        );
      }
    } catch (e) {
      debugPrint('Print Bridge notification permission error: $e');

      _addLog(
        LogLevel.warn,
        'Could not request notification permission: $e',
      );
    }
  }

  Future<bool> _enableBackgroundExecution() async {
    // Already running.
    if (_backgroundExecutionEnabled) {
      return true;
    }

    try {
      // Must be granted BEFORE the foreground service starts so that the
      // notification can appear in the tray.
      await _ensureNotificationPermission();

      // The plugin is configured here rather than in main() so a failure is
      // reported in the activity log instead of hanging a blank window.
      final configured = await BackgroundBootstrap.ensureInitialized(
            (ok, message) =>
            _addLog(ok ? LogLevel.info : LogLevel.error, message),
      );

      if (!configured) {
        return false;
      }

      debugPrint('Print Bridge: starting Android foreground service...');

      final enabled = await FlutterBackground.enableBackgroundExecution();

      if (enabled) {
        _backgroundExecutionEnabled = true;

        debugPrint('Print Bridge: foreground service started.');

        _addLog(
          LogLevel.info,
          'Print Bridge is running in the background.',
        );

        notifyListeners();

        _warnIfBatteryOptimised();

        // Re-show the notification within 5s if the user swipes it away.
        _startNotificationWatchdog();

        return true;
      }

      debugPrint('Print Bridge: foreground service could not be started.');

      _addLog(
        LogLevel.warn,
        'Could not start background execution.',
      );

      return false;
    } catch (e, stackTrace) {
      debugPrint('Print Bridge background execution error: $e');

      debugPrintStack(stackTrace: stackTrace);

      _addLog(
        LogLevel.error,
        'Failed to start background execution: $e',
      );

      return false;
    }
  }

  /// Non-blocking hint: Android may throttle or kill the poll loop once the
  /// screen is off unless the app is exempt from battery optimisation.
  void _warnIfBatteryOptimised() {
    BackgroundBootstrap.isBatteryExempt().then((exempt) {
      if (exempt) return;

      _addLog(
        LogLevel.warn,
        'Battery optimisation is still active. Set Print Bridge to '
            '"Unrestricted" in Settings > Apps > Print Bridge > Battery, '
            'otherwise Android can pause polling when the screen is off.',
      );
    });
  }

  Future<void> _disableBackgroundExecution() async {
    // Always stop the watchdog first so it can't restart the service while
    // we are shutting it down.
    _stopNotificationWatchdog();

    if (!_backgroundExecutionEnabled) {
      return;
    }

    try {
      debugPrint('Print Bridge: stopping Android foreground service...');

      await FlutterBackground.disableBackgroundExecution();

      _backgroundExecutionEnabled = false;

      debugPrint('Print Bridge: foreground service stopped.');

      _addLog(
        LogLevel.info,
        'Print Bridge background execution stopped.',
      );
    } catch (e) {
      debugPrint('Print Bridge background shutdown error: $e');

      _addLog(
        LogLevel.warn,
        'Failed to stop background execution: $e',
      );
    }
  }

  // ===========================================================================
  // NOTIFICATION WATCHDOG
  // ===========================================================================

  void _startNotificationWatchdog() {
    _notifWatchdog?.cancel();

    _notifWatchdog = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _checkNotification(),
    );
  }

  void _stopNotificationWatchdog() {
    _notifWatchdog?.cancel();

    _notifWatchdog = null;

    // Remove the notification we may have posted ourselves.
    if (_notifPluginReady) {
      _notifPlugin.cancel(_statusNotifId).catchError((_) {});
    }
  }

  Future<void> _ensureNotifPlugin() async {
    if (_notifPluginReady) return;

    await _notifPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    final android = _notifPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _statusChannelId,
        'Print Bridge status',
        description: 'Shows that Print Bridge is running in the background',
        importance: Importance.low,
      ),
    );

    _notifPluginReady = true;
  }

  Future<void> _postStatusNotification(String icon) {
    return _notifPlugin.show(
      _statusNotifId,
      _statusTitle,
      _statusBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _statusChannelId,
          'Print Bridge status',
          channelDescription:
          'Shows that Print Bridge is running in the background',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          onlyAlertOnce: true,
          icon: icon,
        ),
      ),
    );
  }

  /// If no notification of this app is in the tray (the user swiped the
  /// foreground-service one away), post an ongoing one.
  Future<void> _checkNotification() async {
    if (_checkingNotification ||
        !_backgroundExecutionEnabled ||
        _pollTimer == null) {
      return;
    }

    _checkingNotification = true;

    try {
      await _ensureNotifPlugin();

      final android = _notifPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (android == null) {
        return;
      }

      final active = await android.getActiveNotifications();

      // A notification is still showing: nothing to do.
      if (active.isNotEmpty) {
        return;
      }

      // Disconnect may have happened while we were awaiting.
      if (!_backgroundExecutionEnabled || _pollTimer == null) {
        return;
      }

      try {
        await _postStatusNotification('ic_notification');
      } catch (_) {
        // Drawable missing: fall back to the launcher icon.
        await _postStatusNotification('@mipmap/ic_launcher');
      }

      _addLog(LogLevel.info, 'Background notification restored.');
    } catch (e) {
      debugPrint('Print Bridge notification watchdog error: $e');
    } finally {
      _checkingNotification = false;
    }
  }

  // ===========================================================================
  // CONNECT
  // ===========================================================================

  /// Connects to the RestroSanjal backend and starts polling for jobs.
  ///
  /// After the server connection succeeds, Android foreground execution
  /// is enabled. This causes the persistent Print Bridge notification
  /// to appear in the Android notification tray.
  Future<void> connect() async {
    if (!_config.isValid) {
      _addLog(
        LogLevel.error,
        'BRIDGE_TOKEN and SERVER_URL are required. '
            'Get your token from Settings > Printer Setup.',
      );

      _status = BridgeStatus.error;

      notifyListeners();

      return;
    }

    // Prevent duplicate connection attempts.
    if (_status == BridgeStatus.connecting) {
      return;
    }

    _status = BridgeStatus.connecting;

    notifyListeners();

    _service = _createService();

    try {
      // -----------------------------------------------------------------------
      // Server connection
      // -----------------------------------------------------------------------

      final ok = await _service!.checkServer();

      _status = ok ? BridgeStatus.connected : BridgeStatus.error;
      _consecutiveErrors = ok ? 0 : 1;

      notifyListeners();

      // -----------------------------------------------------------------------
      // Start Android foreground service (single call) so the persistent
      // notification appears. Only done once the server check succeeded.
      // -----------------------------------------------------------------------

      if (ok) {
        final backgroundStarted = await _enableBackgroundExecution();

        if (!backgroundStarted) {
          _addLog(
            LogLevel.warn,
            'Bridge connected, but Android background '
                'execution could not be started.',
          );
        }
      }

      // -----------------------------------------------------------------------
      // Polling lifecycle
      // -----------------------------------------------------------------------

      _pollTimer?.cancel();

      _pollTimer = Timer.periodic(
        Duration(milliseconds: _config.pollIntervalMs),
            (_) => _poll(),
      );

      // Run first poll shortly after connection.
      Timer(const Duration(milliseconds: 400), _poll);
    } catch (e, stackTrace) {
      debugPrint('Print Bridge connection error: $e');

      debugPrintStack(stackTrace: stackTrace);

      _status = BridgeStatus.error;

      _consecutiveErrors++;

      _addLog(
        LogLevel.error,
        'Connection failed: $e',
      );

      notifyListeners();
    }
  }

  // ===========================================================================
  // POLLING
  // ===========================================================================

  Future<void> _poll() async {
    final service = _service;

    if (service == null || _isPolling) {
      return;
    }

    _isPolling = true;

    try {
      final printed = await service.pollOnce();

      if (printed) {
        _jobsPrinted++;

        notifyListeners();
      }

      if (_status != BridgeStatus.connected) {
        _status = BridgeStatus.connected;

        notifyListeners();
      }

      _consecutiveErrors = 0;
    } catch (e) {
      _consecutiveErrors++;

      if (_consecutiveErrors >= 3 && _status == BridgeStatus.connected) {
        _status = BridgeStatus.error;

        _addLog(
          LogLevel.warn,
          'Repeated poll failures; '
              'connection marked as degraded ($e)',
        );

        notifyListeners();
      }
    } finally {
      _isPolling = false;
    }
  }

  // ===========================================================================
  // TEST PRINT
  // ===========================================================================

  Future<bool> testPrintSample() async {
    _service ??= _createService();

    return _service!.testPrintSample();
  }

  // ===========================================================================
  // TEST PRINTER
  // ===========================================================================

  Future<bool> testPrinter() async {
    _service ??= _createService();

    return _service!.testPrinterConnection();
  }

  // ===========================================================================
  // PRINTER DISCOVERY
  // ===========================================================================

  /// Scans local network to discover printers listening on port 9100.
  Future<void> discoverPrinters() async {
    _service ??= _createService();

    _isDiscovering = true;

    _discoveredPrinters = [];

    _discoveryProgress = 'Scanning local network for printers...';

    notifyListeners();

    _addLog(
      LogLevel.info,
      'Scanning local subnet for port '
          '${_config.printerPortInt} printers...',
    );

    try {
      final found = await _service!.discoverLocalPrinters(
        onProgress: (p) {
          _discoveryProgress = p;

          notifyListeners();
        },
      );

      _discoveredPrinters = found;

      if (found.isEmpty) {
        _addLog(
          LogLevel.warn,
          'No network printers found on local subnet. '
              'Verify printer is on same WiFi.',
        );
      } else {
        _addLog(
          LogLevel.info,
          'Discovered ${found.length} printer(s): '
              '${found.join(", ")}',
        );
      }
    } catch (e) {
      _addLog(
        LogLevel.error,
        'Printer discovery failed: $e',
      );
    } finally {
      _isDiscovering = false;

      _discoveryProgress = '';

      notifyListeners();
    }
  }

  // ===========================================================================
  // DISCONNECT
  // ===========================================================================

  Future<void> disconnect() async {
    // Stop polling.
    _pollTimer?.cancel();

    _pollTimer = null;

    _isPolling = false;

    // Remove existing service instance.
    _service = null;

    // Stop Android foreground service (removes the notification).
    await _disableBackgroundExecution();

    _status = BridgeStatus.disconnected;

    _consecutiveErrors = 0;

    _addLog(
      LogLevel.info,
      'Disconnected from server.',
    );

    notifyListeners();
  }

  // ===========================================================================
  // CLEAR LOGS
  // ===========================================================================

  void clearLogs() {
    _logs.clear();

    notifyListeners();
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _pollTimer?.cancel();

    _pollTimer = null;

    _stopNotificationWatchdog();

    // ChangeNotifier.dispose() cannot await.
    // Stop the Android foreground service without blocking dispose().
    if (_backgroundExecutionEnabled) {
      FlutterBackground.disableBackgroundExecution().catchError((_) => false);

      _backgroundExecutionEnabled = false;
    }

    super.dispose();
  }
}