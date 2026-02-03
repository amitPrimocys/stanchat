/// SocketEventController
///
/// Central hub that manages socket events and provides streams for UI components.
/// This controller handles all socket communication including chat messages,
/// online users, typing indicators, and chat list management.
///
/// Key Features:
/// - Real-time chat messaging
/// - Online/offline user status tracking
/// - Typing indicators
/// - Message pagination
/// - Automatic reconnection handling
///
/// Usage:
/// ```dart
/// final controller = SocketEventController(socketService, socketEvents);
/// await controller.initialize();
/// controller.setCurrentChat(chatId, peerId);
/// ```
library;

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:stanchat/core/services/socket/socket_service.dart';
import 'package:stanchat/featuers/chat/data/online_user_model.dart';
import 'package:stanchat/featuers/chat/data/chat_ids_model.dart';
import 'package:stanchat/featuers/chat/data/chat_list_model.dart' as chatlist;
import 'package:stanchat/featuers/chat/data/chats_model.dart';
import 'package:stanchat/featuers/chat/data/typing_model.dart';
import 'package:stanchat/featuers/chat/data/block_updates_model.dart';
import 'package:stanchat/featuers/chat/provider/archive_chat_provider.dart';
import 'package:stanchat/featuers/chat/utils/chat_cache_manager.dart';
import 'package:stanchat/utils/logger.dart';
import 'package:stanchat/utils/preference_key/preference_key.dart';
import 'package:stanchat/utils/preference_key/sharedpref_key.dart';

class SocketEventController with ChangeNotifier {
  // ═══════════════════════════════════════════════════════════════════════════
  // DEPENDENCIES
  // ═══════════════════════════════════════════════════════════════════════════

  final SocketService _socketService;
  final SocketEvents _socketEvents;
  ArchiveChatProvider? _archiveChatProvider;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
    'SocketEventController',
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTANTS
  // ═══════════════════════════════════════════════════════════════════════════

  static const int _defaultPageSize = 20;
  static const int _maxRecentMessages = 50;
  static const int _recentMessageCleanupThreshold = 25;

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE VARIABLES
  // ═══════════════════════════════════════════════════════════════════════════

  // Data models
  chatlist.ChatListModel _chatListData = chatlist.ChatListModel(chats: []);
  ChatsModel _chatsData = ChatsModel();
  final ChatIdsModel _chatIdsData = ChatIdsModel();
  OnlineUsersModel _onlineUsersData = OnlineUsersModel(onlineUsers: []);
  TypingModel _typingData = TypingModel();
  BlockUpdatesModel _blockUpdatesData = BlockUpdatesModel();

  // Loading states
  bool _isChatLoading = false;
  bool _isChatListLoading = false;
  bool _hasMoreMessages = true;
  bool _isConnected = false;
  bool _isInitialized = false;
  bool _isPaginationLoading = false;

  // Cache protection flag to prevent server responses from overriding fresh cached data
  bool _cacheDataProtected = false;
  bool _isRefreshing = false;

  // Current chat context
  int? _currentChatId;
  int? _currentUserId;
  int _chatsPageNo = 1;
  int? _lastChatRefresh; // Track last refresh time to prevent spam

  // Error handling
  String? _lastError;

  // Duplicate message prevention
  final Set<int> _recentlyProcessedMessages = <int>{};

  // Track already seen messages to prevent duplicate emissions
  final Set<int> _seenMessages = <int>{};

  // Track emission and acknowledgment statistics
  final Map<String, int> _emissionStats = {};

  // Typing status tracking
  final Map<int, bool> _userTypingStatus = {}; // userId -> isTyping
  final Map<String, bool> _chatTypingStatus = {}; // chatId -> isTyping
  int? _currentTypingUserId;

  // Track pending delete message operation
  int? _pendingDeleteMessageId;
  int? _pendingDeleteChatId;
  bool _isPendingDeleteForMe = false;

  // ✅ NEW: Chat focus tracking
  bool _isChatScreenActive = false;
  bool _isAppInForeground = true;
  String? _activeChatScreenId;
  bool _isPendingFocusChange = false;

  bool get isChatScreenActive => _isChatScreenActive;
  bool get isAppInForeground => _isAppInForeground;
  String? get activeChatScreenId => _activeChatScreenId;
  int? get currentChatId => _currentChatId;

  // Message lock when new message received
  bool _isUpdatingChatList = false;
  final List<Records> _pendingMessages = [];

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT FOCUS
  // ═══════════════════════════════════════════════════════════════════════════

