// =============================================================================
// File: lib/features/call/screens/call_screen.dart
// Step 5: The main call screen UI
// =============================================================================

// ignore_for_file: sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';
import 'package:whoxa/featuers/call/call_model.dart';
import 'package:whoxa/featuers/call/call_provider.dart';
import 'package:whoxa/core/services/call_notification_manager.dart';
import 'package:whoxa/screens/splash_screen.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Configuration class for responsive video grid layout
class GridLayoutConfig {
  final int crossAxisCount;
  final double aspectRatio;
  final double spacing;
  final double padding;

  GridLayoutConfig({
    required this.crossAxisCount,
    required this.aspectRatio,
    required this.spacing,
    required this.padding,
  });
}

/// Candidate grid configuration for layout optimization
class GridCandidate {
  final int crossAxisCount;
  final int rows;
  final double aspectRatio;
  final double score;
  final double tileWidth;
  final double tileHeight;

  GridCandidate({
    required this.crossAxisCount,
    required this.rows,
    required this.aspectRatio,
    required this.score,
    required this.tileWidth,
    required this.tileHeight,
  });
}

class CallScreen extends StatefulWidget {
  final int chatId;
  final String chatName;
  final CallType callType;
  final bool isIncoming;
  final int?
  peerId; // Peer user ID for calls without existing chat (chatId = 0)

  const CallScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.callType,
    this.isIncoming = false,
    this.peerId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  bool _controlsVisible = true;
  late AnimationController _pulseController;
  Timer? _incomingCallTimer;
  Timer? _callDurationTimer;
  bool _isNavigating = false;
  bool _isInitializing = true;
  bool _hasCompletedNavigation = false; // Track if we've already navigated once
  DateTime? _screenInitTime;
  String _callDurationText = '00:00';
  final _logger = ConsoleAppLogger.forModule('CallScreen');
  bool _hasStoppedNotification = false;
  // Debouncing variables for state changes
  DateTime? _lastStateChangeTime;
  CallState? _lastProcessedState;
  // Cached display name to prevent UI rebuild spam
  String? _cachedDisplayName;
  // Loading state for call acceptance
  bool _isAcceptingCall = false;

