import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/print_bridge_config.dart';
import '../services/print_bridge_services.dart';

enum BridgeStatus { disconnected, connecting, connected, error }

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String message;
  LogEntry(this.time, this.level, this.message);
}

/// App-wide state: holds the config, drives the connect/poll lifecycle,
/// and keeps a rolling log the UI can render.
class PrintBridgeProvider extends ChangeNotifier {
  BridgeConfig _config = const BridgeConfig();
  BridgeStatus _status = BridgeStatus.disconnected;
  final List<LogEntry> _logs = [];
  Timer? _pollTimer;
  PrintBridgeService? _service;
  int _jobsPrinted = 0;
  bool _loaded = false;

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

  BridgeConfig get config => _config;
  BridgeStatus get status => _status;
  List<LogEntry> get logs => List.unmodifiable(_logs.reversed);
  int get jobsPrinted => _jobsPrinted;
  bool get loaded => _loaded;
  bool get isConnected => _status == BridgeStatus.connected;
  bool get isBusy => _status == BridgeStatus.connecting;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, String>{};
    for (final key in _fields) {
      final v = prefs.getString('$_prefsPrefix$key');
      if (v != null) map[key] = v;
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
      await prefs.setString('$_prefsPrefix${entry.key}', entry.value);
    }
    notifyListeners();
  }

  void _addLog(LogLevel level, String message) {
    _logs.add(LogEntry(DateTime.now(), level, message));
    if (_logs.length > 300) _logs.removeAt(0);
    notifyListeners();
  }

  /// Equivalent of the original script's startup: validates the token,
  /// pings the server, then starts the poll loop on a timer.
  Future<void> connect() async {
    if (!_config.isValid) {
      _addLog(LogLevel.error,
          'BRIDGE_TOKEN and SERVER_URL are required. Get your token from Settings > Printer Setup in the web app.');
      _status = BridgeStatus.error;
      notifyListeners();
      return;
    }

    _status = BridgeStatus.connecting;
    notifyListeners();

    _service = PrintBridgeService(
      config: _config,
      onLog: _addLog,
      clientIdFallback: () => 'flutter-client',
    );

    final ok = await _service!.checkServer();
    _status = ok ? BridgeStatus.connected : BridgeStatus.error;
    notifyListeners();

    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(Duration(milliseconds: _config.pollIntervalMs), (_) => _poll());
    Timer(const Duration(milliseconds: 500), _poll);
  }

  Future<void> _poll() async {
    final service = _service;
    if (service == null) return;
    final before = _jobsPrinted;
    await service.pollOnce();
    // Heuristic bump: a successful print logs an "printed successfully" info line.
    if (_logs.isNotEmpty &&
        _logs.last.level == LogLevel.info &&
        _logs.last.message.contains('printed successfully')) {
      _jobsPrinted = before + 1;
    }
  }

  Future<bool> testPrintSample() async {
    _service ??= PrintBridgeService(
      config: _config,
      onLog: _addLog,
      clientIdFallback: () => 'flutter-client',
    );
    return _service!.testPrintSample();
  }

  Future<bool> testPrinter() async {
    _service ??= PrintBridgeService(
      config: _config,
      onLog: _addLog,
      clientIdFallback: () => 'flutter-client',
    );
    return _service!.testPrinterConnection();
  }

  void disconnect() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _service = null;
    _status = BridgeStatus.disconnected;
    _addLog(LogLevel.info, 'Disconnected.');
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
