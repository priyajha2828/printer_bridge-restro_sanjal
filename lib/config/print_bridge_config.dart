import '../core/constants/api_constant.dart';

/// Configuration for the print bridge.
///
/// Mirrors the fields configured for the RestroSanjal Print Bridge:
/// SERVER_URL, BRIDGE_TOKEN, CLIENT_ID, PRINTER_IP, PRINTER_PORT,
/// POLL_INTERVAL, LOG_LEVEL.
class BridgeConfig {
  final String serverUrl;
  final String bridgeToken;
  final String clientId;
  final String printerIp;
  final String printerPort;
  final String pollInterval;
  final String logLevel;

  const BridgeConfig({
    this.serverUrl = ApiConstant.baseUrl,
    this.bridgeToken = '',
    this.clientId = '',
    this.printerIp = '',
    this.printerPort = ApiConstant.defaultPrinterPort,
    this.pollInterval = ApiConstant.defaultPollInterval,
    this.logLevel = 'info',
  });

  BridgeConfig copyWith({
    String? serverUrl,
    String? bridgeToken,
    String? clientId,
    String? printerIp,
    String? printerPort,
    String? pollInterval,
    String? logLevel,
  }) {
    return BridgeConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      bridgeToken: bridgeToken ?? this.bridgeToken,
      clientId: clientId ?? this.clientId,
      printerIp: printerIp ?? this.printerIp,
      printerPort: printerPort ?? this.printerPort,
      pollInterval: pollInterval ?? this.pollInterval,
      logLevel: logLevel ?? this.logLevel,
    );
  }

  Map<String, String> toMap() => {
    'serverUrl': serverUrl,
    'bridgeToken': bridgeToken,
    'clientId': clientId,
    'printerIp': printerIp,
    'printerPort': printerPort,
    'pollInterval': pollInterval,
    'logLevel': logLevel,
  };

  factory BridgeConfig.fromMap(Map<String, String> map) {
    final rawUrl = map['serverUrl'];
    // Migrate any legacy localhost values to the production baseUrl
    final resolvedUrl = (rawUrl == null ||
            rawUrl.isEmpty ||
            rawUrl.contains('localhost') ||
            rawUrl.contains('127.0.0.1') ||
            rawUrl.contains('10.0.2.2'))
        ? ApiConstant.baseUrl
        : rawUrl;

    return BridgeConfig(
      serverUrl: resolvedUrl,
      bridgeToken: map['bridgeToken'] ?? '',
      clientId: map['clientId'] ?? '',
      printerIp: map['printerIp'] ?? '',
      printerPort: map['printerPort'] ?? ApiConstant.defaultPrinterPort,
      pollInterval: map['pollInterval'] ?? ApiConstant.defaultPollInterval,
      logLevel: map['logLevel'] ?? 'info',
    );
  }

  /// Strips trailing slashes from the server URL.
  String get cleanServerUrl => serverUrl.replaceAll(RegExp(r'/+$'), '');

  /// Poll interval in ms, floored at 1000ms.
  int get pollIntervalMs {
    final v = int.tryParse(pollInterval) ?? 3000;
    return v < 1000 ? 1000 : v;
  }

  int get printerPortInt =>
      int.tryParse(printerPort) ?? int.parse(ApiConstant.defaultPrinterPort);

  bool get isValid =>
      bridgeToken.trim().isNotEmpty && serverUrl.trim().isNotEmpty;
}
