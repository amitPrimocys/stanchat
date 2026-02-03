// =============================================================================
// FILE 1: Updated dependency_injection.dart
// =============================================================================

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:stanchat/core/api/api_client.dart';
import 'package:stanchat/core/network/network_listner.dart';
import 'package:stanchat/core/services/local_notification_service.dart';
import 'package:stanchat/core/services/call_audio_manager.dart';
import 'package:stanchat/featuers/provider/voice_provider.dart';
import 'package:stanchat/featuers/story/data/story_upload_repo.dart';
import 'package:stanchat/featuers/auth/data/repositories/login_repository.dart';
import 'package:stanchat/featuers/auth/provider/auth_provider.dart';
import 'package:stanchat/featuers/auth/services/onesignal_service.dart';

import 'package:stanchat/featuers/chat/group/data/repository/group_repository.dart';
import 'package:stanchat/featuers/chat/group/provider/group_provider.dart';
import 'package:stanchat/featuers/chat/provider/chat_provider.dart';
import 'package:stanchat/featuers/chat/provider/archive_chat_provider.dart';
import 'package:stanchat/featuers/chat/repository/chat_repository.dart';
import 'package:stanchat/featuers/home/provider/home_provider.dart';

import 'package:stanchat/featuers/language_method/data/repository/language_repo.dart';
import 'package:stanchat/featuers/language_method/provider/language_provider.dart';
import 'package:stanchat/featuers/onboarding/Provider/onboarding_provider.dart';
import 'package:stanchat/featuers/call/call_provider.dart';
import 'package:stanchat/featuers/profile/data/repository/profile_status_repo.dart';
import 'package:stanchat/featuers/profile/provider/profile_provider.dart';
import 'package:stanchat/featuers/project-config/data/config_repo.dart';
import 'package:stanchat/featuers/project-config/provider/config_provider.dart';
import 'package:stanchat/featuers/provider/theme_provider.dart';
import 'package:stanchat/featuers/story/provider/story_provider.dart';
import 'package:stanchat/featuers/call/call_manager.dart';
import 'package:stanchat/featuers/call/web_rtc_service.dart';
import 'package:stanchat/featuers/contacts/provider/contact_provider.dart';
import 'package:stanchat/featuers/contacts/data/repository/contact_repo.dart';
import 'package:stanchat/featuers/provider/tabbar_provider.dart';
import 'package:stanchat/featuers/report/data/repositories/report_repository.dart';
import 'package:stanchat/featuers/call/call_history/repositories/call_history_repository.dart';
import 'package:stanchat/featuers/call/call_history/providers/call_history_provider.dart';
import 'package:stanchat/featuers/report/provider/report_provider.dart';
import 'package:stanchat/utils/network_info.dart';
import 'package:stanchat/utils/preference_key/sharedpref_key.dart';
import 'package:stanchat/utils/logger.dart';
import 'core/services/socket/socket_event_controller.dart';
import 'core/services/socket/socket_service.dart';
import 'core/services/socket/socket_manager.dart';

final GetIt getIt = GetIt.instance;

/// ✅ Track if dependencies are fully initialized
bool _dependenciesInitialized = false;

/// Check if dependencies are ready for use
bool get areDependenciesReady => _dependenciesInitialized;

