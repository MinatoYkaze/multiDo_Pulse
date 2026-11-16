import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:obsidian_todo/core/network/api_client.dart';
import 'package:obsidian_todo/core/network/api_exception.dart';
import 'package:obsidian_todo/core/models/models.dart';
import 'package:obsidian_todo/features/groups/data/ai_repository.dart';

class _TimeoutCapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  DioException? exceptionToThrow;
  ResponseBody? responseToReturn;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return responseToReturn ??
        ResponseBody.fromString(
          '{"message": "Hello from AI"}',
          200,
          headers: {
            'content-type': ['application/json'],
          },
        );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Timeout and Idempotency Tests', () {
    test('ApiException correctly classifies receiveTimeout', () {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/ai/chat'),
        type: DioExceptionType.receiveTimeout,
        message: 'Receiving data timed out',
      );
      final apiErr = ApiException.from(dioErr);

      expect(apiErr.isTimeout, isTrue);
      expect(apiErr.isReceiveTimeout, isTrue);
      expect(apiErr.isConnectionTimeout, isFalse);
      expect(apiErr.isSendTimeout, isFalse);
      expect(apiErr.message, contains('Server response timed out'));
    });

    test('ApiException correctly classifies connectionTimeout', () {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/ai/chat'),
        type: DioExceptionType.connectionTimeout,
        message: 'Connecting timed out',
      );
      final apiErr = ApiException.from(dioErr);

      expect(apiErr.isTimeout, isTrue);
      expect(apiErr.isConnectionTimeout, isTrue);
      expect(apiErr.isReceiveTimeout, isFalse);
      expect(apiErr.message, contains('Connection timed out'));
    });

    test('ApiClient passes custom timeout options to Dio', () async {
      final adapter = _TimeoutCapturingAdapter();
      final dio = Dio(BaseOptions(
        baseUrl: 'https://taskflow-api-v1-225t.onrender.com',
        receiveTimeout: const Duration(seconds: 30),
      ));
      dio.httpClientAdapter = adapter;
      final client = ApiClient(dio);

      // Default timeout call inherits BaseOptions (30s)
      await client.post('/test', parse: (d) => d);
      expect(adapter.lastOptions?.receiveTimeout, const Duration(seconds: 30));

      // Dedicated custom timeout call overrides to 90s
      await client.post(
        '/ai/chat',
        timeout: const Duration(seconds: 90),
        parse: (d) => d,
      );
      expect(adapter.lastOptions?.receiveTimeout, const Duration(seconds: 90));
    });

    test('AIRepository.chat uses dedicated 90-second receiveTimeout', () async {
      final adapter = _TimeoutCapturingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://taskflow-api-v1-225t.onrender.com'));
      dio.httpClientAdapter = adapter;
      final client = ApiClient(dio);
      final aiRepo = AIRepository(client);

      final res = await aiRepo.chat(const AIChatRequest(
        threadId: 'th-123',
        message: 'list my tasks',
      ));

      expect(res.message, 'Hello from AI');
      expect(adapter.lastOptions?.receiveTimeout, const Duration(seconds: 90));
      expect(adapter.lastOptions?.path, '/ai/chat');
    });
  });
}
