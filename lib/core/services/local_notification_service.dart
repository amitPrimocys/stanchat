// import 'dart:async';
// import 'dart:io';
// import 'dart:ui';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:whoxa/utils/logger.dart';

// class LocalNotificationService {
//   static final LocalNotificationService _instance =
//       LocalNotificationService._internal();
//   factory LocalNotificationService() => _instance;
//   LocalNotificationService._internal();

//   final ConsoleAppLogger _logger = ConsoleAppLogger();
//   FlutterLocalNotificationsPlugin? _localNotifications;
//   Timer? _callNotificationTimer;
//   bool _isInitialized = false;

//   // Notification IDs
//   static const int callNotificationId = 1001;
//   static const String callChannelId = 'call_channel';
//   static const String callChannelName = 'Incoming Calls';

//   bool get isInitialized => _isInitialized;

//   /// Initialize local notifications
//   Future<void> initialize() async {
//     if (_isInitialized) {
//       _logger.i('LocalNotificationService already initialized');
//       return;
//     }

//     try {
//       _logger.i('Initializing LocalNotificationService...');

//       _localNotifications = FlutterLocalNotificationsPlugin();

//       // Android initialization settings
//       const AndroidInitializationSettings initializationSettingsAndroid =
//           AndroidInitializationSettings('@mipmap/ic_launcher');

//       // iOS initialization settings
//       const DarwinInitializationSettings initializationSettingsIOS =
//           DarwinInitializationSettings(
//             requestAlertPermission: true,
//             requestBadgePermission: true,
//             requestSoundPermission: true,
//             requestCriticalPermission: true,
//           );

//       const InitializationSettings initializationSettings =
//           InitializationSettings(
//             android: initializationSettingsAndroid,
//             iOS: initializationSettingsIOS,
//           );

//       // Initialize with settings
//       await _localNotifications!.initialize(
//         initializationSettings,
//         onDidReceiveNotificationResponse: _onNotificationTapped,
//       );

//       // Request permissions
//       await _requestPermissions();

//       // Create notification channels for Android
//       if (Platform.isAndroid) {
//         await _createNotificationChannels();
//       }

//       _isInitialized = true;
//       _logger.i('LocalNotificationService initialized successfully');
//     } catch (e) {
//       _logger.e('Error initializing LocalNotificationService', e);
//     }
//   }

//   /// Request notification permissions
//   Future<void> _requestPermissions() async {
//     try {
//       if (Platform.isAndroid) {
//         final status = await Permission.notification.request();
//         _logger.i('Android notification permission status: $status');

//         // For Android 13+ (API 33+), request POST_NOTIFICATIONS permission
//         if (await Permission.notification.isDenied) {
//           _logger.w('Notification permission denied');
//         }
//       } else if (Platform.isIOS) {
//         final bool? result = await _localNotifications!
//             .resolvePlatformSpecificImplementation<
//               IOSFlutterLocalNotificationsPlugin
//             >()
//             ?.requestPermissions(
//               alert: true,
//               badge: true,
//               sound: true,
//               critical: true,
//             );
//         _logger.i('iOS notification permission result: $result');
//       }
//     } catch (e) {
//       _logger.e('Error requesting notification permissions', e);
//     }
//   }

//   /// Create notification channels for Android
//   Future<void> _createNotificationChannels() async {
//     try {
//       AndroidNotificationChannel callChannel = AndroidNotificationChannel(
//         callChannelId,
//         callChannelName,
//         description: 'Notifications for incoming calls',
//         importance: Importance.max,
//         enableVibration: true,
//         enableLights: true,
//         ledColor: Color.fromARGB(255, 255, 0, 0),
//         showBadge: true,
//         playSound: true,
//         // Use default notification sound
//         sound: null, // This will use the default notification sound
//       );

//       await _localNotifications!
//           .resolvePlatformSpecificImplementation<
//             AndroidFlutterLocalNotificationsPlugin
//           >()
//           ?.createNotificationChannel(callChannel);

//       _logger.i('Android notification channels created');
//     } catch (e) {
//       _logger.e('Error creating notification channels', e);
//     }
//   }

