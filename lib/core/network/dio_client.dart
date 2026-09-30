import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/api_constant.dart';

/// Callback type for forwarding network logs to the UI activity logger.
typedef DioLogCallback = void Function(String message, {bool isError});

/// Production-ready Dio network client for RestroSanjal Print Bridge.
class DioClient {
  static String _bridgeToken = '';
  static String _clientId = '';
  static DioLogCallback? logCallback;

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: ApiConstant.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      responseType: ResponseType.json,
    ),
  )..interceptors.addAll([
      _AuthInterceptor(),
      _LoggingInterceptor(),
      _RetryInterceptor(),
      _ErrorInterceptor(),
    ]);

  /// Update the authorization token used for subsequent requests.
  static void setAuthToken(String token) {
    _bridgeToken = token.trim();
  }

  /// Update the client identifier used for subsequent requests.
  static void setClientId(String clientId) {
    _clientId = clientId.trim();
  }

  /// Update base URL dynamically when custom server URL is configured.
  static void updateBaseUrl(String url) {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleanUrl.isNotEmpty) {
      dio.options.baseUrl = cleanUrl;
    }
  }

  /// Current active token
  static String get bridgeToken => _bridgeToken;

  /// Current active client ID
  static String get clientId => _clientId;
}

/// Request & Auth interceptor injecting required Print Bridge headers.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (DioClient._bridgeToken.isNotEmpty) {
      options.headers[ApiConstant.headerToken] = DioClient._bridgeToken;
    }
    if (DioClient._clientId.isNotEmpty) {
      options.headers[ApiConstant.headerClientId] = DioClient._clientId;
    }
    handler.next(options);
  }
}

/// Logging interceptor with optional hook to the app activity log.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final logMsg = '--> ${options.method} ${options.uri}';
    DioClient.logCallback?.call(logMsg);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final logMsg =
        '<-- ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}';
    DioClient.logCallback?.call(logMsg);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final logMsg =
        '<-- ERROR [${err.response?.statusCode ?? err.type.name}] ${err.requestOptions.uri}: ${err.message}';
    DioClient.logCallback?.call(logMsg, isError: true);
    handler.next(err);
  }
}

/// Robust retry interceptor with exponential backoff for network/transient failures.
class _RetryInterceptor extends Interceptor {
  static const int maxRetries = 2;
  static const List<Duration> delays = [
    Duration(milliseconds: 500),
    Duration(milliseconds: 1000),
  ];

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;
    final retryCount = requestOptions.extra['retry_count'] as int? ?? 0;

    // Retry only on network connection failures, receive timeouts, or 502/503/504 server errors
    final isRetryable = err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        (err.response != null &&
            (err.response!.statusCode == 502 ||
                err.response!.statusCode == 503 ||
                err.response!.statusCode == 504));

    if (isRetryable && retryCount < maxRetries) {
      requestOptions.extra['retry_count'] = retryCount + 1;
      final delay = delays[retryCount];
      await Future<void>.delayed(delay);

      try {
        final response = await DioClient.dio.fetch(requestOptions);
        return handler.resolve(response);
      } on DioException catch (e) {
        return handler.next(e);
      } catch (e) {
        return handler.next(
          DioException(
            requestOptions: requestOptions,
            error: e,
            type: DioExceptionType.unknown,
          ),
        );
      }
    }

    handler.next(err);
  }
}

/// Comprehensive error interceptor converting Dio exceptions into clear, human-readable errors.
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String readableMessage;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        readableMessage =
            'Connection timed out. Please check your internet or server responsiveness.';
        break;
      case DioExceptionType.connectionError:
        readableMessage =
            'Cannot reach server at ${err.requestOptions.baseUrl}. Check network connectivity.';
        break;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        if (status == 401 || status == 403) {
          readableMessage =
              'Authentication failed (HTTP $status). Verify your Bridge Token in Settings > Printer Setup.';
        } else if (status == 404) {
          readableMessage = 'API endpoint not found (HTTP 404).';
        } else if (status != null && status >= 500) {
          readableMessage = 'Server error (HTTP $status). Please try again later.';
        } else {
          readableMessage = 'Server returned HTTP $status: ${err.response?.data}';
        }
        break;
      case DioExceptionType.cancel:
        readableMessage = 'Request was cancelled.';
        break;
      default:
        readableMessage = err.message ?? 'Unexpected network error occurred.';
    }

    final modifiedException = err.copyWith(
      error: readableMessage,
      message: readableMessage,
    );

    handler.next(modifiedException);
  }
}
