// =============================================================================
// Enhanced WebRTC service with improved video streaming
// =============================================================================

// ignore_for_file: dead_code, unused_element

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:peerdart/peerdart.dart';
import 'package:stanchat/featuers/call/call_model.dart';
import 'package:stanchat/core/services/call_audio_manager.dart';
import 'package:stanchat/utils/logger.dart';

// Platform channel for native iOS speaker management
const MethodChannel _platform = MethodChannel('primocys.call.audio');

// Simple CallOption implementation for metadata
class MetadataCallOption extends CallOption {
  MetadataCallOption({required Map<String, dynamic> metadata}) {
    this.metadata = metadata;
  }
}

class WebRTCService {
  // Singleton
  static final WebRTCService _instance = WebRTCService._internal();
  static WebRTCService get instance => _instance;
  WebRTCService._internal();

  final _logger = ConsoleAppLogger.forModule('WebRTCService');

  // Peer connection
  Peer? _peer;
  String? _myPeerId;

  // Enhanced media stream management
  MediaStream? _localStream;
  final Map<String, MediaConnection> _connections = {};
  final Map<String, bool> _connectionAttempts = {};

  // CRITICAL FIX: Track remote streams for proper cleanup (reelboostmobile pattern)
  final Map<String, MediaStream> _remoteStreams = {};

  // Stream quality settings
  CallType? _currentCallType;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isSpeakerOn = true;

  // CRITICAL: WebRTC service debouncing
  DateTime? _lastSpeakerToggle;
  DateTime? _lastIOSAudioConfig;

  // Callbacks
  Function(String peerId, MediaStream stream)? onRemoteStreamAdded;
  Function(String peerId)? onRemoteStreamRemoved;
  Function(String peerId, Map<String, dynamic>? metadata)?
  onIncomingCallWithMetadata;
  Function(String error)? onError;

  // Getters
  String? get myPeerId => _myPeerId;
  MediaStream? get localStream => _localStream;
  bool get isInitialized => _peer != null && _localStream != null;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isSpeakerOn => _isSpeakerOn;
  int get connectionCount => _connections.length;
  Set<String> get connectedPeers => _connections.keys.toSet();

  /// CRITICAL FIX: Minimal initialization - let WebRTC manage its own timing
  Future<String> initialize({
    required String userId,
    required CallType callType,
  }) async {
    try {
      _logger.i('🚀 WebRTCService: Initializing (WebRTC manages audio)...');

      // If previous session exists, dispose it
      if (_peer != null || _localStream != null) {
        _logger.i('🔄 Existing session - disposing...');
        await dispose();
        // CRITICAL: NO delay needed - WebRTC handles its own lifecycle
      }

      // Generate peer ID
      _myPeerId = userId;

      // Initialize peer
      await _initializePeer();

      // Set call type
      _currentCallType = callType;

      // Get user media - WebRTC will activate audio session automatically
      await _getUserMedia(callType);

      _logger.i('✅ WebRTCService: Initialized (WebRTC audio active)');
      return _myPeerId!;
    } catch (e) {
      _logger.e('❌ WebRTCService: Failed to initialize: $e');
      onError?.call('Failed to initialize WebRTC: $e');
      rethrow;
    }
  }

