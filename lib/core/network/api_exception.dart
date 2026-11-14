import 'package:dio/dio.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  const ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  /// Converts any Dio error into a user-presentable message
  /// (understands FastAPI's `{"detail": ...}` payloads, including 422 lists).
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final code = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        final d = data['detail'];
        if (d is String) return ApiException(d, statusCode: code);
        if (d is List && d.isNotEmpty) {
          final first = d.first;
          final msg = first is Map
              ? '${(first['loc'] as List?)?.last ?? 'field'}: ${first['msg']}'
              : first.toString();
          return ApiException(msg, statusCode: code);
        }
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const ApiException('Request timed out. Please try again.');
        case DioExceptionType.connectionError:
          return const ApiException('No connection to the server.');
        default:
          return ApiException(error.message ?? 'Unexpected network error',
              statusCode: code);
      }
    }
    return ApiException(error.toString());
  }

  @override
  String toString() => message;
}
