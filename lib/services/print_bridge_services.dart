import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/print_bridge_config.dart';

enum LogLevel { error, warn, info, debug }

typedef LogCallback = void Function(LogLevel level, String message);

/// A print job as returned by `/api/print-bridge/jobs/next`.
class PrintJob {
  final String id;
  final String type;
  final Map<String, dynamic>? printer;
  final String? contentBase64;

  PrintJob({
    required this.id,
    required this.type,
    this.printer,
    this.contentBase64,
  });

  factory PrintJob.fromJson(Map<String, dynamic> json) => PrintJob(
    id: json['id'].toString(),
    type: (json['type'] ?? '').toString(),
    printer: json['printer'] is Map
        ? Map<String, dynamic>.from(json['printer'] as Map)
        : null,
    contentBase64: json['content_base64'] as String?,
  );
}

/// Handles all networking with the server and delivery of raw bytes to a
/// network (IP:port) printer, mirroring the original Node.js bridge script.
///
/// NOTE ON PARITY: the original script also supported printing to an
/// OS-registered printer by name (Windows `copy`/PowerShell raw print,
/// macOS `lp -o raw`). Flutter has no cross-platform equivalent of that
/// without a native plugin, so this port focuses on the network printer
/// path (`PRINTER_IP` / `PRINTER_PORT`), which is the most reliable option
/// for thermal/label printers (e.g. TSPL2/ESC-POS over port 9100) anyway.
class PrintBridgeService {
  final BridgeConfig config;
  final LogCallback onLog;
  final String Function() clientIdFallback;

  PrintBridgeService({
    required this.config,
    required this.onLog,
    required this.clientIdFallback,
  });

  static const Map<LogLevel, int> _levelOrder = {
    LogLevel.error: 0,
    LogLevel.warn: 1,
    LogLevel.info: 2,
    LogLevel.debug: 3,
  };

  void _log(LogLevel level, String msg) {
    final configured = _levelFromString(config.logLevel);
    if (_levelOrder[level]! > _levelOrder[configured]!) return;
    onLog(level, msg);
  }

  LogLevel _levelFromString(String s) {
    switch (s) {
      case 'error':
        return LogLevel.error;
      case 'warn':
        return LogLevel.warn;
      case 'debug':
        return LogLevel.debug;
      case 'info':
      default:
        return LogLevel.info;
    }
  }

  Map<String, String> get _headers => {
    'X-Print-Bridge-Token': config.bridgeToken,
    'X-Client-Id':
    config.clientId.isNotEmpty ? config.clientId : clientIdFallback(),
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Uri _uri(String endpoint) => Uri.parse('${config.cleanServerUrl}$endpoint');

  Future<Map<String, dynamic>> apiGet(String endpoint) async {
    final res = await http
        .get(_uri(endpoint), headers: _headers)
        .timeout(const Duration(seconds: 10));
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> apiPost(
      String endpoint, Map<String, dynamic> payload) async {
    final res = await http
        .post(_uri(endpoint), headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 10));
    return _parseJson(res);
  }

  Map<String, dynamic> _parseJson(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const FormatException('Unexpected JSON shape');
    } catch (_) {
      final body =
      res.body.length > 300 ? res.body.substring(0, 300) : res.body;
      throw Exception('Invalid JSON (HTTP ${res.statusCode}): $body');
    }
  }

  /// Equivalent of the original `checkServer()`.
  Future<bool> checkServer() async {
    try {
      final data = await apiGet('/api/print-bridge/status');
      _log(LogLevel.info, 'Server connected: ${data['status']}');
      return true;
    } catch (err) {
      _log(LogLevel.warn, 'Cannot reach server at ${config.cleanServerUrl}: $err');
      return false;
    }
  }

  /// Equivalent of the original `poll()` — fetches one job (if any) and
  /// prints it, then reports completion back to the server.
  Future<void> pollOnce() async {
    _log(LogLevel.debug, 'Polling for jobs...');
    try {
      final data = await apiGet('/api/print-bridge/jobs/next');
      if (data['success'] != true || data['job'] == null) {
        _log(LogLevel.debug, 'No pending jobs');
        return;
      }

      final job = PrintJob.fromJson(Map<String, dynamic>.from(data['job']));
      _log(LogLevel.info, 'Got job ${job.id} type=${job.type}');

      if (job.contentBase64 == null || job.contentBase64!.isEmpty) {
        _log(LogLevel.warn, 'Job ${job.id} has no binary content, skipping');
        await apiPost('/api/print-bridge/jobs/${job.id}/complete',
            {'status': 'failed', 'error': 'No binary content'});
        return;
      }

      await sendToPrinter(job.printer, job.contentBase64!);
      await apiPost(
          '/api/print-bridge/jobs/${job.id}/complete', {'status': 'printed'});
      _log(LogLevel.info, 'Job ${job.id} printed successfully');
    } catch (err) {
      _log(LogLevel.error, 'Poll error: $err');
    }
  }

  /// Equivalent of the original `sendToPrinter()`. Job-level printer info
  /// (from the server) takes priority; otherwise falls back to the
  /// configured default PRINTER_IP.
  Future<void> sendToPrinter(
      Map<String, dynamic>? printer, String contentBase64) async {
    final bytes = base64Decode(contentBase64);
    final jobPrinterIp = (printer?['ip'] as String?) ?? '';

    if (jobPrinterIp.isNotEmpty) {
      _log(LogLevel.info,
          'Sending to IP printer at $jobPrinterIp:${config.printerPort}');
      return sendToIp(jobPrinterIp, config.printerPortInt, bytes);
    }
    if (config.printerIp.isNotEmpty) {
      _log(LogLevel.info,
          'Sending to default IP ${config.printerIp}:${config.printerPort}');
      return sendToIp(config.printerIp, config.printerPortInt, bytes);
    }
    throw Exception(
        'No printer IP configured. Set PRINTER_IP/PRINTER_PORT — named OS printers are not supported in this Flutter build.');
  }

  /// Raw TCP socket write, equivalent to the original `sendToIp()`.
  Future<void> sendToIp(String ip, int port, List<int> bytes) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 10));
      socket.add(bytes);
      await socket.flush();
    } finally {
      socket?.destroy();
    }
  }

  /// Sends a sample text message to the configured printer so the user can
  /// verify it actually prints. Prints "hello printer is working" followed
  /// by a newline.
  Future<bool> testPrintSample() async {
    if (config.printerIp.isEmpty) return false;
    try {
      const message = 'hello printer is working\n';
      _log(LogLevel.info,
          'Sending test print to ${config.printerIp}:${config.printerPort}');
      await sendToIp(
          config.printerIp, config.printerPortInt, utf8.encode(message));
      _log(LogLevel.info, 'Test print sent');
      return true;
    } catch (err) {
      _log(LogLevel.warn, 'Test print failed: $err');
      return false;
    }
  }

  /// Quick reachability check for the "Test printer" button in the UI.
  Future<bool> testPrinterConnection() async {
    if (config.printerIp.isEmpty) return false;
    try {
      final socket = await Socket.connect(
        config.printerIp,
        config.printerPortInt,
        timeout: const Duration(seconds: 5),
      );
      socket.destroy();
      return true;
    } catch (err) {
      _log(LogLevel.warn, 'Printer connection test failed: $err');
      return false;
    }
  }
}