  /// Get user media with enhanced quality settings
  Future<void> _getUserMedia(CallType callType) async {
    try {
      _logger.i('📹 WebRTCService: Getting user media for ${callType.name}');
      _currentCallType = callType;

      // CRITICAL FIX: Skip iOS audio prep before WebRTC - let WebRTC handle it first
      // await _prepareIOSAudioSession(); // Moved to post-WebRTC initialization

      final constraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'sampleRate': 44100,
          'channelCount': 1,
        },
        'video':
            callType == CallType.video
                ? {
                  'width': {'min': 640, 'ideal': 1280, 'max': 1920},
                  'height': {'min': 480, 'ideal': 720, 'max': 1080},
                  'frameRate': {'min': 15, 'ideal': 30, 'max': 60},
                  'facingMode': 'user',
                  'aspectRatio': 16 / 9,
                }
                : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _currentCallType = callType;
      _isVideoEnabled = callType == CallType.video;
      _isAudioEnabled = true;
      _isSpeakerOn = callType == CallType.video;

      // CRITICAL: Verify stream is active (with fallback for compatibility)
      bool isStreamActive = true;
      try {
        isStreamActive = _localStream!.active ?? true;
        if (!isStreamActive) {
          throw Exception('Local stream is not active');
        }
      } catch (e) {
        _logger.w(
          '⚠️ Could not check stream active state, assuming active: $e',
        );
        // Continue assuming stream is active for better compatibility
      }

      // Log stream quality
      final videoTracks = _localStream!.getVideoTracks();
      final audioTracks = _localStream!.getAudioTracks();

      _logger.i(
        '📹 WebRTCService: Got local stream - Video: ${videoTracks.length}, Audio: ${audioTracks.length}',
      );

      // CRITICAL: Configure iOS audio AFTER WebRTC initializes (research-based fix)
      await _configureIOSAudioAfterWebRTC();

      if (videoTracks.isNotEmpty) {
        final track = videoTracks.first;
        try {
          _logger.i('📹 Video track settings: ${track.getSettings()}');
        } catch (e) {
          _logger.w('⚠️ Could not get video track settings: $e');
        }

        // CRITICAL: Verify video track is enabled
        if (!track.enabled) {
          track.enabled = true;
          _logger.i('📹 Enabled video track');
        }
      }

      // CRITICAL: Verify audio track is enabled
      if (audioTracks.isNotEmpty) {
        final track = audioTracks.first;
        if (!track.enabled) {
          track.enabled = true;
          _logger.i('🔊 Enabled audio track');
        }
      }
    } catch (e) {
      _logger.e('❌ WebRTCService: Failed to get user media: $e');
      onError?.call('Failed to get user media: $e');
      rethrow;
    }
  }

  /// Initialize PeerJS with enhanced configuration and retry logic for ID conflicts
  Future<void> _initializePeer() async {
    int maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        _logger.i(
          '🔗 WebRTCService: Initializing peer connection (attempt ${retryCount + 1}/$maxRetries)',
        );

        // If this is a retry, modify the peer ID slightly
        String attemptPeerId = _myPeerId!;
        if (retryCount > 0) {
          attemptPeerId = '$_myPeerId-retry$retryCount';
          _logger.i(
            '🔄 WebRTCService: Using modified peer ID for retry: $attemptPeerId',
          );
        }

        _peer = Peer(
          id: attemptPeerId,
          options: PeerOptions(
            host: "62.72.36.245",
            port: 4001,
            path: "/",
            secure: false,
            config: {
              'iceServers': [
                {'urls': 'stun:stun.l.google.com:19302'},
                {'urls': 'stun:stun1.l.google.com:19302'},
                {'urls': 'stun:stun2.l.google.com:19302'},
              ],
              'iceCandidatePoolSize': 10,
              'bundlePolicy': 'balanced',
              'rtcpMuxPolicy': 'require',
              'sdpSemantics': 'unified-plan',
            },
          ),
        );

        // Wait for peer to be ready
        final completer = Completer<void>();
        StreamSubscription? openSub;
        StreamSubscription? errorSub;
        StreamSubscription? disconnectedSub;
        StreamSubscription? closeSub;

        openSub = _peer!.on("open").listen((id) {
          _logger.i('✅ WebRTCService: Peer opened with ID: $id');
          _myPeerId = id; // Update with actual peer ID
          openSub?.cancel();
          errorSub?.cancel();
          disconnectedSub?.cancel();
          closeSub?.cancel();
          completer.complete();
        });

        errorSub = _peer!.on("error").listen((error) {
          _logger.e('❌ WebRTCService: Peer error: $error');
          openSub?.cancel();
          errorSub?.cancel();
          disconnectedSub?.cancel();
          closeSub?.cancel();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        });

        disconnectedSub = _peer!.on("disconnected").listen((_) {
          _logger.w('⚠️ WebRTCService: Peer disconnected');
        });

        closeSub = _peer!.on("close").listen((_) {
          _logger.i('ℹ️ WebRTCService: Peer closed');
        });

        // Setup call handler
        _peer!.on<MediaConnection>("call").listen(_handleIncomingCall);

        // Wait with timeout
        await completer.future.timeout(
          Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Peer connection timeout'),
        );

        _logger.i(
          '✅ WebRTCService: Peer initialized successfully with ID: $_myPeerId',
        );
        return; // Success - exit retry loop
      } catch (e) {
        _logger.e(
          '❌ WebRTCService: Failed to initialize peer (attempt ${retryCount + 1}): $e',
        );

        // Check if this is an "ID is taken" error
        if (e.toString().contains('is taken') && retryCount < maxRetries - 1) {
          _logger.w(
            '⚠️ WebRTCService: ID conflict detected, retrying with modified ID...',
          );

          // Clean up failed peer
          try {
            _peer?.disconnect();
          } catch (_) {}
          _peer = null;

          retryCount++;

          // Wait before retry
          await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
          continue;
        }

        // If not an ID conflict or max retries reached, rethrow
        onError?.call('Failed to initialize peer: $e');
        rethrow;
      }
    }

    throw Exception('Failed to initialize peer after $maxRetries attempts');
  }

  /// Make a call to another peer
  Future<void> callPeer(
    String remotePeerId, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.i(
        '📞 WebRTCService: Calling peer: $remotePeerId with metadata: $metadata',
      );

      if (_peer == null || _localStream == null) {
        throw Exception('Not initialized');
      }

      // CRITICAL: Verify local stream is active (with fallback for compatibility)
      bool isLocalStreamActive = true;
      try {
        isLocalStreamActive = _localStream!.active ?? true;
        if (!isLocalStreamActive) {
          throw Exception('Local stream is not active');
        }
      } catch (e) {
        _logger.w(
          '⚠️ Could not check local stream active state, assuming active: $e',
        );
        // Continue assuming stream is active for better compatibility
      }

      // Check if already connected
      if (_connections.containsKey(remotePeerId)) {
        _logger.w('⚠️ WebRTCService: Already connected to: $remotePeerId');
        return;
      }

      // Make the call with metadata using CallOption
      CallOption? callOptions;
      if (metadata != null) {
        callOptions = MetadataCallOption(metadata: metadata);
        _logger.i(
          '📤 SENDING metadata to $remotePeerId: ${metadata['user_name'] ?? metadata['first_name'] ?? 'Unknown'}',
        );
      } else {
        _logger.w('⚠️ NO metadata being sent to $remotePeerId');
      }
      final call = _peer!.call(
        remotePeerId,
        _localStream!,
        options: callOptions,
      );

      _setupCallHandlers(call, remotePeerId);
      _connections[remotePeerId] = call;
      _logger.i('✅ WebRTCService: Call initiated to: $remotePeerId');
    } catch (e) {
      _logger.e('❌ WebRTCService: Failed to call peer: $e');
      onError?.call('Failed to call peer: $e');
      rethrow;
    }
  }

  /// Handle incoming call
  void _handleIncomingCall(MediaConnection call) {
    try {
      final remotePeerId = call.peer;
      final metadata = call.metadata as Map<String, dynamic>?;
      _logger.i(
        '📞 WebRTCService: Incoming call from: $remotePeerId with metadata: $metadata',
      );

      if (metadata != null) {
        _logger.i(
          '📥 RECEIVED metadata from $remotePeerId: ${metadata['user_name'] ?? metadata['first_name'] ?? 'Unknown'}',
        );
      } else {
        _logger.w('⚠️ NO metadata received from $remotePeerId');
      }

      // Notify callback about incoming call with metadata
      _logger.i(
        '🔄 WebRTCService: Calling onIncomingCallWithMetadata callback',
      );
      onIncomingCallWithMetadata?.call(remotePeerId, metadata);

      // Check if already connected
      if (_connections.containsKey(remotePeerId)) {
        _logger.w('⚠️ WebRTCService: Already connected, rejecting duplicate');
        call.close();
        return;
      }

      // Answer the call
      if (_localStream != null) {
        try {
          // Check if stream is active - with fallback for compatibility
          bool isStreamActive = true;
          try {
            isStreamActive = _localStream!.active ?? true;
          } catch (e) {
            _logger.w(
              '⚠️ Could not check stream active state, assuming active: $e',
            );
          }

          if (isStreamActive) {
            call.answer(_localStream!);
            _setupCallHandlers(call, remotePeerId);
            _connections[remotePeerId] = call;
            _logger.i('✅ WebRTCService: Answered call from: $remotePeerId');
          } else {
            _logger.e('❌ WebRTCService: Local stream is not active');
            call.close();
          }
        } catch (e) {
          _logger.e('❌ WebRTCService: Error answering call: $e');
          call.close();
        }
      } else {
        _logger.e('❌ WebRTCService: No local stream to answer call');
        call.close();
      }
    } catch (e) {
      _logger.e('❌ WebRTCService: Error handling incoming call: $e');
    }
  }

  /// Setup call event handlers
  void _setupCallHandlers(MediaConnection call, String remotePeerId) {
    // Handle stream
    call.on<MediaStream>('stream').listen((remoteStream) {
      _logger.i('📹 WebRTCService: Got remote stream from: $remotePeerId');

      // CRITICAL: Verify remote stream is active (with fallback for compatibility)
      bool isRemoteStreamActive = true;
      try {
        isRemoteStreamActive = remoteStream.active ?? true;
        if (!isRemoteStreamActive) {
          _logger.w(
            '⚠️ WebRTCService: Remote stream is not active for: $remotePeerId',
          );
          return;
        }
      } catch (e) {
        _logger.w(
          '⚠️ Could not check remote stream active state, assuming active: $e',
        );
        // Continue processing stream even if we can't check active state
      }

      final videoTracks = remoteStream.getVideoTracks();
      final audioTracks = remoteStream.getAudioTracks();

      _logger.i(
        '📹 WebRTCService: Remote stream tracks - Video: ${videoTracks.length}, Audio: ${audioTracks.length}',
      );

      // CRITICAL: Ensure tracks are enabled
      for (final track in videoTracks) {
        if (!track.enabled) {
          track.enabled = true;
          _logger.i('📹 Enabled remote video track');
        }
      }

      for (final track in audioTracks) {
        if (!track.enabled) {
          track.enabled = true;
          _logger.i('🔊 Enabled remote audio track');
        }
      }

      // CRITICAL FIX: Store remote stream for proper cleanup (reelboostmobile pattern)
      _remoteStreams[remotePeerId] = remoteStream;
      _logger.i('💾 Stored remote stream for peer: $remotePeerId');

      onRemoteStreamAdded?.call(remotePeerId, remoteStream);
    });

    // Handle close
    call.on('close').listen((_) {
      _logger.i('📞 WebRTCService: Call closed with: $remotePeerId');
      _handleConnectionClosed(remotePeerId);
    });

    // Handle error
    call.on('error').listen((error) {
      _logger.e('❌ WebRTCService: Call error with $remotePeerId: $error');
      _handleConnectionClosed(remotePeerId);
    });
  }

  /// Handle connection closed
  void _handleConnectionClosed(String peerId) {
    _connections.remove(peerId);

    // CRITICAL FIX: Clean up remote stream (reelboostmobile pattern)
    final remoteStream = _remoteStreams.remove(peerId);
    if (remoteStream != null) {
      _cleanupRemoteStream(remoteStream, peerId);
    }

    onRemoteStreamRemoved?.call(peerId);
  }

  /// CRITICAL FIX: Cleanup remote stream with disable -> stop -> dispose pattern
  void _cleanupRemoteStream(MediaStream stream, String peerId) {
    try {
      _logger.i('🧹 Cleaning up remote stream for peer: $peerId');

      // Step 1: Disable all tracks FIRST (immediate audio silence - reelboostmobile pattern)
      for (var track in stream.getTracks()) {
        try {
          _logger.d('🔇 Disabling ${track.kind} track: ${track.id}');
          track.enabled = false;
        } catch (e) {
          _logger.w('⚠️ Error disabling track: $e');
        }
      }

      // Step 2: Stop all tracks (release hardware)
      for (var track in stream.getTracks()) {
        try {
          _logger.d('⏹️ Stopping ${track.kind} track: ${track.id}');
          track.stop();
        } catch (e) {
          _logger.w('⚠️ Error stopping track: $e');
        }
      }

      // Step 3: Dispose stream
      try {
        stream.dispose();
        _logger.i('✅ Remote stream disposed for peer: $peerId');
      } catch (e) {
        _logger.w('⚠️ Error disposing remote stream: $e');
      }
    } catch (e) {
      _logger.e('❌ Error cleaning up remote stream for $peerId: $e');
    }
  }

  /// Close connection to specific peer
  void closePeerConnection(String peerId) {
    final connection = _connections[peerId];
    if (connection != null) {
      try {
        // CRITICAL: Check if connection is still open before closing
        // to prevent "Cannot add new events after calling close" error
        if (connection.open) {
          connection.close();
        }
      } catch (e) {
        _logger.w('⚠️ Error closing connection for $peerId: $e');
        // Continue with cleanup even if close fails
      }
      _handleConnectionClosed(peerId);
    }
  }

  /// Toggle audio with enhanced handling
  void toggleAudio(bool enabled) {
    try {
      _isAudioEnabled = enabled;
      _localStream?.getAudioTracks().forEach((track) {
        track.enabled = enabled;
      });
      _logger.i('🔊 Audio ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _logger.e('❌ Error toggling audio: $e');
      onError?.call('Failed to toggle audio: $e');
    }
  }

  /// Toggle video with enhanced handling
  void toggleVideo(bool enabled) {
    try {
      _isVideoEnabled = enabled;
      _localStream?.getVideoTracks().forEach((track) {
        track.enabled = enabled;
      });
      _logger.i('📹 Video ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _logger.e('❌ Error toggling video: $e');
      onError?.call('Failed to toggle video: $e');
    }
  }

  /// Recreate local stream for video toggle
  Future<void> recreateLocalStream(
    CallType callType, {
    bool videoEnabled = true,
  }) async {
    try {
      _logger.i('🔄 Recreating local stream with video: $videoEnabled');

      // Stop current stream
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) => track.stop());
        await _localStream!.dispose();
      }

      // Create new stream
      final constraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'sampleRate': 44100,
          'channelCount': 1,
        },
        'video':
            (callType == CallType.video && videoEnabled)
                ? {
                  'width': {'min': 640, 'ideal': 1280, 'max': 1920},
                  'height': {'min': 480, 'ideal': 720, 'max': 1080},
                  'frameRate': {'min': 15, 'ideal': 30, 'max': 60},
                  'facingMode': 'user',
                  'aspectRatio': 16 / 9,
                }
                : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _isVideoEnabled = videoEnabled && callType == CallType.video;

      // Update all peer connections with new stream
      await _updateAllConnectionsWithNewStream();

      _logger.i('✅ Local stream recreated successfully');
    } catch (e) {
      _logger.e('❌ Failed to recreate local stream: $e');
      onError?.call('Failed to recreate stream: $e');
      rethrow;
    }
  }

  /// Update all connections with new stream
  Future<void> _updateAllConnectionsWithNewStream() async {
    try {
      _logger.i('🔄 Updating all connections with new stream');

      // For stream updates, we need to close and recreate connections
      final peerIds = List<String>.from(_connections.keys);

      for (final peerId in peerIds) {
        try {
          // Close existing connection
          closePeerConnection(peerId);

          // Wait a bit
          await Future.delayed(Duration(milliseconds: 500));

          // Recreate connection with new stream (without metadata for existing connections)
          await callPeer(peerId);
        } catch (e) {
          _logger.w('⚠️ Failed to update connection for $peerId: $e');
        }
      }
    } catch (e) {
      _logger.e('❌ Error updating connections with new stream: $e');
    }
  }

  /// Switch camera
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks.first);
      }
    }
  }

  /// Set speaker with proper earpiece routing for Android/iOS
  Future<void> setSpeakerphone(bool enabled) async {
    try {
      // CRITICAL: Debounce speaker toggle to prevent rapid calls
      final now = DateTime.now();
      if (_lastSpeakerToggle != null &&
          now.difference(_lastSpeakerToggle!).inMilliseconds < 300) {
        _logger.i('🛑 WebRTCService: Speaker toggle debounced (too recent)');
        return;
      }
      _lastSpeakerToggle = now;

      _isSpeakerOn = enabled;
      _logger.i(
        '🔊 WebRTCService: Setting speaker to ${enabled ? 'ON (Speaker)' : 'OFF (Earpiece)'}',
      );

      // Use BOTH flutter_webrtc AND native for reliable routing
      await Helper.setSpeakerphoneOn(enabled);
      _logger.i('✅ flutter_webrtc setSpeakerphoneOn($enabled)');

      // CRITICAL: Also call native platform method for reliable routing on both platforms
      try {
        await _platform.invokeMethod('setSpeakerphone', {'enabled': enabled});
        _logger.i('✅ Native setSpeakerphone(${enabled ? "ON" : "OFF"})');
      } catch (e) {
        _logger.w('⚠️ Native speaker call failed: $e');
      }

      // For earpiece (speaker OFF), apply additional routing on Android
      if (!enabled && defaultTargetPlatform == TargetPlatform.android) {
        await _forceEarpieceOnAndroid();
      }

      _logger.i(
        '✅ Audio routing completed: ${enabled ? 'SPEAKER' : 'EARPIECE'}',
      );
    } catch (e) {
      _logger.e('❌ Error setting speaker: $e');
      onError?.call('Failed to set speaker: $e');
    }
  }

  /// Force earpiece routing on Android with multiple attempts
  Future<void> _forceEarpieceOnAndroid() async {
    try {
      _logger.i(
        '📱 Android: Forcing earpiece routing with multiple attempts...',
      );

      // Method 1: Multiple setSpeakerphoneOn(false) calls with delays
      // Android sometimes needs repeated calls to properly route to earpiece
      for (int attempt = 1; attempt <= 3; attempt++) {
        await Helper.setSpeakerphoneOn(false);
        _logger.d('📱 Android: Earpiece attempt $attempt/3');
        if (attempt < 3) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
      }

      // Method 2: Try device enumeration as additional step
      try {
        final devices = await Helper.enumerateDevices('audiooutput');
        _logger.d(
          '📱 Available audio devices: ${devices.map((d) => d.label).toList()}',
        );

        // Look for earpiece/receiver device (might be labeled differently on different devices)
        for (var device in devices) {
          final label = device.label.toLowerCase();
          // Check for common earpiece labels
          if (label.contains('earpiece') ||
              label.contains('receiver') ||
              label.contains('phone') ||
              label.contains('handset') ||
              label.contains('built-in') ||
              (label.contains('speaker') == false &&
                  device.deviceId != 'default')) {
            try {
              await Helper.selectAudioOutput(device.deviceId);
              _logger.i('✅ Android: Selected device: ${device.label}');
              break;
            } catch (selectError) {
              _logger.w(
                '⚠️ Android: Could not select ${device.label}: $selectError',
              );
            }
          }
        }
      } catch (e) {
        _logger.w('⚠️ Android device enumeration failed: $e');
      }

      // Final verification - one more setSpeakerphoneOn(false)
      await Helper.setSpeakerphoneOn(false);
      _logger.i('✅ Android: Earpiece routing completed');
    } catch (e) {
      _logger.e('❌ Android earpiece routing failed: $e');
    }
  }

  /// Helper method to safely get stream active status
  bool _getStreamActiveStatus(MediaStream? stream) {
    if (stream == null) return false;
    try {
      return stream.active ?? false;
    } catch (e) {
      _logger.w('⚠️ Could not get stream active status: $e');
      return true; // Assume active if we can't check
    }
  }

  /// Get connection status
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isInitialized': isInitialized,
      'myPeerId': myPeerId,
      'connectionCount': connectionCount,
      'connectedPeers': connectedPeers.toList(),
      'isVideoEnabled': isVideoEnabled,
      'isAudioEnabled': isAudioEnabled,
      'isSpeakerOn': isSpeakerOn,
      'currentCallType': _currentCallType?.name,
      'hasLocalStream': _localStream != null,
      'localStreamActive': _getStreamActiveStatus(_localStream),
      'localVideoTracks': _localStream?.getVideoTracks().length ?? 0,
      'localAudioTracks': _localStream?.getAudioTracks().length ?? 0,
    };
  }

  /// Dispose everything with enhanced cleanup
  Future<void> dispose() async {
    try {
      _logger.i('🧹 WebRTCService: Disposing...');

      // CRITICAL FIX Step 1: Clean up ALL remote streams FIRST (reelboostmobile pattern)
      // This ensures remote audio stops immediately before anything else
      _logger.i(
        '🔇 Step 1: Cleaning up ${_remoteStreams.length} remote streams...',
      );
      final remoteStreamIds = List<String>.from(_remoteStreams.keys);
      for (final peerId in remoteStreamIds) {
        final remoteStream = _remoteStreams[peerId];
        if (remoteStream != null) {
          _cleanupRemoteStream(remoteStream, peerId);
        }
      }
      _remoteStreams.clear();
      _logger.i('✅ All remote streams cleaned up');

      // Step 2: Close all connections with proper checks
      _logger.i('📞 Step 2: Closing ${_connections.length} connections...');
      final connectionIds = List<String>.from(_connections.keys);
      for (final peerId in connectionIds) {
        try {
          final connection = _connections[peerId];
          if (connection != null) {
            // CRITICAL: Check if connection is still open before closing
            // to prevent "Cannot add new events after calling close" error
            if (connection.open) {
              connection.close();
            }
          }
        } catch (e) {
          _logger.w('⚠️ Error closing connection for $peerId: $e');
        }
      }
      _connections.clear();
      _connectionAttempts.clear();

      // Step 3: Clean up local stream with disable -> stop -> dispose pattern (reelboostmobile)
      if (_localStream != null) {
        _logger.i('🎤 Step 3: Cleaning up local stream...');

        // Disable all tracks FIRST (immediate audio silence)
        for (var track in _localStream!.getTracks()) {
          try {
            _logger.d('🔇 Disabling local ${track.kind} track');
            track.enabled = false;
          } catch (e) {
            _logger.w('⚠️ Error disabling local track: $e');
          }
        }

        // Stop all tracks (release hardware)
        for (var track in _localStream!.getTracks()) {
          try {
            _logger.d('⏹️ Stopping local ${track.kind} track');
            track.stop();
          } catch (e) {
            _logger.w('⚠️ Error stopping local track: $e');
          }
        }

        // Clear track arrays
        _localStream!.getAudioTracks().clear();
        _localStream!.getVideoTracks().clear();

        // Dispose stream
        try {
          await _localStream!.dispose();
          _logger.i('✅ Local stream disposed');
        } catch (e) {
          _logger.w('⚠️ Error disposing local stream: $e');
        }

        _localStream = null;
      }

      // Step 4: Disconnect peer to release the ID
      if (_peer != null) {
        _logger.i('🔌 Step 4: Disconnecting peer...');
        try {
          _peer!.disconnect();
          _logger.i('✅ Peer disconnected and ID released');
        } catch (e) {
          _logger.w('⚠️ Error disconnecting peer: $e');
        }
        _peer = null;
      }

      // Step 5: Reset audio routing
      try {
        await Helper.setSpeakerphoneOn(false);
        _logger.i('🔊 Audio routing reset');
      } catch (e) {
        _logger.w('⚠️ Error resetting audio: $e');
      }

      // Reset state
      _myPeerId = null;
      _currentCallType = null;
      _isVideoEnabled = true;
      _isAudioEnabled = true;
      _isSpeakerOn = true;

      _logger.i(
        '✅ WebRTCService: Disposed successfully - all audio should be stopped',
      );
    } catch (e) {
      _logger.e('❌ Error disposing WebRTCService: $e');
    }
  }

  /// Configure iOS audio AFTER WebRTC initializes (research-based approach)
  Future<void> _configureIOSAudioAfterWebRTC() async {
    try {
      // CRITICAL: Debounce iOS audio configuration to prevent rapid calls
      final now = DateTime.now();
      if (_lastIOSAudioConfig != null &&
          now.difference(_lastIOSAudioConfig!).inMilliseconds < 1000) {
        _logger.i('🛑 WebRTCService: iOS audio config debounced (too recent)');
        return;
      }
      _lastIOSAudioConfig = now;

      // DISABLED: Audio configuration is handled by CallManager, not here
      // This was causing MULTIPLE simultaneous audio configs which interfered with WebRTC
      if (false && Platform.isIOS && _currentCallType != null) {
        final isVideoCall = _currentCallType == CallType.video;
        _logger.i(
          '🍎 WebRTCService: Post-init audio config DISABLED (handled by CallManager)',
        );

        // OLD CODE - This was causing the problem:
        // - CallManager configures audio
        // - Then this code waits 1 second and configures AGAIN
        // - Result: Multiple configs fight each other, WebRTC audio breaks

        if (false && isVideoCall) {
          _logger.i(
            '🎥 WebRTCService: Video call - applying research-based speaker fix',
          );
          try {
            // Step 1: Use WebRTC's built-in speaker routing FIRST
            await Helper.setSpeakerphoneOn(true);
            await Future.delayed(Duration(milliseconds: 300));

            // Step 2: Use centralized CallAudioManager (with built-in debouncing)
            try {
              await CallAudioManager.instance.configureAudioForCall(
                useSpeaker: true,
              );
              _logger.i(
                '✅ WebRTCService: Centralized iOS video call config applied',
              );

              // Step 3: Wait and re-apply WebRTC speaker setting
              await Future.delayed(Duration(milliseconds: 500));
              await Helper.setSpeakerphoneOn(true);

              _logger.i(
                '✅ WebRTCService: Research-based video call speaker fix completed',
              );
            } catch (nativeError) {
              _logger.w(
                '⚠️ WebRTCService: Native config failed, using fallback: $nativeError',
              );
              // Fallback: Multiple WebRTC attempts only
              for (int attempt = 1; attempt <= 5; attempt++) {
                await Helper.setSpeakerphoneOn(true);
                await Future.delayed(Duration(milliseconds: 200));
                _logger.i(
                  '✅ WebRTCService: Fallback speaker attempt $attempt/5',
                );
              }
            }
          } catch (e) {
            _logger.e('❌ WebRTCService: Video call speaker fix failed: $e');
          }
        } else {
          _logger.i('📞 WebRTCService: Audio call - ensuring earpiece routing');
          try {
            await Helper.setSpeakerphoneOn(false);
            _logger.i('✅ WebRTCService: Audio call earpiece routing ensured');
          } catch (e) {
            _logger.e('❌ WebRTCService: Audio call earpiece fix failed: $e');
          }
        }

        _logger.i(
          '✅ WebRTCService: Post-WebRTC iOS audio configuration completed',
        );
      }
    } catch (e) {
      _logger.e('❌ WebRTCService: Post-WebRTC audio configuration failed: $e');
    }
  }

  /// Restore native audio session to prevent audio continuation after disposal
  Future<void> _restoreNativeAudioSession() async {
    try {
      // FIXED: Multiple attempts to ensure WebRTC releases its hold on the native audio session
      // particularly important for iOS AVAudioSession and Android AudioManager

      // First attempt - set to earpiece/default
      await Helper.setSpeakerphoneOn(false);
      await Future.delayed(Duration(milliseconds: 100));

      // Second attempt - toggle to ensure routing is reset
      await Helper.setSpeakerphoneOn(true);
      await Future.delayed(Duration(milliseconds: 50));
      await Helper.setSpeakerphoneOn(false);
      await Future.delayed(Duration(milliseconds: 100));

      _logger.d('🔊 Native audio session restored with multiple attempts');
    } catch (e) {
      _logger.w('⚠️ Could not restore native audio session: $e');
      // Fallback attempt with extended delays
      try {
        await Future.delayed(Duration(milliseconds: 200));
        await Helper.setSpeakerphoneOn(false);
        await Future.delayed(Duration(milliseconds: 100));
        _logger.d('🔊 Fallback native audio session restore completed');
      } catch (fallbackError) {
        _logger.w('⚠️ Fallback audio restore also failed: $fallbackError');
      }
    }
  }
}
