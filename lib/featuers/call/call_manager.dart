// =============================================================================
// Enhanced Call Manager with improved flow from ultimate_call
// Based on webrtc_call_flow_flutter_updated.md documentation
//
// Socket Events:
// EMIT: call, accept_call, reject_call, leave_call
// LISTEN: call, user_joined, user_left, call_ended, call_declined, call_missed
// OPTIONAL: call_accepted, call_failed, peer_disconnected
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:stanchat/featuers/call/call_model.dart';
import 'package:stanchat/featuers/call/web_rtc_service.dart';
import 'package:stanchat/core/services/socket/socket_service.dart';
import 'package:stanchat/core/services/call_audio_manager.dart';
import 'package:stanchat/core/services/call_notification_manager.dart';
import 'package:stanchat/featuers/chat/services/contact_name_service.dart';
import 'package:stanchat/featuers/project-config/provider/config_provider.dart';
import 'package:stanchat/core/api/api_client.dart';
import 'package:stanchat/core/api/api_endpoint.dart';
import 'package:stanchat/utils/logger.dart';
import 'package:stanchat/widgets/global.dart';
import 'package:stanchat/core/navigation_helper.dart';

class CallManager {
  // Singleton
  static final CallManager _instance = CallManager._internal();
  static CallManager get instance => _instance;
  CallManager._internal();

  final _logger = ConsoleAppLogger.forModule('CallManager');

  // Dependencies
  final _webrtc = WebRTCService.instance;
  final _audioManager = CallAudioManager.instance;
  SocketService? _socket;
  ApiClient? _apiClient;

  // Platform channel for native audio restoration
  static const platform = MethodChannel('primocys.call.audio');

  SocketService get socket {
    _socket ??= GetIt.instance<SocketService>();
    return _socket!;
  }

  ApiClient get apiClient {
    _apiClient ??= GetIt.instance<ApiClient>();
    return _apiClient!;
  }

  // Enhanced call state with session management
  CallState _state = CallState.idle;
  CallInfo? _currentCall;
  final Map<String, CallParticipant> _participants = {};
  final Map<String, Map<String, dynamic>> _peerMetadata =
      {}; // Store metadata by peer ID
  String? _sessionId;
  String? _roomId;
  bool _isInitialized = false;
  Timer? _callTimeoutTimer;
  Timer? _connectionTimeoutTimer;
  DateTime? _lastEmergencyStop; // For debouncing emergency stops

  // Callbacks
  VoidCallback? onStateChanged;
  Function(CallParticipant participant)? onParticipantJoined;
  Function(String peerId)? onParticipantLeft;
  Function(String peerId, MediaStream stream)? onStreamAdded;
  Function(String peerId)? onStreamRemoved;
  Function(String error)? onError;
  Function(Map<String, dynamic> missedCallData)? onMissedCall;

  // Getters
  CallState get state => _state;
  CallInfo? get currentCall => _currentCall;
  List<CallParticipant> get participants => _participants.values.toList();
  bool get isInCall => _state != CallState.idle && _state != CallState.ended;
  bool get isInitialized => _isInitialized;
  String? get sessionId => _sessionId;
  String? get roomId => _roomId;
  int get participantCount => _participants.length + (isInCall ? 1 : 0);

  /// Initialize the call manager with enhanced setup
  Future<void> initialize() async {
    try {
      _logger.i('🚀 CallManager: Initializing...');

      // Initialize audio manager
      await _audioManager.initialize();

      // Setup audio manager timeout callback
      _audioManager.onCallTimeout = () {
        if (_state == CallState.ringing || _state == CallState.calling) {
          _logger.w('⏰ CallManager: Auto call timeout');

          // Trigger missed call callback
          final missedCallData = {
            'missed_call_type':
                _currentCall?.isIncoming == true
                    ? 'incoming_timeout'
                    : 'outgoing_timeout',
            'reason':
                _currentCall?.isIncoming == true
                    ? 'Incoming call timeout - no user action'
                    : 'Outgoing call timeout - caller auto-end',
            'call_id': _currentCall?.callId,
            'chat_id': _currentCall?.chatId,
            'call_type': _currentCall?.callType.name,
            'caller_name': _currentCall?.callerName,
            'duration': callDuration?.inSeconds ?? 0,
            'timestamp': DateTime.now().toIso8601String(),
          };
          onMissedCall?.call(missedCallData);

          // Use appropriate method based on call direction
          if (_currentCall?.isIncoming == false) {
            // For outgoing calls, use leaveCall to emit leave_call event
            leaveCall();
          } else {
            // For incoming calls, just cleanup without emitting events
            _cleanup();
          }
        }
      };

      // Setup WebRTC callbacks
      _webrtc.onRemoteStreamAdded = _handleRemoteStreamAdded;
      _webrtc.onRemoteStreamRemoved = _handleRemoteStreamRemoved;
      _webrtc.onIncomingCallWithMetadata = _handleIncomingCallWithMetadata;

      // Setup socket listeners
      _setupSocketListeners();

      _isInitialized = true;
      _logger.i('✅ CallManager: Initialized successfully');
    } catch (e) {
      _logger.e('❌ CallManager: Failed to initialize: $e');
      onError?.call('Failed to initialize call manager: $e');
      rethrow;
    }
  }

  /// Setup socket event listeners with enhanced error handling
  /// Based on webrtc_call_flow_flutter_updated.md documentation
  void _setupSocketListeners() {
    try {
      // CRITICAL: Remove existing listeners first to prevent duplicates
      socket.off('call');
      socket.off('receiving_call');
      socket.off('user_joined');
      socket.off('user_left');
      socket.off('call_ended');
      socket.off('call_declined');
      socket.off('call_missed');
      socket.off('call_accepted');
      socket.off('call_failed');
      socket.off('peer_disconnected');
      socket.off('call_changes');

      socket.on(
        'receiving_call',
        _handleIncomingCall,
      ); // NEW: Handle incoming calls
      socket.on(
        'user_joined',
        _handleUserJoined,
      ); // A new user joined the call room
      socket.on('user_left', _handleUserLeft); // When user leaves call
      socket.on(
        'call_ended',
        _handleCallEnded,
      ); // The call was ended by someone
      socket.on(
        'call_declined',
        _handleCallDeclined,
      ); // Listener gets notified of rejection
      socket.on('missed_call', _handleCallMissed); // Missed call (no answer)
      _logger.i('✅ Missed call listener registered');

      // NEW: Real-time call changes event for audio/video state updates
      socket.on('call_changes', _handleCallChanges);

      // Optional events (may or may not be supported by current backend)
      socket.on(
        'call_accepted',
        _handleCallAccepted,
      ); // Call acceptance confirmation
      socket.on('call_failed', _handleCallFailed); // Call failure notification
      socket.on(
        'peer_disconnected',
        _handlePeerDisconnected,
      ); // Peer disconnection

      _logger.i('✅ Socket listeners setup successfully (duplicates removed)');
    } catch (e) {
      _logger.e('❌ Error setting up socket listeners: $e');
      onError?.call('Socket setup failed: $e');
    }
  }

