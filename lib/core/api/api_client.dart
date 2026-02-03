// *****************************************************************************************
// * Filename: api_client.dart                                                             *
// * Developer: Deval Joshi                                                                *
// * Date: 11 October 2024                                                                 *                      *
// * Description: This file contains the ApiClient class, responsible for making HTTP      *
// * requests (GET, POST, PUT, DELETE). It includes error handling for network issues,     *
// * server errors, and invalid responses, while logging each request and response.        *
// *****************************************************************************************

import 'package:dio/dio.dart';
import 'package:stanchat/core/api/api_endpoint.dart';
import 'package:stanchat/core/error/app_error.dart';
import 'package:stanchat/utils/logger.dart';
import 'package:stanchat/utils/network_info.dart';
import 'package:stanchat/utils/preference_key/preference_key.dart';
import 'package:stanchat/utils/preference_key/sharedpref_key.dart';

class ApiClient {
  final Dio _dio;
  final NetworkInfo _networkInfo;
  final _logger = ConsoleAppLogger.forModule('ApiClient');

  ApiClient(this._dio, this._networkInfo) {
    _initializeDio();
  }

  Future<void> _initializeDio() async {
    // String? token = await SecurePrefs.getString(SecureStorageKeys.TOKEN) ?? '';

    _dio.options.baseUrl = ApiEndpoints.baseUrl;

    // Set up headers with bearer token authentication
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // // Add Authorization header if token exists
    // if (authToken.isNotEmpty) {
    //   _dio.options.headers['Authorization'] = 'Bearer $authToken';
    // }

    // Add logging interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 🔄 Always get the latest token before each request
          final token =
              await SecurePrefs.getString(SecureStorageKeys.TOKEN) ?? '';
          if (token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          _logger.i('API Request: ${options.method} ${options.path}');
          _logger.d('Headers: ${options.headers}');
          _logger.d('Data: ${options.data}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d('Response status: ${response.statusCode}');
          _logger.d('Response data: ${response.data}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          _logger.e('Request error: ${e.message}', e);
          return handler.next(e);
        },
      ),
    );
  }

  Future<dynamic> request(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (!await _networkInfo.isConnected) {
      _logger.e('No internet connection');

      throw AppError('No internet connection');
    }

    try {
      late Response response;

      switch (method) {
        case 'GET':
          _logger.d('Sending GET request to $endpoint');
          response = await _dio.get(endpoint, data: body);
          break;
        case 'POST':
          _logger.d('Sending POST request to $endpoint with body: $body');
          response = await _dio.post(endpoint, data: body);
          break;
        case 'PUT':
          _logger.d('Sending PUT request to $endpoint with body: $body');
          response = await _dio.put(endpoint, data: body);
          break;
        case 'DELETE':
          _logger.d('Sending DELETE request to $endpoint');
          response = await _dio.delete(endpoint, data: body);
          break;
        default:
          _logger.e('Unsupported HTTP method: $method');
          throw AppError('Unsupported HTTP method');
      }

      _logger.i('Request successful');
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    } catch (e) {
      _logger.e('Request failed', e);
      throw AppError('Request failed: $e');
    }
  }

  // Future<dynamic> multipartRequest(
  //   String endpoint, {
  //   required Map<String, dynamic> body,
  //   required Map<String, String> files,
  // }) async {
  //   if (!await _networkInfo.isConnected) {
  //     _logger.e('No internet connection');
  //     throw AppError('No internet connection');
  //   }

  //   try {
  //     FormData formData = FormData.fromMap(body);
  //     for (var entry in files.entries) {
  //       String fileName = entry.value.split('/').last;
  //       formData.files.add(
  //         MapEntry(
  //           entry.key,
  //           await MultipartFile.fromFile(entry.value, filename: fileName),
  //         ),
  //       );
  //     }

  //     _logger.d('Sending multipart request to $endpoint');
  //     Response response = await _dio.post(endpoint, data: formData);
  //     _logger.i('Multipart request successful');
  //     return response.data;
  //   } on DioException catch (e) {
  //     _handleDioException(e);
  //   } catch (e) {
  //     _logger.e('Multipart request failed', e);
  //     throw AppError('Multipart request failed: $e');
  //   }
  // }

  Future<dynamic> multipartRequest(
    String endpoint, {
    required Map<String, dynamic> body,
    required Map<String, dynamic> files, // Changed from Map<String, String>
  }) async {
    if (!await _networkInfo.isConnected) {
      _logger.e('No internet connection');
      throw AppError('No internet connection');
    }

    try {
      FormData formData = FormData.fromMap(body);

      for (var entry in files.entries) {
        if (entry.value is String) {
          // Single file
          String fileName = entry.value.split('/').last;
          formData.files.add(
            MapEntry(
              entry.key,
              await MultipartFile.fromFile(entry.value, filename: fileName),
            ),
          );
        } else if (entry.value is List<String>) {
          // Multiple files
          for (String filePath in entry.value) {
            String fileName = filePath.split('/').last;
            formData.files.add(
              MapEntry(
                entry.key,
                await MultipartFile.fromFile(filePath, filename: fileName),
              ),
            );
          }
        }
      }

      _logger.d('Sending multipart request to $endpoint');
      Response response = await _dio.post(endpoint, data: formData);
      _logger.i('Multipart request successful');
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    } catch (e) {
      _logger.e('Multipart request failed', e);
      throw AppError('Multipart request failed: $e');
    }
  }

  void _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        _logger.e('Network timeout', e);
        throw AppError('Network timeout. Please try again.');
      case DioExceptionType.connectionError:
        _logger.e('Connection error', e);
        throw AppError(
          'Connection error. Please check your internet connection.',
        );
      case DioExceptionType.badResponse:
        _logger.e('Server error: ${e.response?.statusCode}', e);
        // throw AppError('Server error: ${e.response?.statusCode ?? "Unknown"}');
        final responseData = e.response?.data;
        final printResponse = responseData;
        _logger.d('printResponse: $printResponse');

        String message = 'Server error: ${e.response?.statusCode ?? "Unknown"}';

        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('message')) {
          message = responseData['message'].toString();
        }

        throw AppError(message);
      case DioExceptionType.badCertificate:
        _logger.e('Bad certificate', e);
        throw AppError('Security error. Invalid certificate.');
      case DioExceptionType.cancel:
        _logger.e('Request cancelled', e);
        throw AppError('Request cancelled');
      default:
        _logger.e('Network error', e);
        throw AppError('Network error: ${e.message}');
    }
  }
}