//   /// Show incoming call notification with auto-dismiss
//   /// This creates a prominent notification that opens the app when tapped
//   Future<void> showIncomingCallNotification({
//     required String callerName,
//     required String callType,
//     required int chatId,
//     required int callId,
//     String? peerId,
//     int autoDismissSeconds = 30,
//   }) async {
//     if (!_isInitialized || _localNotifications == null) {
//       _logger.w(
//         'LocalNotificationService not initialized, cannot show notification',
//       );
//       return;
//     }

//     try {
//       _logger.i(
//         'Showing incoming $callType call notification from $callerName',
//       );

//       // Cancel any existing call notification timer
//       _cancelCallNotificationTimer();

//       // Determine call icon and title
//       String callIcon = callType.toLowerCase() == 'video' ? '📹' : '📞';
//       String title = '$callIcon Incoming Call';
//       String body = '$callerName is calling... Tap to answer';

//       // Android notification details - optimized for call notifications
//       AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//         callChannelId,
//         callChannelName,
//         channelDescription: 'Incoming call notifications',
//         importance: Importance.max,
//         priority: Priority.high,
//         category: AndroidNotificationCategory.call,
//         fullScreenIntent: true, // This makes it show over lock screen
//         autoCancel: true, // Allow user to dismiss
//         ongoing: false, // Don't make it sticky
//         enableVibration: true,
//         enableLights: true,
//         ledColor: const Color.fromARGB(255, 0, 255, 0),
//         ledOnMs: 1000,
//         ledOffMs: 500,
//         playSound: true,
//         // Use default sound or remove if you don't have a custom sound
//         sound: null,
//         // Add large icon for better visibility
//         largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
//         // Style as a big text notification
//         styleInformation: BigTextStyleInformation(
//           body,
//           htmlFormatBigText: false,
//           contentTitle: title,
//           htmlFormatContentTitle: false,
//         ),
//         // No action buttons - just tap to open
//       );

//       // iOS notification details - optimized for calls
//       DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
//         presentAlert: true,
//         presentBadge: true,
//         presentSound: true,
//         sound: null, // Use default iOS sound
//         categoryIdentifier: 'call_category',
//         interruptionLevel: InterruptionLevel.critical, // Bypass Do Not Disturb
//         subtitle:
//             callType.toLowerCase() == 'video' ? 'Video Call' : 'Voice Call',
//         threadIdentifier: 'incoming_call_$callId',
//       );

//       NotificationDetails notificationDetails = NotificationDetails(
//         android: androidDetails,
//         iOS: iosDetails,
//       );

//       // Payload with call information
//       String payload =
//           'call_notification|$chatId|$callId|$callType|${peerId ?? ''}|$callerName';

//       // Show the notification
//       await _localNotifications!.show(
//         callNotificationId,
//         title,
//         body,
//         notificationDetails,
//         payload: payload,
//       );

//       // Start auto-dismiss timer
//       _startCallNotificationTimer(autoDismissSeconds);

//       _logger.i(
//         'Incoming call notification shown with auto-dismiss in ${autoDismissSeconds}s',
//       );
//     } catch (e) {
//       _logger.e('Error showing incoming call notification', e);
//     }
//   }

//   /// Show a persistent call notification for active calls
//   Future<void> showActiveCallNotification({
//     required String callerName,
//     required String callType,
//     required String callStatus, // 'connecting', 'connected', 'ringing'
//   }) async {
//     if (!_isInitialized || _localNotifications == null) {
//       return;
//     }

//     try {
//       String callIcon = callType.toLowerCase() == 'video' ? '📹' : '📞';
//       String title = '$callIcon $callStatus Call';
//       String body =
//           callStatus == 'connected'
//               ? 'Connected with $callerName'
//               : 'Call with $callerName';

//       AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
//         'active_call_channel',
//         'Active Calls',
//         channelDescription: 'Ongoing call notifications',
//         importance: Importance.low,
//         priority: Priority.low,
//         ongoing: true, // Make it persistent
//         autoCancel: false,
//         enableVibration: false,
//         playSound: false,
//         showWhen: false,
//         usesChronometer:
//             callStatus == 'connected', // Show timer for connected calls
//         chronometerCountDown: false,
//       );

//       const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
//         presentAlert: false,
//         presentBadge: false,
//         presentSound: false,
//       );

