// =============================================================================
// SIMPLIFIED: Mesh Connection Controller - Everyone Sees Everyone
// =============================================================================

import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:peerdart/peerdart.dart';
import 'package:stanchat/utils/logger.dart';

/// Simplified controller that handles mesh connections properly
class SimpleMeshController {
  static final SimpleMeshController _instance = SimpleMeshController._();
  static SimpleMeshController get instance => _instance;
  SimpleMeshController._();

  final _logger = ConsoleAppLogger.forModule('SimpleMeshController');

  // Core state
  Peer? _myPeer;
  String? _myPeerId;
  MediaStream? _localStream;

  // Track all participants and their connections
  final Map<String, PeerParticipant> _participants = {};
  final Map<String, MediaConnection> _outgoingCalls = {};
  final Map<String, MediaConnection> _incomingCalls = {};

  // Callbacks for UI updates
  Function(String peerId, MediaStream stream)? onStreamAdded;
  Function(String peerId)? onStreamRemoved;
  Function(String peerId, String userName)? onParticipantJoined;
  Function(String peerId)? onParticipantLeft;

  // Getters
  String? get myPeerId => _myPeerId;
  MediaStream? get localStream => _localStream;
  List<PeerParticipant> get participants => _participants.values.toList();

  /// Initialize peer and local stream
  Future<void> initialize({
    required String userId,
    required CallType callType,
  }) async {
    try {
      _logger.i('🚀 Initializing mesh controller');

      // Generate peer ID
      _myPeerId = 'peer-$userId-${DateTime.now().millisecondsSinceEpoch}';

      // Create local stream
      await _createLocalStream(callType);

      // Initialize peer
      await _initializePeer();

      _logger.i('✅ Mesh controller initialized with peer ID: $_myPeerId');
    } catch (e) {
      _logger.e('❌ Failed to initialize: $e');
      rethrow;
    }
  }

