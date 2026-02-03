// *****************************************************************************************
// * Filename: socket_service.dart (FIXED VERSION)
// * Developer: Deval Joshi
// * Date: May, 2025                                                                     *
// * Description: Fixed socket service with proper connection management                 *
// *****************************************************************************************

import 'dart:async';
import 'dart:developer';
import 'package:get_it/get_it.dart';
import 'package:stanchat/core/api/api_endpoint.dart';
import 'package:stanchat/core/error/app_error.dart';
import 'package:stanchat/utils/logger.dart' show ConsoleAppLogger;
import 'package:stanchat/utils/network_info.dart';
import 'package:stanchat/utils/preference_key/preference_key.dart';
import 'package:stanchat/utils/preference_key/sharedpref_key.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

// Enum to represent the connection state of the socket
enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class SocketService {
  // Singleton pattern implementation
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  // Initialize with non-late field and direct initialization in constructor
  final _logger = ConsoleAppLogger.forModule('SocketService');
  final NetworkInfo _networkInfo;

  // Socket.io instance - ONLY ONE INSTANCE
  io.Socket? _socket;

  // Connection state stream controller
  final _connectionStateController =
      StreamController<SocketConnectionState>.broadcast();
  Stream<SocketConnectionState> get connectionState =>
      _connectionStateController.stream;

  // Event types that need to be handled
  final Map<String, List<Function(dynamic)>> _eventHandlers = {};

  // Configuration
  static const String socketBaseUrl = ApiEndpoints.socketUrl;
  String _socketUrl = socketBaseUrl;
  String _socketPath = '/socket';
  bool _initialized = false;
  bool _connecting = false;

  // Constructor now takes networkInfo directly
  SocketService._internal() : _networkInfo = GetIt.instance<NetworkInfo>();

  // Initialize the socket service
  void initialize({
    String? socketUrl,
    String? socketPath,
    Map<String, dynamic>? authData,
    int maxRetryAttempts = 5,
    int retryDelayMs = 3000,
  }) {
    if (_initialized) {
      _logger.i('SocketService already initialized');
      return;
    }

    _socketUrl = socketUrl ?? socketBaseUrl;
    _socketPath = socketPath ?? '/socket';
    _initialized = true;

    _logger.i('SocketService initialized with URL: $_socketUrl');
  }

  Future<bool> connect() async {
    // Prevent multiple connection attempts
    if (_connecting) {
      _logger.i('Connection already in progress');
      return false;
    }

    // Check if already connected
    if (_socket != null && _socket!.connected) {
      _logger.i('Socket is already connected');
      _connectionStateController.add(SocketConnectionState.connected);
      return true;
    }

    _connecting = true;

    try {
      // Check network connection first
      bool hasConnection = false;
      try {
        hasConnection = await _networkInfo.isConnected;
      } catch (e) {
        _logger.e('Error checking network connection', e);
        hasConnection = true; // Continue even if network check fails
      }

      if (!hasConnection) {
        _logger.e('No internet connection. Cannot connect to socket');
        _connectionStateController.add(SocketConnectionState.error);
        _connecting = false;
        throw AppError('No internet connection');
      }

      _connectionStateController.add(SocketConnectionState.connecting);
      _logger.i('Connecting to socket server: $_socketUrl');

      // Get the authentication token
      final token = await SecurePrefs.getString(SecureStorageKeys.TOKEN);
      if (token == null || token.isEmpty) {
        _logger.e('No authentication token available');
        _connectionStateController.add(SocketConnectionState.error);
        _connecting = false;
        throw AppError('No authentication token');
      }

      _logger.i('User token available');
      _logger.i('User token: $token');

      // IMPORTANT: Disconnect existing socket if any
      if (_socket != null) {
        _logger.i('Cleaning up existing socket connection');
        _socket!.clearListeners();
        _socket!.disconnect();
        _socket!.close();
        _socket = null;
      }

      // Create NEW socket instance with proper configuration
      _socket = io.io(
        _socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling']) // Include both transports
            .setPath(_socketPath)
            .setExtraHeaders({'token': token})
            .enableAutoConnect() // Let socket.io handle auto-connection
            .setReconnectionAttempts(5)
            .setReconnectionDelay(3000)
            .setReconnectionDelayMax(30000)
            .enableForceNew() // Force new connection
            .build(),
      );

      // Set up event listeners BEFORE connecting
      _setupSocketListeners();

      // Connect to the socket server
      _socket!.connect();

      // Wait for connection with timeout
      final completer = Completer<bool>();
      Timer? timeoutTimer;

      // Setup temporary listeners for connection response
      late StreamSubscription subscription;
      subscription = _connectionStateController.stream.listen((state) {
        if (state == SocketConnectionState.connected) {
          if (!completer.isCompleted) {
            completer.complete(true);
            timeoutTimer?.cancel();
            subscription.cancel();
          }
        } else if (state == SocketConnectionState.error) {
          if (!completer.isCompleted) {
            completer.complete(false);
            timeoutTimer?.cancel();
            subscription.cancel();
          }
        }
      });

      // Add timeout
      timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          _logger.w('Socket connection timeout');
          completer.complete(false);
          subscription.cancel();
        }
      });

      final result = await completer.future;
      _connecting = false;
      return result;
    } catch (e) {
      _logger.e('Error connecting to socket server', e);
      _connectionStateController.add(SocketConnectionState.error);
      _connecting = false;
      return false;
    }
  }

  // Set up socket event listeners - ONLY CALL ONCE PER SOCKET
  void _setupSocketListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      _logger.i('Socket connected successfully');
      log('CONNECTED', name: 'SOCKET');
      _connectionStateController.add(SocketConnectionState.connected);
      // Reset on successful connection
    });

    _socket!.onConnectError((error) {
      _logger.e('Socket connection error', error);
      log('CONNECTION ERROR: $error', name: 'SOCKET');
      _connectionStateController.add(SocketConnectionState.error);
    });

    _socket!.onDisconnect((reason) {
      _logger.w('Socket disconnected: $reason');
      log('DISCONNECTED: $reason', name: 'SOCKET');
      _connectionStateController.add(SocketConnectionState.disconnected);
    });

    _socket!.onError((error) {
      _logger.e('Socket error occurred', error);
      log('ERROR: $error', name: 'SOCKET');
      _connectionStateController.add(SocketConnectionState.error);
    });

    // Register all existing event handlers
    for (final entry in _eventHandlers.entries) {
      final event = entry.key;
      for (final handler in entry.value) {
        _socket!.on(event, (data) {
          try {
            handler(data);
          } catch (e) {
            _logger.e('Error in event handler for $event', e);
          }
        });
      }
    }
  }

  // Manually disconnect from the socket server
  void disconnect() {
    if (_socket != null) {
      _logger.i('Manually disconnecting socket');
      _socket!.disconnect();
      _connectionStateController.add(SocketConnectionState.disconnected);
    }
  }

  // Close and clean up all socket resources
  void closeSocket() {
    if (_socket != null) {
      _socket!.clearListeners();
      _socket!.disconnect();
      _socket!.close();
      _socket = null;
      _logger.i('Socket closed and listeners removed');
      log('Socket closed and listeners removed', name: "SOCKET");
    }
  }

  // Register a custom event handler
  void on(String event, Function(dynamic) handler) {
    if (!_eventHandlers.containsKey(event)) {
      _eventHandlers[event] = [];
    }

    _eventHandlers[event]!.add(handler);

    // Register the event with socket.io if we have an active socket
    if (_socket != null) {
      _socket!.on(event, (data) {
        _logger.d('Received event $event: $data');
        _notifyEventHandlers(event, data);
      });
    }

    _logger.d('Registered handler for event: $event');
  }

  // Notify all registered handlers for a specific event
  void _notifyEventHandlers(String event, dynamic data) {
    if (_eventHandlers.containsKey(event)) {
      for (var handler in _eventHandlers[event]!) {
        try {
          handler(data);
        } catch (e) {
          _logger.e('Error in event handler for $event', e);
        }
      }
    }
  }

  // Remove a specific event handler
  void off(String event, [Function(dynamic)? handler]) {
    if (handler == null) {
      // Remove all handlers for this event
      _eventHandlers.remove(event);
      if (_socket != null) {
        _socket!.off(event);
      }
      _logger.d('Removed all handlers for event: $event');
    } else if (_eventHandlers.containsKey(event)) {
      // Remove specific handler
      _eventHandlers[event]!.remove(handler);

      // If no handlers left, remove the event listener from socket
      if (_eventHandlers[event]!.isEmpty) {
        _eventHandlers.remove(event);
        if (_socket != null) {
          _socket!.off(event);
        }
      }
      _logger.d('Removed specific handler for event: $event');
    }
  }

  // Emit an event to the server
  void emit(
    String event, {
    dynamic data,
    Function(dynamic)? callback,
    bool withAck = false,
  }) {
    if (_socket != null && _socket!.connected) {
      _logger.d('Emitting event $event: $data');

      if (withAck && callback != null) {
        if (data != null) {
          _socket!.emitWithAck(event, data, ack: callback);
        } else {
          _socket!.emitWithAck(event, data, ack: callback);
        }
      } else {
        if (data != null) {
          _socket!.emit(event, data);
        } else {
          _socket!.emit(event);
        }
      }
    } else {
      _logger.w('Cannot emit event $event: Socket not connected');
      throw AppError('Socket not connected. Cannot emit event: $event');
    }
  }

  // Check if socket is connected
  bool get isConnected => _socket?.connected ?? false;

  // Get current socket ID
  String? get socketId => _socket?.id;

  // Update authentication data
  Future<void> updateAuthData(Map<String, dynamic> newAuthData) async {
    _logger.i('Updating auth data');

    if (_socket != null && _socket!.connected) {
      // Disconnect and reconnect with new auth data
      disconnect();

      // Wait a bit before reconnecting
      await Future.delayed(Duration(milliseconds: 500));

      // Reconnect
      await connect();
    }
  }

  // Listen for connection status
  void onConnect(Function() callback) {
    if (_socket != null) {
      _socket!.onConnect((_) => callback());
    }
  }

  // Listen for disconnection status
  void onDisconnect(Function() callback) {
    if (_socket != null) {
      _socket!.onDisconnect((_) => callback());
    }
  }

  // Handle errors
  void onError(Function(dynamic error) callback) {
    if (_socket != null) {
      _socket!.onError((error) => callback(error));
    }
  }

  // ✅ NEW: Complete reset method for logout scenarios
  void reset() {
    _logger.i('Resetting SocketService to clean state');

    try {
      // Cancel any existing connection attempts
      _connecting = false;

      // Close and dispose current socket
      if (_socket != null) {
        _socket!.clearListeners();
        _socket!.disconnect();
        _socket!.close();
        _socket = null;
        _logger.i('Socket instance completely destroyed');
      }

      // Clear all event handlers
      _eventHandlers.clear();
      _logger.i('All event handlers cleared');

      // Reset all state flags

      _initialized = false;
      _connecting = false;

      // Reset connection state without closing the stream controller
      // (we need to keep it alive for future connections)
      _connectionStateController.add(SocketConnectionState.disconnected);

      _logger.i(
        'SocketService reset completed - ready for fresh initialization',
      );
    } catch (e) {
      _logger.e('Error during SocketService reset', e);
    }
  }

  // Dispose the socket service (for complete app shutdown)
  void dispose() {
    _logger.i('Disposing SocketService');

    closeSocket();

    // Close stream controllers
    _connectionStateController.close();

    _initialized = false;
  }
}