  /// Make a call with enhanced flow and error handling
  Future<void> makeCall({
    required int chatId,
    required CallType callType,
    required String chatName,
    int? peerId, // Peer user ID for calls without existing chat (chatId = 0)
  }) async {
    try {
      _logger.i(
        '📞 CallManager: Making ${callType.name} call to chat $chatId${peerId != null ? ', peerId: $peerId' : ''}',
      );

      // CRITICAL: Prevent multiple simultaneous calls
      if (isInCall) {
        _logger.w('⚠️ CallManager: Already in a call, cannot make new call');
        throw Exception('Already in a call');
      }

      // Generate session and room IDs
      _sessionId = _generateSessionId();
      _roomId = _generateRoomId(chatId);

      // Update state
      _setState(CallState.calling);
      _currentCall = CallInfo(
        chatId: chatId,
        callType: callType,
        callerName: chatName,
        isIncoming: false,
        sessionId: _sessionId,
        roomId: _roomId,
      );

      // Get user ID first for API call and WebRTC initialization
      final userId = userID.toString();

      // CRITICAL: Call /call/make-call API FIRST before any other call process
      _logger.i('🚀 CallManager: Calling /call/make-call API first...');

      try {
        // Build API body based on whether we have chat_id or peer_id
        final Map<String, dynamic> apiBody = {'call_type': callType.name};

        // CRITICAL FIX: When chatId is 0/null, send peer_id instead of chat_id
        // Don't send chat_id at all when it's 0 - API only needs peer_id for new chats
        if (chatId > 0) {
          apiBody['chat_id'] = chatId;
          _logger.i('📞 CallManager: Using chat_id=$chatId for API request');
        } else if (peerId != null) {
          apiBody['peer_id'] = peerId;
          _logger.i(
            '📞 CallManager: Using peer_id=$peerId for API request (no chat_id)',
          );
        }

        _logger.i('📞 CallManager: API body = $apiBody');

        final apiResponse = await apiClient.request(
          ApiEndpoints.makeCall,
          method: 'POST',
          body: apiBody,
        );

        _logger.i('✅ CallManager: API call successful: $apiResponse');

        // Extract call data and user data from API response
        final callData = apiResponse['call'];
        final userData = apiResponse['user'];

        if (callData != null) {
          // Update current call with complete API response data
          _currentCall = _currentCall!.copyWith(
            callId: callData['call_id'],
            roomId: callData['room_id'],
            startTime:
                callData['start_time'] != null
                    ? DateTime.tryParse(callData['start_time'])
                    : null,
            peerId: userId, // Set peerId to current user ID for outgoing call
          );
          _roomId = callData['room_id'];
          _sessionId =
              callData['session_id'] ??
              _sessionId; // Use API session ID if provided

          _logger.i('✅ CallManager: Call data updated from API');
          _logger.i('   - Call ID: ${_currentCall!.callId}');
          _logger.i('   - Room ID: $_roomId');
          _logger.i('   - Session ID: $_sessionId');
          _logger.i('   - Call Status: ${callData['call_status']}');
          _logger.i('   - Current Users: ${callData['current_users']}');
          _logger.i('   - Message ID: ${callData['message_id']}');
          _logger.i('   - User ID: ${callData['user_id']}');
          _logger.i('   - Caller PeerID set to: $userId');
        }

        // Store user data for caller information - this ensures we have caller details for peer connections
        if (userData != null) {
          _logger.i('✅ CallManager: User data from API');
          _logger.i('   - User ID: ${userData['user_id']}');
          _logger.i('   - Full Name: ${userData['full_name'] ?? 'N/A'}');
          _logger.i('   - Profile Pic: ${userData['profile_pic'] ?? 'N/A'}');
          _logger.i('   - Socket IDs: ${userData['socket_ids']}');
          _logger.i('   - Country: ${userData['country'] ?? 'N/A'}');
          _logger.i('   - Device Token: ${userData['device_token'] ?? 'N/A'}');

          // Store current user metadata for peer connections
          final currentUserMetadata = {
            'user_id': userData['user_id'],
            'user_name': userData['user_name'] ?? '',
            'full_name': userData['full_name'] ?? '',
            'first_name': userData['first_name'] ?? '',
            'last_name': userData['last_name'] ?? '',
            'profile_pic': userData['profile_pic'] ?? '',
            'country': userData['country'] ?? '',
            'country_code': userData['country_code'] ?? '',
          };

          // Store this for when other users join the call
          _peerMetadata[userId] = currentUserMetadata;
          _logger.i('💾 Stored current user metadata for peer connections');
        }
      } catch (apiError) {
        _logger.e('❌ CallManager: API call failed: $apiError');
        _setState(CallState.failed);
        await _cleanup();
        onError?.call('Failed to initiate call: $apiError');
        rethrow;
      }

      // Initialize WebRTC after successful API call
      await _webrtc.initialize(userId: userId, callType: callType);

      // 🚀 FINAL: WebRTC-native outgoing video call speaker setup
      if (callType == CallType.video) {
        _logger.i(
          '🚀 FINAL: WebRTC-native outgoing video call speaker setup...',
        );

        // Configure audio for video call with speaker
        await _audioManager.configureAudioForCall(useSpeaker: true);

        _logger.i(
          '✅ FINAL: WebRTC-native outgoing video call speaker setup completed',
        );
      }

      // CRITICAL: Both users must emit "accept_call" regardless of who initiated the call

      if (_currentCall != null) {
        socket.emit(
          'accept_call',
          data: {
            'call_id': _currentCall!.callId,
            'peer_id': _webrtc.myPeerId, // Use generated WebRTC peer ID
            'chat_id': _currentCall!.chatId,
            'user_name': userName, // Use global user name
            'user_id': userID, // Use global user ID
          },
        );
        _logger.i(
          '📤 CallManager: Call maker emitted accept_call for call_id: ${_currentCall!.callId}',
        );
      }

      // The socket emit has been moved to AFTER API call completion

      // Start caller tone with proper audio routing based on call type
      await _audioManager.startCallerTone(
        isVideoCall: callType == CallType.video,
      );

      // CRITICAL: Set timeout for call response (frontend-side handling)
      _callTimeoutTimer = Timer(Duration(seconds: 30), () {
        if (_state == CallState.calling) {
          _logger.w('⚠️ CallManager: Call timeout - no response');

          // Trigger missed call callback for outgoing call timeout
          if (_currentCall?.isIncoming == false) {
            final missedCallData = {
              'missed_call_type': 'outgoing_timeout',
              'reason': 'Outgoing call timeout - no receiver response',
              'call_id': _currentCall?.callId,
              'chat_id': _currentCall?.chatId,
              'call_type': _currentCall?.callType.name,
              'caller_name': _currentCall?.callerName,
              'duration': callDuration?.inSeconds ?? 0,
              'timestamp': DateTime.now().toIso8601String(),
            };
            onMissedCall?.call(missedCallData);
          }

          _setState(CallState.failed);
          onError?.call('Call timeout - no response');
          _cleanup();
        }
      });

      _logger.i(
        '✅ CallManager: Call initiated successfully with API-first flow',
      );
    } catch (e) {
      _logger.e('❌ CallManager: Failed to make call: $e');
      _setState(CallState.failed);
      await _cleanup();
      onError?.call('Failed to make call: $e');
      rethrow;
    }
  }

  /// Accept incoming call with enhanced flow
  Future<void> acceptCall() async {
    try {
      _logger.i('✅ CallManager: Accepting call');

      if (_currentCall == null || _state != CallState.ringing) {
        throw Exception('No incoming call to accept');
      }

      // CRITICAL: Single emergency stop with debouncing
      final now = DateTime.now();

      if (_lastEmergencyStop == null ||
          now.difference(_lastEmergencyStop!).inMilliseconds > 1000) {
        _lastEmergencyStop = now;
        await _emergencyStopAllAudio();
      }

      // Configure audio with proper speaker state
      final useSpeaker = _currentCall!.callType == CallType.video;
      await _audioManager.configureAudioForCall(useSpeaker: useSpeaker);

      // Update state to connecting
      _setState(CallState.connecting);

      // Initialize WebRTC with clean audio state
      final userId = userID.toString();
      await _webrtc.initialize(
        userId: userId,
        callType: _currentCall!.callType,
      );
      // Note: peerId is formatted as 'peer-{userId}-{timestamp}' for WebRTC internal use

      // Emit accept_call
      socket.emit(
        'accept_call',
        data: {
          'call_id': _currentCall!.callId,
          'peer_id': _webrtc.myPeerId,
          'chat_id': _currentCall!.chatId,
          'user_name': userName,
          'user_id': userID,
        },
      );
      // Set connection timeout
      _connectionTimeoutTimer = Timer(Duration(seconds: 30), () {
        if (_state == CallState.connecting) {
          _logger.w('⚠️ CallManager: Connection timeout');
          _setState(CallState.failed);
          onError?.call('Connection timeout');
          _cleanup();
        }
      });

      // Configure speaker for video calls
      if (_currentCall!.callType == CallType.video) {
        await _audioManager.configureAudioForCall(useSpeaker: true);
      }

      // Transition to connected state
      _setState(CallState.connected);
      _callTimeoutTimer?.cancel();
      _connectionTimeoutTimer?.cancel();

      _logger.i('✅ CallManager: Call accepted successfully');
    } catch (e) {
      _logger.e('❌ CallManager: Failed to accept call: $e');
      _setState(CallState.failed);
      onError?.call('Failed to accept call: $e');
      rethrow;
    }
  }

  /// Decline incoming call with proper cleanup
  Future<void> declineCall({bool isAutoTimeout = false}) async {
    _logger.i('❌ CallManager: Declining call (isAutoTimeout: $isAutoTimeout)');

    if (_currentCall == null) return;

    try {
      // CRITICAL: Emergency stop all audio immediately (decline call - restore session)
      await _emergencyStopAllAudioAndRestore();

      // Always use decline_call for declineCall method
      _logger.i('❌ CallManager: Emitting decline_call');
      socket.emit(
        'decline_call',
        data: {
          'call_id': _currentCall!.callId,
          'chat_id': _currentCall!.chatId,
          'peer_id': userID.toString(),
        },
      );

      _logger.i('✅ CallManager: Call declined successfully');
    } catch (e) {
      _logger.e('❌ Error declining call: $e');
    }

    await _cleanup();
  }

  /// Leave current call (emits leave_call event)
  Future<void> leaveCall() async {
    _logger.i('🔍 DEBUG: CallManager.leaveCall() called');
    _logger.i('🔍 DEBUG: Current state: ${_state.name}');
    _logger.i('🔍 DEBUG: Current call: ${_currentCall?.toString()}');
    _logger.i('🚪 CallManager: Leaving call (current state: ${_state.name})');

    if (_currentCall == null) {
      _logger.w('⚠️ CallManager: No current call to leave');
      return;
    }

    try {
      // CRITICAL: Emergency stop all audio immediately (leave call - restore session)
      await _emergencyStopAllAudioAndRestore();

      // Emit leave_call event with proper body
      final leaveCallData = <String, dynamic>{
        'peer_id': userID,
        'chat_id': _currentCall!.chatId,
      };

      // Include call_id if available
      if (_currentCall!.callId != null) {
        leaveCallData['call_id'] = _currentCall!.callId;
        _logger.i(
          '🚪 CallManager: Including call_id in leave_call: ${_currentCall!.callId}',
        );
      } else {
        _logger.w(
          '⚠️ CallManager: call_id is null, sending leave_call without call_id',
        );
      }

      _logger.i(
        '🚪 CallManager: Emitting leave_call with data: $leaveCallData',
      );
      socket.emit('leave_call', data: leaveCallData);

      // Update state and cleanup
      _setState(CallState.ended);
      await _cleanup();

      _logger.i('✅ CallManager: Left call successfully');
    } catch (e) {
      _logger.e('❌ Error leaving call: $e');
      // Force cleanup even on error
      await _forceCleanup();
    }
  }

  /// End current call with proper cleanup
  Future<void> endCall() async {
    _logger.i('🔚 CallManager: Ending call (current state: ${_state.name})');

    // CRITICAL: Prevent multiple end call attempts
    if (_state == CallState.idle || _state == CallState.ended) {
      _logger.d('⚠️ CallManager: Call already ended');
      return;
    }

    try {
      // CRITICAL: Emergency stop all audio immediately (end call - restore session)
      await _emergencyStopAllAudioAndRestore();

      if (_currentCall != null) {
        // CRITICAL: Different socket events based on call state
        String socketEvent = 'leave_call';

        // If caller is ending call during ringing/calling state, this should trigger missed_call on receiver
        if (_state == CallState.calling || _state == CallState.ringing) {
          _logger.i(
            '🔚 CallManager: Ending call during ringing/calling state - this may trigger missed_call for receiver',
          );

          // Trigger local missed call callback for manual end during ringing/calling
          if (_currentCall != null) {
            final missedCallData = {
              'missed_call_type':
                  _currentCall!.isIncoming
                      ? 'incoming_manual_decline'
                      : 'outgoing_manual_cancel',
              'reason':
                  _currentCall!.isIncoming
                      ? 'Incoming call manually declined'
                      : 'Outgoing call manually cancelled',
              'call_id': _currentCall!.callId,
              'chat_id': _currentCall!.chatId,
              'call_type': _currentCall!.callType.name,
              'caller_name': _currentCall!.callerName,
              'duration': callDuration?.inSeconds ?? 0,
              'timestamp': DateTime.now().toIso8601String(),
            };
            onMissedCall?.call(missedCallData);
          }
        }

        // Send end call via socket - include call_id as required
        final leaveCallData = <String, dynamic>{
          'peer_id': userID,
          'chat_id': _currentCall!.chatId,
        };

        // CRITICAL: Only include call_id if it's not null to avoid server errors
        if (_currentCall!.callId != null) {
          leaveCallData['call_id'] = _currentCall!.callId;
          _logger.i(
            '🔚 CallManager: Including call_id in leave_call: ${_currentCall!.callId}',
          );
        } else {
          _logger.w(
            '⚠️ CallManager: call_id is null, sending leave_call without call_id',
          );
        }

        _logger.i(
          '🔚 CallManager: Emitting $socketEvent with data: $leaveCallData',
        );
        socket.emit(socketEvent, data: leaveCallData);
      }

      // Update state and cleanup
      _setState(CallState.ended);
      await _cleanup();

      _logger.i('✅ CallManager: Call ended successfully');
    } catch (e) {
      _logger.e('❌ Error ending call: $e');
      // Force cleanup even on error
      await _forceCleanup();
    }
  }

