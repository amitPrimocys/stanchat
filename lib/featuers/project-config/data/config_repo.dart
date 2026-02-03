// *****************************************************************************************
// * Filename: project_config_repository.dart                                              *
// * Developer: Deval Joshi                                             *
// * Date: 25 June 25
// * Description: Repository for handling project configuration API calls                 *
// *****************************************************************************************

import 'dart:ui';

import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/notification/model/mark_read_model.dart';
import 'package:whoxa/featuers/notification/model/notification_model.dart';
import 'package:whoxa/featuers/project-config/data/config_model.dart';

import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart';

class ProjectConfigRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  ProjectConfigRepository(this._apiClient);

  /// Fetches project configuration from the API
  /// Returns ProjectConfig object containing all configuration data
  Future<ProjectConfig> getProjectConfiguration() async {
    _logger.i('Fetching project configuration');

    try {
      final response = await _apiClient.request(
        ApiEndpoints.projectConfig,
        method: 'GET',
      );

      _logger.d('Project configuration fetched successfully');
      _logger.d('Response: $response');

      final projectConfig = ProjectConfig.fromJson(response);

      if (!projectConfig.status) {
        _logger.w('Project configuration API returned status: false');
        throw AppError(
          projectConfig.message.isNotEmpty
              ? projectConfig.message
              : 'Failed to fetch project configuration',
        );
      }

      _logger.i('Project configuration parsed successfully');
      _logger.d('App Name: ${projectConfig.data.appName}');
      _logger.d('Config ID: ${projectConfig.data.configId}');
      _logger.d('Phone Auth: ${projectConfig.data.phoneAuthentication}');
      _logger.d('Email Auth: ${projectConfig.data.emailAuthentication}');
      _logger.d('APP LOGO:${projectConfig.data.appLogoLight}');
      _logger.d('APP LOGO DARK:${projectConfig.data.appLogoDark}');

      await SecurePrefs.setMultiple({
        SecureStorageKeys.IS_PHONE_AUTH: projectConfig.data.phoneAuthentication,
        SecureStorageKeys.IS_EMAIL_AUTH: projectConfig.data.emailAuthentication,
        SecureStorageKeys.APP_LOGO: projectConfig.data.appLogoLight,
        SecureStorageKeys.APP_LOGO_DARK: projectConfig.data.appLogoDark,
        SecureStorageKeys.APP_NAME: projectConfig.data.appName,
        SecureStorageKeys.DEMO_CREDENTIAL: projectConfig.data.demoCredential,
      });
      await SecureStorageKeys().loadeBoolValuePrefes();
      appLogo = (await SecurePrefs.getString(SecureStorageKeys.APP_LOGO))!;
      appLogoDarkMode =
          (await SecurePrefs.getString(SecureStorageKeys.APP_LOGO_DARK))!;
      appName = (await SecurePrefs.getString(SecureStorageKeys.APP_NAME))!;
      termsConditionText = projectConfig.data.termsAndConditions;
      privacyPoicyText = projectConfig.data.privacyPolicy;
      demoCredential =
          (await SecurePrefs.getBool(SecureStorageKeys.DEMO_CREDENTIAL)) ??
          false;

      // ✅ THEME COLOR PRIORITY LOGIC
      // 1. Check if user has selected custom theme color
      // 2. If yes, use custom color; if no, use project config color
      final customThemeColor = await SecurePrefs.getString(
        SecureStorageKeys.customThemeColor,
      );

      if (customThemeColor != null && customThemeColor.isNotEmpty) {
        // Use custom theme color selected by user
        _logger.i("Using custom theme color: $customThemeColor");
        appPrimeColor = customThemeColor;
        appSecColor = customThemeColor;
      } else {
        // Use project config color (default)
        _logger.i(
          "Using project config color: ${projectConfig.data.appPrimaryColor}",
        );
        appPrimeColor = projectConfig.data.appPrimaryColor;
        //: only one color need to use that's why sec color set as primary
        appSecColor = projectConfig.data.appPrimaryColor;
      }

      appPrimeColor = appPrimeColor.replaceAll("#", "");
      appSecColor = appSecColor.replaceAll("#", "");
      int colorIntPrime = int.parse("0xFF$appPrimeColor");
      int colorIntSec = int.parse("0xFF$appSecColor");
      AppColors.appPriSecColor.primaryColor = Color(colorIntPrime);
      AppColors.appPriSecColor.secondaryColor = Color(colorIntSec);

      _logger.i("😊😊appLogo😊😊:$appLogo");
      _logger.i("😊😊appPrime😊😊:${AppColors.appPriSecColor.primaryColor}");
      _logger.i(
        "😊😊appSecColor😊😊:${AppColors.appPriSecColor.secondaryColor}",
      );

      return projectConfig;
    } catch (e) {
      _logger.e('Error fetching project configuration', e);

      if (e is AppError) {
        rethrow;
      }

      throw AppError('Failed to fetch project configuration: ${e.toString()}');
    }
  }

  /// Validates if the configuration response is valid
  // ignore: unused_element
  bool _isValidConfiguration(ProjectConfig config) {
    if (!config.status) {
      _logger.w('Configuration status is false');
      return false;
    }

    if (config.data.configId <= 0) {
      _logger.w('Invalid config ID: ${config.data.configId}');
      return false;
    }

    _logger.i('Configuration validation passed');
    return true;
  }

  /// Gets a safe/default configuration in case API fails
  ProjectConfig getDefaultConfiguration() {
    _logger.w('Using default project configuration');

    return ProjectConfig(
      status: true,
      message: 'Default configuration loaded',
      toast: false,
      data: ProjectConfigData(
        appLogoLight: '',
        appLogoDark: '',
        oneSignalAppId: '',
        oneSignalApiKey: '',
        webLogoLight: '',
        webLogoDark: '',
        twilioAccountSid: '',
        twilioAuthToken: '',
        twilioPhoneNumber: '',
        password: '',
        emailBanner: '',
        configId: 1,
        phoneAuthentication: true,
        emailAuthentication: true,
        maximumMembersInGroup: 10,
        showAllContacts: true,
        showPhoneContacts: true,
        userNameFlow: true,
        contactFlow: true, // Set to true for testing, normally would be false
        appName: 'whoxa',
        appEmail: '',
        appText: '',
        appPrimaryColor: '#006400',
        appSecondaryColor: '#0AC00A',
        demoCredential: false,
        appIosLink: '',
        appAndroidLink: '',
        appTellAFriendText: '',
        emailService: '',
        smtpHost: '',
        email: '',
        emailTitle: '',
        copyrightText: '',
        privacyPolicy: '',
        termsAndConditions: '',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  Future<NotificationListModel> getNotificationListRepo() async {
    _logger.i('Fetching Notification list');

    try {
      final response = await _apiClient.request(
        ApiEndpoints.broadcastNotification,
        method: "POST",
        body: {},
      );

      _logger.d('Notification_Response:$response');

      final notification = NotificationListModel.fromJson(response);

      return notification;
    } catch (e) {
      _logger.e("Error fetching notification list");

      if (e is AppError) {
        rethrow;
      }
      throw AppError("Failed to fetch Notification list: ${e.toString()}");
    }
  }

  Future<MarkReadNotifiModel> marReadNotifiRepo() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.markAsSeenNotification,
        method: "POST",
        body: {},
      );

      _logger.d('Mark_Read_Notification_Response:$response');

      final markReadNotifiModel = MarkReadNotifiModel.fromJson(response);
      return markReadNotifiModel;
    } catch (e) {
      _logger.e("Error fetching read notification");

      if (e is AppError) {
        rethrow;
      }
      throw AppError("Failed to fetch Read Notification: ${e.toString()}");
    }
  }
}