  // ✅ NEW: Methods to manage chat focus
  void setChatScreenActive(int chatId, int userId, {bool isActive = true}) {
    _logger.d(
      'Chat screen focus request: active=$isActive, chatId=$chatId, userId=$userId',
    );

    // ✅ TRACK WHEN FOCUS CHANGES
    _isPendingFocusChange = true;

    // ✅ IMMEDIATE STATE UPDATE
    _isChatScreenActive = isActive;
    _activeChatScreenId = isActive ? '${chatId}_$userId' : null;

    _logger.d(
      '✅ Chat screen focus updated: active=$_isChatScreenActive, screenId=$_activeChatScreenId',
    );

    // ✅ CLEAR PENDING FLAG AFTER SHORT DELAY
    Future.delayed(Duration(milliseconds: 200), () {
      _isPendingFocusChange = false;
    });

    // Safely notify listeners after frame to avoid setState during dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void setAppForegroundState(bool isInForeground) {
    _isAppInForeground = isInForeground;
    _logger.d('App foreground state changed: $isInForeground');

    // If app goes to background, consider chat screen inactive
    if (!isInForeground) {
      _isChatScreenActive = false;
      _activeChatScreenId = null;
    }

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAM CONTROLLERS
  // ═══════════════════════════════════════════════════════════════════════════

  final StreamController<chatlist.ChatListModel> _chatListStreamController =
      StreamController<chatlist.ChatListModel>.broadcast();
  final StreamController<ChatsModel> _chatsStreamController =
      StreamController<ChatsModel>.broadcast();
  final StreamController<ChatIdsModel> _chatIdsStreamController =
      StreamController<ChatIdsModel>.broadcast();
  final StreamController<OnlineUsersModel> _onlineUsersStreamController =
      StreamController<OnlineUsersModel>.broadcast();
  final StreamController<TypingModel> _typingStreamController =
      StreamController<TypingModel>.broadcast();
  final StreamController<BlockUpdatesModel> _blockUpdatesStreamController =
      StreamController<BlockUpdatesModel>.broadcast();
  final StreamController<ChatsModel> _pinUnpinStreamController =
      StreamController<ChatsModel>.broadcast();

  // Stream for real-time message notifications (only socket messages, not pagination)
  final StreamController<Records> _newMessageStreamController =
      StreamController<Records>.broadcast();

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ═══════════════════════════════════════════════════════════════════════════

  SocketEventController(
    this._socketService,
    this._socketEvents, [
    this._archiveChatProvider,
  ]) {
    _logger.i('Creating SocketEventController');
    _setupSocketEventListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC GETTERS
  // ═══════════════════════════════════════════════════════════════════════════

  // Data getters
  chatlist.ChatListModel get chatListData => _chatListData;
  ChatsModel get chatsData => _chatsData;
  ChatIdsModel get chatIdsData => _chatIdsData;
  OnlineUsersModel get onlineUsersData => _onlineUsersData;
  TypingModel get typingData => _typingData;
  BlockUpdatesModel get blockUpdatesData => _blockUpdatesData;

  // State getters
  bool get isChatLoading => _isChatLoading;
  bool get isChatListLoading => _isChatListLoading;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  bool get isPaginationLoading => _isPaginationLoading;
  bool get isRefreshing => _isRefreshing;

  // Stream getters
  Stream<chatlist.ChatListModel> get chatListStream =>
      _chatListStreamController.stream;
  Stream<ChatsModel> get chatsStream => _chatsStreamController.stream;
  Stream<ChatIdsModel> get chatIdsStream => _chatIdsStreamController.stream;
  Stream<OnlineUsersModel> get onlineUsersStream =>
      _onlineUsersStreamController.stream;
  Stream<TypingModel> get typingStream => _typingStreamController.stream;
  Stream<BlockUpdatesModel> get blockUpdatesStream =>
      _blockUpdatesStreamController.stream;

  Stream<ChatsModel> get pinUnpinStream => _pinUnpinStreamController.stream;

  // Stream for real-time message notifications (socket messages only)
  Stream<Records> get newMessageStream => _newMessageStreamController.stream;

  // ═══════════════════════════════════════════════════════════════════════════
  // LOADER STATE
  // ═══════════════════════════════════════════════════════════════════════════

  // ✅ Add starred messages data storage to your SocketEventController class
  final ChatsModel _starredMessagesData = ChatsModel();
  ChatsModel get starredMessagesData => _starredMessagesData;

  void _setIsChatLoading(bool value) {
    if (_isChatLoading != value) {
      _isChatLoading = value;
      notifyListeners();
    }
  }

  /// 🗄️ Public method to set chat loading state (for cache integration)
  void setChatLoadingState(bool value) {
    _setIsChatLoading(value);
  }

  /// 🛡️ Set cache protection flag to prevent server overrides
  void setCacheDataProtection(bool value) {
    _cacheDataProtected = value;
    if (value) {
      _logger.d(
        '🛡️ Cache data protection ENABLED - server responses will be merged instead of replaced',
      );
    } else {
      _logger.d(
        '🔓 Cache data protection DISABLED - server responses will replace data normally',
      );
    }
  }

  void _setPaginationLoading(bool value) {
    if (_isPaginationLoading != value) {
      _isPaginationLoading = value;
      notifyListeners();
    }
  }

  void _setRefreshing(bool value) {
    if (_isRefreshing != value) {
      _isRefreshing = value;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the socket controller
  ///
  /// This method should be called once when the controller is first used.
  /// It establishes socket connection and loads initial data.
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.d('SocketEventController already initialized');
      return;
    }

    _logger.i('Initializing SocketEventController');

    try {
      // Setup event listeners if not already set up
      _setupSocketEventListeners();

      // Connect to socket
      final connectionSuccess = await connect();
      if (!connectionSuccess) {
        throw Exception('Failed to establish socket connection');
      }

      // Load initial data
      await Future.wait([emitChatList(), emitInitialOnlineUser()]);

      _isInitialized = true;
      _logger.i('SocketEventController initialized successfully');
    } catch (e) {
      _lastError = 'Initialization failed: ${e.toString()}';
      _logger.e(_lastError!);
      notifyListeners();
      rethrow;
    }
  }

  /// Connect to the socket server
  Future<bool> connect() async {
    try {
      _isConnected = await _socketService.connect();

      if (_isConnected) {
        _logger.i('Socket connected successfully');
        _clearError();
        return true;
      } else {
        _setError('Failed to connect to socket');
        return false;
      }
    } catch (e) {
      _setError('Socket connection error: ${e.toString()}');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT MANAGEMENT METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set the current active chat context
  ///
  /// [chatId] - The ID of the chat (0 for new chats)
  /// [peerId] - The ID of the peer user
  void setCurrentChat(int chatId, int peerId) {
    _logger.d('Setting current chat - chatId: $chatId, peerId: $peerId');

    // Validate input parameters
    if (!_isValidChatContext(chatId, peerId)) {
      _logger.e('Invalid chat context: chatId=$chatId, peerId=$peerId');
      return;
    }

    // Clear typing context when switching chats
    _clearTypingContext();

    // Check if context has actually changed
    final bool contextChanged =
        _currentChatId != chatId || _currentUserId != peerId;

    _currentChatId = chatId;
    _currentUserId = peerId;

    if (contextChanged) {
      _logger.d('Chat context changed, resetting state');
      _resetChatState();
      _loadMessagesForCurrentChat();
    } else {
      _logger.d('Chat context unchanged, skipping reload');
    }

    notifyListeners();
  }

  /// ✅ Set current chat without triggering loading state (for cached data)
  void setCurrentChatWithoutLoading(int chatId, int peerId) {
    _logger.d(
      'Setting current chat WITHOUT LOADING: chatId=$chatId, peerId=$peerId',
    );

    // Update chat context without triggering loading
    _currentChatId = chatId;
    _currentUserId = peerId;

    // Update typing context for chat ID transition
    if (chatId > 0) {
      _updateTypingContextForChatId(chatId);
    }

    // Ensure loading state is false since we're using cached data
    _setIsChatLoading(false);

    notifyListeners();
  }

  /// Update the current chat ID (used when a new chat gets an ID)
  void updateCurrentChatId(int newChatId) {
    if (newChatId <= 0) {
      _logger.w('Attempted to update chat ID with invalid value: $newChatId');
      return;
    }

    _logger.d('Updating current chat ID from $_currentChatId to $newChatId');
    _currentChatId = newChatId;

    // Update typing context for chat ID transition
    _updateTypingContextForChatId(newChatId);

    notifyListeners();
  }

  Future<void> _loadMessagesForCurrentChat() async {
    if (_currentChatId == null && _currentUserId == null) {
      _logger.e('Cannot load messages: No valid chat context');
      return;
    }

    try {
      // ✅ Set initial loading state (not pagination or refresh)
      _setIsChatLoading(true);

      // ✅ FIX: Add timeout safety mechanism
      Timer(Duration(seconds: 15), () {
        if (_isChatLoading) {
          _logger.w('🕐 Chat loading timeout - forcing loading state to false');
          _setIsChatLoading(false);
        }
      });

      // Reset pagination
      _chatsPageNo = 1;
      _hasMoreMessages = true;

      if (_currentChatId != null && _currentChatId! > 0) {
        _logger.d('Loading messages for existing chat: $_currentChatId');
        await emitChatMessages(chatId: _currentChatId!, page: 1);
      } else if (_currentUserId != null && _currentUserId! > 0) {
        _logger.d('Loading messages for new chat with user: $_currentUserId');
        await emitChatMessages(peerId: _currentUserId!, page: 1);
      }
    } catch (e) {
      _logger.e('Error loading messages for current chat: $e');
      _setError('Failed to load messages: ${e.toString()}');
      _setIsChatLoading(false);
    }
  }

  Future<void> refreshChatMessages(int chatId, int peerId) async {
    if (_isRefreshing) {
      _logger.d('Already refreshing, skipping duplicate request');
      return;
    }

    try {
      _logger.d('🔄 Starting chat messages refresh in SocketEventController');
      _setRefreshing(true);

      // ✅ IMPORTANT: Reset pagination for refresh
      _chatsPageNo = 1;
      _hasMoreMessages = true;

      // ✅ Clear existing messages before refresh
      _chatsData = ChatsModel();
      _chatsStreamController.add(_chatsData);

      // ✅ Request fresh data from server
      if (chatId > 0) {
        await emitChatMessages(chatId: chatId, page: 1);
      } else {
        await emitChatMessages(peerId: peerId, page: 1);
      }

      _logger.d('✅ Refresh request sent successfully');
    } catch (e) {
      _logger.e('❌ Error refreshing chat messages: $e');
      _setRefreshing(false); // Reset on error
      rethrow;
    }
    // Note: _setRefreshing(false) will be called by the message list listener
  }

  /// Reset chat state for new chat context
  void _resetChatState() {
    _chatsData = ChatsModel();
    _chatsPageNo = 1;
    _hasMoreMessages = true;
    _chatsStreamController.add(_chatsData);

    // Clear seen messages set when switching chats
    _seenMessages.clear();
    clearEmissionTracking(); // Clear emission tracking for new chat
    _logger.d(
      'Cleared seen messages cache and emission tracking for new chat context',
    );
  }

  /// Reset chat data completely
  void resetChat() {
    _logger.d('Resetting chat data');
    _resetChatState();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE LOADING METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Emit request to load chat messages
  ///
  /// [chatId] - ID of existing chat (use 0 for new chats)
  /// [peerId] - ID of peer user (for new chats)
  /// [page] - Page number for pagination
  /// [pageSize] - Number of messages per page
  Future<void> emitChatMessages({
    int chatId = 0,
    int peerId = 0,
    int page = 1,
    int pageSize = _defaultPageSize,
  }) async {
    // Use current context if parameters not provided
    final int effectiveChatId = chatId > 0 ? chatId : (_currentChatId ?? 0);
    final int effectivePeerId = peerId > 0 ? peerId : (_currentUserId ?? 0);

    // Validate parameters
    if (!_isValidChatContext(effectiveChatId, effectivePeerId)) {
      _logger.e(
        'Invalid chat context for message loading: chatId=$effectiveChatId, peerId=$effectivePeerId',
      );
      return;
    }

    _setIsChatLoading(true);

    // ✅ FIX: Add timeout safety mechanism for socket requests
    Timer(Duration(seconds: 15), () {
      if (_isChatLoading) {
        _logger.w('🕐 Socket request timeout - forcing loading state to false');
        _setIsChatLoading(false);
      }
    });

    try {
      final Map<String, dynamic> eventData;
      final String logContext;

      if (effectiveChatId > 0) {
        eventData = {
          "chat_id": effectiveChatId,
          "page": page,
          "pageSize": pageSize,
          "pinned": true,
        };
        logContext = 'existing chat - Chat ID: $effectiveChatId';
      } else {
        eventData = {
          "user_id": effectivePeerId,
          "page": page,
          "pageSize": pageSize,
          "pinned": true,
        };
        logContext = 'new chat - User ID: $effectivePeerId';
      }

      _logger.d(
        'Emitting message_list for $logContext, Page: $page, PageSize: $pageSize',
      );
      _logger.d('Event data: $eventData');

      // Actually emit the socket event
      _socketService.emit(_socketEvents.messageList, data: eventData);

      // Mark messages as seen for first page
      // if (page == 1) {
      //   _markFirstMessageAsSeen(effectiveChatId);
      // }
      if (page == 1 && chatId > 0) {
        // Delay to ensure messages are loaded first
        Future.delayed(Duration(milliseconds: 500), () {
          // _markFirstMessageAsSeen(chatId);
        });
      }

      _logger.d('Socket event emitted successfully');
    } catch (e) {
      _setError('Error requesting chat messages: ${e.toString()}');
      _setIsChatLoading(false);
      _logger.e('Failed to emit chat messages: $e');
    }
  }

  /// Load more messages (pagination)
  Future<void> loadMoreMessages() async {
    // ✅ ESSENTIAL CHECKS ONLY
    if (_isPaginationLoading || !_hasMoreMessages) {
      _logger.d(
        '⏭️ Pagination skipped - loading: $_isPaginationLoading, hasMore: $_hasMoreMessages',
      );
      return;
    }

    if (!_hasValidCurrentChatContext()) {
      _logger.e('❌ No valid chat context for pagination');
      return;
    }

    try {
      // ✅ SET LOADING STATE IMMEDIATELY
      _setPaginationLoading(true);

      // ✅ CALCULATE NEXT PAGE
      final pagination = _chatsData.pagination;
      final nextPage = (pagination?.currentPage ?? 0) + 1;
      final totalPages = pagination?.totalPages ?? 1;

      // ✅ FINAL CHECK: Don't exceed total pages
      if (nextPage > totalPages) {
        _logger.d('🏁 Reached last page ($nextPage > $totalPages)');
        _hasMoreMessages = false;
        _setPaginationLoading(false);
        return;
      }

      _logger.d('📄 Loading page $nextPage of $totalPages');

      // ✅ EMIT REQUEST BASED ON CHAT CONTEXT
      if (_currentChatId != null && _currentChatId! > 0) {
        await _emitPaginationForExistingChat(_currentChatId!, nextPage);
      } else if (_currentUserId != null && _currentUserId! > 0) {
        await _emitPaginationForNewChat(_currentUserId!, nextPage);
      }

      _logger.d('✅ Pagination request sent for page $nextPage');
    } catch (e) {
      _logger.e('❌ Pagination error: $e');
      _setPaginationLoading(false);
      _setError('Failed to load more messages: ${e.toString()}');
    }
    // Note: _setPaginationLoading(false) will be called by the response handler
  }

  /// Emit pagination request for existing chat
  Future<void> _emitPaginationForExistingChat(int chatId, int page) async {
    _logger.d('📤 Requesting page $page for chat $chatId');

    _socketService.emit(
      _socketEvents.messageList,
      data: {
        "chat_id": chatId,
        "page": page,
        "pageSize": _defaultPageSize,
        "pinned": false, // Don't fetch pinned messages in pagination
      },
    );
  }

  /// Emit pagination request for new chat
  Future<void> _emitPaginationForNewChat(int userId, int page) async {
    _logger.d('📤 Requesting page $page for user $userId');

    _socketService.emit(
      _socketEvents.messageList,
      data: {
        "user_id": userId,
        "page": page,
        "pageSize": _defaultPageSize,
        "pinned": false, // Don't fetch pinned messages in pagination
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT LIST METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Request chat list from server
  // Future<void> emitChatList() async {
  //   try {
  //     _isChatListLoading = true;
  //     notifyListeners();

  //     _logger.d('Requesting chat list');
  //     _socketService.emit(_socketEvents.chatList, data: {});
  //   } catch (e) {
  //     _setError('Error requesting chat list: ${e.toString()}');
  //     _isChatListLoading = false;
  //     notifyListeners();
  //   }
  // }

  Future<void> emitChatList({int page = 1, int pageSize = 20}) async {
    try {
      // Always set loading state for any page request
      _isChatListLoading = true;
      notifyListeners();

      final Map<String, dynamic> eventData = {
        "page": page,
        "pageSize": pageSize,
      };

      _logger.d(
        '🔄 EMITTING paginated chat list request - Page: $page, PageSize: $pageSize',
      );
      _logger.d('📤 Event data being sent: $eventData');

      // Emit the socket event with pagination parameters
      _socketService.emit(_socketEvents.chatList, data: eventData);

      _logger.d('Paginated chat list request sent successfully');
    } catch (e) {
      _setError('Error requesting paginated chat list: ${e.toString()}');
      _isChatListLoading = false;
      notifyListeners();
    }
  }

  /// Refresh chat list (with optional silent mode)
  Future<void> refreshChatList({bool silent = false}) async {
    try {
      if (!silent) {
        _isChatListLoading = true;
        notifyListeners();
      }

      _logger.d('Refreshing chat list${silent ? ' (silent)' : ''}');
      _socketService.emit(_socketEvents.chatList, data: {});
    } catch (e) {
      _setError('Error refreshing chat list: ${e.toString()}');
      if (!silent) {
        _isChatListLoading = false;
        notifyListeners();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONLINE USERS METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Request initial online users data
  Future<void> emitInitialOnlineUser() async {
    try {
      _logger.d('Requesting initial online users');
      _socketService.emit(_socketEvents.initialOnlineUser, data: {});
    } catch (e) {
      _setError('Error requesting online users: ${e.toString()}');
    }
  }

  /// Check if a specific user is online
  bool isUserOnline(int userId) {
    if (_onlineUsersData.onlineUsers?.isEmpty ?? true) {
      return false;
    }

    final user = _onlineUsersData.onlineUsers!.firstWhere(
      (user) => user.userId == userId,
      orElse: () => OnlineUsers(userId: userId, isOnline: false),
    );

    return user.isOnline == true;
  }

  /// Get user's last seen timestamp
  String? getUserLastSeen(int userId) {
    if (_onlineUsersData.onlineUsers == null) return null;

    final user = _onlineUsersData.onlineUsers!.firstWhere(
      (user) => user.userId == userId,
      orElse: () => OnlineUsers(userId: userId),
    );

    return user.updatedAt;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TYPING INDICATOR METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send typing indicator
  void sendTypingIndicator(String chatId, bool isTyping) {
    try {
      final int chatIdInt = int.tryParse(chatId) ?? 0;

      if (chatIdInt == 0 && _currentUserId != null && _currentUserId! > 0) {
        _sendTypingIndicatorForNewChat(_currentUserId!, isTyping);
      } else if (chatIdInt > 0) {
        _sendTypingIndicatorForExistingChat(chatIdInt, isTyping);
      } else {
        _logger.w('Cannot send typing indicator - invalid chat context');
      }
    } catch (e) {
      _setError('Error sending typing indicator: ${e.toString()}');
    }
  }

  /// Check if someone is typing in a chat
  bool isUserTypingInChat(int chatId) {
    final bool socketTyping = _typingData.typing == true;
    if (!socketTyping) return false;

    if (chatId == 0 && _currentUserId != null && _currentUserId! > 0) {
      return _currentTypingUserId == _currentUserId;
    }

    if (chatId > 0) {
      return _typingData.chatId == chatId.toString();
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE STATUS METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mark a message as seen
  Future<bool> markMessageAsSeen(String chatId, String messageId) async {
    try {
      _logger.d(
        'Marking message as seen - chatId: $chatId, messageId: $messageId',
      );

      _socketService.emit(
        _socketEvents.realTimeMessageSeen,
        data: {"chat_id": chatId, "message_id": messageId, "status": "seen"},
      );

      // Update local chat list to clear unread count
      _updateLocalUnreadCount(chatId);

      return true;
    } catch (e) {
      _setError('Error marking message as seen: ${e.toString()}');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Format timestamp for UI display
  String formatTime(String? time) {
    if (time == null) return "";

    try {
      final dateTime = DateTime.parse(time);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return DateFormat('MMM d, yyyy').format(dateTime);
      } else if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hr' : 'hr'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'min' : 'min'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      _logger.e('Error formatting time: $e');
      return "";
    }
  }

  /// Clear error message
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Silent refresh of all data
  Future<void> silentRefresh() async {
    await refreshChatList(silent: true);

    if (_currentChatId != null) {
      _socketService.emit(
        _socketEvents.messageList,
        data: {
          "chat_id": _currentChatId,
          "page": 1,
          "pageSize": _defaultPageSize,
        },
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set chat loading state

  /// Set error message and notify listeners
  void _setError(String error) {
    _lastError = error;
    _logger.e(error);
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _lastError = null;
  }

  /// Validate chat context parameters
  bool _isValidChatContext(int chatId, int peerId) {
    return chatId > 0 || peerId > 0;
  }

  /// Check if current chat context is valid
  bool _hasValidCurrentChatContext() {
    return (_currentChatId != null && _currentChatId! > 0) ||
        (_currentUserId != null && _currentUserId! > 0);
  }

  /// Send typing indicator for new chat
  void _sendTypingIndicatorForNewChat(int userId, bool isTyping) {
    _logger.d(
      'Sending typing indicator for new chat - UserID: $userId, IsTyping: $isTyping',
    );

    _userTypingStatus[userId] = isTyping;
    _currentTypingUserId = isTyping ? userId : null;

    _socketService.emit(
      _socketEvents.typing,
      data: {"typing": isTyping, "user_id": userId},
    );
  }

  /// Send typing indicator for existing chat
  void _sendTypingIndicatorForExistingChat(int chatId, bool isTyping) {
    _logger.d(
      'Sending typing indicator for existing chat - ChatID: $chatId, IsTyping: $isTyping',
    );

    final String chatIdStr = chatId.toString();
    _chatTypingStatus[chatIdStr] = isTyping;
    _currentTypingUserId = null;

    _socketService.emit(
      _socketEvents.typing,
      data: {"typing": isTyping, "chat_id": chatId},
    );
  }

  /// Update typing context when chat ID changes
  void _updateTypingContextForChatId(int newChatId) {
    if (_currentTypingUserId != null && newChatId > 0) {
      final String newChatIdStr = newChatId.toString();
      _chatTypingStatus[newChatIdStr] =
          _userTypingStatus[_currentTypingUserId] ?? false;
      _currentTypingUserId = null;

      _logger.d(
        'Switched typing context from user-based to chat-based for chat ID: $newChatId',
      );
    }
  }

  /// Clear typing context
  void _clearTypingContext() {
    _userTypingStatus.clear();
    _chatTypingStatus.clear();
    _currentTypingUserId = null;
  }

  /// Update local unread count for a chat
  void _updateLocalUnreadCount(String chatId) {
    if (_chatListData.chats.isNotEmpty) {
      for (var chat in _chatListData.chats) {
        if (chat.records?.isNotEmpty == true &&
            chat.records![0].chatId.toString() == chatId) {
          chat.records![0].unseenCount = 0;
          break;
        }
      }
      notifyListeners();
    }
  }

  /// Get current user ID asynchronously
  Future<int?> _getCurrentUserIdAsync() async {
    try {
      final String? userIdString = await SecurePrefs.getString(
        SecureStorageKeys.USERID,
      );
      return int.tryParse(userIdString ?? '');
    } catch (e) {
      _logger.e('Error getting current user ID: $e');
      return null;
    }
  }

  /// Check if message is duplicate
  bool _isDuplicateMessage(int? messageId) {
    if (messageId == null) return false;

    if (_recentlyProcessedMessages.contains(messageId)) {
      _logger.d(
        'Message $messageId was recently processed, skipping duplicate',
      );
      return true;
    }

    _recentlyProcessedMessages.add(messageId);

    // Clean up old message IDs to prevent memory growth
    if (_recentlyProcessedMessages.length > _maxRecentMessages) {
      final list = _recentlyProcessedMessages.toList();
      list.removeRange(0, _recentMessageCleanupThreshold);
      _recentlyProcessedMessages.clear();
      _recentlyProcessedMessages.addAll(list);
    }

    return false;
  }

  // ==========================================
  // DELETE MESSAGE HANDLE
  // ==========================================

  /// Emit delete message for me event
  void emitDeleteMessageForMe(int chatId, int messageId) {
    try {
      _logger.d(
        '📤 Emitting delete for me - ChatID: $chatId, MessageID: $messageId',
      );

      // ✅ Store the pending delete action
      _storePendingDeleteAction(messageId, chatId, true);

      _socketService.emit(
        _socketEvents.messageDeleteForMe,
        data: {'chat_id': chatId, 'message_id': messageId},
      );

      _logger.d('✅ Delete for me event emitted successfully');
    } catch (e) {
      _setError('Error emitting delete for me: ${e.toString()}');
      _logger.e('❌ Failed to emit delete for me: $e');
    }
  }

  /// Emit delete message for everyone event
  void emitDeleteMessageForEveryone(int chatId, int messageId) {
    try {
      _logger.d(
        '📤 Emitting delete for everyone - ChatID: $chatId, MessageID: $messageId',
      );

      // ✅ Store the pending delete action
      _storePendingDeleteAction(messageId, chatId, false);

      _socketService.emit(
        _socketEvents.messageDeleteForEveryone,
        data: {'chat_id': chatId, 'message_id': messageId},
      );

      _logger.d('✅ Delete for everyone event emitted successfully');
    } catch (e) {
      _setError('Error emitting delete for everyone: ${e.toString()}');
      _logger.e('❌ Failed to emit delete for everyone: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOCKET EVENT LISTENERS SETUP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Setup all socket event listeners
  void _setupSocketEventListeners() {
    _setupChatListListener();
    _setupMessageListListener();
    _setupPinUnpinMessageListener();
    _setupStarUnstarMessageListener();
    _setupOnlineUsersListeners();
    _setupTypingListener();
    _setupBlockUpdatesListener();
    _setupNewMessageListener();
    _setupMessageSeenListeners();
    _setupConnectionListeners();
    _setupMessageDeletionListeners();
    _setupArchiveChatListeners();
    _setupMissedCallListener();
    _setupCallEventListeners();
  }

  /// Setup chat list event listener
  // void _setupChatListListener() {
  //   _socketService.on(_socketEvents.chatList, (data) {
  //     _logger.d('Received chat list: $data');
  //     try {
  //       _chatListData = chatlist.ChatListModel.fromJson(data);
  //       _chatListStreamController.add(_chatListData);
  //       _isChatListLoading = false;
  //       notifyListeners();
  //     } catch (e) {
  //       _setError('Error parsing chat list: ${e.toString()}');
  //     }
  //   });
  // }
  void _setupChatListListener() {
    _socketService.on(_socketEvents.chatList, (data) {
      _logger.d(
        '📥 RECEIVED chat list response: ${data.toString().length > 500 ? '${data.toString().substring(0, 500)}...[truncated]' : data}',
      );

      try {
        // ✅ FIXED: Handle both paginated and non-paginated responses
        final parsedData = _parseChatListResponse(data);

        if (parsedData != null) {
          // ✅ NEW: Use unified chat processing that handles both regular and archived chats
          _processUnifiedChatListResponse(parsedData);

          // ✅ Log pagination info if available
          if (_chatListData.pagination != null) {
            final p = _chatListData.pagination!;
            _logger.d(
              'Chat list pagination - Page: ${p.currentPage}/${p.totalPages}, Total: ${p.totalRecords}',
            );
          }
        } else {
          throw Exception('Failed to parse chat list response');
        }

        _isChatListLoading = false;
        notifyListeners();
      } catch (e) {
        _setError('Error parsing chat list: ${e.toString()}');
        _isChatListLoading = false;
        notifyListeners();
      }
    });
  }

  /// Parse chat list response to handle different formats
  chatlist.ChatListModel? _parseChatListResponse(dynamic data) {
    try {
      _logger.d('🔍 Parsing chat list response type: ${data.runtimeType}');

      if (data is Map<String, dynamic>) {
        _logger.d('📋 Chat list response keys: ${data.keys.toList()}');

        // ✅ Handle your specific response format based on the example you provided
        if (data.containsKey('Chats') && data.containsKey('pagination')) {
          // This matches your response format exactly
          return chatlist.ChatListModel.fromJson(data);
        }
        // Fallback to direct parsing
        else if (data.containsKey('chats')) {
          return chatlist.ChatListModel.fromJson(data);
        }
        // Try direct parsing as ChatListModel
        else {
          try {
            return chatlist.ChatListModel.fromJson(data);
          } catch (e) {
            _logger.w('⚠️ Direct ChatListModel parsing failed: $e');
          }
        }
      }

      _logger.e('❌ Unsupported chat list response format');
      return null;
    } catch (e, stackTrace) {
      _logger.e('❌ Chat list parsing error: $e');
      _logger.e('📍 Stack trace: $stackTrace');
      _logProblematicChatListData(data);
      return null;
    }
  }

  /// Log problematic chat list data for debugging
  void _logProblematicChatListData(dynamic data) {
    try {
      final dataStr = data.toString();
      final debugStr =
          dataStr.length > 500
              ? '${dataStr.substring(0, 500)}...[truncated]'
              : dataStr;

      _logger.d('🔍 Problematic chat list data:');
      _logger.d(debugStr);

      if (data is Map<String, dynamic>) {
        _logger.d('📋 Response structure:');
        data.forEach((key, value) {
          final valueType = value.runtimeType.toString();
          final valueInfo =
              value is List
                  ? '$valueType[${value.length}]'
                  : value is Map
                  ? '$valueType{${value.keys.length} keys}'
                  : valueType;
          _logger.d('  $key: $valueInfo');
        });
      }
    } catch (e) {
      _logger.d('🔍 Could not serialize problematic chat list data: $e');
    }
  }

  /// ✅ NEW: Unified chat processing method that handles both regular and archived chats
  /// This processes all chats from socket events and splits them into regular and archived lists
  void _processUnifiedChatListResponse(
    chatlist.ChatListModel parsedData,
  ) async {
    try {
      // Get current user ID to determine which chats are archived
      final currentUserId = await _getCurrentUserIdAsync();
      if (currentUserId == null) {
        _logger.w(
          'Cannot process unified chat list - current user ID not available',
        );
        // Fall back to regular processing
        _processRegularChatList(parsedData);
        return;
      }

      _logger.d(
        '🔄 Processing unified chat list with ${parsedData.chats.length} chats for user $currentUserId',
      );

      final isFirstPage = parsedData.pagination?.currentPage == 1;

      // Separate chats into regular and archived based on archived_for field
      final List<chatlist.Chats> regularChats = [];
      final List<chatlist.Chats> archivedChats = [];

      for (final chat in parsedData.chats) {
        final record =
            chat.records?.isNotEmpty == true ? chat.records!.first : null;
        final archivedFor = record?.archivedFor ?? [];

        // Check if current user ID is in the archived_for list
        final isArchived =
            archivedFor.contains(currentUserId.toString()) ||
            archivedFor.contains(currentUserId);

        if (isArchived) {
          archivedChats.add(chat);
        } else {
          regularChats.add(chat);
        }
      }

      _logger.d(
        '📊 Split results: ${regularChats.length} regular, ${archivedChats.length} archived',
      );

      // Process regular chats (existing logic)
      final regularChatListData = chatlist.ChatListModel(
        pagination: parsedData.pagination,
        chats: regularChats,
      );

      if (isFirstPage || _chatListData.chats.isEmpty) {
        _chatListData = regularChatListData;
        _logger.d(
          '📄 Replaced regular chat list with ${_chatListData.chats.length} chats',
        );
      } else {
        // Append new regular chats (avoid duplicates)
        final existingChatIds =
            _chatListData.chats
                .expand((chat) => chat.records?.map((r) => r.chatId) ?? [])
                .where((id) => id != null)
                .toSet();

        final newRegularChats =
            regularChats.where((chat) {
              final chatId = chat.records?.first.chatId;
              return chatId != null && !existingChatIds.contains(chatId);
            }).toList();

        _chatListData.chats.addAll(newRegularChats);
        _chatListData.pagination = parsedData.pagination;
        _logger.d(
          '📄 Added ${newRegularChats.length} new regular chats via pagination (total: ${_chatListData.chats.length})',
        );
      }

      // Process archived chats via ArchiveChatProvider
      if (_archiveChatProvider != null && archivedChats.isNotEmpty) {
        _logger.d('📦 Updating archived chats via provider');
        // Convert archived chats to the format expected by ArchiveChatProvider
        final archivedData = {
          'pagination': parsedData.pagination?.toJson(),
          'Chats': archivedChats.map((chat) => chat.toJson()).toList(),
        };
        _archiveChatProvider!.handleArchivedChatList(archivedData);
      }

      // Update streams and listeners
      _chatListStreamController.add(_chatListData);
      _logger.d(
        '✅ Unified chat processing complete - regular: ${_chatListData.chats.length}, archived: ${archivedChats.length}',
      );
    } catch (e) {
      _logger.e('❌ Error in unified chat processing: $e');
      // Fall back to regular processing
      _processRegularChatList(parsedData);
    }
  }

  /// ✅ HELPER: Process regular chat list (fallback method)
  void _processRegularChatList(chatlist.ChatListModel parsedData) {
    final isFirstPage = parsedData.pagination?.currentPage == 1;

    if (isFirstPage || _chatListData.chats.isEmpty) {
      _chatListData = parsedData;
      _logger.d(
        '📄 Replaced chat list with ${_chatListData.chats.length} chats (fallback)',
      );
    } else {
      final existingChatIds =
          _chatListData.chats
              .expand((chat) => chat.records?.map((r) => r.chatId) ?? [])
              .where((id) => id != null)
              .toSet();

      final newChats =
          parsedData.chats.where((chat) {
            final chatId = chat.records?.first.chatId;
            return chatId != null && !existingChatIds.contains(chatId);
          }).toList();

      _chatListData.chats.addAll(newChats);
      _chatListData.pagination = parsedData.pagination;
      _logger.d(
        '📄 Added ${newChats.length} new chats via pagination (total: ${_chatListData.chats.length}) (fallback)',
      );
    }

    _chatListStreamController.add(_chatListData);
  }

  void _setupPinUnpinMessageListener() {
    _socketService.on(_socketEvents.pinnedUnpinnedMessage, (data) {
      _logger.d('📌 Received pin/unpin message response from socket: $data');

      try {
        // Handle both direct Records array and wrapped response formats
        List<dynamic> recordsList = [];

        if (data is Map<String, dynamic>) {
          // Check for Records key (uppercase)
          if (data.containsKey('Records') && data['Records'] is List) {
            recordsList = data['Records'] as List<dynamic>;
          }
          // Check for records key (lowercase)
          else if (data.containsKey('records') && data['records'] is List) {
            recordsList = data['records'] as List<dynamic>;
          }
          // If the data itself looks like a ChatsModel structure
          else {
            try {
              final ChatsModel parsedData = ChatsModel.fromJson(data);
              recordsList =
                  parsedData.records?.map((r) => r.toJson()).toList() ?? [];
            } catch (e) {
              _logger.w('⚠️ Could not parse as ChatsModel: $e');
            }
          }
        }
        // Handle direct array response
        else if (data is List) {
          recordsList = data;
        }

        if (recordsList.isEmpty) {
          _logger.w('⚠️ No records found in pin/unpin socket response');
          return;
        }

        // ✅ CREATE UPDATED RECORDS LIST
        List<Records> updatedRecords = [];

        // Process each record in the response
        for (var recordData in recordsList) {
          if (recordData is Map<String, dynamic>) {
            try {
              // Create Records object from the map
              final Records updatedMessage = Records.fromJson(recordData);

              _logger.d(
                '📌 Processing pin status change for message ${updatedMessage.messageId}: pinned=${updatedMessage.pinned}',
              );

              // ✅ UPDATE EXISTING MESSAGES IN CHAT DATA
              _updateExistingMessagePinStatus(updatedMessage);

              // ✅ UPDATE PINNED MESSAGES COLLECTION
              _updatePinnedMessagesCollection(updatedMessage);

              // ✅ ADD TO UPDATED RECORDS LIST
              updatedRecords.add(updatedMessage);

              _logger.i(
                '✅ Pin/unpin message processed successfully for message ${updatedMessage.messageId}',
              );
            } catch (e) {
              _logger.e('❌ Error processing individual record: $e');
              _logger.d('🔍 Problematic record data: $recordData');
            }
          }
        }

        if (updatedRecords.isNotEmpty) {
          // ✅ NOTIFY UI VIA MAIN CHATS STREAM (This is crucial!)
          _chatsStreamController.add(_chatsData);

          // ✅ ALSO NOTIFY VIA DEDICATED PIN/UNPIN STREAM
          final pinUnpinUpdate = ChatsModel(
            records: updatedRecords,
            pagination: _chatsData.pagination,
          );
          _pinUnpinStreamController.add(pinUnpinUpdate);

          _logger.d('📌 Notified both chats stream and pin/unpin stream');
        }

        // ✅ FORCE UI UPDATE
        notifyListeners();

        _logger.i('✅ All pin/unpin messages processed successfully');
      } catch (e, stackTrace) {
        _logger.e('❌ Error processing pin/unpin socket response: $e');
        _logger.e('📍 Stack trace: $stackTrace');

        // Log the raw data for debugging
        _logger.d('🔍 Raw response data: $data');

        // Set error for UI to handle
        _setError('Failed to process pin/unpin socket update: ${e.toString()}');
      }
    });
  }

  void _updateExistingMessagePinStatus(Records updatedMessage) {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      _logger.w('⚠️ No existing chat messages to update pin status');
      return;
    }

    bool messageFound = false;

    // Find and update the corresponding message in existing chat data
    for (int i = 0; i < _chatsData.records!.length; i++) {
      final existingMessage = _chatsData.records![i];

      if (existingMessage.messageId == updatedMessage.messageId) {
        // Create updated message with new pin status
        // ✅ CRITICAL FIX: Preserve ALL fields including story data
        final updatedRecord = Records(
          messageContent: existingMessage.messageContent,
          replyTo: existingMessage.replyTo,
          socialId: existingMessage.socialId,
          messageId: existingMessage.messageId,
          messageType: existingMessage.messageType,
          messageThumbnail: existingMessage.messageThumbnail, // ✅ PRESERVE
          messageLength: existingMessage.messageLength,
          messageSeenStatus: existingMessage.messageSeenStatus,
          messageSize: existingMessage.messageSize,
          deletedFor: existingMessage.deletedFor,
          starredFor: existingMessage.starredFor,
          deletedForEveryone: existingMessage.deletedForEveryone,
          pinned: updatedMessage.pinned, // ✅ UPDATE PIN STATUS
          stared: existingMessage.stared, // ✅ PRESERVE
          pinLifetime: updatedMessage.pinLifetime, // ✅ UPDATE PIN LIFETIME
          pinnedTill: updatedMessage.pinnedTill, // ✅ UPDATE PIN TILL
          createdAt: existingMessage.createdAt,
          updatedAt:
              updatedMessage.updatedAt ??
              existingMessage.updatedAt, // ✅ UPDATE TIMESTAMP
          chatId: existingMessage.chatId,
          senderId: existingMessage.senderId,
          storyId: existingMessage.storyId, // ✅ CRITICAL: PRESERVE STORY ID
          unseenCount: existingMessage.unseenCount, // ✅ PRESERVE
          parentMessage: existingMessage.parentMessage,
          replies: existingMessage.replies,
          user: existingMessage.user,
          story: existingMessage.story, // ✅ CRITICAL: PRESERVE STORY DATA
          actionedUser: existingMessage.actionedUser, // ✅ PRESERVE
          social: existingMessage.social, // ✅ PRESERVE
          peerUserData: existingMessage.peerUserData,
          isFollowing: existingMessage.isFollowing, // ✅ PRESERVE
          calls: existingMessage.calls, // ✅ PRESERVE
          chat: existingMessage.chat, // ✅ PRESERVE
        );

        // Replace the message in the list
        _chatsData.records![i] = updatedRecord;
        messageFound = true;

        _logger.d(
          '📌 Updated message ${existingMessage.messageId} pin status: ${existingMessage.pinned} -> ${updatedMessage.pinned}',
        );
        break; // Found and updated, exit loop
      }
    }

    if (!messageFound) {
      _logger.w(
        '⚠️ Message ${updatedMessage.messageId} not found in current chat data for pin status update',
      );
    }
  }

  /// Update pinned messages collection
  void _updatePinnedMessagesCollection(Records updatedMessage) {
    try {
      _pinnedMessagesData.records ??= [];

      if (updatedMessage.pinned == true) {
        // Message was pinned - add to pinned messages if not already there
        final existingIndex = _pinnedMessagesData.records!.indexWhere(
          (msg) => msg.messageId == updatedMessage.messageId,
        );

        if (existingIndex == -1) {
          // Add new pinned message at the beginning (newest first)
          _pinnedMessagesData.records!.insert(0, updatedMessage);
          _logger.d('📌 Added new pinned message: ${updatedMessage.messageId}');
        } else {
          // Update existing pinned message
          _pinnedMessagesData.records![existingIndex] = updatedMessage;
          _logger.d(
            '📌 Updated existing pinned message: ${updatedMessage.messageId}',
          );
        }
      } else {
        // Message was unpinned - remove from pinned messages
        final initialCount = _pinnedMessagesData.records!.length;
        _pinnedMessagesData.records!.removeWhere(
          (msg) => msg.messageId == updatedMessage.messageId,
        );
        final finalCount = _pinnedMessagesData.records!.length;

        if (initialCount > finalCount) {
          _logger.d('📌 Removed unpinned message: ${updatedMessage.messageId}');
        } else {
          _logger.w(
            '⚠️ Message ${updatedMessage.messageId} was not in pinned messages list',
          );
        }
      }

      // Update pagination info for pinned messages
      final pinnedCount = _pinnedMessagesData.records!.length;
      _pinnedMessagesData.pagination = Pagination(
        totalRecords: pinnedCount,
        currentPage: 1,
        totalPages: 1,
        recordsPerPage: pinnedCount,
      );

      _logger.d('📌 Pinned messages collection updated. Total: $pinnedCount');
    } catch (e) {
      _logger.e('❌ Error updating pinned messages collection: $e');
    }
  }

  // ✅ NEW: Add pinned messages data storage
  ChatsModel _pinnedMessagesData = ChatsModel();
  ChatsModel get pinnedMessagesData => _pinnedMessagesData;

  void _setupMessageListListener() {
    _socketService.on(_socketEvents.messageList, (data) {
      _logger.d('📨 Received message list response');
      _logger.d('Received message list response : $data');
      try {
        // ✅ PARSE RESPONSE DATA
        final parsedData = _parseMessageListResponse(data);
        if (parsedData == null) {
          throw Exception('Failed to parse message list response');
        }

        final ChatsModel newChatsData = parsedData['messages'];
        final ChatsModel? pinnedData = parsedData['pinned'];

        // ✅ UPDATE PINNED MESSAGES IF AVAILABLE
        if (pinnedData != null) {
          _pinnedMessagesData = pinnedData;
          _logger.d(
            '📌 Updated ${pinnedData.records?.length ?? 0} pinned messages',
          );
        }

        // ✅ PROCESS MAIN MESSAGES
        _processMessageListResponse(newChatsData);

        // ✅ UPDATE STREAM
        _chatsStreamController.add(_chatsData);

        // ✅ HANDLE LOADING STATES
        _handleResponseLoadingStates(newChatsData);

        // ✅ FORCE UI UPDATE
        notifyListeners();
      } catch (e, stackTrace) {
        _logger.e('❌ Message list parsing error: $e');
        _logger.e('📍 Stack trace: $stackTrace');

        _setError('Error parsing message list: ${e.toString()}');
        _resetAllLoadingStates();
      }
    });
  }

  void _setupStarUnstarMessageListener() {
    _socketService.on(_socketEvents.starUnstarMessage, (data) {
      _logger.d('⭐ Received star/unstar message response from socket: $data');

      try {
        // Handle both direct Records array and wrapped response formats
        List<dynamic> recordsList = [];

        if (data is Map<String, dynamic>) {
          // Check for Records key (uppercase)
          if (data.containsKey('Records') && data['Records'] is List) {
            recordsList = data['Records'] as List<dynamic>;
          }
          // Check for records key (lowercase)
          else if (data.containsKey('records') && data['records'] is List) {
            recordsList = data['records'] as List<dynamic>;
          }
          // If the data itself looks like a ChatsModel structure
          else {
            try {
              final ChatsModel parsedData = ChatsModel.fromJson(data);
              recordsList =
                  parsedData.records?.map((r) => r.toJson()).toList() ?? [];
            } catch (e) {
              _logger.w('⚠️ Could not parse as ChatsModel: $e');
            }
          }
        }
        // Handle direct array response
        else if (data is List) {
          recordsList = data;
        }

        if (recordsList.isEmpty) {
          _logger.w('⚠️ No records found in star/unstar socket response');
          return;
        }

        // ✅ CREATE UPDATED RECORDS LIST
        List<Records> updatedRecords = [];

        // Process each record in the response
        for (var recordData in recordsList) {
          if (recordData is Map<String, dynamic>) {
            try {
              // Create Records object from the map
              final Records updatedMessage = Records.fromJson(recordData);

              // ✅ Determine the star status from the response
              // The response contains "starred_for" array and "starred" boolean
              bool isStarred = false;

              // Check starred_for array
              if (recordData['starred_for'] is List) {
                final starredForList = recordData['starred_for'] as List;
                isStarred = starredForList.isNotEmpty;
              }

              // Also check the "starred" boolean field if it exists
              if (recordData.containsKey('starred')) {
                isStarred = recordData['starred'] == true;
              }

              _logger.d(
                '⭐ Processing star status change for message ${updatedMessage.messageId}: starred=$isStarred',
              );

              // ✅ UPDATE EXISTING MESSAGES IN CHAT DATA
              _updateExistingMessageStarStatus(updatedMessage, isStarred);

              // ✅ UPDATE STARRED MESSAGES COLLECTION
              _updateStarredMessagesCollection(updatedMessage, isStarred);

              // ✅ ADD TO UPDATED RECORDS LIST
              updatedRecords.add(updatedMessage);

              _logger.i(
                '✅ Star/unstar message processed successfully for message ${updatedMessage.messageId}',
              );
            } catch (e) {
              _logger.e('❌ Error processing individual record: $e');
              _logger.d('🔍 Problematic record data: $recordData');
            }
          }
        }

        if (updatedRecords.isNotEmpty) {
          // ✅ NOTIFY UI VIA MAIN CHATS STREAM (This is crucial!)
          _chatsStreamController.add(_chatsData);

          // ✅ ALSO NOTIFY VIA DEDICATED STAR/UNSTAR STREAM (if you want to create one)
          // You can create a separate stream for star/unstar updates if needed

          _logger.d('⭐ Notified chats stream about star/unstar changes');
        }

        // ✅ FORCE UI UPDATE
        notifyListeners();

        _logger.i('✅ All star/unstar messages processed successfully');
      } catch (e, stackTrace) {
        _logger.e('❌ Error processing star/unstar socket response: $e');
        _logger.e('📍 Stack trace: $stackTrace');

        // Log the raw data for debugging
        _logger.d('🔍 Raw response data: $data');

        // Set error for UI to handle
        _setError(
          'Failed to process star/unstar socket update: ${e.toString()}',
        );
      }
    });
  }

  // ✅ NEW: Update existing message star status in chat data
  void _updateExistingMessageStarStatus(
    Records updatedMessage,
    bool isStarred,
  ) {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      _logger.w('⚠️ No existing chat messages to update star status');
      return;
    }

    bool messageFound = false;

    // Find and update the corresponding message in existing chat data
    for (int i = 0; i < _chatsData.records!.length; i++) {
      final existingMessage = _chatsData.records![i];

      if (existingMessage.messageId == updatedMessage.messageId) {
        // Create updated message with new star status
        // ✅ CRITICAL FIX: Preserve ALL fields including story data
        final updatedRecord = Records(
          messageContent: existingMessage.messageContent,
          replyTo: existingMessage.replyTo,
          socialId: existingMessage.socialId,
          messageId: existingMessage.messageId,
          messageType: existingMessage.messageType,
          messageThumbnail: existingMessage.messageThumbnail, // ✅ PRESERVE
          messageLength: existingMessage.messageLength,
          messageSeenStatus: existingMessage.messageSeenStatus,
          messageSize: existingMessage.messageSize,
          deletedFor: existingMessage.deletedFor,
          starredFor: updatedMessage.starredFor, // ✅ UPDATE STARRED FOR
          deletedForEveryone: existingMessage.deletedForEveryone,
          pinned: existingMessage.pinned,
          stared: isStarred, // ✅ UPDATE STAR STATUS
          pinLifetime: existingMessage.pinLifetime,
          pinnedTill: existingMessage.pinnedTill,
          createdAt: existingMessage.createdAt,
          updatedAt: updatedMessage.updatedAt ?? existingMessage.updatedAt,
          chatId: existingMessage.chatId,
          senderId: existingMessage.senderId,
          storyId: existingMessage.storyId, // ✅ CRITICAL: PRESERVE STORY ID
          unseenCount: existingMessage.unseenCount, // ✅ PRESERVE
          parentMessage: existingMessage.parentMessage,
          replies: existingMessage.replies,
          user: existingMessage.user,
          story: existingMessage.story, // ✅ CRITICAL: PRESERVE STORY DATA
          actionedUser: existingMessage.actionedUser, // ✅ PRESERVE
          social: existingMessage.social, // ✅ PRESERVE
          peerUserData: existingMessage.peerUserData,
          isFollowing: existingMessage.isFollowing, // ✅ PRESERVE
          calls: existingMessage.calls, // ✅ PRESERVE
          chat: existingMessage.chat, // ✅ PRESERVE
        );

        // Replace the message in the list
        _chatsData.records![i] = updatedRecord;
        messageFound = true;

        _logger.d(
          '⭐ Updated message ${existingMessage.messageId} star status: ${existingMessage.stared} -> $isStarred',
        );
        break; // Found and updated, exit loop
      }
    }

    if (!messageFound) {
      _logger.w(
        '⚠️ Message ${updatedMessage.messageId} not found in current chat data for star status update',
      );
    }
  }

  // ✅ NEW: Update starred messages collection (if you maintain one)
  void _updateStarredMessagesCollection(
    Records updatedMessage,
    bool isStarred,
  ) {
    try {
      // Initialize starred messages data if not already done
      _starredMessagesData.records ??= [];

      if (isStarred) {
        // Message was starred - add to starred messages if not already there
        final existingIndex = _starredMessagesData.records!.indexWhere(
          (msg) => msg.messageId == updatedMessage.messageId,
        );

        if (existingIndex == -1) {
          // Add new starred message at the beginning (newest first)
          _starredMessagesData.records!.insert(0, updatedMessage);
          _logger.d('⭐ Added new starred message: ${updatedMessage.messageId}');
        } else {
          // Update existing starred message
          _starredMessagesData.records![existingIndex] = updatedMessage;
          _logger.d(
            '⭐ Updated existing starred message: ${updatedMessage.messageId}',
          );
        }
      } else {
        // Message was unstarred - remove from starred messages
        final initialCount = _starredMessagesData.records!.length;
        _starredMessagesData.records!.removeWhere(
          (msg) => msg.messageId == updatedMessage.messageId,
        );
        final finalCount = _starredMessagesData.records!.length;

        if (initialCount > finalCount) {
          _logger.d('⭐ Removed unstarred message: ${updatedMessage.messageId}');
        } else {
          _logger.w(
            '⚠️ Message ${updatedMessage.messageId} was not in starred messages list',
          );
        }
      }

      // Update pagination info for starred messages
      final starredCount = _starredMessagesData.records!.length;
      _starredMessagesData.pagination = Pagination(
        totalRecords: starredCount,
        currentPage: 1,
        totalPages: 1,
        recordsPerPage: starredCount,
      );

      _logger.d('⭐ Starred messages collection updated. Total: $starredCount');
    } catch (e) {
      _logger.e('❌ Error updating starred messages collection: $e');
    }
  }

  /// Handles both wrapped and direct response formats
  /// ✅ FIXED: Handles both wrapped and direct response formats
  Map<String, dynamic>? _parseMessageListResponse(dynamic data) {
    try {
      ChatsModel? messagesData;
      ChatsModel? pinnedData;

      _logger.d('🔍 Parsing response type: ${data.runtimeType}');

      if (data is Map<String, dynamic>) {
        _logger.d('📋 Response keys: ${data.keys.toList()}');

        // ✅ HANDLE PINNED MESSAGES FIRST (Critical for initial load)
        if (data.containsKey('pinned_messages') &&
            data['pinned_messages'] is Map<String, dynamic>) {
          _logger.d('📌 Found pinned_messages in response');
          final pinnedMap = data['pinned_messages'] as Map<String, dynamic>;

          // Check if pinned_messages has actual records
          final pinnedRecords = pinnedMap['Records'] ?? pinnedMap['records'];
          if (pinnedRecords is List && pinnedRecords.isNotEmpty) {
            try {
              pinnedData = ChatsModel.fromJson(pinnedMap);
              _logger.d('📌 Parsed ${pinnedRecords.length} pinned messages');
            } catch (e) {
              _logger.w('⚠️ Failed to parse pinned messages: $e');
            }
          } else {
            _logger.d('📌 No pinned records found');
          }
        }

        // ✅ HANDLE MAIN MESSAGE LIST
        if (data.containsKey('message_list') &&
            data['message_list'] is Map<String, dynamic>) {
          _logger.d('📨 Found wrapped message_list');
          messagesData = ChatsModel.fromJson(data['message_list']);
        } else if (data.containsKey('Records') || data.containsKey('records')) {
          _logger.d('📨 Found direct Records format');
          messagesData = ChatsModel.fromJson(data);
        } else {
          // ✅ FALLBACK: Try to parse as direct ChatsModel
          _logger.d('📨 Attempting direct parsing');
          try {
            messagesData = ChatsModel.fromJson(data);
          } catch (e) {
            _logger.w('⚠️ Direct parsing failed: $e');
          }
        }
      } else if (data is List && data.isNotEmpty) {
        // ✅ HANDLE ARRAY RESPONSE FORMAT
        _logger.d('📨 Handling array response with ${data.length} items');

        for (var item in data) {
          if (item is Map<String, dynamic>) {
            // Check for pinned messages in array items
            if (item.containsKey('pinned_messages')) {
              final pinnedMap = item['pinned_messages'] as Map<String, dynamic>;
              try {
                pinnedData = ChatsModel.fromJson(pinnedMap);
                _logger.d('📌 Found pinned messages in array item');
              } catch (e) {
                _logger.w('⚠️ Failed to parse pinned from array: $e');
              }
            }

            // Check for main messages
            final parsed = _extractValidMessageData(item);
            if (parsed != null && messagesData == null) {
              try {
                messagesData = ChatsModel.fromJson(parsed);
                break;
              } catch (e) {
                _logger.w('⚠️ Failed to parse array item: $e');
                continue;
              }
            }
          }
        }
      }

      // ✅ VALIDATE THAT WE HAVE VALID MESSAGE DATA
      if (messagesData == null || !_isValidChatsModel(messagesData)) {
        throw Exception('No valid message data found in response');
      }

      // ✅ VALIDATE PARSED DATA
      final recordCount = messagesData.records?.length ?? 0;
      final pinnedCount = pinnedData?.records?.length ?? 0;

      _logger.d(
        '✅ Parsing successful - Messages: $recordCount, Pinned: $pinnedCount',
      );

      return {'messages': messagesData, 'pinned': pinnedData};
    } catch (e, stackTrace) {
      _logger.e('❌ Response parsing error: $e');
      _logger.e('📍 Stack trace: $stackTrace');
      _logProblematicResponseData(data);
      return null;
    }
  }

  Map<String, dynamic>? _extractValidMessageData(Map<String, dynamic> item) {
    // Check for message_list first
    if (item.containsKey('message_list') &&
        item['message_list'] is Map<String, dynamic>) {
      final messageList = item['message_list'] as Map<String, dynamic>;
      if (_hasValidRecords(messageList)) {
        return messageList;
      }
    }

    // Check for direct Records
    if (_hasValidRecords(item)) {
      return item;
    }

    // Check for pinned_messages as fallback
    if (item.containsKey('pinned_messages') &&
        item['pinned_messages'] is Map<String, dynamic>) {
      final pinnedMessages = item['pinned_messages'] as Map<String, dynamic>;
      if (_hasValidRecords(pinnedMessages)) {
        return pinnedMessages;
      }
    }

    return null;
  }

  /// Check if a map has valid records
  bool _hasValidRecords(Map<String, dynamic> data) {
    final records = data['Records'] ?? data['records'];
    return records is List;
  }

  /// Validate if ChatsModel has valid structure
  bool _isValidChatsModel(ChatsModel? model) {
    return model != null && (model.records != null || model.pagination != null);
  }

  /// Log problematic response data for debugging
  void _logProblematicResponseData(dynamic data) {
    try {
      final dataStr = data.toString();
      final debugStr =
          dataStr.length > 1000
              ? '${dataStr.substring(0, 1000)}...[truncated]'
              : dataStr;

      _logger.d('🔍 Problematic response data:');
      _logger.d(debugStr);

      // Also log the structure
      if (data is Map<String, dynamic>) {
        _logger.d('📋 Response structure:');
        data.forEach((key, value) {
          final valueType = value.runtimeType.toString();
          final valueInfo =
              value is List
                  ? '$valueType[${value.length}]'
                  : value is Map
                  ? '$valueType{${value.keys.length} keys}'
                  : valueType;
          _logger.d('  $key: $valueInfo');
        });
      }
    } catch (e) {
      _logger.d('🔍 Could not serialize problematic data: $e');
    }
  }

  /// Merge new server data with existing cached data intelligently
  void _mergeWithExistingData(ChatsModel serverData) {
    final existingRecords = _chatsData.records ?? [];
    final newRecords = serverData.records ?? [];

    if (newRecords.isEmpty) return;

    // Create a map of existing messages by ID for quick lookup
    final Map<int, Records> existingMessagesMap = {};
    for (var record in existingRecords) {
      if (record.messageId != null) {
        existingMessagesMap[record.messageId!] = record;
      }
    }

    // Merge logic: update existing messages and add new ones
    final List<Records> mergedRecords = List.from(newRecords);

    // Add any cached messages that aren't in server response (e.g., very recent cached messages)
    for (var cachedRecord in existingRecords) {
      if (cachedRecord.messageId != null &&
          !newRecords.any(
            (newRecord) => newRecord.messageId == cachedRecord.messageId,
          )) {
        mergedRecords.add(cachedRecord);
      }
    }

    // Sort by creation date (most recent first, as expected by UI)
    mergedRecords.sort((a, b) {
      final aTime = DateTime.tryParse(a.createdAt ?? '');
      final bTime = DateTime.tryParse(b.createdAt ?? '');
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    // Create merged chat model
    _chatsData = ChatsModel(
      records: mergedRecords,
      pagination: serverData.pagination,
    );

    _logger.d('✅ Merged data: ${mergedRecords.length} total messages');
  }

  /// Process message list response and update internal state
  void _processMessageListResponse(ChatsModel newChatsData) {
    final pagination = newChatsData.pagination;
    final currentPage = pagination?.currentPage ?? 1;
    final totalPages = pagination?.totalPages ?? 1;
    final totalRecords = pagination?.totalRecords ?? 0;
    final newRecords = newChatsData.records ?? [];

    _logger.d(
      '📊 Processing response - '
      'Page: $currentPage/$totalPages, '
      'Records: ${newRecords.length}, '
      'Total: $totalRecords',
    );

    if (currentPage == 1) {
      // ✅ FIRST PAGE: Check cache protection and existing data
      final existingMessageCount = _chatsData.records?.length ?? 0;
      final newMessageCount = newRecords.length;

      if (_cacheDataProtected && existingMessageCount > 0) {
        // Cache protection is enabled - always merge or preserve
        if (newMessageCount == 0) {
          _logger.d(
            '🛡️ CACHE PROTECTION: Server returned empty data but we have $existingMessageCount protected cached messages - keeping cached data',
          );
        } else {
          _logger.d(
            '🛡️ CACHE PROTECTION: Merging $existingMessageCount cached with $newMessageCount server messages',
          );
          _mergeWithExistingData(newChatsData);
        }
        // ✅ Keep cache protection for first load, disable for subsequent loads
        if (_chatsPageNo > 1) {
          _cacheDataProtected = false;
          _logger.d('🔓 Cache protection reset for pagination load');
        } else {
          _logger.d('🛡️ Keeping cache protection active for first load');
        }
      } else if (existingMessageCount > 0 && newMessageCount == 0) {
        // Server returned empty but we have cached data - keep cached data
        _logger.d(
          '🎯 CACHE PRESERVATION: Server returned empty data but we have $existingMessageCount cached messages - keeping cached data',
        );
      } else if (existingMessageCount > 0 && newMessageCount > 0) {
        // We have both cached and server data - merge them intelligently
        _logger.d(
          '🔄 SMART MERGE: Merging $existingMessageCount cached with $newMessageCount server messages',
        );
        _mergeWithExistingData(newChatsData);
      } else {
        // No cached data or server has more recent data - replace
        _logger.d(
          '📄 FULL REPLACE: First page loaded with ${newRecords.length} messages (no cached data to preserve)',
        );
        _chatsData = newChatsData;
      }

      // Reset pagination tracking
      _chatsPageNo = currentPage;
    } else {
      // ✅ PAGINATION: Append new messages
      _appendPaginatedMessages(newChatsData);

      // Update pagination tracking
      _chatsPageNo = currentPage;
    }

    // ✅ UPDATE PAGINATION STATUS
    _hasMoreMessages = currentPage < totalPages;

    // ✅ HANDLE EDGE CASE: Empty response but more pages expected
    if (_hasMoreMessages && newRecords.isEmpty && currentPage > 1) {
      _logger.w('⚠️ Empty pagination response, assuming no more data');
      _hasMoreMessages = false;
    }

    _logger.d(
      '📈 Updated pagination status - '
      'HasMore: $_hasMoreMessages, '
      'CurrentPage: $_chatsPageNo, '
      'TotalMessages: ${_chatsData.records?.length ?? 0}',
    );
  }

  /// Append paginated messages to existing data
  void _appendPaginatedMessages(ChatsModel newChatsData) {
    final newRecords = newChatsData.records ?? [];

    if (newRecords.isEmpty) {
      _logger.w('⚠️ No new records in pagination response');
      return;
    }

    // ✅ ENSURE EXISTING RECORDS LIST EXISTS
    _chatsData.records ??= [];

    // ✅ PREVENT DUPLICATES: Filter out messages that already exist
    final existingMessageIds =
        _chatsData.records!
            .map((r) => r.messageId)
            .where((id) => id != null)
            .toSet();

    final uniqueNewRecords =
        newRecords
            .where((record) => !existingMessageIds.contains(record.messageId))
            .toList();

    if (uniqueNewRecords.isNotEmpty) {
      // ✅ APPEND OLDER MESSAGES TO END (they should appear at top with reverse ListView)
      // Reverse the order to ensure oldest messages go first (highest indices)
      _chatsData.records!.addAll(uniqueNewRecords.reversed);

      // ✅ UPDATE PAGINATION METADATA
      _chatsData.pagination = newChatsData.pagination;

      _logger.d(
        '📑 Appended ${uniqueNewRecords.length} unique messages. '
        'Total: ${_chatsData.records!.length}',
      );
    } else {
      _logger.w(
        '⚠️ All ${newRecords.length} paginated messages were duplicates',
      );

      // Still update pagination metadata even if no new unique records
      _chatsData.pagination = newChatsData.pagination;
    }
  }

  /// Handle loading states after receiving response
  void _handleResponseLoadingStates(ChatsModel newChatsData) {
    final pagination = newChatsData.pagination;
    final currentPage = pagination?.currentPage ?? 1;
    final isFirstPage = currentPage == 1;

    _logger.d('🔄 Handling loading states for page $currentPage');

    if (isFirstPage) {
      // ✅ FIRST PAGE: Reset initial/refresh loading states
      if (_isRefreshing) {
        _logger.d('✅ Refresh completed successfully');
        _setRefreshing(false);
      }

      if (_isChatLoading) {
        _logger.d('✅ Initial chat loading completed');
        _setIsChatLoading(false);
      }
    } else {
      // ✅ PAGINATION: Reset pagination loading state
      if (_isPaginationLoading) {
        _logger.d('✅ Pagination loading completed');
        _setPaginationLoading(false);
      }
    }

    // ✅ ALWAYS ENSURE UI UPDATES
    notifyListeners();

    // // ✅ SCHEDULE ADDITIONAL UI UPDATE (ensures loaders disappear)
    // Future.delayed(Duration(milliseconds: 50), () {
    //   if (!_isDisposed) {
    //     notifyListeners();
    //   }
    // });
  }

  /// Reset all loading states (used on error or dispose)
  void _resetAllLoadingStates() {
    _logger.d('🔄 Resetting all loading states');

    // ✅ RESET ALL LOADING FLAGS
    _setIsChatLoading(false);
    _setPaginationLoading(false);
    _setRefreshing(false);

    // ✅ RESET CHAT LIST LOADING
    _isChatListLoading = false;

    // ✅ FORCE IMMEDIATE UI UPDATE
    notifyListeners();

    _logger.d('✅ All loading states reset');
  }

  /// Setup online users event listeners
  void _setupOnlineUsersListeners() {
    // Initial online users
    _socketService.on(_socketEvents.initialOnlineUser, (data) {
      _logger.d('Received initial online users: $data');
      try {
        _onlineUsersData = OnlineUsersModel.fromJson(data);
        _onlineUsersStreamController.add(_onlineUsersData);
        notifyListeners();
      } catch (e) {
        _setError('Error parsing initial online users: ${e.toString()}');
      }
    });

    // User comes online
    _socketService.on(_socketEvents.onlineUser, (data) {
      _logger.d('User came online: $data');
      try {
        final onlineUser = OnlineUsers.fromJson(data);
        _updateUserOnlineStatus(onlineUser, true);
        _onlineUsersStreamController.add(_onlineUsersData);
        notifyListeners();
      } catch (e) {
        _setError('Error handling user online: ${e.toString()}');
      }
    });

    // User goes offline
    _socketService.on(_socketEvents.offlineUser, (data) {
      _logger.d('User went offline: $data');
      try {
        final offlineUser = OnlineUsers.fromJson(data);
        _updateUserOnlineStatus(offlineUser, false);
        _onlineUsersStreamController.add(_onlineUsersData);
        notifyListeners();
      } catch (e) {
        _setError('Error handling user offline: ${e.toString()}');
      }
    });
  }

  /// Update user online status in the list
  void _updateUserOnlineStatus(OnlineUsers user, bool isOnline) {
    _onlineUsersData.onlineUsers ??= [];

    final existingUserIndex = _onlineUsersData.onlineUsers!.indexWhere(
      (existingUser) => existingUser.userId == user.userId,
    );

    if (existingUserIndex != -1) {
      // Update existing user
      _onlineUsersData.onlineUsers![existingUserIndex].isOnline = isOnline;
      _onlineUsersData.onlineUsers![existingUserIndex].updatedAt =
          user.updatedAt;
    } else if (isOnline) {
      // Add new online user
      _onlineUsersData.onlineUsers!.add(user);
    }
  }

  /// Setup typing event listener
  void _setupTypingListener() {
    _socketService.on(_socketEvents.typing, (data) {
      _logger.d('Received typing event: $data');
      try {
        _typingData = TypingModel.fromJson(data);
        _typingStreamController.add(_typingData);
        notifyListeners();
      } catch (e) {
        _setError('Error parsing typing event: ${e.toString()}');
      }
    });
  }

  /// Setup block updates event listener
  void _setupBlockUpdatesListener() {
    _socketService.on(_socketEvents.blockUpdates, (data) {
      _logger.d('Received block updates event: $data');
      try {
        _blockUpdatesData = BlockUpdatesModel.fromJson(data);
        _blockUpdatesStreamController.add(_blockUpdatesData);
        _logger.i(
          'Block update processed: userId=${_blockUpdatesData.userId}, chatId=${_blockUpdatesData.chatId}, isBlocked=${_blockUpdatesData.isBlocked}',
        );
        notifyListeners();
      } catch (e) {
        _setError('Error parsing block updates event: ${e.toString()}');
        _logger.e('Error parsing block updates event: $e');
      }
    });
  }

  /// Setup new message event listener

  // void _setupNewMessageListener() {
  //   _socketService.on(_socketEvents.recieve, (data) {
  //     _logger.d('Received new message: $data');

  //     try {
  //       final socketResponse = ChatsModel.fromJson(data);

  //       if (socketResponse.records?.isEmpty ?? true) {
  //         _logger.e('No records found in socket response');
  //         return;
  //       }

  //       final newMessage = socketResponse.records!.first;

  //       // Check for duplicate messages
  //       if (_isDuplicateMessage(newMessage.messageId)) {
  //         return;
  //       }

  //       _logger.d(
  //         'Processing new message - Chat ID: ${newMessage.chatId}, Sender ID: ${newMessage.senderId}',
  //       );

  //       // Update chat list with new message
  //       _updateChatListWithNewMessage(newMessage);

  //       // Handle current chat updates
  //       _handleNewMessageForCurrentChat(newMessage);

  //       // ✅ NEW: Auto-mark message as seen if user is currently viewing this chat
  //       _autoMarkMessageAsSeenIfActive(newMessage);

  //       // Notify listeners
  //       _chatListStreamController.add(_chatListData);
  //       notifyListeners();
  //     } catch (e, stackTrace) {
  //       _setError('Error handling new message: ${e.toString()}');
  //       _logger.e('Stack trace: $stackTrace');
  //     }
  //   });
  // }
  void _setupNewMessageListener() {
    _socketService.on(_socketEvents.receive, (data) {
      _logger.d('📨 Received new message via socket');

      try {
        final socketResponse = ChatsModel.fromJson(data);

        if (socketResponse.records?.isEmpty ?? true) {
          _logger.e('No records found in socket response');
          return;
        }

        final newMessage = socketResponse.records!.first;

        // Check for duplicate messages
        if (_isDuplicateMessage(newMessage.messageId)) {
          return;
        }

        // ✅ CRITICAL DEBUG: Log actionedUser from socket payload
        _logger.d('=== Socket Message Debug ===');
        _logger.d('Chat ID: ${newMessage.chatId}');
        _logger.d('Message Type: ${newMessage.messageType}');
        _logger.d('Sender ID: ${newMessage.senderId}');
        _logger.d(
          'ActionedUser from socket: ${newMessage.actionedUser?.userId ?? "NULL"}',
        );
        _logger.d(
          'ActionedUser name: ${newMessage.actionedUser?.fullName ?? "NULL"}',
        );
        _logger.d('===========================');

        // ✅ SIMPLE FIX: Use mutex lock
        _processChatListUpdateWithLock(newMessage);

        // Handle current chat updates (this doesn't conflict)
        _handleNewMessageForCurrentChat(newMessage);

        // Auto-mark message as seen if user is actively viewing this chat
        _autoMarkMessageAsSeenIfActive(newMessage);
      } catch (e, stackTrace) {
        _setError('Error handling new message: ${e.toString()}');
        _logger.e('Stack trace: $stackTrace');
      }
    });
  }

  // ✅ NEW: Process with mutex lock
  void _processChatListUpdateWithLock(Records newMessage) {
    if (_isUpdatingChatList) {
      // If already updating, add to pending and process later
      _pendingMessages.add(newMessage);
      _logger.d(
        '📝 Chat list busy, added message ${newMessage.messageId} to pending queue',
      );
      return;
    }

    // Process immediately
    _processMessageUpdate(newMessage);
  }

  Future<void> _processMessageUpdate(Records newMessage) async {
    _isUpdatingChatList = true;

    try {
      _logger.d(
        '🔒 Acquired chat list lock for message ${newMessage.messageId}',
      );

      // Update chat list with new message
      await _updateChatListWithNewMessage(newMessage);

      // Notify listeners
      _chatListStreamController.add(_chatListData);
      notifyListeners();

      _logger.d('✅ Updated chat list for message ${newMessage.messageId}');
    } catch (e) {
      _logger.e('❌ Error updating chat list: $e');
    } finally {
      _isUpdatingChatList = false;
      _logger.d('🔓 Released chat list lock');

      // Process any pending messages
      if (_pendingMessages.isNotEmpty) {
        final nextMessage = _pendingMessages.removeAt(0);
        _logger.d('📤 Processing pending message ${nextMessage.messageId}');

        // Small delay to prevent overwhelming
        Future.delayed(Duration(milliseconds: 100), () {
          _processMessageUpdate(nextMessage);
        });
      }
    }
  }

  /// Auto-mark message as seen if user is actively viewing the chat
  /// Fixed auto-mark message as seen method in SocketEventController
  void _autoMarkMessageAsSeenIfActive(Records newMessage) async {
    try {
      // ✅ ENHANCED: Better timing check
      if (_isPendingFocusChange) {
        _logger.d('⏭️ Skipping auto-mark - focus change is pending');
        return;
      }

      // Get current user ID
      final currentUserId = await _getCurrentUserIdAsync();
      if (currentUserId == null) {
        _logger.w('Cannot auto-mark message - current user ID not available');
        return;
      }

      // Skip if message is from current user
      if (newMessage.senderId == currentUserId) {
        _logger.d('⏭️ Skipping auto-mark - message is from current user');
        return;
      }

      // ✅ SIMPLIFIED: Check if user is actively viewing the chat where message arrived
      final isViewingThisChat =
          _isAppInForeground &&
          _isChatScreenActive &&
          _currentChatId != null &&
          _currentChatId == newMessage.chatId &&
          !_isPendingFocusChange;

      if (isViewingThisChat && newMessage.messageId != null) {
        _logger.d(
          '👁️ AUTO-MARKING message as seen (actively viewing this chat)',
        );

        // ✅ IMMEDIATE: Mark as seen right away
        emitMessageSeen(newMessage.chatId!, newMessage.messageId!);
        _logger.d('✅ Message seen event emitted immediately');
      } else {
        _logger.d(
          '⏭️ NOT auto-marking message - user not actively viewing this chat',
        );
      }
    } catch (e) {
      _logger.e('Error in auto-mark message as seen: $e');
    }
  }

  void forceClearChatFocus() {
    _logger.d('🧹 Force clearing chat focus');
    _isChatScreenActive = false;
    _activeChatScreenId = null;
    _isPendingFocusChange = false;
    notifyListeners();
  }

  /// Handle new message for current active chat
  void _handleNewMessageForCurrentChat(Records newMessage) {
    if (_currentChatId != null && newMessage.chatId == _currentChatId) {
      // Message belongs to current active chat
      _addMessageToCurrentChat(newMessage);
      _setPaginationLoading(false);

      // ✅ FIX: When messages arrive via socket, stop the loading indicator
      if (_isChatLoading) {
        _logger.d(
          '💾 Socket message received - stopping chat loading indicator',
        );
        _setIsChatLoading(false);
      }
    } else if (_currentChatId == 0 && newMessage.chatId != null) {
      // New chat scenario - update current chat ID
      _logger.d('New chat created with ID: ${newMessage.chatId}');
      updateCurrentChatId(newMessage.chatId!);
      _addMessageToCurrentChat(newMessage);
      _setPaginationLoading(false);

      // ✅ FIX: When messages arrive via socket, stop the loading indicator
      if (_isChatLoading) {
        _logger.d(
          '💾 Socket message received - stopping chat loading indicator',
        );
        _setIsChatLoading(false);
      }
    }
  }

  /// Add message to current chat if not duplicate
  void _addMessageToCurrentChat(Records newMessage) {
    final bool messageExists =
        _chatsData.records?.any(
          (record) => record.messageId == newMessage.messageId,
        ) ??
        false;

    if (!messageExists) {
      _chatsData.records ??= [];
      _chatsData.records!.add(
        newMessage,
      ); // Add to end (bottom) for newest-to-oldest display

      _logger.d(
        '✅ REAL-TIME: Added new message to current chat. Total messages: ${_chatsData.records!.length}',
      );
      _logger.d(
        '📨 MESSAGE DETAILS: ID=${newMessage.messageId}, Content="${newMessage.messageContent}", From=${newMessage.senderId}, Chat=${newMessage.chatId}',
      );

      // ✅ CRITICAL DEBUG: Log actionedUser when adding to current chat
      if (newMessage.messageType == 'member-left' ||
          newMessage.messageType == 'member-removed' ||
          newMessage.messageType == 'member-added') {
        _logger.d('🔍 MEMBER ACTION MESSAGE:');
        _logger.d('  Type: ${newMessage.messageType}');
        _logger.d(
          '  ActionedUser: ${newMessage.actionedUser?.userId ?? "NULL"}',
        );
        _logger.d(
          '  ActionedUser Name: ${newMessage.actionedUser?.fullName ?? "NULL"}',
        );
        _logger.d('  Sender: ${newMessage.senderId}');
      }

      // 🗄️ CRITICAL FIX: Update cache with the new message
      _addMessageToCache(newMessage);

      // 🔔 NOTIFICATION: Emit new message for UI notification (real-time only)
      _newMessageStreamController.add(newMessage);

      _chatsStreamController.add(_chatsData);
    } else {
      _logger.d('Message already exists in current chat, skipping duplicate');
    }
  }

  /// Add new message to cache
  void _addMessageToCache(Records newMessage) {
    try {
      // Determine chat ID for cache key
      String? chatIdString;
      if (_currentChatId != null && _currentChatId! > 0) {
        chatIdString = _currentChatId.toString();
      } else if (_currentUserId != null && _currentUserId! > 0) {
        chatIdString = 'user_$_currentUserId';
      }

      if (chatIdString != null) {
        _logger.d(
          '🗄️ CACHE: Adding new message to cache for chat $chatIdString',
        );
        // Run cache update asynchronously to avoid blocking UI
        ChatCacheManager.addMessage(chatIdString, newMessage).catchError((
          error,
        ) {
          _logger.e('❌ CACHE: Failed to add message to cache: $error');
        });
      } else {
        _logger.w('⚠️ CACHE: Cannot determine chat ID for caching new message');
      }
    } catch (e) {
      _logger.e('❌ CACHE: Error adding message to cache: $e');
    }
  }

  /// Setup message seen event listener
  void _setupMessageSeenListeners() {
    // Real-time message seen (when someone sees your message)
    _socketService.on(_socketEvents.realTimeMessageSeen, (data) async {
      _logger.d('📩 Received real-time message seen: $data');

      // Validate acknowledgment
      _validateMessageSeenAcknowledgment(data);

      try {
        await _handleMessageSeenUpdate(data);
      } catch (e) {
        _logger.e('❌ Error handling real-time message seen: $e');
      }
    });

    // Message seen status (batch/historical updates)
    _socketService.on(_socketEvents.messageSeenStatus, (data) async {
      _logger.d('📩 Received message seen status: $data');

      try {
        await _handleMessageSeenUpdate(data);
      } catch (e) {
        _logger.e('❌ Error handling message seen status: $e');
      }
    });
  }

  /// Validate acknowledgment of emitted message seen events
  void _validateMessageSeenAcknowledgment(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        final messageId = data['message_id']?.toString();
        final chatId = data['chat_id']?.toString();
        final userId = data['user_id']?.toString();
        final currentUserId = userId.toString();

        if (messageId != null && chatId != null) {
          _logger.d('🔍 ACKNOWLEDGMENT VALIDATION:');
          _logger.d('  - Message ID: $messageId');
          _logger.d('  - Chat ID: $chatId');
          _logger.d('  - User ID: $userId');
          _logger.d('  - Current User ID: $currentUserId');

          // Track acknowledgment if this is from our emission
          if (userId == currentUserId) {
            final messageIdInt = int.tryParse(messageId);
            if (messageIdInt != null && _seenMessages.contains(messageIdInt)) {
              _logger.d(
                '✅ ACKNOWLEDGMENT CONFIRMED: Message $messageId was successfully acknowledged',
              );
              _emissionStats['acknowledged'] =
                  (_emissionStats['acknowledged'] ?? 0) + 1;
            } else {
              _logger.w(
                '⚠️ UNEXPECTED ACKNOWLEDGMENT: Message $messageId not in our seen messages set',
              );
            }
          } else {
            _logger.d('📥 RECEIVED: Message seen from other user ($userId)');
          }
        } else {
          _logger.e(
            '❌ INVALID ACKNOWLEDGMENT DATA: Missing message_id or chat_id',
          );
        }
      } else {
        _logger.e(
          '❌ INVALID ACKNOWLEDGMENT FORMAT: Expected Map, got ${data.runtimeType}',
        );
      }
    } catch (e) {
      _logger.e('❌ Error validating message seen acknowledgment: $e');
    }
  }

  /// ✅ NEW: Centralized message seen update handler
  Future<void> _handleMessageSeenUpdate(dynamic data) async {
    try {
      // Handle both direct message object and wrapped response
      Map<String, dynamic>? messageData;

      if (data is Map<String, dynamic>) {
        // Check if it's a direct message object
        if (data.containsKey('message_id') &&
            data.containsKey('message_seen_status')) {
          messageData = data;
        }
        // Check if it's wrapped in a message key
        else if (data.containsKey('message')) {
          messageData = data['message'] as Map<String, dynamic>?;
        }
      }

      if (messageData == null) {
        _logger.w('⚠️ Invalid message seen data format');
        return;
      }

      final messageId = messageData['message_id'];
      final seenStatus = messageData['message_seen_status'];
      final senderId = messageData['sender_id'];

      if (messageId == null || seenStatus == null) {
        _logger.w('⚠️ Missing required fields in message seen data');
        return;
      }

      // Get current user ID for validation
      final currentUserId = await _getCurrentUserIdAsync();
      if (currentUserId == null) {
        _logger.w(
          '⚠️ Cannot process message seen - current user ID not available',
        );
        return;
      }

      _logger.d('📩 Processing message seen update:');
      _logger.d('  Message ID: $messageId');
      _logger.d('  Status: $seenStatus');
      _logger.d('  Sender ID: $senderId');
      _logger.d('  Current User ID: $currentUserId');

      // ✅ CRITICAL FIX: Update message in current chat data
      bool messageUpdated = await _updateMessageSeenStatus(
        messageId,
        seenStatus,
        senderId,
        currentUserId,
      );

      if (messageUpdated) {
        // ✅ FORCE UI UPDATE: Notify all streams
        _chatsStreamController.add(_chatsData);
        notifyListeners();

        _logger.d('✅ Message seen status updated and UI notified');
      } else {
        _logger.d('⚠️ Message not found in current chat data');
      }
    } catch (e) {
      _logger.e('❌ Error in message seen update handler: $e');
    }
  }

  /// ✅ NEW: Update message seen status in chat data
  Future<bool> _updateMessageSeenStatus(
    int messageId,
    String seenStatus,
    int? senderId,
    int currentUserId,
  ) async {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      _logger.w('⚠️ No chat messages to update seen status');
      return false;
    }

    bool messageFound = false;

    for (int i = 0; i < _chatsData.records!.length; i++) {
      final message = _chatsData.records![i];

      // ✅ FIXED: Match by message ID (not chat ID)
      if (message.messageId == messageId) {
        _logger.d('📝 Found message $messageId for status update');

        // ✅ SIMPLIFIED: Just update the message seen status
        // This handles both scenarios:
        // 1. I mark someone else's message as seen (senderId == currentUserId in params)
        // 2. Someone else marks my message as seen (senderId != currentUserId in params)
        _logger.d(
          '📝 Message details: senderId=${message.senderId}, currentUserId=$currentUserId, paramSenderId=$senderId',
        );

        // Always update for now - we'll add filtering if needed
        _logger.d(
          '✅ Updating message $messageId status: ${message.messageSeenStatus} → $seenStatus',
        );

        // Create updated message with new seen status
        // ✅ CRITICAL FIX: Preserve ALL fields including story data
        final updatedMessage = Records(
          messageContent: message.messageContent,
          replyTo: message.replyTo,
          socialId: message.socialId,
          messageId: message.messageId,
          messageType: message.messageType,
          messageThumbnail: message.messageThumbnail, // ✅ PRESERVE
          messageLength: message.messageLength,
          messageSeenStatus: seenStatus, // ✅ UPDATE STATUS
          messageSize: message.messageSize,
          deletedFor: message.deletedFor,
          starredFor: message.starredFor,
          deletedForEveryone: message.deletedForEveryone,
          pinned: message.pinned,
          stared: message.stared, // ✅ PRESERVE
          pinLifetime: message.pinLifetime,
          pinnedTill: message.pinnedTill,
          createdAt: message.createdAt,
          updatedAt: message.updatedAt,
          chatId: message.chatId,
          senderId: message.senderId,
          storyId: message.storyId, // ✅ CRITICAL: PRESERVE STORY ID
          unseenCount: message.unseenCount, // ✅ PRESERVE
          parentMessage: message.parentMessage,
          replies: message.replies,
          user: message.user,
          story: message.story, // ✅ CRITICAL: PRESERVE STORY DATA
          actionedUser: message.actionedUser, // ✅ PRESERVE
          social: message.social, // ✅ PRESERVE
          peerUserData: message.peerUserData,
          isFollowing: message.isFollowing, // ✅ PRESERVE
          calls: message.calls, // ✅ PRESERVE
          chat: message.chat, // ✅ PRESERVE
        );

        // Replace the message in the list
        _chatsData.records![i] = updatedMessage;
        messageFound = true;

        _logger.d('✅ Message $messageId status updated to: $seenStatus');
        break;
      }
    }

    if (!messageFound) {
      _logger.w(
        '⚠️ Message $messageId not found in current chat for seen status update',
      );
    }

    return messageFound;
  }

  /// Setup socket connection event listeners
  void _setupConnectionListeners() {
    _socketService.onConnect(() {
      _logger.i('🟢 Socket connected - updating UI');
      _isConnected = true;
      _clearError();

      // Refresh data on reconnect
      if (_chatListData.chats.isEmpty) {
        emitChatList();
      }
      emitInitialOnlineUser();
      notifyListeners();

      // Additional notification after a short delay to ensure UI updates
      Future.delayed(Duration(milliseconds: 100), () {
        if (_isInitialized) {
          notifyListeners();
          _logger.d('🔄 Additional UI notification sent after reconnection');
        }
      });
    });

    _socketService.onDisconnect(() {
      _logger.w('🔴 Socket disconnected - updating UI');
      _isConnected = false;
      notifyListeners();

      // Additional notification after a short delay to ensure UI updates
      Future.delayed(Duration(milliseconds: 100), () {
        if (_isInitialized) {
          notifyListeners();
          _logger.d('🔄 Additional UI notification sent after disconnection');
        }
      });
    });

    _socketService.onError((error) {
      _logger.e('❌ Socket error: $error');
      _setError('Socket error: $error');
    });
  }

  /// Update chat list with new message
  // Future<void> _updateChatListWithNewMessage(Records newMessage) async {
  //   if (_chatListData.chats.isEmpty) {
  //     _logger.d('Chat list is empty, cannot update');
  //     return;
  //   }

  //   bool chatFound = false;

  //   // Find and update the matching chat
  //   for (int i = 0; i < _chatListData.chats.length; i++) {
  //     final chat = _chatListData.chats[i];

  //     if (chat.records?.isEmpty ?? true) continue;

  //     final chatRecord = chat.records!.first;

  //     if (_isMatchingChat(newMessage)) {
  //       chatFound = true;

  //       // Check for duplicate message
  //       if (_isMessageAlreadyInChat(chatRecord, newMessage)) {
  //         _logger.d(
  //           'Message ${newMessage.messageId} already exists in chat list',
  //         );
  //         return;
  //       }

  //       // Update chat with new message
  //       await _updateChatRecord(chatRecord, newMessage, i);
  //       break;
  //     }
  //   }

  //   if (!chatFound) {
  //     _logger.d('Chat not found in list, refreshing chat list');
  //     emitChatList();
  //   }
  //   _setPaginationLoading(false);
  // }

  // Future<void> _updateChatListWithNewMessage(Records newMessage) async {
  //   if (_chatListData.chats.isEmpty) {
  //     _logger.d('Chat list is empty, cannot update');
  //     return;
  //   }

  //   bool chatFound = false;
  //   int? targetChatIndex;

  //   _logger.d('🔍 Looking for chat to update with new message:');
  //   _logger.d('  New Message Chat ID: ${newMessage.chatId}');
  //   _logger.d('  New Message Sender ID: ${newMessage.senderId}');
  //   _logger.d('  New Message Peer User: ${newMessage.peerUserData?.userId}');

  //   // Get current user ID once for all comparisons
  //   final currentUserId = await _getCurrentUserIdAsync();
  //   _logger.d('  Current User ID: $currentUserId');

  //   // Find and update the matching chat
  //   for (int i = 0; i < _chatListData.chats.length; i++) {
  //     final chat = _chatListData.chats[i];

  //     if (chat.records?.isEmpty ?? true) continue;

  //     final chatRecord = chat.records!.first;

  //     _logger.d('📋 Checking chat at index $i:');
  //     _logger.d('  Chat Record Chat ID: ${chatRecord.chatId}');
  //     _logger.d('  Chat Record Chat Type: ${chatRecord.chatType}');

  //     // ✅ Log all possible peer user sources for debugging
  //     _logAllPeerUserSources(chat, chatRecord, i);

  //     // ✅ ROBUST: Try multiple matching strategies
  //     if (_isMatchingChatRobust(newMessage, chatRecord, chat, currentUserId)) {
  //       chatFound = true;
  //       targetChatIndex = i;

  //       _logger.d('✅ Found matching chat at index $i');

  //       // Check for duplicate message
  //       if (_isMessageAlreadyInChat(chatRecord, newMessage)) {
  //         _logger.d(
  //           'Message ${newMessage.messageId} already exists in chat list',
  //         );
  //         return;
  //       }

  //       // Update chat with new message
  //       await _updateChatRecord(chatRecord, newMessage, i);
  //       break;
  //     }
  //   }

  //   if (!chatFound) {
  //     _logger.d('❌ Chat not found in list, refreshing chat list');
  //     _logChatListSummary();
  //     emitChatList();
  //   } else {
  //     _logger.d('✅ Successfully updated chat at index $targetChatIndex');
  //   }

  //   _setPaginationLoading(false);
  // }

  // Future<void> _updateChatListWithNewMessage(Records newMessage) async {
  //   if (_chatListData.chats.isEmpty) {
  //     _logger.d('Chat list is empty, cannot update');
  //     return;
  //   }

  //   bool chatFound = false;
  //   final currentUserId = await _getCurrentUserIdAsync();

  //   _logger.d('🔍 Looking for chat to update:');
  //   _logger.d('  New Message Chat ID: ${newMessage.chatId}');
  //   _logger.d('  New Message Sender ID: ${newMessage.senderId}');
  //   _logger.d('  New Message Peer User: ${newMessage.peerUserData?.userId}');
  //   _logger.d('  Current User ID: $currentUserId');

  //   // ✅ ENHANCED: More detailed matching logic
  //   for (int i = 0; i < _chatListData.chats.length; i++) {
  //     final chat = _chatListData.chats[i];

  //     if (chat.records?.isEmpty ?? true) continue;

  //     final chatRecord = chat.records!.first;

  //     _logger.d('📋 Checking chat at index $i:');
  //     _logger.d('  Chat Record Chat ID: ${chatRecord.chatId}');
  //     _logger.d('  Chat Record Chat Type: ${chatRecord.chatType}');
  //     _logger.d('  Chat Peer User ID: ${chat.peerUserData?.userId}');

  //     // ✅ PRIORITY 1: Exact chat ID match
  //     if (newMessage.chatId != null &&
  //         chatRecord.chatId != null &&
  //         newMessage.chatId == chatRecord.chatId) {
  //       chatFound = true;
  //       _logger.d('✅ Found exact chat ID match at index $i');

  //       if (!_isMessageAlreadyInChat(chatRecord, newMessage)) {
  //         await _updateChatRecord(chatRecord, newMessage, i);
  //       }
  //       break;
  //     }
  //     // ✅ PRIORITY 2: Individual chat peer matching
  //     else if (chatRecord.chatType?.toLowerCase() != 'group') {
  //       final chatPeerUserId = chat.peerUserData?.userId;

  //       bool isMatch = false;

  //       // Case 1: New message FROM the peer user TO current user
  //       if (newMessage.senderId == chatPeerUserId) {
  //         isMatch = true;
  //         _logger.d('✅ Match: Message FROM peer user $chatPeerUserId');
  //       }
  //       // Case 2: New message FROM current user TO the peer user
  //       else if (newMessage.senderId == currentUserId &&
  //           newMessage.peerUserData?.userId == chatPeerUserId) {
  //         isMatch = true;
  //         _logger.d('✅ Match: Message TO peer user $chatPeerUserId');
  //       }

  //       if (isMatch) {
  //         chatFound = true;
  //         _logger.d('✅ Found individual chat match at index $i');

  //         if (!_isMessageAlreadyInChat(chatRecord, newMessage)) {
  //           await _updateChatRecord(chatRecord, newMessage, i);
  //         }
  //         break;
  //       }
  //     }
  //   }

  //   if (!chatFound) {
  //     _logger.d('❌ No matching chat found, scheduling refresh');

  //     // Schedule a refresh instead of doing it immediately
  //     Future.delayed(Duration(seconds: 1), () {
  //       emitChatList();
  //     });
  //   }
  // }

  Future<void> _updateChatListWithNewMessage(Records newMessage) async {
    // ✅ CRITICAL FIX: Always check archived chats first, regardless of main chat list status
    await _updateArchivedChatWithNewMessage(newMessage);

    if (_chatListData.chats.isEmpty) {
      _logger.d('Chat list is empty, attempting to create new chat entry');

      // ✅ FIX: When chat list is empty, check if we can create a new chat entry
      if (newMessage.messageType == 'group-created' ||
          newMessage.messageType == 'group_created' ||
          (newMessage.chat != null && newMessage.chatId != null) ||
          (newMessage.peerUserData != null)) {
        _logger.d('🔄 Creating new chat entry for message with available data');
        await _createNewChatEntry(newMessage);
      } else {
        _logger.d('❌ Cannot create new chat entry - insufficient data');
        // Still trigger a chat list refresh as fallback
        emitChatList(page: 1);
      }
      return;
    }

    bool chatFound = false;
    final currentUserId = await _getCurrentUserIdAsync();

    _logger.d('🔍 Looking for chat to update:');
    _logger.d('  New Message Chat ID: ${newMessage.chatId}');
    _logger.d('  New Message Sender ID: ${newMessage.senderId}');

    // ✅ STEP 1: First pass - EXACT chat ID matching (prioritizes groups and existing chats)
    if (newMessage.chatId != null && newMessage.chatId! > 0) {
      for (int i = 0; i < _chatListData.chats.length; i++) {
        final chat = _chatListData.chats[i];
        if (chat.records?.isEmpty ?? true) continue;

        final chatRecord = chat.records!.first;

        // ✅ EXACT MATCH: Chat ID must match exactly
        if (chatRecord.chatId == newMessage.chatId) {
          chatFound = true;
          _logger.d(
            '✅ Found EXACT chat ID match at index $i (ID: ${chatRecord.chatId}, Type: ${chatRecord.chatType})',
          );

          if (!_isMessageAlreadyInChat(chatRecord, newMessage)) {
            await _updateChatRecord(chatRecord, newMessage, i);
          }
          break; // ✅ CRITICAL: Stop after exact match
        }
      }
    }

    // ✅ STEP 2: Second pass - Only for individual chats without chat ID (new chats)
    if (!chatFound && (newMessage.chatId == null || newMessage.chatId == 0)) {
      _logger.d(
        '🔍 No exact chat ID match, trying peer user matching for new individual chat...',
      );

      for (int i = 0; i < _chatListData.chats.length; i++) {
        final chat = _chatListData.chats[i];
        if (chat.records?.isEmpty ?? true) continue;

        final chatRecord = chat.records!.first;
        final chatType = chatRecord.chatType?.toLowerCase();

        // ✅ ONLY match with individual chats (not groups)
        if (chatType != 'group') {
          final chatPeerUserId = chat.peerUserData?.userId;

          if (chatPeerUserId != null) {
            bool isMatch = false;

            // Case 1: Message FROM the peer user TO current user
            if (newMessage.senderId == chatPeerUserId) {
              isMatch = true;
              _logger.d('✅ Match: Message FROM peer user $chatPeerUserId');
            }
            // Case 2: Message FROM current user TO the peer user
            else if (newMessage.senderId == currentUserId &&
                newMessage.peerUserData?.userId == chatPeerUserId) {
              isMatch = true;
              _logger.d('✅ Match: Message TO peer user $chatPeerUserId');
            }

            if (isMatch) {
              chatFound = true;
              _logger.d('✅ Found individual chat match at index $i');

              if (!_isMessageAlreadyInChat(chatRecord, newMessage)) {
                await _updateChatRecord(chatRecord, newMessage, i);
              }
              break;
            }
          }
        }
      }
    }

    if (!chatFound) {
      _logger.d('❌ No matching chat found in main list');
      // ✅ UPDATED: Check if this is a group-created message OR if Chat data is available
      if (newMessage.messageType == 'group-created' ||
          newMessage.messageType == 'group_created' ||
          (newMessage.chat != null && newMessage.chatId != null)) {
        _logger.d('🔄 Creating new chat entry for message with Chat data');
        await _createNewChatEntry(newMessage);
      } else {
        // ✅ FIXED: Don't immediately refresh - this can interrupt pagination
        // Instead, only refresh if it's been a while since last update
        final now = DateTime.now().millisecondsSinceEpoch;
        const refreshCooldown = 5000; // 5 seconds

        if (_lastChatRefresh == null ||
            (now - _lastChatRefresh!) > refreshCooldown) {
          _logger.d('🔄 Scheduling controlled refresh...');
          _lastChatRefresh = now;
          Future.delayed(Duration(seconds: 2), () {
            if (_chatListData.chats.isEmpty ||
                !_chatListData.chats.any(
                  (chat) =>
                      chat.records?.any((r) => r.chatId == newMessage.chatId) ==
                      true,
                )) {
              emitChatList(page: 1); // Only refresh first page
            }
          });
        } else {
          _logger.d('⏱️ Refresh on cooldown, skipping');
        }
      }
    }
  }

  /// ✅ NEW: Update archived chat with new message (real-time updates)
  Future<void> _updateArchivedChatWithNewMessage(Records newMessage) async {
    try {
      _logger.d(
        '🗃️ Checking archive update for message: chatId=${newMessage.chatId}, senderId=${newMessage.senderId}',
      );

      // Only update archived chats if ArchiveChatProvider is available
      if (_archiveChatProvider == null) {
        _logger.d('⚠️ ArchiveChatProvider is null, skipping archive update');
        return;
      }

      _logger.d('✅ ArchiveChatProvider available, delegating archive update');
      // Delegate to ArchiveChatProvider for archived chat updates
      _archiveChatProvider!.updateArchivedChatWithNewMessage(newMessage);
    } catch (e) {
      _logger.e('❌ Error updating archived chat with new message: $e');
    }
  }

  /// Create a new chat entry for newly created chats (groups and private)
  Future<void> _createNewChatEntry(Records newMessage) async {
    try {
      _logger.d('🆕 Creating new chat entry for Chat ID: ${newMessage.chatId}');

      // Extract info from the new message
      final chatId = newMessage.chatId;
      final peerUserData = newMessage.peerUserData;
      final chatInfo =
          newMessage.chat; // ✅ Extract Chat object from socket response

      // ✅ Enhanced check: Allow creation with either chatId OR peerUserData
      if (chatId == null && peerUserData == null) {
        _logger.w(
          '❌ Cannot create chat entry - missing both chat ID and peer user data',
        );
        return;
      }

      // ✅ Determine chat type and extract appropriate info
      final chatType =
          chatInfo?.chatType ?? 'private'; // Default to private for new chats

      // ✅ Extract info based on chat type
      final groupName =
          chatType.toLowerCase() == 'group'
              ? (chatInfo?.groupName?.isNotEmpty == true
                  ? chatInfo!.groupName!
                  : 'New Group')
              : (peerUserData?.fullName ??
                  peerUserData?.userName ??
                  'Unknown User');

      final groupIcon =
          chatType.toLowerCase() == 'group'
              ? (chatInfo?.groupIcon?.isNotEmpty == true
                  ? chatInfo!.groupIcon!
                  : '')
              : (peerUserData?.profilePic ?? '');

      final groupDescription = chatInfo?.groupDescription ?? '';

      // ✅ Determine if message should be marked as unseen
      final currentUserId = await _getCurrentUserIdAsync();
      final isFromCurrentUser = newMessage.senderId == currentUserId;
      final unseenCount =
          isFromCurrentUser ? 0 : 1; // Don't count own messages as unseen

      _logger.d('✅ Extracted chat info:');
      _logger.d('  Chat Name: $groupName');
      _logger.d('  Chat Icon: $groupIcon');
      _logger.d('  Chat Type: $chatType');
      _logger.d('  Chat ID: $chatId');
      _logger.d('  Unseen Count: $unseenCount');

      // Create a new Messages object from the new message
      final newMessages = chatlist.Messages(
        messageContent: newMessage.messageContent,
        replyTo: newMessage.replyTo ?? 0,
        socialId: newMessage.socialId ?? 0,
        messageId: newMessage.messageId,
        messageType: newMessage.messageType,
        messageLength: newMessage.messageLength ?? '',
        messageSeenStatus: newMessage.messageSeenStatus,
        messageSize: newMessage.messageSize ?? '',
        deletedFor: newMessage.deletedFor ?? [],
        starredFor: newMessage.starredFor ?? [],
        deletedForEveryone: newMessage.deletedForEveryone ?? false,
        pinned: newMessage.pinned ?? false,
        createdAt: newMessage.createdAt,
        updatedAt: newMessage.updatedAt,
        chatId: newMessage.chatId,
        senderId: newMessage.senderId,
        user: newMessage.user,
        social: null,
        calls: [],
      );

      // ✅ Create Records object with chat data
      final newChatRecord = chatlist.Records(
        groupIcon: groupIcon,
        chatId: chatId ?? 0, // Use 0 as fallback if chatId is null
        chatType: chatType,
        groupName: groupName,
        groupDescription: groupDescription,
        deletedAt: null,
        createdAt: newMessage.createdAt,
        updatedAt: newMessage.updatedAt,
        messages: [newMessages],
        unseenCount: unseenCount, // ✅ Proper unseen count logic
        blockedBy: [],
      );

      // Create PeerUserData if available
      chatlist.PeerUserData? peerData;
      if (peerUserData != null) {
        peerData = chatlist.PeerUserData(
          userName: peerUserData.userName ?? '',
          email: peerUserData.email ?? '',
          phoneNumber: '', // Use empty string as fallback
          profilePic: peerUserData.profilePic ?? '',
          userId: peerUserData.userId ?? 0,
          fullName: peerUserData.fullName ?? '',
          countryCode: peerUserData.countryCode ?? '',
          country: peerUserData.country ?? '',
          gender: peerUserData.gender ?? '',
          bio: peerUserData.bio ?? '',
          profileVerificationStatus:
              peerUserData.profileVerificationStatus ?? false,
          loginVerificationStatus:
              peerUserData.loginVerificationStatus ?? false,
          socketIds: [], // Use empty list as fallback
          updatedAt: peerUserData.updatedAt,
          createdAt: peerUserData.createdAt,
        );
      }

      // Create a new Chats object
      final newChat = chatlist.Chats(
        records: [newChatRecord],
        peerUserData: peerData,
      );

      // Insert at the beginning of the chat list (most recent first)
      _chatListData.chats.insert(0, newChat);

      _logger.d('✅ Successfully created new chat entry');
      _logger.d('📊 Chat list now has ${_chatListData.chats.length} chats');
      _logger.d(
        '💬 Chat added for: ${chatType == "group" ? "Group" : "Private"} chat with ${peerUserData?.fullName ?? "Unknown"}',
      );

      // Update listeners
      _chatListStreamController.add(_chatListData);
      notifyListeners();
    } catch (e) {
      _logger.e('❌ Error creating new chat entry: $e');
      // Fallback to refresh if creation fails
      emitChatList(page: 1);
    }
  }

  /// Check if message already exists in chat
  bool _isMessageAlreadyInChat(
    chatlist.Records chatRecord,
    Records newMessage,
  ) {
    return chatRecord.messages?.any(
          (msg) => msg.messageId == newMessage.messageId,
        ) ??
        false;
  }

  /// Update chat record with new message
  // Future<void> _updateChatRecord(
  //   chatlist.Records chatRecord,
  //   Records newMessage,
  //   int chatIndex,
  // ) async {
  //   _logger.d('Updating chat record at index $chatIndex');

  //   // Update or create message
  //   if (chatRecord.messages?.isNotEmpty ?? false) {
  //     final lastMessage = chatRecord.messages!.first;
  //     _updateMessageData(lastMessage, newMessage);
  //   } else {
  //     chatRecord.messages = [_createChatListMessage(newMessage)];
  //   }

  //   // Update chat record metadata
  //   chatRecord.createdAt = newMessage.createdAt;
  //   chatRecord.updatedAt = newMessage.updatedAt;

  //   // Update chat ID if it was a new chat
  //   if (chatRecord.chatId == null && newMessage.chatId != null) {
  //     chatRecord.chatId = newMessage.chatId;
  //   }

  //   // Update unread count
  //   await _updateUnreadCount(chatRecord, newMessage);

  //   // Move chat to top of list
  //   final updatedChat = _chatListData.chats.removeAt(chatIndex);
  //   _chatListData.chats.insert(0, updatedChat);

  //   _logger.d('Moved chat to top of list');
  // }

  /// ✅ IMPROVED: Better update logic with more thorough chat matching
  Future<void> _updateChatRecord(
    chatlist.Records chatRecord,
    Records newMessage,
    int chatIndex,
  ) async {
    _logger.d('📝 Updating chat record at index $chatIndex');
    _logger.d('  Chat ID: ${chatRecord.chatId} -> ${newMessage.chatId}');
    _logger.d('  Message: ${newMessage.messageContent}');

    try {
      // ✅ CRITICAL: Update chat ID if it was missing (new chat scenario)
      if (chatRecord.chatId == null && newMessage.chatId != null) {
        _logger.d('🆕 Setting chat ID for new chat: ${newMessage.chatId}');
        chatRecord.chatId = newMessage.chatId;
      }

      // ✅ Update or create message with intelligent handling
      if (chatRecord.messages?.isNotEmpty ?? false) {
        final lastMessage = chatRecord.messages!.first;

        // CRITICAL: Check if this is a brand new message or an update to existing message
        if (newMessage.messageId != null &&
            lastMessage.messageId != null &&
            newMessage.messageId != lastMessage.messageId &&
            newMessage.messageType != 'call') {
          // This is a genuinely new message (different ID, not a call event)
          // Insert it as the new first message
          _logger.d('🆕 Adding completely new message to front of list');
          chatRecord.messages!.insert(0, _createChatListMessage(newMessage));
        } else {
          // This is an update to the existing message (same ID or call event)
          _updateMessageData(lastMessage, newMessage);
          _logger.d('📝 Updated existing message data');
        }
      } else {
        chatRecord.messages = [_createChatListMessage(newMessage)];
        _logger.d('🆕 Created new message entry');
      }

      // ✅ Update chat record metadata
      chatRecord.createdAt = newMessage.createdAt;
      chatRecord.updatedAt = newMessage.updatedAt;

      // ✅ Update group information if available
      if (newMessage.chatId != null &&
          chatRecord.chatType?.toLowerCase() == 'group') {
        // You might want to update group info from the Chat object in the response
        _logger.d('📝 Updated group chat metadata');
      }

      // ✅ Update unread count
      await _updateUnreadCount(chatRecord, newMessage);

      // ✅ Move chat to top of list (most recent first)
      final updatedChat = _chatListData.chats.removeAt(chatIndex);
      _chatListData.chats.insert(0, updatedChat);

      _logger.d('✅ Moved chat to top of list');
      _logger.d('📊 Chat list now has ${_chatListData.chats.length} chats');
    } catch (e) {
      _logger.e('❌ Error updating chat record: $e');
      // Don't throw, just log the error and refresh the list
      emitChatList();
    }
  }

  /// Update message data in chat list
  /// ✅ HELPER: Update existing message data while preserving important fields
  void _updateMessageData(chatlist.Messages lastMessage, Records newMessage) {
    _logger.d('🔄 Updating message data:');
    _logger.d(
      '  Old: ${lastMessage.messageContent} (Type: ${lastMessage.messageType})',
    );
    _logger.d(
      '  New: ${newMessage.messageContent} (Type: ${newMessage.messageType})',
    );
    _logger.d('  Old calls count: ${lastMessage.calls?.length ?? 0}');
    _logger.d('  New calls count: ${newMessage.calls?.length ?? 0}');

    // CRITICAL FIX: Only replace with newer messages, not call events updating existing messages
    final oldMessageId = lastMessage.messageId;
    final newMessageId = newMessage.messageId;

    // If this is truly a newer/different message, update all fields
    if (newMessageId != null &&
        (oldMessageId == null || newMessageId > oldMessageId)) {
      _logger.d(
        '✅ Updating to newer message ID: $oldMessageId -> $newMessageId',
      );

      lastMessage.messageContent = newMessage.messageContent;
      lastMessage.messageType = newMessage.messageType;
      lastMessage.createdAt = newMessage.createdAt;
      lastMessage.updatedAt = newMessage.updatedAt;
      lastMessage.messageId = newMessage.messageId;
      lastMessage.senderId = newMessage.senderId;
      lastMessage.messageSeenStatus = newMessage.messageSeenStatus;

      // Update calls array if provided
      if (newMessage.calls != null && newMessage.calls!.isNotEmpty) {
        lastMessage.calls = newMessage.calls;
        _logger.d(
          '✅ Updated calls array with ${newMessage.calls!.length} calls',
        );
      }

      // Update user data if provided
      if (newMessage.user != null) {
        lastMessage.user = newMessage.user;
      }

      // ✅ CRITICAL FIX: Update actionedUser for member-left/removed/added messages
      // DEFENSIVE: Never overwrite existing actionedUser with null - preserve it!
      if (newMessage.actionedUser != null) {
        lastMessage.actionedUser = chatlist.User(
          userId: newMessage.actionedUser!.userId,
          userName: newMessage.actionedUser!.userName,
          fullName: newMessage.actionedUser!.fullName,
          profilePic: newMessage.actionedUser!.profilePic,
        );
        _logger.d('✅ Updated actionedUser: ${newMessage.actionedUser!.userId}');
      } else if (lastMessage.actionedUser != null) {
        // ANTI-FLICKER: Preserve existing actionedUser if new message doesn't have it
        _logger.d(
          '⚠️ Preserving existing actionedUser: ${lastMessage.actionedUser!.userId}',
        );
      }
    }
    // If it's the same message ID, only update specific fields (for call events)
    else if (newMessageId != null && oldMessageId == newMessageId) {
      _logger.d(
        '🔄 Updating same message ID: $newMessageId (likely call event update)',
      );

      // Only update timestamp and seen status for same message
      lastMessage.updatedAt = newMessage.updatedAt ?? lastMessage.updatedAt;
      lastMessage.messageSeenStatus =
          newMessage.messageSeenStatus ?? lastMessage.messageSeenStatus;

      // Update calls array if provided (this handles call_end events)
      if (newMessage.calls != null && newMessage.calls!.isNotEmpty) {
        lastMessage.calls = newMessage.calls;
        _logger.d('🔄 Updated calls array for existing message');
      }

      // Update message content ONLY for call messages to reflect final status
      if (lastMessage.messageType == 'call' &&
          newMessage.messageContent != null) {
        lastMessage.messageContent = newMessage.messageContent;
        _logger.d(
          '🔄 Updated call message content: ${newMessage.messageContent}',
        );
      }
    }
    // Fallback for cases where we don't have clear message ID info
    else {
      _logger.d('⚠️  Fallback update - preserving calls array');

      // Preserve the calls array from the old message if new message doesn't have calls
      final oldCalls = lastMessage.calls;

      lastMessage.messageContent = newMessage.messageContent;
      lastMessage.messageType = newMessage.messageType;
      lastMessage.createdAt = newMessage.createdAt;
      lastMessage.updatedAt = newMessage.updatedAt;
      lastMessage.messageId = newMessage.messageId;
      lastMessage.senderId = newMessage.senderId;
      lastMessage.messageSeenStatus = newMessage.messageSeenStatus;

      // Preserve or update calls array intelligently
      if (newMessage.calls != null && newMessage.calls!.isNotEmpty) {
        lastMessage.calls = newMessage.calls;
        _logger.d('✅ Updated with new calls array');
      } else if (oldCalls != null && oldCalls.isNotEmpty) {
        // Keep the old calls array if new message doesn't have calls
        lastMessage.calls = oldCalls;
        _logger.d('✅ Preserved existing calls array');
      }

      // ✅ CRITICAL FIX: Update actionedUser for member-left/removed/added messages
      // DEFENSIVE: Never overwrite existing actionedUser with null - preserve it!
      if (newMessage.actionedUser != null) {
        lastMessage.actionedUser = chatlist.User(
          userId: newMessage.actionedUser!.userId,
          userName: newMessage.actionedUser!.userName,
          fullName: newMessage.actionedUser!.fullName,
          profilePic: newMessage.actionedUser!.profilePic,
        );
        _logger.d('✅ Updated actionedUser: ${newMessage.actionedUser!.userId}');
      } else if (lastMessage.actionedUser != null) {
        // ANTI-FLICKER: Preserve existing actionedUser if new message doesn't have it
        _logger.d(
          '⚠️ Preserving existing actionedUser: ${lastMessage.actionedUser!.userId}',
        );
      }
    }

    // Update chat ID if it was missing
    if (lastMessage.chatId == null && newMessage.chatId != null) {
      lastMessage.chatId = newMessage.chatId;
    }

    _logger.d('📊 Final message state:');
    _logger.d('  Content: ${lastMessage.messageContent}');
    _logger.d('  Type: ${lastMessage.messageType}');
    _logger.d('  Calls: ${lastMessage.calls?.length ?? 0}');
    _logger.d('  Message ID: ${lastMessage.messageId}');
  }

  /// ✅ HELPER: Create a properly formatted chat list message
  chatlist.Messages _createChatListMessage(Records newMessage) {
    _logger.d('🆕 Creating new chat list message:');
    _logger.d('  Content: ${newMessage.messageContent}');
    _logger.d('  Type: ${newMessage.messageType}');
    _logger.d('  Calls count: ${newMessage.calls?.length ?? 0}');
    _logger.d('  ActionedUser: ${newMessage.actionedUser?.userId ?? 'null'}');

    return chatlist.Messages(
      messageContent: newMessage.messageContent,
      messageType: newMessage.messageType,
      createdAt: newMessage.createdAt,
      updatedAt: newMessage.updatedAt,
      messageId: newMessage.messageId,
      senderId: newMessage.senderId,
      messageSeenStatus: newMessage.messageSeenStatus,
      chatId: newMessage.chatId,
      calls: newMessage.calls, // CRITICAL FIX: Include calls array
      user: newMessage.user, // Include user data
      actionedUser:
          newMessage.actionedUser != null
              ? chatlist.User(
                userId: newMessage.actionedUser!.userId,
                userName: newMessage.actionedUser!.userName,
                fullName: newMessage.actionedUser!.fullName,
                profilePic: newMessage.actionedUser!.profilePic,
              )
              : null, // ✅ CRITICAL FIX: Include actionedUser for member-left messages
    );
  }

  // /// Update unread count for chat
  // Future<void> _updateUnreadCount(
  //   chatlist.Records chatRecord,
  //   Records newMessage,
  // ) async {
  //   final currentUserId = await _getCurrentUserIdAsync();

  //   if (newMessage.senderId != currentUserId) {
  //     // Message from another user
  //     final currentChatId = _currentChatId ?? 0;
  //     final newMessageChatId = newMessage.chatId ?? 0;

  //     // ✅ FIXED: Check if user is actively viewing THIS specific chat
  //     final isActivelyViewingThisChat =
  //         _isChatScreenActive &&
  //         _isAppInForeground &&
  //         currentChatId > 0 &&
  //         currentChatId == newMessageChatId;

  //     if (isActivelyViewingThisChat) {
  //       // Chat is currently active - keep unread count at 0
  //       chatRecord.unseenCount = 0;
  //       _logger.d('Chat is active, keeping unread count at 0');

  //       // ✅ NEW: Auto-mark the new message as seen
  //       if (newMessage.messageId != null) {
  //         Future.delayed(Duration(milliseconds: 300), () {
  //           emitMessageSeen(newMessageChatId, newMessage.messageId!);
  //         });
  //       }
  //     } else {
  //       // Chat is not currently active - increment unread count
  //       chatRecord.unseenCount = (chatRecord.unseenCount ?? 0) + 1;
  //       _logger.d('Incremented unread count to: ${chatRecord.unseenCount}');
  //     }
  //   } else {
  //     // Message from current user - don't increment unread count
  //     _logger.d('Message from current user, not incrementing unread count');
  //   }
  // }
  /// ✅ ENHANCED: Better unread count logic with proper user context
  Future<void> _updateUnreadCount(
    chatlist.Records chatRecord,
    Records newMessage,
  ) async {
    try {
      final currentUserId = await _getCurrentUserIdAsync();

      _logger.d('📊 Updating unread count:');
      _logger.d('  Current User ID: $currentUserId');
      _logger.d('  Message Sender ID: ${newMessage.senderId}');
      _logger.d('  Current Chat ID: $_currentChatId');
      _logger.d('  Message Chat ID: ${newMessage.chatId}');
      _logger.d('  Is Chat Screen Active: $_isChatScreenActive');
      _logger.d('  Is App In Foreground: $_isAppInForeground');

      // ✅ Only increment unread count for messages from other users
      if (newMessage.senderId != currentUserId) {
        // Message from another user
        final currentChatId = _currentChatId ?? 0;
        final newMessageChatId = newMessage.chatId ?? 0;

        // ✅ CRITICAL FIX: Check if user is actively viewing THIS specific chat
        final isActivelyViewingThisChat =
            _isChatScreenActive &&
            _isAppInForeground &&
            currentChatId > 0 &&
            currentChatId == newMessageChatId;

        _logger.d(
          '  Is Actively Viewing This Chat: $isActivelyViewingThisChat',
        );

        if (isActivelyViewingThisChat) {
          // Chat is currently active - keep unread count at 0
          chatRecord.unseenCount = 0;
          _logger.d('✅ Chat is active, keeping unread count at 0');

          // ✅ Auto-mark the new message as seen after a short delay
          if (newMessage.messageId != null && newMessageChatId > 0) {
            Future.delayed(Duration(milliseconds: 500), () {
              _logger.d('📩 Auto-marking message as seen');
              emitMessageSeen(newMessageChatId, newMessage.messageId!);
            });
          }
        } else {
          // Chat is not currently active - increment unread count
          final oldCount = chatRecord.unseenCount ?? 0;
          chatRecord.unseenCount = oldCount + 1;
          _logger.d(
            '📈 Incremented unread count: $oldCount -> ${chatRecord.unseenCount}',
          );
        }
      } else {
        // Message from current user - keep unread count as is (don't increment)
        _logger.d(
          '⏭️ Message from current user, not incrementing unread count',
        );
      }
    } catch (e) {
      _logger.e('❌ Error updating unread count: $e');
      // Fallback: increment unread count if we can't determine user context
      if (chatRecord.unseenCount == null) {
        chatRecord.unseenCount = 1;
      } else {
        chatRecord.unseenCount = chatRecord.unseenCount! + 1;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DELETE CHAT METHOD
  // ═══════════════════════════════════════════════════════════════════════════

  // ✅ NEW: Setup message deletion event listeners
  void _setupMessageDeletionListeners() {
    // Delete for me event
    _socketService.on(_socketEvents.messageDeleteForMe, (data) {
      _logger.d('📱 Received delete for me event: $data');
      _handleDeleteForMeEvent(data);
    });

    // Delete for everyone event
    _socketService.on(_socketEvents.messageDeleteForEveryone, (data) {
      _logger.d('🗑️ Received delete for everyone event: $data');
      _handleDeleteForEveryoneEvent(data);
    });
  }

  // ✅ NEW: Handle delete for me event
  void _handleDeleteForMeEvent(dynamic data) {
    try {
      _logger.d('Processing delete for me event: $data');

      // Handle string response (like "Message Already deleted.")
      if (data is String) {
        _logger.d('Delete for me response: $data');

        // ✅ Use the stored pending delete action to remove the message
        if (_pendingDeleteMessageId != null &&
            _pendingDeleteChatId != null &&
            _isPendingDeleteForMe) {
          _logger.d(
            '📝 Using pending delete action - MessageID: $_pendingDeleteMessageId, ChatID: $_pendingDeleteChatId',
          );

          // Remove message from current chat data using stored IDs
          if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
            final initialCount = _chatsData.records!.length;

            _chatsData.records!.removeWhere(
              (record) =>
                  record.messageId == _pendingDeleteMessageId &&
                  record.chatId == _pendingDeleteChatId,
            );

            final finalCount = _chatsData.records!.length;

            if (initialCount > finalCount) {
              _logger.d('✅ Message deleted locally using pending action');

              // Update pagination if needed
              if (_chatsData.pagination != null) {
                _chatsData.pagination!.totalRecords = finalCount;
              }

              // Notify UI
              _chatsStreamController.add(_chatsData);
              notifyListeners();

              // Update chat list to reflect the deletion
              _updateChatListAfterDeletion(
                _pendingDeleteMessageId!,
                _pendingDeleteChatId!,
              );
            } else {
              _logger.w(
                '⚠️ Message not found in current chat data for deletion',
              );
              // Message might already be removed or not in current view, refresh to sync
              _refreshCurrentChatAfterDeletion();
            }
          }

          // ✅ Clear pending delete action
          _clearPendingDeleteAction();
        } else {
          _logger.w('⚠️ No pending delete action found for string response');
          // Fallback: refresh current chat to sync with server
          _refreshCurrentChatAfterDeletion();
        }
        return;
      }

      // Handle object response with message details
      if (data is Map<String, dynamic>) {
        final messageId = data['message_id'];
        final chatId = data['chat_id'];

        if (messageId == null || chatId == null) {
          _logger.w(
            '⚠️ Invalid delete for me data: missing message_id or chat_id',
          );
          return;
        }

        _logger.d(
          'Processing delete for me - Message ID: $messageId, Chat ID: $chatId',
        );

        // Remove message from current chat data
        if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
          final initialCount = _chatsData.records!.length;

          _chatsData.records!.removeWhere(
            (record) =>
                record.messageId == messageId && record.chatId == chatId,
          );

          final finalCount = _chatsData.records!.length;

          if (initialCount > finalCount) {
            _logger.d('✅ Message deleted locally for current user');

            // Update pagination if needed
            if (_chatsData.pagination != null) {
              _chatsData.pagination!.totalRecords = finalCount;
            }

            // Notify UI
            _chatsStreamController.add(_chatsData);
            notifyListeners();

            // Update chat list to reflect the deletion
            _updateChatListAfterDeletion(messageId, chatId);
          } else {
            _logger.w('⚠️ Message not found in current chat data for deletion');
          }
        }

        // ✅ Clear pending delete action
        _clearPendingDeleteAction();
      }
    } catch (e) {
      _logger.e('❌ Error handling delete for me event: $e');
      _setError('Failed to delete message: ${e.toString()}');
      // ✅ Clear pending delete action on error
      _clearPendingDeleteAction();
    }
  }

  void _storePendingDeleteAction(
    int messageId,
    int chatId,
    bool isDeleteForMe,
  ) {
    _pendingDeleteMessageId = messageId;
    _pendingDeleteChatId = chatId;
    _isPendingDeleteForMe = isDeleteForMe;
    _logger.d(
      '📝 Stored pending delete action - MessageID: $messageId, ChatID: $chatId, ForMe: $isDeleteForMe',
    );
  }

  void _clearPendingDeleteAction() {
    _pendingDeleteMessageId = null;
    _pendingDeleteChatId = null;
    _isPendingDeleteForMe = false;
    _logger.d('🧹 Cleared pending delete action');
  }

  void _refreshCurrentChatAfterDeletion() {
    try {
      if (_currentChatId != null && _currentChatId! > 0) {
        _logger.d('🔄 Emitting chat messages to refresh after deletion');

        // Re-emit chat messages to get updated list from server
        emitChatMessages(chatId: _currentChatId!, page: 1);
      } else if (_currentUserId != null && _currentUserId! > 0) {
        _logger.d(
          '🔄 Emitting chat messages for user to refresh after deletion',
        );

        // For new chats, use user ID
        emitChatMessages(peerId: _currentUserId!, page: 1);
      }
    } catch (e) {
      _logger.e('❌ Error refreshing chat after deletion: $e');
    }
  }

  // ✅ NEW: Handle delete for everyone event
  void _handleDeleteForEveryoneEvent(dynamic data) {
    try {
      _logger.d('Processing delete for everyone event: $data');

      // Handle the actual response format which is a Records object
      if (data is Map<String, dynamic>) {
        // Try to parse as Records object first
        Records? updatedMessage;

        try {
          updatedMessage = Records.fromJson(data);
          _logger.d('✅ Parsed delete for everyone response as Records object');
        } catch (e) {
          _logger.w('⚠️ Could not parse as Records object: $e');

          // Fallback to manual extraction
          final messageId = data['message_id'];
          final chatId = data['chat_id'];

          if (messageId == null || chatId == null) {
            _logger.w(
              '⚠️ Invalid delete for everyone data: missing message_id or chat_id',
            );
            return;
          }

          // Create a minimal Records object for processing
          updatedMessage = Records(
            messageId: messageId,
            chatId: chatId,
            deletedForEveryone: data['deleted_for_everyone'] ?? true,
            messageContent:
                data['message_content'] ?? 'This message was deleted.',
            messageType: data['message_type'] ?? 'text',
            senderId: data['sender_id'],
            createdAt: data['createdAt'],
            updatedAt: data['updatedAt'],
          );
        }

        if (updatedMessage.messageId != null && updatedMessage.chatId != null) {
          _logger.d(
            'Processing delete for everyone - Message ID: ${updatedMessage.messageId}, Chat ID: ${updatedMessage.chatId}',
          );

          // Find and update the message to mark as deleted for everyone
          if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
            bool messageUpdated = false;

            for (int i = 0; i < _chatsData.records!.length; i++) {
              final record = _chatsData.records![i];

              if (record.messageId == updatedMessage.messageId &&
                  record.chatId == updatedMessage.chatId) {
                // Create updated record with deletedForEveryone = true and updated content
                // ✅ CRITICAL FIX: Preserve ALL fields including story data
                final updatedRecord = Records(
                  messageContent:
                      'This message was deleted.', // ✅ Use standard deleted message text
                  replyTo: record.replyTo,
                  socialId: record.socialId,
                  messageId: record.messageId,
                  messageType: record.messageType,
                  messageThumbnail: record.messageThumbnail, // ✅ PRESERVE
                  messageLength: record.messageLength,
                  messageSeenStatus: record.messageSeenStatus,
                  messageSize: record.messageSize,
                  deletedFor: updatedMessage.deletedFor ?? record.deletedFor,
                  starredFor: record.starredFor,
                  deletedForEveryone: true, // ✅ Mark as deleted for everyone
                  pinned: record.pinned,
                  stared: record.stared, // ✅ PRESERVE
                  pinLifetime: record.pinLifetime,
                  pinnedTill: record.pinnedTill,
                  createdAt: record.createdAt,
                  updatedAt: updatedMessage.updatedAt ?? record.updatedAt,
                  chatId: record.chatId,
                  senderId: record.senderId,
                  storyId: record.storyId, // ✅ CRITICAL: PRESERVE STORY ID
                  unseenCount: record.unseenCount, // ✅ PRESERVE
                  parentMessage: record.parentMessage,
                  replies: record.replies,
                  user: record.user,
                  story: record.story, // ✅ CRITICAL: PRESERVE STORY DATA
                  actionedUser: record.actionedUser, // ✅ PRESERVE
                  social: record.social, // ✅ PRESERVE
                  peerUserData: record.peerUserData,
                  isFollowing: record.isFollowing, // ✅ PRESERVE
                  calls: record.calls, // ✅ PRESERVE
                  chat: record.chat, // ✅ PRESERVE
                );

                // Replace the message in the list
                _chatsData.records![i] = updatedRecord;
                messageUpdated = true;

                _logger.d('✅ Message marked as deleted for everyone');
                break;
              }
            }

            if (messageUpdated) {
              // Notify UI
              _chatsStreamController.add(_chatsData);
              notifyListeners();

              // Update chat list to show "This message was deleted." preview
              _updateChatListAfterDeletion(
                updatedMessage.messageId!,
                updatedMessage.chatId!,
                isDeletedForEveryone: true,
              );
            } else {
              _logger.w(
                '⚠️ Message not found in current chat data for deletion update',
              );
            }
          }
        }
      } else {
        _logger.w(
          '⚠️ Unexpected delete for everyone response format: ${data.runtimeType}',
        );
      }
    } catch (e) {
      _logger.e('❌ Error handling delete for everyone event: $e');
      _setError('Failed to update deleted message: ${e.toString()}');
    }
  }

  // ✅ NEW: Update chat list after message deletion
  void _updateChatListAfterDeletion(
    int messageId,
    int chatId, {
    bool isDeletedForEveryone = false,
  }) {
    try {
      if (_chatListData.chats.isEmpty) return;

      for (int i = 0; i < _chatListData.chats.length; i++) {
        final chat = _chatListData.chats[i];

        if (chat.records?.isNotEmpty == true) {
          final chatRecord = chat.records!.first;

          // Check if this chat matches
          if (chatRecord.chatId == chatId) {
            // Check if the deleted message was the latest message
            if (chatRecord.messages?.isNotEmpty == true) {
              final latestMessage = chatRecord.messages!.first;

              if (latestMessage.messageId == messageId) {
                if (isDeletedForEveryone) {
                  // Update the message content to show "This message was deleted."
                  latestMessage.messageContent = "This message was deleted.";
                  latestMessage.messageType =
                      "text"; // Keep as text type for consistency
                } else {
                  // For delete for me, we need to refresh to get the previous message
                  _refreshChatListAfterLocalDeletion(chatId);
                  return;
                }

                // Notify chat list update
                _chatListStreamController.add(_chatListData);
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      _logger.e('❌ Error updating chat list after deletion: $e');
    }
  }

  // ✅ NEW: Refresh chat list after local deletion
  void _refreshChatListAfterLocalDeletion(int chatId) {
    // Trigger a refresh of the chat list to get the updated latest message
    Future.delayed(Duration(milliseconds: 500), () {
      refreshChatList(silent: true);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE SEEN STATUS METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Enhanced emit message seen with strict validation
  void emitMessageSeen(int chatId, int messageId) async {
    try {
      // Get current user ID first
      final currentUserId = await _getCurrentUserIdAsync();
      if (currentUserId == null) {
        _logger.w(
          'Cannot mark message as seen - current user ID not available',
        );
        return;
      }

      // ✅ STRICT VALIDATION: Log all validation checks
      _logger.d('🔍 VALIDATION START for message $messageId:');

      final isAlreadyTracked = _seenMessages.contains(messageId);
      _logger.d('  - Already tracked as seen: $isAlreadyTracked');

      bool isLocallyMarkedSeen = false;
      bool isMyOwnMessage = false;
      if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
        final message = _chatsData.records!.firstWhere(
          (msg) => msg.messageId == messageId,
          orElse: () => Records(),
        );
        isLocallyMarkedSeen = message.messageSeenStatus == 'seen';
        isMyOwnMessage = message.senderId == currentUserId;
        _logger.d(
          '  - Locally marked as seen: $isLocallyMarkedSeen (status: ${message.messageSeenStatus})',
        );
        _logger.d(
          '  - Message sender: ${message.senderId} (current user: $currentUserId) - isMyMessage: $isMyOwnMessage',
        );

        // ✅ CRITICAL FIX: Only skip if message is from current user (my own message)
        if (isMyOwnMessage) {
          _logger.d(
            '  - ❌ SKIPPED: This is my own message, no need to mark as seen',
          );
          return;
        }
      }

      // ✅ ENHANCED DUPLICATE CHECK: Only skip if already tracked AND locally seen
      if (isAlreadyTracked && isLocallyMarkedSeen) {
        _logger.d(
          '❌ SKIPPED: Message $messageId already fully processed (tracked: $isAlreadyTracked, seen: $isLocallyMarkedSeen)',
        );
        return;
      }

      // ✅ FORCE EMIT: Even if tracked but not locally seen, emit again
      if (isAlreadyTracked && !isLocallyMarkedSeen) {
        _logger.w(
          '⚠️ RE-EMITTING: Message $messageId was tracked but not confirmed locally seen',
        );
        _seenMessages.remove(messageId); // Remove to allow re-emission
      }

      _logger.d(
        '✅ VALIDATION PASSED: Proceeding with emission for message $messageId',
      );
      _logger.d(
        '🚀 EMITTING message seen - chatId: $chatId, messageId: $messageId, currentUserId: $currentUserId',
      );

      // Add to seen messages set BEFORE emitting to prevent race conditions
      _seenMessages.add(messageId);

      // ✅ IMMEDIATE LOCAL UPDATE: Update UI immediately for better UX
      _logger.d(
        '🔄 IMMEDIATE: Updating local message $messageId status to seen',
      );
      bool localUpdateSuccess = await _updateMessageSeenStatus(
        messageId,
        'seen',
        null, // senderId doesn't matter for immediate local update
        currentUserId,
      );

      if (localUpdateSuccess) {
        // ✅ IMMEDIATE UI UPDATE: Force UI refresh
        _chatsStreamController.add(_chatsData);
        notifyListeners();
        _logger.d('🔄 IMMEDIATE: Local UI updated for message $messageId');
      }

      // ✅ ENHANCED EMISSION WITH ACK TRACKING
      _socketService.emit(
        _socketEvents.realTimeMessageSeen,
        data: {
          "chat_id": chatId,
          "message_id": messageId,
          "status": "seen",
          "user_id": currentUserId,
          "timestamp": DateTime.now().millisecondsSinceEpoch, // For debugging
        },
      );

      _logger.d(
        '✅ SUCCESS: Message seen event emitted for messageId: $messageId',
      );

      // ✅ TRACK EMISSION FOR DEBUGGING
      _trackEmissionForDebugging(chatId, messageId);
    } catch (e) {
      _logger.e('❌ ERROR emitting message seen event: $e');
      _setError('Failed to mark message as seen: ${e.toString()}');
      // Remove from seen messages set if emission failed
      _seenMessages.remove(messageId);

      // ✅ TRACK FAILED EMISSION
      _logger.e('❌ FAILED EMISSION for messageId: $messageId, chatId: $chatId');
    }
  }

  /// Track emissions for debugging the 7 vs 4 issue
  final Map<int, Map<String, dynamic>> _emissionTracker = {};

  void _trackEmissionForDebugging(int chatId, int messageId) {
    final key = messageId;
    _emissionTracker[key] = {
      'chatId': chatId,
      'messageId': messageId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'emitted': true,
    };

    _logger.d(
      '📊 EMISSION TRACKED: Total emissions in session: ${_emissionTracker.length}',
    );
    _logger.d('📊 EMISSION LIST: ${_emissionTracker.keys.toList()}');
  }

  /// Get emission statistics for debugging
  Map<String, dynamic> getEmissionStats() {
    final totalEmissions = _emissionTracker.length;
    final emittedMessages = _emissionTracker.keys.toList();
    final totalAcknowledged = _emissionStats['acknowledged'] ?? 0;

    return {
      'totalEmissions': totalEmissions,
      'totalAcknowledged': totalAcknowledged,
      'emittedMessageIds': emittedMessages,
      'seenMessagesCache': _seenMessages.toList(),
      'lastEmissionTime':
          _emissionTracker.values.isNotEmpty
              ? _emissionTracker.values.last['timestamp']
              : null,
      'emissionAckRatio':
          totalEmissions > 0 ? totalAcknowledged / totalEmissions : 0.0,
      'missingAcknowledgments': totalEmissions - totalAcknowledged,
    };
  }

  /// Get a detailed report of emission vs acknowledgment discrepancies
  Map<String, dynamic> getEmissionVsAcknowledgmentReport() {
    final stats = getEmissionStats();
    final totalEmissions = stats['totalEmissions'] as int;
    final totalAcknowledged = stats['totalAcknowledged'] as int;

    return {
      'summary': {
        'totalEmissions': totalEmissions,
        'totalAcknowledged': totalAcknowledged,
        'missingAcknowledgments': totalEmissions - totalAcknowledged,
        'successRate':
            totalEmissions > 0
                ? '${(totalAcknowledged / totalEmissions * 100).toStringAsFixed(1)}%'
                : '0%',
      },
      'details': {
        'emittedMessageIds': stats['emittedMessageIds'],
        'seenMessagesCache': stats['seenMessagesCache'],
        'emissionTracker': _emissionTracker,
        'emissionStats': _emissionStats,
      },
      'recommendations': _generateRecommendations(
        totalEmissions,
        totalAcknowledged,
      ),
    };
  }

  List<String> _generateRecommendations(int emissions, int acknowledgments) {
    final recommendations = <String>[];

    if (emissions == 0) {
      recommendations.add(
        'No emissions detected - check if markMessageAsSeen is being called',
      );
    } else if (acknowledgments == 0) {
      recommendations.add(
        'No acknowledgments received - check socket connection and event listeners',
      );
    } else if (acknowledgments < emissions) {
      final missing = emissions - acknowledgments;
      recommendations.add(
        '$missing acknowledgments missing - possible socket delivery issues',
      );
      recommendations.add(
        'Check network connectivity and server-side event handling',
      );
    } else if (acknowledgments > emissions) {
      recommendations.add(
        'More acknowledgments than emissions - possible duplicate event handling',
      );
    } else {
      recommendations.add(
        'Emission and acknowledgment counts match - system working correctly',
      );
    }

    return recommendations;
  }

  /// Batch emit multiple message seen events with strict validation
  /// Recommended for bulk operations to ensure no messages are lost
  Future<Map<String, dynamic>> batchEmitMessagesSeen({
    required int chatId,
    required List<int> messageIds,
    int batchSize = 5,
    Duration delayBetweenBatches = const Duration(milliseconds: 100),
  }) async {
    _logger.d(
      '🎯 BATCH EMISSION: Starting to emit ${messageIds.length} message seen events',
    );
    _logger.d('📋 MESSAGE IDS: $messageIds');
    _logger.d(
      '⚙️  BATCH SIZE: $batchSize, DELAY: ${delayBetweenBatches.inMilliseconds}ms',
    );

    final results = {
      'totalIntended': messageIds.length,
      'totalSuccessful': 0,
      'totalFailed': 0,
      'successfulIds': <int>[],
      'failedIds': <int>[],
      'errors': <String>[],
      'batchResults': <Map<String, dynamic>>[],
    };

    // Split into batches
    final batches = <List<int>>[];
    for (int i = 0; i < messageIds.length; i += batchSize) {
      final end =
          (i + batchSize < messageIds.length)
              ? i + batchSize
              : messageIds.length;
      batches.add(messageIds.sublist(i, end));
    }

    _logger.d('📦 SPLIT INTO ${batches.length} BATCHES');

    // Process each batch
    for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batch = batches[batchIndex];
      _logger.d(
        '📦 PROCESSING BATCH ${batchIndex + 1}/${batches.length}: ${batch.length} messages',
      );

      final batchResult = {
        'batchIndex': batchIndex + 1,
        'messageIds': batch,
        'successful': <int>[],
        'failed': <int>[],
        'errors': <String>[],
      };

      // Process each message in the batch
      for (final messageId in batch) {
        try {
          // Use the existing strict validation emission method
          await Future.microtask(() => emitMessageSeen(chatId, messageId));

          (batchResult['successful'] as List<int>).add(messageId);
          (results['successfulIds'] as List<int>).add(messageId);
          results['totalSuccessful'] = (results['totalSuccessful'] as int) + 1;

          _logger.d(
            '✅ BATCH SUCCESS: Message $messageId emitted in batch ${batchIndex + 1}',
          );
        } catch (e) {
          final error = 'Failed to emit message $messageId: $e';
          (batchResult['failed'] as List<int>).add(messageId);
          (batchResult['errors'] as List<String>).add(error);
          (results['failedIds'] as List<int>).add(messageId);
          (results['errors'] as List<String>).add(error);
          results['totalFailed'] = (results['totalFailed'] as int) + 1;

          _logger.e(
            '❌ BATCH FAILURE: Message $messageId failed in batch ${batchIndex + 1}: $e',
          );
        }
      }

      (results['batchResults'] as List<Map<String, dynamic>>).add(batchResult);

      // Add delay between batches to prevent overwhelming the socket
      if (batchIndex < batches.length - 1 &&
          delayBetweenBatches.inMilliseconds > 0) {
        _logger.d(
          '⏱️  BATCH DELAY: Waiting ${delayBetweenBatches.inMilliseconds}ms before next batch',
        );
        await Future.delayed(delayBetweenBatches);
      }
    }

    // Final report
    final totalIntended = results['totalIntended'] as int;
    final totalSuccessful = results['totalSuccessful'] as int;
    final totalFailed = results['totalFailed'] as int;

    final successRate =
        totalIntended > 0
            ? (totalSuccessful / totalIntended * 100).toStringAsFixed(1)
            : '0.0';

    _logger.d('📊 BATCH EMISSION COMPLETE:');
    _logger.d('  - Total Intended: $totalIntended');
    _logger.d('  - Total Successful: $totalSuccessful');
    _logger.d('  - Total Failed: $totalFailed');
    _logger.d('  - Success Rate: $successRate%');

    if (totalFailed > 0) {
      _logger.w('⚠️  FAILED MESSAGE IDS: ${results['failedIds']}');
    }

    return results;
  }

  /// Clear emission tracking (call when switching chats)
  void clearEmissionTracking() {
    _emissionTracker.clear();
    _emissionStats.clear();
    _logger.d('🧹 EMISSION TRACKING CLEARED');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPOSE METHOD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Setup archive chat event listeners
  void _setupArchiveChatListeners() {
    if (_archiveChatProvider == null) {
      _logger.w(
        'ArchiveChatProvider not provided, skipping archive chat listeners setup',
      );
      return;
    }

    // Listen to archive action for a single chat update
    _socketService.on(_socketEvents.archiveChatEvent, (data) {
      _logger.d('Received archive chat event: $data');
      // ✅ NEW: Handle archive status change in unified manner
      _handleArchiveStatusChange(data);
      // Still call the provider method for backward compatibility
      _archiveChatProvider?.handleArchiveChat(data);
    });

    // Listen to full archived chat list with pagination
    _socketService.on(_socketEvents.archivedChatListEvent, (data) {
      _logger.d('Received archived chat list event: $data');
      _archiveChatProvider?.handleArchivedChatList(data);
    });

    _logger.i('Archive chat event listeners setup completed');
  }

  /// ✅ NEW: Handle archive status changes that affect both regular and archived lists
  void _handleArchiveStatusChange(dynamic archiveData) async {
    try {
      _logger.d(
        '🗃️ Processing archive status change: $archiveData (type: ${archiveData.runtimeType})',
      );

      // ✅ HANDLE STRING RESPONSES (e.g., demo accounts or errors)
      if (archiveData is String) {
        _logger.w(
          'Received String response for archive status change: $archiveData',
        );
        return;
      }

      // ✅ HANDLE MAP RESPONSE (normal case)
      if (archiveData is! Map<String, dynamic>) {
        _logger.e(
          'Unexpected data type for archive status change: ${archiveData.runtimeType}',
        );
        return;
      }

      // Parse the archive response
      if (archiveData['success'] == true && archiveData['message'] != null) {
        final message = archiveData['message'].toString();
        final isArchived = message.contains('archived : true');
        final isUnarchived = message.contains('archived : false');

        // Get the chat ID that was affected (should be stored by ArchiveChatProvider)
        // For now, we'll trigger a refresh to ensure consistency
        if (isArchived || isUnarchived) {
          _logger.d(
            'Archive status changed - refreshing chat list to ensure consistency',
          );

          // Refresh the main chat list to reflect archive status changes
          await refreshChatList(silent: true);

          if (isUnarchived) {
            // If a chat was unarchived, also refresh archived list to remove it from there
            await _archiveChatProvider?.fetchArchivedChats();
          }
        }
      }
    } catch (e) {
      _logger.e('❌ Error handling archive status change: $e');
    }
  }

  /// Set the ArchiveChatProvider after it's available
  void setArchiveChatProvider(ArchiveChatProvider archiveChatProvider) {
    _logger.i('🔗 Setting ArchiveChatProvider and setting up listeners');

    // ✅ CRITICAL: Store the provider reference
    _archiveChatProvider = archiveChatProvider;
    _logger.i('✅ ArchiveChatProvider successfully set and stored');

    // Remove any existing listeners to prevent duplicates
    _socketService.off(_socketEvents.archiveChatEvent);
    _socketService.off(_socketEvents.archivedChatListEvent);

    // Listen to archive action for a single chat update
    _socketService.on(_socketEvents.archiveChatEvent, (data) {
      _logger.d('Received archive chat event: $data');
      // ✅ NEW: Handle archive status change in unified manner
      _handleArchiveStatusChange(data);
      // Still call the provider method for backward compatibility
      archiveChatProvider.handleArchiveChat(data);
    });

    // Listen to full archived chat list with pagination
    _socketService.on(_socketEvents.archivedChatListEvent, (data) {
      _logger.d('Received archived chat list event: $data');
      archiveChatProvider.handleArchivedChatList(data);
    });

    _logger.i('Archive chat event listeners setup completed');
  }

  /// Setup missed call event listener
  void _setupMissedCallListener() {
    _socketService.on(_socketEvents.missCall, (data) {
      _logger.d('Received missed call event: $data');

      try {
        // Parse missed call data
        final Map<String, dynamic> missedCallData = {};

        if (data is Map<String, dynamic>) {
          missedCallData.addAll(data);
        }

        final int? chatId = missedCallData['chat_id'];
        final int? messageId = missedCallData['message_id'];

        if (chatId == null) {
          _logger.e('Missing chat_id in missed call data');
          return;
        }

        _logger.i(
          'Processing missed call for chat_id: $chatId, message_id: $messageId',
        );

        // Update the chat list to show "missed call" as the latest message
        _updateChatWithMissedCallMessage(chatId, messageId, missedCallData);

        // Also update current chat messages if user is viewing this chat
        _updateCurrentChatWithMissedCallMessage(
          chatId,
          messageId,
          missedCallData,
        );
      } catch (e, stackTrace) {
        _logger.e('Error handling missed call: $e');
        _logger.e('Stack trace: $stackTrace');
      }
    });

    _logger.i('Missed call event listener setup completed');
  }

  /// Update chat with missed call message
  void _updateChatWithMissedCallMessage(
    int chatId,
    int? messageId,
    Map<String, dynamic> missedCallData,
  ) {
    try {
      // Find the chat in the chat list
      final chatIndex = _chatListData.chats.indexWhere((chat) {
        final record =
            chat.records?.isNotEmpty == true ? chat.records!.first : null;
        return record?.chatId == chatId;
      });

      if (chatIndex == -1) {
        _logger.w('Chat with ID $chatId not found in chat list');
        return;
      }

      final targetChat = _chatListData.chats[chatIndex];
      final chatRecord =
          targetChat.records?.isNotEmpty == true
              ? targetChat.records!.first
              : null;

      if (chatRecord == null) {
        _logger.e('No chat record found for chat ID $chatId');
        return;
      }

      // Create or update the latest message with "missed call" content
      chatRecord.messages ??= [];

      // Check if we need to create a new message or update existing one
      if (messageId != null && chatRecord.messages!.isNotEmpty) {
        // Try to find existing message by ID
        final existingMessageIndex = chatRecord.messages!.indexWhere(
          (msg) => msg.messageId == messageId,
        );

        if (existingMessageIndex != -1) {
          // Update existing message
          chatRecord.messages![existingMessageIndex].messageContent =
              "callmissed";

          // CRITICAL FIX: Also update the call status and users array for ChatList
          if (chatRecord.messages![existingMessageIndex].calls != null &&
              chatRecord.messages![existingMessageIndex].calls!.isNotEmpty) {
            for (var call
                in chatRecord.messages![existingMessageIndex].calls!) {
              call.callStatus = "missed";
              // Update users array from missed call event for correct logic
              if (missedCallData['users'] != null) {
                call.users =
                    (missedCallData['users'] as List)
                        .map(
                          (e) => e is int ? e : int.tryParse(e.toString()) ?? 0,
                        )
                        .toList();
              }
            }
            _logger.i(
              'Updated ChatList call status to "missed" and users array in calls array for message $messageId',
            );
          }

          _logger.i(
            'Updated existing message $messageId with "callmissed" content',
          );
        } else {
          // Add new message at the beginning (most recent)
          chatRecord.messages!.insert(
            0,
            chatlist.Messages(
              messageId: messageId,
              messageContent: "callmissed",
              messageType: "call",
              chatId: chatId,
              senderId: missedCallData['user_id'] ?? missedCallData['peer_id'],
              createdAt: DateTime.now().toIso8601String(),
              updatedAt: DateTime.now().toIso8601String(),
            ),
          );
          _logger.i('Added new missed call message with ID $messageId');
        }
      } else {
        // No message ID provided or no existing messages, create new message
        final newMessageId = messageId ?? DateTime.now().millisecondsSinceEpoch;
        chatRecord.messages!.insert(
          0,
          chatlist.Messages(
            messageId: newMessageId,
            messageContent: "callmissed",
            messageType: "call",
            chatId: chatId,
            senderId: missedCallData['user_id'] ?? missedCallData['peer_id'],
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        _logger.i(
          'Added new missed call message with generated ID $newMessageId',
        );
      }

      // Update chat timestamp to ensure proper sorting
      final currentTime = DateTime.now().toIso8601String();
      chatRecord.updatedAt = currentTime;

      // Also update the message timestamp to be the most recent
      if (chatRecord.messages?.isNotEmpty == true) {
        chatRecord.messages!.first.updatedAt = currentTime;
        chatRecord.messages!.first.createdAt = currentTime;
      }

      // Move this chat to the top of the list (most recent activity)
      final updatedChat = _chatListData.chats.removeAt(chatIndex);
      _chatListData.chats.insert(0, updatedChat);
      _logger.d(
        'Moved chat $chatId to top of chat list (from index $chatIndex to 0)',
      );

      // Notify listeners with updated chat list
      _chatListStreamController.add(_chatListData);
      notifyListeners();

      // Force a secondary update to ensure the chat stays at the top
      Future.delayed(Duration(milliseconds: 100), () {
        if (!_chatListStreamController.isClosed) {
          _chatListStreamController.add(_chatListData);
          notifyListeners();
          _logger.d('Secondary notification sent for chat list update');
        }
      });

      _logger.i('Successfully updated chat $chatId with missed call message');
    } catch (e, stackTrace) {
      _logger.e('Error updating chat with missed call message: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// Update current chat messages with missed call message if user is viewing this chat
  void _updateCurrentChatWithMissedCallMessage(
    int chatId,
    int? messageId,
    Map<String, dynamic> missedCallData,
  ) {
    try {
      // Check if user is currently viewing this chat
      if (_currentChatId == null || _currentChatId != chatId) {
        _logger.d(
          'Not updating current chat - user not viewing chat $chatId (current: $_currentChatId)',
        );
        return;
      }

      _logger.i(
        'Updating current chat messages for missed call - chat_id: $chatId, message_id: $messageId',
      );

      // Initialize records if null
      _chatsData.records ??= [];

      // Check if we need to create a new message or update existing one
      if (messageId != null && _chatsData.records!.isNotEmpty) {
        // Try to find existing message by ID
        final existingMessageIndex = _chatsData.records!.indexWhere(
          (msg) => msg.messageId == messageId,
        );

        if (existingMessageIndex != -1) {
          // Update existing message
          _chatsData.records![existingMessageIndex].messageContent =
              "callmissed";

          // CRITICAL FIX: Also update the call status and users array from missed call event
          if (_chatsData.records![existingMessageIndex].calls != null &&
              _chatsData.records![existingMessageIndex].calls!.isNotEmpty) {
            for (var call in _chatsData.records![existingMessageIndex].calls!) {
              call.callStatus = "missed";
              // Update users array from missed call event for correct logic
              if (missedCallData['users'] != null) {
                call.users =
                    (missedCallData['users'] as List)
                        .map(
                          (e) => e is int ? e : int.tryParse(e.toString()) ?? 0,
                        )
                        .toList();
              }
            }
            _logger.i(
              'Updated call status to "missed" and users array in calls array for message $messageId',
            );
          }

          _logger.i(
            'Updated existing current chat message $messageId with "callmissed" content',
          );
        } else {
          // Add new message at the beginning (most recent)
          _chatsData.records!.insert(
            0,
            Records(
              messageId: messageId,
              messageContent: "callmissed",
              messageType: "call",
              chatId: chatId,
              senderId: missedCallData['user_id'] ?? missedCallData['peer_id'],
              createdAt: DateTime.now().toIso8601String(),
              updatedAt: DateTime.now().toIso8601String(),
            ),
          );
          _logger.i(
            'Added new missed call message to current chat with ID $messageId',
          );
        }
      } else {
        // No message ID provided or no existing messages, create new message
        final newMessageId = messageId ?? DateTime.now().millisecondsSinceEpoch;
        _chatsData.records!.insert(
          0,
          Records(
            messageId: newMessageId,
            messageContent: "callmissed",
            messageType: "call",
            chatId: chatId,
            senderId: missedCallData['user_id'] ?? missedCallData['peer_id'],
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        _logger.i(
          'Added new missed call message to current chat with generated ID $newMessageId',
        );
      }

      // Notify listeners with updated current chat data
      _chatsStreamController.add(_chatsData);
      notifyListeners();

      _logger.i('Successfully updated current chat messages for missed call');
    } catch (e, stackTrace) {
      _logger.e('Error updating current chat with missed call message: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// Setup all call-related event listeners
  void _setupCallEventListeners() {
    _logger.i('Setting up call event listeners');

    // Handle call_ended events
    _socketService.on(_socketEvents.callEnded, (data) {
      _logger.d('Received call_ended event: $data');
      _handleCallEndedEvent(data);
    });

    // Handle user_joined events
    _socketService.on(_socketEvents.userJoinedCall, (data) {
      _logger.d('Received user_joined event: $data');
      _handleUserJoinedEvent(data);
    });

    // Handle receiving_call events (if this event exists)
    // Note: receiving_call might be handled differently - check if this event exists
    try {
      _socketService.on('receiving_call', (data) {
        _logger.d('Received receiving_call event: $data');
        _handleReceivingCallEvent(data);
      });
    } catch (e) {
      _logger.d('receiving_call event not available: $e');
    }

    _logger.i('Call event listeners setup completed');
  }

  /// Handle call_ended socket event
  void _handleCallEndedEvent(dynamic data) {
    try {
      _logger.d('Processing call_ended event: $data');

      if (data is! Map<String, dynamic>) {
        _logger.e('Invalid call_ended data format');
        return;
      }

      final int? chatId = data['chat_id'];
      final int? messageId = data['message_id'];

      if (chatId == null) {
        _logger.e('Missing chat_id in call_ended event');
        return;
      }

      _logger.i(
        'Processing call_ended for chat_id: $chatId, message_id: $messageId',
      );

      // Update the chat list to show "call ended" status
      _updateChatWithCallEvent(chatId, messageId, data, 'ended');

      // Also update current chat if user is viewing this chat
      _updateCurrentChatWithCallEvent(chatId, messageId, data, 'ended');
    } catch (e, stackTrace) {
      _logger.e('Error handling call_ended event: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// Handle user_joined socket event
  void _handleUserJoinedEvent(dynamic data) {
    try {
      _logger.d('Processing user_joined event: $data');

      if (data is! Map<String, dynamic>) {
        _logger.e('Invalid user_joined data format');
        return;
      }

      final callData = data['call'];
      if (callData == null) {
        _logger.e('Missing call data in user_joined event');
        return;
      }

      final int? chatId = callData['chat_id'];
      final int? messageId = callData['message_id'];

      if (chatId == null) {
        _logger.e('Missing chat_id in user_joined event');
        return;
      }

      _logger.i(
        'Processing user_joined for chat_id: $chatId, message_id: $messageId',
      );

      // Update the chat list to show "ongoing call" status
      _updateChatWithCallEvent(chatId, messageId, callData, 'ongoing');

      // Also update current chat if user is viewing this chat
      _updateCurrentChatWithCallEvent(chatId, messageId, callData, 'ongoing');
    } catch (e, stackTrace) {
      _logger.e('Error handling user_joined event: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// Handle receiving_call socket event
  void _handleReceivingCallEvent(dynamic data) {
    try {
      _logger.d('Processing receiving_call event: $data');

      if (data is! Map<String, dynamic>) {
        _logger.e('Invalid receiving_call data format');
        return;
      }

      final callData = data['call'];
      final chatData = data['chat'];

      if (callData == null || chatData == null) {
        _logger.e('Missing call or chat data in receiving_call event');
        return;
      }

      final int? chatId = chatData['chat_id'];
      final int? messageId = callData['message_id'];

      if (chatId == null) {
        _logger.e('Missing chat_id in receiving_call event');
        return;
      }

      _logger.i(
        'Processing receiving_call for chat_id: $chatId, message_id: $messageId',
      );

      // Update the chat list to show "ringing" status
      _updateChatWithCallEvent(chatId, messageId, callData, 'ringing');

      // Also update current chat if user is viewing this chat
      _updateCurrentChatWithCallEvent(chatId, messageId, callData, 'ringing');
    } catch (e, stackTrace) {
      _logger.e('Error handling receiving_call event: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// Generic method to update chat with call events
  void _updateChatWithCallEvent(
    int chatId,
    int? messageId,
    Map<String, dynamic> callData,
    String callStatus,
  ) {
    try {
      _logger.d(
        'UPDATE chatId:$chatId msgId:$messageId status:$callStatus preview:Updating...',
      );

      // Find the chat in the chat list
      final chatIndex = _chatListData.chats.indexWhere((chat) {
        final record =
            chat.records?.isNotEmpty == true ? chat.records!.first : null;
        return record?.chatId == chatId;
      });

      if (chatIndex == -1) {
        _logger.w(
          'Chat with ID $chatId not found in chat list for $callStatus event',
        );
        return;
      }

      final targetChat = _chatListData.chats[chatIndex];
      final chatRecord =
          targetChat.records?.isNotEmpty == true
              ? targetChat.records!.first
              : null;

      if (chatRecord?.messages?.isNotEmpty != true) {
        _logger.w('No messages found for chat ID $chatId');
        return;
      }

      // Find the message to update
      var messageToUpdate = chatRecord!.messages!.first;
      if (messageId != null) {
        final specificMessage =
            chatRecord.messages!
                .where((msg) => msg.messageId == messageId)
                .firstOrNull;
        if (specificMessage != null) {
          messageToUpdate = specificMessage;
        }
      }

      // CRITICAL FIX: Update both calls array AND message content for proper preview
      bool wasUpdated = false;

      // Update the call status in the calls array
      if (messageToUpdate.calls?.isNotEmpty == true) {
        for (var call in messageToUpdate.calls!) {
          call.callStatus = callStatus;
          // Update call duration if available
          if (callData['call_duration'] != null) {
            call.callDuration = callData['call_duration'];
          }
          // Update users array if available
          if (callData['users'] != null) {
            call.users =
                (callData['users'] as List)
                    .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
                    .toList();
          }
          if (callData['current_users'] != null) {
            call.currentUsers =
                (callData['current_users'] as List)
                    .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
                    .toList();
          }
        }
        wasUpdated = true;
        _logger.i(
          'Updated calls array with status "$callStatus" for message $messageId in chat $chatId',
        );
      }

      // CRITICAL FIX: Also update message content to reflect final call status
      // This prevents the preview from being stuck on "calling"
      if (messageToUpdate.messageType == 'call') {
        final oldContent = messageToUpdate.messageContent;

        // Map call status to appropriate message content
        switch (callStatus.toLowerCase()) {
          case 'ended':
            messageToUpdate.messageContent = 'ended';
            break;
          case 'missed':
            messageToUpdate.messageContent = 'callmissed';
            break;
          case 'ongoing':
            messageToUpdate.messageContent = 'ongoing';
            break;
          case 'ringing':
            messageToUpdate.messageContent = 'calling';
            break;
          default:
            messageToUpdate.messageContent = callStatus;
            break;
        }

        if (oldContent != messageToUpdate.messageContent) {
          wasUpdated = true;
          _logger.i(
            'Updated message content from "$oldContent" to "${messageToUpdate.messageContent}" for chat $chatId',
          );
        }
      }

      if (!wasUpdated) {
        _logger.w(
          'No calls array or message content found for call event update',
        );
        return;
      }

      // Update chat timestamp
      final currentTime = DateTime.now().toIso8601String();
      chatRecord.updatedAt = currentTime;
      messageToUpdate.updatedAt = currentTime;

      // Move chat to top if it's not already there
      if (chatIndex != 0) {
        final updatedChat = _chatListData.chats.removeAt(chatIndex);
        _chatListData.chats.insert(0, updatedChat);
        _logger.d('Moved chat $chatId to top of chat list');
      }

      // Notify listeners - this will trigger _buildMessagePreview to rebuild
      _chatListStreamController.add(_chatListData);
      notifyListeners();

      // Enhanced logging with preview information
      final callType = messageToUpdate.calls?.first.callType ?? 'voice';
      final duration = messageToUpdate.calls?.first.callDuration;
      final previewInfo =
          duration != null && duration > 0
              ? 'Ended $callType call (${_formatDurationForLog(duration)})'
              : '$callStatus $callType call';

      _logger.i(
        'UPDATE chatId:$chatId msgId:$messageId status:$callStatus type:$callType preview:"$previewInfo"',
      );

      _logger.i(
        'Successfully updated chat $chatId with call status: $callStatus',
      );
    } catch (e, stackTrace) {
      _logger.e('Error updating chat with call event: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// Helper method to format duration for logging
  String _formatDurationForLog(int? durationInSeconds) {
    if (durationInSeconds == null || durationInSeconds == 0) return '0s';
    if (durationInSeconds < 60) {
      return '${durationInSeconds}s';
    } else {
      final minutes = durationInSeconds ~/ 60;
      final seconds = durationInSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
  }

  /// Update current chat with call event if user is viewing this chat
  void _updateCurrentChatWithCallEvent(
    int chatId,
    int? messageId,
    Map<String, dynamic> callData,
    String callStatus,
  ) {
    try {
      // Check if user is currently viewing this chat
      if (_currentChatId == null || _currentChatId != chatId) {
        return;
      }

      if (_chatsData.records?.isNotEmpty != true) {
        return;
      }

      // Find and update the message in current chat
      var messageToUpdate = _chatsData.records!.first;
      if (messageId != null) {
        final specificMessage =
            _chatsData.records!
                .where((msg) => msg.messageId == messageId)
                .firstOrNull;
        if (specificMessage != null) {
          messageToUpdate = specificMessage;
        }
      }

      // Update call status
      if (messageToUpdate.calls?.isNotEmpty == true) {
        for (var call in messageToUpdate.calls!) {
          call.callStatus = callStatus;
          if (callData['call_duration'] != null) {
            call.callDuration = callData['call_duration'];
          }
          if (callData['users'] != null) {
            call.users =
                (callData['users'] as List)
                    .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
                    .toList();
          }
        }
        _logger.i('Updated current chat message call status to: $callStatus');
      }

      // Notify listeners
      _chatsStreamController.add(_chatsData);
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating current chat with call event: $e');
      _logger.e('Stack trace: $stackTrace');
    }
  }

  /// ✅ NEW: Reset method for logout scenarios (keeps streams alive)
  void reset() {
    _logger.d('Resetting SocketEventController to clean state');

    try {
      // Reset initialization flag
      _isInitialized = false;
      _isConnected = false;

      // ✅ CRITICAL FIX: Clear ALL data structures to prevent old user data
      _chatListData = chatlist.ChatListModel(chats: []);
      _chatsData = ChatsModel();
      _onlineUsersData = OnlineUsersModel(onlineUsers: []);
      _typingData = TypingModel();
      _blockUpdatesData = BlockUpdatesModel();
      _logger.d(
        '✅ Cleared all data models (chatList, chats, onlineUsers, etc.)',
      );

      // Clear all collections but keep streams alive
      _recentlyProcessedMessages.clear();
      _userTypingStatus.clear();
      _chatTypingStatus.clear();
      _seenMessages.clear();
      _pendingMessages.clear(); // ✅ Clear pending messages queue
      _emissionStats.clear(); // ✅ Clear emission stats
      _logger.d('✅ Cleared all tracking collections');

      // Reset chat state
      _resetChatState();
      _resetAllLoadingStates();

      // Clear current chat context
      _currentChatId = null;
      _currentUserId = null;
      _currentTypingUserId = null;
      _activeChatScreenId = null;
      _pendingDeleteMessageId = null;
      _pendingDeleteChatId = null;
      _isPendingDeleteForMe = false;
      _logger.d('✅ Cleared all context and tracking variables');

      // ✅ IMPORTANT: Clear stream controllers by emitting empty data
      // This ensures UI components receive fresh empty state
      _chatListStreamController.add(_chatListData);
      _chatsStreamController.add(_chatsData);
      _onlineUsersStreamController.add(_onlineUsersData);
      _typingStreamController.add(_typingData);
      _blockUpdatesStreamController.add(_blockUpdatesData);
      _logger.d('✅ Emitted empty state to all streams');

      _logger.d(
        'SocketEventController reset completed - ALL old user data cleared, ready for fresh initialization',
      );
    } catch (e) {
      _logger.e('Error during SocketEventController reset', e);
    }
  }

  @override
  void dispose() {
    _logger.d('Disposing SocketEventController');

    // Close all stream controllers
    _chatListStreamController.close();
    _chatsStreamController.close();
    _chatIdsStreamController.close();
    _onlineUsersStreamController.close();
    _typingStreamController.close();
    _blockUpdatesStreamController.close();
    _pinUnpinStreamController.close();
    _newMessageStreamController.close();

    // Clear collections
    _recentlyProcessedMessages.clear();
    _userTypingStatus.clear();
    _chatTypingStatus.clear();
    _seenMessages.clear();

    super.dispose();
  }
}
