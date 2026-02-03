import 'dart:io';

import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/auth/data/models/login_model.dart';
import 'package:whoxa/featuers/auth/data/models/otp_model.dart';
import 'package:whoxa/featuers/auth/data/models/user_delete_model.dart';
import 'package:whoxa/featuers/auth/data/models/logout_model.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';
import 'package:whoxa/featuers/auth/data/models/user_profile_model.dart';
import 'package:whoxa/featuers/auth/data/models/avatar_model.dart';
import 'package:whoxa/utils/logger.dart';

class LoginRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  LoginRepository(this._apiClient);

  //=============================================================================================================================
  //===================================================== Login email/mobile method =============================================
  //=============================================================================================================================
  LoginModel loginModel = LoginModel();
  Future<LoginModel> emailLoginRepository(String email) async {
    String device = Platform.isIOS ? 'ios' : 'android';
    _logger.i('Adding new email: $email');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.registerEmail,
        method: 'POST',
        body: {'email': email, 'login_type': 'email', 'platform': device},
      );
      _logger.i('Email added successfully');
      return loginModel = LoginModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding email:', e.toString());
      rethrow;
    }
  }

  Future<LoginModel> mobileLoginRepository(
    String countryCode,
    String phoneNumber,
    String countryFullName,
    String selectedCountrySortName,
  ) async {
    String device = Platform.isIOS ? 'ios' : 'android';
    _logger.i('Adding new mobile: $phoneNumber');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.registerPhone,
        method: 'POST',
        body: {
          'login_type': 'phone',
          'country': countryFullName,
          'country_code': countryCode,
          'mobile_num': phoneNumber,
          'country_short_name': selectedCountrySortName,
          'platform': device,
        },
      );
      _logger.i('Mobile added successfully');
      return loginModel = LoginModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding mobile:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== OTP email/mobile method ===============================================
  //=============================================================================================================================
  VerifyOTPModel otpModel = VerifyOTPModel();

  Future<VerifyOTPModel> otpRepository({
    required bool isEmail,
    required String countryCode,
    required String phoneNumber,
    required String email,
    required String otp,
    required String fcmtoken,
    required String oneSignalId,
  }) async {
    _logger.i('Adding new otp: $otp');
    _logger.i('Adding new fcmtoken: $fcmtoken');
    _logger.i('Adding new oneSignalId: $oneSignalId');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.verifyOtpEmail,
        method: 'POST',
        body:
            isEmail
                ? {
                  'email': email,
                  'otp': otp,
                  'login_type': 'email',
                  'device_token': oneSignalId,
                }
                : {
                  // 'country_code': countryCode,
                  'mobile_num': phoneNumber,
                  'otp': otp,
                  'login_type': 'phone', 'device_token': oneSignalId,
                },
      );
      return otpModel = VerifyOTPModel.fromJson(response);

      // // ✅ Store the resData into shared preferences
      // if (otpModel.resData != null) {
      //   await SharedPrefs.setModel(
      //     SharedPreferencesKey.OTPRESPONSEDATA,
      //     otpModel.resData!,
      //   );
      //   ResData? user = SharedPrefs.getModel<ResData>(
      //     SharedPreferencesKey.OTPRESPONSEDATA,
      //     (json) => ResData.fromJson(json),
      //   );

      //   _logger.i('User data saved to SharedPrefs');
      // }

      // _logger.i('OTP verification successful');
      // return VerifyOTPModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding otp:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== User name check method ================================================
  //=============================================================================================================================
  UserNameCheckModel userNameCheckModel = UserNameCheckModel();

  Future<UserNameCheckModel> userNameCheckRepo(String xyz) async {
    _logger.i('Adding new user_name: $xyz');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.userNameCheck,
        method: 'POST',
        body: {'user_name': xyz, 'user_check': true},
      );

      return userNameCheckModel = UserNameCheckModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding user_name:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== User add Profiel method ===============================================
  //=============================================================================================================================
  UserProfileModel userProfileModel = UserProfileModel();
  Future<UserProfileModel> userProfileAddRepo(
    File? image, {
    required String userName,
    required String fname,
    required String lname,
    required String country,
    required String gender,
    required String deviceToken,
    // required String email,
    required String countryCode,
    required String mobile,
    String? avatarUrl,
    String pictureType = 'profile_pic',
  }) async {
    _logger.v('Adding new user_name: $userName');
    _logger.v('Adding new user_fname: $fname');
    _logger.v('Adding new user_lname: $lname');
    _logger.v('Adding new user_country: $country');
    _logger.v('Adding new user_gender: $gender');
    _logger.v('Adding new deviceToken: $deviceToken');
    // _logger.v('Adding new email: $email');
    _logger.v('Adding picture type: $pictureType');
    _logger.v('Adding avatarUrl: $avatarUrl');

    Map<String, String> files = {};

    var bodyData = {
      'user_name': userName,
      'first_name': fname,
      'last_name': lname,
      'gender': gender,
      // 'device_token': '',
      // 'email': email,
      'country_code': countryCode,
      'mobile_num': mobile,
      // 'pictureType': pictureType,
    };

    if (image != null) {
      files['files'] = image.path;
      bodyData['pictureType'] = pictureType;
    }

    if (avatarUrl != null) {
      bodyData['avatarUrl'] = avatarUrl;
      bodyData['pictureType'] = pictureType;
    }

    try {
      final response = await _apiClient.multipartRequest(
        ApiEndpoints.userCreateProfile,
        body: bodyData,
        files: files,
      );
      _logger.d('data pass in userProfileAddRepo: $bodyData');

      // final response = await _apiClient.request(
      //   ApiEndpoints.userCreateProfile,
      //   method: 'POST',
      //   body: {
      //     'user_name': userName,
      //     'first_name': fname,
      //     'last_name': lname,
      //     'gender': gender,
      //     'device_token': '',
      //     'email_id': email,
      //     'one_signal_player_id': '',
      //   },
      // );

      return userProfileModel = UserProfileModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding user profile:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== User get Profiel method ===============================================
  //=============================================================================================================================
  Future<UserProfileModel> userProfileGetRepo() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.userCreateProfile,
        method: 'POST',
        body: {},
      );

      return userProfileModel = UserProfileModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding user profile:', e.toString());
      rethrow;
    }
  }

  DeleteAccModel deleteAccModel = DeleteAccModel();
  Future<DeleteAccModel> deleteUserRepo() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.deleteAcc,
        method: "DELETE",
        body: {},
      );

      return deleteAccModel = DeleteAccModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding user delete:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== User logout method ===============================================
  //=============================================================================================================================
  LogoutModel logoutModel = LogoutModel();
  Future<LogoutModel> logoutUserRepo({String? socketId}) async {
    _logger.i('Logging out user with socket_id: $socketId');
    try {
      final body = <String, dynamic>{};
      if (socketId != null && socketId.isNotEmpty) {
        body['socket_id'] = socketId;
      }

      final response = await _apiClient.request(
        ApiEndpoints.logout,
        method: "POST",
        body: body,
      );

      return logoutModel = LogoutModel.fromJson(response);
    } catch (e) {
      _logger.e('Error logging out user:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== Update Avatar Only method ===============================================
  //=============================================================================================================================
  Future<UserProfileModel> updateAvatarRepo({
    File? image,
    String? avatarUrl,
    String pictureType = 'profile_pic',
  }) async {
    _logger.i('Updating avatar only');
    _logger.i('Adding picture type: $pictureType');
    _logger.i('Adding avatarUrl: $avatarUrl');

    Map<String, String> files = {};
    var bodyData = <String, String>{};

    if (image != null) {
      files['files'] = image.path;
      bodyData['pictureType'] = pictureType;
      _logger.i('Adding image file: ${image.path}');
    }

    if (avatarUrl != null) {
      bodyData['avatarUrl'] = avatarUrl;
      bodyData['pictureType'] = pictureType;
    }

    try {
      final response = await _apiClient.multipartRequest(
        ApiEndpoints.userCreateProfile,
        body: bodyData,
        files: files,
      );
      _logger.d('Avatar update data: $bodyData');

      return userProfileModel = UserProfileModel.fromJson(response);
    } catch (e) {
      _logger.e('Error updating avatar:', e.toString());
      rethrow;
    }
  }

  //=============================================================================================================================
  //===================================================== Get All Avatars method ===============================================
  //=============================================================================================================================
  AvatarModel avatarModel = AvatarModel();

  Future<AvatarModel> getAllAvatarsRepo() async {
    _logger.i('Fetching all avatars');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.getAllAvatars,
        method: 'GET',
        body: {},
      );

      return avatarModel = AvatarModel.fromJson(response);
    } catch (e) {
      _logger.e('Error fetching avatars:', e.toString());
      rethrow;
    }
  }
}