//       await _localNotifications!.show(
//         callNotificationId + 1, // Different ID for active call
//         title,
//         body,
//         NotificationDetails(android: androidDetails, iOS: iosDetails),
//       );
//     } catch (e) {
//       _logger.e('Error showing active call notification', e);
//     }
//   }

//   /// Start timer to auto-dismiss call notification
//   void _startCallNotificationTimer(int seconds) {
//     _cancelCallNotificationTimer();

//     _callNotificationTimer = Timer(Duration(seconds: seconds), () {
//       _logger.i('Auto-dismissing call notification after $seconds seconds');
//       dismissCallNotification();
//     });

//     _logger.d('Call notification auto-dismiss timer started (${seconds}s)');
//   }

//   /// Cancel call notification timer
//   void _cancelCallNotificationTimer() {
//     if (_callNotificationTimer != null) {
//       _callNotificationTimer!.cancel();
//       _callNotificationTimer = null;
//       _logger.d('Call notification timer cancelled');
//     }
//   }

//   /// Dismiss call notification
//   Future<void> dismissCallNotification() async {
//     try {
//       _cancelCallNotificationTimer();

//       if (_localNotifications != null) {
//         await _localNotifications!.cancel(callNotificationId);
//         await _localNotifications!.cancel(
//           callNotificationId + 1,
//         ); // Active call notification
//         _logger.i('Call notifications dismissed');
//       }
//     } catch (e) {
//       _logger.e('Error dismissing call notification', e);
//     }
//   }

//   /// Handle notification tap - opens the app to the call screen
//   void _onNotificationTapped(NotificationResponse response) {
//     try {
//       _logger.i('Notification tapped: ${response.payload}');

//       if (response.payload != null &&
//           response.payload!.startsWith('call_notification|')) {
//         final parts = response.payload!.split('|');
//         if (parts.length >= 5) {
//           final chatId = int.tryParse(parts[1]);
//           final callId = int.tryParse(parts[2]);
//           final callType = parts[3];
//           final peerId = parts.length > 4 ? parts[4] : null;
//           final callerName = parts.length > 5 ? parts[5] : 'Unknown';

//           _logger.i(
//             'Opening call screen: chatId=$chatId, callId=$callId, type=$callType, caller=$callerName',
//           );

//           // Dismiss the notification
//           dismissCallNotification();

//           // Navigate to call screen
//           _navigateToCallScreen(chatId, callId, callType, peerId, callerName);
//         }
//       }
//     } catch (e) {
//       _logger.e('Error handling notification tap', e);
//     }
//   }

//   /// Navigate to call screen - implement based on your routing system
//   void _navigateToCallScreen(
//     int? chatId,
//     int? callId,
//     String callType,
//     String? peerId,
//     String callerName,
//   ) {
//     _logger.i(
//       'Navigating to call screen: chatId=$chatId, callId=$callId, type=$callType',
//     );

//     // Examples based on different routing systems:

//     // If using GetX:
//     // Get.toNamed('/call', arguments: {
//     //   'chatId': chatId,
//     //   'callId': callId,
//     //   'callType': callType,
//     //   'peerId': peerId,
//     //   'callerName': callerName,
//     //   'isIncoming': true,
//     // });

//     // If using Navigator:
//     // NavigatorKey.currentState?.pushNamed('/call', arguments: {
//     //   'chatId': chatId,
//     //   'callId': callId,
//     //   'callType': callType,
//     //   'peerId': peerId,
//     //   'callerName': callerName,
//     //   'isIncoming': true,
//     // });

//     // If using Provider/Riverpod to manage call state:
//     // context.read<CallProvider>().handleIncomingCall(
//     //   chatId: chatId!,
//     //   callId: callId!,
//     //   callType: callType,
//     //   peerId: peerId,
//     //   callerName: callerName,
//     // );
//   }

//   /// Show a regular message notification
//   Future<void> showMessageNotification({
//     required String title,
//     required String body,
//     String? payload,
//   }) async {
//     if (!_isInitialized || _localNotifications == null) {
//       return;
//     }

