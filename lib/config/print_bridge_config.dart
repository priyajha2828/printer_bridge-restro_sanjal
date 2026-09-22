/// Configuration for the print bridge.
///
/// This mirrors the fields that used to live in the Node.js `.env` file:
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
    this.serverUrl = 'http://localhost',
    this.bridgeToken = '',
    this.clientId = '',
    this.printerIp = '',
    this.printerPort = '9100',
    this.pollInterval = '3000',
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

  factory BridgeConfig.fromMap(Map<String, String> map) => BridgeConfig(
    serverUrl: map['serverUrl'] ?? 'http://localhost',
    bridgeToken: map['bridgeToken'] ?? '',
    clientId: map['clientId'] ?? '',
    printerIp: map['printerIp'] ?? '',
    printerPort: map['printerPort'] ?? '9100',
    pollInterval: map['pollInterval'] ?? '3000',
    logLevel: map['logLevel'] ?? 'info',
  );

  /// Strips trailing slashes, same as the Node version's SERVER_URL handling.
  String get cleanServerUrl => serverUrl.replaceAll(RegExp(r'/+$'), '');

  /// Poll interval in ms, floored at 1000ms just like the original.
  int get pollIntervalMs {
    final v = int.tryParse(pollInterval) ?? 3000;
    return v < 1000 ? 1000 : v;
  }

  int get printerPortInt => int.tryParse(printerPort) ?? 9100;

  bool get isValid => bridgeToken.trim().isNotEmpty && serverUrl.trim().isNotEmpty;
}
