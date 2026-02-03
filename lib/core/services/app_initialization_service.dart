import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stanchat/featuers/auth/provider/auth_provider.dart';
import 'package:stanchat/featuers/auth/services/onesignal_service.dart';
import 'package:stanchat/featuers/project-config/provider/config_provider.dart';
import 'package:stanchat/featuers/provider/tabbar_provider.dart';
import 'package:stanchat/core/services/cold_start_handler.dart';
import 'package:stanchat/utils/preference_key/constant/app_routes.dart';
import 'package:stanchat/widgets/global.dart';
import 'package:stanchat/utils/logger.dart';

enum InitializationStatus { loading, completed, error }

enum NavigationTarget { onboarding, login, addInfo, tabbar, callScreen }

class AppInitializationService {
  static final AppInitializationService _instance =
      AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  final _logger = ConsoleAppLogger.forModule('AppInitializationService');

  InitializationStatus _status = InitializationStatus.loading;
  NavigationTarget? _navigationTarget;
  String? _errorMessage;

  bool _projectConfigLoaded = false;
  bool _oneSignalInitialized = false;
  bool _providersInitialized = false;
  bool _callHandled = false;

  // Getters
  InitializationStatus get status => _status;
  NavigationTarget? get navigationTarget => _navigationTarget;
  String? get errorMessage => _errorMessage;
  bool get isCompleted => _status == InitializationStatus.completed;
  bool get hasError => _status == InitializationStatus.error;

  // Progress getters for UI
  bool get projectConfigLoaded => _projectConfigLoaded;
  bool get oneSignalInitialized => _oneSignalInitialized;
  bool get providersInitialized => _providersInitialized;

  double get progress {
    int completed = 0;
    if (_projectConfigLoaded) completed++;
    if (_oneSignalInitialized) completed++;
    if (_providersInitialized) completed++;
    if (_callHandled) completed++;
    return completed / 4;
  }

  /// Initialize the entire app
  Future<void> initializeApp(BuildContext context) async {
    try {
      _status = InitializationStatus.loading;
      _logger.i('🚀 Starting app initialization');

      // Step 1: Initialize project configuration and OneSignal
      await _initializeProjectConfigAndOneSignal(context);

      // Step 2: Handle any pending call notifications
      await _handlePendingCallNotifications();

      // Step 4: Determine navigation target
      if (context.mounted) {
        _determineNavigationTarget(context);
      }

      _status = InitializationStatus.completed;
      _logger.i('✅ App initialization completed successfully');
    } catch (e) {
      _status = InitializationStatus.error;
      _errorMessage = e.toString();
      _logger.e('❌ App initialization failed: $e');

      // Set fallback navigation
      _navigationTarget = NavigationTarget.login;
    }
  }

  /// Initialize project configuration and OneSignal
  Future<void> _initializeProjectConfigAndOneSignal(
    BuildContext context,
  ) async {
    try {
      _logger.i('🔧 Initializing project configuration and OneSignal');

      final configProvider = Provider.of<ProjectConfigProvider>(
        context,
        listen: false,
      );

      // Initialize project config
      final success = await configProvider.initializeProjectConfig();

      if (success && configProvider.hasValidConfig) {
        _projectConfigLoaded = true;
        _logger.i('✅ Project configuration loaded');

        // Initialize OneSignal with dynamic App ID
        final oneSignalAppId = configProvider.oneSignalAppId;
        if (oneSignalAppId.isNotEmpty) {
          await _initializeOneSignal(oneSignalAppId);
        } else {
          await _initializeOneSignalFallback();
        }
      } else {
        _logger.w('⚠️ Project configuration failed, using fallback');
        await _initializeOneSignalFallback();
      }
    } catch (e) {
      _logger.e('❌ Error in project config initialization: $e');
      await _initializeOneSignalFallback();
    }
  }

  /// Initialize OneSignal with provided app ID
  Future<void> _initializeOneSignal(String appId) async {
    try {
      _logger.i('🔔 Initializing OneSignal with App ID: $appId');

      await OneSignalService().initializeWithConfig(appId);
      await OneSignalService().emergencySetupHandlers(appId);

      // Try to get player ID
      final playerId = await OneSignalService().getPlayerIdAsync();
      if (playerId != null) {
        _logger.i('🆔 OneSignal Player ID: $playerId');
      }

      _oneSignalInitialized = true;
      _logger.i('✅ OneSignal initialization completed');
    } catch (e) {
      _logger.e('❌ OneSignal initialization failed: $e');
      await _initializeOneSignalFallback();
    }
  }

