import 'dart:convert';

class AppError implements Exception {
  final String message;

  AppError(this.message);

  @override
  String toString() => 'AppError: $message';
}

Map<String, dynamic>? extractErrorData(AppError error) {
  String errorBody = error.toString();

  // Handle "No internet connection" case
  if (errorBody.contains('No internet connection')) {
    return {
      'success': false,
      'message': 'No internet connection. Please check your internet settings.',
    };
  }

  // Extract JSON from response body if present
  if (errorBody.contains('Response Body:')) {
    try {
      String jsonStr = errorBody.split('Response Body:')[1].trim();
      return jsonDecode(jsonStr);
    } catch (_) {
      // If JSON parsing fails, return the raw error message
      return {'success': false, 'message': error.message};
    }
  }

  // Default case: return the error message
  return {'success': false, 'message': error.message};
}