  @override
  void initState() {
    super.initState();
    _screenInitTime = DateTime.now();
    _pulseController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    // Delay initialization to prevent race conditions during cold start
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _isInitializing = false;
        _initializeCall();
      }
    });

    // DEBUG: Log initState timing and widget properties
    _logger.i('🔍 DEBUG: initState() called');
    _logger.i('🔍 DEBUG: widget.isIncoming: ${widget.isIncoming}');

    // Start 30 second timer and notification for incoming calls
    if (widget.isIncoming) {
      // _startIncomingCallTimer(); // Commented out as per requirements
      _startIncomingCallNotification();
    } else {
      // Start outgoing call timer for caller side
      _logger.i('🔍 DEBUG: About to call _startOutgoingCallTimer()');
      _startOutgoingCallTimer();
    }
  }

  // void _startIncomingCallTimer() {
  //   // CRITICAL FIX: Only start timer if we're actually in ringing state
  //   final provider = context.read<CallProvider>();
  //   if (provider.callState != CallState.ringing) {
  //     _logger.w(
  //       '⚠️ Not starting timer - call state is ${provider.callState.name}, not ringing',
  //     );
  //     return;
  //   }

  //   _incomingCallTimer = Timer(Duration(seconds: 30), () async {
  //     if (!mounted) return;

  //     final provider = context.read<CallProvider>();
  //     if (provider.callState == CallState.ringing) {
  //       // Stop notification first
  //       await _stopIncomingCallNotification();

  //       // Then decline the call in background
  //       await provider.declineCall();

  //       // Navigate after decline
  //       if (mounted && !_isNavigating) {
  //         _isNavigating = true;
  //         Navigator.of(context).pop();
  //       }
  //     }
  //   });
  // }

  void _startOutgoingCallTimer() {
    // DEBUG: Log timer initialization
    final provider = context.read<CallProvider>();
    _logger.i('🔍 DEBUG: _startOutgoingCallTimer called');
    _logger.i('🔍 DEBUG: Current call state: ${provider.callState.name}');
    _logger.i('🔍 DEBUG: Provider isInCall: ${provider.isInCall}');
    _logger.i('🔍 DEBUG: Widget isIncoming: ${widget.isIncoming}');

    // For outgoing calls, we want to start timer regardless of current state
    // since the state might transition from idle -> calling quickly
    _logger.i(
      '✅ Starting 30-second outgoing call timer (regardless of current state)',
    );

    _incomingCallTimer = Timer(Duration(seconds: 30), () async {
      if (!mounted) {
        _logger.w('⚠️ Timer fired but widget not mounted');
        return;
      }

      final provider = context.read<CallProvider>();

      // DEBUG: Log detailed state information
      _logger.i('🔍 DEBUG: 30-second timer fired!');
      _logger.i('🔍 DEBUG: Current call state: ${provider.callState.name}');
      _logger.i('🔍 DEBUG: Provider isInCall: ${provider.isInCall}');
      _logger.i('🔍 DEBUG: Provider currentCall: ${provider.currentCall}');
      _logger.i(
        '🔍 DEBUG: Provider participantCount: ${provider.participantCount}',
      );
      _logger.i('🔍 DEBUG: Widget isIncoming: ${widget.isIncoming}');

      // CRITICAL FIX: Only call leave_call when no other user has joined
      // Check if we're still in an active call state AND only current user is in call
      if (provider.callState == CallState.calling ||
          provider.callState == CallState.connecting ||
          provider.callState == CallState.connected) {
        // Check participant count - only leave if no other user joined (participantCount = 1 means only current user)
        if (provider.participantCount <= 1) {
          _logger.i(
            '⏰ State is active (${provider.callState.name}) and no other user joined (count: ${provider.participantCount}) - proceeding with leave_call',
          );

          // Call leave_call method instead of decline_call
          await provider.leaveCall();

          // Navigate after leave
          if (mounted && !_isNavigating) {
            _isNavigating = true;
            Navigator.of(context).pop();
          }
        } else {
          _logger.i(
            '✅ Other users joined the call (count: ${provider.participantCount}) - NOT calling leave_call',
          );
        }
      } else {
        _logger.w(
          '⚠️ Timer fired but call is not active (${provider.callState.name}) - NOT calling leave_call',
        );
      }
    });
  }

  /// Start incoming call notification based on device sound profile
  Future<void> _startIncomingCallNotification() async {
    try {
      await CallNotificationManager.instance.startIncomingCallNotification();
    } catch (e) {
      debugPrint('❌ Failed to start incoming call notification: $e');
    }
  }

  /// Stop incoming call notification
  Future<void> _stopIncomingCallNotification() async {
    try {
      await CallNotificationManager.instance.stopIncomingCallNotification();
    } catch (e) {
      debugPrint('❌ Failed to stop incoming call notification: $e');
    }
  }

  /// Update call duration timer based on call state
  void _updateCallDurationTimer(CallProvider provider) {
    //enable to see call duration in debug
    // _logger.d(
    //   '🕐 _updateCallDurationTimer: callState=${provider.callState.name}, timerActive=${_callDurationTimer?.isActive ?? false}',
    // );

    // Start timer if we have startTime available (regardless of call state)
    if (provider.currentCall?.startTime != null) {
      // Start timer if not already running
      if (_callDurationTimer == null || !_callDurationTimer!.isActive) {
        _logger.i('🕐 Starting call duration timer - startTime available');
        _startCallDurationTimer(provider);
      }
    } else {
      // Stop timer if no startTime available
      if (_callDurationTimer != null && _callDurationTimer!.isActive) {
        _logger.i('🕐 Stopping call duration timer - no startTime available');
        _callDurationTimer?.cancel();
      }
      _callDurationTimer = null;
      // Use post frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _callDurationText = '00:00';
          });
        }
      });
    }
  }

  /// Start call duration timer
  void _startCallDurationTimer(CallProvider provider) {
    _logger.i(
      '🕐 _startCallDurationTimer: startTime=${provider.currentCall?.startTime}',
    );
    _updateCallDurationText(provider);
    _callDurationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && provider.currentCall?.startTime != null) {
        _updateCallDurationText(provider);
      } else {
        _logger.d(
          '🕐 Timer cancelled: mounted=$mounted, hasStartTime=${provider.currentCall?.startTime != null}',
        );
        timer.cancel();
      }
    });
  }

  /// Update call duration text
  void _updateCallDurationText(CallProvider provider) {
    if (provider.currentCall?.startTime != null) {
      final startTime = provider.currentCall!.startTime!;
      final now = DateTime.now();
      final duration = now.difference(startTime);

      // Debug logging for duration calculation
      _logger.d(
        '🕐 Duration calculation: now=$now, startTime=$startTime, duration=${duration.inSeconds}s',
      );

      // Ensure duration is not negative (could happen with server timestamp issues)
      if (duration.isNegative) {
        _logger.w('⚠️ Negative duration detected, resetting startTime to now');
        // Reset startTime to current time to fix negative duration
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && provider.currentCall != null) {
            // We can't directly modify the call in CallManager from here, so we'll show 00:00
            setState(() {
              _callDurationText = '00:00';
            });
          }
        });
        return;
      }

      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      final newDurationText =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      _logger.d(
        '🕐 Calculated duration: ${minutes}m ${seconds}s -> $newDurationText',
      );

      if (_callDurationText != newDurationText && mounted) {
        // Use post frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _callDurationText = newDurationText;
            });
          }
        });
      }
    } else {
      // No startTime available - show appropriate state text
      final stateText =
          provider.callState == CallState.ringing
              ? 'Ringing...'
              : provider.callState == CallState.calling
              ? 'Calling...'
              : '00:00';

      if (_callDurationText != stateText && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _callDurationText = stateText;
            });
          }
        });
      }
    }
  }

  Future<void> _initializeCall() async {
    // Use post frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final provider = context.read<CallProvider>();

      if (!widget.isIncoming) {
        // Making outgoing call
        try {
          await provider.makeCall(
            chatId: widget.chatId,
            callType: widget.callType,
            chatName: widget.chatName,
            peerId:
                widget.peerId, // Pass peerId for calls without existing chat
          );
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed to start call: $e')));
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        // Prevent accidental back navigation during call
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<CallProvider>(
          builder: (context, provider, child) {
            return Stack(
              children: [
                // Main content based on state
                _buildMainContent(provider),

                // Controls overlay
                if (_controlsVisible) _buildControlsOverlay(provider),

                // Incoming call overlay - now handled in controls
                if (widget.isIncoming &&
                    provider.callState == CallState.ringing)
                  _buildIncomingCallControls(provider),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _logger.i('🧹 CallScreen: dispose() called - starting cleanup');

    // Cancel timers first
    _pulseController.dispose();
    _incomingCallTimer?.cancel();
    _callDurationTimer?.cancel();

    // Reset navigation flag
    _isNavigating = false;

    // Stop notification and audio for all call types when disposing
    _stopIncomingCallNotification();

    // WHOXA-OLD STYLE: Proper disposal order - stop, clear, dispose srcObject
    try {
      final provider = context.read<CallProvider>();

      // WHOXA-OLD: Stop local tracks → Clear arrays → Dispose srcObject
      final localStream = provider.localRenderer.srcObject;
      if (localStream != null) {
        _logger.i('🔇 CallScreen: Disposing local stream (whoxa-old style)...');

        // Step 1: Stop all audio tracks
        for (var track in localStream.getAudioTracks()) {
          track.stop();
        }

        // Step 2: Stop all video tracks
        for (var track in localStream.getVideoTracks()) {
          track.stop();
        }

        // Step 3: CRITICAL - Clear track arrays (whoxa-old does this!)
        localStream.getAudioTracks().clear();
        localStream.getVideoTracks().clear();

        // Step 4: CRITICAL - Dispose srcObject BEFORE clearing renderer (whoxa-old does this!)
        try {
          localStream.dispose();
          _logger.i('✅ Local srcObject disposed');
        } catch (e) {
          _logger.w('⚠️ Error disposing local srcObject: $e');
        }

        // Step 5: Clear renderer reference
        provider.localRenderer.srcObject = null;
      }

      // WHOXA-OLD: Same for remote streams - dispose srcObject!
      for (final entry in provider.remoteRenderers.entries) {
        final peerId = entry.key;
        final renderer = entry.value;
        final stream = renderer.srcObject;

        if (stream != null) {
          _logger.i('🔇 CallScreen: Disposing remote stream for: $peerId');

          // Stop all tracks
          for (var track in stream.getTracks()) {
            track.stop();
          }

          // Clear track arrays
          stream.getAudioTracks().clear();
          stream.getVideoTracks().clear();

          // CRITICAL - Dispose srcObject (whoxa-old does this!)
          try {
            stream.dispose();
            _logger.d('✅ Remote srcObject disposed for: $peerId');
          } catch (e) {
            _logger.w('⚠️ Error disposing remote srcObject for $peerId: $e');
          }

          // Clear renderer reference
          renderer.srcObject = null;
        }
      }

      _logger.i(
        '✅ CallScreen: All streams properly disposed (whoxa-old style)',
      );
    } catch (e) {
      _logger.e('❌ CallScreen: Error during disposal: $e');
    }

    _logger.i(
      '✅ CallScreen: dispose() completed - iOS audio session should be released',
    );
    super.dispose();
  }

  Widget _buildMainContent(CallProvider provider) {
    // CRITICAL FIX: Add state change debouncing
    final currentTime = DateTime.now();
    final currentState = provider.callState;

    // Debounce rapid state changes
    if (_lastStateChangeTime != null &&
        _lastProcessedState == currentState &&
        currentTime.difference(_lastStateChangeTime!).inMilliseconds < 500) {
      // Return current view without processing
      return _buildStateView(provider, currentState);
    }

    _lastStateChangeTime = currentTime;
    _lastProcessedState = currentState;

    // CRITICAL: Stop notification only ONCE per state transition
    if (widget.isIncoming && provider.callState != CallState.ringing) {
      // Use a flag to prevent multiple calls
      if (!_hasStoppedNotification) {
        _hasStoppedNotification = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _stopIncomingCallNotification();
        });
      }
    }

    // Rest of existing method...
    return _buildStateView(provider, currentState);
  }

  // Extract view building to separate method
  Widget _buildStateView(CallProvider provider, CallState state) {
    // Start or stop call duration timer based on state - use post frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateCallDurationTimer(provider);

        // Additional safety check: if we're connected but timer not running, start it after a delay
        if (provider.callState == CallState.connected &&
            (_callDurationTimer == null || !_callDurationTimer!.isActive)) {
          Future.delayed(Duration(milliseconds: 1000), () {
            if (mounted &&
                provider.callState == CallState.connected &&
                (_callDurationTimer == null || !_callDurationTimer!.isActive)) {
              _logger.w(
                '🕐 Safety timer start: Detected connected state without timer, force starting',
              );
              _startCallDurationTimer(provider);
            }
          });
        }
      }
    });

    switch (state) {
      case CallState.idle:
        // Reset notification flag when returning to idle
        _hasStoppedNotification = false;
        // CRITICAL FIX: Reset navigation flag when entering idle from ended to prevent race conditions
        if (_isNavigating) {
          _logger.d(
            '📱 CallState.idle: Resetting navigation flag to prevent race condition',
          );
          _isNavigating = false;
        }

        final timeSinceInit =
            _screenInitTime != null
                ? DateTime.now().difference(_screenInitTime!).inMilliseconds
                : 999999;

        // Debug logging
        _logger.d(
          '📱 CallState.idle debug: _isNavigating=$_isNavigating, _isInitializing=$_isInitializing, timeSinceInit=${timeSinceInit}ms, isIncoming=${widget.isIncoming}',
        );

        // CRITICAL FIX: Improved navigation logic - only navigate once per call session
        if (!_isNavigating &&
            !_isInitializing &&
            !_hasCompletedNavigation &&
            timeSinceInit > 1000) {
          debugPrint('📱 Call state idle - determining proper navigation');
          _isNavigating = true;
          _hasCompletedNavigation =
              true; // Mark that we've completed navigation for this call session

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                // CRITICAL FIX: More robust navigation stack detection
                final canPop = Navigator.of(context).canPop();

                debugPrint('📱 Navigation stack info: canPop=$canPop');
                debugPrint(
                  '📱 Navigation flags: wasSkipped=${SplashNavigationTracker.wasSkipped}, cameFromNotificationTap=${SplashNavigationTracker.cameFromNotificationTap}',
                );

                // Check if app was opened from cold start (launched from notification)
                if (SplashNavigationTracker.wasSkipped) {
                  debugPrint(
                    '📱 Cold start from notification - navigating to proper route',
                  );

                  // For cold start from notification, always navigate to tabbar since user is already logged in
                  debugPrint(
                    '📱 Navigating to tabbar after call from notification',
                  );

                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRoutes.tabbar, (route) => false);

                  // Reset the splash tracker after successful navigation
                  SplashNavigationTracker.reset();
                } else if (SplashNavigationTracker.cameFromNotificationTap) {
                  // User tapped on notification and came to call UI - use removeUntil to go to tabbar
                  debugPrint(
                    '📱 User came from notification tap - navigating to tabbar with removeUntil',
                  );

                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRoutes.tabbar, (route) => false);

                  // Reset the notification flag after successful navigation
                  SplashNavigationTracker.reset();
                } else if (canPop) {
                  // App was already open - try to go back to previous screen
                  debugPrint(
                    '📱 App was open - popping back to previous screen',
                  );
                  Navigator.of(context).pop();
                } else {
                  // Fallback: navigate to tabbar for any other scenario
                  debugPrint('📱 Fallback: navigating to main tabbar');
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRoutes.tabbar, (route) => false);
                }
              } catch (e) {
                _logger.e('❌ Navigation error: $e');
                // Emergency fallback: always try to navigate to tabbar for logged in users
                try {
                  debugPrint('📱 Emergency fallback: navigating to tabbar');
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRoutes.tabbar, (route) => false);
                } catch (e2) {
                  _logger.e('❌ Emergency fallback navigation failed: $e2');
                  // Last resort: go to splash to let app initialize properly
                  try {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.splash,
                      (route) => false,
                    );
                  } catch (e3) {
                    _logger.e('❌ Last resort navigation failed: $e3');
                  }
                }
              }
            }
          });

          // Return loading while navigation happens
          return Container(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        } else {
          // During initialization, show appropriate view
          _logger.d(
            '📱 Call state idle but showing view (initializing: $_isInitializing, timeSinceInit: ${timeSinceInit}ms)',
          );
          return widget.isIncoming
              ? _buildIncomingCallView(provider)
              : _buildCallingView(provider);
        }

      case CallState.calling:
        return _buildCallingView(provider);

      case CallState.ringing:
        return widget.isIncoming
            ? _buildIncomingCallView(provider)
            : _buildCallingView(provider);

      case CallState.connected:
        // Ensure timer is running when displaying connected view
        if (_callDurationTimer == null || !_callDurationTimer!.isActive) {
          _logger.w(
            '🕐 Connected view: Timer not running, starting immediately',
          );
          Future.microtask(() => _startCallDurationTimer(provider));
        }
        return _buildConnectedView(provider);

      case CallState.failed:
        return _buildFailedView(provider);

      // auto call ended with pop so no need to pop in any screen after call ended
      case CallState.ended:
        // Stop notifications immediately without async gap
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _stopIncomingCallNotification();
        });

        // CRITICAL FIX: Show call ended view briefly, then let idle state handle navigation
        // This ensures consistent behavior whether user A or user B cuts the call
        final timeSinceInit =
            _screenInitTime != null
                ? DateTime.now().difference(_screenInitTime!).inMilliseconds
                : 999999;

        _logger.i(
          '📱 CallState.ended: Showing ended view (timeSinceInit: ${timeSinceInit}ms)',
        );

        // Don't try to navigate from ended state - let idle state handle it consistently
        return _buildEndedView();
      case CallState.connecting:
        return _buildConnectingView(provider);
      case CallState.disconnected:
        return _buildDisconnectedView(provider);
    }
  }

  Widget _buildCallingView(CallProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: SizeConfig.sizedBoxHeight(120),
            width: SizeConfig.sizedBoxWidth(120),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(120),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(120),
              child: Image.network(
                toUserProfileCall,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.person, size: 60, color: Colors.white);
                },
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            _getDisplayName(),
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Calling',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(width: 4),
              _buildAnimatedDots(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Calculate opacity for each dot with staggered animation
            final progress = (_pulseController.value + (index * 0.3)) % 1.0;
            final opacity = (0.3 + (0.7 * (1 - (progress - 0.5).abs() * 2)))
                .clamp(0.3, 1.0);

            return Container(
              margin: EdgeInsets.symmetric(horizontal: 1),
              child: Text(
                '.',
                style: TextStyle(
                  color: Colors.white70.withValues(alpha: opacity),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildIncomingCallView(CallProvider provider) {
    return Stack(
      children: [
        // Background with profile pic blur effect
        Container(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Profile image background or default gradient
              _buildBlurredBackground(),

              // Additional blur overlay
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.black.withValues(alpha: 0.3)),
              ),
            ],
          ),
        ),

        // Main content overlay
        SafeArea(
          child: Column(
            children: [
              // Spacer to center content
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Caller name
                    Text(
                      _getDisplayName(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 12),

                    // Incoming call badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Incoming',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      '${widget.callType.name} Call',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    SizedBox(height: 60),

                    // Profile picture with white border
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(child: _buildProfileImage()),
                    ),
                  ],
                ),
              ),

              // Bottom spacer for buttons
              Expanded(flex: 1, child: Container()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedView(CallProvider provider) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _controlsVisible = !_controlsVisible;
        });
      },
      child:
          widget.callType == CallType.video
              ? _buildVideoView(provider)
              : _buildAudioView(provider),
    );
  }

  Widget _buildVideoView(CallProvider provider) {
    final allParticipants = provider.participants;
    // CRITICAL: Filter participants more strictly - ensure both renderer exists AND has valid stream
    final participants =
        allParticipants.where((participant) {
          final renderer = provider.remoteRenderers[participant.peerId];
          // CRITICAL: Only show if renderer exists, is properly connected, AND renderer has a valid stream
          return renderer != null &&
              participant.isConnected &&
              renderer.srcObject != null;
        }).toList();

    // Calculate total participants (local user + remote participants)
    final totalCount = participants.length + 1; // +1 for local user

    // DISABLED: This was forcing speaker back ON every UI rebuild
    // _checkAndEnforceSpeakerModeBackup(provider, totalCount);

    return Stack(
      children: [
        // Use responsive video grid to show all participants
        _buildResponsiveVideoGrid(provider, participants, totalCount),

        // Call duration timer overlay - centered
        Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    _callDurationText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Responsive video layout that adapts based on participant count
  Widget _buildResponsiveVideoGrid(
    CallProvider provider,
    List participants,
    int totalCount,
  ) {
    // Special handling for 2 participants - use Column layout (one above the other)
    if (totalCount == 2) {
      return _build2ParticipantLayout(provider, participants, totalCount);
    }

    // Special handling for 3 participants with optimized layout
    if (totalCount == 3) {
      return _build3ParticipantLayout(provider, participants, totalCount);
    }

    // Special handling for 4 participants - custom 50%+50% layout
    if (totalCount == 4) {
      return _build4ParticipantLayout(provider, participants, totalCount);
    }

    // For 5+ participants, use 2x2 GridView layout with scrolling
    final gridLayout = _calculateOptimalGridLayout(totalCount, context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use available screen space efficiently
        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          padding: EdgeInsets.zero, // Use full screen
          child: GridView.builder(
            // Enable scrolling for 5+ participants, otherwise clamp to prevent bounce
            physics:
                totalCount > 4
                    ? BouncingScrollPhysics()
                    : ClampingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridLayout.crossAxisCount,
              crossAxisSpacing: gridLayout.spacing,
              mainAxisSpacing: gridLayout.spacing,
              childAspectRatio: gridLayout.aspectRatio,
            ),
            itemCount: totalCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                // Local video always first
                return _buildVideoTile(
                  renderer: provider.localRenderer,
                  name: 'You',
                  userId: userID.toString(),
                  isLocal: true,
                  isMuted: !provider.isAudioEnabled,
                  hasVideo: provider.isVideoEnabled,
                );
              } else {
                // Remote videos
                final participantIndex = index - 1;
                if (participantIndex < participants.length) {
                  final participant = participants[participantIndex];
                  final renderer = provider.remoteRenderers[participant.peerId];

                  // Double-check renderer still exists
                  if (renderer == null || renderer.srcObject == null) {
                    return _buildVideoTilePlaceholder('Connection Lost');
                  }

                  return _buildVideoTile(
                    renderer: renderer,
                    name: participant.userName,
                    userId: participant.userId,
                    peerId: participant.peerId,
                    isLocal: false,
                    isMuted: !participant.hasAudio,
                    hasVideo: participant.hasVideo,
                  );
                } else {
                  return _buildVideoTilePlaceholder('Waiting...');
                }
              }
            },
          ),
        );
      },
    );
  }

  /// Calculate optimal grid layout for maximum screen space efficiency
  GridLayoutConfig _calculateOptimalGridLayout(
    int participantCount,
    BuildContext context,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    final screenAspectRatio = screenSize.width / screenSize.height;

    // Use full device height and width for better visibility
    final availableHeight = screenSize.height; // Full device height
    final availableWidth = screenSize.width; // Full device width

    // Calculate optimal layout based on screen space and participant count
    final layout = _calculateSpaceOptimalLayout(
      participantCount,
      availableWidth,
      availableHeight,
      isLandscape,
      screenAspectRatio,
    );

    return layout;
  }

  GridLayoutConfig _calculateSpaceOptimalLayout(
    int participantCount,
    double availableWidth,
    double availableHeight,
    bool isLandscape,
    double screenAspectRatio,
  ) {
    // 1 user → Fullscreen
    if (participantCount == 1) {
      return GridLayoutConfig(
        crossAxisCount: 1,
        aspectRatio: isLandscape ? 16 / 9 : 9 / 16,
        spacing: 0,
        padding: 0,
      );
    }

    // 2 users → 1 row, 2 columns (side by side) - 50/50 split
    if (participantCount == 2) {
      return GridLayoutConfig(
        crossAxisCount: 2,
        aspectRatio:
            isLandscape ? 4 / 3 : 3 / 4, // Orientation-aware aspect ratio
        spacing: 2.0, // Minimal spacing for maximum video size
        padding: 0.0, // No padding for full screen usage
      );
    }

    // 3 users → 2 rows: 2 on top, 1 centered on bottom
    if (participantCount == 3) {
      return GridLayoutConfig(
        crossAxisCount: 2,
        aspectRatio: 4 / 3,
        spacing: 2.0, // Minimal spacing
        padding: 0.0, // No padding for full screen usage
      );
    }

    // 5+ users → Use 2x2 grid size for consistent large tiles with scrolling
    return GridLayoutConfig(
      crossAxisCount: 2, // Always 2 columns for large, consistent tiles
      aspectRatio: isLandscape ? 1.4 : 0.9, // Large tiles for good visibility
      spacing: 2.0, // Minimal spacing for maximum video size
      padding: 0.0, // No padding for full screen usage
    );
  }

  /// Special layout for 2 participants: Column layout (one above the other)
  Widget _build2ParticipantLayout(
    CallProvider provider,
    List participants,
    int totalCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 2.0; // Minimal spacing for maximum video size

        return Container(
          padding: EdgeInsets.zero, // Use full screen
          child: Column(
            children: [
              // Local video (top)
              Expanded(
                flex: 1,
                child: Container(
                  margin: EdgeInsets.only(bottom: spacing / 2),
                  child: _buildVideoTile(
                    renderer: provider.localRenderer,
                    name: 'You',
                    userId: userID.toString(),
                    isLocal: true,
                    isMuted: !provider.isAudioEnabled,
                    hasVideo: provider.isVideoEnabled,
                  ),
                ),
              ),

              // Remote participant (bottom)
              Expanded(
                flex: 1,
                child: Container(
                  margin: EdgeInsets.only(top: spacing / 2),
                  child:
                      participants.isNotEmpty
                          ? _buildVideoTile(
                            renderer:
                                provider.remoteRenderers[participants[0]
                                    .peerId],
                            name: participants[0].userName,
                            userId: participants[0].userId,
                            peerId: participants[0].peerId,
                            isLocal: false,
                            isMuted: !participants[0].hasAudio,
                            hasVideo: participants[0].hasVideo,
                          )
                          : _buildVideoTilePlaceholder('Connecting...'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Special layout for 3 participants: 2 on top, 1 centered below with maximum screen utilization
  Widget _build3ParticipantLayout(
    CallProvider provider,
    List participants,
    int totalCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final spacing = 2.0; // Minimal spacing for maximum video size

        if (isLandscape) {
          // Landscape: 3 participants in a row, equal sizes
          return Container(
            padding: EdgeInsets.zero, // Use full screen
            child: Row(
              children: [
                // Local video (always first)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: spacing / 2),
                    child: _buildVideoTile(
                      renderer: provider.localRenderer,
                      name: 'You',
                      userId: userID.toString(),
                      isLocal: true,
                      isMuted: !provider.isAudioEnabled,
                      hasVideo: provider.isVideoEnabled,
                    ),
                  ),
                ),
                // Remote participants
                ...participants.asMap().entries.map((entry) {
                  final participant = entry.value;
                  final renderer = provider.remoteRenderers[participant.peerId];

                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: spacing / 2),
                      child: _buildVideoTile(
                        renderer: renderer,
                        name: participant.userName,
                        userId: participant.userId,
                        peerId: participant.peerId,
                        isLocal: false,
                        isMuted: !participant.hasAudio,
                        hasVideo: participant.hasVideo,
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        } else {
          // Portrait: Use Expanded widgets to prevent overflow
          final availableWidth = constraints.maxWidth; // Use full width
          final bottomTileWidth =
              availableWidth * 0.70; // 70% width for bottom tile

          return Container(
            padding: EdgeInsets.zero, // Use full screen
            child: Column(
              children: [
                // Top row with 2 tiles - Use Expanded to fill available space
                Expanded(
                  flex: 1, // Equal space for top row
                  child: Row(
                    children: [
                      // Local video
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: spacing / 2),
                          child: _buildVideoTile(
                            renderer: provider.localRenderer,
                            name: 'You',
                            userId: userID.toString(),
                            isLocal: true,
                            isMuted: !provider.isAudioEnabled,
                            hasVideo: provider.isVideoEnabled,
                          ),
                        ),
                      ),
                      // First remote participant
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.only(left: spacing / 2),
                          child:
                              participants.isNotEmpty
                                  ? _buildVideoTile(
                                    renderer:
                                        provider.remoteRenderers[participants[0]
                                            .peerId],
                                    name: participants[0].userName,
                                    userId: participants[0].userId,
                                    peerId: participants[0].peerId,
                                    isLocal: false,
                                    isMuted: !participants[0].hasAudio,
                                    hasVideo: participants[0].hasVideo,
                                  )
                                  : _buildVideoTilePlaceholder('Connecting...'),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: spacing),

                // Bottom row with 1 centered participant - Use Expanded to fill remaining space
                Expanded(
                  flex: 1, // Equal space for bottom row
                  child: Center(
                    child: Container(
                      width: bottomTileWidth,
                      child:
                          participants.length >= 2
                              ? _buildVideoTile(
                                renderer:
                                    provider.remoteRenderers[participants[1]
                                        .peerId],
                                name: participants[1].userName,
                                userId: participants[1].userId,
                                peerId: participants[1].peerId,
                                isLocal: false,
                                isMuted: !participants[1].hasAudio,
                                hasVideo: participants[1].hasVideo,
                              )
                              : _buildVideoTilePlaceholder('Waiting...'),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  /// Special layout for 4 participants: 2 participants top (50%), 2 participants bottom (50%)
  Widget _build4ParticipantLayout(
    CallProvider provider,
    List participants,
    int totalCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 2.0; // Minimal spacing for maximum video size

        return Container(
          padding: EdgeInsets.zero, // Use full screen
          child: Column(
            children: [
              // Top half - First 2 participants (50% of screen)
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    // Local video (always first)
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          right: spacing / 2,
                          bottom: spacing / 2,
                        ),
                        child: _buildVideoTile(
                          renderer: provider.localRenderer,
                          name: 'You',
                          userId: userID.toString(),
                          isLocal: true,
                          isMuted: !provider.isAudioEnabled,
                          hasVideo: provider.isVideoEnabled,
                        ),
                      ),
                    ),
                    // Second participant
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          left: spacing / 2,
                          bottom: spacing / 2,
                        ),
                        child:
                            participants.isNotEmpty
                                ? _buildVideoTile(
                                  renderer:
                                      provider.remoteRenderers[participants[0]
                                          .peerId],
                                  name: participants[0].userName,
                                  userId: participants[0].userId,
                                  peerId: participants[0].peerId,
                                  isLocal: false,
                                  isMuted: !participants[0].hasAudio,
                                  hasVideo: participants[0].hasVideo,
                                )
                                : _buildVideoTilePlaceholder('Connecting...'),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom half - Last 2 participants (50% of screen)
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    // Third participant
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          right: spacing / 2,
                          top: spacing / 2,
                        ),
                        child:
                            participants.length >= 2
                                ? _buildVideoTile(
                                  renderer:
                                      provider.remoteRenderers[participants[1]
                                          .peerId],
                                  name: participants[1].userName,
                                  userId: participants[1].userId,
                                  peerId: participants[1].peerId,
                                  isLocal: false,
                                  isMuted: !participants[1].hasAudio,
                                  hasVideo: participants[1].hasVideo,
                                )
                                : _buildVideoTilePlaceholder('Waiting...'),
                      ),
                    ),
                    // Fourth participant
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          left: spacing / 2,
                          top: spacing / 2,
                        ),
                        child:
                            participants.length >= 3
                                ? _buildVideoTile(
                                  renderer:
                                      provider.remoteRenderers[participants[2]
                                          .peerId],
                                  name: participants[2].userName,
                                  userId: participants[2].userId,
                                  peerId: participants[2].peerId,
                                  isLocal: false,
                                  isMuted: !participants[2].hasAudio,
                                  hasVideo: participants[2].hasVideo,
                                )
                                : _buildVideoTilePlaceholder('Waiting...'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Placeholder widget for video tiles that are loading or disconnected
  Widget _buildVideoTilePlaceholder(String message) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade700.withValues(alpha: 0.5),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.grey.shade500,
                  size: 32,
                ),
              ),
              SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoTile({
    RTCVideoRenderer? renderer,
    required String name,
    String? userId,
    String? peerId,
    required bool isLocal,
    bool isMuted = false,
    bool hasVideo = true,
  }) {
    // Video tile setup

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade700, width: 0.5),
        ),
        child: Stack(
          children: [
            // Video or placeholder - CRITICAL: Ensure renderer stream exists
            if (renderer != null && hasVideo && renderer.srcObject != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: RTCVideoView(
                  renderer,
                  mirror: isLocal,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[700],
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      renderer == null
                          ? 'No renderer'
                          : renderer.srcObject == null
                          ? 'No stream'
                          : !hasVideo
                          ? 'Video off'
                          : 'Loading...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Name label with user ID info
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mute indicator for both local and remote users
                        if (isMuted) ...[
                          Icon(
                            Icons.mic_off_rounded,
                            color: Colors.red.shade400,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(width: 4),
                        // Video off indicator for both local and remote users
                        if (!hasVideo)
                          Icon(
                            Icons.videocam_off_rounded,
                            color: Colors.orange.shade400,
                            size: 14,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Status indicators overlay for better visibility
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Audio status indicator
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color:
                          isMuted ? Colors.red.shade600 : Colors.green.shade600,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                  SizedBox(width: 6),
                  // Video status indicator (only for video calls)
                  if (hasVideo || !hasVideo) // Always show for video calls
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color:
                            hasVideo
                                ? Colors.green.shade600
                                : Colors.orange.shade600,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        hasVideo
                            ? Icons.videocam_rounded
                            : Icons.videocam_off_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioView(CallProvider provider) {
    // CRITICAL: Filter out participants without active renderers, disconnected participants, AND no valid stream
    final participants =
        provider.participants.where((participant) {
          final renderer = provider.remoteRenderers[participant.peerId];
          return renderer != null &&
              participant.isConnected &&
              renderer.srcObject != null;
        }).toList();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Main speaker avatar
          CircleAvatar(
            radius: 80,
            backgroundColor: Colors.grey[800],
            child: Icon(Icons.person, size: 80, color: Colors.white),
          ),
          SizedBox(height: 20),
          Text(
            _getDisplayName(),
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
          SizedBox(height: 10),
          // Call duration
          Text(
            _callDurationText,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 40),

          // Participants list
          if (participants.isNotEmpty) ...[
            Text(
              'Participants',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 16),
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: participants.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildParticipantItem(
                      name: 'You',
                      isMuted: !provider.isAudioEnabled,
                    );
                  }
                  final participant = participants[index - 1];
                  return _buildParticipantItem(
                    name: participant.userName,
                    isMuted: !participant.hasAudio,
                    isConnected: participant.isConnected,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantItem({
    required String name,
    bool isMuted = false,
    bool isConnected = true,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: isConnected ? Colors.green : Colors.grey,
          ),
          SizedBox(width: 12),
          Expanded(child: Text(name, style: TextStyle(color: Colors.white))),
          if (isMuted) Icon(Icons.mic_off, color: Colors.red, size: 20),
        ],
      ),
    );
  }

  Widget _buildFailedView(CallProvider provider) {
    // Auto-navigate after showing failed state briefly
    // CRITICAL: Add cold start protection here too
    if (!_isNavigating && !_isInitializing) {
      final timeSinceInit =
          _screenInitTime != null
              ? DateTime.now().difference(_screenInitTime!).inMilliseconds
              : 999999;

      if (timeSinceInit > 2000) {
        // Only auto-navigate if screen has been up for at least 2 seconds
        _isNavigating = true;
        Future.delayed(Duration(milliseconds: 2000), () {
          if (mounted) {
            try {
              Navigator.of(context).pop();
            } catch (e) {
              debugPrint('Error during navigation from failed state: $e');
            }
          }
        });
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 64),
          SizedBox(height: 20),
          Text(
            'Call Failed',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
          SizedBox(height: 10),
          Text(
            provider.lastError ?? 'Connection failed',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          SizedBox(height: 10),
          Text(
            'Closing...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEndedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.call_end, color: Colors.white, size: 64),
          SizedBox(height: 20),
          Text(
            'Call Ended',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
          SizedBox(height: 20),
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          SizedBox(height: 10),
          Text(
            'Closing...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay(CallProvider provider) {
    // CRITICAL: Don't show regular controls for incoming calls
    if (widget.isIncoming && provider.callState == CallState.ringing) {
      return Container(); // Empty container, incoming controls shown separately
    }

    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: SafeArea(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                ),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute button
                    _buildNewControlButton(
                      svgPath:
                          provider.isAudioEnabled
                              ? 'assets/images/call/microphone-on.svg'
                              : 'assets/images/call/microphone-disable.svg',
                      isEnabled: provider.isAudioEnabled,
                      onTap: () => provider.toggleAudio(),
                    ),

                    // Video button (for video calls)
                    if (widget.callType == CallType.video)
                      _buildNewControlButton(
                        svgPath:
                            provider.isVideoEnabled
                                ? 'assets/images/call/video_on.svg'
                                : 'assets/images/call/video-disable.svg',
                        isEnabled: provider.isVideoEnabled,
                        onTap: () => provider.toggleVideo(),
                      ),

                    // Speaker button
                    _buildNewControlButton(
                      svgPath:
                          provider.isSpeakerOn
                              ? 'assets/images/call/speaker-on.svg'
                              : 'assets/images/call/speaker-disable.svg',
                      isEnabled: provider.isSpeakerOn,
                      onTap: () async {
                        try {
                          await provider.toggleSpeaker();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to toggle speaker'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),

                    // Switch camera (for video calls)
                    if (widget.callType == CallType.video)
                      _buildNewControlButton(
                        svgPath: 'assets/images/Camera.svg',
                        isEnabled: true,
                        onTap: () => provider.switchCamera(),
                      ),

                    // End call button - moved to last position
                    _buildNewControlButton(
                      svgPath: 'assets/images/call/Call.svg',
                      isEndCall: true,
                      onTap: () async {
                        await _stopIncomingCallNotification();
                        await provider.endCall();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewControlButton({
    required String svgPath,
    required VoidCallback onTap,
    bool isEnabled = true,
    bool isEndCall = false,
  }) {
    final size = 56.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color:
              isEndCall
                  ? Color(0xFFFF3B30) // Red for end call
                  : Colors.white.withValues(
                    alpha: 0.2,
                  ), // Semi-transparent white
          shape: BoxShape.circle,
          border:
              isEndCall
                  ? null
                  : Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
        ),
        child: Center(
          child: SvgPicture.asset(
            svgPath,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  /// CRITICAL: Incoming call controls overlay
  Widget _buildIncomingCallControls(CallProvider provider) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Stack(
        children: [
          // Main controls
          Container(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject button with ripple animation
                  _buildRippleCallButton(
                    backgroundColor: Colors.red,
                    icon: Icons.call_end,
                    label: 'Reject',
                    onTap: () async {
                      if (_isNavigating) return;

                      try {
                        _incomingCallTimer?.cancel();
                        await _stopIncomingCallNotification();
                        await provider.declineCall();

                        if (mounted && !_isNavigating) {
                          _isNavigating = true;
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        debugPrint('Error declining call: $e');
                        if (mounted && !_isNavigating) {
                          _isNavigating = true;
                          Navigator.of(context).pop();
                        }
                      }
                    },
                  ),

                  // Accept button with ripple animation
                  _buildRippleCallButton(
                    backgroundColor: Colors.green,
                    icon: Icons.call,
                    label: 'Confirm',
                    onTap: () async {
                      // Prevent multiple taps
                      if (_isNavigating || _isAcceptingCall) return;

                      // Set loading state
                      setState(() {
                        _isAcceptingCall = true;
                      });

                      try {
                        _incomingCallTimer?.cancel();
                        await _stopIncomingCallNotification();
                        await provider.acceptCall();

                        if (mounted) {
                          setState(() {
                            _isAcceptingCall = false;
                          });
                        }
                      } catch (e) {
                        debugPrint('❌ Error accepting call: $e');
                        if (mounted) {
                          setState(() {
                            _isAcceptingCall = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to accept call: $e'),
                            ),
                          );

                          if (!_isNavigating) {
                            _isNavigating = true;
                            Navigator.of(context).pop();
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay when accepting call
          if (_isAcceptingCall)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Connecting...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRippleCallButton({
    required IconData icon,
    required Color backgroundColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 100, // Fixed container size to prevent movement
            height: 100, // Fixed container size to prevent movement
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ripple circle - contained within fixed size
                    Container(
                      width: 80 + (_pulseController.value * 20),
                      height: 80 + (_pulseController.value * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: backgroundColor.withValues(
                          alpha: 0.3 * (1 - _pulseController.value),
                        ),
                      ),
                    ),
                    // Middle ripple circle - contained within fixed size
                    Container(
                      width: 75 + (_pulseController.value * 10),
                      height: 75 + (_pulseController.value * 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: backgroundColor.withValues(
                          alpha: 0.4 * (1 - _pulseController.value * 0.7),
                        ),
                      ),
                    ),
                    // Main button - stays constant size
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 32),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 20, // Fixed height to prevent text layout shifts
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildBlurredBackground() {
    // Get profile picture from call provider
    final provider = context.watch<CallProvider>();
    final profilePicUrl = provider.currentCall?.callerProfilePic;

    if (profilePicUrl != null && profilePicUrl.isNotEmpty) {
      return Image.network(
        profilePicUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to gradient background if image fails to load
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8A87C),
                  Color(0xFFC38B69),
                  Color(0xFF8B6B47),
                  Color(0xFF5A4A3A),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          );
        },
      );
    }

    // Default gradient background
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE8A87C),
            Color(0xFFC38B69),
            Color(0xFF8B6B47),
            Color(0xFF5A4A3A),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    // Get profile picture from call provider
    final provider = context.watch<CallProvider>();
    final profilePicUrl = provider.currentCall?.callerProfilePic;

    if (profilePicUrl != null && profilePicUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          profilePicUrl,
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to default if image fails to load
            return Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE8A87C), Color(0xFFC38B69)],
                ),
              ),
              child: Icon(
                Icons.person,
                size: 80,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE8A87C), Color(0xFFC38B69)],
                ),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value:
                      loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      );
    }

    // Default fallback image
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8A87C), Color(0xFFC38B69)],
        ),
      ),
      child: Icon(
        Icons.person,
        size: 80,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }

  /// CRITICAL: Add missing state views
  Widget _buildConnectingView(CallProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 20),
          Text(
            'Connecting...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedView(CallProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.signal_wifi_off, color: Colors.orange, size: 64),
          SizedBox(height: 20),
          Text(
            'Disconnected',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
          SizedBox(height: 10),
          Text(
            'Trying to reconnect...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // REMOVED: _checkAndEnforceSpeakerModeBackup - No longer needed
  // This method was disabled as speaker mode is now properly managed by CallProvider

  /// Get the display name using the same logic as chat list
  String _getDisplayName() {
    // Return cached name if available to prevent UI rebuild spam
    if (_cachedDisplayName != null) {
      return _cachedDisplayName!;
    }

    try {
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      ProjectConfigProvider? configProvider;
      try {
        configProvider = Provider.of<ProjectConfigProvider>(
          context,
          listen: false,
        );
      } catch (e) {
        _logger.w('⚠️ Could not get ConfigProvider: $e');
        // Continue without configProvider - fallback to basic display name logic
      }

      // PRIORITY 1: For incoming calls, check if CallProvider has caller name
      // This is especially important for incoming calls where chat data might not be loaded yet
      if (widget.isIncoming && callProvider.currentCall != null) {
        final callerName = callProvider.currentCall!.callerName;
        if (callerName.isNotEmpty &&
            callerName != 'Unknown' &&
            !callerName.startsWith('Caller ')) {
          // Try to enhance with contact name service if we have user data
          if (callProvider.participants.isNotEmpty) {
            final firstParticipant = callProvider.participants.first;
            final userId = int.tryParse(firstParticipant.userId);
            if (userId != null) {
              // Ensure contacts are loaded into cache if not already
              if (!ContactNameService.instance.hasCachedContacts) {
                debugPrint('📞 CallUI: Contact cache empty, triggering load');
                ContactNameService.instance.loadAndCacheContacts().catchError((
                  e,
                ) {
                  debugPrint('📞 CallUI: Failed to load contacts: $e');
                });
              }

              final contactName = ContactNameService.instance
                  .getDisplayNameStable(
                    userId: userId,
                    configProvider: configProvider,
                    contextFullName: null, // No context available here
                  );
              if (contactName != callerName) {
                _cachedDisplayName = contactName;
                return contactName;
              }
            }
          }

          _cachedDisplayName = callerName;
          return callerName;
        }
      }

      // PRIORITY 2: Try to get peer data from chat list using chatId
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final chatListData = chatProvider.chatListData;

      if (chatListData.chats.isNotEmpty) {
        for (final chat in chatListData.chats) {
          // Check if this chat matches our chatId by looking at the records
          if (chat.records?.isNotEmpty == true &&
              chat.records!.first.chatId == widget.chatId) {
            final record = chat.records!.first;
            final chatType = record.chatType ?? 'Private';
            final isGroupChat = chatType.toLowerCase() == 'group';

            // For group calls, prioritize group name
            if (isGroupChat) {
              String displayName;
              if (record.groupName != null &&
                  record.groupName!.trim().isNotEmpty) {
                displayName = record.groupName!;
              }
              // Fallback to peer data for group if no group name
              else if (chat.peerUserData?.fullName != null &&
                  chat.peerUserData!.fullName!.trim().isNotEmpty) {
                displayName = "${chat.peerUserData!.fullName!} (Group)";
              } else {
                displayName = 'Group Call';
              }
              _cachedDisplayName = displayName;
              return displayName;
            }

            // For individual calls, use contact name service
            if (chat.peerUserData != null) {
              final displayName = ContactNameService.instance
                  .getDisplayNameStable(
                    userId: chat.peerUserData!.userId,
                    configProvider: configProvider,
                    contextFullName:
                        chat
                            .peerUserData!
                            .fullName, // Pass the full name from peer data
                  );
              _cachedDisplayName = displayName;
              return displayName;
            }
          }
        }
      }

      // PRIORITY 3: For outgoing calls, check CallProvider caller name as secondary option
      if (!widget.isIncoming && callProvider.currentCall != null) {
        final callerName = callProvider.currentCall!.callerName;
        if (callerName.isNotEmpty && callerName != widget.chatName) {
          _cachedDisplayName = callerName;
          return callerName;
        }
      }
    } catch (e) {
      _logger.w('Error getting display name: $e');
    }

    // FALLBACK: Use widget.chatName if no other data available
    _cachedDisplayName = widget.chatName;
    return widget.chatName;
  }
}
