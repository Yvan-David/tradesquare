import 'package:dio/dio.dart';

/// HTTP client for the TradeSquare FastAPI backend (which reads Supabase/Postgres).
class TradeSquareApiClient {
  TradeSquareApiClient({
    String? baseUrl,
    Dio? dio,
  })  : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'TRADESQUARE_API_BASE_URL',
              defaultValue: 'http://localhost:8000',
            ),
        _dio = dio ?? Dio();

  final String baseUrl;
  final Dio _dio;

  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, dynamic>? query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$baseUrl$path',
      queryParameters: query,
      options: Options(
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$baseUrl$path',
      data: body,
      options: Options(
        responseType: ResponseType.json,
        contentType: 'application/json',
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    return response.data ?? <String, dynamic>{};
  }
}