  /// Handle incoming call from socket - UPDATED for 'receiving_call' event
  void _handleIncomingCall(dynamic data) async {
    _logger.i('🔍 CallManager: Raw receiving_call data: $data');

    // Only reject if already in call
    if (isInCall) {
      _logger.w('⚠️ CallManager: Already in call, rejecting incoming call');
      return;
    }

    try {
      final callData = data['call'] ?? {};
      final userData = data['user'] ?? {};
      final chatData = data['chat'] ?? {};

      _logger.i('🔍 CallManager: Parsed call data: $callData');
      _logger.i('🔍 CallManager: Parsed user data: $userData');
      _logger.i('🔍 CallManager: Parsed chat data: $chatData');

      if (callData.isEmpty) {
        _logger.e('❌ CallManager: No call data in receiving_call event');
        return;
      }

      // Extract caller information from user data
      String callerName = 'Unknown Caller';
      String callerId = '';

      if (userData.isNotEmpty) {
        // Extract caller details from user object
        final userDetails = userData['User'] ?? userData;
        callerId =
            userDetails['user_id']?.toString() ??
            userData['user_id']?.toString() ??
            '';

        callerName =
            userDetails['full_name']?.toString() ??
            userData['full_name']?.toString() ??
            'Caller $callerId';

        _logger.i(
          '✅ CallManager: Caller info - ID: $callerId, Name: $callerName',
        );
      }

      // Extract chat information
      String chatName = '';
      if (chatData.isNotEmpty) {
        chatName =
            chatData['group_name']?.toString() ??
            chatData['chat_name']?.toString() ??
            'Chat ${callData['chat_id']}';

        _logger.i(
          '✅ CallManager: Chat info - Name: $chatName, IsPrivate: ${chatData['is_private']}',
        );
      }

      // Use chat name for group calls, caller name for individual calls
      final displayName =
          chatData['is_private'] != true ? chatName : callerName;

      // Parse start time from call data
      DateTime? incomingStartTime;
      final serverStartTimeData = callData['start_time'];
      if (serverStartTimeData != null) {
        try {
          incomingStartTime = DateTime.tryParse(serverStartTimeData.toString());
          if (incomingStartTime != null) {
            _logger.i('⏱️ CallManager: Server start time: $incomingStartTime');
          }
        } catch (e) {
          _logger.w('⚠️ CallManager: Failed to parse start time: $e');
        }
      }

      // Create CallInfo with complete data from receiving_call event
      _currentCall = CallInfo(
        chatId: callData['chat_id'] ?? 0,
        callId: callData['call_id'],
        roomId: callData['room_id'],
        sessionId: callData['session_id'],
        callType:
            callData['call_type'] == 'video' ? CallType.video : CallType.audio,
        callerName: displayName,
        isIncoming: true,
        startTime: incomingStartTime,
        peerId: callData['peer_id'],
        callerProfilePic:
            userData['profile_pic'], // Add profile picture from incoming call data
      );

      // Update manager state variables
      _sessionId = callData['session_id'];
      _roomId = callData['room_id'];

      _logger.i('✅ CallManager: Created incoming call info');
      _logger.i('   - Call ID: ${_currentCall!.callId}');
      _logger.i('   - Room ID: $_roomId');
      _logger.i('   - Session ID: $_sessionId');
      _logger.i('   - Call Type: ${_currentCall!.callType.name}');
      _logger.i('   - Caller: ${_currentCall!.callerName}');
      _logger.i('   - Chat ID: ${_currentCall!.chatId}');
      _logger.i('   - Current Users: ${callData['current_users']}');

      _setState(CallState.ringing);

      // Start ringtone with loudspeaker for incoming call
      await _audioManager.startIncomingCallRingtone();

      // CRITICAL FIX: Trigger navigation to incoming call screen for both iOS and Android
      try {
        final callData = {
          'chatId': _currentCall!.chatId,
          'callId': _currentCall!.callId,
          'peerId': _currentCall!.peerId,
          'roomId': _currentCall!.roomId,
          'callType': _currentCall!.callType.name,
          'callerName': _currentCall!.callerName,
          'callerAvatar': _currentCall!.callerProfilePic ?? '',
        };

        _logger.i(
          '🚀 Triggering NavigationHelper for incoming call: $callData',
        );
        NavigationHelper.handleIncomingCall(callData);
      } catch (e) {
        _logger.e('❌ Error triggering navigation for incoming call: $e');
      }

      _logger.i('✅ CallManager: Incoming call processed successfully');
    } catch (e) {
      _logger.e('❌ Error processing receiving_call: $e');
      onError?.call('Failed to process incoming call: $e');
    }
  }

  /// ✅ PUBLIC: Handle incoming call from notification
  void handleIncomingCallFromNotification(dynamic data) {
    _logger.i('📞 CallManager: Incoming call from notification: $data');
    _handleIncomingCall(data);
  }

