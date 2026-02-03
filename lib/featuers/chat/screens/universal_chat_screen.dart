import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:stanchat/featuers/chat/screens/location.dart';
import 'package:stanchat/featuers/chat/utils/chat_date_grouper.dart';
import 'package:stanchat/featuers/profile/screens/user_profile_view.dart';
import 'package:stanchat/featuers/profile/screens/user_profile_view_business.dart';
import 'package:get_it/get_it.dart';
import 'package:stanchat/core/api/api_client.dart';
import 'package:stanchat/featuers/auth/data/models/user_name_check_model.dart';
import 'package:stanchat/featuers/chat/data/chats_model.dart' as chats;
import 'package:stanchat/featuers/chat/provider/chat_provider.dart';
import 'package:stanchat/featuers/chat/group/provider/group_provider.dart';
import 'package:stanchat/featuers/chat/utils/chat_cache_manager.dart';
import 'package:stanchat/featuers/chat/utils/cache_test_helper.dart';
import 'package:stanchat/featuers/chat/screens/pdf_viewer_screen.dart';
import 'package:stanchat/featuers/chat/utils/message_utils.dart';
import 'package:stanchat/featuers/chat/widgets/chat_appbar_title.dart';
import 'package:stanchat/featuers/chat/widgets/chat_files_views_handle/image_view.dart';
import 'package:stanchat/featuers/chat/widgets/chat_files_views_handle/video_view.dart';
import 'package:stanchat/featuers/chat/widgets/chat_keyboard.dart';
import 'package:stanchat/featuers/chat/widgets/chat_type_dialog.dart';
import 'package:stanchat/featuers/chat/widgets/current_chat_widget/lastseen_widget.dart';
import 'package:stanchat/featuers/chat/widgets/current_chat_widget/message_content_widget.dart';
import 'package:stanchat/featuers/chat/widgets/current_chat_widget/pin_duration_dialog.dart';
import 'package:stanchat/featuers/chat/widgets/pinned_widget.dart';
import 'package:stanchat/featuers/chat/widgets/contact_picker_bottom_sheet.dart';
import 'package:stanchat/featuers/contacts/screen/contact_list.dart';
import 'package:stanchat/featuers/contacts/data/model/contact_model.dart';
import 'package:stanchat/featuers/home/screens/chat_list.dart';
import 'package:stanchat/featuers/call/chat_buttons.dart';
import 'package:stanchat/featuers/chat/services/contact_name_service.dart';
import 'package:stanchat/featuers/project-config/provider/config_provider.dart';
import 'package:stanchat/featuers/provider/voice_provider.dart';
import 'package:stanchat/utils/app_size_config.dart';
import 'package:stanchat/utils/enums.dart';
import 'package:stanchat/utils/preference_key/constant/app_assets.dart';
import 'package:stanchat/utils/preference_key/constant/app_routes.dart';
import 'package:stanchat/utils/location_service.dart';
import 'package:stanchat/utils/logger.dart';
import 'package:stanchat/utils/packages/scroll_to_index/scroll_to_index.dart';
import 'package:stanchat/utils/preference_key/constant/app_colors.dart';
import 'package:stanchat/utils/preference_key/constant/app_text_style.dart';
import 'package:stanchat/utils/preference_key/constant/app_theme_manage.dart';
import 'package:stanchat/utils/preference_key/constant/strings.dart';
import 'package:stanchat/utils/preference_key/preference_key.dart';
import 'package:stanchat/utils/preference_key/sharedpref_key.dart';
import 'package:stanchat/utils/voice_wave.dart/mic_animation.dart';
import 'package:stanchat/widgets/cusotm_blur_appbar.dart';
import 'package:stanchat/featuers/report/widgets/report_user_dialog.dart';
import 'package:stanchat/widgets/custom_bottomsheet.dart';
import 'package:stanchat/widgets/global.dart';
import 'package:stanchat/widgets/global.dart' as global;
import 'package:stanchat/utils/preference_key/constant/app_direction_manage.dart';
import 'package:audioplayers/audioplayers.dart';

/// Navigation source enum to track where user navigated from
enum NavigationSource {
  chatList,
  starredMessages,
  userProfile,
  archive,
  unknown,
}

/// OneToOneChat Screen - Main chat interface for private conversations
///
/// This screen handles:
/// - Real-time messaging with text, images, videos, documents, location
/// - Message starring, pinning, replying, deleting
/// - Auto-pagination for loading older messages
/// - Message highlighting and searching
/// - Typing indicators and online status
/// - Chat focus management for marking messages as seen
class UniversalChatScreen extends StatefulWidget {
  final int? userId; // For individual chats
  final String profilePic;
  final String chatName; // User name or group name
  final int? chatId;
  final String? updatedAt;
  final bool isGroupChat; // Flag to distinguish chat types
  final String? groupDescription; // Group description if available
  final bool searchMode; // Flag to enable search mode
  final bool blockFlag; // Instant block status for initial UI rendering
  final int? highlightMessageId; // Message ID to highlight when opening chat
  final bool fromArchive; // Flag to track navigation source

  const UniversalChatScreen({
    super.key,
    this.userId,
    required this.profilePic,
    required this.chatName,
    this.chatId,
    this.updatedAt,
    this.isGroupChat = false,
    this.groupDescription,
    this.searchMode = false,
    this.blockFlag = false, // Default to not blocked
    this.highlightMessageId, // Add parameter for message highlighting
    this.fromArchive = false, // Default to not from archive
  });

  @override
  State<UniversalChatScreen> createState() => _UniversalChatScreenState();
}

