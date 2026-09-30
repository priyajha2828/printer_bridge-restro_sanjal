import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../config/print_bridge_config.dart';
import '../core/constants/api_constant.dart';
import '../core/network/dio_client.dart';

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

/// Handles all networking with the server via Dio and delivery of raw ESC/POS & TSPL
/// bytes to network (TCP IP:port) printers.
class PrintBridgeService {
  final BridgeConfig config;
  final LogCallback onLog;
  final String Function() clientIdFallback;

  PrintBridgeService({
    required this.config,
    required this.onLog,
    required this.clientIdFallback,
  }) {
    _initClient();
  }

  static const Map<LogLevel, int> _levelOrder = {
    LogLevel.error: 0,
    LogLevel.warn: 1,
    LogLevel.info: 2,
    LogLevel.debug: 3,
  };

  void _initClient() {
    DioClient.updateBaseUrl(config.cleanServerUrl);
    DioClient.setAuthToken(config.bridgeToken);
    DioClient.setClientId(
      config.clientId.isNotEmpty ? config.clientId : clientIdFallback(),
    );
    DioClient.logCallback = (msg, {isError = false}) {
      _log(isError ? LogLevel.warn : LogLevel.debug, '[Dio] $msg');
    };
  }

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

  /// Sends a GET request via DioClient.
  Future<Map<String, dynamic>> apiGet(String endpoint) async {
    _initClient();
    final response = await DioClient.dio.get<dynamic>(
      endpoint,
      options: Options(
        headers: {
           'x-client-Id':config.clientId,
          'x-Printer-System-Names':'80 Printer Series,ZKP8016',
          'Accept':'application/json',
        },
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    return _normalizeJson(response.data);
  }

  /// Sends a POST request via DioClient.
  Future<Map<String, dynamic>> apiPost(
      String endpoint, Map<String, dynamic> payload) async {
    _initClient();
    final response = await DioClient.dio.post<dynamic>(
      endpoint,
      data: payload,
      options: Options(
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    return _normalizeJson(response.data);
  }

  Map<String, dynamic> _normalizeJson(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      return Map<String, dynamic>.from(data);
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        throw FormatException('Unexpected response format: $data');
      }
    }
    throw const FormatException('Expected JSON map response');
  }

  /// Pings the RestroSanjal backend status endpoint.
  Future<bool> checkServer() async {
    try {
      final data = await apiGet(ApiConstant.statusEndpoint);
      final status = data['status'] ?? 'ok';
      _log(LogLevel.info, 'Server connected successfully: $status');
      return true;
    } catch (err) {
      _log(LogLevel.warn,
          'Cannot reach server at ${config.cleanServerUrl}: $err');
      return false;
    }
  }

  /// Polls the server for the next pending print job and executes it.
  Future<bool> pollOnce() async {
    _log(LogLevel.debug, 'Polling for pending print jobs...');
    try {
      final data = await apiGet(ApiConstant.nextJobEndpoint);
      debugPrint("polling");
      debugPrint(data.toString());
      if (data['success'] != true || data['job'] == null) {
        _log(LogLevel.debug, 'No pending jobs in queue');
        return false;
      }

      final job = PrintJob.fromJson(Map<String, dynamic>.from(data['job']));
      _log(LogLevel.info, 'Received print job ${job.id} (type: ${job.type})');

      if (job.contentBase64 == null || job.contentBase64!.trim().isEmpty) {
        _log(LogLevel.warn, 'Job ${job.id} has no binary content, skipping');
        await apiPost(
          ApiConstant.completeJobEndpoint(job.id),
          {'status': 'failed', 'error': 'No binary content provided'},
        );
        return false;
      }

      try {
        await sendToPrinter(job.printer, job.contentBase64!);
        await apiPost(
          ApiConstant.completeJobEndpoint(job.id),
          {'status': 'printed'},
        );
        _log(LogLevel.info, 'Job ${job.id} printed successfully');
        return true;
      } catch (printErr) {
        _log(LogLevel.error, 'Failed to print job ${job.id}: $printErr');
        try {
          await apiPost(
            ApiConstant.completeJobEndpoint(job.id),
            {'status': 'failed', 'error': printErr.toString()},
          );
        } catch (reportErr) {
          _log(LogLevel.error,
              'Could not notify server of job failure: $reportErr');
        }
        return false;
      }
    } catch (err) {
      _log(LogLevel.error, 'Poll error: $err');
      return false;
    }
  }

  /// Resolves the destination IP and delivers the decoded payload.
  Future<void> sendToPrinter(
      Map<String, dynamic>? printer, String contentBase64) async {
    final bytes = base64Decode(contentBase64);
    final jobPrinterIp = (printer?['ip'] as String?)?.trim() ?? '';

    if (jobPrinterIp.isNotEmpty) {
      _log(LogLevel.info,
          'Sending to job-specific IP printer at $jobPrinterIp:${config.printerPort}');
      return sendToIpWithRetry(jobPrinterIp, config.printerPortInt, bytes);
    }
    if (config.printerIp.trim().isNotEmpty) {
      _log(LogLevel.info,
          'Sending to default configured printer at ${config.printerIp}:${config.printerPort}');
      return sendToIpWithRetry(
          config.printerIp.trim(), config.printerPortInt, bytes);
    }
    throw Exception(
        'No printer IP configured. Please configure Printer IP in settings.');
  }

  /// Sends raw bytes to TCP socket with connection retries and timeout protection.
  Future<void> sendToIpWithRetry(String ip, int port, List<int> bytes,
      {int maxRetries = 2}) async {
    int attempt = 0;
    Exception? lastException;

    while (attempt <= maxRetries) {
      Socket? socket;
      try {
        if (attempt > 0) {
          _log(LogLevel.warn,
              'Retrying printer connection to $ip:$port (attempt ${attempt + 1}/${maxRetries + 1})...');
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }

        socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(seconds: 6),
        );
        socket.setOption(SocketOption.tcpNoDelay, true);
        socket.add(bytes);
        await socket.flush().timeout(const Duration(seconds: 8));
        return; // Success
      } on SocketException catch (se) {
        lastException = se;
        _log(LogLevel.warn,
            'SocketException on $ip:$port (OS Error: ${se.osError?.message ?? se.message})');
      } on TimeoutException catch (te) {
        lastException = te;
        _log(LogLevel.warn, 'Socket timed out on $ip:$port');
      } catch (e) {
        lastException = Exception(e.toString());
        _log(LogLevel.warn, 'Unexpected socket error on $ip:$port: $e');
      } finally {
        socket?.destroy();
      }
      attempt++;
    }

    throw Exception(
        'Printer offline or unreachable at $ip:$port. ${lastException?.toString() ?? ""}');
  }

  /// Tests connectivity to the printer socket with a short timeout.
  Future<bool> testPrinterConnection() async {
    final ip = config.printerIp.trim();
    if (ip.isEmpty) {
      _log(LogLevel.warn, 'Printer test aborted: No printer IP configured.');
      return false;
    }
    Socket? socket;
    try {
      _log(LogLevel.info,
          'Testing TCP socket connectivity to $ip:${config.printerPortInt}...');
      socket = await Socket.connect(
        ip,
        config.printerPortInt,
        timeout: const Duration(seconds: 4),
      );
      _log(LogLevel.info, 'Printer connection test PASSED at $ip');
      return true;
    } on SocketException catch (se) {
      _log(LogLevel.warn,
          'Printer unreachable at $ip:${config.printerPortInt} (${se.osError?.message ?? se.message})');
      return false;
    } catch (err) {
      _log(LogLevel.warn, 'Printer test failed: $err');
      return false;
    } finally {
      socket?.destroy();
    }
  }

  /// Sends a structured ESC/POS test receipt to verify thermal printing and paper feed/cut.
  Future<bool> testPrintSample() async {
    final ip = config.printerIp.trim();
    if (ip.isEmpty) return false;

    try {
      _log(LogLevel.info,
          'Generating ESC/POS test receipt for $ip:${config.printerPort}');
      final escposBytes = _buildEscPosSampleReceipt();
      await sendToIpWithRetry(ip, config.printerPortInt, escposBytes);
      _log(LogLevel.info, 'ESC/POS test receipt sent successfully');
      return true;
    } catch (err) {
      _log(LogLevel.error, 'ESC/POS test print failed: $err');
      return false;
    }
  }

  /// Constructs a standard ESC/POS formatted test receipt.
  List<int> _buildEscPosSampleReceipt() {
    final bytes = <int>[];

    // ESC @: Initialize printer
    bytes.addAll([0x1B, 0x40]);

    // ESC a 1: Center alignment
    bytes.addAll([0x1B, 0x61, 0x01]);

    // GS ! 0x11: Double height & double width
    bytes.addAll([0x1D, 0x21, 0x11]);
    bytes.addAll(utf8.encode('RESTROSANJAL\n'));

    // GS ! 0x00: Normal font
    bytes.addAll([0x1D, 0x21, 0x00]);
    bytes.addAll(utf8.encode('PRINT BRIDGE v1.0\n'));

    // ESC a 0: Left alignment
    bytes.addAll([0x1B, 0x61, 0x00]);
    bytes.addAll(utf8.encode('--------------------------------\n'));
    bytes.addAll(utf8.encode('STATUS    : READY / CONNECTED\n'));
    bytes.addAll(utf8.encode('PRINTER IP: ${config.printerIp}\n'));
    bytes.addAll(utf8.encode('PORT      : ${config.printerPort}\n'));
    bytes.addAll(utf8.encode('BACKEND   : ${config.cleanServerUrl}\n'));
    final now = DateTime.now().toLocal().toString().split('.').first;
    bytes.addAll(utf8.encode('DATE/TIME : $now\n'));
    bytes.addAll(utf8.encode('--------------------------------\n'));

    // ESC a 1: Center alignment
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll(utf8.encode('*** TEST PRINT SUCCESSFUL ***\n\n'));

    // ESC d 4: Feed 4 lines
    bytes.addAll([0x1B, 0x64, 0x04]);

    // GS V 66 0: Partial cut with feed
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return bytes;
  }

  /// Automatically discovers thermal printers listening on port 9100 on the local subnet.
  Future<List<String>> discoverLocalPrinters(
      {void Function(String progress)? onProgress}) async {
    final discovered = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final candidatePrefixes = <String>{};
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              candidatePrefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
            }
          }
        }
      }

      if (candidatePrefixes.isEmpty) {
        // Fallback default private subnet
        candidatePrefixes.add('192.168.1');
      }

      final port = config.printerPortInt;
      for (final prefix in candidatePrefixes) {
        onProgress?.call('Scanning subnet $prefix.0/24 on port $port...');

        // Scan common static IP ranges for thermal printers first (e.g. 50-150, 190-254) in batches
        const int batchSize = 25;
        for (int i = 1; i <= 254; i += batchSize) {
          final end = (i + batchSize - 1 > 254) ? 254 : i + batchSize - 1;
          final futures = <Future<String?>>[];

          for (int host = i; host <= end; host++) {
            final ip = '$prefix.$host';
            futures.add(_probeIp(ip, port));
          }

          final results = await Future.wait(futures);
          for (final found in results) {
            if (found != null && !discovered.contains(found)) {
              discovered.add(found);
              onProgress?.call('Found printer at $found');
            }
          }
        }
      }
    } catch (e) {
      _log(LogLevel.warn, 'Printer discovery encountered error: $e');
    }
    return discovered;
  }

  Future<String?> _probeIp(String ip, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 350),
      );
      return ip;
    } catch (_) {
      return null;
    } finally {
      socket?.destroy();
    }
  }
}