  /// Handle user joined event
  void _handleUserJoined(dynamic data) async {
    try {
      _logger.i('🔍 CallManager: Raw user_joined data: $data');

      final peerId = data['peer_id'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;

      if (peerId == null) {
        _logger.w('⚠️ Invalid user joined data - missing peer_id: $data');
        return;
      }

      _logger.i('🔍 CallManager: Extracted userData: $userData');
      _logger.i('🔍 CallManager: PeerId: $peerId');

      // Extract user information with better fallbacks
      final userId =
          userData?['user_id']?.toString() ??
          userData?['id']?.toString() ??
          userData?['userId']?.toString() ??
          data['user_id']?.toString() ??
          data['id']?.toString() ??
          '';

      _logger.i(
        '👤 CallManager: User joined - UserID: $userId, PeerID: $peerId',
      );
      _logger.i(
        '🔍 CallManager: Socket user data keys: ${userData?.keys.toList()}',
      );

      // CRITICAL: Set call ID from user_joined event if not already set
      if (_currentCall != null && _currentCall!.callId == null) {
        final callId = data['call_id'];
        if (callId != null) {
          _currentCall = _currentCall!.copyWith(callId: callId);
          _logger.i(
            '✅ CallManager: Call ID set from user_joined event: $callId',
          );
        }
      }

      // Try to extract server start_time for synchronized timing from call object
      DateTime? serverStartTime;
      final callData = data['call'];
      final serverTimestamp =
          callData?['start_time'] ??
          data['call_start_time'] ??
          data['start_time'] ??
          data['timestamp'];

      if (serverTimestamp != null) {
        try {
          if (serverTimestamp is int) {
            serverStartTime = DateTime.fromMillisecondsSinceEpoch(
              serverTimestamp,
            );
          } else if (serverTimestamp is String) {
            // Handle timestamp format with spaces: "2025-09-03T06: 49: 20.253Z"
            String cleanedTimestamp = serverTimestamp.replaceAll(' ', '');
            serverStartTime = DateTime.tryParse(cleanedTimestamp);
          }
          if (serverStartTime != null) {
            _logger.i(
              '⏱️ CallManager: Server provided synchronized start_time from call data: $serverStartTime',
            );
          } else {
            _logger.w(
              '⚠️ CallManager: Failed to parse server start_time: "$serverTimestamp"',
            );
          }
        } catch (e) {
          _logger.w('⚠️ CallManager: Failed to parse server start_time: $e');
        }
      }

      // Log the full call data for debugging
      if (callData != null) {
        _logger.i('📞 CallManager: Call data from server: $callData');
        _logger.i(
          '📞 CallManager: Call status: ${callData['call_status']}, Start time: ${callData['start_time']}',
        );
      }

      // ALWAYS set startTime from server data for ALL users (including call maker) for synchronized display
      if (_currentCall != null && serverStartTime != null) {
        if (_currentCall!.startTime == null) {
          // First time setting startTime - use server start_time directly
          _currentCall = _currentCall!.copyWith(startTime: serverStartTime);
          final durationFromStart =
              DateTime.now().difference(serverStartTime).inSeconds;
          _logger.i(
            '⏱️ CallManager: Setting startTime from server for ALL users - startTime: $serverStartTime, current duration: ${durationFromStart}s',
          );
        } else {
          // Force sync if server time is significantly different
          final currentStartTime = _currentCall!.startTime!;
          final serverTimeDiff =
              currentStartTime.difference(serverStartTime).abs().inSeconds;

          if (serverTimeDiff > 2) {
            _currentCall = _currentCall!.copyWith(startTime: serverStartTime);
            final newDuration =
                DateTime.now().difference(serverStartTime).inSeconds;
            _logger.i(
              '🔄 CallManager: Force synchronized to server start_time - new duration: ${newDuration}s',
            );
          }
        }
      }

      // Check if this is the call maker's own join event
      bool skipOwnJoinEvent = false;
      final isOwnPeerId = peerId == _webrtc.myPeerId;
      final isOwnUserId = userId == userID.toString();

      if (isOwnPeerId || isOwnUserId) {
        skipOwnJoinEvent = true;
        _logger.d(
          '📍 CallManager: Own join event detected - PeerID match: $isOwnPeerId, UserID match: $isOwnUserId ($userId == $userID)',
        );
      }

      // Count total participants (excluding self if this is own join event)
      final totalParticipants =
          skipOwnJoinEvent
              ? _participants.length +
                  1 // +1 for self
              : _participants.length +
                  2; // +1 for self, +1 for the joining participant

      _logger.i(
        '🔍 CallManager: Participant count check - current: ${_participants.length}, total after join: $totalParticipants, isOwnJoin: $skipOwnJoinEvent',
      );
      _logger.i(
        '🔍 CallManager: Logic branches - will go to connected: ${totalParticipants >= 2 && !skipOwnJoinEvent}, will go to ringing: ${totalParticipants == 1 || skipOwnJoinEvent}',
      );

      // CRITICAL: Only transition to connected state when we have 2+ users AND it's not our own join event
      // This prevents the call maker's own join from starting the call
      if ((_state == CallState.connecting || _state == CallState.calling) &&
          totalParticipants >= 2 &&
          !skipOwnJoinEvent) {
        _logger.i(
          '✅ CallManager: Transitioning to connected state - 2+ users present ($totalParticipants total)',
        );

        // CRITICAL: Emergency stop caller tone and configure audio for call
        await _emergencyStopAllAudio();

        // CRITICAL: Also explicitly stop caller tone to fix phone ringtone continuing issue
        await _audioManager.stopCallerTone();

        // Configure audio with proper speaker state based on call type
        final useSpeaker = _currentCall?.callType == CallType.video;
        await _audioManager.configureAudioForCall(useSpeaker: useSpeaker);

        // 🚀 FINAL: WebRTC-native speaker enforcement for video calls in user_joined
        if (useSpeaker) {
          _logger.i(
            '🚀 FINAL: WebRTC-native speaker enforcement in user_joined...',
          );

          // Set speaker via WebRTC-native control
          await setSpeakerphone(true);

          _logger.i(
            '✅ FINAL: WebRTC-native speaker enforcement in user_joined completed',
          );
        }

        _setState(CallState.connected);

        // Clear timeout timers on successful connection
        _callTimeoutTimer?.cancel();
        _connectionTimeoutTimer?.cancel();
      } else if (totalParticipants == 1 || skipOwnJoinEvent) {
        _logger.i(
          '🔔 CallManager: Ringing condition met - totalParticipants: $totalParticipants, skipOwnJoin: $skipOwnJoinEvent',
        );

        if (skipOwnJoinEvent) {
          _logger.i(
            '🔔 CallManager: Call maker\'s own join event - maintaining ringing state, will configure audio',
          );
        } else {
          _logger.i(
            '🔔 CallManager: Maintaining ringing state - only 1 user present, waiting for 2nd participant',
          );
        }

        // Ensure we're in the correct ringing state based on call direction
        if (_state == CallState.connecting || _state == CallState.calling) {
          if (_currentCall?.isIncoming == true) {
            _setState(CallState.ringing);
          } else {
            _setState(CallState.calling);
          }
        }

        // Configure ringing audio based on call type
        final isVideoCall = _currentCall?.callType == CallType.video;
        _logger.i(
          '🔔 CallManager: Configuring ringing audio - isVideoCall: $isVideoCall, isIncoming: ${_currentCall?.isIncoming}',
        );

        if (_currentCall?.isIncoming == false) {
          // For outgoing calls, caller tone should already be playing from makeCall()
          // Don't restart it here to avoid "Loading interrupted" errors
          _logger.i(
            '📞 CallManager: Caller tone should already be playing from makeCall() - ${isVideoCall ? "video (speaker)" : "audio (earpiece)"}',
          );

          // Only ensure proper audio routing is configured without restarting ringtone
          // Use the public configureAudioForCall method but don't use emergency stop (which would kill the caller tone)
          _logger.d(
            '🎵 CallManager: Ensuring audio routing is configured for ongoing caller tone',
          );
          // Note: We don't call configureAudioForCall here as it would stop the caller tone
          // The caller tone from makeCall() should continue playing until 2nd user joins
        } else {
          // For incoming calls, ringtone is already handled elsewhere
          // Just ensure proper audio routing for the call type
          _logger.i(
            '📞 CallManager: Configuring audio for incoming call - ${isVideoCall ? "video (speaker)" : "audio (earpiece)"}',
          );
          final useSpeaker = isVideoCall;
          await _audioManager.configureAudioForCall(useSpeaker: useSpeaker);
        }
      }

      // Skip participant handling if it's us (but state/startTime logic already executed above)
      if (skipOwnJoinEvent) {
        _logger.d(
          '📍 CallManager: Skipping own join event participant handling (but state/timer logic already executed)',
        );
        return;
      }

      // CRITICAL: Check if participant already exists
      final existingParticipant = _participants[peerId];
      if (existingParticipant != null) {
        // Only update connection status, NOT the name (name comes from metadata only)
        final updatedParticipant = existingParticipant.copyWith(
          userId: userId,
          isConnected: true,
        );
        _participants[peerId] = updatedParticipant;
        _logger.i(
          '✅ Updated participant connection status (peerId: $peerId, name unchanged: ${existingParticipant.userName})',
        );
        // Notify UI about the connection update
        onParticipantJoined?.call(updatedParticipant);
      } else {
        // Create new participant - IMMEDIATELY use socket userData instead of temporary name
        String participantName;
        final existingMetadata = _peerMetadata[peerId];

        if (existingMetadata != null) {
          // Use existing metadata if available
          participantName = _extractNameFromMetadata(existingMetadata, userId);
          _logger.i(
            '✅ Using existing metadata for new participant: $participantName',
          );
        } else if (userData != null) {
          // CRITICAL: Use socket userData IMMEDIATELY - no temporary names!
          participantName = _extractUserName(userData, 'User $userId');
          _logger.i(
            '✅ Using socket userData for new participant: $participantName',
          );
        } else {
          // Last resort fallback (should rarely happen)
          participantName = 'User $userId';
          _logger.i('⚠️ Using fallback name for participant: $participantName');
        }

        final newParticipant = CallParticipant(
          peerId: peerId,
          userId: userId,
          userName: participantName,
          isConnected: true,
        );
        _participants[peerId] = newParticipant;
        _logger.i('✅ Created participant: $participantName (peerId: $peerId)');

        // Notify UI about new participant
        onParticipantJoined?.call(newParticipant);

        // Call the new participant with metadata (sending LOCAL user's info)
        // CRITICAL: Use same key structure as socket data for consistency
        final localFullName =
            '${firstName.isNotEmpty ? firstName : ""} ${lastName.isNotEmpty ? lastName : ""}'
                .trim();
        final primaryName =
            userName.isNotEmpty
                ? userName
                : localFullName.isNotEmpty
                ? localFullName
                : firstName.isNotEmpty
                ? firstName
                : 'User';

        final metadata = {
          'user_id': userID.toString(),
          'user_name':
              userName.isNotEmpty
                  ? userName
                  : primaryName, // Match socket data priority
          'full_name': localFullName.isNotEmpty ? localFullName : primaryName,
          'first_name': firstName.isNotEmpty ? firstName : '',
          'last_name': lastName.isNotEmpty ? lastName : '',
        };

        _logger.i(
          '📤 CALLING $peerId with LOCAL name: ${metadata['user_name']} (user_id: ${metadata['user_id']})',
        );

        _webrtc.callPeer(peerId, metadata: metadata).catchError((e) {
          _logger.e('❌ CallManager: Failed to call peer $peerId: $e');
          onError?.call('Failed to connect to peer');
        });
      }

      _logger.i('✅ CallManager: User joined processed successfully');
    } catch (e) {
      _logger.e('❌ Error handling user joined: $e');
      onError?.call('Error processing user joined: $e');
    }
  }

  /// Handle user left event
  void _handleUserLeft(dynamic data) {
    try {
      final peerId = data['peer_id'] as String?;

      if (peerId == null) {
        _logger.w('⚠️ Invalid user left data: $data');
        return;
      }

      // CRITICAL: Check if participant exists to prevent duplicate processing
      final participant = _participants[peerId];
      if (participant == null) {
        _logger.w(
          '⚠️ CallManager: Participant $peerId already removed or never existed',
        );
        // CRITICAL: Still notify UI even if participant not found to ensure cleanup
        onParticipantLeft?.call(peerId);
        onStreamRemoved?.call(peerId);
        return;
      }

      _logger.i('👤 CallManager: User left: ${participant.userName} ($peerId)');

      // CRITICAL: Remove participant from list first to prevent race conditions
      _participants.remove(peerId);
      _peerMetadata.remove(peerId); // Clean up metadata
      _logger.i('✅ Removed participant: ${participant.userName}');

      // CRITICAL: Close WebRTC connection and dispose streams properly
      try {
        _webrtc.closePeerConnection(peerId);
      } catch (e) {
        _logger.w('⚠️ Error closing WebRTC connection for $peerId: $e');
      }

      // CRITICAL: Notify UI components IMMEDIATELY for cleanup
      onStreamRemoved?.call(peerId);
      onParticipantLeft?.call(peerId);

      // ENHANCED: Check if call should end based on remaining participants and call state
      // Only end the call if there's only 1 user left (just the local user) AND it's not a group call scenario
      final remainingUsers = _participants.length + 1; // +1 for local user
      final leftReason = data['reason']?.toString() ?? 'unknown';

      _logger.i(
        '👥 CallManager: Remaining users after user left: $remainingUsers (reason: $leftReason)',
      );

      // STATE-AWARE: Handle call ending based on current state
      final callData = data['call'];
      final currentUsers = callData?['current_users'] as List?;

      _logger.i(
        '🔍 CallManager: _handleUserLeft - State: ${_state.name}, remainingUsers: $remainingUsers, leftReason: $leftReason',
      );

      // ENHANCED: Handle different scenarios based on call state
      if (_state == CallState.connected) {
        // FIXED: CONNECTED STATE - Check if this is a group call before ending
        final callData = data['call'] ?? {};
        final chatData = data['chat'] ?? {};
        final callUsers = callData['users'] as List?;

        // FIXED: Use is_private flag with fallback logic for when chat data is missing
        final hasValidChatData = chatData.isNotEmpty;
        final isPrivateFromChatData = chatData['is_private'] == true;
        bool chatTypeIsGroup;

        if (hasValidChatData && chatData.containsKey('is_private')) {
          chatTypeIsGroup = !isPrivateFromChatData;
          _logger.i(
            '🔍 CallManager: CONNECTED - Using chat is_private flag: $isPrivateFromChatData -> isGroup: $chatTypeIsGroup',
          );
        } else {
          final uniqueUsers = callUsers?.toSet().toList() ?? [];
          final uniqueUserCount = uniqueUsers.length;
          chatTypeIsGroup = uniqueUserCount >= 3;
          _logger.i(
            '🔍 CallManager: CONNECTED - No chat data, using participant count: $uniqueUserCount -> isGroup: $chatTypeIsGroup',
          );
        }

        final originalCallUserCount = callUsers?.length ?? 1;

        // FIXED: Use consistent group detection logic with server data (same as _handleCallDeclined)
        final currentUsers = callData['current_users'] as List?;
        final remainingUserCount = currentUsers?.length ?? 0;
        final serverIndicatesMultipleUsers = remainingUserCount >= 2;
        final isActualGroupCall =
            chatTypeIsGroup ||
            originalCallUserCount >= 3 ||
            serverIndicatesMultipleUsers;

        _logger.i(
          '🔍 CallManager: CONNECTED Group Detection - chatTypeIsGroup: $chatTypeIsGroup, originalUsers: $originalCallUserCount, serverUsers: $remainingUserCount, serverIndicatesMultiple: $serverIndicatesMultipleUsers -> isActualGroupCall: $isActualGroupCall',
        );

        // End call based on call type and remaining users
        if (isActualGroupCall) {
          // For group calls: only end when 1 user remains (just local user)
          if (remainingUsers <= 1) {
            _logger.i(
              '🔚 CallManager: GROUP CONNECTED call - Only local user remains, ending call',
            );
            Future.delayed(Duration(milliseconds: 500), () {
              if (_state == CallState.connected) {
                endCall();
              }
            });
          } else {
            _logger.i(
              '✅ CallManager: GROUP CONNECTED call - $remainingUsers users still connected, call continues',
            );
          }
        } else {
          // For individual calls: end when 2 or fewer users remain
          if (remainingUsers <= 2) {
            _logger.i(
              '🔚 CallManager: INDIVIDUAL CONNECTED call - Only $remainingUsers user(s) remain, ending call',
            );
            Future.delayed(Duration(milliseconds: 500), () {
              if (_state == CallState.connected) {
                endCall();
              }
            });
          } else {
            _logger.i(
              '✅ CallManager: INDIVIDUAL CONNECTED call - $remainingUsers users still connected, call continues',
            );
          }
        }
      } else if (_state == CallState.calling || _state == CallState.ringing) {
        // FIXED: RINGING/CALLING STATE logic
        final callData = data['call'] ?? {};
        final chatData = data['chat'] ?? {};
        final callUsers = callData['users'] as List?;

        // FIXED: Use is_private flag with fallback logic for when chat data is missing
        final hasValidChatData = chatData.isNotEmpty;
        final isPrivateFromChatData = chatData['is_private'] == true;
        bool chatTypeIsGroup;

        if (hasValidChatData && chatData.containsKey('is_private')) {
          chatTypeIsGroup = !isPrivateFromChatData;
          _logger.i(
            '🔍 CallManager: RINGING - Using chat is_private flag: $isPrivateFromChatData -> isGroup: $chatTypeIsGroup',
          );
        } else {
          final uniqueUsers = callUsers?.toSet().toList() ?? [];
          final uniqueUserCount = uniqueUsers.length;
          chatTypeIsGroup = uniqueUserCount >= 3;
          _logger.i(
            '🔍 CallManager: RINGING - No chat data, using participant count: $uniqueUserCount -> isGroup: $chatTypeIsGroup',
          );
        }

        final originalCallUserCount = callUsers?.length ?? 1;

        // FIXED: Use consistent group detection logic with server data (same as _handleCallDeclined)
        final currentUsers = callData['current_users'] as List?;
        final remainingUserCount = currentUsers?.length ?? 0;
        final serverIndicatesMultipleUsers = remainingUserCount >= 2;
        final isActualGroupCall =
            chatTypeIsGroup ||
            originalCallUserCount >= 3 ||
            serverIndicatesMultipleUsers;

        _logger.i(
          '🔍 CallManager: RINGING Group Detection - chatTypeIsGroup: $chatTypeIsGroup, originalUsers: $originalCallUserCount, serverUsers: $remainingUserCount, serverIndicatesMultiple: $serverIndicatesMultipleUsers -> isActualGroupCall: $isActualGroupCall',
        );

        if (leftReason == 'declined_call') {
          if (isActualGroupCall) {
            // FIXED: For group calls during ringing, NEVER end the call due to individual declines
            // The call should continue for other potential participants
            _logger.i(
              '🔄 CallManager: Group RINGING/CALLING call - User declined, preserving call for other participants (original users: $originalCallUserCount)',
            );
            // Don't end the call - let other users potentially join
            return;
          } else {
            // For 1-on-1 calls, if the other user declines, end the call immediately
            _logger.i(
              '🔚 CallManager: 1-on-1 RINGING/CALLING call - Other user declined, ending call',
            );
            Future.delayed(Duration(milliseconds: 500), () {
              if (_state == CallState.calling || _state == CallState.ringing) {
                endCall();
              }
            });
          }
        } else if (remainingUsers <= 1 && leftReason != 'declined_call') {
          // Only end if it's not a decline and we're in a non-group scenario
          if (!isActualGroupCall) {
            _logger.i(
              '🔚 CallManager: RINGING/CALLING call - Only local user remains and not due to decline, ending call',
            );
            Future.delayed(Duration(milliseconds: 500), () {
              if (_state == CallState.calling || _state == CallState.ringing) {
                endCall();
              }
            });
          } else {
            _logger.i(
              '✅ CallManager: Group RINGING/CALLING call - Preserving call despite low participant count (original users: $originalCallUserCount)',
            );
          }
        } else {
          _logger.i(
            '✅ CallManager: RINGING/CALLING call - $remainingUsers users still available, call continues',
          );
        }
      } else {
        // OTHER STATES: Use original logic
        if (remainingUsers <= 1) {
          _logger.i(
            '🔚 CallManager: OTHER state (${_state.name}) - Only local user remains, ending call',
          );
          Future.delayed(Duration(milliseconds: 500), () {
            if (_state != CallState.idle && _state != CallState.ended) {
              endCall();
            }
          });
        }
      }

      // Server validation: Only end if server explicitly says no users are left
      if (currentUsers != null) {
        _logger.i(
          '📊 CallManager: Server reports ${currentUsers.length} active users',
        );

        // Only end if server explicitly says no users are left AND we're not in a critical call state
        if (currentUsers.isEmpty && _state == CallState.connected) {
          _logger.w(
            '⚠️ CallManager: Server reports no active users in connected call, ending call',
          );

          Future.delayed(Duration(milliseconds: 500), () {
            if (_state == CallState.connected) {
              endCall();
            }
          });
        }
      }

      _logger.i('✅ CallManager: User left processed successfully');
    } catch (e) {
      _logger.e('❌ Error handling user left: $e');
    }
  }

  /// Handle call ended from socket
  void _handleCallEnded(dynamic data) {
    try {
      _logger.i('🔚 CallManager: Call ended by server');
      _logger.i('🔍 CallManager: Call ended data: $data');

      // CRITICAL: Emergency stop all audio immediately (call end - restore session)
      _emergencyStopAllAudioAndRestore();

      // Update state to ended if not already
      if (_state != CallState.ended) {
        _setState(CallState.ended);
      }

      // Force cleanup to ensure proper state reset
      _cleanup();

      _logger.i('✅ CallManager: Call ended handled successfully');
    } catch (e) {
      _logger.e('❌ CallManager: Error handling call ended: $e');
      // Force cleanup even on error
      _forceCleanup();
    }
  }

  /// Handle call accepted confirmation (if backend sends this)
  void _handleCallAccepted(dynamic data) {
    _logger.i('✅ CallManager: Call accepted confirmation received');
    // This might be sent by backend for confirmation, but we primarily rely on user_joined
    if (_state == CallState.calling) {
      _setState(CallState.connecting);
    }
  }

  /// Handle call declined from socket
  void _handleCallDeclined(dynamic data) {
    try {
      _logger.i('❌ CallManager: Call declined by remote user');
      _logger.i('🔍 CallManager: Decline data: $data');

      // Extract declining user information
      final decliningUserId =
          data['declining_user_id'] ?? data['user_id'] ?? data['peer_id'];
      final decliningPeerId =
          data['declining_peer_id'] ?? data['peer_id'] ?? decliningUserId;
      final chatData = data['chat'] ?? {};
      final callData = data['call'] ?? {};

      // REQUIRED BEHAVIOR: Use real-time joinedUsers set (maintained from user_joined events)
      // The joinedUsers count is represented by _participants.length
      final joinedUsersCount = _participants.length;

      // Telemetry/logging for debugging as required
      _logger.i(
        '🔍 CallManager: Telemetry - joinedUsers.size: $joinedUsersCount',
      );
      _logger.i(
        '🔍 CallManager: Telemetry - decliningUserId: $decliningUserId',
      );
      _logger.i('🔍 CallManager: Telemetry - call state: ${_state.name}');
      _logger.i('🔍 CallManager: Chat data: $chatData');
      _logger.i('🔍 CallManager: Call data: $callData');

      // Check if the declining user was ever in joinedUsers
      final wasInJoinedUsers =
          decliningPeerId != null && _participants.containsKey(decliningPeerId);
      _logger.i(
        '🔍 CallManager: Telemetry - was declining user in joinedUsers: $wasInJoinedUsers',
      );

      // Extract chat_type to determine if this is a group call
      final chatType = chatData['chat_type']?.toString() ?? '';
      final isPrivate = chatType == 'private';
      final isGroupCall =
          chatType == 'group' || (!isPrivate && chatType.isNotEmpty);

      _logger.i(
        '🔍 CallManager: Telemetry - chatType: $chatType, isPrivate: $isPrivate, isGroupCall: $isGroupCall',
      );

      if (joinedUsersCount == 0) {
        if (isGroupCall) {
          // For group calls: don't end the call even if no users joined yet
          // The call should continue for other potential participants
          _logger.i(
            '🔄 CallManager: Decision path: joinedUsers.size == 0 BUT isGroupCall -> preserving call for other participants',
          );

          if (wasInJoinedUsers) {
            // User was actually joined, treat as user_left
            final userLeftData = {
              'peer_id': decliningPeerId,
              'user_id': decliningUserId,
              'reason': 'declined_call',
              'call': callData,
              'chat': chatData,
            };
            _logger.i(
              '🔄 CallManager: Converting decline to user_left for joined user in group call',
            );
            _handleUserLeft(userLeftData);
          } else {
            // User declined before joining - just update invite state
            _logger.i(
              '📝 CallManager: User declined before joining group call - updating invite state only',
            );
          }

          _logger.i(
            '✅ CallManager: Group call preserved - user declined but call continues for other participants',
          );
          return;
        } else {
          // Case 1: Private call with no users actually joined - end the call for the call maker
          _logger.i(
            '🔚 CallManager: Decision path: joinedUsers.size == 0 AND private call -> ending call (nobody actually joined)',
          );

          // CRITICAL: Emergency stop all audio immediately (call end - restore session)
          _emergencyStopAllAudioAndRestore();

          // Update state to ended and cleanup
          _setState(CallState.ended);
          _cleanup();

          _logger.i(
            '✅ CallManager: Call ended - no users had joined private call',
          );
          return;
        }
      } else if (joinedUsersCount >= 2) {
        // Case 2: Multiple users joined - do not end the call, just handle the decline
        _logger.i(
          '🔄 CallManager: Decision path: joinedUsers.size >= 2 -> preserving call, removing declining participant',
        );

        if (wasInJoinedUsers) {
          // User was actually joined, treat as user_left
          final userLeftData = {
            'peer_id': decliningPeerId,
            'user_id': decliningUserId,
            'reason': 'declined_call',
            'call': callData,
            'chat': chatData,
          };
          _logger.i(
            '🔄 CallManager: Converting decline to user_left for joined user',
          );
          _handleUserLeft(userLeftData);
        } else {
          // User declined before joining - just update invite state
          _logger.i(
            '📝 CallManager: User declined before joining - updating invite state only',
          );
          // Note: No specific invite tracking in current implementation,
          // but call continues for other participants
        }

        // Notify remaining participants about the decline
        _logger.i('✅ CallManager: Call continues with remaining participants');
        return;
      } else {
        // Case 3: joinedUsersCount >= 1 (but < 2)
        if (!wasInJoinedUsers) {
          // Declining user was never in joinedUsers (declined before joining)
          // Don't touch the ongoing call if we have at least 1 joined user
          _logger.i(
            '📝 CallManager: Decision path: decline from non-joined user, preserving call (joinedUsers.size >= 1)',
          );
          _logger.i(
            '✅ CallManager: Call preserved - user declined before joining',
          );
          return;
        } else {
          // The declining user was actually joined - this is more complex
          // Since they're leaving and we have < 2 total, this might end the call
          // But according to requirements, we should still check the final count after they leave
          _logger.i(
            '🔄 CallManager: Joined user is declining, handling as user_left',
          );

          final userLeftData = {
            'peer_id': decliningPeerId,
            'user_id': decliningUserId,
            'reason': 'declined_call',
            'call': callData,
            'chat': chatData,
          };
          _handleUserLeft(userLeftData);
          return;
        }
      }
    } catch (e) {
      _logger.e('❌ CallManager: Error handling call decline: $e');
      // Force cleanup even on error
      _forceCleanup();
    }
  }

  /// Handle call missed from socket
  void _handleCallMissed(dynamic data) {
    try {
      _logger.i('📞 CallManager: Call missed event received');
      _logger.i('🔍 CallManager: Missed call data: $data');

      // Parse missed call data
      final Map<String, dynamic> missedCallInfo = {};

      if (data is Map<String, dynamic>) {
        missedCallInfo.addAll(data);
      }

      // Add current call information if available
      if (_currentCall != null) {
        missedCallInfo['local_call_info'] = {
          'chat_id': _currentCall!.chatId,
          'call_id': _currentCall!.callId,
          'call_type': _currentCall!.callType.name,
          'is_incoming': _currentCall!.isIncoming,
          'caller_name': _currentCall!.callerName,
          'duration': callDuration?.inSeconds ?? 0,
        };
      }

      // Add current state information
      missedCallInfo['call_state'] = _state.name;
      missedCallInfo['timestamp'] = DateTime.now().toIso8601String();

      // Determine missed call type based on current state and call direction
      if (_currentCall?.isIncoming == true && _state == CallState.ringing) {
        // Receiver didn't answer incoming call
        missedCallInfo['missed_call_type'] = 'incoming_not_answered';
        _logger.i(
          '📞 CallManager: Missed call type: Incoming call not answered by receiver',
        );
      } else if (_currentCall?.isIncoming == false &&
          (_state == CallState.calling || _state == CallState.ringing)) {
        // Caller cancelled outgoing call before receiver answered
        missedCallInfo['missed_call_type'] = 'outgoing_cancelled';
        _logger.i(
          '📞 CallManager: Missed call type: Outgoing call cancelled by caller',
        );
      } else {
        // Generic missed call
        missedCallInfo['missed_call_type'] = 'generic';
        _logger.i('📞 CallManager: Missed call type: Generic missed call');
      }

      // CRITICAL: Emergency stop all audio immediately (missed call - restore session)
      _emergencyStopAllAudioAndRestore();

      // Update state to ended first
      _setState(CallState.ended);

      // Notify UI about missed call with detailed information
      onMissedCall?.call(missedCallInfo);

      // CRITICAL: For missed calls, transition to idle after cleanup to trigger proper navigation
      Future.delayed(Duration(milliseconds: 500), () async {
        if (_state == CallState.ended) {
          await _cleanup();
          _logger.i(
            '📞 CallManager: Missed call cleanup completed, transitioning to idle',
          );
        }
      });

      _logger.i('✅ CallManager: Missed call handled successfully');
    } catch (e) {
      _logger.e('❌ CallManager: Error handling missed call: $e');
      // Force cleanup even on error
      _forceCleanup();
    }
  }

  /// Handle call failed from backend (if supported)
  void _handleCallFailed(dynamic data) {
    _logger.e(
      '❌ CallManager: Call failed from backend - ${data['reason'] ?? 'Unknown reason'}',
    );
    _setState(CallState.failed);
    onError?.call('Call failed: ${data['reason'] ?? 'Unknown reason'}');
    _cleanup();
  }

  /// Handle peer disconnected (if backend supports this)
  void _handlePeerDisconnected(dynamic data) {
    final peerId = data['peer_id'] as String?;
    if (peerId != null) {
      _logger.w('⚠️ CallManager: Peer disconnected from backend: $peerId');
      _handleUserLeft(data);
    }
  }

  /// NEW: Handle real-time call changes for audio/video state updates
  void _handleCallChanges(dynamic data) {
    try {
      _logger.i('🔄 CallManager: Call changes received: $data');

      final roomId = data['room_id'] as String?;
      final peerId = data['peer_id'] as String?;
      final isAudioEnabled = data['isAudioEnabled'] as bool?;
      final isVideoEnabled = data['isVideoEnabled'] as bool?;

      if (roomId == null || peerId == null) {
        _logger.w('⚠️ Invalid call changes data: $data');
        return;
      }

      // Only process if this is for our current call
      if (_currentCall?.roomId != roomId) {
        _logger.w(
          '⚠️ Call changes for different room: $roomId (current: ${_currentCall?.roomId})',
        );
        return;
      }

      // Update participant state
      final participant = _participants[peerId];
      if (participant != null) {
        final updatedParticipant = participant.copyWith(
          hasAudio: isAudioEnabled ?? participant.hasAudio,
          hasVideo: isVideoEnabled ?? participant.hasVideo,
        );
        _participants[peerId] = updatedParticipant;

        _logger.i(
          '✅ Updated participant $peerId - Audio: ${updatedParticipant.hasAudio}, Video: ${updatedParticipant.hasVideo}',
        );

        // Notify UI about the changes
        onParticipantJoined?.call(updatedParticipant);
      } else {
        _logger.w('⚠️ Participant $peerId not found for call changes update');
      }

      _logger.i('✅ CallManager: Call changes processed successfully');
    } catch (e) {
      _logger.e('❌ Error handling call changes: $e');
    }
  }

  /// Handle remote stream added
  void _handleRemoteStreamAdded(String peerId, MediaStream stream) {
    try {
      _logger.i('📹 CallManager: Remote stream added for: $peerId');

      // Validate stream
      if (stream.getTracks().isEmpty) {
        _logger.w('⚠️ Empty stream received from $peerId');
        return;
      }

      // Update or create participant
      final participant = _participants[peerId];
      if (participant != null) {
        // Update existing participant
        _participants[peerId] = participant.copyWith(
          isConnected: true,
          hasVideo: stream.getVideoTracks().isNotEmpty,
          hasAudio: stream.getAudioTracks().isNotEmpty,
          stream: stream,
        );

        _logger.i(
          '✅ Updated participant $peerId - Video: ${stream.getVideoTracks().length}, Audio: ${stream.getAudioTracks().length}',
        );
      } else {
        // CRITICAL: Create participant if not exists (for cases where stream arrives before user_joined event)
        _logger.i('🆕 Creating temporary participant for stream: $peerId');

        // Try to use metadata if available, otherwise use temporary name
        final metadata = _peerMetadata[peerId];
        String participantName;
        String userId = '0';

        if (metadata != null) {
          userId = metadata['user_id']?.toString() ?? '0';

          // Use consistent metadata extraction
          participantName = _extractNameFromMetadata(metadata, userId);

          _logger.i(
            '✅ Using metadata for participant: $participantName (UserID: $userId, PeerID: $peerId)',
          );
        } else {
          // CRITICAL: No metadata - use User ID instead of peer-based name to avoid confusion
          participantName = 'User $userId';
          _logger.w(
            '⚠️ No metadata available for $peerId, using fallback: $participantName',
          );
        }

        final newParticipant = CallParticipant(
          peerId: peerId,
          userId: userId,
          userName: participantName,
          isConnected: true,
          hasVideo: stream.getVideoTracks().isNotEmpty,
          hasAudio: stream.getAudioTracks().isNotEmpty,
          stream: stream,
        );

        _participants[peerId] = newParticipant;

        _logger.i(
          '✅ Created temporary participant $participantName (UserID: $userId, PeerID: $peerId) - Video: ${stream.getVideoTracks().length}, Audio: ${stream.getAudioTracks().length}',
        );

        // Notify UI about new participant (will be updated with real name later)
        onParticipantJoined?.call(newParticipant);
      }

      // Notify UI about stream
      onStreamAdded?.call(peerId, stream);

      // CRITICAL: Immediately log debug info after stream update to verify state changes
      _logger.i('🔍 ===== CALL DEBUGGING INFO =====');
      _logger.i('🔍 Call State: ${_state.name}');
      _logger.i('🔍 Participant Count: ${_participants.length}');
      _logger.i('🔍 Remote Renderers: ${_participants.keys.toList()}');
      _logger.i('🔍 Detailed Participant Info:');

      int participantIndex = 1;
      for (final participant in _participants.values) {
        _logger.i('🔍   Participant $participantIndex:');
        _logger.i('🔍     UserID: ${participant.userId}');
        _logger.i('🔍     UserName: ${participant.userName}');
        _logger.i('🔍     PeerID: ${participant.peerId}');
        _logger.i('🔍     Connected: ${participant.isConnected}');
        _logger.i('🔍     HasVideo: ${participant.hasVideo}');
        _logger.i('🔍     HasAudio: ${participant.hasAudio}');
        // Also show metadata status
        final hasMetadata = _peerMetadata.containsKey(participant.peerId);
        _logger.i('🔍     HasMetadata: $hasMetadata');
        if (hasMetadata) {
          final metadata = _peerMetadata[participant.peerId];
          _logger.i(
            '🔍     Metadata: ${metadata?['user_name']} / ${metadata?['full_name']} / ${metadata?['first_name']}',
          );
        }
        participantIndex++;
      }
      _logger.i('🔍 ================================');
    } catch (e) {
      _logger.e('❌ Error handling remote stream added: $e');
    }
  }

  /// Handle remote stream removed
  void _handleRemoteStreamRemoved(String peerId) {
    try {
      _logger.i('📹 CallManager: Remote stream removed for: $peerId');

      // Update participant
      final participant = _participants[peerId];
      if (participant != null) {
        _participants[peerId] = participant.copyWith(
          isConnected: false,
          hasVideo: false,
          hasAudio: false,
          stream: null,
        );
        _logger.i('✅ Updated participant $peerId - stream removed');
      }

      // Notify UI
      onStreamRemoved?.call(peerId);
    } catch (e) {
      _logger.e('❌ Error handling remote stream removed: $e');
    }
  }

  /// Handle incoming call with metadata from WebRTC
  void _handleIncomingCallWithMetadata(
    String peerId,
    Map<String, dynamic>? metadata,
  ) {
    try {
      _logger.i(
        '📞 CallManager: Incoming call metadata from $peerId: $metadata',
      );

      if (metadata != null) {
        _peerMetadata[peerId] = metadata;
        _logger.i(
          '💾 STORED metadata for $peerId: ${metadata['user_name'] ?? metadata['first_name'] ?? 'Unknown'}',
        );

        // CRITICAL: Update participant name if they already exist
        final existingParticipant = _participants[peerId];
        if (existingParticipant != null) {
          final userId =
              metadata['user_id']?.toString() ?? existingParticipant.userId;

          // Extract name from metadata using consistent priority
          final participantName = _extractNameFromMetadata(metadata, userId);

          final updatedParticipant = existingParticipant.copyWith(
            userName: participantName,
            userId: userId,
          );
          _participants[peerId] = updatedParticipant;

          _logger.i(
            '🔄 NAME UPDATE: ${existingParticipant.userName} → $participantName',
          );

          // Notify UI about name update - only if name actually changed
          if (existingParticipant.userName != participantName) {
            _logger.i(
              '🔄 CallManager: Notifying UI about participant name update',
            );
            onParticipantJoined?.call(updatedParticipant);

            // Validate metadata status after update
            validateMetadataStatus();
          } else {
            _logger.d(
              '🔄 CallManager: Name unchanged, skipping UI notification',
            );
          }
        }
      }
    } catch (e) {
      _logger.e('❌ Error handling incoming call metadata: $e');
    }
  }

  /// Toggle audio
  void toggleAudio(bool enabled) {
    _webrtc.toggleAudio(enabled);
    _emitCallChanges(isAudioEnabled: enabled);
  }

  /// Toggle video
  void toggleVideo(bool enabled) {
    _webrtc.toggleVideo(enabled);
    _emitCallChanges(isVideoEnabled: enabled);
  }

  /// NEW: Emit call_changes event for real-time audio/video state updates
  void _emitCallChanges({bool? isAudioEnabled, bool? isVideoEnabled}) {
    if (_currentCall?.roomId == null || !isInCall) {
      _logger.w('⚠️ Cannot emit call changes - no active call');
      return;
    }

    try {
      final data = <String, dynamic>{
        'room_id': _currentCall!.roomId!,
        'peer_id': _webrtc.myPeerId,
      };

      if (isAudioEnabled != null) {
        data['isAudioEnabled'] = isAudioEnabled;
      }
      if (isVideoEnabled != null) {
        data['isVideoEnabled'] = isVideoEnabled;
      }

      socket.emit('call_changes', data: data);
      _logger.i('📤 CallManager: Emitted call_changes: $data');
    } catch (e) {
      _logger.e('❌ Error emitting call changes: $e');
    }
  }

  /// Switch camera
  Future<void> switchCamera() async {
    await _webrtc.switchCamera();
  }

  /// 🚀 FINAL SOLUTION: WebRTC-Native Speaker Control
  Future<void> setSpeakerphone(bool enabled) async {
    _logger.i(
      '🚀 FINAL: WebRTC-native speaker control (${enabled ? "ON" : "OFF"})',
    );

    try {
      // 🎯 KEY: Use WebRTC-native audio manager for speaker control
      await _audioManager.toggleSpeaker(enabled);

      // Also set via WebRTC service layer as backup
      await _webrtc.setSpeakerphone(enabled);

      _logger.i(
        '✅ FINAL: WebRTC-native speaker control completed - ${enabled ? "SPEAKER" : "EARPIECE"}',
      );
    } catch (e) {
      _logger.e('❌ FINAL: WebRTC-native speaker control failed: $e');

      // Emergency fallback
      try {
        await _webrtc.setSpeakerphone(enabled);
        _logger.w('🚨 Emergency speaker fallback successful');
      } catch (fallbackError) {
        _logger.e('❌ Emergency speaker fallback failed: $fallbackError');
      }
    }
  }

  /// Configure audio for call with speaker state
  Future<void> configureAudioForCallWithSpeaker(bool useSpeaker) async {
    await _audioManager.configureAudioForCall(useSpeaker: useSpeaker);
    _logger.i('🎵 CallManager: Audio configured with speaker: $useSpeaker');
  }

  /// CRITICAL FIX: Force reset audio session for subsequent calls
  Future<void> forceResetAudioSessionForNextCall() async {
    try {
      _logger.i('🔄 CallManager: Force resetting audio session for next call');
      await _audioManager.forceResetAudioSessionForNextCall();
      _logger.i('✅ CallManager: Audio session force reset completed');
    } catch (e) {
      _logger.e('❌ CallManager: Audio session force reset failed: $e');
      rethrow;
    }
  }

  /// Generate unique session ID
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'session-$timestamp-$random';
  }