//     const NotificationDetails notificationDetails = NotificationDetails(
//       android: AndroidNotificationDetails(
//         'message_channel',
//         'Messages',
//         channelDescription: 'New message notifications',
//         importance: Importance.high,
//         priority: Priority.high,
//         showWhen: true,
//       ),
//       iOS: DarwinNotificationDetails(
//         presentAlert: true,
//         presentBadge: true,
//         presentSound: true,
//       ),
//     );

//     await _localNotifications!.show(
//       DateTime.now().millisecondsSinceEpoch.remainder(100000),
//       title,
//       body,
//       notificationDetails,
//       payload: payload,
//     );
//   }

//   /// Show a simple notification (for testing)
//   Future<void> showTestNotification() async {
//     if (!_isInitialized || _localNotifications == null) {
//       _logger.w('Cannot show test notification - service not initialized');
//       return;
//     }

//     await showMessageNotification(
//       title: 'Test Notification',
//       body: 'This is a test notification',
//       payload: 'test_notification',
//     );
//   }

//   /// Reset the service
//   void reset() {
//     _cancelCallNotificationTimer();
//     dismissCallNotification();
//     _logger.i('LocalNotificationService reset');
//   }

//   /// Dispose resources
//   void dispose() {
//     _cancelCallNotificationTimer();
//     _logger.d('LocalNotificationService disposed');
//   }
// }

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:whoxa/utils/logger.dart';

class CallNotificationService {
  static final CallNotificationService _instance =
      CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal();

  final ConsoleAppLogger _logger = ConsoleAppLogger();
  FlutterLocalNotificationsPlugin? _localNotifications;
  Timer? _callNotificationTimer;
  bool _isInitialized = false;
  bool _isAppInForeground = true;

  // Notification IDs and channels
  static const int callNotificationId = 1001;
  static const String callChannelId = 'incoming_calls';
  static const String callChannelName = 'Incoming Calls';
  static const String callChannelDescription =
      'Notifications for incoming voice and video calls';

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isAppInForeground => _isAppInForeground;

