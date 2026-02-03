// *****************************************************************************************
// * Filename: onesignal_service.dart                                                      *
// * Developer: Deval Joshi                                                              *
// * Date: June 26, 2025                                                                   *
// * Description: Complete OneSignal service with dynamic configuration support           *
// *****************************************************************************************

import 'dart:async';

import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/core/services/local_notification_service.dart';
import 'package:whoxa/core/services/socket/socket_event_controller.dart';
import 'package:whoxa/featuers/call/call_manager.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/core/services/cold_start_handler.dart';
import 'package:whoxa/dependency_injection.dart';

class OneSignalService {
  static final OneSignalService _instance = OneSignalService._internal();
  factory OneSignalService() => _instance;
  OneSignalService._internal();

  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'OneSignalService',
  );
  final CallNotificationService _callNotificationService =
      CallNotificationService();

  // State variables
  String? _playerId;
  String? _appId;
  String? _externalUserId;
  bool _isInitialized = false;
  bool _isAppInForeground = true;
  bool _handlersSetup = false;
  bool _permissionsRequested = false;
  bool _isDisposed = false;

  // ✅ CRITICAL: Add notification deduplication
  final Set<String> _processedNotifications = <String>{};
  final Map<String, DateTime> _notificationTimestamps = <String, DateTime>{};
  static const Duration _deduplicationWindow = Duration(seconds: 5);

  // Callevent controller
  // CallEventController? _callEventController;

  // Getters
  String? get playerId => _playerId;
  String? get appId => _appId;
  String? get externalUserId => _externalUserId;
  bool get isInitialized => _isInitialized;
  bool get isAppInForeground => _isAppInForeground;
  bool get handlersSetup => _handlersSetup;
  bool get permissionsRequested => _permissionsRequested;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Basic initialization without App ID
  Future<void> initialize() async {
    try {
      _logger.i('🔧 Basic OneSignal initialization...');

      // Initialize call notification service first
      await _callNotificationService.initialize();

      // Basic OneSignal setup
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

      _logger.i('✅ Basic OneSignal service initialized');
    } catch (e) {
      _logger.e('❌ Error in basic OneSignal initialization', e);
    }
  }

  /// Full initialization with App ID
  Future<bool> initializeWithConfig(String oneSignalAppId) async {
    if (_isInitialized && _appId == oneSignalAppId && _handlersSetup) {
      _logger.i('✅ OneSignal already fully initialized with this App ID');
      return true;
    }

    try {
      _logger.i('🚀 STARTING ONESIGNAL FULL INITIALIZATION...');
      _logger.i('📱 App ID: $oneSignalAppId');

      if (oneSignalAppId.isEmpty) {
        _logger.w('❌ OneSignal App ID is empty');
        return false;
      }

      _appId = oneSignalAppId;

      // Step 1: Initialize OneSignal SDK
      _logger.i('🔧 Initializing OneSignal SDK...');
      OneSignal.initialize(oneSignalAppId);

      // Step 2: Wait for proper initialization
      await Future.delayed(Duration(milliseconds: 1000));

      // ✅ CRITICAL iOS FIX: DO NOT request permissions in OneSignal initialization
      // Let the onboarding flow handle all permission requests to avoid conflicts
      // await _requestNotificationPermissions();

      // Step 4: Setup subscription observer
      _setupSubscriptionObserver();

      // Step 5: Get initial player ID
      await _getPlayerId();

      // Step 6: Setup notification handlers
      _setupNotificationHandlers();
      _handlersSetup = true;

      _isInitialized = true;

      _logger.i('🎉 ONESIGNAL INITIALIZATION SUCCESSFUL!');
      _logInitializationStatus();

      return true;
    } catch (e) {
      _logger.e('💥 ERROR IN ONESIGNAL INITIALIZATION: $e');
      return false;
    }
  }

  /// Emergency setup for immediate handler configuration
  Future<bool> emergencySetupHandlers(String oneSignalAppId) async {
    if (_handlersSetup) {
      _logger.i('✅ Handlers already setup');
      return true;
    }

    try {
      _logger.i('🚨 EMERGENCY SETUP: Configuring handlers immediately');

      if (!_isInitialized || _appId != oneSignalAppId) {
        OneSignal.initialize(oneSignalAppId);
        _appId = oneSignalAppId;
        await Future.delayed(Duration(milliseconds: 500));
      }

      _setupNotificationHandlers();
      _handlersSetup = true;
      _isInitialized = true;

      _logger.i('✅ Emergency handlers setup completed');
      return true;
    } catch (e) {
      _logger.e('💥 Error in emergency setup: $e');
      return false;
    }
  }

  // // setCallEventController to set data
  // void setCallEventController(CallEventController controller) {
  //   _callEventController = controller;
  //   _logger.i('✅ CallEventController reference set in OneSignalService');
  // }

  // notification handlers for setdata:
  // void _passNotificationToCallController(OSNotification notification) {
  //   try {
  //     // Get the controller from GetIt instead of storing a reference
  //     final callEventController = GetIt.instance.get<CallEventController>();

  //     final callData = _extractCallData(notification);
  //     if (callData == null) return;

  //     final notificationData = {
  //       'success': true,
  //       'caller_name': callData['callerName'],
  //       'call': {
  //         'room_id': callData['roomId'],
  //         'call_id': callData['callId'],
  //         'chat_id': callData['chatId'],
  //         'call_type': callData['callType'],
  //         'call_status': 'ringing',
  //         'peer_id': callData['peerId'],
  //         'dataValues': {
  //           'call_id': callData['callId'],
  //           'chat_id': callData['chatId'],
  //           'call_type': callData['callType'],
  //           'caller_name': callData['callerName'],
  //         },
  //       },
  //     };
  //     _logger.i('✅ Notification passed data: $notificationData');
  //     callEventController.handleOneSignalCallNotification(notificationData);
  //     _logger.i('✅ Notification passed to CallEventController');
  //   } catch (e) {
  //     _logger.e('❌ Error getting or calling CallEventController: $e');
  //   }
  // }

  void _passNotificationToCallController(OSNotification notification) {
    try {
      final callData = _extractCallData(notification);
      if (callData == null) return;

      final notificationData = {
        'success': true,
        'caller_name': callData['callerName'],
        'call': {
          'room_id': callData['roomId'],
          'call_id': callData['callId'],
          'chat_id': callData['chatId'],
          'call_type': callData['callType'],
          'call_status': 'ringing',
          'peer_id': callData['peerId'],
          'dataValues': {
            'call_id': callData['callId'],
            'chat_id': callData['chatId'],
            'call_type': callData['callType'],
            'caller_name': callData['callerName'],
          },
        },
      };

      _logger.i('✅ Notification passed data: $notificationData');

      // ✅ CRITICAL FIX: Initialize call state in CallManager for incoming calls
      _initializeIncomingCallState(callData);

      _logger.i('✅ Call notification handling moved to opus_call provider');
    } catch (e) {
      _logger.e('❌ Error getting or calling SimpleCallController: $e');
    }
  }

  /// ✅ CRITICAL FIX: Initialize incoming call state in CallManager
  void _initializeIncomingCallState(Map<String, dynamic> callData) {
    try {
      _logger.i('🔄 Initializing incoming call state in CallManager');

      // Get CallManager instance
      final callManager = CallManager.instance;

      // Create socket event data format that matches what CallManager expects
      final socketEventData = {
        'call': {
          'chat_id': callData['chatId'],
          'call_id': callData['callId'],
          'room_id': callData['roomId'],
          'call_type': callData['callType'],
          'peer_id': callData['peerId'],
          'call_status': 'ringing',
        },
        'user': {
          'full_name': callData['callerName'],
          'user_id': callData['chatId'], // Use chatId as fallback
        },
      };

      // Trigger the incoming call handler using the public method
      callManager.handleIncomingCallFromNotification(socketEventData);

      _logger.i('✅ Incoming call state initialized successfully');
    } catch (e) {
      _logger.e('❌ Error initializing incoming call state: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEDUPLICATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// ✅ Check if notification was already processed
  bool _isNotificationAlreadyProcessed(String notificationId) {
    final now = DateTime.now();

    // Clean up old notifications (older than deduplication window)
    _cleanupOldNotifications(now);

    // Check if notification was already processed
    if (_processedNotifications.contains(notificationId)) {
      return true; // Already processed
    }

    // Mark as processed
    _processedNotifications.add(notificationId);
    _notificationTimestamps[notificationId] = now;

    _logger.d('✅ Notification marked as new: $notificationId');
    return false; // Not processed before
  }

  /// ✅ Clean up old processed notifications
  void _cleanupOldNotifications(DateTime now) {
    final expiredNotifications = <String>[];

    _notificationTimestamps.forEach((notificationId, timestamp) {
      if (now.difference(timestamp) > _deduplicationWindow) {
        expiredNotifications.add(notificationId);
      }
    });

    for (final notificationId in expiredNotifications) {
      _processedNotifications.remove(notificationId);
      _notificationTimestamps.remove(notificationId);
    }

    if (expiredNotifications.isNotEmpty) {
      _logger.d(
        '🧹 Cleaned up ${expiredNotifications.length} old notifications',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERMISSION AND SUBSCRIPTION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Setup OneSignal permissions after user has granted them in onboarding
  Future<void> setupPermissionsAfterUserGrant() async {
    try {
      _logger.i('🔐 Setting up OneSignal permissions after user grant...');

      // Check if permission is already granted
      final permissionStatus = await Permission.notification.status;
      _logger.i('🔍 Permission status: $permissionStatus');

      if (permissionStatus.isGranted || permissionStatus.isProvisional) {
        _logger.i('✅ Notification permission confirmed - opting in to OneSignal...');

        // ✅ CRITICAL FIX: Opt-in to OneSignal push notifications
        // This is what actually subscribes the user to push notifications in OneSignal
        await OneSignal.User.pushSubscription.optIn();
        _logger.i('✅ Successfully opted in to OneSignal push subscription');

        _permissionsRequested = true;

        // Wait a moment and verify subscription
        await Future.delayed(Duration(milliseconds: 500));
        final subscriptionId = OneSignal.User.pushSubscription.id;
        if (subscriptionId != null) {
          _logger.i('✅ OneSignal subscription verified - ID: $subscriptionId');
        } else {
          _logger.w('⚠️ OneSignal subscription ID not yet available');
        }
      } else {
        _logger.w(
          '⚠️ Permission not granted - OneSignal may not work properly',
        );
        _permissionsRequested = false;
      }
    } catch (e) {
      _logger.e('❌ Error setting up permissions after user grant', e);
      _permissionsRequested = false;
    }
  }

  /// DEPRECATED: This method should not be used - permissions handled in onboarding
  // ignore: unused_element
  Future<void> _requestNotificationPermissions() async {
    _logger.w(
      '⚠️ DEPRECATED: _requestNotificationPermissions called - use setupPermissionsAfterUserGrant instead',
    );
    await setupPermissionsAfterUserGrant();
  }

  /// Setup subscription observer
  void _setupSubscriptionObserver() {
    try {
      _logger.i('👂 Setting up subscription observer...');

      OneSignal.User.pushSubscription.addObserver((state) {
        final newPlayerId = state.current.id;
        if (newPlayerId != _playerId) {
          _playerId = newPlayerId;
          _logger.i('📱 OneSignal Player ID updated: $_playerId');
        }
      });
    } catch (e) {
      _logger.e('❌ Error setting up subscription observer', e);
    }
  }

  /// Get OneSignal Player ID with retry logic
  Future<String?> _getPlayerId() async {
    try {
      for (int attempt = 1; attempt <= 5; attempt++) {
        try {
          final user = OneSignal.User;
          final pushSubscription = user.pushSubscription;
          _playerId = pushSubscription.id;

          if (_playerId != null && _playerId!.isNotEmpty) {
            _logger.i('✅ Player ID obtained (attempt $attempt): $_playerId');
            return _playerId;
          } else {
            _logger.w(
              '⚠️ Player ID null/empty (attempt $attempt), retrying...',
            );
            await Future.delayed(Duration(seconds: attempt));
          }
        } catch (e) {
          _logger.w('⚠️ Error getting Player ID (attempt $attempt): $e');
          if (attempt == 5) rethrow;
          await Future.delayed(Duration(seconds: attempt));
        }
      }

      _logger.w('❌ Failed to get Player ID after 5 attempts');
      return null;
    } catch (e) {
      _logger.e('💥 Error getting Player ID', e);
      return null;
    }
  }

  /// Get player ID asynchronously
  Future<String?> getPlayerIdAsync() async {
    if (_playerId != null && _playerId!.isNotEmpty) {
      return _playerId;
    }

    int attempts = 0;
    const maxAttempts = 15;

    while ((_playerId == null || _playerId!.isEmpty) &&
        attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _getPlayerId();
      attempts++;
    }

    return _playerId;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATION HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Setup all notification handlers
  void _setupNotificationHandlers() {
    _logger.i('🎯 Setting up notification handlers...');

    try {
      // Handle foreground notifications (app open)
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        _handleForegroundNotification(event);
      });

      // Handle notification clicks (app closed/background)
      OneSignal.Notifications.addClickListener((event) {
        _handleNotificationClick(event);
      });

      // Handle permission changes
      OneSignal.Notifications.addPermissionObserver((state) {
        _logger.i('🔐 Permission changed: $state');
      });

      _logger.i('✅ All notification handlers setup completed');
    } catch (e) {
      _logger.e('💥 Error setting up notification handlers: $e');
    }
  }

  /// ✅ FIXED: Handle foreground notifications with deduplication
  void _handleForegroundNotification(OSNotificationWillDisplayEvent event) {
    // ✅ CRITICAL: Guard against disposed service to prevent iOS crashes
    if (_isDisposed) {
      _logger.w('⚠️ Ignoring foreground notification - service is disposed');
      try {
        event.preventDefault();
      } catch (e) {
        _logger.e('💥 Error preventing notification display: $e');
      }
      return;
    }

    final notificationId = event.notification.notificationId;

    // ✅ CRITICAL: Check for duplicate processing FIRST
    if (_isNotificationAlreadyProcessed(notificationId)) {
      _logger.w('🚫 Skipping duplicate notification: $notificationId');
      try {
        event.preventDefault(); // Still prevent display for duplicates
      } catch (e) {
        _logger.e('💥 Error preventing duplicate notification: $e');
      }
      return;
    }

    _logger.i('🔔 FOREGROUND NOTIFICATION: $notificationId');

    try {
      _logger.d('📧 Title: ${event.notification.title}');
      _logger.d('📝 Body: ${event.notification.body}');
      _logger.d('📊 Data: ${event.notification.additionalData}');

      final isCall = _isCallNotification(event.notification);
      _logger.i('📞 Is call notification: $isCall');

      // Add this line in both _handleForegroundNotification and _handleNotificationClick
      // if (isCall) {
      //   _passNotificationToCallController(event.notification); // Add this line
      // }

      if (isCall) {
        _logger.i('📞 CALL NOTIFICATION DETECTED');
        try {
          _passNotificationToCallController(event.notification); // Add this line
        } catch (e) {
          _logger.e('💥 Error passing to call controller: $e');
        }

        // Prevent OneSignal from showing the notification
        try {
          event.preventDefault();
        } catch (e) {
          _logger.e('💥 Error preventing call notification: $e');
        }

        if (_isAppInForeground) {
          _logger.i('📱 App in foreground - handling call directly');
          try {
            _handleIncomingCallDirect(event.notification);
          } catch (e) {
            _logger.e('💥 Error handling incoming call direct: $e');
          }
        } else {
          _logger.i('🏠 App in background - showing local notification');
          try {
            _handleIncomingCallBackground(event.notification);
          } catch (e) {
            _logger.e('💥 Error handling incoming call background: $e');
          }
        }
      } else {
        // ✅ NEW: Check if notification is for the same chat user is currently viewing
        if (_isAppInForeground &&
            _isNotificationForCurrentChat(event.notification)) {
          _logger.i('🚫 Hiding notification - user is already in this chat');
          try {
            event.preventDefault(); // Hide the notification
          } catch (e) {
            _logger.e('💥 Error preventing chat notification: $e');
          }
          return;
        }

        _logger.i('📨 Regular notification - showing normally');
        try {
          event.notification.display();
        } catch (e) {
          _logger.e('💥 Error displaying notification: $e');
        }
      }
    } catch (e) {
      _logger.e('💥 Error handling foreground notification: $e');
      // Fallback: show notification
      try {
        event.notification.display();
      } catch (displayError) {
        _logger.e('💥 Error in fallback display: $displayError');
      }
    }
  }

  /// ✅ FIXED: Handle notification clicks with deduplication and cold start support
  void _handleNotificationClick(OSNotificationClickEvent event) {
    // ✅ CRITICAL: Guard against disposed service to prevent iOS crashes
    if (_isDisposed) {
      _logger.w('⚠️ Ignoring notification click - service is disposed');
      return;
    }

    final notificationId = event.notification.notificationId;

    final isCall = _isCallNotification(event.notification);
    _logger.i('📞 Is call _handleNotificationClick: $isCall');

    // Add this line in both _handleForegroundNotification and _handleNotificationClick
    if (isCall) {
      _passNotificationToCallController(event.notification);
    }

    // ✅ CRITICAL: Check for duplicate processing FIRST
    if (_isNotificationAlreadyProcessed(notificationId)) {
      _logger.w('🚫 Skipping duplicate click: $notificationId');
      return;
    }

    _logger.i('🔔 NOTIFICATION CLICKED: $notificationId');

    try {
      if (_isCallNotification(event.notification)) {
        _callNotificationService.dismissCallNotification();

        final callData = _extractCallData(event.notification);
        if (callData != null) {
          // ✅ CRITICAL: Check if app is launching from cold start
          if (NavigationHelper.context == null) {
            _logger.i(
              '📱 App cold start detected - storing notification payload',
            );
            ColdStartHandler().storePendingCallData(callData);

            // ✅ CRITICAL FIX: Schedule retry with exponential backoff for cold start
            _scheduleNavigationRetry(callData, 0);
          } else {
            _navigateToCallScreen(callData);
          }
        }
      } else {
        _handleRegularNotificationClick(event.notification);
      }
    } catch (e) {
      _logger.e('💥 Error handling notification click: $e');
      // ✅ Store call data as fallback even on error
      try {
        final callData = _extractCallData(event.notification);
        if (callData != null) {
          ColdStartHandler().storePendingCallData(callData);
        }
      } catch (storageError) {
        _logger.e('💥 Error storing call data as fallback: $storageError');
      }
    }
  }

  /// ✅ CRITICAL FIX: Retry navigation with exponential backoff for cold start
  void _scheduleNavigationRetry(Map<String, dynamic> callData, int attempt) {
    if (attempt >= 5) {
      _logger.e('❌ Navigation retry failed after 5 attempts');
      return;
    }

    final delayMs = [500, 1000, 2000, 3000, 5000][attempt];
    _logger.i('⏳ Scheduling navigation retry attempt ${attempt + 1} in ${delayMs}ms');

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (_isDisposed) {
        _logger.w('⚠️ Service disposed during retry - cancelling');
        return;
      }

      if (NavigationHelper.context != null) {
        _logger.i('✅ Navigation context available - attempting navigation');
        _navigateToCallScreen(callData);
      } else {
        _logger.w('⚠️ Navigation context still null - scheduling retry ${attempt + 2}');
        _scheduleNavigationRetry(callData, attempt + 1);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CALL NOTIFICATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if notification is a call notification
  bool _isCallNotification(OSNotification notification) {
    try {
      // Method 1: Check title/body
      final title = notification.title?.toLowerCase() ?? '';
      final body = notification.body?.toLowerCase() ?? '';

      if (title.contains('calling') ||
          title.contains('call') ||
          body.contains('ringing') ||
          body.contains('calling')) {
        return true;
      }

      // Method 2: Check additional data
      final data = notification.additionalData;
      if (data != null) {
        // Check for call object in custom JSON
        final customString = data['custom'] as String?;
        if (customString != null && customString.contains('"call":{')) {
          return true;
        }

        // Check direct indicators
        if (data['call'] != null ||
            data['caller_name'] != null ||
            data['call_type'] != null ||
            data['call_id'] != null) {
          return true;
        }
      }

      return false;
    } catch (e) {
      _logger.e('💥 Error detecting call: $e');
      return false;
    }
  }

  /// ✅ NEW: Check if notification is for the same chat user is currently viewing
  bool _isNotificationForCurrentChat(OSNotification notification) {
    try {
      // Get the current chat ID from SocketEventController
      final socketEventController = getIt<SocketEventController>();
      final currentChatId = socketEventController.currentChatId;

      if (currentChatId == null || currentChatId <= 0) {
        _logger.d('No current chat active, allowing notification');
        return false;
      }

      // Extract chat_id from notification data
      final data = notification.additionalData;
      if (data == null) {
        _logger.d('No additional data in notification, allowing notification');
        return false;
      }

      int? notificationChatId;

      // Try to extract chat_id from different possible locations
      if (data['chat_id'] != null) {
        notificationChatId = int.tryParse(data['chat_id'].toString());
      } else if (data['chatId'] != null) {
        notificationChatId = int.tryParse(data['chatId'].toString());
      } else {
        // Try to parse from custom JSON string
        final customString = data['custom'] as String?;
        if (customString != null) {
          final customData = _parseJsonString(customString);
          if (customData != null && customData['a'] != null) {
            final additionalData = customData['a'] as Map<String, dynamic>?;
            if (additionalData != null) {
              notificationChatId = int.tryParse(
                additionalData['chat_id']?.toString() ?? '',
              );
            }
          }
        }
      }

      if (notificationChatId == null) {
        _logger.d(
          'Could not extract chat_id from notification, allowing notification',
        );
        return false;
      }

      final isSameChat = currentChatId == notificationChatId;
      _logger.i(
        'Chat comparison: current=$currentChatId, notification=$notificationChatId, same=$isSameChat',
      );

      return isSameChat;
    } catch (e) {
      _logger.e('Error checking if notification is for current chat: $e');
      return false; // If error, allow notification to be safe
    }
  }

  /// Helper method to parse JSON string safely
  Map<String, dynamic>? _parseJsonString(String jsonString) {
    try {
      // Add JSON parsing logic if needed
      // For now, return null as the custom data structure needs to be analyzed
      return null;
    } catch (e) {
      return null;
    }
  }

  // / ✅ IMPROVED: Extract call data with better parsing for your exact format
  Map<String, dynamic>? _extractCallData(OSNotification notification) {
    try {
      final data = notification.additionalData;
      if (data == null) return null;

      // Initialize defaults
      String callType = 'audio';
      String? roomId;
      int chatId = 0;
      int callId = 0;
      String callerName = 'Unknown Caller';
      String? peerId;
      String? callerAvatar;

      // Extract caller name from title first
      if (notification.title != null) {
        final match = RegExp(
          r'^(.*?)\s+is\s+(calling|ringing)',
        ).firstMatch(notification.title!);
        if (match != null) {
          callerName = match.group(1)!.trim();
        }
      }

      // ✅ IMPROVED: Parse your exact data structure
      if (data['call'] != null) {
        final callData = data['call'];
        if (callData is Map) {
          _logger.d('Room id data:${callData['room_id']?.toString()}');
          callType = callData['call_type']?.toString() ?? 'audio';
          roomId = callData['room_id']?.toString();
          chatId = int.tryParse(callData['chat_id']?.toString() ?? '0') ?? 0;
          callId = int.tryParse(callData['call_id']?.toString() ?? '0') ?? 0;
          peerId = callData['peer_id']?.toString();

          _logger.d(
            '📊 Direct call data: type=$callType, chatId=$chatId, callId=$callId, roomId=$roomId',
          );
        }
      }

      // Get caller name and user data
      if (data['caller_name'] != null) {
        callerName = data['caller_name'].toString();
      }

      if (data['user'] != null) {
        final userData = data['user'];
        if (userData is Map) {
          callerName = userData['full_name']?.toString() ?? callerName;
          callerAvatar = userData['profile_pic']?.toString();
        }
      }

      // ✅ CRITICAL: Ensure we have valid data
      if (chatId == 0 || callId == 0) {
        _logger.w('⚠️ Invalid call data: chatId=$chatId, callId=$callId');
        // Still proceed but with fallback values
        chatId = chatId == 0 ? 999 : chatId;
        callId = callId == 0 ? DateTime.now().millisecondsSinceEpoch : callId;
      }

      final result = {
        'roomId': roomId,
        'callType': callType,
        'chatId': chatId,
        'callId': callId,
        'callerName': callerName,
        'peerId': peerId,
        'callerAvatar': callerAvatar,
      };

      _logger.i('✅ Final call data: $result');
      return result;
    } catch (e) {
      _logger.e('💥 Error extracting call data: $e');
      return null;
    }
  }

  // Map<String, dynamic>? _extractCallData(OSNotification notification) {
  //   try {
  //     final data = notification.additionalData;
  //     if (data == null) return null;

  //     _logger.d('🔍 Raw notification data: $data');

  //     // Initialize defaults
  //     String callType = 'audio';
  //     int chatId = 0;
  //     int callId = 0;
  //     String callerName = 'Unknown Caller';
  //     String? peerId;
  //     String? callerAvatar;
  //     String? roomId; // ✅ Add room_id
  //     int? messageId;
  //     int? userId;
  //     List<dynamic>? currentUsers;
  //     Map<String, dynamic>? userData;

  //     // Extract caller name from title first
  //     if (notification.title != null) {
  //       final match = RegExp(
  //         r'^(.*?)\s+is\s+(calling|ringing)',
  //       ).firstMatch(notification.title!);
  //       if (match != null) {
  //         callerName = match.group(1)!.trim();
  //       }
  //     }

  //     // ✅ IMPROVED: Parse your exact data structure based on the log
  //     if (data['call'] != null) {
  //       final callData = data['call'];
  //       if (callData is Map) {
  //         callType = callData['call_type']?.toString() ?? 'audio';
  //         chatId = int.tryParse(callData['chat_id']?.toString() ?? '0') ?? 0;
  //         callId = int.tryParse(callData['call_id']?.toString() ?? '0') ?? 0;
  //         peerId = callData['peer_id']?.toString();
  //         roomId = callData['room_id']?.toString(); // ✅ Extract room_id
  //         messageId = int.tryParse(callData['message_id']?.toString() ?? '0');
  //         userId = int.tryParse(callData['user_id']?.toString() ?? '0');
  //         currentUsers = callData['current_users'];

  //         _logger.d(
  //           '📊 Direct call data: type=$callType, chatId=$chatId, callId=$callId, roomId=$roomId',
  //         );
  //       }
  //     }

  //     // ✅ Extract user data
  //     if (data['user'] != null) {
  //       userData = data['user'] as Map<String, dynamic>?;
  //       if (userData != null) {
  //         callerName =
  //             userData['full_name']?.toString() ??
  //             userData['first_name']?.toString() ??
  //             callerName;
  //         callerAvatar = userData['profile_pic']?.toString();

  //         _logger.d(
  //           '👤 User data extracted: name=$callerName, avatar=$callerAvatar',
  //         );
  //       }
  //     }

  //     // Get caller name from additional data if available
  //     if (data['caller_name'] != null) {
  //       callerName = data['caller_name'].toString();
  //     }

  //     // ✅ CRITICAL: Ensure we have valid data
  //     if (chatId == 0 || callId == 0) {
  //       _logger.w('⚠️ Invalid call data: chatId=$chatId, callId=$callId');
  //       // Still proceed but with fallback values
  //       chatId = chatId == 0 ? 999 : chatId;
  //       callId = callId == 0 ? DateTime.now().millisecondsSinceEpoch : callId;
  //     }

  //     final result = {
  //       'callType': callType,
  //       'chatId': chatId,
  //       'callId': callId,
  //       'callerName': callerName,
  //       'peerId': peerId,
  //       'callerAvatar': callerAvatar,
  //       'roomId': roomId, // ✅ Include room_id
  //       'messageId': messageId,
  //       'userId': userId,
  //       'currentUsers': currentUsers,
  //       'user': userData, // ✅ Include complete user data
  //     };

  //     _logger.i('✅ Final call data extracted: $result');
  //     return result;
  //   } catch (e) {
  //     _logger.e('💥 Error extracting call data: $e');
  //     return null;
  //   }
  // }

  /// Handle incoming call when app is in foreground
  void _handleIncomingCallDirect(OSNotification notification) {
    try {
      _logger.i('📱 Handling incoming call directly');

      final callData = _extractCallData(notification);
      if (callData != null) {
        _navigateToCallScreen(callData);
      }
    } catch (e) {
      _logger.e('💥 Error handling direct call: $e');
    }
  }

  /// Handle incoming call when app is in background
  void _handleIncomingCallBackground(OSNotification notification) {
    try {
      _logger.i('🏠 Handling incoming call in background');

      final callData = _extractCallData(notification);
      if (callData != null) {
        _callNotificationService.showIncomingCallNotification(
          callerName: callData['callerName'] ?? 'Unknown Caller',
          callType: callData['callType'] ?? 'audio',
          chatId: callData['chatId'] ?? 0,
          callId: callData['callId'] ?? 0,
          peerId: callData['peerId'],
          callerAvatar: callData['callerAvatar'],
          autoDismissSeconds: 30,
        );
      }
    } catch (e) {
      _logger.e('💥 Error handling background call: $e');
    }
  }

  /// Navigate to call screen safely
  void _navigateToCallScreen(Map<String, dynamic> callData) {
    try {
      _logger.i('🧭 Navigating to call screen: $callData');

      final context = NavigationHelper.context;
      if (context != null) {
        NavigationHelper.handleIncomingCall(callData);
        _logger.i('✅ Navigation successful _navigateToCallScreen onesignal');
      } else {
        _logger.w('⚠️ No navigation context, retrying...');

        Future.delayed(Duration(milliseconds: 500), () {
          final retryContext = NavigationHelper.context;
          if (retryContext != null) {
            NavigationHelper.handleIncomingCall(callData);
            _logger.i('✅ Navigation successful on retry');
          } else {
            _logger.e('❌ Navigation context unavailable after retry');
            _showFallbackNotification(callData);
          }
        });
      }
    } catch (e) {
      _logger.e('💥 Navigation error: $e');
      _showFallbackNotification(callData);
    }
  }

  /// Show fallback notification if navigation fails
  void _showFallbackNotification(Map<String, dynamic> callData) {
    try {
      _callNotificationService.showMessageNotification(
        title: 'Missed Call',
        body: 'Call from ${callData['callerName'] ?? 'Unknown'}',
        payload: 'missed_call',
      );
    } catch (e) {
      _logger.e('💥 Fallback notification failed: $e');
    }
  }

  /// Handle regular notification clicks
  void _handleRegularNotificationClick(OSNotification notification) {
    _logger.i(
      '📨 Handling regular notification: ${notification.notificationId}',
    );
    // Implement your regular notification handling logic
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // USER MANAGEMENT METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set external user ID (after login)
  /// Returns: true if successful, false if failed
  ///
  /// ⚠️ IMPORTANT: OneSignal blocks certain external_id values (like "1", "2", "test")
  /// to prevent spam/abuse. This method prefixes the user ID to avoid blocking.
  Future<bool> setExternalUserId(String userId) async {
    if (!_isInitialized) {
      _logger.w('⚠️ OneSignal not initialized, cannot set user ID');
      return false;
    }

    try {
      // ✅ FIX: Add prefix to avoid OneSignal blocking common IDs like "1", "2", etc.
      // OneSignal blocks certain user IDs to prevent spam/abuse
      final String prefixedUserId = 'user_$userId';

      _logger.i('🔐 Attempting to set OneSignal external user ID: $prefixedUserId (original: $userId)');

      // ✅ Add timeout to prevent infinite blocking
      await Future.any([
        Future(() => OneSignal.login(prefixedUserId)),
        Future.delayed(Duration(seconds: 10), () => throw TimeoutException('OneSignal login timeout')),
      ]);

      _externalUserId = prefixedUserId;
      _logger.i('✅ External user ID set successfully: $prefixedUserId');
      return true;
    } catch (e) {
      _logger.e('❌ Error setting external user ID: $e');

      // ✅ CRITICAL: Don't block app initialization on OneSignal errors
      // The app should continue to work even if OneSignal login fails
      _logger.w('⚠️ OneSignal user login failed - notifications may not work properly');
      _logger.w('⚠️ This usually happens when the user ID is blocked by OneSignal spam protection');

      return false;
    }
  }

  /// Add tags to user
  Future<void> addTags(Map<String, String> tags) async {
    if (!_isInitialized) {
      _logger.w('⚠️ OneSignal not initialized, cannot add tags');
      return;
    }

    try {
      OneSignal.User.addTags(tags);
      _logger.i('✅ Tags added: $tags');
    } catch (e) {
      _logger.e('❌ Error adding tags', e);
    }
  }

  /// Remove tags from user
  Future<void> removeTags(List<String> tagKeys) async {
    if (!_isInitialized) {
      _logger.w('⚠️ OneSignal not initialized, cannot remove tags');
      return;
    }

    try {
      OneSignal.User.removeTags(tagKeys);
      _logger.i('✅ Tags removed: $tagKeys');
    } catch (e) {
      _logger.e('❌ Error removing tags', e);
    }
  }

  /// Logout user from OneSignal (removes external user ID)
  Future<void> logout() async {
    if (!_isInitialized) {
      _logger.w('⚠️ OneSignal not initialized, skipping logout');
      return;
    }

    try {
      _logger.i('🔓 Logging out from OneSignal...');

      // Call OneSignal logout to remove external user ID
      OneSignal.logout();

      // Clear the stored external user ID
      _externalUserId = null;

      _logger.i('✅ OneSignal logout completed - user disassociated from device');
    } catch (e) {
      _logger.e('❌ Error during OneSignal logout', e);
      // Still clear the external user ID even if OneSignal logout fails
      _externalUserId = null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE MANAGEMENT METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set app foreground/background state
  void setAppForegroundState(bool isInForeground) {
    _isAppInForeground = isInForeground;
    _callNotificationService.setAppForegroundState(isInForeground);
    _logger.d('📱 App foreground state: $_isAppInForeground');
  }

  /// Show active call notification
  Future<void> showActiveCallNotification({
    required String callerName,
    required String callType,
    required String callStatus,
    required int callId,
  }) async {
    await _callNotificationService.showActiveCallNotification(
      callerName: callerName,
      callType: callType,
      callStatus: callStatus,
      callId: callId,
    );
  }

  /// Show regular message notification
  Future<void> showMessageNotification({
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
  }) async {
    await _callNotificationService.showMessageNotification(
      title: title,
      body: body,
      payload: payload,
      imageUrl: imageUrl,
    );
  }

  /// Dismiss call notifications
  void dismissCallNotifications() {
    _callNotificationService.dismissCallNotification();
  }

  /// Show test notification
  Future<void> showTestNotification() async {
    await _callNotificationService.showTestNotification();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Log initialization status
  void _logInitializationStatus() {
    _logger.i('📊 ONESIGNAL STATUS:');
    _logger.i('  - App ID: $_appId');
    _logger.i('  - Player ID: $_playerId');
    _logger.i('  - External User ID: $_externalUserId');
    _logger.i('  - Initialized: $_isInitialized');
    _logger.i('  - Handlers Setup: $_handlersSetup');
    _logger.i('  - Permissions Requested: $_permissionsRequested');
    _logger.i('  - App Foreground: $_isAppInForeground');
    _logger.i('  - Processed Notifications: ${_processedNotifications.length}');
  }

  /// Get complete status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'appId': _appId,
      'playerId': _playerId,
      'externalUserId': _externalUserId,
      'isInitialized': _isInitialized,
      'handlersSetup': _handlersSetup,
      'permissionsRequested': _permissionsRequested,
      'isAppInForeground': _isAppInForeground,
      'processedNotifications': _processedNotifications.length,
    };
  }

  /// ✅ IMPROVED: Reset service state with cleanup
  void reset() {
    _playerId = null;
    _appId = null;
    _externalUserId = null;
    _isInitialized = false;
    _handlersSetup = false;
    _permissionsRequested = false;
    _isDisposed = false; // Reset disposed flag for reinitialization

    // ✅ Clear processed notifications
    _processedNotifications.clear();
    _notificationTimestamps.clear();

    _callNotificationService.reset();
    _logger.i('🔄 OneSignal service reset completed');
  }

  /// ✅ CRITICAL: Dispose resources and remove all OneSignal event listeners
  void dispose() {
    try {
      _logger.i('🗑️ Starting OneSignal service disposal...');

      // Clear notification tracking
      _processedNotifications.clear();
      _notificationTimestamps.clear();

      // ✅ CRITICAL: Reset OneSignal state to prevent iOS crashes
      try {
        // Reset player ID and external user ID
        _playerId = null;
        _externalUserId = null;

        // Note: OneSignal Flutter doesn't provide explicit listener removal methods
        // The listeners are cleaned up when the app is disposed
        _logger.i('✅ OneSignal state reset for clean disposal');
      } catch (e) {
        _logger.w('⚠️ Error resetting OneSignal state: $e');
      }

      // Dispose call notification service
      _callNotificationService.dispose();

      // Reset state flags
      _handlersSetup = false;
      _isInitialized = false;
      _isDisposed = true;

      _logger.i('✅ OneSignal service disposed successfully');
    } catch (e) {
      _logger.e('❌ Error during OneSignal disposal', e);
    }
  }
}