  /// Create local media stream
  Future<void> _createLocalStream(CallType callType) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': callType == CallType.video,
    });
    _logger.i('📹 Local stream created');
  }

  /// Initialize PeerJS connection
  Future<void> _initializePeer() async {
    _myPeer = Peer(
      id: _myPeerId!,
      options: PeerOptions(
        host: "62.72.36.245",
        port: 4001,
        path: "/",
        secure: false,
      ),
    );

    // Wait for peer to open
    final completer = Completer<void>();

    _myPeer!.on("open").listen((id) {
      _logger.i('✅ Peer opened with ID: $id');
      completer.complete();
    });

    // Handle incoming calls
    _myPeer!.on<MediaConnection>("call").listen((incomingCall) {
      _handleIncomingCall(incomingCall);
    });

    await completer.future;
  }

  /// Handle when a new user joins the room
  void handleUserJoined({
    required String peerId,
    required String userId,
    required String userName,
  }) {
    _logger.i('👤 User joined: $userName ($peerId)');

    // Skip if it's ourselves
    if (peerId == _myPeerId) {
      _logger.i('📍 Skipping own join event');
      return;
    }

    // Add participant
    _participants[peerId] = PeerParticipant(
      peerId: peerId,
      userId: userId,
      userName: userName,
      hasStream: false,
    );

    // Notify UI
    onParticipantJoined?.call(peerId, userName);

    // CRITICAL: Establish connection to new participant
    _callPeer(peerId);
  }

  /// Make a call to a peer
  void _callPeer(String remotePeerId) {
    try {
      _logger.i('📞 Calling peer: $remotePeerId');

      if (_localStream == null || _myPeer == null) {
        _logger.e('❌ Cannot call - no local stream or peer');
        return;
      }

      // Check if we already have an outgoing call to this peer
      if (_outgoingCalls.containsKey(remotePeerId)) {
        _logger.w('⚠️ Already have outgoing call to: $remotePeerId');
        return;
      }

      // Make the call
      final call = _myPeer!.call(remotePeerId, _localStream!);

      _outgoingCalls[remotePeerId] = call;
      _setupCallHandlers(call, remotePeerId, isIncoming: false);
      _logger.i('✅ Outgoing call initiated to: $remotePeerId');
    } catch (e) {
      _logger.e('❌ Error calling peer $remotePeerId: $e');
    }
  }

  /// Handle incoming call from another peer
  void _handleIncomingCall(MediaConnection incomingCall) {
    try {
      final remotePeerId = incomingCall.peer;
      _logger.i('📞 Incoming call from: $remotePeerId');

      // Check if we already have this incoming call
      if (_incomingCalls.containsKey(remotePeerId)) {
        _logger.w('⚠️ Already handling incoming call from: $remotePeerId');
        incomingCall.close();
        return;
      }

      // Answer the call
      if (_localStream != null) {
        incomingCall.answer(_localStream!);
        _incomingCalls[remotePeerId] = incomingCall;
        _setupCallHandlers(incomingCall, remotePeerId, isIncoming: true);
        _logger.i('✅ Answered call from: $remotePeerId');
      } else {
        _logger.e('❌ Cannot answer - no local stream');
        incomingCall.close();
      }
    } catch (e) {
      _logger.e('❌ Error handling incoming call: $e');
    }
  }

  /// Setup handlers for a call (incoming or outgoing)
  void _setupCallHandlers(
    MediaConnection call,
    String remotePeerId, {
    required bool isIncoming,
  }) {
    // Handle stream received
    call.on<MediaStream>('stream').listen((remoteStream) {
      _logger.i('📹 Received stream from: $remotePeerId');

      // Update participant
      if (_participants.containsKey(remotePeerId)) {
        _participants[remotePeerId]!.hasStream = true;
        _participants[remotePeerId]!.stream = remoteStream;
      }

      // Notify UI
      onStreamAdded?.call(remotePeerId, remoteStream);
    });

    // Handle call closed
    call.on('close').listen((_) {
      _logger.i('📞 Call closed with: $remotePeerId');
      _cleanupPeerConnection(remotePeerId);
    });

    // Handle errors
    call.on('error').listen((error) {
      _logger.e('❌ Call error with $remotePeerId: $error');
      _cleanupPeerConnection(remotePeerId);
    });
  }

  /// Clean up connection to a peer
  void _cleanupPeerConnection(String peerId) {
    // Close outgoing call if exists
    final outgoingCall = _outgoingCalls.remove(peerId);
    outgoingCall?.close();

    // Close incoming call if exists
    final incomingCall = _incomingCalls.remove(peerId);
    incomingCall?.close();

    // Update participant
    if (_participants.containsKey(peerId)) {
      _participants[peerId]!.hasStream = false;
      _participants[peerId]!.stream = null;
    }

    // Notify UI
    onStreamRemoved?.call(peerId);
  }

  /// Handle when a user leaves
  void handleUserLeft(String peerId) {
    _logger.i('👤 User left: $peerId');

    // Clean up connections
    _cleanupPeerConnection(peerId);

    // Remove participant
    _participants.remove(peerId);

    // Notify UI
    onParticipantLeft?.call(peerId);
  }

  /// Get debug info
  Map<String, dynamic> getDebugInfo() {
    return {
      'myPeerId': _myPeerId,
      'hasLocalStream': _localStream != null,
      'participants': _participants.keys.toList(),
      'outgoingCalls': _outgoingCalls.keys.toList(),
      'incomingCalls': _incomingCalls.keys.toList(),
      'participantsWithStream':
          _participants.values
              .where((p) => p.hasStream)
              .map((p) => p.peerId)
              .toList(),
    };
  }

  /// Dispose everything
  Future<void> dispose() async {
    _logger.i('🧹 Disposing mesh controller');

    // Close all calls
    for (final call in _outgoingCalls.values) {
      call.close();
    }
    for (final call in _incomingCalls.values) {
      call.close();
    }

    // Clear collections
    _outgoingCalls.clear();
    _incomingCalls.clear();
    _participants.clear();

    // Dispose local stream
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      await _localStream!.dispose();
      _localStream = null;
    }

    // Disconnect peer
    _myPeer?.disconnect();
    _myPeer = null;

    _logger.i('✅ Mesh controller disposed');
  }
}

/// Simple participant model
class PeerParticipant {
  final String peerId;
  final String userId;
  final String userName;
  bool hasStream;
  MediaStream? stream;

  PeerParticipant({
    required this.peerId,
    required this.userId,
    required this.userName,
    this.hasStream = false,
    this.stream,
  });
}

enum CallType { audio, video }