  /// Generate room ID based on chat ID
  String _generateRoomId(int chatId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'room-$chatId-$timestamp';
  }

  /// Update state with enhanced logging
  void _setState(CallState newState) {
    if (_state != newState) {
      final oldState = _state;
      _state = newState;
      _logger.i(
        '🔄 CallManager: State change: ${oldState.name} → ${newState.name}',
      );

      // Notify listeners
      onStateChanged?.call();

      // Handle state-specific actions
      _handleStateChange(oldState, newState);
    }
  }

  /// Handle state change actions
  void _handleStateChange(CallState oldState, CallState newState) {
    switch (newState) {
      case CallState.connected:
        _logger.i('📞 Call connected successfully');
        break;
      case CallState.ended:
        _logger.i('🔚 Call ended');
        break;
      case CallState.failed:
        _logger.e('❌ Call failed');
        onError?.call('Call failed');
        break;
      default:
        break;
    }
  }

  /// Enhanced cleanup with proper error handling
  Future<void> _cleanup() async {
    try {
      _logger.i('🧹 CallManager: Starting cleanup...');

      // CRITICAL: Prevent cleanup during ongoing operations
      if (_state == CallState.idle) {
        _logger.d('⚠️ CallManager: Already cleaned up');
        return;
      }

      _setState(CallState.ended);

      // CRITICAL: Emergency stop all audio first for immediate silence (cleanup - restore session)
      await _emergencyStopAllAudioAndRestore();

      // Then do regular cleanup
      await _audioManager.cleanup();

      // Cancel timeout timers
      _callTimeoutTimer?.cancel();
      _connectionTimeoutTimer?.cancel();

      // Clean up participants and metadata
      _participants.clear();
      _peerMetadata.clear();

      // CRITICAL: Small delay to allow any pending stream events to complete
      // before disposing WebRTC to prevent "Cannot add new events after calling close" error
      await Future.delayed(Duration(milliseconds: 100));

      // Dispose WebRTC with proper error handling
      // SIMPLIFIED: WebRTCService.dispose() now handles all stream cleanup (reelboostmobile pattern)
      try {
        await _webrtc.dispose();
        _logger.i('✅ WebRTC disposed - all audio should be stopped');
      } catch (e) {
        _logger.w('⚠️ Error disposing WebRTC: $e');
      }

      // SIMPLIFIED: No native code needed - WebRTC cleanup is sufficient (reelboostmobile pattern)
      // The _webrtc.dispose() now properly cleans up all remote streams with disable -> stop -> dispose

      // Clear call info
      _currentCall = null;
      _sessionId = null;
      _roomId = null;

      // Small delay before setting to idle
      await Future.delayed(Duration(milliseconds: 200));

      _setState(CallState.idle);

      _logger.i('✅ CallManager: Cleanup completed');
    } catch (e) {
      _logger.e('❌ Error during cleanup: $e');
      await _forceCleanup();
    }
  }

