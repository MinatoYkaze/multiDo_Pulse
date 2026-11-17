import 'package:dio/dio.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final DioExceptionType? dioType;

  const ApiException(this.message, {this.statusCode, this.dioType});

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  bool get isTimeout =>
      dioType == DioExceptionType.connectionTimeout ||
      dioType == DioExceptionType.sendTimeout ||
      dioType == DioExceptionType.receiveTimeout;
  bool get isConnectionTimeout =>
      dioType == DioExceptionType.connectionTimeout;
  bool get isSendTimeout => dioType == DioExceptionType.sendTimeout;
  bool get isReceiveTimeout =>
      dioType == DioExceptionType.receiveTimeout;

  /// Converts any Dio error into a user-presentable message
  /// (understands FastAPI's `{"detail": ...}` payloads, including 422 lists).
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final code = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        final d = data['detail'];
        if (d is String) {
          return ApiException(d, statusCode: code, dioType: error.type);
        }
        if (d is List && d.isNotEmpty) {
          final first = d.first;
          final msg = first is Map
              ? '${(first['loc'] as List?)?.last ?? 'field'}: ${first['msg']}'
              : first.toString();
          return ApiException(msg, statusCode: code, dioType: error.type);
        }
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return ApiException(
            'Connection timed out. The server may be waking up or unreachable.',
            statusCode: code,
            dioType: error.type,
          );
        case DioExceptionType.sendTimeout:
          return ApiException(
            'Upload timed out while sending request data.',
            statusCode: code,
            dioType: error.type,
          );
        case DioExceptionType.receiveTimeout:
          return ApiException(
            'Server response timed out. The operation may still be processing on the server.',
            statusCode: code,
            dioType: error.type,
          );
        case DioExceptionType.connectionError:
          return ApiException(
            'No connection to the server.',
            statusCode: code,
            dioType: error.type,
          );
        default:
          return ApiException(
            error.message ?? 'Unexpected network error',
            statusCode: code,
            dioType: error.type,
          );
      }
    }
    return ApiException(error.toString());
  }

  @override
  String toString() => message;
}
