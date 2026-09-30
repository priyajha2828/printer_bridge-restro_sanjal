/// Core API constants for RestroSanjal Print Bridge.
class ApiConstant {
  /// Production Backend Base URL
  static const String baseUrl = 'https://restrosanjal.com';

  /// Default printer port for ESC/POS & TSPL network thermal printers
  static const String defaultPrinterPort = '9100';

  /// Default polling interval in milliseconds
  static const String defaultPollInterval = '3000';


  /// Endpoints
  static const String statusEndpoint = '/api/print-bridge/status';
  static const String nextJobEndpoint = '/api/print-bridge/jobs/next';
  static String completeJobEndpoint(String jobId) =>
      '/api/print-bridge/jobs/$jobId/complete';

  /// Request headers
  static const String headerToken = 'X-Print-Bridge-Token';
  static const String headerClientId = 'X-Client-Id';
}