  /// Fallback OneSignal initialization
  Future<void> _initializeOneSignalFallback() async {
    try {
      const String fallbackAppId = "fa0d2111-1ab5-49d7-ad5d-976b8d9d66a4";

      _logger.i('🔧 Using fallback OneSignal App ID: $fallbackAppId');
      await OneSignalService().initializeWithConfig(fallbackAppId);
      await OneSignalService().emergencySetupHandlers(fallbackAppId);

      _oneSignalInitialized = true;
      _logger.i('✅ OneSignal fallback initialization completed');
    } catch (e) {
      _logger.e('❌ OneSignal fallback initialization failed: $e');
      // Don't throw - allow app to continue without OneSignal
      _oneSignalInitialized = false;
    }
  }

  /// Handle any pending call notifications
  Future<void> _handlePendingCallNotifications() async {
    try {
      final coldStartHandler = ColdStartHandler();

      if (coldStartHandler.hasPendingCallData) {
        _logger.i('📞 Handling pending call notification');
        _navigationTarget = NavigationTarget.callScreen;

        // Let cold start handler manage the call navigation
        await coldStartHandler.handlePendingNotification();
        _callHandled = true;
        return;
      }

      _callHandled = true;
      _logger.d('ℹ️ No pending call notifications');
    } catch (e) {
      _logger.e('❌ Error handling call notifications: $e');
      _callHandled = true; // Continue without call handling
    }
  }

  /// Determine where to navigate after initialization
  void _determineNavigationTarget(BuildContext context) {
    // Skip if already determined (e.g., call screen)
    if (_navigationTarget != null) return;

    try {
      _logger.i('🧭 Determining navigation target');

      // Check permissions
      if (!permission) {
        _navigationTarget = NavigationTarget.onboarding;
        _logger.i('📍 Navigation target: Onboarding (permissions needed)');
        return;
      }

      // Check authentication
      if (authToken.isEmpty) {
        _navigationTarget = NavigationTarget.login;
        _logger.i('📍 Navigation target: Login (no auth token)');
        return;
      }

      // Check user info completion
      if (userName.isEmpty) {
        _navigationTarget = NavigationTarget.addInfo;
        _logger.i('📍 Navigation target: Add Info (username missing)');

        // Initialize auth provider for user info
        try {
          Provider.of<AuthProvider>(context, listen: false).initializeData();
        } catch (e) {
          _logger.w('⚠️ Failed to initialize auth provider: $e');
        }
        return;
      }

      // All checks passed - go to main app
      _navigationTarget = NavigationTarget.tabbar;
      _logger.i('📍 Navigation target: Tabbar (authenticated user)');

      // Initialize providers for main app
      try {
        Provider.of<AuthProvider>(context, listen: false).initializeData();
        Provider.of<TabbarProvider>(context, listen: false).navigateToIndex(0);
      } catch (e) {
        _logger.w('⚠️ Failed to initialize main app providers: $e');
      }
    } catch (e) {
      _logger.e('❌ Error determining navigation target: $e');
      _navigationTarget = NavigationTarget.login; // Safe fallback
    }
  }

  /// Get the route string for navigation
  String getRouteForTarget(NavigationTarget target) {
    switch (target) {
      case NavigationTarget.onboarding:
        return AppRoutes.onboarding;
      case NavigationTarget.login:
        return AppRoutes.login;
      case NavigationTarget.addInfo:
        return AppRoutes.addinfo;
      case NavigationTarget.tabbar:
        return AppRoutes.tabbar;
      case NavigationTarget.callScreen:
        // This should be handled by ColdStartHandler
        return AppRoutes.tabbar; // Fallback
    }
  }

  /// Reset initialization state (useful for testing or re-initialization)
  void reset() {
    _status = InitializationStatus.loading;
    _navigationTarget = null;
    _errorMessage = null;
    _projectConfigLoaded = false;
    _oneSignalInitialized = false;
    _providersInitialized = false;
    _callHandled = false;
  }
}