class _UniversalChatScreenState extends State<UniversalChatScreen>
    with WidgetsBindingObserver {
  // ═══════════════════════════════════════════════════════════════════════════
  // CONTROLLERS & FOCUS NODES
  // ═══════════════════════════════════════════════════════════════════════════

  final TextEditingController _messageController = TextEditingController();
  // final ScrollController _scrollController = ScrollController();
  late AutoScrollController _scrollController;
  final FocusNode _messageFocusNode = FocusNode();

  // ═══════════════════════════════════════════════════════════════════════════
  // CORE STATE VARIABLES
  // ═══════════════════════════════════════════════════════════════════════════

  final ConsoleAppLogger _logger = ConsoleAppLogger();
  ChatProvider? _chatProvider;
  // String? _chatProvider!.currentUserId;
  // bool _isDisposed = false;
  // bool _isInitialized = false;
  // bool _isInitializing = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // UI STATE VARIABLES
  // ═══════════════════════════════════════════════════════════════════════════

  // bool _isLoadingCurrentUser = false;
  // bool _hasError = false;
  // String? _errorMessage;
  bool _isAttachmentMenuOpen = false;
  bool _isClearingChat = false;

  // New message notification system
  bool _showNewMessageIndicator = false;
  int _newMessageCount = 0;
  bool _isUserScrolledUp = false;
  bool _preventAutoScroll = false;
  StreamSubscription<chats.Records>? _newMessageSubscription;

  // ═══════════════════════════════════════════════════════════════════════════
  // SEARCH FUNCTIONALITY
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isSearchMode = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  int _searchCurrentPage = 1;
  // ignore: unused_field
  int _searchTotalPages = 1;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // ═══════════════════════════════════════════════════════════════════════════
  // TYPING & FOCUS MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  Timer? _typingTimer;
  bool _isTyping = false;
  // bool _isScreenActive = false;
  bool isUrlText = false;
  bool _hasInitializedFocus = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // ONLINE STATUS & USER MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  final bool _isUserOnlineFromApi = false;
  // bool _isLoadingOnlineStatus = false;
  // String? _lastSeenFromApi;
  bool _isSendingLocation = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // FILE ATTACHMENTS
  // ═══════════════════════════════════════════════════════════════════════════

  List<File>? _selectedImages;
  List<File>? _selectedDocuments;
  List<File>? _selectedVideos;
  String _videoThumbnail = "";

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGINATION & SCROLLING
  // ═══════════════════════════════════════════════════════════════════════════

  Timer? _paginationDebounceTimer;
  Timer? _scrollDebounceTimer;
  bool _isInitialLoadComplete = false;
  // ignore: unused_field
  bool _hasTriggeredPagination = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE HIGHLIGHTING & NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════

  final Map<int, GlobalKey> _messageKeys = {};
  Map<int, int> _messageIdToWidgetIndex = {};

  // Helper getters
  bool get isGroupChat => widget.isGroupChat;
  bool get isIndividualChat => !widget.isGroupChat;
  int get chatPartnerId => widget.userId ?? 0;
  List<chats.User> get groupMembers => _groupMembersMap.values.toList();
  int get groupMemberCount => _groupMembersMap.length;

  // ═══════════════════════════════════════════════════════════════════════════
  //  GROUP MEMBER MANAGMENT
  // ═══════════════════════════════════════════════════════════════════════════

  // Dynamic group member management
  final Map<int, chats.User> _groupMembersMap = {}; // userId -> User

  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-SELECT-DELETE?FORWARD STATE VARIABLES (Add to existing state variables section)
  // ═══════════════════════════════════════════════════════════════════════════

  // Multi-delete/forward functionality
  bool _isMultiSelectMode = false; // Renamed from multi-delete to multi-
  bool isForwardDialog = false;
  String? _multiSelectAction;
  Set<int> _selectedMessageIds = <int>{};
  bool _isDeletingMessages = false;
  bool _isForwardingMessages = false; // ✅ NEW: Forward loading state
  int _totalMessagesToDelete = 0;
  int _deletedMessagesCount = 0;
  int _totalMessagesToForward = 0; // ✅ NEW: Forward progress tracking
  int _forwardedMessagesCount = 0; // ✅ NEW: Forward progress tracking

  // Multi-delete/forward getters
  bool get isMultiSelectMode => _isMultiSelectMode; // Renamed
  Set<int> get selectedMessageIds => _selectedMessageIds;
  bool get hasSelectedMessages => _selectedMessageIds.isNotEmpty;
  int get selectedMessagesCount => _selectedMessageIds.length;
  bool get isDeletingMessages => _isDeletingMessages;
  bool get isForwardingMessages => _isForwardingMessages; // ✅ NEW

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGET LIFECYCLE METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  late AudioRecorder audioRecord;
  late AudioPlayer audioPlayer;
  File? _selectedVoices;

  @override
  void initState() {
    super.initState();
    audioPlayer = AudioPlayer();
    audioRecord = AudioRecorder();
    _logger.d("OneToOneChat initState called");
    debugPrint(
      'UniversalChatScreen: initState called with userId: ${widget.userId}, chatId: ${widget.chatId}, chatName: ${widget.chatName}',
    );

    _scrollController = AutoScrollController(axis: Axis.vertical);

    debugPrint('chat name: ${widget.chatName}');

    WidgetsBinding.instance.addObserver(this);

    // 🔑 Batch all provider calls into one post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint("Inside the addPostFrameCallback of initState");
      _chatProvider = Provider.of<ChatProvider>(context, listen: false);

      _chatProvider!.resetAll();
      _chatProvider!.initOfUniversal(
        context: context,
        chatId: widget.chatId,
        userId: widget.userId,
        isGroupChat: widget.isGroupChat,
      );

      if (widget.isGroupChat) {
        _loadGroupMembers();
      }

      // // 🚀 PERFORMANCE: Check cache immediately to prevent flicker
      // _chatProvider!.checkCacheAvailability(
      //   widget.chatId ?? 0,
      //   widget.userId ?? 0,
      // );

      // // Initialize the chat screen
      // _chatProvider!.initializeScreen(
      //   context: context,
      //   chatId: widget.chatId ?? 0,
      //   userId: widget.userId ?? 0,
      //   isGroupChat: widget.isGroupChat,
      // );

      // // Initialize cache for this chat
      // _chatProvider!.initializeCacheForChat(
      //   chatId: widget.chatId ?? 0,
      //   userId: widget.userId ?? 0,
      // );

      // // Try to load cached data for faster initial display
      // _chatProvider!.loadCachedDataIfAvailable();

      // // Mark screen as active
      // _chatProvider!.setScreenActive(true, widget.chatId, widget.userId);

      // Initialize search mode if enabled
      if (widget.searchMode && mounted) {
        _isSearchMode = true;
        _searchFocusNode.requestFocus();
      }

      // Handle highlight message ID for starred messages navigation
      if (widget.highlightMessageId != null && mounted) {
        // Wait for messages to load AND widgets to be built before scrolling
        Future.delayed(Duration(milliseconds: 1000), () async {
          if (mounted && !_chatProvider!.isDisposedOfChat) {
            // Wait for widget index to be populated (up to 5 attempts)
            for (int i = 0; i < 5; i++) {
              if (_messageIdToWidgetIndex.isNotEmpty) {
                debugPrint(
                  '✅ Widget index populated after ${i + 1} attempt(s), proceeding to scroll',
                );
                break;
              }
              debugPrint(
                '⏳ Widget index not populated yet, waiting... (attempt ${i + 1}/5)',
              );
              await Future.delayed(Duration(milliseconds: 300));
            }

            // Now ensure widgets are fully built before scrolling
            if (mounted && !_chatProvider!.isDisposedOfChat) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_chatProvider!.isDisposedOfChat) {
                  _scrollToMessageAndHighlight(
                    widget.highlightMessageId!,
                    _chatProvider!,
                  );
                }
              });
            }
          }
        });
      }
    });

    _scrollController.addListener(_onScroll);

    // 🚀 INSTANT UI: Block status handled via Provider Consumer
    _logger.d('Block status flag from navigation: ${widget.blockFlag}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (!_chatProvider!.isDisposedOfChat) {
      // Initialize GroupProvider for group chats
      if (isGroupChat) {
        final groupProvider = Provider.of<GroupProvider>(
          context,
          listen: false,
        );
        groupProvider.setGroupInfo(
          groupName: widget.chatName,
          groupDescription: null,
          groupIcon: widget.profilePic,
        );
      }

      // Set up new message notification subscription
      _setupNewMessageSubscription();

      // Only set screen active once, defer to post-frame
      if (!_hasInitializedFocus) {
        _hasInitializedFocus = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_chatProvider!.isDisposedOfChat) {
            _chatProvider!.setScreenActive(true, widget.chatId, widget.userId);
          }
        });
      }
    }
  }

  // @override
  // void initState() {
  //   super.initState();
  //   _logger.d("OneToOneChat initState called");
  //   debugPrint(
  //     'UniversalChatScreen: initState called with userId: ${widget.userId}, chatId: ${widget.chatId}, chatName: ${widget.chatName}',
  //   );
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     _chatProvider = Provider.of<ChatProvider>(context, listen: false);
  //   });
  //   // 🚀 INSTANT UI: Block status is now handled via Provider Consumer pattern
  //   _logger.d('Block status flag from navigation: ${widget.blockFlag}');

  //   // 🚀 PERFORMANCE: Check cache immediately to prevent loading flicker
  //   // _checkCacheAvailability();
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     _chatProvider!.checkCacheAvailability(
  //       widget.chatId ?? 0,
  //       widget.userId ?? 0,
  //     );
  //   });
  //   _scrollController = AutoScrollController(
  //     axis: Axis.vertical,
  //     // if your ListView is reversed:
  //   );
  //   debugPrint('chat name: ${widget.chatName}');

  //   WidgetsBinding.instance.addObserver(this);
  //   // _initializeScreen();

  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     _chatProvider!.initializeScreen(
  //       context: context,
  //       chatId: widget.chatId ?? 0,
  //       userId: widget.userId ?? 0,
  //       isGroupChat: widget.isGroupChat,
  //     );
  //   });
  //   // Block status is now handled via Provider Consumer pattern - no background checks needed

  //   // Initialize cache for current chat
  //   // _initializeCacheForChat();
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     _chatProvider!.initializeCacheForChat(
  //       chatId: widget.chatId ?? 0,
  //       userId: widget.userId ?? 0,
  //     );
  //   });

  //   // Try to load cached data for faster initial display (run after first frame)
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     // _loadCachedDataIfAvailable();
  //     _chatProvider!.loadCachedDataIfAvailable();
  //   });

  //   // Optional: Run cache tests (remove in production)
  //   // _runCacheTestsIfDebugMode();

  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     _chatProvider!.setScreenActive(true, widget.chatId, widget.userId);
  //   });

  //   _scrollController.addListener(_onScroll);

  //   // Initialize search mode if enabled from widget parameter
  //   if (widget.searchMode) {
  //     _isSearchMode = true;
  //     // Focus search field after initial build
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       if (mounted) {
  //         _searchFocusNode.requestFocus();
  //       }
  //     });
  //   }
  // }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   _chatProvider = Provider.of<ChatProvider>(context, listen: false);

  //   if (!_chatProvider!.isDisposedOfChat) {
  //     // _chatProvider = Provider.of<ChatProvider>(context, listen: false);

  //     // Initialize GroupProvider for group chats and set initial group data
  //     if (isGroupChat) {
  //       final groupProvider = Provider.of<GroupProvider>(
  //         context,
  //         listen: false,
  //       );
  //       groupProvider.setGroupInfo(
  //         groupName: widget.chatName,
  //         groupDescription: null,
  //         groupIcon: widget.profilePic,
  //       );
  //     }

  //     // Set up new message notification subscription
  //     _setupNewMessageSubscription();

  //     if (!_hasInitializedFocus && _chatProvider != null) {
  //       _hasInitializedFocus = true;
  //       // Defer the state change to avoid setState during build
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         if (!_chatProvider!.isDisposedOfChat) {
  //           _chatProvider!.setScreenActive(true, widget.chatId, widget.userId);
  //         }
  //       });
  //     }

  //     // Block status is now handled via Provider Consumer pattern - no manual checks needed
  //   }
  // }

  @override
  void didUpdateWidget(UniversalChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.chatId != widget.chatId ||
        oldWidget.userId != widget.userId) {
      _logger.d("Chat changed, updating focus");
      _chatProvider!.setScreenActive(true, widget.chatId, widget.userId);
      // Block status is now handled via Provider Consumer pattern
    }

    if (!_chatProvider!.isDisposedOfChat &&
        oldWidget.chatId != widget.chatId &&
        widget.chatId != null &&
        widget.chatId! > 0) {
      _logger.d("Chat ID changed, reinitializing chat");
      _chatProvider!.setIsInitialized(false);
      // Reset cached data flag for new chat
      _chatProvider!.setHasCachedData(false);
      // 🚀 PERFORMANCE: Check cache for new chat to prevent loading flicker
      _checkCacheAvailability();
      _initializeChat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _logger.d('App lifecycle state changed: $state');

    if (_chatProvider != null) {
      switch (state) {
        case AppLifecycleState.resumed:
          _chatProvider!.setAppForegroundState(true);
          Future.delayed(Duration(milliseconds: 500), () {
            if (_chatProvider!.isScreenActive &&
                !_chatProvider!.isDisposedOfChat &&
                mounted) {
              _chatProvider!.setScreenActive(
                true,
                widget.chatId,
                widget.userId,
              );
            }
          });
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          _chatProvider!.setAppForegroundState(false);
          break;
      }
    }
  }

  @override
  void dispose() {
    _logger.d("UniversalChatScreen dispose called");
    audioRecord.dispose();
    audioPlayer.dispose();
    // Cancel timers/subscriptions early
    _typingTimer?.cancel();
    _scrollDebounceTimer?.cancel();
    _paginationDebounceTimer?.cancel();
    _newMessageSubscription?.cancel();

    // Dispose controllers/focus nodes
    _messageController.dispose();

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();

    // Provider updates last
    if (_chatProvider != null) {
      try {
        _chatProvider!.setChatScreenActive(
          widget.chatId ?? 0,
          widget.userId ?? 0,
          isActive: false,
        );
        _chatProvider!.setIsDisposedOfChat(true);
        _chatProvider!.setCurrentChat(0, 0);
      } catch (e) {
        _logger.e("Error resetting chat in dispose: $e");
      }
    }

    WidgetsBinding.instance.removeObserver(this);
    _messageFocusNode.dispose();

    super.dispose();
  }

  // @override
  // void dispose() {
  //   _logger.d("UniversalChatScreen dispose called");

  //   // Clear multi-delete state
  //   _selectedMessageIds.clear();

  //   if (_chatProvider != null) {
  //     // Defer notification until after dispose to avoid widget tree lock
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       _chatProvider?.setChatScreenActive(
  //         widget.chatId ?? 0,
  //         widget.userId ?? 0,
  //         isActive: false,
  //       );
  //     });
  //   }

  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     _chatProvider!.setIsDisposedOfChat(true);
  //   });

  //   WidgetsBinding.instance.removeObserver(this);
  //   _messageController.dispose();
  //   _typingTimer?.cancel();
  //   _scrollController.removeListener(_onScroll);
  //   _scrollController.dispose();
  //   _scrollDebounceTimer?.cancel();
  //   _messageFocusNode.dispose();
  //   _searchController.dispose();
  //   _searchFocusNode.dispose();
  //   _paginationDebounceTimer?.cancel();
  //   _newMessageSubscription?.cancel();

  //   if (_chatProvider != null) {
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       try {
  //         if (_chatProvider != null) {
  //           _chatProvider!.setCurrentChat(0, 0);
  //         }
  //       } catch (e) {
  //         _logger.e("Error resetting chat in post-dispose: $e");
  //       }
  //     });
  //   }

  //   super.dispose();
  // }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN BUILD METHOD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // Defensive check: if provider is not initialized yet or is disposed, show loading
    if (_chatProvider == null || _chatProvider!.isDisposedOfChat) {
      return Scaffold(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        body: Center(child: commonLoading()),
      );
    }

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (_isMultiSelectMode) {
          _exitMultiSelectMode();
          return false;
        }

        _logger.d("🔙 System back button pressed - clearing chat focus");
        _chatProvider!.setScreenActive(false, widget.chatId, widget.userId);
        await Future.delayed(Duration(milliseconds: 100));

        // Handle navigation source with switch cases
        return await _handleBackNavigation();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
          appBar: _buildAppBar(),
          body: _buildBody(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI BUILDING METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  PreferredSize _buildAppBar() {
    return PreferredSize(
      preferredSize: Size.fromHeight(SizeConfig.sizedBoxHeight(65)),
      child: AppBar(
        scrolledUnderElevation: 0,
        leadingWidth: 50,
        // Hide back arrow when search mode is active
        leading:
            _isSearchMode
                ? null
                : IconButton(
                  icon: SvgPicture.asset(
                    AppDirectionality.appDirectionIcon.arrowForBack,
                    height: 30,
                    colorFilter: ColorFilter.mode(
                      AppThemeManage.appTheme.darkWhiteColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed:
                      _isMultiSelectMode ? _exitMultiSelectMode : _navigateBack,
                ),
        flexibleSpace: flexibleSpace(), //flexibleSpaceSplash(),
        systemOverlayStyle: systemUI(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 2,
        title: _buildAppBarTitle(),
        actions:
            _isMultiSelectMode
                ? _buildMultiSelectActions()
                : _isSearchMode
                ? [] // Hide all actions when in search mode
                : [
                  // Replace CallWidget with socket-based call buttons
                  // CRITICAL FIX: Pass userId as fallback when chatId is 0/null
                  // This enables calls even when no chat history exists
                  ChatCallButtons(
                    chatId: widget.chatId ?? 0,
                    chatName: widget.chatName,
                    profilePic: widget.profilePic,
                    userId: widget.userId, // Fallback for new chats
                  ),
                  SizedBox(width: SizeConfig.width(5)),
                  // Add PopupMenuButton for more options
                  // if (widget.userId != null) ...[
                  //   // Individual chat popup menu
                  //   Consumer<ChatProvider>(
                  //     builder: (context, chatProvider, child) {
                  //       // Get block scenario using proper logic
                  //       final blockScenario = chatProvider.getBlockScenario(
                  //         widget.chatId,
                  //         widget.userId,
                  //       );

                  //       // Determine menu options based on block scenario
                  //       final canShowBlockOption =
                  //           blockScenario != 'user_blocked_by_other';
                  //       final showUnblockOption =
                  //           blockScenario == 'user_blocked_other' ||
                  //           blockScenario == 'mutual_block';
                  //       final blockOptionText =
                  //           showUnblockOption
                  //               ? AppString.blockUserStrings.unbolockUser
                  //               : AppString
                  //                   .blockUserStrings
                  //                   .blockUser; //'Unblock User' : 'Block User';

                  //       return PopupMenuButton<String>(
                  //         color: AppThemeManage.appTheme.darkGreyColor,
                  //         menuPadding: EdgeInsetsGeometry.zero,
                  //         padding: EdgeInsetsGeometry.zero,
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadiusGeometry.circular(7),
                  //         ),
                  //         constraints: BoxConstraints(
                  //           minWidth: SizeConfig.sizedBoxWidth(150),
                  //         ),
                  //         borderRadius: BorderRadius.circular(7),
                  //         icon: Icon(
                  //           Icons.more_vert,
                  //           color: AppThemeManage.appTheme.darkWhiteColor,
                  //         ),
                  //         onSelected: (value) {
                  //           switch (value) {
                  //             // case 'profile':
                  //             //   _navigateToUserProfile();
                  //             //   break;
                  //             case 'block':
                  //             case 'unblock':
                  //               _handleBlockUnblock();
                  //               break;
                  //             case 'clear_chat':
                  //               _handleClearChat();
                  //               break;
                  //             case 'report':
                  //               _handleReportUser();
                  //               break;
                  //             // case 'starred_messages':
                  //             //   _handleStarredMessages();
                  //             //   break;
                  //             // case 'chat_media':
                  //             //   _handleChatMedia();
                  //             //   break;
                  //           }
                  //         },
                  //         itemBuilder:
                  //             (context) => [
                  //               // PopupMenuItem(
                  //               //   height: 40,
                  //               //   value: 'profile',
                  //               //   textStyle: AppTypography.innerText14(context),
                  //               //   child: Row(
                  //               //     children: [
                  //               //       SizedBox(width: 8),
                  //               //       Text('View Profile'),
                  //               //     ],
                  //               //   ),
                  //               // ),
                  //               // PopupMenuItem(
                  //               //   height: 1,
                  //               //   padding: EdgeInsets.zero,
                  //               //   child: Divider(
                  //               //     height: 1,
                  //               //     thickness: 1,
                  //               //     color: AppColors.strokeColor.cECECEC,
                  //               //   ),
                  //               // ),
                  //               // Show block/unblock option based on block scenario
                  //               if (canShowBlockOption)
                  //                 PopupMenuItem(
                  //                   height: 40,
                  //                   value:
                  //                       showUnblockOption ? 'unblock' : 'block',
                  //                   textStyle: AppTypography.innerText14(
                  //                     context,
                  //                   ),
                  //                   child: Row(
                  //                     children: [
                  //                       SizedBox(width: 8),
                  //                       Text(
                  //                         blockOptionText,
                  //                         style: AppTypography.innerText14(
                  //                           context,
                  //                         ),
                  //                       ),
                  //                     ],
                  //                   ),
                  //                 )
                  //               else
                  //                 PopupMenuItem(
                  //                   value: 'blocked_by_user',
                  //                   enabled: false,
                  //                   child: Row(
                  //                     children: [
                  //                       Icon(Icons.block, color: Colors.grey),
                  //                       SizedBox(width: 8),
                  //                       Text(
                  //                         AppString
                  //                             .blockUserStrings
                  //                             .blockedByUser, //'Blocked by User',
                  //                         style: TextStyle(color: Colors.grey),
                  //                       ),
                  //                     ],
                  //                   ),
                  //                 ),
                  //               PopupMenuItem(
                  //                 height: 1,
                  //                 padding: EdgeInsets.zero,
                  //                 child: Divider(
                  //                   height: 1,
                  //                   thickness: 1,
                  //                   color: AppThemeManage.appTheme.borderColor,
                  //                 ),
                  //               ),
                  //               PopupMenuItem(
                  //                 height: 40,
                  //                 value: 'clear_chat',
                  //                 textStyle: AppTypography.innerText14(context),
                  //                 child: Row(
                  //                   children: [
                  //                     SizedBox(width: 8),
                  //                     Text(
                  //                       AppString
                  //                           .homeScreenString
                  //                           .clearChat, //'Clear Chat',
                  //                       style: AppTypography.innerText14(
                  //                         context,
                  //                       ),
                  //                     ),
                  //                   ],
                  //                 ),
                  //               ),
                  //               PopupMenuItem(
                  //                 height: 1,
                  //                 padding: EdgeInsets.zero,
                  //                 child: Divider(
                  //                   height: 1,
                  //                   thickness: 1,
                  //                   color: AppThemeManage.appTheme.borderColor,
                  //                 ),
                  //               ),
                  //               PopupMenuItem(
                  //                 height: 40,
                  //                 value: 'report',
                  //                 textStyle: AppTypography.innerText14(context),
                  //                 child: Row(
                  //                   children: [
                  //                     SizedBox(width: 8),
                  //                     Text(
                  //                       AppString.reportUser,
                  //                       style: AppTypography.innerText14(
                  //                         context,
                  //                       ),
                  //                     ),
                  //                   ],
                  //                 ),
                  //               ),
                  //               // PopupMenuItem(
                  //               //   value: 'starred_messages',
                  //               //   child: Row(
                  //               //     children: [
                  //               //       Icon(Icons.star, color: Colors.amber),
                  //               //       SizedBox(width: 8),
                  //               //       Text('Starred Messages'),
                  //               //     ],
                  //               //   ),
                  //               // ),
                  //               // PopupMenuItem(
                  //               //   value: 'chat_media',
                  //               //   child: Row(
                  //               //     children: [
                  //               //       Icon(
                  //               //         Icons.perm_media,
                  //               //         color: Colors.purple,
                  //               //       ),
                  //               //       SizedBox(width: 8),
                  //               //       Text('Media'),
                  //               //     ],
                  //               //   ),
                  //               // ),
                  //             ],
                  //       );
                  //     },
                  //   ),
                  // ] else if (isGroupChat) ...[
                  //   // Group chat popup menu
                  //   PopupMenuButton<String>(
                  //     shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadiusGeometry.circular(7),
                  //     ),
                  //     menuPadding: EdgeInsetsGeometry.zero,
                  //     color: AppThemeManage.appTheme.darkGreyColor,
                  //     padding: EdgeInsetsGeometry.zero,
                  //     borderRadius: BorderRadius.circular(7),
                  //     icon: Icon(
                  //       Icons.more_vert,
                  //       color: AppThemeManage.appTheme.darkWhiteColor,
                  //     ),
                  //     onSelected: (value) {
                  //       switch (value) {
                  //         // case 'group_info':
                  //         //   _navigateToGroupInfo();
                  //         //   break;
                  //         case 'clear_chat':
                  //           _handleClearChat();
                  //           break;
                  //         case 'report':
                  //           _handleReportUser();
                  //           break;
                  //         // case 'starred_messages':
                  //         //   _handleStarredMessages();
                  //         //   break;
                  //         // case 'chat_media':
                  //         //   _handleChatMedia();
                  //         //   break;
                  //       }
                  //     },
                  //     itemBuilder:
                  //         (context) => [
                  //           // PopupMenuItem(
                  //           //   value: 'group_info',
                  //           //   child: Row(
                  //           //     children: [
                  //           //       Icon(Icons.info, color: Colors.blue),
                  //           //       SizedBox(width: 8),
                  //           //       Text('Group Info'),
                  //           //     ],
                  //           //   ),
                  //           // ),
                  //           PopupMenuItem(
                  //             height: 40,
                  //             value: 'clear_chat',
                  //             textStyle: AppTypography.innerText14(context),
                  //             child: Row(
                  //               children: [
                  //                 SizedBox(width: 8),
                  //                 Text(
                  //                   AppString.homeScreenString.clearChat,
                  //                   style: AppTypography.innerText14(context),
                  //                 ),
                  //               ],
                  //             ),
                  //           ),
                  //           PopupMenuItem(
                  //             height: 1,
                  //             padding: EdgeInsets.zero,
                  //             child: Divider(
                  //               height: 1,
                  //               thickness: 1,
                  //               color: AppThemeManage.appTheme.borderColor,
                  //             ),
                  //           ),
                  //           // PopupMenuItem(
                  //           //   value: 'starred_messages',
                  //           //   child: Row(
                  //           //     children: [
                  //           //       Icon(Icons.star, color: Colors.amber),
                  //           //       SizedBox(width: 8),
                  //           //       Text('Starred Messages'),
                  //           //     ],
                  //           //   ),
                  //           // ),
                  //           // PopupMenuItem(
                  //           //   value: 'chat_media',
                  //           //   child: Row(
                  //           //     children: [
                  //           //       Icon(Icons.perm_media, color: Colors.purple),
                  //           //       SizedBox(width: 8),
                  //           //       Text('Media'),
                  //           //     ],
                  //           //   ),
                  //           // ),
                  //           PopupMenuItem(
                  //             height: 40,
                  //             value: 'report',
                  //             textStyle: AppTypography.innerText14(context),
                  //             child: Row(
                  //               children: [
                  //                 SizedBox(width: 8),
                  //                 Text(
                  //                   AppString.reportUser,
                  //                   style: AppTypography.innerText14(context),
                  //                 ),
                  //               ],
                  //             ),
                  //           ),
                  //         ],
                  //   ),
                  // ],
                ],
      ),
    );
  }

  /// Safely show SnackBar with proper error handling
  // ignore: unused_element
  void _safeShowSnackBar(SnackBar snackBar) {
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } catch (e) {
      // If context is deactivated, just log instead of crashing
      debugPrint(
        'UniversalChatScreen: Cannot show snackbar - context deactivated',
      );
    }
  }

  List<Widget> _buildMultiSelectActions() {
    return [
      // // Select All button
      // if (hasSelectedMessages && !_isDeletingMessages && !_isForwardingMessages)
      //   IconButton(
      //     icon: Icon(Icons.select_all, color: Colors.black),
      //     onPressed: _selectAllVisibleMessages,
      //     tooltip: 'Select All',
      //   ),

      // // Forward button
      // if (hasSelectedMessages && !_isDeletingMessages && !_isForwardingMessages)
      //   IconButton(
      //     icon: Icon(Icons.forward, color: Colors.black),
      //     onPressed: _showForwardChatSelectionDialog,
      //     tooltip: 'Forward Selected',
      //   ),

      // Delete button
      // if (hasSelectedMessages && !_isDeletingMessages && !_isForwardingMessages)
      //   IconButton(
      //     icon: Icon(Icons.delete, color: Colors.redAccent),
      //     onPressed: _showDeleteSelectedMessagesDialog,
      //     tooltip: 'Delete Selected',
      //   ),

      // Cancel button
      if (!_isDeletingMessages && !_isForwardingMessages)
        TextButton(
          onPressed: _exitMultiSelectMode,
          child: Text(
            AppString.cancel,
            style: AppTypography.innerText16(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),

      SizedBox(width: 8),
    ];
  }

  Widget _buildBody() {
    return GestureDetector(
      onTap: () {
        if (mounted && !_chatProvider!.isDisposedOfChat) {
          setState(() {
            _isAttachmentMenuOpen = false;
          });
          FocusScope.of(context).unfocus();
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              // Only show pinned messages when not in search mode
              if (!_isSearchMode) _buildPinnedMessagesWidget(),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      opacity: 0.02,
                      fit: BoxFit.cover,
                      image: AssetImage(AppAssets.chatImage.chatBackImage2),
                    ),
                  ),
                  child:
                      _isSearchMode
                          ? _buildSearchContent()
                          : _buildChatContent(),
                ),
              ),
            ],
          ),
          // Only show input field when not in search mode
          if (!_isSearchMode) _buildInputField(),
          _buildAttachmentMenu(),
          if (_isClearingChat) _buildClearChatLoadingOverlay(),
          if (_showNewMessageIndicator) _buildNewMessageIndicator(),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    if (_isSearchMode) {
      return _buildSearchField();
    }

    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        if (isGroupChat) {
          return _buildGroupChatTitle(chatProvider);
        } else {
          return _buildIndividualChatTitle(chatProvider);
        }
      },
    );
  }

  Widget _buildSearchField() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColors.white.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.3)),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: AppTypography.mediumText(
                context,
              ).copyWith(color: AppColors.textColor.textDarkGray),
              decoration: InputDecoration(
                hintText: "${AppString.searchmessages}...",
                hintStyle: AppTypography.mediumText(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textColor.textGreyColor,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onChanged: (value) {
                _searchQuery = value;
                if (value.isNotEmpty && value.length >= 2) {
                  _performSearch(value);
                } else {
                  setState(() {
                    _searchResults.clear();
                  });
                }
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _performSearch(value);
                }
              },
            ),
          ),
        ),
        SizedBox(width: 12),
        GestureDetector(
          onTap: _exitSearchMode,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              AppString.cancel,
              style: AppTypography.mediumText(
                context,
              ).copyWith(color: AppColors.appPriSecColor.primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchContent() {
    // Always show search results when in search mode, including empty states
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            commonLoading(),
            SizedBox(height: 16),
            Text(
              "${AppString.searchingmessages}...",
              style: AppTypography.mediumText(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textColor.textGreyColor,
            ),
            SizedBox(height: 16),
            Text(
              AppString.nomessagesfound,
              style: AppTypography.h5(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
            ),
            SizedBox(height: 8),
            Text(
              AppString.tryadifferentsearchterm,
              style: AppTypography.mediumText(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: AppColors.textColor.textGreyColor,
            ),
            SizedBox(height: 16),
            Text(
              AppString.searchmessages,
              style: AppTypography.h5(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
            ),
            SizedBox(height: 8),
            Text(
              AppString.typeatleastcharacterstosearch,
              style: AppTypography.mediumText(
                context,
              ).copyWith(color: AppColors.textColor.textGreyColor),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search results count header with divider
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgColor.bg4Color,
            border: Border(
              bottom: BorderSide(
                color: AppColors.shadowColor.cE9E9E9,
                width: 0.5,
              ),
            ),
          ),
          child: Text(
            "${_searchResults.length} results found",
            style: AppTypography.mediumText(context).copyWith(
              color: AppColors.textColor.textGreyColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Add some spacing
        SizedBox(height: 8),
        // Search results list
        Expanded(
          child: ListView.separated(
            itemCount: _searchResults.length,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            separatorBuilder:
                (context, index) => Divider(
                  color: AppColors.shadowColor.cE9E9E9,
                  height: 1,
                  thickness: 0.5,
                  indent: 60, // Align with message content (after avatar)
                ),
            itemBuilder: (context, index) {
              return _buildSearchResultItem(_searchResults[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> message) {
    final messageContent = message['message_content'] ?? '';
    final messageType = message['message_type'] ?? 'text';
    final createdAt = message['createdAt'] ?? '';
    final user = message['User'] ?? {};
    final fullName = user['full_name'] ?? 'Unknown User';
    final profilePic = user['profile_pic'] ?? '';

    // Check if this message is from the current user
    final senderId = message['sender_id'];
    final currentUserIdInt =
        _chatProvider!.currentUserId != null
            ? int.tryParse(_chatProvider!.currentUserId!)
            : null;
    final isCurrentUser =
        currentUserIdInt != null && senderId == currentUserIdInt;
    final displayName = isCurrentUser ? 'You' : fullName;

    return GestureDetector(
      onLongPress: () => _handleSearchResultLongPress(message),
      onTap: () => _handleSearchResultTap(message),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            _buildUserAvatar(
              profilePic: profilePic,
              userName: fullName,
              userId: senderId ?? 0,
              radius: 20,
            ),
            SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: AppTypography.mediumText(context).copyWith(
                            color: AppColors.textColor.textBlackColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _formatSearchResultTime(createdAt),
                        style: AppTypography.smallText(context).copyWith(
                          color: AppColors.textColor.textGreyColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  // Message content with better styling
                  if (messageType == 'text')
                    Text(
                      messageContent,
                      style: AppTypography.mediumText(context).copyWith(
                        color: AppColors.textColor.textBlackColor,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.shadowColor.cE9E9E9.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getMessageTypeIcon(messageType),
                            size: 14,
                            color:
                                isCurrentUser
                                    ? AppThemeManage.appTheme.textGreyWhite
                                    : AppColors.textColor.textGreyColor,
                          ),
                          SizedBox(width: 6),
                          Text(
                            _getMessageTypeLabel(messageType),
                            style: AppTypography.smallText(context).copyWith(
                              color:
                                  isCurrentUser
                                      ? AppThemeManage.appTheme.textGreyWhite
                                      : AppColors.textColor.textGreyColor,
                            ),
                          ),
                        ],
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

  String _formatSearchResultTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) {
        return "${diff.inDays}d ago";
      } else if (diff.inHours > 0) {
        return "${diff.inHours}h ago";
      } else if (diff.inMinutes > 0) {
        return "${diff.inMinutes}m ago";
      } else {
        return "Just now";
      }
    } catch (e) {
      return "";
    }
  }

  IconData _getMessageTypeIcon(String messageType) {
    switch (messageType.toLowerCase()) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      case 'document':
        return Icons.description;
      case 'location':
        return Icons.location_on;
      default:
        return Icons.message;
    }
  }

  String _getMessageTypeLabel(String messageType) {
    switch (messageType.toLowerCase()) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Audio';
      case 'document':
        return 'Document';
      case 'location':
        return 'Location';
      default:
        return 'Message';
    }
  }

  Widget _buildGroupChatTitle(ChatProvider chatProvider) {
    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        final onlineCount = _getOnlineGroupMembersCount(chatProvider);
        final typingUsers = _getTypingUsersInGroup();

        // Use GroupProvider member count if available, otherwise fallback to _groupMembersMap
        final memberCount =
            groupProvider.members.isNotEmpty
                ? groupProvider.members.length
                : groupMemberCount;

        // Use updated group name from GroupProvider if available, otherwise fallback to widget.chatName
        final groupName = groupProvider.groupName ?? widget.chatName;

        return ChatAppbarTitle(
          profile: groupProvider.groupIcon ?? widget.profilePic,
          title: groupName,
          statusWidget: GroupChatStatusWidget(
            memberCount: memberCount,
            onlineCount: onlineCount,
            typingUsers: typingUsers,
          ),
          onTap: () {
            _navigateToGroupInfo();
          },
        );
      },
    );
  }

  Widget _buildIndividualChatTitle(ChatProvider chatProvider) {
    final isOnline = _isUserOnlineFromChatListOrApi(chatProvider);
    bool isTyping = false;
    final currentChatId = chatProvider.currentChatData.chatId ?? 0;

    if (chatProvider.typingData.typing == true) {
      isTyping = chatProvider.isUserTypingInChat(currentChatId);
    }

    String? lastSeenTime = _getLastSeenTimeFromChatListOrApi(chatProvider);

    // Check if any blocking scenario is active (hide typing/online status if blocked)
    final blockScenario = chatProvider.getBlockScenario(
      widget.chatId,
      widget.userId,
    );
    final isAnyBlockActive = blockScenario != 'none';

    return ChatAppbarTitle(
      profile: widget.profilePic,
      title: _getDisplayName(chatProvider),
      onlineStatus: isAnyBlockActive ? "" : null,
      statusWidget:
          isAnyBlockActive
              ? null
              : LiveLastSeenWidget(
                timestamp: lastSeenTime,
                isOnline: isOnline,
                isTyping: isTyping,
              ),
      onTap: () {
        // Navigator.pushNamed(context, AppRoutes.chatProfile);
        _navigateToUserProfile();
      },
    );
  }

  Widget _buildChatContent() {
    if (_chatProvider!.hasError) return _buildErrorState();
    // ✅ FIX: Show loading instead of error while user ID is being loaded
    if (_chatProvider!.currentUserId == null) {
      return _chatProvider!.isLoadingCurrentUser
          ? _buildLoadingIndicator()
          : _buildErrorState();
    }

    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        // Debug flags for easier troubleshooting
        final debugInfo = {
          'hasMessages': chatProvider.chatsData.records?.isNotEmpty ?? false,
          'isLoadingCurrentUser': _chatProvider!.isLoadingCurrentUser,
          'isInitializing': _chatProvider!.isInitializingOfChat,
          'isInitialized': _chatProvider!.isInitialized,
          'isChatLoading': chatProvider.isChatLoading,
          'hasCachedData': chatProvider.hasCachedData,
          'recordsCount': chatProvider.chatsData.records?.length ?? 0,
        };

        // Log debug info when in debug mode
        if (kDebugMode) {
          _logger.d('💬 Chat Content Debug: $debugInfo');
        }

        final messages = chatProvider.chatsData.records ?? [];
        final hasMessages = messages.isNotEmpty;

        // Update cache flag when messages are loaded from any source
        // Use WidgetsBinding to avoid setState during build
        if (hasMessages && !chatProvider.hasCachedData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !chatProvider.hasCachedData) {
              setState(() {
                chatProvider.setHasCachedData(true);
              });
            }
          });
        }

        // PRIORITY 1: Show messages if available (highest priority)
        if (hasMessages) {
          if (kDebugMode) {
            _logger.d('✅ Showing ${messages.length} messages');
          }
          return RefreshIndicator(
            color: AppColors.appPriSecColor.primaryColor,
            onRefresh: () async {
              if (!_chatProvider!.isDisposedOfChat && mounted) {
                try {
                  await _refreshChatMessages();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_chatProvider!.isDisposedOfChat && mounted) {
                      _scrollToBottom(animated: false);
                    }
                  });
                } catch (e) {
                  _logger.e("RefreshIndicator error: $e");
                }
              }
            },
            child: _buildMessagesList(),
          );
        }

        // PRIORITY 2: Show loading states only when no messages available
        if (_chatProvider!.isLoadingCurrentUser) {
          if (kDebugMode) {
            _logger.d('⏳ Loading current user');
          }
          return _buildLoadingIndicator();
        }

        if (_chatProvider!.isInitializingOfChat) {
          if (kDebugMode) {
            _logger.d('🚀 Initializing chat');
          }
          return _buildLoadingIndicator();
        }

        if (chatProvider.isChatLoading) {
          if (kDebugMode) {
            _logger.d('📥 Chat provider loading');
          }
          return _buildLoadingIndicator();
        }

        // PRIORITY 3: Show empty state only when everything is done and no messages
        // ✅ FIX: Also check provider messages to prevent false empty states
        if (_chatProvider!.isInitialized &&
            !_chatProvider!.isInitializingOfChat &&
            !chatProvider.isChatLoading &&
            !chatProvider.hasCachedData &&
            messages.isEmpty) {
          if (kDebugMode) {
            _logger.d('📭 Showing empty state');
          }
          return _buildEmptyState();
        }

        // FALLBACK: Handle edge cases more gracefully
        if (kDebugMode) {
          _logger.w(
            '⚠️ Fallback loading state reached - this might indicate an edge case',
          );
          _logger.d(
            'State debug - initialized: ${_chatProvider!.isInitialized}, initializing: ${_chatProvider!.isInitializingOfChat}, chatLoading: ${chatProvider.isChatLoading}, hasCached: ${chatProvider.hasCachedData}',
          );
        }

        // Check if we're in a transient state and should show empty instead of loading
        if (_chatProvider!.isInitialized &&
            !_chatProvider!.isInitializingOfChat &&
            !chatProvider.isChatLoading) {
          // Check if provider actually has messages but local state is out of sync
          final providerMessages = chatProvider.chatsData.records ?? [];
          if (providerMessages.isNotEmpty) {
            // Provider has messages but we're showing fallback - sync the cache flag
            _logger.d(
              '🔄 State sync issue detected - provider has messages, updating cache flag',
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  chatProvider.setHasCachedData(true);
                });
              }
            });
            // Return the messages list immediately
            return RefreshIndicator(
              color: AppColors.appPriSecColor.primaryColor,
              onRefresh: () async {
                if (!_chatProvider!.isDisposedOfChat && mounted) {
                  try {
                    await _refreshChatMessages();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_chatProvider!.isDisposedOfChat && mounted) {
                        _scrollToBottom(animated: false);
                      }
                    });
                  } catch (e) {
                    _logger.e("RefreshIndicator error: $e");
                  }
                }
              },
              child: _buildMessagesList(),
            );
          }
          // This is likely a case where messages were cleared but cache flag wasn't reset
          _logger.d(
            '🔄 Transient state detected - showing empty state instead of loader',
          );
          return _buildEmptyState();
        }

        return _buildLoadingIndicator();
      },
    );
  }

  // Widget _buildMessagesList(
  //   List<chats.Records> messages,
  //   ChatProvider chatProvider,
  // ) {
  //   // Update group members from messages
  //   if (isGroupChat) {
  //     _updateGroupMembersFromMessages(messages);
  //   }

  //   final totalItemCount =
  //       messages.length + (chatProvider.hasMoreMessages ? 1 : 0);

  //   return ListView.builder(
  //     key: PageStorageKey('universal_chat_list_${widget.chatId}'),
  //     controller: _scrollController,
  //     reverse: true,
  //     physics: const AlwaysScrollableScrollPhysics(),
  //     padding: const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 120),
  //     cacheExtent: 1000,
  //     itemCount: totalItemCount,
  //     itemBuilder: (context, index) {
  //       if (chatProvider.hasMoreMessages && index == messages.length) {
  //         return _buildPaginationLoader();
  //       }

  //       final message = messages[index];
  //       return RepaintBoundary(
  //         child: _buildMessageBubble(message, index, messages),
  //       );
  //     },
  //   );
  // }

  Widget _buildMessagesList() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final messages = chatProvider.chatsData.records;

        if (messages == null || messages.isEmpty) {
          return Center(child: Text(AppString.nomessagesyet));
        }

        // Update group members from messages
        if (isGroupChat) {
          _updateGroupMembersFromMessages(messages);
        }

        // Get grouped messages
        final groupedMessages = chatProvider.groupedMessages;

        if (groupedMessages.isEmpty) {
          return Center(child: Text(AppString.nomessagesyet));
        }

        // Build grouped widgets with proper indexing
        final groupedWidgets = <Widget>[];
        int widgetIndex = 0;

        // Create a mapping of messageId to widget index for AutoScrollTag
        final messageIdToWidgetIndex = <int, int>{};

        // Use custom logic to build grouped widgets with proper indices
        final sortedKeys =
            groupedMessages.keys.toList()..sort(
              (a, b) => ChatDateGrouper.sortDateKeysForReversedList(a, b),
            );

        for (final dateKey in sortedKeys) {
          final messages = groupedMessages[dateKey]!;

          // Add messages for this date (in reverse order within the group)
          for (int i = messages.length - 1; i >= 0; i--) {
            final message = messages[i];
            messageIdToWidgetIndex[message.messageId!] = widgetIndex;
            final messageWidget = _buildMessageBubble(
              message,
              widgetIndex,
              messages,
            );
            groupedWidgets.add(messageWidget);
            widgetIndex++;
          }

          // Add date header
          groupedWidgets.add(ChatDateGrouper.buildDateHeader(dateKey));
          widgetIndex++;
        }

        // Store the mapping for use in scrollToIndex
        _messageIdToWidgetIndex = messageIdToWidgetIndex;

        // Add pagination loader if needed
        final totalItemCount =
            groupedWidgets.length + (chatProvider.hasMoreMessages ? 1 : 0);

        return ListView.builder(
          key: PageStorageKey('universal_chat_list_${widget.chatId}'),
          controller: _scrollController,
          reverse: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
            left: 10,
            right: 10,
            top: 10,
            bottom: 120,
          ),
          cacheExtent: 1000,
          itemCount: totalItemCount,
          itemBuilder: (context, index) {
            // Show pagination loader at the end (top of reversed list)
            if (chatProvider.hasMoreMessages &&
                index == groupedWidgets.length) {
              return _buildPaginationLoader();
            }

            return RepaintBoundary(child: groupedWidgets[index]);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(
    chats.Records chat,
    int index,
    List<chats.Records> messages,
  ) {
    final messageId = chat.messageId!;
    final key = _messageKeys.putIfAbsent(messageId, () => GlobalKey());

    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final isSentByMe =
            chat.senderId.toString() == _chatProvider!.currentUserId;
        final isPinned = chat.pinned == true;
        final isStarred = chatProvider.isMessageStarred(messageId);
        final isHighlighted = chatProvider.highlightedMessageId == messageId;
        final isSelected = _selectedMessageIds.contains(messageId);

        final showSenderInfo =
            isGroupChat &&
            !isSentByMe &&
            _shouldShowSenderInfo(chat, index, messages);

        return AutoScrollTag(
          key: ValueKey(messageId),
          controller: _scrollController,
          index: index,
          child: _buildSelectableMessageContainer(
            chat: chat,
            key: key,
            isSentByMe: isSentByMe,
            isPinned: isPinned,
            isStarred: isStarred,
            isHighlighted: isHighlighted,
            isSelected: isSelected,
            showSenderInfo: showSenderInfo,
            chatProvider: chatProvider,
          ),
        );
      },
    );
  }

  Widget _buildSelectableMessageContainer({
    required chats.Records chat,
    required GlobalKey key,
    required bool isSentByMe,
    required bool isPinned,
    required bool isStarred,
    required bool isHighlighted,
    required bool isSelected,
    required bool showSenderInfo,
    required ChatProvider chatProvider,
  }) {
    final messageId = chat.messageId!;
    final isSelectableForMultiSelect = _isMessageSelectableForMultiSelect(chat);

    // Determine container decoration
    BoxDecoration? containerDecoration;
    EdgeInsets containerPadding = EdgeInsets.zero;
    Duration animationDuration = Duration.zero;

    // if (isSelected) {
    //   // Selection takes priority over highlight
    //   containerDecoration = BoxDecoration(
    //     color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.15),
    //     borderRadius: BorderRadius.circular(16),
    //     border: Border.all(
    //       color: AppColors.appPriSecColor.primaryColor,
    //       width: 2.0,
    //     ),
    //   );
    //   containerPadding = EdgeInsets.all(8);
    //   animationDuration = Duration(milliseconds: 200);
    // } else
    if (isHighlighted) {
      containerDecoration = BoxDecoration(
        color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.appPriSecColor.primaryColor,
          width: 2.5,
        ),
      );
      containerPadding = EdgeInsets.all(12);
      animationDuration = Duration(milliseconds: 600);
    }

    Widget messageContainer = Column(
      crossAxisAlignment:
          isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // if (isStarred) _buildStarIndicator(isSentByMe),
        // if (isPinned) _buildPinIndicator(isSentByMe, isHighlighted),
        if (showSenderInfo) _buildGroupSenderInfo(chat),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              isSentByMe
                  ? (_isMultiSelectMode && isSelectableForMultiSelect)
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.end
                  : MainAxisAlignment.start,
          children: [
            // Selection indicator for messages from others
            if (_isMultiSelectMode && isSelectableForMultiSelect)
              _buildSelectionIndicator(isSelected, messageId),

            // Non-selectable indicator for system messages
            if (_isMultiSelectMode && !isSelectableForMultiSelect)
              // _buildNonSelectableIndicator(),
              SizedBox.shrink(),

            if (_isMultiSelectMode && !isSentByMe) SizedBox(width: 8),

            // Message content
            Flexible(
              child: KeyedSubtree(
                key: key,
                child: MessageContentWidget(
                  chat: chat,
                  currentUserId: _chatProvider!.currentUserId!,
                  chatProvider: chatProvider,
                  onImageTap: _handleImageTap,
                  onVideoTap: _handleVideoTap,
                  onDocumentTap: _handleDocumentTap,
                  onLocationTap: _handleLocationTap,
                  isStarred: isStarred,
                  onReplyTap:
                      _handleReplyMessageTap, // ✅ NEW: Reply tap handler
                  peerUserId:
                      chatPartnerId, // ✅ NEW: Pass peer user ID for call direction
                ),
              ),
            ),

            // // Selection indicator for own messages
            // if (_isMultiSelectMode && isSentByMe) SizedBox(width: 8),

            // if (_isMultiSelectMode && isSentByMe && isSelectableForMultiSelect)
            //   _buildSelectionIndicator(isSelected, messageId),

            // // Non-selectable indicator for own system messages
            // if (_isMultiSelectMode && isSentByMe && !isSelectableForMultiSelect)
            //   _buildNonSelectableIndicator(),
          ],
        ),
      ],
    );

    return Container(
      margin: EdgeInsets.symmetric(vertical: 3),
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _handleMessageTap(chat),
        onLongPress: () => _handleMessageLongPress(chat),
        child:
            containerDecoration != null && animationDuration > Duration.zero
                ? AnimatedContainer(
                  duration: animationDuration,
                  curve: Curves.easeInOut,
                  decoration: containerDecoration,
                  padding: containerPadding,
                  child: messageContainer,
                )
                : messageContainer,
      ),
    );
  }

  Widget _buildSelectionIndicator(bool isSelected, int messageId) {
    return GestureDetector(
      onTap: () => _toggleMessageSelection(messageId),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              isSelected
                  ? AppColors.appPriSecColor.primaryColor
                  : Colors.transparent,
          border: Border.all(
            color:
                isSelected
                    ? AppColors.appPriSecColor.primaryColor
                    : AppThemeManage.appTheme.strokBorder2,
            width: 2,
          ),
        ),
        child:
            isSelected
                ? Icon(Icons.check, color: AppColors.bgColor.bgBlack, size: 12)
                : null,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-DELETE CORE METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  void _handleMessageTap(chats.Records chat) {
    if (_isMultiSelectMode) {
      // Only allow selection of forwardable/deletable messages
      if (_isMessageSelectableForMultiSelect(chat)) {
        _toggleMessageSelection(chat.messageId!);
      } else {
        _showUnselectableMessageAlert(chat);
      }
    }
    // Normal tap handling can be added here if needed
  }

  void _showUnselectableMessageAlert(chats.Records message) {
    String alertMessage;
    String alertTitle;

    if (message.deletedForEveryone == true) {
      alertTitle = AppString.messageAlreadyDeleted;
      alertMessage =
          AppString.thismessagehasalreadybeendeletedandcannotbeselected;
    } else {
      final messageType = message.messageType?.toLowerCase();
      switch (messageType) {
        case 'group-created':
          alertTitle = AppString.systemMessage;
          alertMessage = AppString.groupcreationmessagescannotbedeleted;
          break;
        case 'member-added':
          alertTitle = AppString.systemMessage;
          alertMessage = AppString.memberadditionmessagescannotbedeleted;
          break;
        case 'member-removed':
          alertTitle = AppString.systemMessage;
          alertMessage = AppString.memberremovalmessagescannotbedeleted;
          break;
        case 'member-left':
          alertTitle = AppString.systemMessage;
          alertMessage = AppString.memberleftmessagescannotbedeleted;
          break;
        case 'promoted-as-admin':
          alertTitle = AppString.systemMessage;
          alertMessage = AppString.promotedasadminmessagescannotbedeleted;
          break;
        case 'removed-as-admin':
          alertTitle = AppString.systemMessage;
          alertMessage = AppString.removedasadminmessagescannotbeDeleted;
          break;

        default:
          alertTitle = AppString.cannotSelectMessage;
          alertMessage = AppString.thisTypeofMessageCannotBeDeleted;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    alertTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    alertMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.appPriSecColor.primaryColor,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // void _handleMessageLongPress(chats.Records chat) {
  //   if (!_isMultiDeleteMode && chat.deletedForEveryone != true) {
  //     // Check if message is selectable before entering multi-delete mode
  //     if (_isMessageSelectableForDeletion(chat)) {
  //       // Start multi-delete mode and select this message
  //       _enterMultiDeleteMode();
  //       _toggleMessageSelection(chat.messageId!);
  //     } else {
  //       // Show normal long press menu for non-selectable messages
  //       _handleLongPress(chat);
  //     }
  //   } else if (!_isMultiDeleteMode) {
  //     // Normal long press for non-deleted messages
  //     _handleLongPress(chat);
  //   }
  // }
  void _handleMessageLongPress(chats.Records chat) {
    if (!_isMultiSelectMode && chat.deletedForEveryone != true) {
      // Skip long press for all system messages
      final messageType = chat.messageType?.toLowerCase();
      const systemMessageTypes = {
        'group-created',
        'member-added',
        'member-removed',
        'member-left',
        'call',
        'block',
        'unblock',
        'promoted-as-admin',
        'removed-as-admin',
      };

      if (systemMessageTypes.contains(messageType)) {
        return; // Don't show options menu for system messages
      }

      // Always show the normal long press menu first
      _handleLongPress(chat);
    }
    // If already in multi-select mode, ignore long press
  }

  void _enterMultiSelectMode() {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    _logger.d('📋 Entering multi-select mode');

    setState(() {
      _isMultiSelectMode = true;
      _selectedMessageIds.clear();
    });
  }

  void _exitMultiSelectMode() {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    _logger.d('📋 Exiting multi-select mode');

    setState(() {
      _multiSelectAction = '';
      _isMultiSelectMode = false;
      _selectedMessageIds.clear();
      _isDeletingMessages = false;
      _isForwardingMessages = false;
      isForwardDialog = false;
    });
  }

  void _handleMultiSelectStart(chats.Records message) {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    _logger.d(
      '📋 Starting multi-select mode from message: ${message.messageId}',
    );

    // Enter multi-select mode and select the initial message
    _enterMultiSelectMode();
    _toggleMessageSelection(message.messageId!);
  }

  bool _isMessageSelectableForMultiSelect(chats.Records message) {
    // 1. Check if message is deleted for everyone
    if (message.deletedForEveryone == true) {
      return false;
    }

    // 2. Only system messages are non-selectable
    final messageType = message.messageType?.toLowerCase();
    const systemMessageTypes = {
      'group-created',
      'member-added',
      'member-removed',
      'member-left',
      'call',
      'block',
      'unblock',
      'promoted-as-admin',
      'removed-as-admin',
    };

    // If it's a system message, it's not selectable
    if (systemMessageTypes.contains(messageType)) {
      return false;
    }

    // 3. All other messages are selectable for both forward and delete
    return true;
  }

  void _showForwardChatSelectionDialog() {
    if (!mounted || _selectedMessageIds.isEmpty) return;

    // ✅ Use existing ContactListScreen instead of custom dialog
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => ContactListScreen(
              fromChatId: widget.chatId,
              selectedMessageIds: _selectedMessageIds.toList(),
              isForwardMode: true, // ✅ Enable forward mode
              onChatSelected:
                  _handleForwardToChatSelected, // ✅ Forward callback
              onForwardCompleted:
                  _exitMultiSelectMode, // ✅ Disable multi-select mode after forwarding
            ),
      ),
    );
  }

  void _handleForwardToChatSelected(int targetChatId, String chatName) {
    // ✅ Pop the contact selection screen
    Navigator.of(context).pop();

    // ✅ Show confirmation dialog
    _showForwardConfirmationDialog(targetChatId, chatName);
  }

  void _showForwardConfirmationDialog(int targetChatId, String chatName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppString.forwardMessages,
            style: AppTypography.h4(context),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppString.chatBubbleStrings.forward} $selectedMessagesCount ${AppString.message} $selectedMessagesCount ${AppString.to}:',
                style: AppTypography.mediumText(context),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.appPriSecColor.primaryColor.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.appPriSecColor.primaryColor.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat,
                      color: AppColors.appPriSecColor.primaryColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatName,
                        style: AppTypography.mediumText(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.appPriSecColor.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppString.messagesWillBeForwarded,
                        style: AppTypography.smallText(
                          context,
                        ).copyWith(color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppString.cancel,
                style: AppTypography.buttonText(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _forwardSelectedMessages(targetChatId);
              },
              child: Text(
                AppString.forward,
                style: AppTypography.buttonText(context).copyWith(
                  color: AppColors.appPriSecColor.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _forwardSelectedMessages(int targetChatId) async {
    if (_chatProvider!.isDisposedOfChat ||
        !mounted ||
        _selectedMessageIds.isEmpty) {
      return;
    }

    final fromChatId = widget.chatId ?? 0;
    if (fromChatId <= 0) {
      _logger.e('❌ Invalid source chat ID for forward');
      return;
    }

    setState(() {
      _isForwardingMessages = true;
      _totalMessagesToForward = _selectedMessageIds.length;
      _forwardedMessagesCount = 0;
    });

    _logger.d(
      '📤 Starting bulk forward of $_totalMessagesToForward messages to chat $targetChatId',
    );

    // Show progress indicator
    _showForwardingProgress();

    final List<int> messagesToForward = _selectedMessageIds.toList();
    bool hasErrors = false;
    int successCount = 0;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    try {
      for (int i = 0; i < messagesToForward.length; i++) {
        if (_chatProvider!.isDisposedOfChat || !mounted) break;

        final messageId = messagesToForward[i];

        _logger.d(
          '📤 Forwarding message $messageId (${i + 1}/$_totalMessagesToForward)',
        );

        bool forwardSuccess = false;

        try {
          // ✅ Use ChatProvider's public forward method
          forwardSuccess = await chatProvider.forwardMessage(
            fromChatId: fromChatId,
            toChatId: targetChatId,
            messageId: messageId,
          );

          if (forwardSuccess) {
            successCount++;
            if (mounted) {
              setState(() {
                _forwardedMessagesCount++;
              });
            }

            _logger.d('📤 Forwarded message $messageId successfully');

            // Small delay between forwards to avoid overwhelming the server
            await Future.delayed(Duration(milliseconds: 300));
          } else {
            hasErrors = true;
            _logger.e('❌ Failed to forward message $messageId');
          }
        } catch (e) {
          hasErrors = true;
          _logger.e('❌ Error forwarding message $messageId: $e');
        }
      }

      // Hide progress indicator
      _hideForwardingProgress();

      if (mounted) {
        setState(() {
          _isForwardingMessages = false;
        });

        // Show result feedback
        final String resultMessage;
        if (hasErrors && successCount > 0) {
          resultMessage =
              'Forwarded $successCount of $_totalMessagesToForward messages. Some forwards failed.';
        } else if (hasErrors) {
          resultMessage = 'Failed to forward messages. Please try again.';
        } else {
          resultMessage = 'Successfully forwarded $successCount messages.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  hasErrors ? Icons.warning : Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(child: Text(resultMessage)),
              ],
            ),
            backgroundColor:
                hasErrors
                    ? AppColors.textColor.textErrorColor
                    : AppColors.appPriSecColor.primaryColor,
            duration: Duration(seconds: 3),
          ),
        );

        // Exit multi-select mode
        _exitMultiSelectMode();
      }
    } catch (e) {
      _logger.e('❌ Critical error during bulk forward: $e');

      _hideForwardingProgress();

      if (mounted) {
        setState(() {
          _isForwardingMessages = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${AppString.failedToForwardMessages}: ${e.toString()}',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.textColor.textErrorColor,
            duration: Duration(seconds: 3),
          ),
        );

        _exitMultiSelectMode();
      }
    }
  }

  void _showForwardingProgress() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                AppString.forwardingMessages,
                style: AppTypography.h4(context),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  commonLoading(),
                  SizedBox(height: 16),
                  Text(
                    '${AppString.forwarded} $_forwardedMessagesCount ${AppString.of} $_totalMessagesToForward ${AppString.homeScreenString.messages}',
                    style: AppTypography.mediumText(context),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value:
                        _totalMessagesToForward > 0
                            ? _forwardedMessagesCount / _totalMessagesToForward
                            : 0.0,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.appPriSecColor.primaryColor,
                    ),
                    backgroundColor: AppColors.strokeColor.greyColor,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _hideForwardingProgress() {
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _toggleMessageSelection(int messageId) {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    // Find the message to check if it's selectable
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chats.Records? targetMessage;

    try {
      targetMessage = chatProvider.chatsData.records?.firstWhere(
        (msg) => msg.messageId == messageId,
      );
    } catch (e) {
      _logger.w('⚠️ Message $messageId not found for selection');
      return;
    }

    if (targetMessage == null) return;

    // Check if message is selectable for deletion
    if (!_isMessageSelectableForDeletion(targetMessage)) {
      _showUnselectableMessageAlert(targetMessage);
      return;
    }

    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        _logger.d('🗑️ Deselected message: $messageId');
      } else {
        _selectedMessageIds.add(messageId);
        _logger.d('🗑️ Selected message: $messageId');
      }
    });

    // Auto-exit if no messages selected
    if (_selectedMessageIds.isEmpty && _isMultiSelectMode) {
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted && _selectedMessageIds.isEmpty) {
          _exitMultiSelectMode();
        }
      });
    }
  }

  /// Check if a message is selectable for deletion
  bool _isMessageSelectableForDeletion(chats.Records message) {
    // 1. Check if message is deleted for everyone
    if (message.deletedForEveryone == true) {
      return false;
    }

    // 2. FIXED: Only system messages are non-selectable
    final messageType = message.messageType?.toLowerCase();
    const systemMessageTypes = {
      'group-created',
      'member-added',
      'member-removed',
      'member-left',
      'block',
      'unblock',
      'promoted-as-admin',
      'removed-as-admin',
    };

    // If it's a system message, it's not selectable
    if (systemMessageTypes.contains(messageType)) {
      return false;
    }

    // 3. All other messages (including text, image, video, etc.) are selectable
    // regardless of who sent them
    return true;
  }

  void _showDeleteSelectedMessagesDialog() {
    if (!mounted || _selectedMessageIds.isEmpty) return;

    // Analyze selected messages to determine delete options
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUserId = int.tryParse(_chatProvider!.currentUserId ?? '');

    int ownMessages = 0;
    int othersMessages = 0;

    for (final messageId in _selectedMessageIds) {
      try {
        final message = chatProvider.chatsData.records?.firstWhere(
          (msg) => msg.messageId == messageId,
        );
        if (message != null) {
          if (message.senderId == currentUserId) {
            ownMessages++;
          } else {
            othersMessages++;
          }
        }
      } catch (e) {
        // Message not found in current data
      }
    }

    bottomSheetGobal(
      context,
      bottomsheetHeight:
          (ownMessages > 0 && othersMessages > 0)
              ? SizeConfig.height(48)
              : (ownMessages > 0)
              ? SizeConfig.height(45)
              : SizeConfig.height(40),
      borderRadius: BorderRadius.circular(30),
      title: AppString.homeScreenString.deleteMessage,
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppString.homeScreenString.chooseHowYouWantToDeleteTheMessages,
              style: AppTypography.innerText16(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: SizeConfig.height(1.5)),

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: AppThemeManage.appTheme.appSndColor2,
              ),
              padding: SizeConfig.getPaddingSymmetric(
                horizontal: 20,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppString.youHaveSelected} $selectedMessagesCount ${AppString.homeScreenString.messages}:',
                    style: AppTypography.innerText16(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  if (ownMessages > 0 && othersMessages > 0) ...[
                    Text(
                      '• $ownMessages ${AppString.ofYourOwnMessage}',
                      style: AppTypography.innerText12Mediu(context),
                    ),
                    Text(
                      '• $othersMessages ${AppString.messagesOfOthers}',
                      style: AppTypography.innerText12Mediu(context),
                    ),
                  ] else if (ownMessages > 0) ...[
                    Text(
                      '• $ownMessages ${AppString.ofYourOwnMessage}',
                      style: AppTypography.innerText12Mediu(context),
                    ),
                  ] else if (othersMessages > 0) ...[
                    Text(
                      '• $othersMessages ${AppString.messagesOfOthers}',
                      style: AppTypography.innerText12Mediu(context),
                    ),
                  ],
                ],
              ),
            ),

            // FIXED: "Delete for Me" - Always available for all selected messages
            SizedBox(height: SizeConfig.height(1)),
            Divider(color: AppThemeManage.appTheme.borderColor),
            SizedBox(height: SizeConfig.height(1)),
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                _deleteSelectedMessages(isDeleteForEveryone: false);
              },
              child: Text(
                AppString.deleteForMe,
                style: AppTypography.innerText14(context).copyWith(
                  color: AppColors.textColor.textErrorColor1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: SizeConfig.height(1)),

            // FIXED: "Delete for Everyone" - Only if user has own messages
            if (ownMessages > 0) ...[
              Divider(color: AppThemeManage.appTheme.borderColor),
              SizedBox(height: SizeConfig.height(1)),
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  if (othersMessages > 0) {
                    // Show validation alert if others' messages are selected
                    _showDeleteForEveryoneValidationAlert(
                      ownMessages,
                      othersMessages,
                    );
                  } else {
                    // Only own messages selected, proceed with confirmation
                    _showDeleteForEveryoneConfirmation();
                  }
                },
                child: Text(
                  AppString.deleteForEveryone1,
                  style: AppTypography.innerText14(context).copyWith(
                    color: AppColors.textColor.textErrorColor1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeleteForEveryoneValidationAlert(
    int ownMessagesCount,
    int othersMessagesCount,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.textColor.textErrorColor,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppString
                      .cannotDeleteForEveryone, //'Cannot Delete for Everyone',
                  style: AppTypography.h4(
                    context,
                  ).copyWith(color: AppColors.textColor.textErrorColor),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main explanation
              Text(
                AppString
                    .youCanOnlyDeleteYourOwnMessagesForEveryone, //'You can only delete your own messages for everyone.',
                style: AppTypography.mediumText(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 16),

              // Selection breakdown container
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.textColor.textErrorColor.withValues(
                    alpha: 0.05,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.textColor.textErrorColor.withValues(
                      alpha: 0.2,
                    ),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppString.yourCurrentSelection}:',
                      style: AppTypography.smallText(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor.textGreyColor,
                      ),
                    ),
                    SizedBox(height: 12),

                    // Own messages (allowed)
                    if (ownMessagesCount > 0) ...[
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.green,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.green,
                              size: 12,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$ownMessagesCount ${ownMessagesCount > 1 ? AppString.ofYourOwnMessages : AppString.ofYourOwnMessage}',
                              style: AppTypography.smallText(context).copyWith(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '✓ ${AppString.canDelete}',
                            style: AppTypography.smallText(context).copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                    ],

                    // Others' messages (not allowed)
                    if (othersMessagesCount > 0) ...[
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.textColor.textErrorColor
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.textColor.textErrorColor,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.close,
                              color: AppColors.textColor.textErrorColor,
                              size: 12,
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$othersMessagesCount ${othersMessagesCount > 1 ? AppString.homeScreenString.messages : AppString.message} ${AppString.fromOthers} ✗',
                              style: AppTypography.smallText(context).copyWith(
                                color: AppColors.textColor.textErrorColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '✗ ${AppString.cannotDelete}',
                            style: AppTypography.smallText(context).copyWith(
                              color: AppColors.textColor.textErrorColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Available options
              Text(
                '${AppString.yourOptions}:',
                style: AppTypography.mediumText(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),

              // Option 1: Delete for me
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.appPriSecColor.primaryColor.withValues(
                    alpha: 0.05,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.appPriSecColor.primaryColor.withValues(
                      alpha: 0.2,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_off,
                      color: AppColors.appPriSecColor.primaryColor,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppString.useDeleteforMe,
                            style: AppTypography.smallText(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.appPriSecColor.primaryColor,
                            ),
                          ),
                          Text(
                            AppString
                                .removesAllSelectedMessagesFromYourViewOnly,
                            style: AppTypography.smallText(context).copyWith(
                              color: AppColors.textColor.textGreyColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 8),

              // Option 2: Select only own messages (if applicable)
              if (ownMessagesCount > 0) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_alt,
                        color: Colors.orange.shade700,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppString.deleteOnlyYourMessagesForEveryone,
                              style: AppTypography.smallText(context).copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            Text(
                              '${AppString.automaticallyFiltersToYour} $ownMessagesCount ${ownMessagesCount > 1 ? AppString.homeScreenString.messages : AppString.message}',
                              style: AppTypography.smallText(context).copyWith(
                                color: AppColors.textColor.textGreyColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppString.cancel,
                style: AppTypography.buttonText(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
              ),
            ),

            // Delete for me button
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSelectedMessages(isDeleteForEveryone: false);
              },
              child: Text(
                AppString.deleteForMe,
                style: AppTypography.buttonText(context).copyWith(
                  color: AppColors.appPriSecColor.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Delete only own messages for everyone (if applicable)
            if (ownMessagesCount > 0)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _filterAndDeleteOwnMessages();
                },
                child: Text(
                  AppString.deleteMineforEveryone, //'Delete Mine for Everyone',
                  style: AppTypography.buttonText(context).copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showDeleteForEveryoneConfirmation() {
    // Validate that user can only delete their own messages for everyone
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUserId = int.tryParse(_chatProvider!.currentUserId ?? '');

    List<int> othersMessageIds = [];
    List<int> ownMessageIds = [];

    for (final messageId in _selectedMessageIds) {
      try {
        final message = chatProvider.chatsData.records?.firstWhere(
          (msg) => msg.messageId == messageId,
        );
        if (message != null) {
          if (message.senderId == currentUserId) {
            ownMessageIds.add(messageId);
          } else {
            othersMessageIds.add(messageId);
          }
        }
      } catch (e) {
        // Message not found in current data
      }
    }

    // If user has selected others' messages, show validation alert
    if (othersMessageIds.isNotEmpty) {
      _showDeleteEveryoneValidationAlert(
        ownMessageIds.length,
        othersMessageIds.length,
      );
      return;
    }

    // If only own messages selected, proceed with confirmation
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppString.deleteForEveryone,
            style: AppTypography.h4(context),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppString.these} ${ownMessageIds.length} ${AppString.message}${ownMessageIds.length} ${AppString.willBeDeletedForEveryoneInTheChat}',
                style: AppTypography.mediumText(context),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textColor.textErrorColor.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.textColor.textErrorColor.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.textColor.textErrorColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppString.thisActionCannotbBeUndoneTheMessages,
                        style: AppTypography.smallText(
                          context,
                        ).copyWith(color: AppColors.textColor.textErrorColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppString.cancel,
                style: AppTypography.buttonText(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSelectedMessages(isDeleteForEveryone: true);
              },
              child: Text(
                AppString.deleteForEveryone1,
                style: AppTypography.buttonText(context).copyWith(
                  color: AppColors.textColor.textErrorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteEveryoneValidationAlert(
    int ownMessagesCount,
    int othersMessagesCount,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.textColor.textErrorColor,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                AppString.cannotDeleteForEveryone,
                style: AppTypography.h4(
                  context,
                ).copyWith(color: AppColors.textColor.textErrorColor),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppString.youCanOnlyDeleteYourOwnMessagesForEveryone,
                style: AppTypography.mediumText(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textColor.textErrorColor.withValues(
                    alpha: 0.05,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppString.yourSelectionContains,
                      style: AppTypography.smallText(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor.textGreyColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (ownMessagesCount > 0)
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '$ownMessagesCount ${ownMessagesCount > 1 ? AppString.ofYourOwnMessages : AppString.ofYourOwnMessage} ✓',
                            style: AppTypography.smallText(context),
                          ),
                        ],
                      ),
                    if (othersMessagesCount > 0) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.cancel,
                            color: AppColors.textColor.textErrorColor,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '$othersMessagesCount ${othersMessagesCount > 1 ? AppString.homeScreenString.messages : AppString.message} ${AppString.fromOthers} ✗',
                            style: AppTypography.smallText(context).copyWith(
                              color: AppColors.textColor.textErrorColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                '${AppString.options}:',
                style: AppTypography.mediumText(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                '• ${AppString.usetoRemoveAllSelectedMessagesFromYourView}',
                style: AppTypography.smallText(context),
              ),
              if (ownMessagesCount > 0) ...[
                SizedBox(height: 4),
                Text(
                  '• ${AppString.selectOnlyYourOwnMessagesToDeleteThemforEveryone}',
                  style: AppTypography.smallText(context),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppString.gotIt,
                style: AppTypography.buttonText(context).copyWith(
                  color: AppColors.appPriSecColor.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (ownMessagesCount > 0)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Filter selection to only own messages and proceed
                  _filterAndDeleteOwnMessages();
                },
                child: Text(
                  AppString.deleteOnlyMineForEveryone,
                  style: AppTypography.buttonText(
                    context,
                  ).copyWith(color: AppColors.textColor.textErrorColor),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelectedMessages({
    required bool isDeleteForEveryone,
  }) async {
    if (_chatProvider!.isDisposedOfChat ||
        !mounted ||
        _selectedMessageIds.isEmpty) {
      return;
    }

    // ✅ DEMO MODE: Additional safeguard - prevent deletion in demo mode
    if (isDemo) {
      snackbarNew(
        context,
        msg: "Demo account - Login with real credentials to delete messages",
      );
      // Exit multi-select mode
      _exitMultiSelectMode();
      return;
    }

    final chatId = widget.chatId ?? 0;
    if (chatId <= 0) {
      _logger.e('❌ Invalid chat ID for bulk delete');
      return;
    }

    // Get current user ID for permission checking
    if (_chatProvider!.currentUserId == null) {
      _logger.e('❌ Current user ID not available for bulk delete');
      return;
    }

    final currentUserId = int.tryParse(_chatProvider!.currentUserId!);
    if (currentUserId == null) {
      _logger.e('❌ Invalid current user ID format for bulk delete');
      return;
    }

    setState(() {
      _isDeletingMessages = true;
      _totalMessagesToDelete = _selectedMessageIds.length;
      _deletedMessagesCount = 0;
    });

    _logger.d(
      '🗑️ Starting bulk delete of $_totalMessagesToDelete messages (deleteForEveryone: $isDeleteForEveryone)',
    );

    // Show progress indicator
    _showDeletionProgress();

    final List<int> messagesToDelete = _selectedMessageIds.toList();
    bool hasErrors = false;
    int successCount = 0;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    try {
      for (int i = 0; i < messagesToDelete.length; i++) {
        if (_chatProvider!.isDisposedOfChat || !mounted) break;

        final messageId = messagesToDelete[i];

        // Find the message to determine delete type
        chats.Records? targetMessage;
        try {
          targetMessage = chatProvider.chatsData.records?.firstWhere(
            (msg) => msg.messageId == messageId,
          );
        } catch (e) {
          _logger.w('⚠️ Message $messageId not found in current data');
          continue;
        }

        if (targetMessage == null) continue;

        _logger.d(
          '🗑️ Deleting message $messageId (${i + 1}/$_totalMessagesToDelete)',
        );

        bool deleteSuccess = false;

        try {
          // FIXED: Apply validation based on delete type
          final isSentByCurrentUser = targetMessage.senderId == currentUserId;

          if (isDeleteForEveryone) {
            // ENHANCED VALIDATION: Only allow deleting own messages for everyone
            if (!isSentByCurrentUser) {
              _logger.e(
                '🚫 SECURITY VIOLATION: Attempt to delete others message $messageId for everyone',
              );
              hasErrors = true;
              continue; // Skip this message
            }

            // Delete own message for everyone
            deleteSuccess = await chatProvider.deleteMessageForEveryone(
              chatId,
              messageId,
            );
            _logger.d(
              '🗑️ Deleted own message $messageId for everyone: $deleteSuccess',
            );
          } else {
            // FIXED: Delete for me - works for ALL messages (own + others)
            deleteSuccess = await chatProvider.deleteMessageForMe(
              chatId,
              messageId,
            );
            _logger.d('🗑️ Deleted message $messageId for me: $deleteSuccess');
          }

          if (deleteSuccess) {
            successCount++;
            if (mounted) {
              setState(() {
                _deletedMessagesCount++;
              });
            }

            // Small delay between deletions to avoid overwhelming the server
            await Future.delayed(Duration(milliseconds: 200));
          } else {
            hasErrors = true;
            _logger.e('❌ Failed to delete message $messageId');
          }
        } catch (e) {
          hasErrors = true;
          _logger.e('❌ Error deleting message $messageId: $e');
        }
      }

      // Hide progress indicator
      _hideDeletionProgress();

      if (mounted) {
        setState(() {
          _isDeletingMessages = false;
        });

        // Show result feedback
        final String resultMessage;
        if (hasErrors && successCount > 0) {
          resultMessage =
              '${AppString.deleted} $successCount ${AppString.of} $_totalMessagesToDelete ${AppString.homeScreenString.messages}. ${AppString.someDeletionsFailed}';
        } else if (hasErrors) {
          resultMessage = AppString.failedToDeleteMessagesPleaseTryAgain;
        } else {
          final deleteType =
              isDeleteForEveryone ? AppString.forEveryone : AppString.foryou;
          resultMessage =
              '${AppString.successfullyDeleted} $successCount ${AppString.homeScreenString.messages} $deleteType.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  hasErrors ? Icons.warning : Icons.check_circle,
                  color: ThemeColorPalette.getTextColor(
                    AppColors.appPriSecColor.primaryColor,
                  ), //AppThemeManage.appTheme.darkWhiteColor,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    resultMessage,
                    style: TextStyle(
                      color: ThemeColorPalette.getTextColor(
                        AppColors.appPriSecColor.primaryColor,
                      ), //AppThemeManage.appTheme.darkWhiteColor,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor:
                hasErrors
                    ? AppColors.textColor.textErrorColor
                    : AppColors.appPriSecColor.primaryColor,
            duration: Duration(seconds: 3),
          ),
        );

        // Refresh chat messages to reflect deletions
        if (successCount > 0) {
          Future.delayed(Duration(milliseconds: 500), () {
            if (!_chatProvider!.isDisposedOfChat && mounted) {
              _refreshChatMessages();
            }
          });
        }

        // Exit multi-delete mode
        _exitMultiSelectMode();
      }
    } catch (e) {
      _logger.e('❌ Critical error during bulk delete: $e');

      _hideDeletionProgress();

      if (mounted) {
        setState(() {
          _isDeletingMessages = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error,
                  color: AppThemeManage.appTheme.darkWhiteColor,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${AppString.failedToDeleteMessages}: ${e.toString()}',
                    style: TextStyle(
                      color: AppThemeManage.appTheme.darkWhiteColor,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.textColor.textErrorColor,
            duration: Duration(seconds: 3),
          ),
        );

        _exitMultiSelectMode();
      }
    }
  }

  void _showDeletionProgress() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppThemeManage.appTheme.darkGreyColor,
              title: Text(
                AppString.deletingMessages,
                style: AppTypography.h4(context),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  commonLoading(),
                  SizedBox(height: 16),
                  Text(
                    '${AppString.deleted} $_deletedMessagesCount ${AppString.of} $_totalMessagesToDelete ${AppString.homeScreenString.messages}',
                    style: AppTypography.mediumText(context),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value:
                        _totalMessagesToDelete > 0
                            ? _deletedMessagesCount / _totalMessagesToDelete
                            : 0.0,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.appPriSecColor.primaryColor,
                    ),
                    backgroundColor: AppColors.strokeColor.greyColor,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _hideDeletionProgress() {
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // ignore: unused_element
  Widget _buildMessageContainer({
    required chats.Records chat,
    required GlobalKey key,
    required bool isSentByMe,
    required bool isPinned,
    required bool isStarred,
    required bool isHighlighted,
    required bool showSenderInfo,
    required ChatProvider chatProvider,
  }) {
    BoxDecoration? containerDecoration;
    EdgeInsets containerPadding = EdgeInsets.zero;
    Duration animationDuration = Duration.zero;

    if (isHighlighted) {
      containerDecoration = BoxDecoration(
        color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.appPriSecColor.primaryColor,
          width: 2.5,
        ),
      );
      containerPadding = EdgeInsets.all(12);
      animationDuration = Duration(milliseconds: 600);
    }

    Widget messageContainer = Column(
      crossAxisAlignment:
          isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // if (isStarred) _buildStarIndicator(isSentByMe),
        if (isPinned) _buildPinIndicator(isSentByMe, isHighlighted),
        if (showSenderInfo) _buildGroupSenderInfo(chat),
        KeyedSubtree(
          key: key,
          child: MessageContentWidget(
            chat: chat,
            currentUserId: _chatProvider!.currentUserId!,
            chatProvider: chatProvider,
            onImageTap: _handleImageTap,
            onVideoTap: _handleVideoTap,
            onDocumentTap: _handleDocumentTap,
            onLocationTap: _handleLocationTap,
            isStarred: isStarred,
            onReplyTap: _handleReplyMessageTap, // ✅ NEW: Reply tap handler
            peerUserId:
                chatPartnerId, // ✅ NEW: Pass peer user ID for call direction
          ),
        ),
      ],
    );

    return Container(
      margin: EdgeInsets.symmetric(vertical: 3),
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onLongPress: () => _handleLongPress(chat),
        borderRadius: BorderRadius.circular(12),
        child:
            containerDecoration != null && animationDuration > Duration.zero
                ? AnimatedContainer(
                  duration: animationDuration,
                  curve: Curves.easeInOut,
                  decoration: containerDecoration,
                  padding: containerPadding,
                  child: messageContainer,
                )
                : messageContainer,
      ),
    );
  }

  void _filterAndDeleteOwnMessages() {
    // Filter selection to only include own messages
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUserId = int.tryParse(_chatProvider!.currentUserId ?? '');

    Set<int> ownMessageIds = <int>{};

    for (final messageId in _selectedMessageIds) {
      try {
        final message = chatProvider.chatsData.records?.firstWhere(
          (msg) => msg.messageId == messageId,
        );
        if (message != null && message.senderId == currentUserId) {
          ownMessageIds.add(messageId);
        }
      } catch (e) {
        // Message not found in current data
      }
    }

    if (ownMessageIds.isNotEmpty) {
      setState(() {
        _selectedMessageIds = ownMessageIds;
      });

      _logger.d(
        '🗑️ Filtered selection to ${ownMessageIds.length} own messages for delete everyone',
      );

      // Proceed with delete for everyone for own messages only
      _deleteSelectedMessages(isDeleteForEveryone: true);
    } else {
      // No own messages found (shouldn't happen, but handle gracefully)
      _exitMultiSelectMode();
    }
  }

  Widget _buildGroupSenderInfo(chats.Records chat) {
    final user = chat.user;
    if (user == null) return SizedBox.shrink();

    // Check if this is the current user's message
    final currentUserIdInt =
        _chatProvider!.currentUserId != null
            ? int.tryParse(_chatProvider!.currentUserId!)
            : null;
    final isCurrentUser =
        currentUserIdInt != null && chat.senderId == currentUserIdInt;
    final displayName =
        isCurrentUser ? 'You' : (user.fullName ?? 'Unknown User');

    return Padding(
      padding: EdgeInsets.only(bottom: 2, top: 0),
      child: GestureDetector(
        onTap: () => _onSenderTap(user),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildUserAvatar(
              profilePic: user.profilePic ?? '',
              userName: user.fullName ?? 'Unknown User',
              userId: user.userId ?? 0,
              radius: 20,
            ),
            SizedBox(width: 6),
            Text(
              displayName,
              style: AppTypography.captionText(context).copyWith(
                color: _getAvatarColor(user.userId ?? 0),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Group management methods
  void _updateGroupMembersFromMessages(List<chats.Records> messages) {
    for (final message in messages) {
      if (message.user != null && message.senderId != null) {
        final userId = message.senderId!;
        final user = message.user!;

        // Add or update user in the map
        if (!_groupMembersMap.containsKey(userId)) {
          _groupMembersMap[userId] = user;
          _logger.d("Added group member: ${user.fullName} (ID: $userId)");
        } else {
          // Update user info if it's newer
          final existingUser = _groupMembersMap[userId]!;
          if (_isUserInfoNewer(user, existingUser)) {
            _groupMembersMap[userId] = user;
            _logger.d("Updated group member: ${user.fullName} (ID: $userId)");
          }
        }
      }
    }

    _logger.d("Group now has ${_groupMembersMap.length} members");
  }

  bool _isUserInfoNewer(chats.User newUser, chats.User existingUser) {
    // Compare updated timestamps or other criteria
    if (newUser.updatedAt != null && existingUser.updatedAt != null) {
      final newTime = DateTime.tryParse(newUser.updatedAt!);
      final existingTime = DateTime.tryParse(existingUser.updatedAt!);
      if (newTime != null && existingTime != null) {
        return newTime.isAfter(existingTime);
      }
    }
    return false; // Keep existing if can't determine
  }

  chats.User? getGroupMember(int userId) {
    return _groupMembersMap[userId];
  }

  List<chats.User> getActiveGroupMembers() {
    return _groupMembersMap.values.where((user) {
      final chatProvider =
          _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
      return chatProvider.isUserOnline(user.userId ?? 0);
    }).toList();
  }

  // Group chat helper methods
  bool _shouldShowSenderInfo(
    chats.Records message,
    int index,
    List<chats.Records> messages,
  ) {
    if (index >= messages.length - 1) return true;

    final nextMessage = messages[index + 1];
    return message.senderId != nextMessage.senderId;
  }

  Color _getAvatarColor(int userId) {
    final colors = [
      Color(0xFF00A884), // WhatsApp green
      Color(0xFF0088CC), // Telegram blue
      Color(0xFF8B5A3C), // Brown
      Color(0xFF5B9BD5), // Light blue
      Color(0xFF70AD47), // Green
      Color(0xFFED7D31), // Orange
      Color(0xFFA5A5A5), // Gray
      Color(0xFFE91E63), // Pink
      Color(0xFF9C27B0), // Purple
      Color(0xFF795548), // Deep brown
      Color(0xFF607D8B), // Blue gray
      Color(0xFF009688), // Teal
    ];
    return colors[userId % colors.length];
  }

  String _getSenderInitial(String name) {
    if (name.isEmpty) return 'U';
    return name.trim()[0].toUpperCase();
  }

  Widget _buildUserAvatar({
    required String profilePic,
    required String userName,
    required int userId,
    required double radius,
  }) {
    final initials = _getSenderInitial(userName);
    final avatarColor = _getAvatarColor(userId);

    return CircleAvatar(
      radius: radius,
      backgroundColor: avatarColor,
      backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
      onBackgroundImageError:
          profilePic.isNotEmpty
              ? (exception, stackTrace) {
                // Log error but don't show it to user
                _logger.w('Failed to load profile image: $profilePic');
              }
              : null,
      child:
          profilePic.isEmpty
              ? Text(
                initials,
                style: TextStyle(
                  fontSize: radius * 0.4,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              )
              : null,
    );
  }

  String _getDisplayName(ChatProvider chatProvider) {
    final configProvider = Provider.of<ProjectConfigProvider>(
      context,
      listen: false,
    );
    final chatListData = chatProvider.chatListData;

    // Try to get peer data from chat list
    if (chatListData.chats.isNotEmpty) {
      for (final chat in chatListData.chats) {
        final peerUserData = chat.peerUserData;
        if (peerUserData != null && peerUserData.userId == widget.userId) {
          return ContactNameService.instance.getDisplayNameStable(
            userId: peerUserData.userId,
            configProvider: configProvider,
            contextFullName:
                peerUserData.fullName, // Pass the full name from peer data
          );
        }
      }
    }

    // 🎯 ANTI-FLUCTUATION: Use stable method to prevent switching between contact name and server name
    return ContactNameService.instance.getDisplayNameStable(
      userId: widget.userId,
      configProvider: configProvider,
      contextFullName: null, // No context available here
    );
  }

  void _onSenderTap(chats.User user) {
    if (user.userId != null) {
      // Show user profile or start individual chat
      _showUserActionSheet(user);
    }
  }

  void _showUserActionSheet(chats.User user) {
    // showModalBottomSheet(
    //   context: context,
    //   builder:
    //       (context) => UserActionSheet(
    //         user: user,
    //         onViewProfile: () {
    //           Navigator.pop(context);
    //           _navigateToUserProfile(user);
    //         },
    //         onStartChat: () {
    //           Navigator.pop(context);
    //           _startIndividualChatWithUser(user);
    //         },
    //       ),
    // );
  }

  // void _navigateToUserProfile(User user) {
  //   Navigator.pushNamed(
  //     context,
  //     AppRoutes.userProfile,
  //     arguments: {'userId': user.userId},
  //   );
  // }

  // ignore: unused_element
  void _startIndividualChatWithUser(chats.User user) {
    Navigator.pushNamed(
      context,
      AppRoutes.universalChat,
      arguments: {
        'userId': user.userId,
        'chatName': user.fullName ?? 'User',
        'profilePic': user.profilePic ?? '',
        'isGroupChat': false,
      },
    );
  }

  Future<void> _navigateToGroupInfo() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.groupInfo,
      arguments: {
        'groupId': widget.chatId,
        'groupName': widget.chatName,
        'groupDescription': widget.groupDescription,
        'groupImage': widget.profilePic,
        'memberCount': groupMemberCount,

        'onGroupDeleted': () {
          // Navigate back to chat list when group is deleted
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      },
    );

    // Handle search mode activation
    if (result == "search") {
      debugPrint('UniversalChatScreen: Search mode requested from group info');
      // Enable search mode
      setState(() {
        _isSearchMode = true;
      });
      // Focus search field after a short delay to allow build to complete
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    } else {
      _chatProvider!.setIsDisposedOfChat(false);
      // _chatProvider!.setScreenActive(true, widget.chatId, widget.userId);
      // _checkCacheAvailability();
      // _initializeScreen();
      // _initializeCacheForChat();
      // _setScreenActive(true);
    }
  }

  int _getOnlineGroupMembersCount(ChatProvider chatProvider) {
    if (!isGroupChat) return 0;

    // First try to get from GroupProvider if available
    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      if (groupProvider.members.isNotEmpty) {
        return groupProvider.members
            .where((member) => chatProvider.isUserOnline(member.userId))
            .length;
      }
    } catch (e) {
      // GroupProvider might not be available in all contexts
      _logger.d(
        'GroupProvider not available, falling back to _groupMembersMap',
      );
    }

    // Fallback to _groupMembersMap for backward compatibility
    return _groupMembersMap.values
        .where((user) => chatProvider.isUserOnline(user.userId ?? 0))
        .length;
  }

  List<String> _getTypingUsersInGroup() {
    if (!isGroupChat) return [];

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
    final currentChatId = chatProvider.currentChatData.chatId ?? 0;

    if (chatProvider.typingData.typing == true) {
      // Get typing user IDs and convert to names
      final typingUserIds = chatProvider.getTypingUserIdsInChat(currentChatId);
      return typingUserIds.map((userId) {
        final user = _groupMembersMap[userId];
        return user?.fullName ?? 'Someone';
      }).toList();
    }

    return [];
  }

  // ignore: unused_element
  Widget _buildStarIndicator(bool isSentByMe) {
    return Padding(
      padding: EdgeInsets.only(
        left: isSentByMe ? 0 : 12,
        right: isSentByMe ? 12 : 0,
        bottom: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300),
            tween: Tween(begin: 0.8, end: 1.0),
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Icon(Icons.star, size: 14, color: Colors.amber),
              );
            },
          ),
          SizedBox(width: 4),
          Text(
            'Starred',
            style: AppTypography.captionText(context).copyWith(
              color: Colors.amber[700],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinIndicator(bool isSentByMe, bool isHighlighted) {
    return Padding(
      padding: EdgeInsets.only(
        left: isSentByMe ? 0 : 12,
        right: isSentByMe ? 12 : 0,
        bottom: 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.push_pin,
            size: 14,
            color:
                isHighlighted
                    ? AppColors.appPriSecColor.primaryColor
                    : AppColors.appPriSecColor.primaryColor.withValues(
                      alpha: 0.7,
                    ),
          ),
          SizedBox(width: 6),
          Text(
            'Pinned',
            style: AppTypography.captionText(context).copyWith(
              color:
                  isHighlighted
                      ? AppColors.appPriSecColor.primaryColor
                      : AppColors.appPriSecColor.primaryColor.withValues(
                        alpha: 0.7,
                      ),
              fontSize: 11,
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (isHighlighted) ...[
            SizedBox(width: 10),
            TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 1500),
              tween: Tween(begin: 0.6, end: 1.0),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.appPriSecColor.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.appPriSecColor.primaryColor
                              .withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'FOUND',
                      style: AppTypography.captionText(context).copyWith(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationLoader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: SizedBox(width: 24, height: 24, child: commonLoading()),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: GestureDetector(
        onTap: _sendHiMessage,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.all(24),
          margin: EdgeInsets.symmetric(horizontal: 32),
          // decoration: BoxDecoration(
          //   color: AppThemeManage.appTheme.borderColor,
          //   borderRadius: BorderRadius.circular(16),
          //   border: Border.all(
          //     color: AppColors.appPriSecColor.primaryColor.withValues(
          //       alpha: 0.3,
          //     ),
          //     width: 1,
          //   ),
          // ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                AppAssets.emptyDataIcons.noInnerChat,
                colorFilter: ColorFilter.mode(
                  AppColors.appPriSecColor.secondaryColor,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(height: 16),
              Text(
                AppString.emptyDataString.startConversation,
                style: AppTypography.h3(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                AppString.emptyDataString.sayHIstartconversation,
                style: AppTypography.innerText12Ragu(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to send Hi message when empty state is tapped
  void _sendHiMessage() {
    if (_chatProvider == null || _chatProvider!.isDisposedOfChat || !mounted) {
      return;
    }

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
    final chatId = widget.chatId ?? 0;

    _logger.d('Sending Hi message from empty state to chat: $chatId');

    // Send "Hi 👋" message
    chatProvider
        .sendMessage(chatId: chatId, 'Hi 👋', messageType: MessageType.Text)
        .then((success) {
          if (success && mounted) {
            _logger.d('Hi message sent successfully');
            // Scroll to bottom to show the new message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom(forceScroll: true);
            });
          } else {
            _logger.e('Failed to send Hi message');
          }
        });
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.textColor.textErrorColor,
          ),
          SizedBox(height: 16),
          Text(
            "Something went wrong",
            style: AppTypography.h4(
              context,
            ).copyWith(color: AppColors.textColor.textBlackColor),
          ),
          SizedBox(height: 8),
          Text(
            _chatProvider!.errorMessage ?? "Please try again",
            textAlign: TextAlign.center,
            style: AppTypography.mediumText(
              context,
            ).copyWith(color: AppColors.textColor.textGreyColor),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _chatProvider!.setHasError(false);
              _initializeScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.appPriSecColor.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          commonLoading(),
          SizedBox(height: 16),
          Text(
            _chatProvider!.isLoadingCurrentUser
                ? "Loading..."
                : "Loading messages...",
            style: AppTypography.mediumText(
              context,
            ).copyWith(color: AppColors.textColor.textGreyColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedMessagesWidget() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final pinnedMessages = chatProvider.pinnedMessagesData.records;

        if (pinnedMessages == null || pinnedMessages.isEmpty) {
          return SizedBox.shrink();
        }

        return PinnedMessagesWidget(
          key: ValueKey(
            'pinned_${pinnedMessages.length}_${pinnedMessages.hashCode}',
          ),
          chatProvider: chatProvider,
          scrollController: _scrollController,
          onMessageTap: _handlePinnedMessageTap,
          onUnpinMessage: _handleUnpinMessage,
          currentUserId: _chatProvider!.currentUserId ?? '0',
          pinnedMessages: pinnedMessages,
          isExpanded: chatProvider.isPinnedMessagesExpanded,
          onToggleExpansion: () {
            chatProvider.togglePinnedMessagesExpansion();
          },
        );
      },
    );
  }

  // ignore: unused_element
  bool get _isMember => Provider.of<GroupProvider>(
    context,
    listen: false,
  ).members.any((e) => e.userId == int.parse(userID));

  Widget _buildInputField() {
    print('🔍 _buildInputField called');

    if (_chatProvider!.isDisposedOfChat || !mounted) {
      print(
        '❌ INPUT HIDDEN: isDisposedOfChat=${_chatProvider!.isDisposedOfChat}, mounted=$mounted',
      );
      return SizedBox.shrink();
    }

    // ✅ FIX: Only hide input if we don't have userId yet OR there's an error
    // Don't hide if userId is already loaded (even if background reload is happening)
    if (_chatProvider!.hasError ||
        (_chatProvider!.isLoadingCurrentUser &&
            _chatProvider!.currentUserId == null)) {
      print(
        '❌ INPUT HIDDEN: isLoadingCurrentUser=${_chatProvider!.isLoadingCurrentUser}, hasError=${_chatProvider!.hasError}, currentUserId=${_chatProvider!.currentUserId}',
      );
      return SizedBox.shrink();
    }

    print('✅ Basic checks passed - creating input field');

    return Align(
      alignment: Alignment.bottomCenter,
      child: Consumer<GroupProvider>(
        builder: (context, groupProvider, _) {
          return Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              print(
                '🔍 Consumer builder called - chatId=${widget.chatId}, userId=${widget.userId}',
              );

              // Check if chat should show blocked UI using new proper block logic
              final shouldShowBlocked = chatProvider.shouldShowBlockedUI(
                widget.chatId,
                widget.userId,
              );

              print('🔍 shouldShowBlocked=$shouldShowBlocked');

              if (shouldShowBlocked) {
                print('❌ INPUT HIDDEN: Showing blocked message widget instead');
                return _buildBlockedMessageWidget();
              }

              print('✅ Not blocked - showing input field');
              final isLoading = chatProvider.isSendingMessage;
              final replyMessage = chatProvider.replyToMessage;

              return _isMultiSelectMode
                  ? Container(
                    height: SizeConfig.sizedBoxHeight(65),
                    padding: SizeConfig.getPaddingSymmetric(horizontal: 25),
                    decoration: BoxDecoration(
                      color: AppThemeManage.appTheme.darkGreyColor,
                      border: Border(
                        top: BorderSide(
                          color: AppThemeManage.appTheme.greyBorder,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            hasSelectedMessages &&
                                    !_isDeletingMessages &&
                                    !_isForwardingMessages
                                // ✅ DEMO MODE: Hide delete button for demo accounts
                                ? _multiSelectAction == 'delete' && !isDemo
                                    ? InkWell(
                                      onTap: _showDeleteSelectedMessagesDialog,
                                      child: Padding(
                                        padding: SizeConfig.getPaddingOnly(
                                          right: 20,
                                        ),
                                        child: SvgPicture.asset(
                                          AppAssets.trash,
                                          colorFilter: ColorFilter.mode(
                                            AppThemeManage
                                                .appTheme
                                                .darkWhiteColor,
                                            BlendMode.srcIn,
                                          ),
                                          height: 25,
                                        ),
                                      ),
                                    )
                                    : _multiSelectAction == 'forward'
                                    ? InkWell(
                                      onTap: _showForwardChatSelectionDialog,
                                      child: Padding(
                                        padding: SizeConfig.getPaddingOnly(
                                          right: 20,
                                        ),
                                        child: SvgPicture.asset(
                                          AppAssets.chatImage.forward,
                                          colorFilter: ColorFilter.mode(
                                            AppThemeManage
                                                .appTheme
                                                .darkWhiteColor,
                                            BlendMode.srcIn,
                                          ),
                                          height: 25,
                                        ),
                                      ),
                                    )
                                    : const SizedBox.shrink()
                                : const SizedBox.shrink(),
                          ],
                        ),
                        Text(
                          "$selectedMessagesCount ${AppString.homeScreenString.messages}",
                          style: AppTypography.innerText14(context).copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                  : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (replyMessage != null)
                        _buildReplyPreview(replyMessage, chatProvider),

                      (widget.isGroupChat && groupProvider.isMembersLoading)
                          ? SizedBox.shrink()
                          : (widget.isGroupChat &&
                              !groupProvider.isMember(userID))
                          ? SizedBox.shrink()
                          : ChatKeyboard(
                            controller: _messageController,
                            focusNode: _messageFocusNode,
                            onTap: () {
                              setState(() {
                                _isAttachmentMenuOpen = false;
                              });
                            },
                            onTapSendMsg: () {
                              if (!_chatProvider!.isDisposedOfChat &&
                                  mounted &&
                                  !isLoading &&
                                  _messageController.text.trim().isNotEmpty) {
                                closeKeyboard();
                                _sendTextMessage();
                              }
                            },
                            onTapVoiceRecordOpen: () {
                              closeKeyboard();
                              voiceBottomSheet();
                            },
                            onTapPin: () {
                              if (!_chatProvider!.isDisposedOfChat && mounted) {
                                setState(() {
                                  _isAttachmentMenuOpen =
                                      !_isAttachmentMenuOpen;
                                });
                                closeKeyboard();
                              }
                            },
                            onTapCamera: () => _sendImage(isFromGallery: false),
                            onChanged: (text) {
                              debugPrint(
                                "Mounted is $mounted and isDisposedOfChats is  ${_chatProvider!.isDisposedOfChat}",
                              );
                              if (!mounted || _chatProvider!.isDisposedOfChat) {
                                return;
                              }

                              if (isURL(text.trim())) {
                                debugPrint("✅ URL detected: $text");
                              }

                              if (text.isNotEmpty && !_isTyping) {
                                _isTyping = true;
                                _sendTypingEvent(true);
                              } else if (text.isEmpty && _isTyping) {
                                _isTyping = false;
                                _sendTypingEvent(false);
                              }

                              _typingTimer?.cancel();
                              _typingTimer = Timer(Duration(seconds: 2), () {
                                if (!_chatProvider!.isDisposedOfChat &&
                                    mounted &&
                                    _isTyping) {
                                  _isTyping = false;
                                  _sendTypingEvent(false);
                                }
                              });
                            },
                            isLoading: isLoading,
                          ),
                    ],
                  );
            },
          );
        },
      ),
    );
  }

  String recordFilePath = '';
  String audioPath = '';
  Future<bool> checkPermission() async {
    if (!await Permission.microphone.isGranted) {
      PermissionStatus status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  int i = 0;
  Future<String> getFilePath() async {
    Directory storageDirectory = await getApplicationDocumentsDirectory();
    String sdPath =
        "${storageDirectory.path}/record${DateTime.now().microsecondsSinceEpoch}.acc";
    var d = Directory(sdPath);
    if (!d.existsSync()) {
      d.createSync(recursive: true);
    }
    return "$sdPath/test_${i++}.mp3";
  }

  Future<void> startRecord() async {
    try {
      if (await audioRecord.hasPermission()) {
        final dir = await getTemporaryDirectory(); // use path_provider package
        final filePath =
            '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        // await audioRecord.start();
        await audioRecord.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );
        // await audioRecord.start();
      } else {
        snackbarNew(context, msg: "Microphone permission required");
      }
    } catch (e) {
      if (kDebugMode) {
        print('Strat recording Error :::$e');
      }
    }
  }

  Future<void> stopRecord({bool isCancel = false}) async {
    final audioProvider = Provider.of<VoiceProvider>(context, listen: false);
    try {
      String? path = await audioRecord.stop();
      audioProvider.end = DateTime.now();
      audioProvider.calcDuration();
      setState(() {
        audioPath = path!;
        audioPath;
        if (kDebugMode) {
          print("audiopath --> $audioPath");
        }
        if (isCancel == false) {
          _selectedVoices = File(audioPath);
          Future.delayed(Duration(seconds: 2));
          _sendVoiceMessage();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Stop recording Error :::$e');
      }
    }
  }

  void stopTimer() {
    seconds = 0;
    newtimer?.cancel();
  }

  bool button = false;

  Future<void> _cancle() async {
    record = false;
    setState(() {
      button = false;
      record = false;
      record = false;
    });
  }

  Timer? newtimer;
  int seconds = 0;
  bool record = false;
  Future voiceBottomSheet() {
    return bottomSheetGobalWithoutTitle(
      context,
      isCrossIconHide: true,
      bottomsheetHeight: SizeConfig.sizedBoxHeight(300),
      child: StatefulBuilder(
        builder: (context, setState1) {
          final audioProvider = Provider.of<VoiceProvider>(
            context,
            listen: false,
          );
          void startTimer() {
            const oneSec = Duration(seconds: 1);
            newtimer = Timer.periodic(
              oneSec,
              (Timer timer) => setState(() {
                setState1(() {
                  seconds += 1;
                });
              }),
            );
          }

          String formatTime(int seconds) {
            int minutes = seconds ~/ 60;
            int remainingSeconds = seconds % 60;
            return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
          }

          return Column(
            children: [
              SizedBox(height: SizeConfig.height(4)),
              Stack(
                alignment: Alignment.center,
                children: [
                  record == true
                      ? MicWaveAnimation(
                        size: 60,
                        color: AppColors.appPriSecColor.primaryColor,
                      )
                      : Container(height: 120),
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(150),
                      color: AppColors.appPriSecColor.primaryColor.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        AppAssets.chatMsgTypeIcon.voiceMic,
                        color: ThemeColorPalette.getTextColor(
                          AppColors.appPriSecColor.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: SizeConfig.height(2)),
              Text(formatTime(seconds), style: AppTypography.h418(context)),
              SizedBox(height: SizeConfig.height(4)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    height: SizeConfig.height(5),
                    width: SizeConfig.width(35),
                    child: customBorderBtn(
                      context,
                      onTap: () {
                        _cancle();
                        Navigator.pop(context);
                      },
                      title: AppString.cancel,
                    ),
                  ),
                  SizedBox(
                    height: SizeConfig.height(5),
                    width: SizeConfig.width(35),
                    child: Consumer<VoiceProvider>(
                      builder: (context, voiceProvider, _) {
                        return customBtn2(
                          context,
                          onTap: () async {
                            if (record) {
                              setState1(() {
                                record = false;
                              });
                              stopTimer();
                              stopRecord();
                              Navigator.pop(context);
                              print("44444");
                            } else {
                              setState1(() {
                                record = true;
                              });
                              var audioPlayer = AudioPlayer();
                              await audioPlayer.play(
                                AssetSource("audio/notification.wav"),
                              );
                              audioPlayer.onPlayerComplete.listen((a) {
                                setState1(() {
                                  record = true;
                                });
                                audioProvider.start = DateTime.now();

                                startTimer();
                                startRecord();
                                audioProvider.isRecording = true;
                              });
                            }
                          },
                          child: Text(
                            record ? "Send" : "Start",
                            style: AppTypography.h5(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: ThemeColorPalette.getTextColor(
                                AppColors.appPriSecColor.primaryColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReplyPreview(
    chats.Records replyMessage,
    ChatProvider chatProvider,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadiusGeometry.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.appPriSecColor.secondaryColor.withValues(
                alpha: 0.2,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: AppColors.appPriSecColor.primaryColor,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Replying to ${replyMessage.user?.fullName ?? 'Unknown'}',
                        style: AppTypography.captionText(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          global.messageContentIcon(
                            context,
                            messageType: replyMessage.messageType!,
                          ),
                          SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _getReplyPreviewText(replyMessage),
                              style: AppTypography.captionText(
                                context,
                              ).copyWith(
                                color: AppColors.textColor.textGreyColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: () => chatProvider.clearReply(),
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.textColor.textBlackColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentMenu() {
    if (_chatProvider!.isDisposedOfChat || !mounted || !_isAttachmentMenuOpen) {
      return SizedBox.shrink();
    }

    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 24),
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppThemeManage.appTheme.darkGreyColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAttachmentOption(
              icon: Icons.photo,
              title: AppString.photo, //"Photo",
              onTap: () => _sendImage(),
            ),
            _buildAttachmentOption(
              icon: Icons.gif, // GIF
              title: AppString.gif,
              onTap: () {
                // Dismiss the attachment menu first
                setState(() {
                  _isAttachmentMenuOpen = false;
                });
                // Then call _sendGif
                _sendGif();
              },
            ),
            _buildAttachmentOption(
              icon: Icons.videocam,
              title: AppString.video, // Video
              onTap: _sendVideo,
            ),
            _buildAttachmentOption(
              icon: Icons.insert_drive_file,
              title: AppString.document, //"Document",
              onTap: _sendDocument,
            ),
            _buildAttachmentOption(
              icon: Icons.location_on,
              title: AppString.location, //"Location",
              onTap: _sendLocation,
              isLoading: _isSendingLocation,
            ),
            _buildAttachmentOption(
              icon: Icons.contacts,
              title: AppString.bottomNavString.contact, //"Contact",
              onTap: _sendContact,
              isDivider: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Build loading overlay for clear chat operation
  Widget _buildClearChatLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(20),
            margin: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                commonLoading(),
                SizedBox(height: 16),
                Text(
                  '${AppString.clearingChat}...',
                  style: AppTypography.h4(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  AppString.pleaseWaitWhileWeClearAllMessages,
                  style: AppTypography.captionText(
                    context,
                  ).copyWith(color: AppColors.textColor.textGreyColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDivider = true,
    bool isLoading = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: isLoading ? null : onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        AppColors.appPriSecColor.secondaryColor,
                        AppColors.appPriSecColor.primaryColor,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child:
                      isLoading
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: commonLoading(),
                          )
                          : Icon(
                            icon,
                            color: AppColors.appPriSecColor.primaryColor,
                            size: 20,
                          ),
                ),
                SizedBox(width: 16),
                Text(title, style: AppTypography.mediumText(context)),
              ],
            ),
          ),
        ),
        if (isDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppThemeManage.appTheme.borderColor,
            indent: 60,
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION & NAVIGATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// 🚀 PERFORMANCE: Check cache synchronously to prevent loading flicker
  void _checkCacheAvailability() {
    try {
      String? chatIdString;

      if (widget.chatId != null && widget.chatId! > 0) {
        // Existing chat/group chat
        chatIdString = widget.chatId.toString();
        _logger.d("🔍 CACHE CHECK: Group/existing chat - ID: $chatIdString");
      } else if (widget.userId != null && widget.userId! > 0) {
        // Individual chat using userId
        chatIdString = 'user_${widget.userId}';
        _logger.d(
          "🔍 CACHE CHECK: Individual chat - Peer ID: ${widget.userId}",
        );
      }

      if (chatIdString != null) {
        _chatProvider!.setHasCachedData(
          ChatCacheManager.hasPage(chatIdString, 1),
        );
        _logger.d(
          "🎯 CACHE CHECK: Chat $chatIdString has cached data: ${_chatProvider!.hasCachedData}",
        );

        // If we have cache, we can skip loading indicators
        if (_chatProvider!.hasCachedData) {
          _logger.d(
            "⚡ PERFORMANCE: Cache detected - will prevent loading flicker",
          );
        }
      } else {
        _logger.w("⚠️ CACHE CHECK: Cannot determine chat ID for cache check");
        _chatProvider!.setHasCachedData(false);
      }
    } catch (e) {
      _logger.e("❌ Error checking cache availability: $e");
      _chatProvider!.setHasCachedData(false);
    }
  }

  Future<void> _initializeScreen() async {
    if (_chatProvider!.isDisposedOfChat) return;

    try {
      _logger.d("🚀 Starting screen initialization");
      _chatProvider!.setIsInitializingOfChat(true);

      await _loadCurrentUserId();
      if (_chatProvider!.isDisposedOfChat) return;

      if (!mounted) return;
      _chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (_chatProvider == null) {
        throw Exception('ChatProvider not available');
      }

      _logger.d(
        "📝 Setting current chat context: chatId=${widget.chatId}, userId=${widget.userId}",
      );
      _chatProvider!.setCurrentChat(widget.chatId ?? 0, widget.userId ?? 0);

      await Future.delayed(Duration(milliseconds: 100));
      if (_chatProvider!.isDisposedOfChat) return;

      _logger.d("📨 Loading chat messages");
      await _chatProvider!.loadChatMessages(
        chatId: widget.chatId ?? 0,
        peerId: widget.userId ?? 0,
        clearExisting: true,
      );

      if (_chatProvider!.isDisposedOfChat) return;

      await Future.delayed(Duration(milliseconds: 500));
      if (_chatProvider!.isDisposedOfChat) return;

      await _chatProvider!.checkUserOnlineStatusFromApi();

      // Load group members for group chats
      if (isGroupChat) {
        await _loadGroupMembers();
      }

      _chatProvider!.setIsInitialized(true);
      _chatProvider!.setIsInitializingOfChat(false);
      _chatProvider!.setHasError(false);
      _chatProvider!.setErrorMessage(null);

      if (mounted) {
        setState(() {});
      }

      _logger.d("✅ Screen initialization completed successfully");
      _debugPinnedMessagesState();
    } catch (e, stackTrace) {
      _logger.e("❌ Error during initialization: $e");
      _logger.e("📍 Stack trace: $stackTrace");

      _chatProvider!.setHasError(true);
      _chatProvider!.setErrorMessage(e.toString());
      _chatProvider!.setIsInitializingOfChat(false);

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadGroupMembers() async {
    if (_chatProvider!.isDisposedOfChat || !isGroupChat) return;

    try {
      _logger.d("👥 Loading group members for chatId: ${widget.chatId}");
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      await groupProvider.getGroupMembers(chatId: widget.chatId ?? 0);
      _logger.d("✅ Group members loaded successfully");
    } catch (e) {
      _logger.e("❌ Error loading group members: $e");
      // Don't throw error as this is not critical for basic chat functionality
    }
  }

  Future<void> _initializeChat() async {
    if (_chatProvider!.isDisposedOfChat ||
        _chatProvider!.isInitializingOfChat ||
        _chatProvider!.currentUserId == null) {
      _logger.d(
        "Chat initialization skipped - disposed: $_chatProvider!.isDisposedOfChat, initializing: ${_chatProvider!.isInitializingOfChat}, currentUserId: $_chatProvider!.currentUserId",
      );
      return;
    }

    _chatProvider!.setIsInitializingOfChat(true);

    try {
      final chatProvider =
          _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
      int chatId = widget.chatId ?? 0;

      _logger.d(
        "Initializing chat with chatId: $chatId, userId: ${widget.userId}",
      );

      if (!_chatProvider!.isDisposedOfChat && mounted) {
        await chatProvider.loadChatMessages(
          chatId: chatId,
          peerId: widget.userId ?? 0,
          clearExisting: true,
        );
      }

      if (!_chatProvider!.isDisposedOfChat) {
        _chatProvider!.setIsInitialized(true);
        _logger.d("Chat initialization completed successfully");
      }
    } catch (e) {
      _logger.e("Error initializing chat: $e");
      if (!_chatProvider!.isDisposedOfChat) {
        setState(() {
          _chatProvider!.setHasError(true);
          _chatProvider!.setErrorMessage(
            "Failed to load chat: ${e.toString()}",
          );
        });
      }
    } finally {
      if (!_chatProvider!.isDisposedOfChat) {
        _chatProvider!.setIsInitializingOfChat(false);
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  Future<void> _loadCurrentUserId() async {
    try {
      // ✅ Set loading to true at start
      if (!_chatProvider!.isDisposedOfChat) {
        setState(() {
          _chatProvider!.setIsLoadingCurrentUser(true);
        });
      }

      _chatProvider!.setCurrentUserId(
        await SecurePrefs.getString(SecureStorageKeys.USERID),
      );

      _logger.d("Current user ID loaded: $_chatProvider!.currentUserId");

      if (_chatProvider!.currentUserId == null ||
          _chatProvider!.currentUserId!.isEmpty) {
        throw Exception("User ID is null or empty");
      }
    } catch (e) {
      _logger.e("Error loading current user ID: $e");
      rethrow;
    } finally {
      // ✅ Always set loading to false regardless of success or failure
      if (!_chatProvider!.isDisposedOfChat) {
        setState(() {
          _chatProvider!.setIsLoadingCurrentUser(false);
        });
      }
    }
  }

  // void _navigateBack() {
  //   if (_chatProvider!.isDisposedOfChat) return;

  //   _logger.d(
  //     "🔙 Navigating back - clearing chat focus first (fromArchive: ${widget.fromArchive})",
  //   );
  //   _chatProvider!.setScreenActive(false, widget.chatId, widget.userId);

  //   Future.delayed(Duration(milliseconds: 100), () {
  //     if (mounted && !_chatProvider!.isDisposedOfChat) {
  //       // Simply pop back to the previous screen
  //       // The navigation stack will properly return to archive list or chat list
  //       // based on where the user came from
  //       Navigator.of(context).pop();
  //     }
  //   });
  // }

  void _navigateBack() async {
    if (_chatProvider!.isDisposedOfChat) return;

    _chatProvider!.setScreenActive(false, widget.chatId, widget.userId);

    await Future.delayed(Duration(milliseconds: 100));

    if (mounted && !_chatProvider!.isDisposedOfChat) {
      // Use the same navigation logic as system back button
      final shouldPop = await _handleBackNavigation();
      if (shouldPop) {
        Navigator.of(context).pop();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FOCUS & TYPING MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  // void _setScreenActive(bool isActive) {
  //   if (_chatProvider!.isDisposedOfChat || _chatProvider == null) return;

  //   _isScreenActive = isActive;

  //   _logger.d(
  //     'Setting OneToOneChat screen active: $isActive, chatId: ${widget.chatId}, userId: ${widget.userId}',
  //   );

  //   _chatProvider!.setChatScreenActive(
  //     widget.chatId ?? 0,
  //     widget.userId ?? 0,
  //     isActive: isActive,
  //   );

  //   if (!isActive) {
  //     _logger.d('🚫 Chat screen deactivated - should stop auto-mark seen');
  //   }

  //   if (isActive && widget.chatId != null && widget.chatId! > 0) {
  //     // Check block status when screen becomes active
  //     // First refresh the data to ensure we have the latest state
  //     // Block status is now handled via Provider Consumer pattern - no manual checks needed

  //     Future.delayed(Duration(milliseconds: 1000), () {
  //       if (!_chatProvider!.isDisposedOfChat &&
  //           _isScreenActive &&
  //           _chatProvider != null &&
  //           _chatProvider!.isChatScreenActive &&
  //           _chatProvider!.isAppInForeground) {
  //         _logger.d('📱 Screen is fully active, marking messages as seen');
  //         _chatProvider!.markChatMessagesAsSeen(widget.chatId!);
  //       }
  //     });
  //   }
  // }

  void _sendTypingEvent(bool isTyping) {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

    final currentChatId = chatProvider.currentChatData.chatId ?? 0;

    _logger.d(
      "Sending typing event - ChatId: $currentChatId, UserId: ${widget.userId}, IsTyping: $isTyping",
    );

    chatProvider.sendTypingStatus(currentChatId, isTyping);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONLINE STATUS & USER DATA METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isUserOnlineFromChatListOrApi(ChatProvider chatProvider) {
    final isOnlineFromSocket = chatProvider.isUserOnline(widget.userId ?? 0);

    if (isOnlineFromSocket) {
      return true;
    }

    final chatListData = chatProvider.chatListData;
    bool userFoundInChatList = false;

    if (chatListData.chats.isNotEmpty) {
      for (final chat in chatListData.chats) {
        final peerUserData = chat.peerUserData;
        if (peerUserData != null && peerUserData.userId == widget.userId) {
          userFoundInChatList = true;
          break;
        }
      }
    }

    if (!userFoundInChatList) {
      return _isUserOnlineFromApi;
    }

    return false;
  }

  String? _getLastSeenTimeFromChatListOrApi(ChatProvider chatProvider) {
    _logger.d(
      "Getting last seen time from chat list for userId: ${widget.userId}",
    );

    final chatListData = chatProvider.chatListData;
    if (chatListData.chats.isEmpty) {
      _logger.w("No chat list data available, using API data");
      return chatProvider.lastSeenFromApi;
    }

    _logger.d("Searching through ${chatListData.chats.length} chats");

    for (final chat in chatListData.chats) {
      final peerUserData = chat.peerUserData;

      if (peerUserData != null && peerUserData.userId == widget.userId) {
        _logger.d("Found matching peer user data for userId: ${widget.userId}");

        // Try to get fresh timestamp from socket first
        final socketLastSeen = chatProvider.socketEventController
            .getUserLastSeen(widget.userId ?? 0);
        if (socketLastSeen != null && socketLastSeen.trim().isNotEmpty) {
          _logger.i("Using fresh last seen from socket: $socketLastSeen");
          return socketLastSeen;
        }

        // Fall back to peer user data updatedAt
        final lastSeen = peerUserData.updatedAt;
        if (lastSeen != null && lastSeen.trim().isNotEmpty) {
          _logger.i("Found last seen from peer user data: $lastSeen");
          return lastSeen;
        } else {
          _logger.w("PeerUserData.updatedAt is null or empty");
        }

        // Final fallback to createdAt
        final createdAt = peerUserData.createdAt;
        if (createdAt != null && createdAt.trim().isNotEmpty) {
          _logger.i("Using createdAt as fallback: $createdAt");
          return createdAt;
        }
      }
    }

    _logger.w("User ${widget.userId} not found in chat list, using API data");
    return chatProvider.lastSeenFromApi ?? widget.updatedAt;
  }

  // Future<void> _checkUserOnlineStatusFromApi() async {
  //   if (_chatProvider!.isDisposedOfChat || !mounted) return;

  //   try {
  //     setState(() {
  //       _isLoadingOnlineStatus = true;
  //     });

  //     final chatProvider =
  //         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

  //     final response = await chatProvider.checkUserOnlineStatus(
  //       widget.userId ?? 0,
  //     );

  //     if (!_chatProvider!.isDisposedOfChat && mounted && response != null) {
  //       setState(() {
  //         _isUserOnlineFromApi = response['isOnline'] ?? false;
  //         _lastSeenFromApi = response['udatedAt'];
  //         _isLoadingOnlineStatus = false;
  //       });

  //       _logger.d(
  //         "User ${widget.userId} online status from API: $_isUserOnlineFromApi, lastSeen: $_lastSeenFromApi",
  //       );
  //     } else {
  //       if (!_chatProvider!.isDisposedOfChat && mounted) {
  //         setState(() {
  //           _isLoadingOnlineStatus = false;
  //         });
  //       }
  //     }
  //   } catch (e) {
  //     _logger.e("Error checking user online status from API: $e");
  //     if (!_chatProvider!.isDisposedOfChat && mounted) {
  //       setState(() {
  //         _isLoadingOnlineStatus = false;
  //       });
  //     }
  //   }
  // }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE SENDING METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  void _sendTextMessage() {
    if (_chatProvider!.isDisposedOfChat ||
        !mounted ||
        _messageController.text.trim().isEmpty) {
      return;
    }

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
    final chatId = widget.chatId ?? 0;
    final replyToMessageId = chatProvider.replyToMessage?.messageId;

    _logger.d(
      "Sending message to ${chatId == 0 ? 'new user' : 'existing chat'}: ${widget.userId}, replyTo: $replyToMessageId",
    );

    chatProvider
        .sendMessage(
          chatId: chatId,
          _messageController.text.trim(),
          messageType:
              isURL(_messageController.text.trim())
                  ? MessageType.Link
                  : MessageType.Text,
          replyToMessageId: replyToMessageId,
        )
        .then((success) {
          if (!_chatProvider!.isDisposedOfChat && mounted) {
            if (success) {
              _messageController.clear();
              _sendTypingEvent(false);

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_chatProvider!.isDisposedOfChat && mounted) {
                  _scrollToBottom(animated: true, forceScroll: true);
                }
              });
            } else {
              // Check if there's an API error message to show
              final apiError = chatProvider.apiErrorMessage;
              if (apiError != null && apiError.isNotEmpty) {
                snackbarNew(context, msg: apiError);
                chatProvider.clearApiErrorMessage();
              }
            }
          }
        });
  }

  void _sendVoiceMessage() {
    if (_chatProvider!.isDisposedOfChat || !mounted
    // ||_messageController.text.trim().isEmpty
    ) {
      return;
    }

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
    final chatId = widget.chatId ?? 0;
    final replyToMessageId = chatProvider.replyToMessage?.messageId;

    _logger.d(
      "Sending message to ${chatId == 0 ? 'new user' : 'existing chat'}: ${widget.userId}, replyTo: $replyToMessageId",
    );
    chatProvider.setShareVoice(_selectedVoices!);

    chatProvider
        .sendMessage(
          chatId: chatId,
          "",
          messageType: MessageType.Voice,
          replyToMessageId: replyToMessageId,
        )
        .then((success) {
          if (!_chatProvider!.isDisposedOfChat && mounted) {
            if (success) {
              _selectedVoices = null;
              _sendTypingEvent(false);

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_chatProvider!.isDisposedOfChat && mounted) {
                  _scrollToBottom(animated: true, forceScroll: true);
                }
              });
            } else {
              // Check if there's an API error message to show
              final apiError = chatProvider.apiErrorMessage;
              if (apiError != null && apiError.isNotEmpty) {
                snackbarNew(context, msg: apiError);
                chatProvider.clearApiErrorMessage();
              }
            }
          }
        });
  }

  void _sendAttachmentMessage(MessageType messageType) {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
    final chatId = widget.chatId ?? 0;
    final replyToMessageId = chatProvider.replyToMessage?.messageId;

    _logger.d(
      "Sending message to ${chatId == 0 ? 'new user' : 'existing chat'}: ${widget.userId}, replyTo: $replyToMessageId",
    );

    switch (messageType) {
      case MessageType.Image:
      case MessageType.Gif:
        if (_selectedImages != null) {
          chatProvider.setShareImage(_selectedImages!);
        }
        break;
      case MessageType.File:
        if (_selectedDocuments != null) {
          chatProvider.setShareDocument(_selectedDocuments!);
        }
        break;
      case MessageType.Video:
        if (_selectedVideos != null) {
          chatProvider.setShareVideo(_selectedVideos!, _videoThumbnail);
        }
        break;
      default:
        break;
    }

    chatProvider
        .sendMessage(
          chatId: chatId,
          "",
          messageType: messageType,
          replyToMessageId: replyToMessageId,
        )
        .then((success) {
          if (!_chatProvider!.isDisposedOfChat && mounted) {
            if (success) {
              _selectedImages = null;
              _selectedDocuments = null;
              _selectedVideos = null;
              _videoThumbnail = "";

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });
            } else {
              // Check if there's an API error message to show
              final apiError = chatProvider.apiErrorMessage;
              if (apiError != null && apiError.isNotEmpty) {
                snackbarNew(context, msg: apiError);
                chatProvider.clearApiErrorMessage();
              }
            }
          }
          closeKeyboard();
        });

    if (mounted) {
      setState(() {
        _isAttachmentMenuOpen = false;
      });
    }
  }

  Future<void> _sendImage({bool isFromGallery = true}) async {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    if (isFromGallery) {
      // Use ImagePicker for gallery to open Photos app on iOS instead of Files app
      final images = await pickImages(source: ImageSource.gallery);
      if (images != null &&
          images.isNotEmpty &&
          !_chatProvider!.isDisposedOfChat &&
          mounted) {
        _selectedImages = images;
        _sendAttachmentMessage(MessageType.Image);
      }
    } else {
      final images = await pickImages(source: ImageSource.camera);
      if (images != null &&
          images.isNotEmpty &&
          !_chatProvider!.isDisposedOfChat &&
          mounted) {
        _selectedImages = images;
        _sendAttachmentMessage(MessageType.Image);
      }
    }
  }

  Future<void> _sendGif() async {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    try {
      _logger.d("Starting GIF picker...");

      // Launch Giphy GIF picker
      final gif = await GiphyGet.getGif(
        context: context,
        apiKey:
            "rAw1eL2UQZBkFdNsKjCsCAJNBT4Lrslg", // Demo key - replace with your actual Giphy API key later
        lang: GiphyLanguage.english,
        randomID: "abcd", // Optional: for analytics
        searchText: "Search GIFs", // Placeholder text
        tabColor: AppColors.appPriSecColor.primaryColor,
        debounceTimeInMilliseconds: 350,
      );

      _logger.d(
        "GIF picker result: ${gif != null ? 'GIF selected' : 'No GIF selected'}",
      );

      if (gif != null && !_chatProvider!.isDisposedOfChat && mounted) {
        _logger.d("GIF object: ${gif.toString()}");
        _logger.d("GIF images: ${gif.images?.toString()}");

        // Get the GIF URL - try different formats
        String? gifUrl;

        // Try original first
        if (gif.images?.original != null) {
          gifUrl = gif.images!.original!.url;
        }

        // Fallback to fixed height
        if ((gifUrl == null || gifUrl.isEmpty) &&
            gif.images?.fixedHeight != null) {
          gifUrl = gif.images!.fixedHeight!.url;
        }

        // Fallback to downsized
        if ((gifUrl == null || gifUrl.isEmpty) &&
            gif.images?.downsized != null) {
          gifUrl = gif.images!.downsized!.url;
        }

        // Try different properties if above don't work
        if (gifUrl == null || gifUrl.isEmpty) {
          gifUrl = gif.url ?? gif.bitlyGifUrl ?? gif.bitlyUrl;
        }

        _logger.d("Extracted GIF URL: $gifUrl");

        if (gifUrl != null && gifUrl.isNotEmpty) {
          // Send the GIF URL directly as message content
          final chatProvider =
              _chatProvider ??
              Provider.of<ChatProvider>(context, listen: false);
          final chatId = widget.chatId ?? 0;

          final replyToMessageId = chatProvider.replyToMessage?.messageId;

          _logger.d(
            "Sending GIF message - ChatID: $chatId, URL: $gifUrl, MessageType: ${MessageType.Gif}",
          );

          // For GIF URLs from external sources (like Giphy), we send them directly
          chatProvider
              .sendMessage(
                chatId: chatId,
                gifUrl,
                messageType: MessageType.Gif,
                replyToMessageId: replyToMessageId,
              )
              .then((success) {
                _logger.d("GIF message send result: $success");

                if (!_chatProvider!.isDisposedOfChat && mounted && success) {
                  // Clear reply message if it exists
                  if (chatProvider.replyToMessage != null) {
                    chatProvider.clearReply();
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom(forceScroll: true);
                  });
                } else {
                  _logger.e("Failed to send GIF message");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppString.failedToSendGIFPleaseTryAgain),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
                closeKeyboard();
              });
        } else {
          _logger.e("GIF URL is null or empty");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppString.couldGIFURLPleaseTryAgain),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        _logger.d("GIF picker was cancelled or returned null");
      }
    } catch (e) {
      _logger.e("Error picking GIF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppString.errorSelectingGIFPleaseTryAgain),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendVideo() async {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    // Use ImagePicker for videos to open Photos app on iOS instead of Files app
    final videos = await pickVideo(source: ImageSource.gallery);
    if (videos != null &&
        videos.isNotEmpty &&
        !_chatProvider!.isDisposedOfChat &&
        mounted) {
      _selectedVideos = videos;
      _sendAttachmentMessage(MessageType.Video);
    }
  }

  Future<void> _sendDocument() async {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    final allowedExtensions = MessageTypeUtils.getAllowedExtensions(
      MessageType.File,
    );

    FilePickerResult? pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: allowedExtensions,
    );

    if (pickedFile != null && !_chatProvider!.isDisposedOfChat && mounted) {
      _selectedDocuments =
          pickedFile.files.map((platformFile) {
            return File(platformFile.path!);
          }).toList();
      _sendAttachmentMessage(MessageType.File);
    }
  }

  void _sendLocation() async {
    if (_chatProvider!.isDisposedOfChat || !mounted || _isSendingLocation) {
      return;
    }

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
    final chatId = widget.chatId ?? 0;
    final replyToMessageId = chatProvider.replyToMessage?.messageId;

    _logger.d(
      "Sending message to ${chatId == 0 ? 'new user' : 'existing chat'}: ${widget.userId}, replyTo: $replyToMessageId",
    );

    // Show loading state but keep dialog open
    if (mounted) {
      setState(() {
        _isSendingLocation = true;
      });
    }

    try {
      // Get user's current location
      final locationService = LocationService();
      await locationService.checkLocationPermission();
      await locationService.getCurrentLocation();

      // final locationData =
      //     "${locationService.latitude},${locationService.longitude}";

      if (!mounted) return;
      final locationData = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => LocationScreen(
                userLocation: locationService.locationAddress!,
                latitude: locationService.latitude,
                longitude: locationService.longitude,
              ),
        ),
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      if (locationData != null) {
        log("Navigator_POP:$locationData");
        chatProvider
            .sendMessage(
              chatId: chatId,
              locationData,
              messageType: MessageType.Location,
              replyToMessageId: replyToMessageId,
            )
            .then((success) {
              if (!_chatProvider!.isDisposedOfChat && mounted) {
                setState(() {
                  _isSendingLocation = false;
                  _isAttachmentMenuOpen = false; // Dismiss dialog after success
                });
                if (success) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom(forceScroll: true);
                  });
                }
              }
              closeKeyboard();
            });
      } else {
        closeKeyboard();
        setState(() {
          _isSendingLocation = false;
          _isAttachmentMenuOpen = false; // Dismiss dialog after success
        });
        if (!_chatProvider!.isDisposedOfChat && mounted) {
          setState(() {
            _isSendingLocation = false;
            _isAttachmentMenuOpen = false; // Dismiss dialog after success
          });
        }
      }
    } catch (e) {
      closeKeyboard();
      debugPrint("Error getting location: $e");
      // Fallback to default location if location access fails
      const locationData = "40.7128,-74.0060";
      chatProvider
          .sendMessage(
            chatId: chatId,
            locationData,
            messageType: MessageType.Location,
            replyToMessageId: replyToMessageId,
          )
          .then((success) {
            if (!_chatProvider!.isDisposedOfChat && mounted) {
              setState(() {
                _isSendingLocation = false;
                _isAttachmentMenuOpen = false; // Dismiss dialog after success
              });
              if (success) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom(forceScroll: true);
                });
              }
            }
          });
    }
  }

  void _sendContact() async {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    setState(() {
      _isAttachmentMenuOpen = false;
    });

    try {
      // Show contact picker dialog
      final selectedContact = await _showContactPicker();

      if (selectedContact != null) {
        if (!mounted) return;
        final chatProvider =
            _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
        final chatId = widget.chatId ?? 0;
        final replyToMessageId = chatProvider.replyToMessage?.messageId;

        _logger.d(
          "Sending message to ${chatId == 0 ? 'new user' : 'existing chat'}: ${widget.userId}, replyTo: $replyToMessageId",
        );

        // Send contact message with both name and phone number
        // Format: "Name,PhoneNumber" so we can split it later
        final messageContent =
            '${selectedContact.name},${selectedContact.phoneNumber}';

        chatProvider
            .sendMessage(
              chatId: chatId,
              messageContent,
              messageType: MessageType.Contact,
              replyToMessageId: replyToMessageId,
            )
            .then((success) {
              if (success && mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom(forceScroll: true);
                });
              }
              closeKeyboard();
            });
      }
    } catch (e) {
      debugPrint('Error sending contact: $e');
    }
  }

  Future<ContactModel?> _showContactPicker() async {
    return showModalBottomSheet<ContactModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ContactPickerBottomSheet();
      },
    );
  }

  Future<List<File>?> pickImages({required ImageSource source}) async {
    if (_chatProvider!.isDisposedOfChat || !mounted) return null;

    try {
      final XFile? pickedImage = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedImage != null && !_chatProvider!.isDisposedOfChat && mounted) {
        return [File(pickedImage.path)];
      }
      return null;
    } catch (e) {
      _logger.e('Error picking image: $e');
      return null;
    }
  }

  Future<List<File>?> pickVideo({required ImageSource source}) async {
    if (_chatProvider!.isDisposedOfChat || !mounted) return null;

    try {
      final XFile? pickedVideo = await ImagePicker().pickVideo(source: source);

      if (pickedVideo != null && !_chatProvider!.isDisposedOfChat && mounted) {
        return [File(pickedVideo.path)];
      }
      return null;
    } catch (e) {
      _logger.e('Error picking video: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE INTERACTION HANDLERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _handleLongPress(chats.Records message) async {
    if (!_chatProvider!.isDisposedOfChat &&
        mounted &&
        message.deletedForEveryone != true) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      final isCurrentlyStarred = chatProvider.isMessageStarred(
        message.messageId!,
      );

      _logger.d(
        'Long press on message ${message.messageId} - currently starred: $isCurrentlyStarred',
      );

      // Enhanced: Add multi-select callback for all selectable messages
      final result = await chatTypeDailog(
        context,
        message: message,
        onPinUnpin: _handlePinUnpinMessage,
        onReply: _handleReply,
        onDelete: _handleDeleteMessage,
        onStarUnstar: _handleStarUnstarMessage,
        // Enhanced: Add multi-select option for selectable messages
        onMultiSelect:
            _isMessageSelectableForMultiSelect(message)
                ? _handleMultiSelectStart
                : null,
        isStarred: isCurrentlyStarred,
      );

      if (!mounted || result == null) return;

      setState(() {
        _multiSelectAction = result; // Store 'delete' or 'forward'
        debugPrint("😊😊RESULT:$_multiSelectAction");
      });
    }
  }

  // void _handleMultiDeleteStart(chats.Records message) {
  //   if (_chatProvider!.isDisposedOfChat || !mounted) return;

  //   _logger.d(
  //     '🗑️ Starting multi-delete mode from message: ${message.messageId}',
  //   );

  //   // Enter multi-delete mode and select the initial message
  //   _enterMultiDeleteMode();
  //   _toggleMessageSelection(message.messageId!);
  // }

  void _handleReply(chats.Records message) {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

    chatProvider.setReplyToMessage(message);
    _messageFocusNode.requestFocus();

    _logger.d('Reply set for message: ${message.messageId}');
  }

  void _handleImageTap(String imageUrl) {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    context.viewImage(
      imageSource: imageUrl,
      imageTitle: 'Chat Image',
      heroTag: imageUrl,
    );
  }

  void _handleVideoTap(String videoUrl) {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;
    debugPrint('video tap url : $videoUrl');
    context.viewVideo(videoUrl: videoUrl);
  }

  void _handleDocumentTap(chats.Records chat) {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

    chatProvider.downloadPdfWithProgress(
      pdfUrl: chat.messageContent!,
      onProgress: (progress) {
        _logger.d("Download progress: ${(progress * 100).toInt()}%");
      },
      onComplete: (filePath, metadata) {
        if (filePath != null) {
          _logger.d("Document downloaded: $filePath");
          _openDocument(filePath);
        } else {
          _logger.e("Document download failed: $metadata");
          _showDocumentError(metadata ?? "Download failed");
        }
      },
    );
  }

  void _handleLocationTap(double latitude, double longitude) {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;
    // Implement location viewing logic
  }

  /// Handle back navigation based on source with switch cases
  Future<bool> _handleBackNavigation() async {
    try {
      // Get the navigation source from route arguments
      final arguments =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final navigationSource = _getNavigationSource(arguments);
      final bool fromProfileOrGroupInfo =
          arguments?['fromProfileOrGroupInfo'] as bool? ?? false;

      _logger.d("🔙 Handling back navigation from source: $navigationSource");

      switch (navigationSource) {
        // case NavigationSource.starredMessages:
        //   // When coming from starred messages, go back to profile view
        //   _logger.d("🔙 Back from starred messages -> profile view");
        //   Navigator.of(context).pop();
        //   return false;

        case NavigationSource.starredMessages:
          // When coming from starred messages via profile/group info, go back to main screen
          if (fromProfileOrGroupInfo) {
            Navigator.of(context).popUntil((route) {
              return route.settings.name == AppRoutes.home ||
                  route.settings.name == AppRoutes.tabbar ||
                  route.isFirst;
            });
            return false;
          } else {
            // Normal back behavior when not from profile/group info
            return true;
          }
        case NavigationSource.userProfile:
          // When coming from user profile, normal back behavior
          _logger.d("🔙 Back from user profile -> previous screen");
          return true;

        case NavigationSource.chatList:
          // When coming from chat list, normal back behavior
          _logger.d("🔙 Back from chat list -> home screen");
          return true;

        case NavigationSource.archive:
          // When coming from archive, normal back behavior
          _logger.d("🔙 Back from archive -> archive list");
          return true;

        case NavigationSource.unknown:
          // Default behavior for unknown sources
          _logger.d("🔙 Back from unknown source -> default behavior");
          return true;
      }
    } catch (e) {
      _logger.e("❌ Error in back navigation handling: $e");
      return true;
    }
  }

  /// Determine navigation source based on route arguments and widget properties
  NavigationSource _getNavigationSource(Map<String, dynamic>? arguments) {
    // Check widget properties first
    if (widget.fromArchive) {
      return NavigationSource.archive;
    }

    // Check route arguments
    if (arguments != null) {
      final String? source = arguments['navigationSource'] as String?;
      final bool fromStarred =
          arguments['fromStarredMessages'] as bool? ?? false;
      final bool fromProfile = arguments['fromUserProfile'] as bool? ?? false;

      if (fromStarred || source == 'starred_messages') {
        return NavigationSource.starredMessages;
      }

      if (fromProfile || source == 'user_profile') {
        return NavigationSource.userProfile;
      }

      if (source == 'chat_list') {
        return NavigationSource.chatList;
      }

      if (source == 'archive') {
        return NavigationSource.archive;
      }
    }

    return NavigationSource.chatList; // Default to chat list
  }

  void _openDocument(String filePath) {
    _logger.d("Opening document: $filePath");
    final fileName = filePath.split('/').last;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                PdfViewerScreen(filePath: filePath, fileName: fileName),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PIN/UNPIN MESSAGE METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // PIN/UNPIN MESSAGE HANDLER
  // ═══════════════════════════════════════════════════════════════════════════

  /// Handles pin/unpin message operations
  ///
  /// This method:
  /// - Validates permissions before allowing pin/unpin operations
  /// - Shows duration selection dialog for pinning new messages
  /// - Directly unpins if message is already pinned
  /// - Provides user feedback throughout the process
  /// - Handles errors gracefully with appropriate notifications
  Future<void> _handlePinUnpinMessage(chats.Records message) async {
    if (_chatProvider!.isDisposedOfChat ||
        !mounted ||
        _chatProvider!.currentUserId == null) {
      return;
    }

    try {
      final chatProvider =
          _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
      final chatId = widget.chatId ?? 0;

      // Validate chat ID and message ID
      if (chatId <= 0 || message.messageId == null) {
        _logger.w("Invalid chat ID or message ID for pin/unpin");
        return;
      }

      // Check if user has permission to pin/unpin messages
      if (!chatProvider.canPinUnpinMessage(message)) {
        final permissionText = chatProvider.getPinUnpinPermissionText(message);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(permissionText),
              backgroundColor: AppColors.textColor.textErrorColor,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // If message is already pinned, unpin it directly
      if (message.pinned == true) {
        _logger.d(
          '🔧 Message ${message.messageId} is pinned, unpinning directly',
        );
        await _executePinUnpinAction(
          chatProvider,
          chatId,
          message.messageId!,
          0, // 0 days means unpin
        );
        return;
      }

      // If message is not pinned, show duration selection dialog
      _logger.d(
        '🔧 Message ${message.messageId} is not pinned, showing duration dialog',
      );
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: const Color.fromRGBO(0, 0, 0, 0.57),
        builder: (BuildContext context) {
          return PinDurationDialog(
            onDurationSelected: (int days) async {
              _logger.d('🔧 Duration selected: $days days');
              await _executePinUnpinAction(
                chatProvider,
                chatId,
                message.messageId!,
                days,
              );
            },
          );
        },
      );
    } catch (e) {
      _logger.e("❌ Error handling pin/unpin message: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text("Error: ${e.toString()}")),
              ],
            ),
            backgroundColor: AppColors.textColor.textErrorColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Executes the actual pin/unpin operation via API
  ///
  /// Parameters:
  /// - [chatProvider]: The chat provider instance
  /// - [chatId]: The chat ID
  /// - [messageId]: The message ID to pin/unpin
  /// - [days]: Duration in days (0 = unpin, -1 = lifetime, >0 = specific duration)
  Future<void> _executePinUnpinAction(
    ChatProvider chatProvider,
    int chatId,
    int messageId,
    int days,
  ) async {
    try {
      // Log the operation details
      _logger.d('🔧 Pin/Unpin Request:');
      _logger.d('  Message ID: $messageId');
      _logger.d('  Chat ID: $chatId');
      _logger.d('  Duration (days): $days');
      _logger.d('  Current User ID: $_chatProvider!.currentUserId');

      // Clear any existing notifications
      ScaffoldMessenger.of(context).clearSnackBars();

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ThemeColorPalette.getTextColor(
                      AppColors.appPriSecColor.primaryColor,
                    ), //AppColors.black,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  "${days == 0 ? AppString.unpinning : AppString.pinning} ${AppString.message}...",
                  style: TextStyle(
                    color: ThemeColorPalette.getTextColor(
                      AppColors.appPriSecColor.primaryColor,
                    ), //AppColors.black
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Execute the pin/unpin operation via API
      final success = await chatProvider.pinUnpinMessage(
        chatId,
        messageId,
        days, // Pass the selected days duration
      );

      // Clear loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      // Log the result
      _logger.d('🔧 Pin/Unpin Result: $success');

      if (success && mounted) {
        // Show success message with appropriate text
        String successMessage;
        if (days == 0) {
          successMessage = AppString.messageUnpinnedSuccessfully;
        } else if (days == -1) {
          successMessage = AppString.messagePinnedForLifetime;
        } else {
          successMessage =
              "${AppString.messagePinnedFor} $days ${days > 1 ? AppString.days : AppString.day}";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: ThemeColorPalette.getTextColor(
                    AppColors.appPriSecColor.primaryColor,
                  ), //AppColors.black
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    successMessage,
                    style: TextStyle(
                      color: ThemeColorPalette.getTextColor(
                        AppColors.appPriSecColor.primaryColor,
                      ), //AppColors.black
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
            duration: Duration(seconds: 2),
          ),
        );

        // Force UI update to reflect the changes
        _logger.d('🔧 Forcing UI update after pin/unpin');
        if (mounted) {
          setState(() {
            // This will trigger a rebuild to show updated pin status
          });
        }
      } else if (mounted) {
        // Show error message if operation failed
        final errorMessage =
            chatProvider.error ??
            "Failed to ${days == 0 ? 'unpin' : 'pin'} message";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: AppColors.textColor.textErrorColor,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Debug: Log current pinned messages count after operation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_chatProvider!.isDisposedOfChat && mounted) {
          final currentPinnedCount =
              chatProvider.pinnedMessagesData.records?.length ?? 0;
          _logger.d(
            '🔧 After pin/unpin - Pinned messages count: $currentPinnedCount',
          );
        }
      });
    } catch (e) {
      _logger.e("❌ Error executing pin/unpin action: $e");

      // Clear loading indicator on error
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show error notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text("Error: ${e.toString()}")),
              ],
            ),
            backgroundColor: AppColors.textColor.textErrorColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleUnpinMessage(chats.Records message) async {
    if (_chatProvider!.isDisposedOfChat ||
        !mounted ||
        _chatProvider!.currentUserId == null) {
      return;
    }

    try {
      final chatProvider =
          _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
      final chatId = widget.chatId ?? 0;

      if (chatId <= 0 || message.messageId == null) {
        _logger.w("Invalid chat ID or message ID for unpin");
        return;
      }

      if (!chatProvider.canPinUnpinMessage(message)) {
        final permissionText = chatProvider.getPinUnpinPermissionText(message);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(permissionText),
              backgroundColor: AppColors.textColor.textErrorColor,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      ScaffoldMessenger.of(context).clearSnackBars();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ThemeColorPalette.getTextColor(
                      AppColors.appPriSecColor.primaryColor,
                    ), //AppColors.black,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  "${AppString.unpinningMessage}...",
                  style: TextStyle(
                    color: ThemeColorPalette.getTextColor(
                      AppColors.appPriSecColor.primaryColor,
                    ), //AppColors.black
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final success = await chatProvider.pinUnpinMessage(
        chatId,
        message.messageId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      _logger.d('🔧 Unpin Result: $success');

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: ThemeColorPalette.getTextColor(
                    AppColors.appPriSecColor.primaryColor,
                  ), //AppColors.black,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  AppString.messageUnpinnedSuccessfully,
                  style: TextStyle(
                    color: ThemeColorPalette.getTextColor(
                      AppColors.appPriSecColor.primaryColor,
                    ), //AppColors.black
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
            duration: Duration(seconds: 2),
          ),
        );

        final remainingPinnedCount =
            chatProvider.pinnedMessagesData.records?.length ?? 0;
        if (remainingPinnedCount <= 1 &&
            chatProvider.isPinnedMessagesExpanded) {
          Future.delayed(Duration(milliseconds: 500), () {
            if (!_chatProvider!.isDisposedOfChat && mounted) {
              chatProvider.setPinnedMessagesExpanded(false);
            }
          });
        }

        if (mounted) {
          setState(() {
            // This will trigger a rebuild
          });
        }
      } else if (mounted) {
        final errorMessage = chatProvider.error ?? "Failed to unpin message";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: AppColors.textColor.textErrorColor,
            duration: Duration(seconds: 3),
          ),
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_chatProvider!.isDisposedOfChat && mounted) {
          final currentPinnedCount =
              chatProvider.pinnedMessagesData.records?.length ?? 0;
          _logger.d(
            '🔧 After unpin - Pinned messages count: $currentPinnedCount',
          );
        }
      });
    } catch (e) {
      _logger.e("❌ Error handling unpin message: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text("Error: ${e.toString()}")),
              ],
            ),
            backgroundColor: AppColors.textColor.textErrorColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handlePinnedMessageTap(int messageId) {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    _logger.d('🎯 Pinned message tapped: $messageId');

    try {
      if (chatProvider.isPinnedMessagesExpanded) {
        chatProvider.setPinnedMessagesExpanded(false);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatProvider!.isDisposedOfChat || !mounted) return;
        _scrollToMessageAndHighlight(messageId, chatProvider);
      });
    } catch (e) {
      _logger.e('❌ Error handling pinned message tap: $e');
      _showHighlightErrorFeedback();
    }
  }

  /// Handles tapping on reply message preview to navigate to the original message
  ///
  /// This method:
  /// - Uses the same navigation logic as pinned messages
  /// - Scrolls to the original message and highlights it
  /// - Provides user feedback with appropriate error handling
  /// - Maintains consistency with existing navigation patterns
  void _handleReplyMessageTap(int messageId) {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    _logger.d('🎯 Reply message tapped, navigating to original: $messageId');

    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatProvider!.isDisposedOfChat || !mounted) return;
        _scrollToMessageAndHighlight(messageId, chatProvider);
      });
    } catch (e) {
      _logger.e('❌ Error handling reply message tap: $e');
      _showHighlightErrorFeedback();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STAR/UNSTAR MESSAGE METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _handleStarUnstarMessage(chats.Records message) async {
    if (_chatProvider!.isDisposedOfChat ||
        !mounted ||
        _chatProvider!.currentUserId == null) {
      return;
    }

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      final isCurrentlyStarred = chatProvider.isMessageStarred(
        message.messageId!,
      );

      if (message.messageId == null) {
        _logger.w("Invalid message ID for star/unstar");
        return;
      }

      if (!chatProvider.canStarUnStarMessage(message)) {
        final permissionText = chatProvider.getStarUnstarPermissionText(
          message,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(permissionText),
              backgroundColor: AppColors.textColor.textErrorColor,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      ScaffoldMessenger.of(context).clearSnackBars();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ThemeColorPalette.getTextColor(
                      AppColors.appPriSecColor.primaryColor,
                    ), //AppColors.black,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  "${isCurrentlyStarred ? AppString.unstarring : AppString.starring} ${AppString.message}...",
                  style: TextStyle(
                    color: ThemeColorPalette.getTextColor(
                      AppColors.appPriSecColor.primaryColor,
                    ), //AppColors.black
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final success = await chatProvider.starUnstarMessage(message.messageId!);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      if (success && mounted) {
        String successMessage =
            isCurrentlyStarred
                ? AppString.messageUnstarredSuccessfully
                : AppString.messageStarredSuccessfully;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isCurrentlyStarred ? Icons.star_border : Icons.star,
                  color: ThemeColorPalette.getTextColor(
                    AppColors.appPriSecColor.primaryColor,
                  ), //AppColors.black,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  successMessage,
                  style: TextStyle(
                    color: ThemeColorPalette.getTextColor(
                      AppColors.appPriSecColor.primaryColor,
                    ), //AppColors.black
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.appPriSecColor.primaryColor,
            duration: Duration(seconds: 2),
          ),
        );

        _logger.d(
          '⭐ Star/unstar completed, UI will update automatically via socket',
        );
      } else if (mounted) {
        final errorMessage =
            chatProvider.error ?? "Failed to star/unstar message";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: AppColors.black, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: TextStyle(color: AppColors.black),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.textColor.textErrorColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _logger.e("❌ Error handling star/unstar message: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: AppColors.black, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Error: ${e.toString()}",
                    style: TextStyle(color: AppColors.black),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.textColor.textErrorColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DELETE MESSAGE METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _handleDeleteMessage(
    chats.Records message,
    bool isDeleteForEveryone,
  ) async {
    if (_chatProvider!.isDisposedOfChat ||
        !mounted ||
        _chatProvider!.currentUserId == null) {
      return;
    }

    // ✅ DEMO MODE: Show message to demo users instead of allowing deletion
    if (isDemo) {
      snackbarNew(
        context,
        msg: "Demo account - Login with real credentials to delete messages",
      );
      return;
    }

    if (!_isMultiSelectMode && message.deletedForEveryone != true) {
      // Check if message is selectable before entering multi-delete mode
      if (_isMessageSelectableForDeletion(message)) {
        // Start multi-delete mode and select this message
        _enterMultiSelectMode();
        _toggleMessageSelection(message.messageId!);
      } else {
        // Show normal long press menu for non-selectable messages
        _handleLongPress(message);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCROLLING & PAGINATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  void _onScroll() {
    if (_chatProvider!.isDisposedOfChat ||
        !_scrollController.hasClients ||
        !mounted) {
      return;
    }

    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      _updateScrollState();
    });
  }

  void _updateScrollState() {
    if (!mounted) return;

    final currentPosition = _scrollController.position.pixels;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;

    // Check if user is near bottom (within 100px)
    final isNearBottom = currentPosition <= 100;

    // Update scroll state for new message indicator
    setState(() {
      _isUserScrolledUp = !isNearBottom;

      // Hide new message indicator if user scrolled to bottom
      if (isNearBottom && _showNewMessageIndicator) {
        _showNewMessageIndicator = false;
        _newMessageCount = 0;
      }

      // Re-enable auto-scroll when user manually scrolls to bottom
      if (isNearBottom && _preventAutoScroll) {
        _preventAutoScroll = false;
        _logger.d('🔓 Auto-scroll re-enabled - user scrolled to bottom');
      }
    });

    if (maxScrollExtent - currentPosition <= 200) {
      _triggerPagination();
    }

    if (!_isInitialLoadComplete && maxScrollExtent > 0) {
      _isInitialLoadComplete = true;
    }
  }

  /// Setup subscription to new message stream for real-time notifications
  void _setupNewMessageSubscription() {
    _newMessageSubscription?.cancel(); // Cancel existing subscription

    if (_chatProvider?.socketEventController != null) {
      _newMessageSubscription = _chatProvider!
          .socketEventController
          .newMessageStream
          .listen(
            _handleNewSocketMessage,
            onError: (error) {
              _logger.e('Error in new message stream: $error');
            },
          );
      _logger.d('🔔 New message subscription established');
    }
  }

  /// Handle new real-time message from socket
  void _handleNewSocketMessage(chats.Records newMessage) {
    // Check if this is the current user's own message
    final currentUserIdInt =
        _chatProvider!.currentUserId != null
            ? int.tryParse(_chatProvider!.currentUserId!)
            : null;
    final isOwnMessage =
        currentUserIdInt != null && newMessage.senderId == currentUserIdInt;

    if (isOwnMessage) {
      // For own messages: Allow auto-scroll, don't show indicator
      _logger.d(
        '📤 Own message sent - allowing auto-scroll, no indicator needed',
      );
      return; // Don't prevent auto-scroll or show indicator
    }

    // For messages from others: Prevent auto-scroll and show indicator if scrolled up
    _preventAutoScroll = true;

    // Only show indicator if user is scrolled up from bottom
    if (_isUserScrolledUp && mounted) {
      setState(() {
        _newMessageCount += 1;
        _showNewMessageIndicator = true;
      });

      _logger.d(
        '🔔 Real-time message notification: New message from user ${newMessage.senderId}',
      );
    }

    // Don't re-enable auto-scroll automatically - let user control it
    // The auto-scroll will be re-enabled when:
    // 1. User manually scrolls to bottom
    // 2. User sends their own message
    // 3. User taps the "new message" indicator
  }

  void _triggerPagination() {
    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

    if (chatProvider.isPaginationLoading ||
        !chatProvider.hasMoreMessages ||
        chatProvider.isChatLoading ||
        chatProvider.isRefreshing ||
        _chatProvider!.isInitializingOfChat ||
        _chatProvider!.isLoadingCurrentUser) {
      return;
    }

    _hasTriggeredPagination = true;
    _loadMoreMessages();
  }

  /// Initialize cache for current chat
  // ignore: unused_element
  Future<void> _initializeCacheForChat() async {
    try {
      final chatId = _getCurrentChatId();
      if (chatId != null) {
        await ChatCacheManager.initializeChat(chatId);
        _logger.d('🗄️ Cache initialized for chat: $chatId');
      }
    } catch (e) {
      _logger.e('❌ Error initializing cache: $e');
    }
  }

  /// Get current chat ID for caching
  String? _getCurrentChatId() {
    if (widget.chatId != null) {
      return widget.chatId.toString();
    } else if (widget.userId != null) {
      return 'user_${widget.userId}';
    }
    return null;
  }

  /// Cache messages that were just loaded from server
  Future<void> _cacheLoadedMessages(
    String chatId,
    ChatProvider chatProvider,
  ) async {
    try {
      // Get the current chat data from provider
      final currentData = chatProvider.chatsData;
      if (currentData.records != null && currentData.records!.isNotEmpty) {
        final currentPage = chatProvider.chatListCurrentPage;

        // Cache the current page data
        await ChatCacheManager.cachePage(
          chatId,
          currentPage,
          currentData.records!,
          pagination: currentData.pagination,
        );

        _logger.d(
          '💾 Cached page $currentPage with ${currentData.records!.length} messages',
        );
      }
    } catch (e) {
      _logger.e('❌ Error caching loaded messages: $e');
    }
  }

  /// Load cached data if available for faster initial display
  // ignore: unused_element
  Future<void> _loadCachedDataIfAvailable() async {
    try {
      final chatId = _getCurrentChatId();
      if (chatId == null) return;

      // Check if we have any cached pages
      final cachedPages = ChatCacheManager.getCachedPages(chatId);
      if (cachedPages.isNotEmpty) {
        _logger.d('🗄️ Found cached pages for chat $chatId: $cachedPages');

        // Load the first cached page to show immediately
        final firstPage = cachedPages.first;
        final cachedMessages = await ChatCacheManager.getPage(
          chatId,
          firstPage,
        );

        if (cachedMessages != null && cachedMessages.isNotEmpty) {
          _logger.d(
            '⚡ Loading cached messages into ChatProvider (${cachedMessages.length} messages)',
          );

          // 🚀 CRITICAL FIX: Load cached data into ChatProvider immediately
          if (!mounted) return;
          final chatProvider = Provider.of<ChatProvider>(
            context,
            listen: false,
          );

          // Create ChatsModel from cached data
          final cachedChatsModel = ChatCacheManager.createChatModelFromCache(
            cachedMessages,
            firstPage,
            1, // Assume at least 1 page for now
          );

          // Set the cached data in the provider to display immediately
          chatProvider.setCachedChatsData(cachedChatsModel);

          _logger.d('✅ Cached data loaded into ChatProvider successfully');
          ChatCacheManager.logCacheStats(chatId);

          // Trigger a rebuild to show cached data
          if (mounted) {
            setState(() {
              _chatProvider!.setHasCachedData(true);
            });
          }
        }
      } else {
        _logger.d('📭 No cached data available for chat $chatId');
      }
    } catch (e) {
      _logger.e('❌ Error loading cached data: $e');
    }
  }

  /// Run cache tests in debug mode only
  // ignore: unused_element
  Future<void> _runCacheTestsIfDebugMode() async {
    // Only run in debug mode and only once per session
    if (kDebugMode) {
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          _logger.d('🧪 Running cache validation tests...');
          final testsPassed = await CacheTestHelper.runAllTests();
          if (testsPassed) {
            _logger.d('✅ Cache system validated successfully');

            // Also run a real-world demo
            _logger.d('🌍 Running real-world cache demo...');
            await CacheTestHelper.demoCache();
          } else {
            _logger.w('⚠️ Some cache tests failed - check implementation');
          }

          // Test current chat caching
          await _testCurrentChatCaching();
        } catch (e) {
          _logger.e('❌ Error running cache tests: $e');
        }
      });
    }
  }

  /// Test caching for the current chat
  Future<void> _testCurrentChatCaching() async {
    try {
      final chatId = _getCurrentChatId();
      if (chatId != null) {
        _logger.d('🔬 SCREEN TEST: Testing cache for current chat: $chatId');

        // Check cache initialization
        await ChatCacheManager.initializeChat(chatId);

        // Log current cache state
        ChatCacheManager.logCacheStats(chatId);

        // Check if any data is cached
        final cachedPages = ChatCacheManager.getCachedPages(chatId);
        if (cachedPages.isNotEmpty) {
          _logger.d(
            '📊 SCREEN TEST: Current chat has ${cachedPages.length} cached pages: $cachedPages',
          );

          // Test retrieval of first cached page
          final firstPage = cachedPages.first;
          final cachedMessages = await ChatCacheManager.getPage(
            chatId,
            firstPage,
          );
          _logger.d(
            '🎯 SCREEN TEST: Page $firstPage contains ${cachedMessages?.length ?? 0} cached messages',
          );
        } else {
          _logger.d(
            '📭 SCREEN TEST: No cached data found for current chat (this is expected on first visit)',
          );
        }

        // Also call the provider's debug method
        if (!mounted) return;
        final chatProvider =
            _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
        await chatProvider.debugCacheStatus(chatId);
      }
    } catch (e) {
      _logger.e('❌ SCREEN TEST: Error testing current chat caching: $e');
    }
  }

  Future<void> _loadMoreMessages() async {
    final chatProvider =
        _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

    if (chatProvider.isPaginationLoading ||
        !chatProvider.hasMoreMessages ||
        chatProvider.isChatLoading ||
        chatProvider.isRefreshing ||
        _chatProvider!.isInitializingOfChat ||
        _chatProvider!.isLoadingCurrentUser) {
      _logger.d('⏭️ Pagination conditions not met, skipping');
      return;
    }

    _logger.d('🔄 Starting pagination load with cache support');

    try {
      // Try loading with cache first
      final chatId = _getCurrentChatId();
      if (chatId != null) {
        final nextPage = (chatProvider.chatListCurrentPage) + 1;

        // Check if next page is cached
        if (ChatCacheManager.hasPage(chatId, nextPage)) {
          final cachedMessages = await ChatCacheManager.getPage(
            chatId,
            nextPage,
          );
          if (cachedMessages != null && cachedMessages.isNotEmpty) {
            _logger.d(
              '🎯 Using cached data for page $nextPage (${cachedMessages.length} messages)',
            );

            // Log cache usage for debugging
            ChatCacheManager.logCacheStats(chatId);

            // The provider will handle adding the cached messages to the UI
            // For now, fall back to server call since we need to integrate with provider state
          }
        }
      }

      // Load from server (original method)
      await chatProvider.loadMoreMessages();

      // Cache the loaded data if we have a chat ID
      if (chatId != null) {
        await _cacheLoadedMessages(chatId, chatProvider);
      }

      _logger.d('✅ Pagination completed successfully');
    } catch (e) {
      _logger.e("❌ Error loading more messages: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load more messages"),
            backgroundColor: AppColors.textColor.textErrorColor,
          ),
        );
      }
    }
  }

  Future<void> _refreshChatMessages() async {
    if (_chatProvider!.isDisposedOfChat ||
        !mounted ||
        _chatProvider!.currentUserId == null) {
      return;
    }

    try {
      final chatProvider =
          _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
      final chatId = widget.chatId ?? 0;

      _logger.d(
        "🔄 Starting refresh - chatId: $chatId, userId: ${widget.userId}",
      );

      await chatProvider.refreshChatMessages(
        chatId: chatId,
        peerId: widget.userId ?? 0,
      );

      _logger.d("✅ Chat refresh completed successfully");
    } catch (e) {
      _logger.e("❌ Error refreshing chat messages: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to refresh messages: ${e.toString()}"),
            backgroundColor: AppColors.textColor.textErrorColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
      rethrow;
    }
  }

  void _scrollToBottom({bool animated = true, bool forceScroll = false}) {
    if (_chatProvider!.isDisposedOfChat ||
        !_scrollController.hasClients ||
        !mounted) {
      return;
    }

    // Prevent auto-scroll when new socket messages arrive (unless forced)
    if (_preventAutoScroll && !forceScroll) {
      _logger.d('📍 Auto-scroll prevented for socket message');
      return;
    }

    _logger.d('📍 Scrolling to bottom - animated: $animated');

    if (animated) {
      _scrollController.animateTo(
        0.0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0.0);
    }
  }

  /// Build the new message notification indicator
  Widget _buildNewMessageIndicator() {
    return Positioned(
      bottom: 140, // Above the input field
      right: 20,
      child: AnimatedScale(
        scale: _showNewMessageIndicator ? 1.0 : 0.0,
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: () {
            // Scroll to bottom and hide indicator (force scroll even if auto-scroll is prevented)
            _scrollToBottom(animated: true, forceScroll: true);
            setState(() {
              _showNewMessageIndicator = false;
              _newMessageCount = 0;
              // Re-enable auto-scroll when user taps the indicator
              _preventAutoScroll = false;
            });
            _logger.d(
              '🔓 Auto-scroll re-enabled - user tapped new message indicator',
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.appPriSecColor.primaryColor, // iOS blue color
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                if (_newMessageCount > 0) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _newMessageCount > 99 ? '99+' : '$_newMessageCount',
                      style: TextStyle(
                        color: Colors.black, // iOS blue color
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                SizedBox(width: 8),
                Text(
                  _newMessageCount > 1 ? 'new messages' : 'new message',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE HIGHLIGHTING & SEARCH METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _scrollToMessageAndHighlight(
    int messageId,
    ChatProvider chatProvider,
  ) async {
    if (_chatProvider!.isDisposedOfChat || !mounted) return;

    _logger.d('🎯 scrollToMessageAndHighlight: $messageId');

    // Clear any existing snackbars/loaders at the start
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // CRITICAL: Reset search states to ensure no search loader is shown
      setState(() {
        _isSearchMode = false;
        _isSearching = false;
      });
    }

    try {
      // 1️⃣ If we already have a GlobalKey for that message -> ensureVisible
      final key = _messageKeys[messageId];
      if (key?.currentContext != null) {
        _logger.d('✅ GlobalKey found – scrolling via ensureVisible');
        try {
          chatProvider.highlightMessage(messageId);
          await Scrollable.ensureVisible(
            key!.currentContext!,
            duration: Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.5,
          );
        } catch (e) {
          _logger.e('❌ Error in GlobalKey scroll: $e');
        }
        _logger.d('✅ [PATH 1] Showing success feedback');
        _showMessageFoundFeedback();
        return;
      }

      // 2️⃣ Not in the current batch? auto-paginate and retry ensureVisible
      if (!_isMessageInCurrentData(messageId, chatProvider)) {
        _logger.d('🔄 Message not loaded – auto-paginating');
        await _autoPaginateToFindMessage(messageId, chatProvider);

        final key2 = _messageKeys[messageId];
        if (key2?.currentContext != null) {
          try {
            chatProvider.highlightMessage(messageId);
            await Scrollable.ensureVisible(
              key2!.currentContext!,
              duration: Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          } catch (e) {
            _logger.e('❌ Error in pagination scroll: $e');
          }
          _logger.d('✅ [PATH 2] Showing success feedback');
          _showMessageFoundFeedback();
          return;
        }
      }

      // 2.5️⃣ Message is in data but GlobalKey not ready - calculate index and scroll
      if (_isMessageInCurrentData(messageId, chatProvider)) {
        _logger.d(
          '⏳ Message in data but GlobalKey not ready, calculating widget index...',
        );

        // Calculate widget index directly from data
        final calculatedIndex = _calculateWidgetIndexForMessage(
          messageId,
          chatProvider,
        );
        if (calculatedIndex == null) {
          _logger.e(
            '❌ Could not calculate widget index for message $messageId',
          );
          throw Exception(
            'Message $messageId found in data but could not calculate widget index',
          );
        }

        _logger.d('📍 Scrolling to calculated index $calculatedIndex');

        // Scroll to the calculated index - this will force ListView to build the widget
        await _scrollController.scrollToIndex(
          calculatedIndex,
          duration: Duration(milliseconds: 400),
          preferPosition: AutoScrollPosition.middle,
        );

        // Wait a moment for the widget to be built after scrolling
        await Future.delayed(Duration(milliseconds: 300));

        // Now the GlobalKey should be available since the widget was built
        final keyAfterScroll = _messageKeys[messageId];
        if (keyAfterScroll?.currentContext != null) {
          _logger.d('✅ GlobalKey available after scroll, refining position');
          try {
            // Refine the scroll position using GlobalKey for pixel-perfect alignment
            await Scrollable.ensureVisible(
              keyAfterScroll!.currentContext!,
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          } catch (e) {
            _logger.w(
              '⚠️ Error refining scroll position: $e (continuing anyway)',
            );
          }
        } else {
          _logger.d(
            'ℹ️ GlobalKey not available after scroll, but message is visible',
          );
        }

        // Highlight the message (wrap in try-catch to ensure feedback is shown)
        try {
          _logger.d('🎨 Highlighting message $messageId');
          chatProvider.highlightMessage(messageId);
        } catch (e) {
          _logger.e('❌ Error highlighting message: $e');
        }

        // ALWAYS show success feedback and hide loaders - even if highlighting failed
        _logger.d('✅ [PATH 3] Showing success feedback');
        _showMessageFoundFeedback();
        return;
      }

      // 3️⃣ Fallback: This should rarely be reached
      _logger.e('❌ Message $messageId not found in current data');
      throw Exception('Message $messageId not found');
    } catch (e, st) {
      _logger.e('❌ Error in scrollToMessage: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        _showHighlightErrorFeedback();
      }
    }
  }

  Future<void> _autoPaginateToFindMessage(
    int messageId,
    ChatProvider chatProvider,
  ) async {
    _logger.d('🔄 Starting auto-pagination for message $messageId');

    int attemptCount = 0;

    // Keep going while there's more data to load
    while (chatProvider.hasMoreMessages) {
      // If the provider is still in the middle of loading/refreshing, wait
      if (chatProvider.isChatLoading || chatProvider.isRefreshing) {
        _logger.d('⏳ Provider busy – waiting...');
        await _waitForProviderToBeReady(chatProvider);
        continue;
      }

      attemptCount++;
      _logger.d(
        '🔄 Auto-pagination attempt #$attemptCount for message $messageId',
      );
      _updateSearchProgress(attemptCount, messageId);

      try {
        // Trigger your normal “load next page” + await until it's done
        await _loadMoreMessagesAndWait(chatProvider);

        // Once new data’s in, check if our target arrived
        if (_isMessageInCurrentData(messageId, chatProvider)) {
          _logger.d('✅ Message $messageId found after $attemptCount attempts');
          return;
        } else {
          _logger.d(
            '📭 Message $messageId still not found (attempt $attemptCount)',
          );
        }
      } catch (e, st) {
        _logger.e(
          '❌ Error during pagination attempt #$attemptCount: $e',
          e,
          st,
        );
        // small back-off before retrying
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // If we exit the loop, hasMoreMessages is now false
    _logger.w('❌ No more messages to load – message $messageId not found');
    throw Exception(
      'Message $messageId not found after loading all available pages',
    );
  }

  Future<void> _waitForProviderToBeReady(ChatProvider chatProvider) async {
    int waitCount = 0;
    const maxWaitCount = 20;

    while ((chatProvider.isChatLoading || chatProvider.isRefreshing) &&
        waitCount < maxWaitCount) {
      await Future.delayed(Duration(milliseconds: 500));
      waitCount++;

      if (_chatProvider!.isDisposedOfChat || !mounted) {
        throw Exception('Component disposed while waiting');
      }
    }

    if (waitCount >= maxWaitCount) {
      _logger.w('⚠️ Timeout waiting for provider to be ready');
    }
  }

  Future<void> _loadMoreMessagesAndWait(ChatProvider chatProvider) async {
    _logger.d('📡 Starting API call to load more messages');

    final currentMessageCount = chatProvider.chatsData.records?.length ?? 0;

    await chatProvider.loadMoreMessages();

    await _waitForNewMessagesToLoad(chatProvider, currentMessageCount);

    _logger.d('✅ API response processed and new messages loaded');
  }

  Future<void> _waitForNewMessagesToLoad(
    ChatProvider chatProvider,
    int previousMessageCount,
  ) async {
    int waitCount = 0;
    const maxWaitCount = 20;

    while (waitCount < maxWaitCount) {
      if (_chatProvider!.isDisposedOfChat || !mounted) {
        throw Exception('Component disposed while waiting for messages');
      }

      if (!chatProvider.isChatLoading && !chatProvider.isRefreshing) {
        final currentMessageCount = chatProvider.chatsData.records?.length ?? 0;

        if (currentMessageCount > previousMessageCount) {
          _logger.d(
            '📬 New messages detected: $previousMessageCount → $currentMessageCount',
          );

          await Future.delayed(Duration(milliseconds: 300));
          return;
        }

        if (!chatProvider.hasMoreMessages) {
          _logger.d('📭 No more messages available from server');
          return;
        }
      }

      await Future.delayed(Duration(milliseconds: 500));
      waitCount++;
    }

    if (waitCount >= maxWaitCount) {
      _logger.w('⚠️ Timeout waiting for new messages to load');
    }
  }

  /// Calculate widget index for a message from the data directly
  /// This mirrors the logic in _buildMessagesList
  int? _calculateWidgetIndexForMessage(
    int messageId,
    ChatProvider chatProvider,
  ) {
    final groupedMessages = chatProvider.groupedMessages;
    if (groupedMessages.isEmpty) {
      return null;
    }

    int widgetIndex = 0;
    final sortedKeys =
        groupedMessages.keys.toList()
          ..sort((a, b) => ChatDateGrouper.sortDateKeysForReversedList(a, b));

    for (final dateKey in sortedKeys) {
      final messages = groupedMessages[dateKey]!;

      // Add messages for this date (in reverse order within the group)
      for (int i = messages.length - 1; i >= 0; i--) {
        final message = messages[i];
        if (message.messageId == messageId) {
          _logger.d(
            '✅ Calculated widget index for message $messageId: $widgetIndex',
          );
          return widgetIndex;
        }
        widgetIndex++;
      }

      // Account for date header
      widgetIndex++;
    }

    _logger.w('⚠️ Message $messageId not found in grouped messages');
    return null;
  }

  bool _isMessageInCurrentData(int messageId, ChatProvider chatProvider) {
    final messages = chatProvider.chatsData.records;
    if (messages == null || messages.isEmpty) {
      _logger.d('📭 No messages loaded yet');
      return false;
    }

    final found = messages.any((record) => record.messageId == messageId);

    if (found) {
      _logger.d(
        '✅ Message $messageId found in ${messages.length} loaded messages',
      );
    } else {
      _logger.d(
        '❌ Message $messageId not found in ${messages.length} loaded messages',
      );

      final messageIds = messages.take(5).map((m) => m.messageId).toList();
      _logger.d('📋 Sample loaded message IDs: $messageIds');
    }

    return found;
  }

  String _getReplyPreviewText(chats.Records message) {
    switch (message.messageType?.toLowerCase()) {
      case 'image':
        return 'Image';
      case 'gif':
        return 'GIF';
      case 'video':
        return 'Video';
      case 'document':
      case 'doc':
      case 'pdf':
      case 'file':
        return 'Document';
      case 'location':
        return 'Location';
      case 'contact':
        return 'Contact';
      case 'text':
      case 'link':
      case 'story_reply':
      default:
        return message.messageContent ?? 'Message';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEEDBACK & NOTIFICATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  void _showMessageFoundFeedback() {
    if (!mounted) return;

    try {
      final messenger = ScaffoldMessenger.of(context);

      // Clear all existing snackbars (including progress/loading bars)
      messenger.clearSnackBars();
      messenger.hideCurrentSnackBar();

      _logger.d('📢 Displaying success message to user');

      // Then show your "found" confirmation:
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(AppString.messageFound),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _logger.e('❌ Error showing success feedback: $e');
    }
  }

  void _showHighlightErrorFeedback() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.search_off, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(AppString.unableTolocateMessage),
          ],
        ),
        backgroundColor: AppColors.textColor.textErrorColor,
      ),
    );
  }

  void _updateSearchProgress(int attemptCount, int messageId) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.black,
                value: attemptCount / 10,
              ),
            ),
            SizedBox(width: 12),
            //we don't know the count that's why use while loop
            Expanded(
              child: Text(
                // 'Searching for message... (${attemptCount})',
                '${AppString.searchingForMessage}...',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.black),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 30),
        backgroundColor: AppColors.appPriSecColor.primaryColor,
      ),
    );
  }

  void _showDocumentError(String error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Document error: $error"),
        backgroundColor: AppColors.textColor.textErrorColor,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEBUG & UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  void _debugPinnedMessagesState() {
    if (_chatProvider != null) {
      final pinnedCount =
          _chatProvider!.pinnedMessagesData.records?.length ?? 0;
      final chatCount = _chatProvider!.chatsData.records?.length ?? 0;

      _logger.d(
        "🔍 DEBUG - Chat messages: $chatCount, Pinned messages: $pinnedCount",
      );

      if (pinnedCount > 0) {
        _logger.d("✅ Pinned messages available after initialization:");
        for (var msg in _chatProvider!.pinnedMessagesData.records!) {
          _logger.d("  - ${msg.messageId}: ${msg.messageContent}");
        }
      } else {
        _logger.d("⚠️ No pinned messages found after initialization");

        if (chatCount > 0) {
          final pinnedInMain =
              _chatProvider!.chatsData.records!
                  .where((r) => r.pinned == true)
                  .toList();
          if (pinnedInMain.isNotEmpty) {
            _logger.w(
              "🚨 Found ${pinnedInMain.length} pinned messages in main chat data but not in pinned collection!",
            );
          }
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BLOCK FUNCTIONALITY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Build blocked message widget
  Widget _buildBlockedMessageWidget() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final blockScenario = chatProvider.getBlockScenario(
          widget.chatId,
          widget.userId,
        );
        final blockMessage = chatProvider.getBlockMessage(
          widget.chatId,
          widget.userId,
        );

        if (blockMessage.isEmpty) {
          return SizedBox.shrink();
        }

        // Get appropriate colors based on block scenario
        Color blockColor = _getBlockColor(blockScenario);

        return Container(
          color: AppThemeManage.appTheme.scaffoldBackColor,
          child: Container(
            height: SizeConfig.sizedBoxHeight(50),
            width: SizeConfig.screenWidth,
            decoration: BoxDecoration(
              color: AppColors.appPriSecColor.secondaryColor.withValues(
                alpha: 0.2,
              ),
              // border: Border(
              //   top: BorderSide(color: AppColors.strokeColor.cECECEC),
              // ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Show different content based on block scenario
                if (blockScenario == 'user_blocked_other' ||
                    blockScenario == 'mutual_block') ...[
                  // User can unblock - show clickable unblock button
                  GestureDetector(
                    onTap: _handleBlockUnblock,
                    child: Center(
                      child: Text(
                        _getUnblockButtonText(blockScenario),
                        style: AppTypography.innerText16(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ),
                ] else if (blockScenario == 'user_blocked_by_other') ...[
                  // User is blocked by someone else - show non-clickable message
                  Center(
                    child: Text(
                      blockMessage,
                      style: AppTypography.innerText16(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ] else ...[
                  // Other scenarios - show generic message
                  Center(
                    child: Text(
                      blockMessage,
                      style: AppTypography.innerText16(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: blockColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Get detailed block message based on scenario
  // ignore: unused_element
  String _getDetailedBlockMessage(String blockScenario) {
    switch (blockScenario) {
      case 'user_blocked_other':
        return 'You blocked ${widget.chatName}. Unblock to continue chatting.';
      case 'user_blocked_by_other':
        return ''; // No message shown when user is blocked by other
      case 'mutual_block':
        return 'You and ${widget.chatName} have blocked each other. Unblock to continue chatting.';
      default:
        return '';
    }
  }

  /// Get appropriate color for block scenario
  Color _getBlockColor(String blockScenario) {
    switch (blockScenario) {
      case 'user_blocked_other':
        return Colors.orange; // User blocked other - can unblock
      case 'user_blocked_by_other':
        return Colors.red; // User is blocked - cannot unblock
      case 'mutual_block':
        return Colors.red; // Mutual block - serious issue
      default:
        return Colors.grey;
    }
  }

  /// Get unblock button text based on scenario
  String _getUnblockButtonText(String blockScenario) {
    switch (blockScenario) {
      case 'user_blocked_other':
        return 'Unblock User';
      case 'mutual_block':
        return 'Unblock User';
      default:
        return 'Unblock';
    }
  }

  /// Check if current user is blocked using blocked_by field from chat list
  // ignore: unused_element
  bool _isCurrentUserBlockedFromChatList() {
    if (widget.chatId == null ||
        _chatProvider == null ||
        _chatProvider!.currentUserId == null) {
      return false;
    }

    try {
      // Use the chat provider's getChatBlockStatus method that checks blocked_by field
      return _chatProvider!.getChatBlockStatus(widget.chatId!);
    } catch (e) {
      _logger.e('Error checking block status from chat list: $e');
      return false;
    }
  }

  /// Check if current user is the one who blocked (can show unblock button)
  // ignore: unused_element
  bool _isCurrentUserTheBlocker() {
    if (_chatProvider == null || _chatProvider!.currentUserId == null) {
      return false;
    }

    try {
      if (widget.chatId != null) {
        return _chatProvider!.isCurrentUserTheBlocker(widget.chatId!);
      } else if (widget.userId != null) {
        return _chatProvider!.isCurrentUserTheBlockerByUserId(widget.userId!);
      }
      return false;
    } catch (e) {
      _logger.e('Error checking if current user is blocker: $e');
      return false;
    }
  }

  // Block status checking is now handled via Provider Consumer pattern
  // No need for separate async block status checking methods

  /// Navigate to user profile
  Future<void> _navigateToUserProfile() async {
    _logger.d('Navigating to user profile with userId: ${widget.userId}');

    if (widget.userId == null) {
      _logger.e('userId is null, cannot navigate to profile');
      return;
    }

    // Get current block status from provider to detect changes
    final initialBlockStatus =
        widget.chatId != null
            ? (_chatProvider?.getInstantBlockStatus(widget.chatId!) ?? false)
            : (_chatProvider?.getInstantBlockStatusByUserId(widget.userId!) ??
                false);

    // Check user type using find-user API before navigation
    Widget profileScreen;
    try {
      _logger.d('Checking user type for userId: ${widget.userId}');

      // Call find-user API directly with the correct parameters
      final apiClient = GetIt.instance<ApiClient>();
      final response = await apiClient.request(
        '/users/find-user',
        method: 'POST',
        body: {'user_id': widget.userId},
      );

      final userProfile = UserNameCheckModel.fromJson(response);
      final userRecord =
          userProfile.data?.records?.isNotEmpty == true
              ? userProfile.data!.records!.first
              : null;

      final userType = userRecord?.userType ?? 'regular';
      _logger.d('User type found: $userType for user: ${userRecord?.fullName}');
      _logger.d('Raw user type from API: ${userRecord?.userType}');

      if (userType == 'regular') {
        _logger.d('Navigating to REGULAR profile for user type: $userType');
        // Navigate to regular profile
        profileScreen = UserProfileView(
          userId: widget.userId ?? 0,
          chatId: widget.chatId,
          blockFlag: initialBlockStatus,
          chatName: widget.chatName,
        );
      } else {
        _logger.d('Navigating to BUSINESS profile for user type: $userType');
        // Navigate to business profile
        profileScreen = UserProfileViewBusiness(
          userId: widget.userId ?? 0,
          chatId: widget.chatId,
          blockFlag: initialBlockStatus,
          chatName: widget.chatName,
        );
      }
    } catch (e) {
      _logger.e('Error checking user type, defaulting to regular profile: $e');
      // Default to regular profile if API call fails
      profileScreen = UserProfileView(
        userId: widget.userId ?? 0,
        chatId: widget.chatId,
        blockFlag: initialBlockStatus,
        chatName: widget.chatName,
      );
    }

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => profileScreen),
    );

    if (!mounted) return;

    // Log navigation result for debugging
    _logger.d('Navigation result from UserProfileView: $result');
    _logger.d('Initial block status was: $initialBlockStatus');

    // Since we're using provider-based Consumer pattern, the UI will automatically
    // update based on provider data. No need for complex async operations or local state updates.

    // Only refresh data in background if block status was changed in UserProfile
    if (result == true && _chatProvider != null) {
      // Block status was changed - refresh in background to sync with server
      // but don't await this to prevent UI delays
      closeKeyboard();
      _chatProvider!.refreshBlockStatus();
      _logger.d('Background refresh triggered for block status sync');
    }

    // Handle search mode activation if needed
    if (result == "search") {
      _logger.d('Search mode requested from UserProfile');
      // Enable search mode
      setState(() {
        _isSearchMode = true;
      });
      // Focus search field after a short delay to allow build to complete
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    } else if (result == true) {
      closeKeyboard();
      _logger.d(
        'Block status changed from UserProfile (no search mode activation)',
      );
      // Block status changed but no search mode activation needed
    }

    // Block status is now handled via Provider Consumer pattern
    _logger.d('UserProfile navigation handling completed');
  }

  /// Handle block/unblock user
  Future<void> _handleBlockUnblock() async {
    if (widget.userId == null || _chatProvider!.isDisposedOfChat) return;

    // Get current block status from provider
    final isUserBlocked =
        widget.chatId != null
            ? (_chatProvider?.getInstantBlockStatus(widget.chatId!) ?? false)
            : (_chatProvider?.getInstantBlockStatusByUserId(widget.userId!) ??
                false);

    // Show confirmation dialog
    final confirmed = await bottomSheetGobalWithoutTitle<bool>(
      context,
      bottomsheetHeight: SizeConfig.safeHeight(28),
      borderRadius: BorderRadius.circular(20),
      alignment: Alignment.bottomCenter,
      isCrossIconHide: true,
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: SizeConfig.height(2)),
            Text(
              "${isUserBlocked ? AppString.homeScreenString.areYouSureUnblock : AppString.homeScreenString.areYouSureBlock} ${widget.chatName}?",
              textAlign: TextAlign.start,
              style: AppTypography.captionText(context).copyWith(
                fontSize: SizeConfig.getFontSize(15),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: SizeConfig.height(1.5)),
            Text(
              isUserBlocked
                  ? '${AppString.blockUserStrings.areYouSureYouWantToUnblock} ${widget.chatName}?'
                  : '${AppString.blockUserStrings.areYouSureYouWantToBlock} ${widget.chatName}? ',
              textAlign: TextAlign.start,
              style: AppTypography.captionText(context).copyWith(
                color: AppColors.textColor.textGreyColor,
                fontSize: SizeConfig.getFontSize(13),
              ),
            ),
            SizedBox(height: SizeConfig.height(3)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: SizeConfig.height(5),
                  width: SizeConfig.width(35),
                  child: customBorderBtn(
                    context,
                    onTap: () {
                      Navigator.pop(context, false);
                    },
                    title: AppString.cancel,
                  ),
                ),
                SizedBox(
                  height: SizeConfig.height(5),
                  width: SizeConfig.width(35),
                  child: customBtn2(
                    context,
                    onTap: () => Navigator.pop(context, true),
                    child: Text(
                      isUserBlocked
                          ? AppString.homeScreenString.unblock
                          : AppString.homeScreenString.block,
                      style: AppTypography.h5(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: ThemeColorPalette.getTextColor(
                          AppColors.appPriSecColor.primaryColor,
                        ), //AppColors.textColor.textBlackColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _performBlockUnblock();
    }
  }

  /// Perform the actual block/unblock API call
  Future<void> _performBlockUnblock() async {
    if (!mounted) return;

    try {
      // Get current block status from provider before making any changes
      final previousBlockStatus =
          widget.chatId != null
              ? (_chatProvider?.getInstantBlockStatus(widget.chatId!) ?? false)
              : (_chatProvider?.getInstantBlockStatusByUserId(widget.userId!) ??
                  false);
      final actionToPerform =
          !previousBlockStatus; // true = block, false = unblock

      // Note: Block updates are now handled automatically by the blockUnblockUser method
      // and real-time socket events, so no manual local updates needed

      // Make API call in background
      final success = await _chatProvider!.blockUnblockUser(
        widget.userId!,
        widget.chatId ?? 0,
      );

      if (mounted) {
        if (success) {
          // API call succeeded - show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                actionToPerform
                    ? '${widget.chatName} has been blocked'
                    : '${widget.chatName} has been unblocked',
              ),
              backgroundColor: actionToPerform ? Colors.red : Colors.green,
            ),
          );
        } else {
          // API call failed - block status revert is handled automatically by the provider

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to ${actionToPerform ? 'block' : 'unblock'} user',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('Error in block/unblock: $e');

      // Revert local chat list data to original status on error
      if (mounted &&
          _chatProvider != null &&
          widget.userId != null &&
          _chatProvider!.currentUserId != null) {
        // Block status revert is handled automatically by the provider

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppString.anRrrorOccurredPleaseTryAgain),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle clear chat functionality
  // ignore: unused_element
  Future<void> _handleClearChat() async {
    if (_chatProvider!.isDisposedOfChat || _isClearingChat) return;

    // Show confirmation dialog
    final confirmed = await bottomSheetGobalWithoutTitle<bool>(
      context,
      bottomsheetHeight: SizeConfig.height(23),
      borderRadius: BorderRadius.circular(20),
      isCenter: false,
      barrierDismissible: false,
      isCrossIconHide: true,
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: SizeConfig.height(3)),
            Text(
              AppString.homeScreenString.clearThisChat,
              style: AppTypography.innerText16(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: SizeConfig.height(2)),
            Text(
              AppString.homeScreenString.alsoDeleteMediaReceived,
              style: AppTypography.innerText12Mediu(
                context,
              ).copyWith(color: AppColors.textColor.textDarkGray),
            ),
            SizedBox(height: SizeConfig.height(3)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: SizeConfig.height(5),
                  width: SizeConfig.width(35),
                  child: customBorderBtn(
                    context,
                    onTap: () => Navigator.pop(context, false),
                    title: AppString.cancel,
                  ),
                ),
                SizedBox(
                  height: SizeConfig.height(5),
                  width: SizeConfig.width(35),
                  child: customBtn2(
                    context,
                    onTap: () => Navigator.pop(context, true),
                    child: Text(
                      AppString.homeScreenString.clearChat,
                      style: AppTypography.h5(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor.textBlackColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _performClearChat();
    }
  }

  /// Perform the actual clear chat API call
  Future<void> _performClearChat() async {
    if (_chatProvider!.isDisposedOfChat) return;

    setState(() {
      _isClearingChat = true;
    });

    try {
      final success = await _chatProvider!.clearChat(chatId: widget.chatId!);

      if (success) {
        // Refresh the chat to show empty state
        await _refreshChatMessages();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppString.chatClearedSuccessfully),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppString.failedToClearChatPleaseTryAgain),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('${AppString.errorClearingChat}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppString.anErrorOccurredWhileClearingChat),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearingChat = false;
        });
      }
    }
  }

  // ignore: unused_element
  void _handleReportUser() {
    if (widget.userId == null) return;

    showReportUserDialog(
      context,
      userId: widget.userId!,
      userName: widget.chatName,
    );
  }

  // ignore: unused_element
  void _handleStarredMessages() {
    if (widget.chatId == null) {
      debugPrint('DEBUG: chatId is null, cannot open starred messages');
      return;
    }

    debugPrint(
      'DEBUG: Opening starred messages for chatId: ${widget.chatId}, chatName: ${widget.chatName}',
    );
    Navigator.pushNamed(
      context,
      AppRoutes.starredMessages,
      arguments: {'chatId': widget.chatId, 'chatName': widget.chatName},
    );
  }

  // ignore: unused_element
  void _handleChatMedia() {
    if (widget.chatId == null) {
      debugPrint('DEBUG: chatId is null, cannot open chat media');
      return;
    }

    debugPrint(
      'DEBUG: Opening chat media for chatId: ${widget.chatId}, chatName: ${widget.chatName}',
    );
    Navigator.pushNamed(
      context,
      AppRoutes.chatMedia,
      arguments: {'chatId': widget.chatId, 'chatName': widget.chatName},
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEARCH FUNCTIONALITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  void _performSearch(String query) async {
    if (widget.chatId == null || query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await _chatProvider?.searchMessages(
        searchText: query.trim(),
        chatId: widget.chatId!,
        page: _searchCurrentPage,
      );

      if (response != null && response['status'] == true) {
        final data = response['data'];
        final records = List<Map<String, dynamic>>.from(data['Records'] ?? []);
        final pagination = data['pagenation'] ?? {};

        setState(() {
          _searchResults = records;
          _searchCurrentPage = pagination['current_page'] ?? 1;
          _searchTotalPages = pagination['total_pages'] ?? 1;
        });
      } else {
        setState(() {
          _searchResults.clear();
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _searchResults.clear();
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _exitSearchMode() {
    setState(() {
      _isSearchMode = false;
      _searchQuery = '';
      _searchResults.clear();
      _searchCurrentPage = 1;
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  void _handleSearchResultTap(Map<String, dynamic> message) {
    // Handle tap on search result - could scroll to message in normal chat
    // For now, just show a snackbar or navigate to the message
    final messageId = message['message_id'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppString.tappedOnMessage} #$messageId'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _handleSearchResultLongPress(Map<String, dynamic> message) {
    if (!_chatProvider!.isDisposedOfChat && mounted) {
      // Convert search result message to chats.Records format for consistency
      final searchMessage = _convertSearchMessageToRecord(message);
      if (searchMessage != null) {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);

        final isCurrentlyStarred = chatProvider.isMessageStarred(
          searchMessage.messageId!,
        );

        _logger.d(
          'Long press on search result message ${searchMessage.messageId} - currently starred: $isCurrentlyStarred',
        );

        // Use the same dialog as normal chat messages
        chatTypeDailog(
          context,
          message: searchMessage,
          onPinUnpin: _handlePinUnpinMessage,
          onReply: (message) {
            // Exit search mode and set reply
            _exitSearchMode();
            _handleReply(message);
          },
          onDelete: _handleDeleteMessage,
          onStarUnstar: _handleStarUnstarMessage,
          onMultiSelect:
              _isMessageSelectableForMultiSelect(searchMessage)
                  ? _handleMultiSelectStart
                  : null,
          isStarred: isCurrentlyStarred,
        );
      }
    }
  }

  // Convert search result message format to chats.Records format
  chats.Records? _convertSearchMessageToRecord(
    Map<String, dynamic> searchMessage,
  ) {
    try {
      final user = searchMessage['User'] as Map<String, dynamic>? ?? {};

      // Create a chats.Records object from search result data
      return chats.Records(
        messageId: searchMessage['message_id'],
        messageContent: searchMessage['message_content'],
        messageType: searchMessage['message_type'],
        messageThumbnail: searchMessage['message_thumbnail'],
        replyTo: searchMessage['reply_to'],
        socialId: searchMessage['social_id'],
        messageLength: searchMessage['message_length'],
        messageSeenStatus: searchMessage['message_seen_status'],
        messageSize: searchMessage['message_size'],
        deletedFor: searchMessage['deleted_for'] ?? [],
        starredFor: searchMessage['starred_for'] ?? [],
        deletedForEveryone: searchMessage['deleted_for_everyone'] ?? false,
        pinned: searchMessage['pinned'] ?? false,
        pinLifetime: searchMessage['pin_lifetime'],
        pinnedTill: searchMessage['pinned_till'],
        stared:
            searchMessage['starred_for'] != null &&
            (searchMessage['starred_for'] as List).isNotEmpty,
        createdAt: searchMessage['createdAt'],
        updatedAt: searchMessage['updatedAt'],
        chatId: searchMessage['chat_id'],
        senderId: searchMessage['sender_id'],
        user: chats.User(
          userId: user['user_id'],
          userName: user['user_name'],
          fullName: user['full_name'],
          profilePic: user['profile_pic'],
        ),
      );
    } catch (e) {
      _logger.e('Error converting search message to Records format: $e');
      return null;
    }
  }
}