  /// Force cleanup in case of errors
  Future<void> _forceCleanup() async {
    try {
      _logger.w('🚨 CallManager: Force cleanup...');

      _state = CallState.idle;
      _currentCall = null;
      _sessionId = null;
      _roomId = null;
      _participants.clear();
      _peerMetadata.clear();

      // Cancel timeout timers
      _callTimeoutTimer?.cancel();
      _connectionTimeoutTimer?.cancel();

      // Force dispose WebRTC
      try {
        await _webrtc.dispose();
      } catch (e) {
        _logger.w('⚠️ Error disposing WebRTC: $e');
      }

      _logger.w('✅ CallManager: Force cleanup completed');
    } catch (e) {
      _logger.e('❌ Error in force cleanup: $e');
    }
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'state': _state.name,
      'isInitialized': _isInitialized,
      'isInCall': isInCall,
      'sessionId': _sessionId,
      'roomId': _roomId,
      'participantCount': participantCount,
      'participants': _participants.keys.toList(),
      'currentCall':
          _currentCall != null
              ? {
                'chatId': _currentCall!.chatId,
                'callId': _currentCall!.callId,
                'callType': _currentCall!.callType.name,
                'isIncoming': _currentCall!.isIncoming,
                'callerName': _currentCall!.callerName,
              }
              : null,
      'webrtcStatus': _webrtc.getConnectionStatus(),
      'hasMissedCallCallback': onMissedCall != null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Test missed call handling (for debugging)
  void testMissedCallHandler(Map<String, dynamic> testData) {
    _logger.i(
      '🧪 CallManager: Testing missed call handler with data: $testData',
    );
    _handleCallMissed(testData);
  }

  /// Extract name from metadata with consistent key handling
  String _extractNameFromMetadata(
    Map<String, dynamic> metadata,
    String userId,
  ) {
    // Use same priority order as socket data
    final userName = metadata['user_name']?.toString();
    final fullName = metadata['full_name']?.toString();
    final firstName = metadata['first_name']?.toString();

    if (userName != null && userName.isNotEmpty) {
      return userName;
    } else if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    } else if (firstName != null && firstName.isNotEmpty) {
      return firstName;
    } else {
      return 'User $userId';
    }
  }

