import 'package:dio/dio.dart';

/// A normalized error surface for the UI layer.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;

  /// Laravel 422 validation bag: { field: [messages] }.
  final Map<String, List<String>>? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidation => statusCode == 422;

  String? firstErrorFor(String field) => errors?[field]?.firstOrNull;

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    final data = response?.data;

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return ApiException(
        'Cannot reach the MChart server. Check your connection.',
        statusCode: null,
      );
    }

    if (data is Map) {
      final rawErrors = data['errors'];
      Map<String, List<String>>? parsed;
      if (rawErrors is Map) {
        parsed = rawErrors.map(
          (key, value) => MapEntry(
            key.toString(),
            (value as List).map((m) => m.toString()).toList(),
          ),
        );
      }
      return ApiException(
        (data['message'] ?? 'Something went wrong.').toString(),
        statusCode: response?.statusCode,
        errors: parsed,
      );
    }

    return ApiException(
      'Something went wrong (${response?.statusCode ?? 'network'}).',
      statusCode: response?.statusCode,
    );
  }

  @override
  String toString() => message;
}