/// ✅ UPDATED: Setup application-wide dependencies with new call system
Future<void> setupDependencies() async {
  final logger = ConsoleAppLogger();
  logger.i('🔧 Setting up dependencies...');

  try {
    // ═══════════════════════════════════════════════════════════════════════════
    // CORE SERVICES - Must be registered FIRST
    // ═══════════════════════════════════════════════════════════════════════════

    logger.i('📦 Registering core services...');
    getIt.registerLazySingleton<Dio>(() => Dio());
    getIt.registerLazySingleton<Connectivity>(() => Connectivity());
    getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(getIt()));

    // Project Configuration dependencies
    getIt.registerLazySingleton(() => ProjectConfigRepository(getIt()));
    getIt.registerLazySingleton(() => ProjectConfigProvider(getIt()));

    // Network Listener
    getIt.registerLazySingleton<NetworkListener>(() => NetworkListener());
    await getIt<NetworkListener>().initialize();
    logger.i('NetworkListener initialized');

    // Storage
    final storage = FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked,
        synchronizable: false,
      ),
    );
    getIt.registerLazySingleton<SecurePrefs>(() => SecurePrefs(storage));

    // API Client
    getIt.registerLazySingleton(() => ApiClient(getIt(), getIt()));

    // ═══════════════════════════════════════════════════════════════════════════
    // SOCKET SERVICES (SINGLETONS) - UPDATED FOR NEW CALL SYSTEM
    // ═══════════════════════════════════════════════════════════════════════════

    // 1. Register SocketService as singleton
    getIt.registerLazySingleton<SocketService>(() => SocketService());
    logger.i('SocketService registered');

    // 2. Register SocketEvents
    getIt.registerLazySingleton<SocketEvents>(() => SocketEvents());
    logger.i('SocketEvents registered');

    // 3. Register SocketEventController (manages chat events) - without ArchiveChatProvider initially
    getIt.registerLazySingleton<SocketEventController>(
      () =>
          SocketEventController(getIt<SocketService>(), getIt<SocketEvents>()),
    );
    logger.i('SocketEventController registered');

    // 4. ✅ NEW: Register opus_call CallManager
    getIt.registerLazySingleton<CallManager>(() => CallManager.instance);
    logger.i('CallManager registered');

    // 5. ✅ NEW: Register opus_call WebRTCService
    getIt.registerLazySingleton<WebRTCService>(() => WebRTCService.instance);
    logger.i('WebRTCService registered');

    // 6. ✅ NEW: Register opus_call CallProvider
    getIt.registerLazySingleton<CallProvider>(() => CallProvider());
    logger.i('opus_call CallProvider registered');

    // 7. Register SocketManager (handles initialization)
    getIt.registerLazySingleton<SocketManager>(() => SocketManager());
    logger.i('SocketManager registered');

    // ═══════════════════════════════════════════════════════════════════════════
    // NOTIFICATION SERVICES
    // ═══════════════════════════════════════════════════════════════════════════

    getIt.registerLazySingleton(() => CallNotificationService());
    getIt.registerLazySingleton(() => OneSignalService());
    logger.i('Notification services registered');

    // ═══════════════════════════════════════════════════════════════════════════
    // REPOSITORIES
    // ═══════════════════════════════════════════════════════════════════════════

    getIt.registerLazySingleton(() => LoginRepository(getIt<ApiClient>()));
    getIt.registerLazySingleton(
      () => ProfileStatusRepository(getIt<ApiClient>()),
    );
    if (!getIt.isRegistered<ContactRepo>()) {
      getIt.registerLazySingleton(() => ContactRepo(getIt()));
    }
    getIt.registerLazySingleton(() => StoryUploadRepo(getIt<ApiClient>()));
    getIt.registerLazySingleton(() => ChatRepository(getIt()));
    getIt.registerLazySingleton(() => GroupRepo(getIt()));
    getIt.registerLazySingleton(() => ReportRepository(getIt<ApiClient>()));
    getIt.registerLazySingleton(
      () => CallHistoryRepository(getIt<ApiClient>()),
    );
    getIt.registerLazySingleton(() => LanguageRepository(getIt<ApiClient>()));
    logger.i('Repositories registered');

    // ═══════════════════════════════════════════════════════════════════════════
    // CORE PROVIDERS (FACTORY)
    // ═══════════════════════════════════════════════════════════════════════════

    getIt.registerFactory(() => AuthProvider(getIt<LoginRepository>()));
    getIt.registerFactory(
      () => ProfileProvider(getIt<ProfileStatusRepository>()),
    );
    getIt.registerFactory(() => ContactListProvider(getIt<ContactRepo>()));
    getIt.registerFactory(() => TabbarProvider());
    getIt.registerFactory(() => VoiceProvider());
    logger.i('Core providers registered');

    // ═══════════════════════════════════════════════════════════════════════════
    // FEATURE PROVIDERS (FACTORY)
    // ═══════════════════════════════════════════════════════════════════════════

    getIt.registerFactory(() => HomeProvider());
    getIt.registerFactory(() => OnboardingProvider());
    getIt.registerFactory(() => StoryProvider(getIt<StoryUploadRepo>()));
    getIt.registerFactory(() => GroupProvider(getIt<GroupRepo>()));
    getIt.registerFactory(() => ReportProvider(getIt<ReportRepository>()));
    getIt.registerFactory(() => ThemeProvider());
    getIt.registerFactory(
      () => CallHistoryProvider(getIt<CallHistoryRepository>()),
    );
    getIt.registerFactory(() => LanguageProvider(getIt<LanguageRepository>()));
    logger.i('Feature providers registered');

    // ═══════════════════════════════════════════════════════════════════════════
    // SOCKET-DEPENDENT PROVIDERS (FACTORY)
    // ═══════════════════════════════════════════════════════════════════════════

    // Chat Provider - Uses SocketEventController
    getIt.registerFactory(
      () => ChatProvider(
        getIt<ApiClient>(),
        getIt<SocketEventController>(),
        getIt<ChatRepository>(),
      ),
    );

    // ✅ CRITICAL FIX: Register ArchiveChatProvider as singleton and link it to SocketEventController IMMEDIATELY
    final archiveChatProvider = ArchiveChatProvider(getIt<SocketService>());
    getIt.registerSingleton<ArchiveChatProvider>(archiveChatProvider);

    // Link ArchiveChatProvider to SocketEventController immediately during setup
    getIt<SocketEventController>().setArchiveChatProvider(archiveChatProvider);
    logger.i(
      'ArchiveChatProvider created, registered, and linked to SocketEventController',
    );

    logger.i('Socket-dependent providers registered');

    // ═══════════════════════════════════════════════════════════════════════════
    // PROJECT CONFIGURATION - ✅ Load cached config for instant UI startup
    // ═══════════════════════════════════════════════════════════════════════════

    // ✅ Load cached config ONLY (no network call during DI setup)
    // Network call will happen AFTER all dependencies are ready in splash screen
    logger.i('📦 Loading cached project configuration...');
    try {
      final projectConfigProvider = getIt<ProjectConfigProvider>();
      final hasCachedConfig = await projectConfigProvider.loadCachedConfig();

      if (hasCachedConfig) {
        logger.i('✅ Cached project configuration loaded successfully');
        logger.i('📋 Cached App Name: ${projectConfigProvider.appName}');
      } else {
        logger.i(
          'ℹ️ No cached config found - will fetch from network in splash screen',
        );
      }
    } catch (e) {
      logger.w('⚠️ Failed to load cached configuration: $e');
      // App will continue and fetch from network in splash screen
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // ✅ MARK DEPENDENCIES AS READY
    // ═══════════════════════════════════════════════════════════════════════════

    _dependenciesInitialized = true;
    logger.i('✅ All dependencies registered and ready for use');
    logger.i('🚀 Dependency injection setup completed successfully');

    // ═══════════════════════════════════════════════════════════════════════════
    // ✅ CRITICAL FIX: DEFER socket initialization until AFTER login
    // ═══════════════════════════════════════════════════════════════════════════

    // ✅ REMOVED: Auto-initialization moved to AFTER first frame renders
    // Socket services will only be initialized when user is verified as logged in
    // This prevents blocking the app startup with socket connections
    logger.i('📱 Socket services will be initialized after UI renders');
  } catch (e) {
    logger.e('❌ Error setting up dependencies', e);
    logger.e(e.toString());
    if (e is Error) {
      logger.e(e.stackTrace.toString());
    }
    rethrow;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SOCKET INITIALIZATION METHODS - UPDATED
// ═══════════════════════════════════════════════════════════════════════════

/// ✅ UPDATED: Call this AFTER user login to initialize socket connections
Future<void> initializeSocketAfterLogin() async {
  final logger = ConsoleAppLogger();
  logger.i('🔌 Initializing socket connections after login');

  try {
    // 1. Initialize socket manager - this will handle the entire socket flow
    await getIt<SocketManager>().initializeSocket();
    logger.i('✅ SocketManager initialized successfully');

    // 2. ✅ UPDATED: Initialize opus_call CallManager
    final callManager = getIt<CallManager>();
    callManager.initialize();
    logger.i('✅ CallManager initialized');

    // 3. Verify socket connection before proceeding
    final socketService = getIt<SocketService>();
    if (socketService.isConnected) {
      logger.i('✅ Socket connection verified - all services ready');
    } else {
      logger.w(
        '⚠️ Socket connection not established - some features may not work',
      );
    }

    logger.i('✅ Socket connections and call service initialized successfully');
  } catch (e) {
    logger.e('❌ Error initializing socket connections after login', e);
    rethrow;
  }
}

/// ✅ UPDATED: Call this AFTER user logout to cleanup socket connections
Future<void> cleanupSocketAfterLogout() async {
  final logger = ConsoleAppLogger();
  logger.i('🧹 Cleaning up socket connections after logout');

  try {
    // 0. ✅ CRITICAL: Clean up audio session FIRST to prevent iOS audio session errors
    try {
      await _cleanupAudioSession();
      logger.i('✅ Audio session cleanup completed');
    } catch (e) {
      logger.w('⚠️ Error during audio session cleanup: $e');
    }

    // 1. ✅ CRITICAL: Dispose OneSignal event listeners FIRST to prevent iOS crashes
    try {
      final oneSignalService = OneSignalService();
      oneSignalService.dispose();
      logger.i('✅ OneSignal service disposed');
    } catch (e) {
      logger.w('⚠️ Error disposing OneSignal service: $e');
    }

    // 2. ✅ UPDATED: Reset opus_call system
    try {
      final callManager = getIt<CallManager>();
      await callManager.forceReset();
      logger.i('✅ CallManager cleanup completed');
    } catch (e) {
      logger.w('⚠️ Error cleaning up CallManager: $e');
    }

    // 2. ✅ FIXED: Force complete socket cleanup with proper reset
    try {
      // First reset the socket event controller
      final socketEventController = getIt<SocketEventController>();
      if (socketEventController.isInitialized) {
        socketEventController.reset();
        logger.i('✅ SocketEventController reset completed');
      }

      // Then reset the socket manager (this will reset the SocketService internally)
      getIt<SocketManager>().reset();
      logger.i('✅ SocketManager reset completed');

      // Add a small delay to ensure all cleanup operations complete
      await Future.delayed(Duration(milliseconds: 500));

      logger.i(
        '✅ All socket services reset - singletons are now in clean state',
      );
    } catch (e) {
      logger.w('⚠️ Error during socket cleanup: $e');
    }

    logger.i('✅ Socket connections and call service cleaned up successfully');
  } catch (e) {
    logger.e('❌ Error cleaning up socket connections after logout', e);
    // Don't rethrow here - logout should continue even if cleanup fails
  }
}

/// ✅ CRITICAL: Clean up audio session to prevent iOS audio session errors during logout
Future<void> _cleanupAudioSession() async {
  final logger = ConsoleAppLogger();

  try {
    logger.i('🎵 Starting audio session cleanup...');

    // Get CallAudioManager instance
    final callAudioManager = CallAudioManager.instance;

    // Force emergency stop all audio
    await callAudioManager.emergencyStopAudio();

    // Clean up and dispose the audio manager
    await callAudioManager.dispose();

    logger.i('🎵 CallAudioManager cleanup completed');
  } catch (e) {
    logger.e('❌ Error during audio session cleanup: $e');
    // Don't rethrow - logout should continue even if audio cleanup fails
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// UTILITY METHODS - UPDATED
// ═══════════════════════════════════════════════════════════════════════════

/// ✅ UPDATED: Check if socket services are properly initialized
bool areSocketServicesReady() {
  try {
    final socketService = getIt<SocketService>();
    final socketEventController = getIt<SocketEventController>();
    final callManager = getIt<CallManager>();

    return socketService.isConnected &&
        socketEventController.isInitialized &&
        callManager.isInitialized; // CallManager readiness check
  } catch (e) {
    final logger = ConsoleAppLogger();
    logger.e('Error checking socket services readiness: $e');
    return false;
  }
}

/// ✅ UPDATED: Get debug info for all socket services
Map<String, dynamic> getSocketServicesDebugInfo() {
  try {
    final socketService = getIt<SocketService>();
    final socketEventController = getIt<SocketEventController>();
    final callManager = getIt<CallManager>();
    final opusCallProvider = getIt<CallProvider>();

    return {
      'socketService': {'isConnected': socketService.isConnected},
      'socketEventController': {
        'isInitialized': socketEventController.isInitialized,
        'isConnected': socketEventController.isConnected,
      },
      'callManager': {
        'isInitialized': callManager.isInitialized,
        'state': callManager.state.name,
        'participantCount': callManager.participants.length,
      },
      'opusCallProvider': {
        'callState': opusCallProvider.callState.name,
        'isInCall': opusCallProvider.isInCall,
        'participantCount': opusCallProvider.participants.length,
      },
      'allServicesReady': areSocketServicesReady(),
    };
  } catch (e) {
    return {'error': e.toString(), 'allServicesReady': false};
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// UTILITY METHODS FOR MANUAL INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════

/// Force initialize socket services (for debugging/manual trigger)
Future<void> forceInitializeSocketServices() async {
  final logger = ConsoleAppLogger();
  logger.i('🔧 Force initializing socket services...');

  try {
    await initializeSocketAfterLogin();
    logger.i('✅ Socket services force-initialized successfully');
  } catch (e) {
    logger.e('❌ Error force-initializing socket services: $e');
    rethrow;
  }
}