  /// Extract user name with priority order: contact_name > user_name > full_name > first_name + last_name > name > fallback
  String _extractUserName(
    Map<String, dynamic>? userData, [
    String fallback = 'Unknown',
  ]) {
    if (userData == null) {
      _logger.d(
        '🔍 _extractUserName: userData is null, using fallback: $fallback',
      );
      return fallback;
    }

    _logger.d('🔍 _extractUserName: Processing userData: $userData');

    // PRIORITY 0: Check if user is saved in contacts (HIGHEST PRIORITY)
    final userId = userData['user_id'];
    if (userId != null) {
      try {
        final userIdInt = int.tryParse(userId.toString());

        // Ensure contacts are loaded if not already cached
        if (!ContactNameService.instance.hasCachedContacts) {
          _logger.d(
            '🔍 _extractUserName: Contact cache empty, triggering load',
          );
          ContactNameService.instance.loadAndCacheContacts().catchError((e) {
            _logger.w('⚠️ _extractUserName: Failed to load contacts: $e');
          });
        }

        if (userIdInt != null &&
            ContactNameService.instance.isUserInContacts(userIdInt)) {
          // Get the saved contact name
          final configProvider = _getConfigProvider();
          if (configProvider != null) {
            final contactDisplayName = ContactNameService.instance
                .getDisplayName(
                  userId: userIdInt,
                  userFullName: userData['full_name'] as String?,
                  userName: userData['user_name'] as String?,
                  userEmail: userData['email'] as String?,
                  configProvider: configProvider,
                );

            // Only use contact name if it's different from server data (indicating it was found in contacts)
            final serverFullName = userData['full_name'] as String? ?? '';
            final serverUserName = userData['user_name'] as String? ?? '';

            if (contactDisplayName != serverFullName &&
                contactDisplayName != serverUserName &&
                contactDisplayName != 'Unknown User') {
              _logger.d(
                '🔍 _extractUserName: Using CONTACT name: $contactDisplayName',
              );
              return contactDisplayName;
            }
          }
        }
      } catch (e) {
        _logger.w('⚠️ _extractUserName: Error checking contacts: $e');
      }
    }

    // Priority 1: user_name (matches socket data - e.g., "Amit67")
    final userName = userData['user_name'] as String?;
    if (userName != null && userName.trim().isNotEmpty) {
      _logger.d('🔍 _extractUserName: Using user_name: $userName');
      return userName.trim();
    }

    // Priority 2: full_name (e.g., "Amit Primo")
    final fullName = userData['full_name'] as String?;
    if (fullName != null && fullName.trim().isNotEmpty) {
      _logger.d('🔍 _extractUserName: Using full_name: $fullName');
      return fullName.trim();
    }

    // Priority 3: first_name + last_name
    final firstName = userData['first_name'] as String?;
    final lastName = userData['last_name'] as String?;
    if (firstName != null && firstName.trim().isNotEmpty) {
      final name = firstName.trim();
      if (lastName != null && lastName.trim().isNotEmpty) {
        final fullNameFromParts = '$name ${lastName.trim()}';
        _logger.d(
          '🔍 _extractUserName: Using first_name + last_name: $fullNameFromParts',
        );
        return fullNameFromParts;
      }
      _logger.d('🔍 _extractUserName: Using first_name only: $name');
      return name;
    }

    // Priority 4: name (generic name field)
    final name = userData['name'] as String?;
    if (name != null && name.trim().isNotEmpty) {
      _logger.d('🔍 _extractUserName: Using name: $name');
      return name.trim();
    }

    // Priority 5: username (without underscore)
    final username = userData['username'] as String?;
    if (username != null && username.trim().isNotEmpty) {
      _logger.d('🔍 _extractUserName: Using username: $username');
      return username.trim();
    }

    // Fallback
    _logger.d('🔍 _extractUserName: No name found, using fallback: $fallback');
    return fallback;
  }