// Socket events class
class SocketEvents {
  final String initialOnlineUser = "initial_online_user";
  final String onlineUser = "online_user";
  final String offlineUser = "offline_user";
  final String typing = "typing";
  final String receive = "receive";
  final String messageList = "message_list";
  final String chatList = "chat_list";
  final String realTimeMessageSeen = "real_time_message_seen"; //emmit for
  final String messageSeenStatus =
      "message_seen_status"; // this field update for actual message in model
  final String pinnedUnpinnedMessage = "pinned_unpinned_message";
  final String messageDeleteForMe = "delete_for_me";
  final String messageDeleteForEveryone = "delete_for_everyone";
  final String starUnstarMessage = "star_unstar_message";

  /// Archive Chat
  final String archiveChatEvent = "archive_chat";
  final String archivedChatListEvent = "archived_chat_list";

  /// Block/Unblock Updates
  final String blockUpdates = "block_updates";

  /// Live Stream
  final String startLive = "start_live";
  final String stopLive = "stop_live";
  final String joinLive = "join_live";
  final String leaveLive = "leave_live";
  final String activityOnLive = "activity_on_live";

  // Call emit
  final String makeCall = "call";
  final String acceptCall = "accept_call";
  final String rejectCall = "decline_call";
  final String endCall = "leave_call";

  // Call listen
  final String call = "call";
  final String declineCall = "call_declined";
  final String userJoinedCall = "user_joined";
  final String callEnded = "call_ended";
  final String missCall = "missed_call";
  final String userLeft = "user_left";
}