  /// Initialize the call notification service
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.i('CallNotificationService already initialized');
      return;
    }

    try {
      _logger.i('Initializing CallNotificationService...');

      _localNotifications = FlutterLocalNotificationsPlugin();

      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
            requestCriticalPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      // Initialize with settings
      await _localNotifications!.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions
      await _requestPermissions();

      // Create notification channels for Android
      if (Platform.isAndroid) {
        await _createCallNotificationChannel();
      }

      _isInitialized = true;
      _logger.i('CallNotificationService initialized successfully');
    } catch (e) {
      _logger.e('Error initializing CallNotificationService', e);
    }
  }

  /// Set app foreground state
  void setAppForegroundState(bool isInForeground) {
    _isAppInForeground = isInForeground;
    _logger.d('App foreground state changed: $_isAppInForeground');
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Request notification permission
        final status = await Permission.notification.request();
        _logger.i('Android notification permission status: $status');

        // Request phone permission for call notifications
        final phoneStatus = await Permission.phone.request();
        _logger.i('Android phone permission status: $phoneStatus');

        // For Android 13+ (API 33+), request POST_NOTIFICATIONS permission
        if (await Permission.notification.isDenied) {
          _logger.w('Notification permission denied');
        }
      } else if (Platform.isIOS) {
        final bool? result = await _localNotifications!
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
              critical: true,
            );
        _logger.i('iOS notification permission result: $result');
      }
    } catch (e) {
      _logger.e('Error requesting notification permissions', e);
    }
  }

  /// Create notification channel for calls (Android)
  Future<void> _createCallNotificationChannel() async {
    try {
      const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
        callChannelId,
        callChannelName,
        description: callChannelDescription,
        importance: Importance.max,
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 0, 255, 0),
        showBadge: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(
          'call_ringtone',
        ), // Custom ringtone for call notifications
      );

      await _localNotifications!
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(callChannel);

      _logger.i('Call notification channel created successfully');
    } catch (e) {
      _logger.e('Error creating call notification channel', e);
    }
  }

  /// Show incoming call notification
  /// Only shows if app is in background or closed
  Future<void> showIncomingCallNotification({
    required String callerName,
    required String callType, // 'audio' or 'video'
    required int chatId,
    required int callId,
    String? peerId,
    String? callerAvatar,
    int autoDismissSeconds = 30,
  }) async {
    if (!_isInitialized || _localNotifications == null) {
      _logger.w(
        'CallNotificationService not initialized, cannot show notification',
      );
      return;
    }

    // ✅ IMPORTANT: Only show notification if app is in background
    if (_isAppInForeground) {
      _logger.i('App is in foreground, skipping call notification display');
      return;
    }

    try {
      _logger.i(
        'Showing incoming $callType call notification from $callerName',
      );

      // Cancel any existing call notification timer
      _cancelCallNotificationTimer();

      // Determine call icon and title
      String callIcon = callType.toLowerCase() == 'video' ? '📹' : '📞';
      String title = '$callIcon Incoming ${callType.toUpperCase()} Call';
      String body = '$callerName is calling... Tap to answer';

      // Android notification details - optimized for call notifications
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        callChannelId,
        callChannelName,
        channelDescription: callChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true, // Shows over lock screen
        autoCancel: false, // Don't auto-dismiss when tapped
        ongoing: true, // Makes it persistent until dismissed
        enableVibration: true,
        enableLights: true,
        ledColor: const Color.fromARGB(255, 0, 255, 0),
        ledOnMs: 1000,
        ledOffMs: 500,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('call_ringtone'),
        // Add action buttons for answer/decline
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'answer_call',
            'Answer',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_call_answer'),
            contextual: true,
          ),
          AndroidNotificationAction(
            'decline_call',
            'Decline',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_call_decline'),
            contextual: true,
            cancelNotification: true,
          ),
        ],
        // Large icon for better visibility
        // largeIcon:
        //     callerAvatar != null
        //         ? NetworkBitmapAndroidIcon(callerAvatar)
        //         : const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        // Style as a big text notification
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          contentTitle: title,
          htmlFormatContentTitle: false,
        ),
      );

      // iOS notification details - optimized for calls
      DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'call_ringtone.mp3', // Custom iOS ringtone
        categoryIdentifier: 'call_category',
        interruptionLevel: InterruptionLevel.critical, // Bypass Do Not Disturb
        subtitle:
            callType.toLowerCase() == 'video' ? 'Video Call' : 'Voice Call',
        threadIdentifier: 'incoming_call_$callId',
        attachments:
            callerAvatar != null
                ? [DarwinNotificationAttachment(callerAvatar)]
                : null,
      );

      NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Payload with call information
      String payload =
          'incoming_call|$chatId|$callId|$callType|${peerId ?? ''}|$callerName';

      // Show the notification
      await _localNotifications!.show(
        callNotificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      // Start auto-dismiss timer
      _startCallNotificationTimer(autoDismissSeconds);

      _logger.i(
        'Incoming call notification shown with auto-dismiss in ${autoDismissSeconds}s',
      );
    } catch (e) {
      _logger.e('Error showing incoming call notification', e);
    }
  }

  /// Show active call notification (while call is ongoing)
  Future<void> showActiveCallNotification({
    required String callerName,
    required String callType,
    required String callStatus, // 'connecting', 'connected', 'ringing'
    required int callId,
  }) async {
    if (!_isInitialized || _localNotifications == null) {
      return;
    }

    try {
      String callIcon = callType.toLowerCase() == 'video' ? '📹' : '📞';
      String title = '$callIcon ${callStatus.toUpperCase()} Call';
      String body =
          callStatus == 'connected'
              ? 'Connected with $callerName'
              : 'Call with $callerName';

      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'active_call_channel',
        'Active Calls',
        channelDescription: 'Ongoing call notifications',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true, // Make it persistent
        autoCancel: false,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        usesChronometer:
            callStatus == 'connected', // Show timer for connected calls
        chronometerCountDown: false,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'end_call',
            'End Call',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_call_end'),
            contextual: true,
            cancelNotification: true,
          ),
        ],
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
        categoryIdentifier: 'active_call_category',
      );

      String payload = 'active_call|$callId|$callType|$callerName';

      await _localNotifications!.show(
        callNotificationId + 1, // Different ID for active call
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: payload,
      );
    } catch (e) {
      _logger.e('Error showing active call notification', e);
    }
  }

  /// Start timer to auto-dismiss call notification
  void _startCallNotificationTimer(int seconds) {
    _cancelCallNotificationTimer();

    _callNotificationTimer = Timer(Duration(seconds: seconds), () {
      _logger.i('Auto-dismissing call notification after $seconds seconds');
      dismissCallNotification();
    });

    _logger.d('Call notification auto-dismiss timer started (${seconds}s)');
  }

  /// Cancel call notification timer
  void _cancelCallNotificationTimer() {
    if (_callNotificationTimer != null) {
      _callNotificationTimer!.cancel();
      _callNotificationTimer = null;
      _logger.d('Call notification timer cancelled');
    }
  }

  /// Dismiss call notification
  Future<void> dismissCallNotification() async {
    try {
      _cancelCallNotificationTimer();

      if (_localNotifications != null) {
        await _localNotifications!.cancel(callNotificationId);
        await _localNotifications!.cancel(
          callNotificationId + 1,
        ); // Active call notification
        _logger.i('Call notifications dismissed');
      }
    } catch (e) {
      _logger.e('Error dismissing call notification', e);
    }
  }

  /// Handle notification tap and actions
  void _onNotificationTapped(NotificationResponse response) {
    try {
      _logger.i('Notification tapped: ${response.payload}');
      _logger.i('Action ID: ${response.actionId}');

      if (response.payload != null) {
        final parts = response.payload!.split('|');

        if (parts[0] == 'incoming_call' && parts.length >= 6) {
          final chatId = int.tryParse(parts[1]);
          final callId = int.tryParse(parts[2]);
          final callType = parts[3];
          final peerId = parts.length > 4 ? parts[4] : null;
          final callerName = parts.length > 5 ? parts[5] : 'Unknown';

          _logger.i(
            'Incoming call data: chatId=$chatId, callId=$callId, type=$callType, caller=$callerName',
          );

          // Handle action buttons
          if (response.actionId == 'answer_call') {
            _logger.i('Answer call button pressed');
            _handleAnswerCall(chatId, callId, callType, peerId, callerName);
          } else if (response.actionId == 'decline_call') {
            _logger.i('Decline call button pressed');
            _handleDeclineCall(chatId, callId, callType, peerId, callerName);
          } else {
            // Normal tap - navigate to call screen
            _logger.i('Normal tap - navigating to call screen');
            _navigateToIncomingCallScreen(
              chatId,
              callId,
              callType,
              peerId,
              callerName,
            );
          }

          // Dismiss the notification
          dismissCallNotification();
        } else if (parts[0] == 'active_call') {
          final callId = int.tryParse(parts[1]);
          final callType = parts[2];
          final callerName = parts[3];

          if (response.actionId == 'end_call') {
            _logger.i('End call button pressed');
            _handleEndCall(callId, callType, callerName);
          }
        }
      }
    } catch (e) {
      _logger.e('Error handling notification tap', e);
    }
  }

  /// Handle answer call action
  void _handleAnswerCall(
    int? chatId,
    int? callId,
    String callType,
    String? peerId,
    String callerName,
  ) {
    _logger.i(
      'Handling answer call: chatId=$chatId, callId=$callId, type=$callType',
    );

    // Implement your call answer logic here
    // Example:
    // CallManager.instance.answerCall(callId: callId!, chatId: chatId!);

    // Navigate to call screen
    _navigateToActiveCallScreen(
      chatId,
      callId,
      callType,
      peerId,
      callerName,
      isIncoming: true,
    );
  }

  /// Handle decline call action
  void _handleDeclineCall(
    int? chatId,
    int? callId,
    String callType,
    String? peerId,
    String callerName,
  ) {
    _logger.i(
      'Handling decline call: chatId=$chatId, callId=$callId, type=$callType',
    );

    // Implement your call decline logic here
    // Example:
    // CallManager.instance.declineCall(callId: callId!, chatId: chatId!);
  }

  /// Handle end call action
  void _handleEndCall(int? callId, String callType, String callerName) {
    _logger.i('Handling end call: callId=$callId, type=$callType');

    // Implement your call end logic here
    // Example:
    // CallManager.instance.endCall(callId: callId!);
  }

  /// Navigate to incoming call screen
  void _navigateToIncomingCallScreen(
    int? chatId,
    int? callId,
    String callType,
    String? peerId,
    String callerName,
  ) {
    _logger.i(
      'Navigating to incoming call screen: chatId=$chatId, callId=$callId, type=$callType',
    );

    // CRITICAL FIX: For now, this method will be called when user taps on the notification
    // The actual implementation should be done at the top of this file by importing:
    // import 'package:whoxa/core/navigation_helper.dart';
    // import 'package:whoxa/featuers/opus_call/call_model.dart';

    _logger.w(
      '⚠️ _navigateToIncomingCallScreen called but not fully implemented',
    );
    _logger.i(
      '📲 User tapped on call notification - app should now be brought to foreground',
    );
    _logger.i(
      '💡 Add the required imports at the top of this file and implement proper navigation',
    );
  }

  /// Navigate to active call screen
  void _navigateToActiveCallScreen(
    int? chatId,
    int? callId,
    String callType,
    String? peerId,
    String callerName, {
    bool isIncoming = false,
  }) {
    _logger.i(
      'Navigating to active call screen: chatId=$chatId, callId=$callId, type=$callType, incoming=$isIncoming',
    );

    // Implement navigation to your active call screen
    // Similar to incoming call screen but for ongoing calls
  }

  /// Show a regular message notification (non-call)
  Future<void> showMessageNotification({
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
  }) async {
    if (!_isInitialized || _localNotifications == null) {
      return;
    }

    try {
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'message_channel',
        'Messages',
        channelDescription: 'New message notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        // largeIcon:
        //     imageUrl != null
        //         ? NetworkBitmapAndroidIcon(imageUrl)
        //         : const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(body),
        // imageUrl != null
        //     ? BigPictureStyleInformation(
        //       NetworkBitmapAndroidIcon(imageUrl),
        //       contentTitle: title,
        //       summaryText: body,
        //     )
        //     : BigTextStyleInformation(body),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications!.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      _logger.e('Error showing message notification', e);
    }
  }

  /// ✅ NEW: Play call ringtone without showing notification UI
  /// Used when OneSignal handles the notification display but we want custom ringtone
  Future<void> playCallRingtoneOnly({
    required String callerName,
    required String callType,
    required int chatId,
    required int callId,
    int autoDismissSeconds = 30,
  }) async {
    if (!_isInitialized || _localNotifications == null) {
      _logger.w(
        'CallNotificationService not initialized, cannot play ringtone',
      );
      return;
    }

    try {
      _logger.i('🔔 Playing call ringtone only (no notification UI)');

      // Cancel any existing call notification timer
      _cancelCallNotificationTimer();

      // Use the custom ringtone sound directly through local notification
      // but make it silent/invisible
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        callChannelId,
        callChannelName,
        channelDescription: callChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.call,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('call_ringtone'),
        enableVibration: true,
        // Make notification invisible but keep sound
        ongoing: false,
        autoCancel: true,
        showWhen: false,
        visibility: NotificationVisibility.secret, // Hide from lock screen
      );

      DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: false, // Don't show alert
        presentBadge: false, // Don't show badge
        presentSound: true, // DO play sound
        sound: 'call_ringtone.mp3',
        interruptionLevel: InterruptionLevel.critical,
      );

      NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show silent notification that only plays sound
      await _localNotifications!.show(
        callNotificationId + 999, // Different ID to avoid conflicts
        '', // Empty title
        '', // Empty body
        notificationDetails,
      );

      // Start auto-dismiss timer
      _startCallNotificationTimer(autoDismissSeconds);

      _logger.i('✅ Call ringtone playing (ringtone-only mode)');
    } catch (e) {
      _logger.e('❌ Error playing call ringtone: $e');
    }
  }

  /// Show a simple test notification
  Future<void> showTestNotification() async {
    if (!_isInitialized || _localNotifications == null) {
      _logger.w('Cannot show test notification - service not initialized');
      return;
    }

    await showMessageNotification(
      title: 'Test Notification',
      body: 'This is a test notification',
      payload: 'test_notification',
    );
  }

  /// Reset the service
  void reset() {
    _cancelCallNotificationTimer();
    dismissCallNotification();
    _logger.i('CallNotificationService reset');
  }

  /// Dispose resources
  void dispose() {
    _cancelCallNotificationTimer();
    _logger.d('CallNotificationService disposed');
  }
}