  /// Get ConfigProvider instance for contact name resolution
  ProjectConfigProvider? _getConfigProvider() {
    try {
      // Try to get from current context if available
      final context = WidgetsBinding.instance.rootElement;
      if (context != null) {
        return Provider.of<ProjectConfigProvider>(context, listen: false);
      }
    } catch (e) {
      _logger.w('⚠️ Could not get ConfigProvider: $e');
    }
    return null; // Will cause ContactNameService to use fallback behavior
  }

  /// Check if peer exists
  bool hasPeer(String peerId) {
    return _participants.containsKey(peerId);
  }

  /// Get participant by peer ID
  CallParticipant? getParticipant(String peerId) {
    return _participants[peerId];
  }

  /// Get participant by user ID
  CallParticipant? getParticipantByUserId(String userId) {
    try {
      return _participants.values.firstWhere(
        (participant) => participant.userId == userId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get all participants with their user ID mapping
  Map<String, CallParticipant> getParticipantsByUserId() {
    final Map<String, CallParticipant> userIdMap = {};
    for (final participant in _participants.values) {
      if (participant.userId.isNotEmpty) {
        userIdMap[participant.userId] = participant;
      }
    }
    return userIdMap;
  }

  /// Get user ID to peer ID mapping
  Map<String, String> getUserIdToPeerIdMapping() {
    final Map<String, String> mapping = {};
    for (final participant in _participants.values) {
      if (participant.userId.isNotEmpty) {
        mapping[participant.userId] = participant.peerId;
      }
    }
    _logger.i('👥 CallManager: User ID to Peer ID mapping: $mapping');
    return mapping;
  }

  /// Get detailed participant information for debugging
  List<Map<String, dynamic>> getDetailedParticipantInfo() {
    return _participants.values
        .map(
          (participant) => {
            'userId': participant.userId,
            'userName': participant.userName,
            'peerId': participant.peerId,
            'isConnected': participant.isConnected,
            'hasVideo': participant.hasVideo,
            'hasAudio': participant.hasAudio,
            'joinedAt': participant.joinedAt.toIso8601String(),
          },
        )
        .toList();
  }

  /// Check metadata status for all participants
  void validateMetadataStatus() {
    _logger.i('🔍 METADATA STATUS CHECK:');
    for (final participant in _participants.values) {
      final hasMetadata = _peerMetadata.containsKey(participant.peerId);
      final metadata = _peerMetadata[participant.peerId];
      final status =
          participant.userName.contains('Connecting') ||
                  participant.userName.contains('Peer ')
              ? '❌ Missing'
              : '✅ Received';
      _logger.i('   ${participant.peerId}: $status (${participant.userName})');
      if (hasMetadata && metadata != null) {
        _logger.i(
          '     → Metadata: user_name=${metadata['user_name']}, full_name=${metadata['full_name']}, first_name=${metadata['first_name']}',
        );
      } else {
        _logger.i('     → No metadata stored');
      }
    }

    // Also log current metadata store
    _logger.i('🔍 STORED METADATA:');
    _peerMetadata.forEach((peerId, metadata) {
      _logger.i(
        '   $peerId: user_name=${metadata['user_name']}, full_name=${metadata['full_name']}, first_name=${metadata['first_name']}',
      );
    });
  }

  /// Force reset the call manager
  Future<void> forceReset() async {
    _logger.w('🚨 CallManager: Force reset...');
    try {
      // Force end any active call
      if (isInCall) {
        await endCall();
      }

      // Force cleanup
      await _forceCleanup();

      _logger.w('✅ CallManager: Force reset completed');
    } catch (e) {
      _logger.e('❌ Error in force reset: $e');
    }
  }

  /// Check if service is ready
  bool get isReady {
    return _isInitialized && _webrtc.isInitialized;
  }

  /// Check if current call is a group call based on participant count
  /// A group call is defined as having more than 2 total participants (including local user)
  bool get isGroupCall {
    if (_currentCall == null) return false;
    final totalParticipants = _participants.length + 1; // +1 for local user
    return totalParticipants > 2;
  }

  /// Check if current call has the potential to be a group call
  /// This is useful during the ringing phase when we don't know who will join yet
  bool get isPotentialGroupCall {
    // This would ideally check chat member count from chat data
    // For now, we assume it's a potential group call if we have chat data indicating group type
    return _currentCall !=
        null; // Can be enhanced with actual group member count
  }

  /// Get current call duration
  Duration? get callDuration {
    if (_currentCall?.startTime == null) return null;
    return DateTime.now().difference(_currentCall!.startTime!);
  }

  /// Format call duration
  String get formattedCallDuration {
    final duration = callDuration;
    if (duration == null) return '00:00';

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Emergency stop all audio for CALL ACCEPT (WebRTC-safe)
  Future<void> _emergencyStopAllAudio() async {
    try {
      _logger.w('🚨 FIXED: Emergency stop for CALL ACCEPT (WebRTC-safe)');

      // Stop both services without them calling each other
      await Future.wait([
        _audioManager.emergencyStopAudio(), // FIXED: WebRTC-safe version
        CallNotificationManager.instance.emergencyStopNotification(),
      ]);

      _logger.w(
        '🚨 FIXED: Emergency stop completed (WebRTC session preserved)',
      );
    } catch (e) {
      _logger.e('❌ CallManager: Emergency stop failed: $e');
    }
  }

  /// Emergency stop all audio for CALL END (kills WebRTC session)
  Future<void> _emergencyStopAllAudioAndRestore() async {
    try {
      _logger.w('🚨 CallManager: Emergency stop for CALL END (full restore)');

      // Stop both services without them calling each other
      await Future.wait([
        _audioManager
            .emergencyStopAudioAndRestore(), // Full restoration for call end
        CallNotificationManager.instance.emergencyStopNotification(),
      ]);

      _logger.w('🚨 CallManager: Emergency stop and restore completed');
    } catch (e) {
      _logger.e('❌ CallManager: Emergency stop and restore failed: $e');
    }
  }

  /// Dispose with proper cleanup
  Future<void> dispose() async {
    _logger.i('🧹 CallManager: Disposing...');

    // Cancel all timers
    _callTimeoutTimer?.cancel();
    _connectionTimeoutTimer?.cancel();

    // CRITICAL: Remove socket listeners to prevent memory leaks and duplicate events
    try {
      socket.off('call');
      socket.off('receiving_call');
      socket.off('user_joined');
      socket.off('user_left');
      socket.off('call_ended');
      socket.off('call_declined');
      socket.off('call_missed');
      socket.off('call_accepted');
      socket.off('call_failed');
      socket.off('peer_disconnected');
      socket.off('call_changes');
      _logger.i('✅ Socket listeners removed');
    } catch (e) {
      _logger.w('⚠️ Error removing socket listeners: $e');
    }

    await _cleanup();
    _isInitialized = false;
  }
}
