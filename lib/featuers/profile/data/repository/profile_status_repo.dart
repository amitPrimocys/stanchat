import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/auth/data/models/user_profile_model.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';
import 'package:whoxa/utils/logger.dart';

class ProfileStatusRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  ProfileStatusRepository(this._apiClient);

  UserProfileModel userProfileModel = UserProfileModel();
  Future<UserProfileModel> profileStatusRepo({
    required bool isGetData,
    required String status,
  }) async {
    _logger.i('Adding new status: $status');

    try {
      final dynamic response;
      if (isGetData) {
        response = await _apiClient.request(
          ApiEndpoints.userCreateProfile,
          method: 'POST',
          body: {},
        );
      } else {
        response = await _apiClient.request(
          ApiEndpoints.userCreateProfile,
          method: "POST",
          body: {'bio': status},
        );
      }
      return userProfileModel = UserProfileModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding status:', e.toString());
      rethrow;
    }
  }

  // Get peer user profile by user_id
  Future<UserNameCheckModel> getPeerUserProfileRepo(int userId) async {
    _logger.i('Getting peer user profile for user_id: $userId');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.userNameCheck,
        method: 'POST',
        body: {'user_id': userId.toString()},
      );

      // Add additional error handling for empty response
      if (response == null) {
        throw Exception('Empty response from server');
      }

      final result = UserNameCheckModel.fromJson(response);

      // Additional validation
      if (result.status != true) {
        throw Exception(result.message ?? 'Failed to get user profile');
      }

      return result;
    } catch (e) {
      _logger.e('Error getting peer user profile:', e.toString());
      rethrow;
    }
  }
}
