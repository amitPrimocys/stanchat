import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/core/services/socket/socket_event_controller.dart';
import 'package:whoxa/dependency_injection.dart';
import 'package:whoxa/featuers/chat/data/blocked_user_model.dart';
import 'package:whoxa/featuers/chat/data/chat_ids_model.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/provider/archive_chat_provider.dart';
import 'package:whoxa/featuers/chat/data/online_user_model.dart';
import 'package:whoxa/featuers/chat/data/typing_model.dart';
import 'package:whoxa/featuers/chat/data/block_updates_model.dart';
import 'package:whoxa/featuers/chat/group/provider/group_provider.dart';
import 'package:whoxa/featuers/chat/repository/chat_repository.dart';
import 'package:whoxa/featuers/chat/utils/message_utils.dart';
import 'package:whoxa/featuers/chat/utils/chat_date_grouper.dart';
import 'package:whoxa/featuers/chat/utils/chat_cache_manager.dart';
import 'package:whoxa/utils/enums.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:whoxa/widgets/global.dart';

class ChatProvider with ChangeNotifier {
  bool _isScreenActive = false;
  bool get isScreenActive => _isScreenActive;

  // ✅ NEW: Track seen messages to prevent duplicate emissions
  final Set<int> _processedSeenMessageIds = <int>{};

  // ✅ NEW: Track recently cleared chats to prevent reload
  final Set<int> _recentlyClearedChats = <int>{};

  void setIsScreenActive(bool value) {
    if (_isScreenActive != value) {
      _isScreenActive = value;
      notifyListeners();
    }
  }

  bool _isUserOnlineFromApi = false;
  bool get isUserOnlineFromApi => _isUserOnlineFromApi;

  void setIsUserOnlineFromApi(bool value) {
    if (_isUserOnlineFromApi != value) {
      _isUserOnlineFromApi = value;
      notifyListeners();
    }
  }

  String? _lastSeenFromApi;
  String? get lastSeenFromApi => _lastSeenFromApi;

  void setLastSeenFromApi(String? value) {
    if (_lastSeenFromApi != value) {
      _lastSeenFromApi = value;
      notifyListeners();
    }
  }

  bool _isLoadingOnlineStatus = false;
  bool get isLoadingOnlineStatus => _isLoadingOnlineStatus;

  void setIsLoadingOnlineStatus(bool value) {
    if (_isLoadingOnlineStatus != value) {
      _isLoadingOnlineStatus = value;
      notifyListeners();
    }
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void setErrorMessage(String? value) {
    if (_errorMessage != value) {
      _errorMessage = value;
      notifyListeners();
    }
  }

  bool _hasError = false;
  bool get hasError => _hasError;

  void setHasError(bool value) {
    if (_hasError != value) {
      _hasError = value;
      notifyListeners();
    }
  }

  bool _isLoadingCurrentUser = false;
  bool get isLoadingCurrentUser => _isLoadingCurrentUser;

  void setIsLoadingCurrentUser(bool value) {
    if (_isLoadingCurrentUser != value) {
      _isLoadingCurrentUser = value;
      notifyListeners();
    }
  }

  bool _isInitializingOfChat = false;
  bool get isInitializingOfChat => _isInitializingOfChat;

  void setIsInitializingOfChat(bool value) {
    if (_isInitializingOfChat != value) {
      _isInitializingOfChat = value;
      notifyListeners();
    }
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  void setIsInitialized(bool value) {
    if (_isInitialized != value) {
      _isInitialized = value;
      notifyListeners();
    }
  }

  bool _isDisposedOfChat = false;
  bool get isDisposedOfChat => _isDisposedOfChat;

  void setIsDisposedOfChat(bool value) {
    if (_isDisposedOfChat != value) {
      _isDisposedOfChat = value;
      // Skip notifyListeners to avoid widget tree lock during disposal
    }
  }

  bool _hasCachedData = false;
  bool get hasCachedData => _hasCachedData;

  void setHasCachedData(bool value) {
    if (_hasCachedData != value) {
      _hasCachedData = value;
      notifyListeners();
    }
  }

  void resetAll() {
    debugPrint("Reset Calls");
    setIsScreenActive(false);
    setIsUserOnlineFromApi(false);
    setLastSeenFromApi(null);
    setIsLoadingOnlineStatus(false);
    setErrorMessage(null);
    setHasError(false);
    setIsLoadingCurrentUser(false);
    setIsInitializingOfChat(false);
    setIsInitialized(false);
    setIsDisposedOfChat(false);
    setHasCachedData(false);
  }

  void initOfUniversal({
    required BuildContext context,
    required int? chatId,
    required int? userId,
    required bool isGroupChat,
  }) {
    // 🚀 PERFORMANCE: Check cache immediately to prevent flicker
    checkCacheAvailability(chatId ?? 0, userId ?? 0);

    // Initialize the chat screen
    initializeScreen(
      context: context,
      chatId: chatId ?? 0,
      userId: userId ?? 0,
      isGroupChat: isGroupChat,
    );

    // Initialize cache for this chat
    initializeCacheForChat(chatId: chatId ?? 0, userId: userId ?? 0);

    // Try to load cached data for faster initial display
    loadCachedDataIfAvailable();

    // Mark screen as active
    setScreenActive(true, chatId, userId);
  }

  /// 🚀 PERFORMANCE: Check cache synchronously to prevent loading flicker
  void checkCacheAvailability(int? chatId, int? userId) {
    try {
      String? chatIdString;

      if (chatId != null && chatId > 0) {
        // Existing chat/group chat
        chatIdString = chatId.toString();
        _logger.d("🔍 CACHE CHECK: Group/existing chat - ID: $chatIdString");
      } else if (userId != null && userId > 0) {
        // Individual chat using userId
        chatIdString = 'user_$userId';
        _logger.d("🔍 CACHE CHECK: Individual chat - Peer ID: $userId");
      }

      if (chatIdString != null) {
        _hasCachedData = ChatCacheManager.hasPage(chatIdString, 1);
        _logger.d(
          "🎯 CACHE CHECK: Chat $chatIdString has cached data: $_hasCachedData",
        );

        // If we have cache, we can skip loading indicators
        if (_hasCachedData) {
          _logger.d(
            "⚡ PERFORMANCE: Cache detected - will prevent loading flicker",
          );
        }
      } else {
        _logger.w("⚠️ CACHE CHECK: Cannot determine chat ID for cache check");
        setHasCachedData(false);
      }
    } catch (e) {
      _logger.e("❌ Error checking cache availability: $e");
      setHasCachedData(false);
    }
  }

  Future<void> _loadCurrentUserIdForChat() async {
    try {
      // ✅ Set loading to true at start
      if (!_isDisposedOfChat) {
        setIsLoadingCurrentUser(true);
      }

      _currentUserId = await SecurePrefs.getString(SecureStorageKeys.USERID);
      _logger.d("Current user ID loaded: $_currentUserId");

      if (_currentUserId == null || _currentUserId!.isEmpty) {
        throw Exception("User ID is null or empty");
      }
    } catch (e) {
      _logger.e("Error loading current user ID: $e");
      rethrow;
    } finally {
      // ✅ Always set loading to false regardless of success or failure
      if (!_isDisposedOfChat) {
        setIsLoadingCurrentUser(false);
      }
      setIsLoadingCurrentUser(false);
    }
  }

  /// Load cached data if available for faster initial display
  Future<void> loadCachedDataIfAvailable() async {
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
          // if (!mounted) return;

          // Create ChatsModel from cached data
          final cachedChatsModel = ChatCacheManager.createChatModelFromCache(
            cachedMessages,
            firstPage,
            1, // Assume at least 1 page for now
          );

          // Set the cached data in the provider to display immediately
          setCachedChatsData(cachedChatsModel);

          _logger.d('✅ Cached data loaded into ChatProvider successfully');
          ChatCacheManager.logCacheStats(chatId);

          // Trigger a rebuild to show cached data
          setHasCachedData(true);
        }
      } else {
        _logger.d('📭 No cached data available for chat $chatId');
      }
    } catch (e) {
      _logger.e('❌ Error loading cached data: $e');
    }
  }

  void setScreenActive(bool isActive, int? chatId, int? userId) {
    if (_isDisposedOfChat) return;

    setIsScreenActive(isActive);

    _logger.d(
      'Setting OneToOneChat screen active: $isActive, chatId: $chatId, userId: $userId',
    );

    setChatScreenActive(chatId ?? 0, userId ?? 0, isActive: isActive);

    if (!isActive) {
      _logger.d('🚫 Chat screen deactivated - should stop auto-mark seen');
    }

    if (isActive && chatId != null && chatId > 0) {
      // Check block status when screen becomes active
      // First refresh the data to ensure we have the latest state
      // Block status is now handled via Provider Consumer pattern - no manual checks needed

      Future.delayed(Duration(milliseconds: 1000), () {
        if (!_isDisposed &&
            _isScreenActive &&
            isChatScreenActive &&
            isAppInForeground) {
          _logger.d('📱 Screen is fully active, marking messages as seen');
          markChatMessagesAsSeen(chatId);
        }
      });
    }
  }

  /// Get current chat ID for caching
  String? _getCurrentChatId({int? chatId, int? userId}) {
    if (chatId != null) {
      return chatId.toString();
    } else if (userId != null) {
      return 'user_$userId';
    }
    return null;
  }

  /// Initialize cache for current chat
  Future<void> initializeCacheForChat({int? chatId, int? userId}) async {
    try {
      final chatIdString = _getCurrentChatId(chatId: chatId, userId: userId);
      if (chatIdString != null) {
        await ChatCacheManager.initializeChat(chatIdString);
        _logger.d('🗄️ Cache initialized for chat: $chatIdString');
      }
      notifyListeners();
    } catch (e) {
      _logger.e('❌ Error initializing cache: $e');
    }
  }

  Future<void> initializeScreen({
    int? chatId,
    int? userId,
    bool isGroupChat = false,
    required BuildContext context,
  }) async {
    if (_isDisposedOfChat) return;

    try {
      _logger.d("🚀 Starting screen initialization");
      // setIsInitializingOfChat(true);
      _isInitializingOfChat = true;
      notifyListeners();
      if (isGroupChat) {
        debugPrint(
          "Loading group members for chatId: $chatId and for group !!!",
        );

        loadGroupMembers(context: context, chatId: chatId, userId: 0);
      }

      await _loadCurrentUserIdForChat();
      if (_isDisposedOfChat) return;

      _logger.d(
        "📝 Setting current chat context: chatId=$chatId, userId=$userId",
      );
      setCurrentChat(chatId ?? 0, userId ?? 0);

      await Future.delayed(Duration(milliseconds: 100));
      if (_isDisposedOfChat) return;

      _logger.d("📨 Loading chat messages");
      await loadChatMessages(
        chatId: chatId ?? 0,
        peerId: userId ?? 0,
        clearExisting: true,
      );

      if (_isDisposedOfChat) return;

      await Future.delayed(Duration(milliseconds: 500));
      if (_isDisposedOfChat) return;

      await checkUserOnlineStatusFromApi();

      // Load group members for group chats
      if (isGroupChat) {
        debugPrint("Loading group members for chatId: $chatId and for group");

        if (!context.mounted) return;
        await loadGroupMembers(
          context: context,
          chatId: chatId,
          userId: userId,
        );
      }

      setIsInitialized(true);
      // setIsInitializingOfChat(false);
      _isInitializingOfChat = false;
      notifyListeners();
      setHasError(false);
      setErrorMessage(null);

      _logger.d("✅ Screen initialization completed successfully");
      _debugPinnedMessagesState();
    } catch (e, stackTrace) {
      _logger.e("❌ Error during initialization: $e");
      _logger.e("📍 Stack trace: $stackTrace");

      setHasError(true);
      setErrorMessage(e.toString());
      // setIsInitializingOfChat(false);
      _isInitializingOfChat = false;
      notifyListeners();
    }
  }

  void _debugPinnedMessagesState() {
    final pinnedCount = pinnedMessagesData.records?.length ?? 0;
    final chatCount = chatsData.records?.length ?? 0;

    _logger.d(
      "🔍 DEBUG - Chat messages: $chatCount, Pinned messages: $pinnedCount",
    );

    if (pinnedCount > 0) {
      _logger.d("✅ Pinned messages available after initialization:");
      for (var msg in pinnedMessagesData.records!) {
        _logger.d("  - ${msg.messageId}: ${msg.messageContent}");
      }
    } else {
      _logger.d("⚠️ No pinned messages found after initialization");

      if (chatCount > 0) {
        final pinnedInMain =
            chatsData.records!.where((r) => r.pinned == true).toList();
        if (pinnedInMain.isNotEmpty) {
          _logger.w(
            "🚨 Found ${pinnedInMain.length} pinned messages in main chat data but not in pinned collection!",
          );
        }
      }
    }
  }

  Future<void> checkUserOnlineStatusFromApi({int? userId}) async {
    if (_isDisposedOfChat) return;

    try {
      setIsLoadingOnlineStatus(true);

      final response = await checkUserOnlineStatus(userId ?? 0);

      if (!_isDisposedOfChat && response != null) {
        setIsLoadingOnlineStatus(response['isOnline'] ?? false);
        setLastSeenFromApi(response['udatedAt']);
        setIsLoadingOnlineStatus(false);

        _logger.d(
          "User $userId online status from API: $_isUserOnlineFromApi, lastSeen: $_lastSeenFromApi",
        );
      } else {
        if (!_isDisposedOfChat) {
          setIsLoadingOnlineStatus(false);
        }
      }
    } catch (e) {
      _logger.e("Error checking user online status from API: $e");
      if (!_isDisposedOfChat) {
        setIsLoadingOnlineStatus(false);
      }
    }
  }

  Future<void> loadGroupMembers({
    int? chatId,
    int? userId,
    bool isGroupChat = false,
    required BuildContext context,
  }) async {
    if (_isDisposedOfChat || !isGroupChat) return;

    try {
      _logger.d("👥 Loading group members for chatId: $chatId");
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      await groupProvider.getGroupMembers(chatId: chatId ?? 0);
      _logger.d("✅ Group members loaded successfully");
    } catch (e) {
      _logger.e("❌ Error loading group members: $e");
      // Don't throw error as this is not critical for basic chat functionality
    }
  }

  // Dependencies
  // ignore: unused_field
  final ApiClient _apiClient;
  final SocketEventController _socketEventController;
  final ChatRepository _chatRepository;
  ChatRepository get chatRepository => _chatRepository;
  SocketEventController get socketEventController => _socketEventController;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule('ChatProvider');

  // State variables
  ChatListModel _chatListData = ChatListModel(chats: []);
  chats.ChatsModel _chatsData = chats.ChatsModel();
  ChatIdsModel _chatIdsData = ChatIdsModel();
  OnlineUsersModel _onlineUsersData = OnlineUsersModel();
  TypingModel _typingData = TypingModel();

  // ✅ NEW: Chat list pagination state
  int _chatListCurrentPage = 1;
  int _chatListTotalPages = 1;
  bool _isChatListPaginationLoading = false;
  bool _hasChatListMoreData = true;
  final int _chatListPageSize = 20;

  // ✅ NEW: Pinned messages state using your existing ChatsModel
  chats.ChatsModel _pinnedMessagesData = chats.ChatsModel();
  bool _isPinnedMessagesExpanded = false;
  int? _highlightedMessageId;
  Timer? _highlightTimer;
  bool _isSearchingForMessage = false;
  int? _targetMessageId;
  Timer? _searchTimeoutTimer;
  bool _isMessageFound = false;

  bool _isSendingMessage = false;
  bool _isShowAttachments = false;
  bool _isInitializing = false;
  bool _isDisposed = false;

  String? _error;
  String? _apiErrorMessage;
  // Current chat data
  ChatIds _currentChatData = ChatIds();
  // File storage
  List<File>? _shareImage;
  List<File>? _shareDocument;
  List<File>? _shareVideo;
  File? _shareVoice;

  String _shareVideoThumbnail = "";

  // Stream subscriptions
  StreamSubscription? _chatListSubscription;
  StreamSubscription? _chatsSubscription;
  StreamSubscription? _chatIdsSubscription;
  StreamSubscription? _onlineUsersSubscription;

  StreamSubscription? _typingSubscription;
  StreamSubscription? _blockUpdatesSubscription;
  StreamSubscription? _pinUnpinSubscription;
  StreamSubscription? _starUnstarSubscription;

  String? _currentUserId;
  // Debouncing and throttling
  Timer? _notifyTimer;
  bool _shouldNotify = false;
  // Track last update to prevent duplicate notifications
  // ignore: unused_field
  String? _lastChatsDataHash;

  // ✅ NEW: Reply state management
  chats.Records? _replyToMessage;

  bool _isReplyMode = false;
  // ✅ NEW: separate pagination loading state
  bool _isPaginationLoading = false;

  // ✅ NEW: Date grouping state
  Map<String, List<chats.Records>> _groupedMessages = {};
  chats.ChatWrapperModel? _chatWrapper;

  // Block functionality state
  final List<BlockedUserRecord> _blockedUsers = [];
  bool _isBlockListLoading = false;
  int _blockListCurrentPage = 1;
  bool _hasMoreBlockedUsers = true;

  bool _isCountLoading = false;
  int _blocklistCount = 0;
  int _starredCount = 0;
  int _notificationCount = 0;
  String _urlTitle = "";
  String _urlDescri = "";
  String _urlImage = "";
  // ✅ NEW: Chat List Pagination Getters
  int get chatListCurrentPage => _chatListCurrentPage;
  int get chatListTotalPages => _chatListTotalPages;
  bool get isChatListPaginationLoading => _isChatListPaginationLoading;
  bool get hasChatListMoreData => _hasChatListMoreData;
  String get urlTitle => _urlTitle;
  String get urlDescri => _urlDescri;
  String get urlImage => _urlImage;

  chats.ChatsModel get starredMessagesData =>
      _socketEventController.starredMessagesData;

  // Constructor with dependency injection
  ChatProvider(
    this._apiClient,
    this._socketEventController,
    this._chatRepository,
  ) {
    _logger.i('Creating ChatProvider with separated API calls');
    _initializeSubscriptions();
  }

  ChatIdsModel get chatIdsData => _chatIdsData;
  // ✅ NEW: Archive filtering state
  final Set<int> _archivedChatIds = <int>{};

  // Getters
  ChatListModel get chatListData => _chatListData;

  // ✅ NEW: Archive filtering methods
  void addArchivedChatId(int chatId) {
    _archivedChatIds.add(chatId);
    _filterArchivedChatsFromList();
  }

  void removeArchivedChatId(int chatId) {
    _archivedChatIds.remove(chatId);

    // ✅ FIXED: When a chat is unarchived, we need to ensure it appears immediately
    // Instead of just refreshing (which only loads page 1), we'll request a full refresh
    // and temporarily add the unarchived chat to ensure immediate visibility
    _handleUnarchivedChat(chatId);
  }

  /// Handle when a chat is unarchived to ensure immediate visibility
  Future<void> _handleUnarchivedChat(int chatId) async {
    try {
      _logger.d('🔓 Handling unarchived chat: $chatId');

      // First, try to get fresh data from the server with larger page size
      // This increases the chance that the unarchived chat will be in the first page
      _logger.d(
        '🔄 Requesting chat list with larger page size for unarchived chat',
      );

      // Reset pagination and request with larger page size to catch the unarchived chat
      resetChatListPagination();
      await _socketEventController.emitChatList(
        page: 1,
        pageSize: _chatListPageSize,
      ); // Use consistent page size

      // Wait a bit longer for the socket response to be processed
      await Future.delayed(const Duration(milliseconds: 800));

      // Check if the chat is now in our current list
      bool chatFound = _chatListData.chats.any(
        (chat) =>
            chat.records?.any((record) => record.chatId == chatId) == true,
      );

      if (!chatFound) {
        _logger.w(
          '⚠️ Unarchived chat $chatId still not found, trying with even larger page size',
        );

        // Last resort: request with very large page size
        await _socketEventController.emitChatList(
          page: 1,
          pageSize: _chatListPageSize * 2,
        );
        await Future.delayed(const Duration(milliseconds: 500));

        // Check again
        chatFound = _chatListData.chats.any(
          (chat) =>
              chat.records?.any((record) => record.chatId == chatId) == true,
        );

        if (chatFound) {
          _logger.d('✅ Unarchived chat $chatId found after extended search');
        } else {
          _logger.e(
            '❌ Unarchived chat $chatId not found even after extended search',
          );
        }
      } else {
        _logger.d('✅ Unarchived chat $chatId found in current list');
      }

      // Always notify listeners to update UI
      _scheduleNotification();
    } catch (e) {
      _logger.e('❌ Error handling unarchived chat: $e');
      // Fallback: try regular refresh as last resort
      try {
        await refreshChatList();
      } catch (fallbackError) {
        _logger.e('❌ Fallback refresh also failed: $fallbackError');
      }
      _scheduleNotification();
    }
  }

  void _filterArchivedChatsFromList({bool shouldSort = true}) {
    if (_archivedChatIds.isEmpty) return;

    final filteredChats =
        _chatListData.chats.where((chat) {
          if (chat.records?.isNotEmpty == true) {
            final chatId = chat.records!.first.chatId;
            return chatId != null && !_archivedChatIds.contains(chatId);
          }
          return true;
        }).toList();

    _chatListData = ChatListModel(chats: filteredChats);

    // Only sort if requested (avoid during pagination to maintain server order)
    if (shouldSort) {
      _sortChatList();
    }
    notifyListeners();
  }

  chats.ChatsModel get chatsData => _chatsData;
  ChatIds get currentChatData => _currentChatData;

  // ✅ NEW: Date grouping getters
  Map<String, List<chats.Records>> get groupedMessages => _groupedMessages;
  chats.ChatWrapperModel? get chatWrapper => _chatWrapper;

  // ✅ NEW: Date grouping methods
  void _regroupMessages() {
    if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
      _groupedMessages = ChatDateGrouper.groupMessagesByDate(
        _chatsData.records!,
      );
      _chatWrapper = chats.ChatWrapperModel(
        messageList: _chatsData,
        pinnedMessages: _pinnedMessagesData,
        starredMessages: starredMessagesData,
      );
    } else {
      _groupedMessages = {};
      _chatWrapper = null;
    }
  }

  void addNewMessage(chats.Records message) {
    if (_chatsData.records != null) {
      _chatsData.records!.add(message);
      _regroupMessages();
      notifyListeners();
    }
  }

  void addMessages(List<chats.Records> newMessages) {
    if (_chatsData.records != null) {
      _chatsData.records!.addAll(newMessages);
      _regroupMessages();
      notifyListeners();
    }
  }

  String? get error => _error ?? _socketEventController.lastError;
  String? get apiErrorMessage => _apiErrorMessage;

  void clearApiErrorMessage() {
    _apiErrorMessage = null;
  }

  bool get hasMoreMessages => _socketEventController.hasMoreMessages;

  int? get highlightedMessageId => _highlightedMessageId;

  bool get isChatListLoading => _socketEventController.isChatListLoading;
  bool get isChatLoading => _socketEventController.isChatLoading;
  bool get isInitializing => _isInitializing;
  bool get isMessageFound => _isMessageFound;
  bool get isPaginationLoading => _isPaginationLoading;

  bool get isPinnedMessagesExpanded => _isPinnedMessagesExpanded;
  bool get isRefreshing => _socketEventController.isRefreshing;

  bool get isReplyMode => _isReplyMode;
  bool get isSearchingForMessage => _isSearchingForMessage;
  bool get isSendingMessage => _isSendingMessage;
  bool get isShowAttachments => _isShowAttachments;
  OnlineUsersModel get onlineUsersData => _onlineUsersData;
  // ✅ NEW: Pinned messages getters
  chats.ChatsModel get pinnedMessagesData => _pinnedMessagesData;
  // ✅ NEW: Reply getters
  chats.Records? get replyToMessage => _replyToMessage;
  int? get targetMessageId => _targetMessageId;
  TypingModel get typingData => _typingData;

  // Block functionality getters
  List<BlockedUserRecord> get blockedUsers => _blockedUsers;
  bool get isBlockListLoading => _isBlockListLoading;
  bool get hasMoreBlockedUsers => _hasMoreBlockedUsers;
  String? get currentUserId => _currentUserId;

  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
    notifyListeners();
  }

  bool get isCountLoading => _isCountLoading;
  int get starredCount => _starredCount;
  int get blocklistCount => _blocklistCount;
  int get notificationCount => _notificationCount;

  bool get isChatScreenActive => _socketEventController.isChatScreenActive;
  bool get isAppInForeground => _socketEventController.isAppInForeground;
  String? get activeChatScreenId => _socketEventController.activeChatScreenId;

  void notify() {
    notifyListeners();
  }

  void setAppForegroundState(bool isInForeground) {
    _socketEventController.setAppForegroundState(isInForeground);
  }

  void setChatScreenActive(int chatId, int userId, {bool isActive = true}) {
    _socketEventController.setChatScreenActive(
      chatId,
      userId,
      isActive: isActive,
    );
  }

  /// Check if current user can delete a message
  bool canDeleteMessage(chats.Records message) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      _logger.w('Current user ID not available for delete permission check');
      return false;
    }

    // Convert current user ID to int for comparison
    final currentUserIdInt = int.tryParse(_currentUserId!) ?? 0;

    // Only the sender can delete their own messages
    return message.senderId == currentUserIdInt;
  }

  /// Check if current user can delete message for everyone
  bool canDeleteMessageForEveryone(chats.Records message) {
    if (!canDeleteMessage(message)) return false;

    // Additional logic can be added here, such as:
    // - Time limit for deletion (e.g., only within 24 hours)
    // - Admin privileges
    // - Group chat rules

    // For now, any user can delete their own message for everyone
    return true;
  }

  ///pin unpin
  // Check if current user can pin/unpin a message
  bool canPinUnpinMessage(chats.Records message) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      _logger.w('Current user ID not available for permission check');
      return false;
    }

    // Convert current user ID to int for comparison
    final currentUserIdInt = int.tryParse(_currentUserId!) ?? 0;

    if (message.pinned == true) {
      // For unpinning: Only the user who pinned the message can unpin it
      // You might need to add a 'pinnedBy' field to your message model
      // For now, we'll allow the message sender to unpin
      return message.senderId == currentUserIdInt;
    } else {
      // For pinning: Any user can pin a message (or implement your own logic)
      return true;
    }
  }

  ///pin unpin
  // Check if current user can pin/unpin a message
  bool canStarUnStarMessage(chats.Records message) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      _logger.w('Current user ID not available for permission check');
      return false;
    }

    // Convert current user ID to int for comparison
    final currentUserIdInt = int.tryParse(_currentUserId!) ?? 0;

    if (message.stared == true) {
      // For unpinning: Only the user who pinned the message can unpin it
      // You might need to add a 'pinnedBy' field to your message model
      // For now, we'll allow the message sender to unpin
      return message.senderId == currentUserIdInt;
    } else {
      // For pinning: Any user can pin a message (or implement your own logic)
      return true;
    }
  }

  // ✅ UPDATED: Check user online status using ChatRepository
  Future<Map<String, dynamic>?> checkUserOnlineStatus(int userId) async {
    if (_isDisposed) return null;

    try {
      _logger.d('Checking online status for user: $userId via ChatRepository');
      return await _chatRepository.checkUserOnlineStatus(userId);
    } catch (e) {
      _logger.e('Error checking user online status: $e');
      return null;
    }
  }

  // Clear current chat data
  void clearCurrentChat() {
    if (_isDisposed) return;

    _currentChatData = ChatIds();
    _chatsData = chats.ChatsModel();
    _pinnedMessagesData = chats.ChatsModel();
    _isPinnedMessagesExpanded = false;
    _lastChatsDataHash = null;
    _regroupMessages();
    clearHighlight();
    _socketEventController.setCurrentChat(0, 0);
    _scheduleNotification();
  }

  // 🚀 CACHE: Set cached chat data for immediate display
  void setCachedChatsData(chats.ChatsModel cachedData) {
    if (_isDisposed) return;

    _logger.d(
      '📱 Setting cached chat data with ${cachedData.records?.length ?? 0} messages',
    );
    _chatsData = cachedData;

    // Extract pinned messages from cached data
    _extractPinnedMessages(cachedData);

    // Regroup messages by date
    _regroupMessages();

    // Trigger UI update
    _scheduleNotification();
  }

  // Clear error message
  void clearError() {
    if (_isDisposed) return;
    _error = null;
    _socketEventController.clearError();
    _scheduleNotification();
  }

  // ✅ NEW: Clear highlight
  void clearHighlight() {
    _highlightTimer?.cancel();
    _highlightedMessageId = null;
    _scheduleNotification();
  }

  void clearReply() {
    _replyToMessage = null;
    _isReplyMode = false;
    _scheduleNotification();
  }

  // Connect to socket
  Future<bool> connect() async {
    if (_isDisposed) return false;

    try {
      return await _socketEventController.connect();
    } catch (e) {
      _error = "Failed to connect: ${e.toString()}";
      _scheduleNotification();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE SEEN STATUS METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mark a specific message as seen
  // Future<void> markMessageAsSeen(int chatId, int messageId) async {
  //   if (_isDisposed) return;

  //   try {
  //     _logger.d(
  //       'Marking message as seen - chatId: $chatId, messageId: $messageId',
  //     );

  //     // Emit via socket controller
  //     _socketEventController.emitMessageSeen(chatId, messageId);

  //     // Optional: Update local state immediately for better UX
  //     _updateLocalMessageSeenStatus(messageId);

  //     _logger.d('Message marked as seen successfully');
  //   } catch (e) {
  //     _error = "Failed to mark message as seen: ${e.toString()}";
  //     _logger.e('Error marking message as seen: $e');
  //     _scheduleNotification();
  //   }
  // }

  Future<void> markMessageAsSeen(int chatId, int messageId) async {
    if (_isDisposed) return;

    try {
      // Check if message is already seen to prevent duplicate processing
      if (_isMessageAlreadySeen(messageId)) {
        _logger.d('Message $messageId already seen - skipping mark as seen');
        return;
      }

      _logger.d(
        'Marking message as seen - chatId: $chatId, messageId: $messageId',
      );

      // Update local message seen status immediately (for UI feedback)
      _updateLocalMessageSeenStatus(messageId);

      // Emit via socket controller
      _socketEventController.emitMessageSeen(chatId, messageId);

      // Decrement unseen count in chat list
      final currentUnseenCount = getChatUnseenCount(chatId);
      if (currentUnseenCount > 0) {
        decrementChatUnseenCount(chatId, 1);
        _logger.d(
          'Decremented unseen count for chat $chatId after marking message $messageId as seen',
        );
      }

      _logger.d('Message marked as seen successfully');
    } catch (e) {
      _error = "Failed to mark message as seen: ${e.toString()}";
      _logger.e('Error marking message as seen: $e');
      _scheduleNotification();
    }
  }

  /// Check if a message is already seen to prevent duplicate processing
  bool _isMessageAlreadySeen(int messageId) {
    if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
      for (var message in _chatsData.records!) {
        if (message.messageId == messageId) {
          return message.messageSeenStatus == 'seen';
        }
      }
    }
    return false;
  }

  /// Update local message seen status (for immediate UI feedback)
  void _updateLocalMessageSeenStatus(int messageId) {
    if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
      for (var message in _chatsData.records!) {
        if (message.messageId == messageId) {
          message.messageSeenStatus = 'seen';
          _logger.d('Updated local message $messageId status to seen');
          break;
        }
      }
      _scheduleNotification();
    }
  }

  /// Update unseen count for a specific chat in the chat list
  void updateChatUnseenCount(int chatId, int newUnseenCount) {
    if (_isDisposed || _chatListData.chats.isEmpty) return;

    bool chatUpdated = false;

    for (int i = 0; i < _chatListData.chats.length; i++) {
      final chat = _chatListData.chats[i];

      // Check if this chat matches the chatId
      if (chat.records != null && chat.records!.isNotEmpty) {
        final chatRecord = chat.records!.first;

        if (chatRecord.chatId == chatId) {
          // Update the unseen count
          final oldUnseenCount = chatRecord.unseenCount ?? 0;
          chatRecord.unseenCount = newUnseenCount;

          _logger.d(
            'Updated chat $chatId unseen count: $oldUnseenCount → $newUnseenCount',
          );

          chatUpdated = true;
          break;
        }
      }
    }

    if (chatUpdated) {
      _scheduleNotification();
    } else {
      _logger.w('Chat $chatId not found in chat list for unseen count update');
    }
  }

  /// Decrement unseen count for a specific chat
  void decrementChatUnseenCount(int chatId, int decrementBy) {
    if (_isDisposed || _chatListData.chats.isEmpty || decrementBy <= 0) return;

    for (int i = 0; i < _chatListData.chats.length; i++) {
      final chat = _chatListData.chats[i];

      if (chat.records != null && chat.records!.isNotEmpty) {
        final chatRecord = chat.records!.first;

        if (chatRecord.chatId == chatId) {
          final currentCount = chatRecord.unseenCount ?? 0;
          final newCount = (currentCount - decrementBy).clamp(0, currentCount);

          if (currentCount != newCount) {
            chatRecord.unseenCount = newCount;

            _logger.d(
              'Decremented chat $chatId unseen count: $currentCount → $newCount',
            );

            _scheduleNotification();
          }
          break;
        }
      }
    }
  }

  /// Clear unseen count for a specific chat (set to 0)
  void clearChatUnseenCount(int chatId) {
    updateChatUnseenCount(chatId, 0);
  }

  /// Get current unseen count for a specific chat
  int getChatUnseenCount(int chatId) {
    if (_chatListData.chats.isEmpty) return 0;

    for (final chat in _chatListData.chats) {
      if (chat.records != null && chat.records!.isNotEmpty) {
        final chatRecord = chat.records!.first;

        if (chatRecord.chatId == chatId) {
          return chatRecord.unseenCount ?? 0;
        }
      }
    }

    return 0;
  }

  /// Auto-mark messages as seen when entering a chat
  // Future<void> markChatMessagesAsSeen(int chatId) async {
  //   if (_isDisposed || chatId <= 0) return;

  //   // ✅ CRITICAL: Only mark if ALL conditions are met
  //   if (!isChatScreenActive || !isAppInForeground) {
  //     _logger.d(
  //       'Skipping mark messages as seen - screen not active or app in background. '
  //       'screenActive: $isChatScreenActive, appForeground: $isAppInForeground',
  //     );
  //     return;
  //   }

  //   // ✅ ADDITIONAL CHECK: Ensure we're actually viewing the correct chat
  //   if (_currentChatData.chatId != chatId) {
  //     _logger.d(
  //       'Skipping mark messages as seen - chat ID mismatch. '
  //       'current: ${_currentChatData.chatId}, requested: $chatId',
  //     );
  //     return;
  //   }

  //   try {
  //     // Get current user ID
  //     final currentUserId = await _getCurrentUserId();
  //     if (currentUserId == null) {
  //       _logger.w(
  //         'Cannot mark messages as seen - current user ID not available',
  //       );
  //       return;
  //     }

  //     // ✅ ENHANCED: Find unread messages from OTHER users only
  //     final unreadMessages =
  //         _chatsData.records
  //             ?.where(
  //               (message) =>
  //                   message.senderId !=
  //                       currentUserId && // Only messages from other users
  //                   message.messageSeenStatus != 'seen' &&
  //                   message.messageId != null &&
  //                   message.deletedForEveryone != true,
  //             ) // Don't mark deleted messages
  //             .toList() ??
  //         [];

  //     if (unreadMessages.isNotEmpty) {
  //       _logger.d(
  //         'Marking ${unreadMessages.length} messages from OTHER users as seen '
  //         '(screen is active and app in foreground)',
  //       );

  //       // ✅ BATCH PROCESSING: Mark messages in smaller batches to avoid overwhelming the server
  //       const batchSize = 3;
  //       for (int i = 0; i < unreadMessages.length; i += batchSize) {
  //         // Check if conditions are still met before each batch
  //         if (!isChatScreenActive || !isAppInForeground || _isDisposed) {
  //           _logger.d('Conditions changed, stopping seen marking');
  //           break;
  //         }

  //         final batch = unreadMessages.skip(i).take(batchSize).toList();

  //         for (var message in batch) {
  //           // Final check before marking each message
  //           if (!isChatScreenActive || _isDisposed) {
  //             _logger.d('Screen became inactive, stopping seen marking');
  //             return;
  //           }

  //           _logger.d(
  //             'Marking message ${message.messageId} as seen '
  //             '(from user ${message.senderId}, current user $currentUserId)',
  //           );

  //           await markMessageAsSeen(chatId, message.messageId!);

  //           // Small delay between individual requests
  //           await Future.delayed(Duration(milliseconds: 150));
  //         }

  //         // Longer delay between batches
  //         if (i + batchSize < unreadMessages.length) {
  //           await Future.delayed(Duration(milliseconds: 300));
  //         }
  //       }

  //       _logger.i(
  //         'Successfully processed ${unreadMessages.length} unread messages from other users',
  //       );
  //     } else {
  //       _logger.d('No unread messages from other users to mark as seen');
  //     }
  //   } catch (e) {
  //     _logger.e('Error marking chat messages as seen: $e');
  //   }
  // }

  Future<void> markChatMessagesAsSeen(int chatId) async {
    if (_isDisposed || chatId <= 0) return;

    // ✅ CRITICAL: Only mark if ALL conditions are met
    if (!isChatScreenActive || !isAppInForeground) {
      _logger.d(
        'Skipping mark messages as seen - screen not active or app in background. '
        'screenActive: $isChatScreenActive, appForeground: $isAppInForeground',
      );
      return;
    }

    // ✅ ADDITIONAL CHECK: Ensure we're actually viewing the correct chat
    if (_currentChatData.chatId != chatId) {
      _logger.d(
        'Skipping mark messages as seen - chat ID mismatch. '
        'current: ${_currentChatData.chatId}, requested: $chatId',
      );
      return;
    }

    try {
      // Get current user ID
      final currentUserId = await _getCurrentUserId();
      if (currentUserId == null) {
        _logger.w(
          'Cannot mark messages as seen - current user ID not available',
        );
        return;
      }

      // ✅ ENHANCED: Find unread messages from OTHER users only
      final unreadMessages =
          _chatsData.records
              ?.where(
                (message) =>
                    message.senderId !=
                        currentUserId && // Only messages from other users
                    message.messageSeenStatus != 'seen' &&
                    message.messageId != null &&
                    message.deletedForEveryone !=
                        true, // Don't mark deleted messages
              )
              .toList() ??
          [];

      if (unreadMessages.isNotEmpty) {
        _logger.d(
          '🎯 BULK MARKING: Starting to mark ${unreadMessages.length} messages from OTHER users as seen '
          '(screen is active and app in foreground)',
        );

        // ✅ STRICT VALIDATION: Log all message IDs that should be marked
        final intendedMessageIds =
            unreadMessages
                .map((m) => m.messageId)
                .where((id) => id != null)
                .cast<int>()
                .toList();
        _logger.d(
          '📋 INTENDED EMISSIONS: ${intendedMessageIds.length} messages - IDs: $intendedMessageIds',
        );

        // ✅ NEW: Store initial unseen count for comparison
        final initialUnseenCount = getChatUnseenCount(chatId);
        int markedMessagesCount = 0;
        final List<int> successfullyMarkedIds = [];
        final List<int> failedToMarkIds = [];

        // ✅ BATCH PROCESSING: Mark messages in smaller batches
        const batchSize = 3;
        for (int i = 0; i < unreadMessages.length; i += batchSize) {
          // Check if conditions are still met before each batch
          if (!isChatScreenActive || !isAppInForeground || _isDisposed) {
            _logger.w(
              '⚠️ CONDITIONS CHANGED: Stopping seen marking - remaining ${unreadMessages.length - i} messages',
            );
            final remainingIds =
                unreadMessages.skip(i).map((m) => m.messageId).toList();
            failedToMarkIds.addAll(
              remainingIds.where((id) => id != null).cast<int>(),
            );
            break;
          }

          final batch = unreadMessages.skip(i).take(batchSize).toList();
          _logger.d(
            '📦 BATCH ${(i ~/ batchSize) + 1}: Processing ${batch.length} messages (${batch.map((m) => m.messageId).toList()})',
          );

          for (var message in batch) {
            // Final check before marking each message
            if (!isChatScreenActive || _isDisposed) {
              _logger.w(
                '❌ EARLY TERMINATION: Screen became inactive, stopping seen marking',
              );
              final remainingInBatch =
                  batch
                      .skip(batch.indexOf(message))
                      .map((m) => m.messageId)
                      .toList();
              failedToMarkIds.addAll(
                remainingInBatch.where((id) => id != null).cast<int>(),
              );
              break;
            }

            _logger.d(
              '🚀 INDIVIDUAL MARK: Marking message ${message.messageId} as seen '
              '(from user ${message.senderId}, current user $currentUserId)',
            );

            try {
              await markMessageAsSeen(chatId, message.messageId!);
              markedMessagesCount++;
              successfullyMarkedIds.add(message.messageId!);
              _logger.d(
                '✅ SUCCESS: Message ${message.messageId} marked successfully',
              );

              // ✅ NEW: Update unseen count immediately for better UX
              final currentUnseenCount = getChatUnseenCount(chatId);
              if (currentUnseenCount > 0) {
                updateChatUnseenCount(chatId, currentUnseenCount - 1);
              }
            } catch (e) {
              _logger.e(
                '❌ FAILED: Error marking message ${message.messageId} as seen: $e',
              );
              failedToMarkIds.add(message.messageId!);
            }

            // Small delay between individual requests
            await Future.delayed(Duration(milliseconds: 150));
          }

          // Longer delay between batches
          if (i + batchSize < unreadMessages.length) {
            await Future.delayed(Duration(milliseconds: 300));
          }
        }

        // ✅ STRICT VALIDATION REPORT
        _logger.i('📊 BULK MARKING REPORT:');
        _logger.i(
          '  - Intended to mark: ${intendedMessageIds.length} messages',
        );
        _logger.i(
          '  - Successfully marked: ${successfullyMarkedIds.length} messages',
        );
        _logger.i('  - Failed to mark: ${failedToMarkIds.length} messages');
        _logger.i(
          '  - Success rate: ${(successfullyMarkedIds.length / intendedMessageIds.length * 100).toStringAsFixed(1)}%',
        );
        _logger.i('  - Successful IDs: $successfullyMarkedIds');

        if (failedToMarkIds.isNotEmpty) {
          _logger.w('❌ FAILED IDs: $failedToMarkIds');
        }

        // ✅ CRITICAL CHECK: Verify the socket controller emission count
        final emissionStats = _socketEventController.getEmissionStats();
        _logger.i(
          '🔍 SOCKET EMISSION STATS: ${emissionStats['totalEmissions']} emissions tracked',
        );
        _logger.i(
          '🔍 EMITTED MESSAGE IDs: ${emissionStats['emittedMessageIds']}',
        );

        // ✅ STRICT ASSERTION: Log discrepancy if any
        if (successfullyMarkedIds.length != emissionStats['totalEmissions']) {
          _logger.e('🚨 DISCREPANCY DETECTED:');
          _logger.e('  - ChatProvider marked: ${successfullyMarkedIds.length}');
          _logger.e(
            '  - SocketController emitted: ${emissionStats['totalEmissions']}',
          );
          _logger.e('  - This explains the 7 vs 4 issue!');
        }

        // ✅ NEW: Final unseen count update based on marked messages
        if (markedMessagesCount > 0) {
          final finalUnseenCount = (initialUnseenCount - markedMessagesCount)
              .clamp(0, initialUnseenCount);
          updateChatUnseenCount(chatId, finalUnseenCount);

          _logger.i(
            'Successfully marked $markedMessagesCount messages as seen. '
            'Unseen count updated: $initialUnseenCount → $finalUnseenCount',
          );

          // ✅ FIX: Also clear archived chat badge count if this chat is archived
          _clearArchivedChatBadgeIfNeeded(chatId);
        }

        _logger.i(
          'Successfully processed ${unreadMessages.length} unread messages from other users',
        );
      } else {
        _logger.d('No unread messages from other users to mark as seen');

        // ✅ NEW: Ensure unseen count is 0 if no unread messages
        final currentUnseenCount = getChatUnseenCount(chatId);
        if (currentUnseenCount > 0) {
          clearChatUnseenCount(chatId);
          _logger.d(
            'Cleared unseen count for chat $chatId (no unread messages found)',
          );
        }

        // ✅ FIX: Also clear archived chat badge count if this chat is archived
        _clearArchivedChatBadgeIfNeeded(chatId);
      }
    } catch (e) {
      _logger.e('Error marking chat messages as seen: $e');
    }
  }

  /// Check if a message has been seen
  bool isMessageSeen(int messageId) {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      return false;
    }

    try {
      final message = _chatsData.records!.firstWhere(
        (msg) => msg.messageId == messageId,
      );
      return message.messageSeenStatus == 'seen';
    } catch (e) {
      return false;
    }
  }

  /// Get current user ID for permission checks
  Future<int?> _getCurrentUserId() async {
    try {
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        return int.tryParse(_currentUserId!);
      }

      final userIdString = await SecurePrefs.getString(
        SecureStorageKeys.USERID,
      );
      return int.tryParse(userIdString ?? '');
    } catch (e) {
      _logger.e('Error getting current user ID: $e');
      return null;
    }
  }

  /// Delete message for everyone (via socket)
  Future<bool> deleteMessageForEveryone(int chatId, int messageId) async {
    if (_isDisposed) return false;

    try {
      _logger.d(
        '🗑️ Emitting delete message for everyone - ChatID: $chatId, MessageID: $messageId',
      );

      // Emit socket event for delete for everyone
      _socketEventController.emitDeleteMessageForEveryone(chatId, messageId);

      _logger.i('✅ Delete message for everyone event emitted successfully');

      // Clear any existing error
      _error = null;
      _scheduleNotification();

      return true;
    } catch (e) {
      _error = "Failed to delete message: ${e.toString()}";
      _logger.e('❌ Delete message for everyone error: $e');
      _scheduleNotification();
      return false;
    }
  }

  Future<bool> deleteMessageForMe(int chatId, int messageId) async {
    if (_isDisposed) return false;

    try {
      _logger.d(
        '🗑️ Emitting delete message for me - ChatID: $chatId, MessageID: $messageId',
      );

      // Emit socket event for delete for me
      _socketEventController.emitDeleteMessageForMe(chatId, messageId);

      _logger.i('✅ Delete message for me event emitted successfully');

      // Clear any existing error
      _error = null;
      _scheduleNotification();

      return true;
    } catch (e) {
      _error = "Failed to delete message: ${e.toString()}";
      _logger.e('❌ Delete message for me error: $e');
      _scheduleNotification();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADD THESE METHODS TO YOUR EXISTING ChatProvider CLASS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Forward message to another chat via ChatRepository
  /// [fromChatId] - Source chat ID
  /// [toChatId] - Destination chat ID
  /// [messageId] - Message ID to forward
  /// Returns true if successful, false otherwise
  Future<bool> forwardMessage({
    required int fromChatId,
    required int toChatId,
    required int messageId,
  }) async {
    if (_isDisposed) return false;

    try {
      _logger.d(
        'ChatProvider: Forwarding message - fromChatId: $fromChatId, toChatId: $toChatId, messageId: $messageId',
      );

      // Use the private _chatRepository through this public method
      final success = await _chatRepository.forwardMessage(
        fromChatId: fromChatId,
        toChatId: toChatId,
        messageId: messageId,
      );

      if (success) {
        _logger.i('ChatProvider: Message forward successful');
        // Clear any existing error
        _error = null;
        _scheduleNotification();
      } else {
        _error = "Failed to forward message";
        _logger.e('ChatProvider: Message forward failed');
        _scheduleNotification();
      }

      return success;
    } catch (e) {
      _error = "Failed to forward message: ${e.toString()}";
      _logger.e('ChatProvider: Forward message error: $e');
      _scheduleNotification();
      return false;
    }
  }

  /// Forward multiple messages in batch
  /// [fromChatId] - Source chat ID
  /// [toChatId] - Destination chat ID
  /// [messageIds] - List of message IDs to forward
  /// Returns a map with results
  Future<Map<String, dynamic>> forwardMultipleMessages({
    required int fromChatId,
    required int toChatId,
    required List<int> messageIds,
  }) async {
    if (_isDisposed) return {'success': false, 'error': 'Provider disposed'};

    try {
      _logger.d(
        'ChatProvider: Forwarding ${messageIds.length} messages from chat $fromChatId to chat $toChatId',
      );

      // Use the private _chatRepository through this public method
      final result = await _chatRepository.forwardMultipleMessages(
        fromChatId: fromChatId,
        toChatId: toChatId,
        messageIds: messageIds,
      );

      if (result['success'] == true) {
        _logger.i('ChatProvider: Batch forward completed successfully');
        // Clear any existing error
        _error = null;
        _scheduleNotification();
      } else {
        _error = "Some messages failed to forward";
        _logger.w('ChatProvider: Batch forward completed with errors');
        _scheduleNotification();
      }

      return result;
    } catch (e) {
      _error = "Failed to forward messages: ${e.toString()}";
      _logger.e('ChatProvider: Batch forward error: $e');
      _scheduleNotification();

      return {
        'success': false,
        'total_messages': messageIds.length,
        'success_count': 0,
        'failure_count': messageIds.length,
        'errors': ['Critical error: $e'],
      };
    }
  }

  /// Forward message to a new user (creates new chat if needed)
  /// [fromChatId] - Source chat ID
  /// [toUserId] - Target user ID
  /// [messageId] - Message ID to forward
  /// Returns true if successful, false otherwise
  Future<bool> forwardMessageToUser({
    required int fromChatId,
    required int toUserId,
    required int messageId,
  }) async {
    if (_isDisposed) return false;

    try {
      _logger.d(
        'ChatProvider: Forwarding message to user - fromChatId: $fromChatId, toUserId: $toUserId, messageId: $messageId',
      );

      // Use the private _chatRepository through this public method
      final success = await _chatRepository.forwardMessageToUser(
        fromChatId: fromChatId,
        toUserId: toUserId,
        messageId: messageId,
      );

      if (success) {
        _logger.i('ChatProvider: Message forward to user successful');
        // Clear any existing error
        _error = null;
        _scheduleNotification();
      } else {
        _error = "Failed to forward message to user";
        _logger.e('ChatProvider: Message forward to user failed');
        _scheduleNotification();
      }

      return success;
    } catch (e) {
      _error = "Failed to forward message to user: ${e.toString()}";
      _logger.e('ChatProvider: Forward message to user error: $e');
      _scheduleNotification();
      return false;
    }
  }

  /// Check if a message can be forwarded (validation method)
  /// [messageId] - Message ID to check
  /// Returns true if the message can be forwarded, false otherwise
  Future<bool> canForwardMessage(int messageId) async {
    if (_isDisposed) return false;

    try {
      // Use the private _chatRepository through this public method
      return await _chatRepository.canForwardMessage(messageId);
    } catch (e) {
      _logger.e('ChatProvider: Error checking forward permission: $e');
      return false;
    }
  }

  /// Get available chats for forwarding (helper method)
  /// Returns a list of chats that the user can forward messages to
  Future<List<Map<String, dynamic>>> getAvailableChatsForForward() async {
    if (_isDisposed) return [];

    try {
      _logger.d('ChatProvider: Getting available chats for forwarding');

      // Use the private _chatRepository through this public method
      return await _chatRepository.getAvailableChatsForForward();
    } catch (e) {
      _logger.e('ChatProvider: Error getting available chats: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _logger.d("ChatProvider disposing");
    _isDisposed = true;

    // Cancel timers
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _highlightTimer?.cancel();
    _highlightTimer = null;

    // Stop any ongoing search
    _stopMessageSearch();

    // Dispose subscriptions
    _disposeSubscriptions();

    super.dispose();
  }

  Future<void> downloadPdfWithProgress({
    required String pdfUrl,
    required Function(double) onProgress,
    required Function(String?, String?) onComplete,
    bool isOpenPdf = false,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${pdfUrl.split('/').last}';
      final file = File(filePath);

      if (await file.exists()) {
        String metadata = await getPdfMetadataWhenDownloaded(filePath);
        onComplete(filePath, metadata);
        return;
      }

      var request = await HttpClient().getUrl(Uri.parse(pdfUrl));
      var response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        onComplete(null, "Download failed: ${response.statusCode}");
        return;
      }

      var totalBytes = response.contentLength;
      var bytesReceived = 0;
      var fileSink = file.openWrite();

      await response.forEach((chunk) {
        bytesReceived += chunk.length;
        fileSink.add(chunk);
        double progress = bytesReceived / totalBytes;
        onProgress(progress);
      });

      await fileSink.flush();
      await fileSink.close();

      String metadata = await getPdfMetadataWhenDownloaded(filePath);
      onComplete(filePath, metadata);
    } catch (e) {
      onComplete(null, "Error: ${e.toString()}");
    }
  }

  // Get chat list using socket (for real-time updates)
  Future<void> emitChatList() async {
    if (_isDisposed) return;

    try {
      _logger.d("Emitting chat list request via socket");
      await _socketEventController.emitChatList();
    } catch (e) {
      _error = "Failed to get chat list: ${e.toString()}";
      _scheduleNotification();
    }
  }

  /// Load more chat list data (pagination)
  Future<void> loadMoreChatList() async {
    if (_isDisposed) return;

    // Enhanced debug logging for load more
    _logger.d('🔄 loadMoreChatList called - Current state check:');
    _logger.d('📊 _hasChatListMoreData: $_hasChatListMoreData');
    _logger.d('⏳ _isChatListPaginationLoading: $_isChatListPaginationLoading');
    _logger.d('📄 _chatListCurrentPage: $_chatListCurrentPage');
    _logger.d('📈 _chatListTotalPages: $_chatListTotalPages');
    _logger.d('💬 Current chats count: ${_chatListData.chats.length}');
    _logger.d(
      '🔢 Page comparison: $_chatListCurrentPage >= $_chatListTotalPages = ${_chatListCurrentPage >= _chatListTotalPages}',
    );

    // Check if we can load more
    if (_isChatListPaginationLoading || !_hasChatListMoreData) {
      _logger.d(
        '❌ Chat list pagination skipped - loading: $_isChatListPaginationLoading, hasMore: $_hasChatListMoreData',
      );
      return;
    }

    // Check if we haven't reached the total pages
    if (_chatListCurrentPage >= _chatListTotalPages) {
      _logger.d(
        '🏁 Reached last page of chat list ($_chatListCurrentPage >= $_chatListTotalPages)',
      );
      _hasChatListMoreData = false;
      return;
    }

    try {
      _logger.d('🔄 Loading more chat list - page ${_chatListCurrentPage + 1}');
      _isChatListPaginationLoading = true;
      _scheduleNotification();

      // Request next page
      final nextPage = _chatListCurrentPage + 1;
      await emitChatListWithPage(nextPage);

      _logger.d('✅ Chat list pagination request sent for page $nextPage');
    } catch (e) {
      _error = "Failed to load more chat list: ${e.toString()}";
      _logger.e("❌ Chat list pagination error: $e");
      _isChatListPaginationLoading = false;
      _scheduleNotification();
    }
  }

  /// Request chat list with specific page
  Future<void> emitChatListWithPage(int page) async {
    try {
      _logger.d('Requesting chat list for page $page');

      // Emit socket event with pagination
      _socketEventController.emitChatList(
        page: page,
        pageSize: _chatListPageSize,
      );
    } catch (e) {
      _setError('Error requesting chat list: ${e.toString()}');
      _isChatListPaginationLoading = false;
      _scheduleNotification();
    }
  }

  void _handleChatListPaginationResponse(ChatListModel newChatListData) {
    try {
      final pagination = newChatListData.pagination;
      if (pagination != null) {
        final previousCurrentPage = _chatListCurrentPage;
        final previousTotalPages = _chatListTotalPages;

        _chatListCurrentPage = pagination.currentPage ?? 1;
        _chatListTotalPages = pagination.totalPages ?? 1;
        _hasChatListMoreData = _chatListCurrentPage < _chatListTotalPages;

        // Debug the hasChatListMoreData calculation
        _logger.d(
          '🧮 Calculating hasChatListMoreData: $_chatListCurrentPage < $_chatListTotalPages = $_hasChatListMoreData',
        );

        _logger.d(
          '📊 Chat list pagination updated - Page: $_chatListCurrentPage/$_chatListTotalPages (was $previousCurrentPage/$previousTotalPages), HasMore: $_hasChatListMoreData',
        );

        // Additional debug info about the received pagination data
        _logger.d(
          '🔍 Received pagination data: currentPage=${pagination.currentPage}, totalPages=${pagination.totalPages}, totalRecords=${pagination.totalRecords}',
        );

        // CRITICAL FIX: Force immediate notification to update UI with new pagination state
        notifyListeners();
      } else {
        _logger.w('⚠️ No pagination data received in response');
        _logger.w('⚠️ newChatListData: ${newChatListData.toString()}');
      }

      if (_chatListCurrentPage == 1) {
        // First page - replace all data
        _chatListData = newChatListData;
        _logger.d(
          '📄 First page chat list loaded with ${_chatListData.chats.length} chats',
        );

        // ✅ NEW: Filter out archived chats after loading (with sorting for first page)
        _filterArchivedChatsFromList(shouldSort: false);

        // ✅ FIXED: Only sort on first page load to maintain server pagination order
        _sortChatList();
      } else {
        // Subsequent pages - append data WITHOUT global sorting to preserve pagination
        _appendChatListData(newChatListData);

        // ✅ NEW: Filter out archived chats after loading (no sorting for pagination)
        _filterArchivedChatsFromList(shouldSort: false);

        _logger.d(
          '📄 Page $_chatListCurrentPage appended. Total chats: ${_chatListData.chats.length}',
        );
      }

      _isChatListPaginationLoading = false;
      _scheduleNotification();
    } catch (e) {
      _logger.e('Error handling chat list pagination response: $e');
      _isChatListPaginationLoading = false;
      _scheduleNotification();
    }
  }

  /// Append new chat list data to existing data
  void _appendChatListData(ChatListModel newChatListData) {
    if (newChatListData.chats.isEmpty) {
      _logger.w('⚠️ No new chats in pagination response');
      return;
    }

    // Get existing chat IDs to prevent duplicates
    final existingChatIds =
        _chatListData.chats
            .where((chat) => chat.records?.isNotEmpty == true)
            .map((chat) => chat.records!.first.chatId)
            .where((id) => id != null)
            .toSet();

    // Filter out duplicate chats
    final uniqueNewChats =
        newChatListData.chats.where((chat) {
          if (chat.records?.isNotEmpty == true) {
            final chatId = chat.records!.first.chatId;
            return chatId != null && !existingChatIds.contains(chatId);
          }
          return false;
        }).toList();

    if (uniqueNewChats.isNotEmpty) {
      _chatListData.chats.addAll(uniqueNewChats);
      _logger.d(
        '📑 Appended ${uniqueNewChats.length} unique chats. Total: ${_chatListData.chats.length}',
      );
    } else {
      _logger.w(
        '⚠️ All ${newChatListData.chats.length} new chats were duplicates',
      );
    }

    // Update pagination metadata
    _chatListData.pagination = newChatListData.pagination;
  }

  /// Sort chat list by updatedAt first, then createdAt as fallback
  void _sortChatList() {
    if (_chatListData.chats.isEmpty) return;

    _chatListData.chats.sort((a, b) {
      // Get the first record from each chat
      final recordA = a.records?.isNotEmpty == true ? a.records!.first : null;
      final recordB = b.records?.isNotEmpty == true ? b.records!.first : null;

      // If either record is null, put it at the end
      if (recordA == null && recordB == null) return 0;
      if (recordA == null) return 1;
      if (recordB == null) return -1;

      // Try to get updatedAt first, then fall back to createdAt
      String? dateA = recordA.updatedAt;
      if (dateA == null || dateA.isEmpty) {
        dateA = recordA.createdAt;
      }

      String? dateB = recordB.updatedAt;
      if (dateB == null || dateB.isEmpty) {
        dateB = recordB.createdAt;
      }

      // If both dates are null/empty, consider them equal
      if ((dateA == null || dateA.isEmpty) &&
          (dateB == null || dateB.isEmpty)) {
        return 0;
      }

      // If one date is null/empty, put it at the end
      if (dateA == null || dateA.isEmpty) return 1;
      if (dateB == null || dateB.isEmpty) return -1;

      // Parse dates and compare (newest first)
      try {
        final parsedA = DateTime.parse(dateA);
        final parsedB = DateTime.parse(dateB);
        return parsedB.compareTo(parsedA); // Descending order (newest first)
      } catch (e) {
        _logger.w('Error parsing dates for sorting: $e');
        // If parsing fails, compare as strings
        return dateB.compareTo(dateA);
      }
    });

    _logger.d('📊 Sorted ${_chatListData.chats.length} chats by date');
  }

  void resetChatListPagination() {
    _chatListCurrentPage = 1;
    _chatListTotalPages =
        1; // This will be updated when real pagination data is received
    _hasChatListMoreData =
        true; // Start optimistically, will be corrected by real data
    _isChatListPaginationLoading = false;
    _chatListData = ChatListModel(chats: []);

    _logger.d(
      '🔄 Reset pagination state - Page: $_chatListCurrentPage/$_chatListTotalPages',
    );
    _scheduleNotification();
  }

  // ✅ NEW: Search functionality state (for home screen chat list)
  ChatListModel _searchResults = ChatListModel(chats: []);
  bool _isSearching = false;
  bool _isSearchLoading = false;
  String _currentSearchQuery = '';

  // ✅ NEW: Search getters (for home screen chat list)
  ChatListModel get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  bool get isSearchLoading => _isSearchLoading;
  String get currentSearchQuery => _currentSearchQuery;

  // ✅ NEW: Universal chat screen message search functionality state
  List<Map<String, dynamic>> _universalChatSearchResults = [];
  bool _isUniversalChatSearching = false;
  bool _isUniversalChatSearchLoading = false;
  String _universalChatSearchQuery = '';

  // ✅ NEW: Universal chat screen search getters
  List<Map<String, dynamic>> get universalChatSearchResults =>
      _universalChatSearchResults;
  bool get isUniversalChatSearching => _isUniversalChatSearching;
  bool get isUniversalChatSearchLoading => _isUniversalChatSearchLoading;
  String get universalChatSearchQuery => _universalChatSearchQuery;

  /// Search chats with the given query
  /// Returns search results that match the current chat list structure
  Future<void> searchChats(String query) async {
    if (_isDisposed) return;

    // Trim and validate query
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      clearSearch();
      return;
    }

    try {
      _logger.d('🔍 Searching chats with query: "$trimmedQuery"');

      // Set loading state
      _isSearchLoading = true;
      _currentSearchQuery = trimmedQuery;
      _scheduleNotification();

      // Call search API
      final response = await _chatRepository.searchChats(
        searchText: trimmedQuery,
      );

      if (response != null) {
        // Parse search results into chat list format
        final searchData = response['data'] as List<dynamic>? ?? [];
        final List<Chats> searchChats = [];

        for (var chatData in searchData) {
          try {
            // Create PeerUserData for the chat
            PeerUserData? peerUser;
            String? chatType = chatData['chat_type']?.toString();
            bool isGroupChat = chatType?.toLowerCase() == 'group';

            if (isGroupChat) {
              // For group chats, create minimal peer data
              peerUser = PeerUserData(
                userId: 0, // Groups don't have a single user ID
                userName: chatData['group_name']?.toString() ?? 'Group Chat',
                fullName: chatData['group_name']?.toString() ?? 'Group Chat',
                profilePic: chatData['group_icon']?.toString() ?? '',
              );
            } else {
              // For individual chats, extract user data from participants
              // Filter out current user from participants
              final participants =
                  chatData['participants'] as List<dynamic>? ?? [];
              final currentUserIdInt = int.tryParse(_currentUserId ?? '') ?? 0;

              // Find the participant who is NOT the current user
              Map<String, dynamic>? otherUserData;
              for (var participant in participants) {
                final userData =
                    participant['User'] as Map<String, dynamic>? ?? {};
                final participantUserId = userData['user_id'] as int? ?? 0;

                if (participantUserId != currentUserIdInt &&
                    participantUserId > 0) {
                  otherUserData = userData;
                  break;
                }
              }

              if (otherUserData != null) {
                peerUser = PeerUserData(
                  userId: otherUserData['user_id'] as int? ?? 0,
                  userName: otherUserData['user_name']?.toString() ?? '',
                  fullName: otherUserData['full_name']?.toString() ?? '',
                  profilePic: otherUserData['profile_pic']?.toString() ?? '',
                  email: otherUserData['email']?.toString() ?? '',
                );
              }
            }

            // Create Records for the chat
            final messages = chatData['Messages'] as List<dynamic>? ?? [];
            Messages? lastMessage;

            if (messages.isNotEmpty) {
              final msgData = messages.first as Map<String, dynamic>;
              lastMessage = Messages(
                messageId: msgData['message_id'] as int? ?? 0,
                messageContent: msgData['message_content']?.toString() ?? '',
                messageType: msgData['message_type']?.toString() ?? 'text',
                createdAt: msgData['createdAt']?.toString() ?? '',
                senderId: msgData['sender_id'] as int? ?? 0,
              );
            }

            final record = Records(
              chatId: chatData['chat_id'] as int? ?? 0,
              chatType: chatType ?? 'private',
              groupName:
                  isGroupChat ? chatData['group_name']?.toString() : null,
              groupIcon:
                  isGroupChat ? chatData['group_icon']?.toString() : null,
              groupDescription:
                  isGroupChat
                      ? chatData['group_description']?.toString()
                      : null,
              messages: lastMessage != null ? [lastMessage] : [],
              unseenCount:
                  0, // Search results don't typically include unseen count
              blockedBy:
                  (chatData['blocked_by'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
            );

            // Create the chat item
            final chat = Chats(peerUserData: peerUser, records: [record]);

            searchChats.add(chat);
          } catch (e) {
            _logger.e('Error parsing search result: $e');
            // Continue with other results even if one fails
          }
        }

        // Update search results
        _searchResults = ChatListModel(chats: searchChats);
        _isSearching = true;

        _logger.i('🔍 Search completed - Found ${searchChats.length} results');
      } else {
        // No results or API error
        _searchResults = ChatListModel(chats: []);
        _isSearching = true;
        _logger.w('🔍 Search returned no results');
      }
    } catch (e) {
      _logger.e('🔍 Search error: $e');
      _searchResults = ChatListModel(chats: []);
      _isSearching = true;
      _error = 'Search failed: ${e.toString()}';
    } finally {
      _isSearchLoading = false;
      _scheduleNotification();
    }
  }

  /// Clear search results and return to normal chat list
  void clearSearch() {
    if (_isDisposed) return;

    _logger.d('🔍 Clearing search results');
    _searchResults = ChatListModel(chats: []);
    _isSearching = false;
    _isSearchLoading = false;
    _currentSearchQuery = '';
    _scheduleNotification();
  }

  /// Clear universal chat screen search results
  void clearUniversalChatSearch() {
    if (_isDisposed) return;

    _logger.d('🔍 Clearing universal chat search results');
    _universalChatSearchResults = [];
    _isUniversalChatSearching = false;
    _isUniversalChatSearchLoading = false;
    _universalChatSearchQuery = '';
    _scheduleNotification();
  }

  /// Set universal chat search loading state
  void setUniversalChatSearchLoading(bool loading) {
    if (_isDisposed) return;
    _isUniversalChatSearchLoading = loading;
    _scheduleNotification();
  }

  /// Set universal chat search results
  void setUniversalChatSearchResults(
    List<Map<String, dynamic>> results,
    String query,
  ) {
    if (_isDisposed) return;
    _universalChatSearchResults = results;
    _universalChatSearchQuery = query;
    _isUniversalChatSearching = query.isNotEmpty;
    _isUniversalChatSearchLoading = false;
    _scheduleNotification();
  }

  void forceHighlightRefresh(int messageId) {
    if (_highlightedMessageId == messageId) {
      _logger.d('🔄 Force refreshing highlight for message: $messageId');

      // Clear current highlight
      _highlightedMessageId = null;
      _scheduleNotification();

      // Re-apply highlight after a brief moment with extended duration
      Future.delayed(Duration(milliseconds: 150), () {
        if (!_isDisposed) {
          _highlightedMessageId = messageId;
          _scheduleNotification();

          // Clear any existing highlight timer
          _highlightTimer?.cancel();

          // Extended highlight duration for better visibility
          _highlightTimer = Timer(Duration(seconds: 8), () {
            // Increased to 8 seconds
            if (!_isDisposed) {
              _logger.d(
                '⏰ Clearing refreshed highlight for message: $messageId',
              );
              _highlightedMessageId = null;
              _scheduleNotification();
            }
          });

          _logger.d('✨ Message $messageId highlight refreshed for 8 seconds');
        }
      });
    } else {
      // Direct highlight if not currently highlighted
      highlightMessage(messageId);
    }
  }

  // Format time for UI
  String formatTime(String? time) {
    return _socketEventController.formatTime(time);
  }

  // Generate video thumbnail
  Future<String?> generateVideoThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.PNG,
        maxWidth: 300,
        maxHeight: 300,
        quality: 75,
      );

      _logger.d("Thumbnail generated: ${thumbnailFile.path}");
      return thumbnailFile.path;
    } catch (e) {
      _logger.e("Failed to generate video thumbnail: $e");
      return null;
    }
  }

  /// Get delete permission text for UI
  String getDeletePermissionText(chats.Records message) {
    if (!canDeleteMessage(message)) {
      return 'You can only delete your own messages';
    }
    return 'Delete Message';
  }

  // PDF related functionality (unchanged)
  Future<String> getPdfMetadata(String pdfUrl) async {
    try {
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode != 200) return "Unknown PDF";

      final PdfDocument document = PdfDocument(inputBytes: response.bodyBytes);
      int pageCount = document.pages.count;
      double fileSizeMB = response.bodyBytes.length / (1024 * 1024);

      document.dispose();
      return "$pageCount Pages • PDF • ${fileSizeMB.toStringAsFixed(2)} MB";
    } catch (e) {
      return "Error loading PDF";
    }
  }

  Future<String> getPdfMetadataWhenDownloaded(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        return "Unknown PDF";
      }

      final PdfDocument document = PdfDocument(
        inputBytes: await file.readAsBytes(),
      );
      int pageCount = document.pages.count;
      double fileSizeMB = file.lengthSync() / (1024 * 1024);

      document.dispose();
      return "$pageCount Pages • PDF • ${fileSizeMB.toStringAsFixed(2)} MB";
    } catch (e) {
      _logger.e("PDF Metadata Error: $e");
      return "Error loading PDF";
    }
  }

  Future<Map<String, dynamic>> getPdfSizeAndPageCount(String pdfUrl) async {
    try {
      final uri = Uri.parse(pdfUrl);
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200 || response.statusCode == 206) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        final contentLength = bytes.length;

        // Convert bytes to human-readable format
        String sizeText;
        if (contentLength < 1024) {
          sizeText = '$contentLength B';
        } else if (contentLength < 1024 * 1024) {
          sizeText = '${(contentLength / 1024).toStringAsFixed(2)} KB';
        } else {
          sizeText = '${(contentLength / (1024 * 1024)).toStringAsFixed(2)} MB';
        }

        // Convert bytes to string to search for page count
        final content = utf8.decode(bytes, allowMalformed: true);
        final pageCountRegex = RegExp(r'/Count\s+(\d+)', caseSensitive: false);
        final match = pageCountRegex.firstMatch(content);

        final pageCount = match != null ? int.parse(match.group(1)!) : null;

        return {'size': sizeText, 'pageCount': pageCount ?? 'Unknown'};
      } else {
        return {
          'size': 'Failed: ${response.statusCode}',
          'pageCount': 'Unknown',
        };
      }
    } catch (e) {
      return {'size': 'Error: $e', 'pageCount': 'Error'};
    }
  }

  /// Get pin/unpin permission text for UI
  String getPinUnpinPermissionText(chats.Records message) {
    if (!canPinUnpinMessage(message)) {
      if (message.pinned == true) {
        return 'Only the user who pinned this message can unpin it';
      } else {
        return 'You cannot pin this message';
      }
    }

    return message.pinned == true ? 'Unpin Message' : 'Pin Message';
  }

  /// Get star/unstar permission text for UI
  String getStarUnstarPermissionText(chats.Records message) {
    if (!canStarUnStarMessage(message)) {
      if (message.stared == true) {
        return 'You cannot unstar this message';
      } else {
        return 'You cannot star this message';
      }
    }

    return message.stared == true ? 'Unstar Message' : 'Star Message';
  }

  // ✅ ENHANCED: Highlight message method
  void highlightMessage(int messageId) {
    _logger.d('🎯 Highlighting message: $messageId');

    _highlightedMessageId = messageId;
    _scheduleNotification();

    // Clear any existing highlight timer
    _highlightTimer?.cancel();

    // Extended highlight duration for better visibility
    _highlightTimer = Timer(Duration(seconds: 5), () {
      // Increased from 3 to 5 seconds
      if (!_isDisposed) {
        _logger.d('⏰ Clearing highlight for message: $messageId');
        _highlightedMessageId = null;
        _scheduleNotification();
      }
    });

    _logger.d('✨ Message $messageId highlighted for 5 seconds');
  }

  // Initialize provider
  Future<void> initialize() async {
    if (_isDisposed) return;

    _logger.i('Initializing ChatProvider');
    _isInitializing = true;
    _scheduleNotification();

    try {
      // Re-initialize subscriptions
      _initializeSubscriptions();

      // Connect to socket if not already connected
      if (!_socketEventController.isConnected) {
        await connect();
      }

      // Refresh chat list data
      await emitChatList();

      // Get online users
      _socketEventController.emitInitialOnlineUser();

      _isInitializing = false;
      _scheduleNotification();
    } catch (e) {
      _error = "Failed to initialize: ${e.toString()}";
      _isInitializing = false;
      _scheduleNotification();
    }
  }

  // ✅ ADD NEW METHOD: Check if a message is pinned
  bool isMessagePinned(int messageId) {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      return false;
    }

    try {
      final message = _chatsData.records!.firstWhere(
        (msg) => msg.messageId == messageId,
      );
      return message.pinned == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isPdfDownloaded(String pdfUrl) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/${pdfUrl.split('/').last}';
    return File(filePath).exists();
  }

  // Check if a user is online
  bool isUserOnline(int userId) {
    if (_isDisposed) return false;
    return _socketEventController.isUserOnline(userId);
  }

  // Check if someone is typing in a chat
  bool isUserTypingInChat(int chatId) {
    if (_isDisposed) return false;

    bool result = _socketEventController.isUserTypingInChat(chatId);
    _logger.d("ChatProvider: isUserTypingInChat($chatId) = $result");
    return result;
  }

  // Future<void> loadChatMessages({
  //   required int chatId,
  //   required int peerId,
  //   bool clearExisting = true,
  // }) async {
  //   if (_isDisposed) return;

  //   try {
  //     _logger.d("Loading chat messages - chatId: $chatId, peerId: $peerId");

  //     // Set the current chat context
  //     setCurrentChat(chatId, peerId);

  //     if (clearExisting) {
  //       // Clear existing messages
  //       _chatsData = chats.ChatsModel();
  //       _pinnedMessagesData = chats.ChatsModel();
  //       _lastChatsDataHash = null;
  //       _scheduleNotification();
  //     }

  //     // Load messages from socket
  //     if (chatId > 0) {
  //       // Existing chat
  //       await _socketEventController.emitChatMessages(chatId: chatId);
  //     } else {
  //       // New chat with user
  //       await _socketEventController.emitChatMessages(peerId: peerId);
  //     }

  //     _logger.d("Chat messages loading initiated");
  //   } catch (e) {
  //     _error = "Failed to load chat messages: ${e.toString()}";
  //     _logger.e("Error loading chat messages: $e");
  //     _scheduleNotification();
  //   }
  // }

  Future<void> loadChatMessages({
    required int chatId,
    required int peerId,
    bool clearExisting = true,
  }) async {
    if (_isDisposed) return;

    try {
      _logger.d(
        "🚀 LOAD CHAT: Starting loadChatMessages - chatId: $chatId, peerId: $peerId, clearExisting: $clearExisting",
      );

      // 🛡️ SAFETY CHECK: Don't load messages from recently cleared chats
      // BUT: If the chat has new messages in the chat list, allow loading
      if (_recentlyClearedChats.contains(chatId)) {
        // 🔍 Check if this chat now has messages in the chat list
        bool hasMessagesInChatList = false;
        for (final chat in _chatListData.chats) {
          if (chat.records != null && chat.records!.isNotEmpty) {
            final chatRecord = chat.records!.first;
            if (chatRecord.chatId == chatId) {
              // Check if this chat has any messages
              if (chatRecord.messages != null &&
                  chatRecord.messages!.isNotEmpty) {
                hasMessagesInChatList = true;
                _logger.d(
                  '✅ ALLOW LOAD: Chat $chatId has new messages, removing from recently cleared',
                );
                // Remove from recently cleared since it has new messages
                _recentlyClearedChats.remove(chatId);
              }
              break;
            }
          }
        }

        // Only block if chat truly has no messages
        if (!hasMessagesInChatList) {
          _logger.w(
            '🚫 BLOCKED: Preventing message load for recently cleared chat $chatId (no new messages)',
          );
          // Clear existing data instead
          _chatsData = chats.ChatsModel();
          _pinnedMessagesData = chats.ChatsModel();
          _lastChatsDataHash = null;
          _regroupMessages();
          _scheduleNotification();
          return;
        }
      }

      // 🗄️ CACHE-FIRST LOADING: Check cache before clearing data
      String? chatIdString;
      if (chatId > 0) {
        chatIdString = chatId.toString();
        _logger.d("💬 CHAT TYPE: Group/existing chat - ID: $chatId");
      } else if (peerId > 0) {
        chatIdString = 'user_$peerId';
        _logger.d("👤 CHAT TYPE: Individual chat - Peer ID: $peerId");
      }

      bool loadedFromCache = false;
      bool hasCache = false;

      if (chatIdString != null) {
        _logger.d("🔍 CACHE: Attempting to load from cache for: $chatIdString");

        // Check if cache exists first
        hasCache = ChatCacheManager.hasPage(chatIdString, 1);
        if (hasCache) {
          _logger.d(
            "🚫 LOADER PREVENTION: Cache detected - will prevent loader from showing",
          );
          // ✅ IMMEDIATE: Set loading to false before any other operations
          _socketEventController.setChatLoadingState(false);
          // ✅ CRITICAL: Set cache protection to prevent server overrides
          _socketEventController.setCacheDataProtection(true);
          // ✅ IMMEDIATE: Trigger UI update to reflect loading state change
          _scheduleNotification();
        }

        loadedFromCache = await _tryLoadFromCache(
          chatIdString,
          chatId > 0 ? chatId : peerId,
        );
        _logger.d("📊 CACHE RESULT: loadedFromCache = $loadedFromCache");
      } else {
        _logger.w("⚠️ NO CHAT ID: Cannot check cache - chatIdString is null");
      }

      // Only clear existing data if no cache was loaded and clearExisting is true
      if (clearExisting && !loadedFromCache) {
        _logger.d(
          "🧹 CLEARING: Clearing existing messages (no cache available)",
        );
        // Clear existing messages
        _chatsData = chats.ChatsModel();
        _pinnedMessagesData = chats.ChatsModel();
        _lastChatsDataHash = null;
        _regroupMessages();
        _scheduleNotification();
      } else if (clearExisting && loadedFromCache) {
        _logger.d(
          "🎯 SKIP CLEARING: Cache loaded, keeping cached data instead of clearing",
        );
      }

      // ✅ Set current chat context AFTER cache check to prevent unnecessary loading state
      if (loadedFromCache) {
        _logger.d(
          "🎯 CACHE LOADED: Setting chat context without clearing cached data",
        );
        // Set current chat data directly without clearing cached messages
        _currentChatData = ChatIds(chatId: chatId, userId: peerId);
        _socketEventController.setCurrentChatWithoutLoading(chatId, peerId);
        // Ensure pinned messages are extracted from cached data
        _extractPinnedMessages(_chatsData);
      } else {
        _logger.d(
          "📡 NO CACHE: Setting chat context normally (will trigger loading state)",
        );
        // Set the current chat context normally (will trigger loading)
        setCurrentChat(chatId, peerId);
      }

      // Load messages from socket only if not loaded from cache
      if (chatId > 0 && !loadedFromCache) {
        _logger.d(
          "🌐 SERVER CALL: Loading from server - cache miss for chat $chatId",
        );
        // Existing chat - use default page size (will be overridden by onChatItemTap if needed)
        await _socketEventController.emitChatMessages(chatId: chatId);

        // ✅ ENHANCED: Wait for messages to load, then mark as seen
        Future.delayed(Duration(milliseconds: 2000), () async {
          if (!_isDisposed && _currentChatData.chatId == chatId) {
            // Ensure messages are actually loaded
            if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
              _logger.d('Messages loaded, now marking unread messages as seen');
              await markChatMessagesAsSeen(chatId);
            } else {
              _logger.w('Messages not loaded yet after 2 seconds');
            }
          }
        });
      } else if (peerId > 0 && !loadedFromCache) {
        // New chat with user - only if not loaded from cache
        _logger.d(
          "🌐 SERVER CALL: New chat - loading messages for peer: $peerId",
        );
        await _socketEventController.emitChatMessages(peerId: peerId);
      } else if (loadedFromCache) {
        _logger.d(
          "🎯 CACHE SUCCESS: Skipped server call - data loaded from cache",
        );
      } else {
        _logger.w(
          "⚠️ NO ACTION: Neither cache hit nor valid IDs for server call",
        );
      }

      _logger.d("Chat messages loading initiated");
    } catch (e) {
      _error = "Failed to load chat messages: ${e.toString()}";
      _logger.e("Error loading chat messages: $e");
      _scheduleNotification();
    }
  }

  /// 🗄️ Try to load chat messages from cache first
  /// Returns true if successfully loaded from cache, false if cache miss
  Future<bool> _tryLoadFromCache(String chatId, int chatIdInt) async {
    try {
      _logger.d("🔍 CACHE CHECK: Checking cache for chat $chatId");

      // 🛡️ SAFETY CHECK: Don't load cache for recently cleared chats
      // BUT: If the chat has new messages in the chat list, allow loading
      if (_recentlyClearedChats.contains(chatIdInt)) {
        // 🔍 Check if this chat now has messages in the chat list
        bool hasMessagesInChatList = false;
        for (final chat in _chatListData.chats) {
          if (chat.records != null && chat.records!.isNotEmpty) {
            final chatRecord = chat.records!.first;
            if (chatRecord.chatId == chatIdInt) {
              // Check if this chat has any messages
              if (chatRecord.messages != null &&
                  chatRecord.messages!.isNotEmpty) {
                hasMessagesInChatList = true;
                _logger.d(
                  '✅ ALLOW CACHE LOAD: Chat $chatIdInt has new messages, removing from recently cleared',
                );
                // Remove from recently cleared since it has new messages
                _recentlyClearedChats.remove(chatIdInt);
              }
              break;
            }
          }
        }

        // Only block if chat truly has no messages
        if (!hasMessagesInChatList) {
          _logger.w(
            '🚫 BLOCKED: Preventing cache load for recently cleared chat $chatIdInt (no new messages)',
          );
          return false;
        }
      }

      await ChatCacheManager.initializeChat(chatId);

      // Check if we have cached data for page 1 (initial load)
      if (ChatCacheManager.hasPage(chatId, 1)) {
        _logger.d("🎯 CACHE HIT: Found cached page 1 for chat $chatId");

        final cachedMessages = await ChatCacheManager.getPage(chatId, 1);

        if (cachedMessages != null && cachedMessages.isNotEmpty) {
          _logger.d(
            "✅ CACHE LOADING: Using ${cachedMessages.length} cached messages for chat $chatId - NO SERVER CALL NEEDED",
          );

          // Create ChatsModel from cached data
          final cachedChatModel = chats.ChatsModel(
            records: cachedMessages,
            pagination: chats.Pagination(
              currentPage: 1,
              totalPages: 10, // Will be updated when fresh data arrives
              totalRecords: cachedMessages.length,
              recordsPerPage: cachedMessages.length,
            ),
          );

          // Update provider state with cached data
          _chatsData = cachedChatModel;
          _regroupMessages();

          // ✅ CRITICAL: Extract pinned messages from cached data
          _extractPinnedMessages(cachedChatModel);
          _logger.d(
            "📌 CACHE: Extracted pinned messages from cached data for chat $chatId",
          );

          // ✅ CRITICAL: Set loading states to false to hide loaders
          _isPaginationLoading = false;
          _isChatListPaginationLoading = false;

          // Initialize pagination state
          _chatListCurrentPage = 1;
          _hasChatListMoreData = true; // Assume more data might be available

          // ✅ CRITICAL: Force socket loading state to false so UI hides loader
          _socketEventController.setChatLoadingState(false);

          // 🛡️ PROTECTION: Enable cache protection to prevent server overrides
          _socketEventController.setCacheDataProtection(true);

          // ✅ CRITICAL: Notify UI immediately with cached data
          _scheduleNotification();

          _logger.d(
            "🚀 CACHE SUCCESS: UI updated with cached data, loaders hidden for chat $chatId",
          );

          // 🔄 DISABLED: Temporarily disable background fetch to prevent loader interference
          // _fetchUpdatesInBackground(chatIdInt);

          _logger.d(
            "🎯 CACHE COMPLETE: Cached data loaded, loader hidden, background fetch disabled",
          );

          return true;
        } else {
          _logger.d(
            "⚠️ CACHE EMPTY: Page exists but no messages for chat $chatId",
          );
        }
      } else {
        _logger.d("📭 CACHE MISS: No cached page 1 found for chat $chatId");
      }

      _logger.d("🌐 FALLBACK: Will load from server for chat $chatId");
      return false;
    } catch (e) {
      _logger.e(
        "❌ CACHE ERROR: Failed to load from cache for chat $chatId: $e",
      );
      return false;
    }
  }

  /// Fetch updates in background after loading from cache
  // ignore: unused_element
  Future<void> _fetchUpdatesInBackground(int chatId) async {
    try {
      _logger.d("🔄 BACKGROUND: Starting background fetch for chat $chatId");

      // Delay to let UI render cached data first
      await Future.delayed(const Duration(seconds: 2));

      if (!_isDisposed && _currentChatData.chatId == chatId) {
        _logger.d(
          "📡 BACKGROUND: Fetching fresh data in background for chat $chatId",
        );
        // Fetch fresh data in background
        await _socketEventController.emitChatMessages(chatId: chatId);
        _logger.d("✅ BACKGROUND: Background fetch completed for chat $chatId");
      } else {
        _logger.d(
          "⏭️ BACKGROUND: Skipped background fetch - chat changed or disposed",
        );
      }
    } catch (e) {
      _logger.e("❌ BACKGROUND: Error in background fetch: $e");
    }
  }

  /// 🗄️ Cache new chat data when received from server
  Future<void> _cacheNewChatData(chats.ChatsModel data) async {
    try {
      if (data.records == null || data.records!.isEmpty) return;

      String? chatIdString;
      if (_currentChatData.chatId != null && _currentChatData.chatId! > 0) {
        chatIdString = _currentChatData.chatId.toString();
      } else if (_currentChatData.userId != null &&
          _currentChatData.userId! > 0) {
        chatIdString = 'user_${_currentChatData.userId}';
      }

      if (chatIdString == null) return;

      final currentPage = data.pagination?.currentPage ?? 1;

      _logger.d(
        "💾 Caching new data for chat $chatIdString, page $currentPage (${data.records!.length} messages)",
      );

      // Cache the data
      await ChatCacheManager.cachePage(
        chatIdString,
        currentPage,
        data.records!,
        pagination: data.pagination,
      );

      _logger.d(
        "✅ Successfully cached page $currentPage for chat $chatIdString",
      );
    } catch (e) {
      _logger.e("❌ Error caching new chat data: $e");
    }
  }

  /// 🧪 Debug method to test cache functionality
  Future<void> debugCacheStatus(String chatId) async {
    try {
      _logger.d("🔬 DEBUG: Testing cache for chat $chatId");

      await ChatCacheManager.initializeChat(chatId);

      final hasPage1 = ChatCacheManager.hasPage(chatId, 1);
      _logger.d("📊 DEBUG: hasPage(1) = $hasPage1");

      if (hasPage1) {
        final messages = await ChatCacheManager.getPage(chatId, 1);
        _logger.d("📊 DEBUG: Cached messages count = ${messages?.length ?? 0}");
      }

      final cachedPages = ChatCacheManager.getCachedPages(chatId);
      _logger.d("📊 DEBUG: All cached pages = $cachedPages");

      ChatCacheManager.logCacheStats(chatId);
    } catch (e) {
      _logger.e("❌ DEBUG: Error testing cache: $e");
    }
  }

  // Load more messages (for pagination)
  // Future<void> loadMoreMessages() async {
  //   if (_isDisposed) return;

  //   // ✅ SIMPLE CHECKS: Only check what's essential
  //   if (_isPaginationLoading || !hasMoreMessages) {
  //     _logger.d(
  //       'Pagination skipped - loading: $_isPaginationLoading, hasMore: $hasMoreMessages',
  //     );
  //     return;
  //   }

  //   try {
  //     _logger.d('🔄 Starting pagination load');
  //     _setPaginationLoading(true);

  //     // ✅ DELEGATE TO SOCKET CONTROLLER: Let it handle the complexity
  //     await _socketEventController.loadMoreMessages();

  //     _logger.d('✅ Pagination load completed');
  //   } catch (e) {
  //     _error = "Failed to load more messages: ${e.toString()}";
  //     _logger.e("❌ Pagination error: $e");
  //     _scheduleNotification();
  //   } finally {
  //     // ✅ ALWAYS RESET LOADING STATE
  //     _setPaginationLoading(false);
  //   }
  // }

  Future<void> loadMoreMessages() async {
    if (_isDisposed) return;

    // ✅ Check all conditions including our own loading state
    if (_isPaginationLoading ||
        !hasMoreMessages ||
        isChatLoading ||
        isRefreshing) {
      _logger.d(
        'Pagination skipped - loading: $_isPaginationLoading, hasMore: $hasMoreMessages, chatLoading: $isChatLoading, refreshing: $isRefreshing',
      );
      return;
    }

    try {
      _logger.d('🔄 Starting pagination load');

      // ✅ CRITICAL: Set loading state BEFORE calling socket controller
      _setPaginationLoading(true);

      // ✅ DELEGATE TO SOCKET CONTROLLER
      await _socketEventController.loadMoreMessages();

      _logger.d('✅ Pagination load completed');
    } catch (e) {
      _error = "Failed to load more messages: ${e.toString()}";
      _logger.e("❌ Pagination error: $e");
      _scheduleNotification();
    } finally {
      // ✅ ALWAYS RESET LOADING STATE
      _setPaginationLoading(false);
    }
  }

  /// Pin or unpin a message
  Future<bool> pinUnpinMessage(
    int chatId,
    int messageId, [
    int inDays = 1,
  ]) async {
    if (_isDisposed) return false;

    try {
      // Find the message to check permissions
      chats.Records? targetMessage;
      if (_chatsData.records != null) {
        try {
          targetMessage = _chatsData.records!.firstWhere(
            (msg) => msg.messageId == messageId,
          );
        } catch (e) {
          _logger.w('Message not found in current chat data: $messageId');
        }
      }

      // Check permissions if message found
      if (targetMessage != null && !canPinUnpinMessage(targetMessage)) {
        _error = getPinUnpinPermissionText(targetMessage);
        _scheduleNotification();
        return false;
      }

      // If message is currently pinned and no specific duration provided, unpin it
      if (targetMessage?.pinned == true && inDays == 1) {
        inDays = 0; // Set to unpin
      }

      _logger.d(
        'Pin/Unpin message via API - chatId: $chatId, messageId: $messageId, inDays: $inDays',
      );

      // ✅ USE API TO PIN/UNPIN MESSAGE WITH DURATION
      final success = await _chatRepository.pinUnpinMessage(
        chatId: chatId,
        messageId: messageId,
        inDays: inDays,
      );

      if (success && !_isDisposed) {
        // ✅ API SUCCESS - Socket listener will handle UI updates
        // No need to manually refresh as socket will send updated data
        _logger.i('Message pin/unpin successful via API');

        // Optional: Clear any existing error
        _error = null;
        _scheduleNotification();

        return true;
      } else {
        _error = "Failed to pin/unpin message via API";
        _logger.e('Pin/unpin message API returned false');
        _scheduleNotification();
        return false;
      }
    } catch (e) {
      _error = "Failed to pin/unpin message: ${e.toString()}";
      _logger.e('Pin/unpin message error: $e');
      _scheduleNotification();
      return false;
    }
  }

  bool isMessageStarred(int messageId) {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      return false;
    }

    try {
      final message = _chatsData.records!.firstWhere(
        (msg) => msg.messageId == messageId,
      );

      // Check both stared field and starredFor array
      if (message.stared == true) {
        return true;
      }

      // Check if current user is in starredFor array
      if (message.starredFor != null && message.starredFor!.isNotEmpty) {
        return message.starredFor!.contains(_currentUserId);
      }

      return false;
    } catch (e) {
      _logger.w('Message $messageId not found for star check: $e');
      return false;
    }
  }

  /// Star or Unstar a message method
  Future<bool> starUnstarMessage(int messageId) async {
    if (_isDisposed) return false;

    try {
      // Find the message to check permissions and current state
      chats.Records? targetMessage;
      if (_chatsData.records != null) {
        try {
          targetMessage = _chatsData.records!.firstWhere(
            (msg) => msg.messageId == messageId,
          );
        } catch (e) {
          _logger.w('Message not found in current chat data: $messageId');
        }
      }

      // Check permissions if message found
      if (targetMessage != null && !canStarUnStarMessage(targetMessage)) {
        _error = getStarUnstarPermissionText(targetMessage);
        _scheduleNotification();
        return false;
      }

      _logger.d('Star/Unstar message via API - messageId: $messageId');

      // ✅ USE API TO STAR/UNSTAR MESSAGE
      final success = await _chatRepository.starUnStarMessage(
        messageId: messageId,
      );

      if (success && !_isDisposed) {
        // ✅ API SUCCESS - Socket listener will handle UI updates automatically
        _logger.i('Message Star/UnStar successful via API');

        // Optional: Clear any existing error
        _error = null;
        _scheduleNotification();

        // ✅ The socket listener will automatically update the UI when the
        // starUnstarMessage event is received, so no manual update needed here

        return true;
      } else {
        _error = "Failed to Star/UnStar message via API";
        _logger.e('Star/UnStar message API returned false');
        _scheduleNotification();
        return false;
      }
    } catch (e) {
      _error = "Failed to Star/UnStar message: ${e.toString()}";
      _logger.e('Star/UnStar message error: $e');
      _scheduleNotification();
      return false;
    }
  }

  // Handle refreshing chat list
  // Future<void> refreshChatList() async {
  //   if (_isDisposed) return;

  //   try {
  //     await _socketEventController.refreshChatList();
  //   } catch (e) {
  //     _logger.e("Error refreshing chat list: $e");
  //   }
  // }

  /// Handle refreshing chat list (updated for pagination)
  Future<void> refreshChatList() async {
    if (_isDisposed) return;

    try {
      _logger.d("🔄 Refreshing chat list from first page");

      // Set loading state immediately
      _error = null;

      // Reset pagination state
      resetChatListPagination();

      // CRITICAL FIX: Force immediate UI update
      notifyListeners();

      // Request first page
      await emitChatListWithPage(1);
    } catch (e) {
      _logger.e("Error refreshing chat list: $e");
      _error = "Failed to refresh chat list: ${e.toString()}";
      _scheduleNotification();
    }
  }

  Future<void> refreshChatMessages({
    required int chatId,
    required int peerId,
  }) async {
    if (_isDisposed) return;

    // Prevent multiple simultaneous refreshes
    if (isRefreshing) {
      _logger.d('Already refreshing, ignoring duplicate request');
      return;
    }

    try {
      _logger.d(
        "🔄 Starting chat messages refresh - chatId: $chatId, peerId: $peerId",
      );

      // Use the socket controller's dedicated refresh method
      await _socketEventController.refreshChatMessages(chatId, peerId);

      _logger.d("✅ Chat messages refresh completed");
    } catch (e) {
      _logger.e("❌ Error refreshing chat messages: $e");
      _error = "Failed to refresh chat messages: ${e.toString()}";
      _scheduleNotification();
      rethrow;
    }
  }

  void scrollToPinnedMessage(int messageId, ScrollController scrollController) {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      _logger.w('No chat messages to scroll to');
      return;
    }

    try {
      // Find the index of the message in the chat list
      final messageIndex = _chatsData.records!.indexWhere(
        (message) => message.messageId == messageId,
      );

      if (messageIndex != -1) {
        // Highlight the message
        highlightMessage(messageId);

        // Calculate scroll position (approximate)
        // Assuming each message bubble is roughly 80 pixels high
        const double averageMessageHeight = 80.0;
        final double targetPosition = messageIndex * averageMessageHeight;

        // Scroll to the message
        scrollController.animateTo(
          targetPosition,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );

        _logger.d('Scrolling to pinned message at index $messageIndex');
      } else {
        _logger.w(
          'Pinned message with ID $messageId not found in current chat',
        );
      }
    } catch (e) {
      _logger.e('Error scrolling to pinned message: $e');
    }
  }

  String? storyid;

  // ✅ UPDATED: Send message using ChatRepository
  Future<bool> sendMessage(
    String messageContent, {
    required MessageType messageType,
    int? chatId,
    int? userId,
    Uint8List? bytes,
    int? replyToMessageId, // ✅ NEW: Add reply parameter
  }) async {
    if (_isDisposed) return false;

    try {
      _isSendingMessage = true;
      _isShowAttachments = false;
      _scheduleNotification();

      // Determine if this is a new chat
      bool isNewChat = chatId == 0;
      // ✅ FIX: Use userId parameter for new chats, otherwise use peerID from current chat
      final peerID =
          isNewChat && userId != null ? userId : _currentChatData.userId;

      _logger.d(
        'Sending message to ${isNewChat ? "new user" : "existing chat"}: $chatId, peer ID: $peerID, type: $messageType, replyTo: $replyToMessageId',
      );
      // Handle message content for different types
      String finalMessageContent = messageContent;
      if (messageContent.isEmpty) {
        switch (messageType) {
          case MessageType.Video:
            finalMessageContent = "Shared a video";
            break;
          case MessageType.Image:
            finalMessageContent = "Shared an image";
            break;
          case MessageType.File:
            finalMessageContent = "Shared a document";
            break;
          case MessageType.Gif:
            finalMessageContent = "Shared a GIF";
            break;
          case MessageType.StoryReply:
            finalMessageContent = messageContent;
          case MessageType.Voice:
            finalMessageContent = "Shared a voice";
            break;
          default:
            finalMessageContent = messageContent;
        }
      }

      // Prepare file paths for attachments
      Map<String, dynamic> filePaths = {};

      if (MessageTypeUtils.requiresFileUpload(messageType)) {
        _logger.d('Processing file upload for type: $messageType');

        switch (messageType) {
          case MessageType.Voice:
            _logger.d('Added Voice file1: ${_shareVoice!.path}');
            if (_shareVoice != null && _shareVoice != null) {
              filePaths['files'] = _shareVoice!.path;
              _logger.d('Added Voice file2: ${_shareVoice!.path}');
            }
            break;

          case MessageType.Image:
            if (_shareImage != null && _shareImage!.isNotEmpty) {
              filePaths['files'] = _shareImage![0].path;
              _logger.d('Added image file: ${_shareImage![0].path}');
            }
            break;

          case MessageType.File:
            if (_shareDocument != null && _shareDocument!.isNotEmpty) {
              filePaths['files'] = _shareDocument![0].path;
              _logger.d('Added document file: ${_shareDocument![0].path}');
            }
            break;

          case MessageType.Video:
            List<String> videoFiles = [];

            if (_shareVideo != null && _shareVideo!.isNotEmpty) {
              String videoPath = _shareVideo![0].path;
              String thumbnailPath = _shareVideoThumbnail;

              // Generate thumbnail if missing
              if (_shareVideoThumbnail.isEmpty ||
                  !File(_shareVideoThumbnail).existsSync()) {
                _logger.w('Video thumbnail not available, generating...');
                final generatedThumbnail = await generateVideoThumbnail(
                  videoPath,
                );
                if (generatedThumbnail != null &&
                    generatedThumbnail.isNotEmpty) {
                  thumbnailPath = generatedThumbnail;
                  _shareVideoThumbnail = thumbnailPath;
                  _logger.d('Generated thumbnail: $thumbnailPath');
                }
              }

              // Add thumbnail first, then video
              if (thumbnailPath.isNotEmpty &&
                  File(thumbnailPath).existsSync()) {
                videoFiles.add(thumbnailPath);
                _logger.d('Added thumbnail: $thumbnailPath');
              }

              videoFiles.add(videoPath);
              _logger.d('Added video file: $videoPath');

              filePaths['files'] = videoFiles;
            } else {
              _logger.e('No video file available for upload');
              throw Exception('No video file selected');
            }
            break;

          case MessageType.Gif:
            if (_shareImage != null && _shareImage!.isNotEmpty) {
              filePaths['files'] = _shareImage![0].path;
              _logger.d('Added GIF file: ${_shareImage![0].path}');
            }
            break;

          default:
            _logger.w(
              'Unknown message type or no file processing needed: $messageType',
            );
            break;
        }
      }

      // Validate that required files are present
      // Special case: GIF URLs from external sources (like Giphy) don't need files
      bool isGifUrl =
          messageType == MessageType.Gif &&
          messageContent.startsWith('http') &&
          messageContent.contains('gif');

      _logger.d(
        'File upload validation - MessageType: $messageType, RequiresUpload: ${MessageTypeUtils.requiresFileUpload(messageType)}, FilePaths empty: ${filePaths.isEmpty}, IsGifUrl: $isGifUrl, MessageContent: $messageContent',
      );

      if (MessageTypeUtils.requiresFileUpload(messageType) &&
          filePaths.isEmpty &&
          !isGifUrl) {
        _logger.e('File upload validation failed - throwing exception');
        throw Exception(
          'File upload required but no files provided for message type: $messageType',
        );
      }

      _logger.d('File upload validation passed - proceeding with message send');
      _logger.d("messageType:$messageType");

      // ✅ UPDATED: Use ChatRepository to send message
      final response = await _chatRepository.sendMessage(
        chatId: chatId ?? 0,
        messageContent: finalMessageContent,
        messageType: messageType,
        userId: peerID, // Always pass peer ID for new chats and story replies
        filePaths: filePaths.isNotEmpty ? filePaths : null,
        replyToMessageId: replyToMessageId, // ✅ NEW: Pass reply ID,
        storyId:
            messageType == MessageType.StoryReply && storyid != null
                ? int.parse(storyid!)
                : null, // ✅ FIX: Only send storyId for StoryReply messages
      );

      // Process the response
      if (response != null && !_isDisposed) {
        _logger.d('Send message response: $response');

        // Check if API returned status false or if message indicates error
        if (response['status'] == false ||
            (response['message'] != null &&
                response['message'].toString().toLowerCase().contains(
                  "can't send message",
                ))) {
          String errorMessage = response['message'] ?? 'Failed to send message';
          _error = errorMessage;
          _isSendingMessage = false;
          _scheduleNotification();

          // Set error message for UI to show snackbar
          _apiErrorMessage = errorMessage;

          return false;
        }

        //Clear reply state after successful send
        if (replyToMessageId != null) {
          clearReply();
        }

        // ✅ FIX: Clear storyid after successful send to prevent it persisting
        if (messageType == MessageType.StoryReply) {
          storyid = null;
          _logger.d('Cleared storyid after successful story reply');
        }

        // Handle new chat creation and message refresh
        if (isNewChat && response['data'] != null) {
          var newChatId = 0;
          if (response['data']['chat_id'] != null) {
            newChatId = int.parse(response['data']['chat_id'].toString());
          }

          if (newChatId > 0 && !_isDisposed) {
            _logger.i('New chat created with ID: $newChatId');
            _currentChatData = ChatIds(chatId: newChatId, userId: peerID ?? 0);
            _socketEventController.setCurrentChat(newChatId, peerID ?? 0);

            await Future.delayed(Duration(milliseconds: 500));
            if (!_isDisposed) {
              await _socketEventController.emitChatMessages(
                chatId: newChatId,
                peerId: peerID ?? 0,
              );
            }
          }
        } else if (!isNewChat && !_isDisposed) {
          await Future.delayed(Duration(milliseconds: 300));
          if (!_isDisposed) {
            await _socketEventController.emitChatMessages(
              chatId: chatId ?? 0,
              peerId: peerID ?? 0,
            );
          }
        }

        // Clear file storage after successful send
        _shareImage = null;
        _shareDocument = null;
        _shareVideo = null;
        _shareVideoThumbnail = "";

        if (!_isDisposed) {
          refreshChatList();
        }

        _isSendingMessage = false;
        _scheduleNotification();
        return true;
      } else {
        _error = "Failed to send message: Server returned null response";
        _isSendingMessage = false;
        _scheduleNotification();
        return false;
      }
    } catch (e) {
      _error = "Failed to send message: ${e.toString()}";
      _isSendingMessage = false;
      _logger.e('Send message failed: $e');
      _scheduleNotification();

      // Set API error message for UI snackbar display
      if (e is AppError) {
        _apiErrorMessage = e.message;
      } else {
        _apiErrorMessage = "Failed to send message: ${e.toString()}";
      }

      return false;
    }
  }

  // Send typing status
  void sendTypingStatus(int chatId, bool isTyping) {
    if (_isDisposed) return;

    _logger.d(
      "ChatProvider: Sending typing status - ChatId: $chatId, IsTyping: $isTyping",
    );
    _socketEventController.sendTypingIndicator(chatId.toString(), isTyping);
  }

  // Set current chat

  // void setCurrentChat(int chatId, int userId) {
  //   if (_isDisposed) return;

  //   _logger.d("Setting current chat - chatId: $chatId, userId: $userId");

  //   // ✅ CLEAR OLD CHAT DATA FIRST
  //   _chatsData = chats.ChatsModel();
  //   _pinnedMessagesData = chats.ChatsModel(); // ✅ Clear pinned messages
  //   _isPinnedMessagesExpanded = false;
  //   _lastChatsDataHash = null;
  //   clearHighlight();

  //   // ✅ SET NEW CHAT DATA
  //   _currentChatData = ChatIds(chatId: chatId, userId: userId);
  //   _socketEventController.setCurrentChat(chatId, userId);

  //   _scheduleNotification();
  // }

  void setCurrentChat(int chatId, int userId) {
    if (_isDisposed) return;

    _logger.d("Setting current chat - chatId: $chatId, userId: $userId");

    // Clear old chat data first
    _chatsData = chats.ChatsModel();
    _pinnedMessagesData = chats.ChatsModel();
    _isPinnedMessagesExpanded = false;
    _lastChatsDataHash = null;
    _regroupMessages();
    clearHighlight();

    // Set new chat data
    _currentChatData = ChatIds(chatId: chatId, userId: userId);
    _socketEventController.setCurrentChat(chatId, userId);

    // ✅ ENHANCED: Only auto-mark if screen is active and it's an existing chat
    if (chatId > 0) {
      // Longer delay to ensure all chat data is loaded and conditions are stable
      Future.delayed(Duration(milliseconds: 2000), () async {
        if (!_isDisposed &&
            _currentChatData.chatId == chatId &&
            isChatScreenActive &&
            isAppInForeground) {
          // ✅ CRITICAL: Double-check we have messages loaded before marking as seen
          if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
            _logger.d(
              'Chat data loaded and screen active, marking messages as seen',
            );
            await markChatMessagesAsSeen(chatId);
          } else {
            _logger.d('Chat data not yet loaded, skipping auto-mark seen');
          }
        } else {
          _logger.d(
            'Skipping auto-mark seen on setCurrentChat - conditions not met. '
            'disposed: $_isDisposed, '
            'chatMatch: ${_currentChatData.chatId == chatId}, '
            'screenActive: $isChatScreenActive, '
            'appForeground: $isAppInForeground',
          );
        }
      });
    }

    _scheduleNotification();
  }

  void setPinnedMessagesExpanded(bool expanded) {
    if (_isPinnedMessagesExpanded != expanded) {
      _isPinnedMessagesExpanded = expanded;
      _scheduleNotification();
    }
  }

  // ✅ NEW: Reply methods
  void setReplyToMessage(chats.Records? message) {
    _replyToMessage = message;
    _isReplyMode = message != null;
    _scheduleNotification();
  }

  // Set document for sharing
  void setShareDocument(List<File> documents) {
    if (_isDisposed) return;
    _shareDocument = documents;
    _logger.d("Set share document: ${documents.length} files");
    _scheduleNotification();
  }

  // Set image for sharing
  void setShareImage(List<File> images) {
    if (_isDisposed) return;
    _shareImage = images;
    _logger.d("Set share image: ${images.length} files");
    _scheduleNotification();
  }

  void setShareVoice(File voices) {
    if (_isDisposed) return;
    _shareVoice = voices;
    _logger.d("Set share voice: $voices files");
    _scheduleNotification();
  }

  // Set video for sharing
  void setShareVideo(List<File> videos, String thumbnail) {
    if (_isDisposed) return;
    _shareVideo = videos;
    _shareVideoThumbnail = thumbnail;
    _logger.d("Set share video: ${videos.length} files, thumbnail: $thumbnail");
    _scheduleNotification();
  }

  Future<void> setShareVideoWithThumbnail(List<File> videos) async {
    if (_isDisposed || videos.isEmpty) return;

    try {
      _logger.d("Setting share video with thumbnail generation");

      _shareVideo = videos;

      // Generate thumbnail for the first video
      final videoFile = videos.first;
      final thumbnailPath = await generateVideoThumbnail(videoFile.path);

      _shareVideoThumbnail = thumbnailPath ?? "";

      _logger.d(
        "Video set successfully - Video: ${videoFile.path}, Thumbnail: $_shareVideoThumbnail",
      );
      _scheduleNotification();
    } catch (e) {
      _logger.e("Error setting video with thumbnail: $e");
      _shareVideo = videos;
      _shareVideoThumbnail = "";
      _scheduleNotification();
    }
  }

  // Silent refresh that doesn't show loading indicators
  Future<void> silentRefresh() async {
    if (_isDisposed) return;

    try {
      await _socketEventController.silentRefresh();
    } catch (e) {
      _logger.e("Error in silent refresh: $e");
    }
  }

  // ✅ NEW: Stop message search
  void stopMessageSearch() {
    if (!_isSearchingForMessage) {
      _logger.d('⚠️ No active search to stop');
      return;
    }

    _logger.d('🛑 Stopping message search by user request');

    // Call the private method that handles cleanup
    _stopMessageSearch();

    // Optional: Show feedback that search was cancelled
    _logger.i('✅ Message search stopped successfully');
  }

  // Toggle attachment menu
  void toggleAttachments() {
    if (_isDisposed) return;

    _isShowAttachments = !_isShowAttachments;
    _scheduleNotification();
  }

  // ✅ NEW: Pinned messages methods
  void togglePinnedMessagesExpansion() {
    _isPinnedMessagesExpanded = !_isPinnedMessagesExpanded;
    _scheduleNotification();
  }

  // ✅ NEW: Cancel search timeout
  void _cancelSearchTimeout() {
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = null;
  }

  void _clearHighlightSilently() {
    if (_highlightTimer != null) {
      _highlightTimer!.cancel();
      _highlightTimer = null;
    }
    _highlightedMessageId = null;
  }

  // ✅ NEW: Create updated record preserving all data
  chats.Records _createUpdatedRecord(
    chats.Records existing,
    chats.Records updated,
  ) {
    return chats.Records(
      messageContent: existing.messageContent,
      replyTo: existing.replyTo,
      socialId: existing.socialId,
      messageId: existing.messageId,
      messageType: existing.messageType,
      messageLength: existing.messageLength,
      messageSeenStatus: existing.messageSeenStatus,
      messageSize: existing.messageSize,
      deletedFor: existing.deletedFor,
      starredFor: existing.starredFor,
      deletedForEveryone: existing.deletedForEveryone,
      // ✅ UPDATE PIN-RELATED FIELDS
      pinned: updated.pinned,
      pinLifetime: updated.pinLifetime,
      pinnedTill: updated.pinnedTill,
      // ✅ PRESERVE ORIGINAL DATA
      createdAt: existing.createdAt,
      updatedAt: updated.updatedAt ?? existing.updatedAt,
      chatId: existing.chatId,
      senderId: existing.senderId,
      parentMessage: existing.parentMessage,
      replies: existing.replies,
      user: existing.user,
      peerUserData: existing.peerUserData,
    );
  }

  // Dispose of all subscriptions
  void _disposeSubscriptions() {
    _chatListSubscription?.cancel();
    _chatsSubscription?.cancel();
    _chatIdsSubscription?.cancel();
    _onlineUsersSubscription?.cancel();
    _typingSubscription?.cancel();
    _blockUpdatesSubscription?.cancel();
    _pinUnpinSubscription?.cancel();
    _starUnstarSubscription?.cancel();

    _chatListSubscription = null;
    _chatsSubscription = null;
    _chatIdsSubscription = null;
    _onlineUsersSubscription = null;
    _typingSubscription = null;
    _blockUpdatesSubscription = null;
    _pinUnpinSubscription = null;
    _starUnstarSubscription = null;
  }

  /// ✅ NEW: Extract pinned messages from chat response using your actual model
  void _extractPinnedMessages(chats.ChatsModel data) {
    try {
      _logger.d("🔍 Extracting pinned messages from chat data");

      // ✅ PRIORITY 1: Check if socket controller has pinned data first
      final socketPinnedData = _socketEventController.pinnedMessagesData;
      if (socketPinnedData.records != null &&
          socketPinnedData.records!.isNotEmpty) {
        _logger.d(
          "✅ Found ${socketPinnedData.records!.length} pinned messages from socket controller",
        );

        // Verify these belong to current chat
        final currentChatId = _currentChatData.chatId ?? 0;
        if (currentChatId > 0) {
          final relevantPinnedMessages =
              socketPinnedData.records!
                  .where((record) => record.chatId == currentChatId)
                  .toList();

          if (relevantPinnedMessages.isNotEmpty) {
            _pinnedMessagesData = chats.ChatsModel(
              records: relevantPinnedMessages,
              pagination: chats.Pagination(
                totalRecords: relevantPinnedMessages.length,
                currentPage: 1,
                totalPages: 1,
                recordsPerPage: relevantPinnedMessages.length,
              ),
            );
            _logger.d(
              "✅ Set ${relevantPinnedMessages.length} pinned messages from socket controller",
            );
            return;
          }
        }
      }

      // ✅ PRIORITY 2: Extract from current chat data
      if (data.records != null && data.records!.isNotEmpty) {
        final pinnedMessages =
            data.records!.where((record) => record.pinned == true).toList();

        _pinnedMessagesData = chats.ChatsModel(
          records: pinnedMessages,
          pagination: chats.Pagination(
            totalRecords: pinnedMessages.length,
            currentPage: 1,
            totalPages: 1,
            recordsPerPage: pinnedMessages.length,
          ),
        );

        _logger.d(
          "✅ Extracted ${pinnedMessages.length} pinned messages from current chat data",
        );
        return;
      }

      // ✅ DEFAULT: Clear pinned messages if nothing found
      _pinnedMessagesData = chats.ChatsModel();
      _logger.d("No pinned messages found, clearing pinned data");
    } catch (e) {
      _logger.e("❌ Error extracting pinned messages: $e");
      _pinnedMessagesData = chats.ChatsModel();
    }
  }

  // Helper method to generate hash for data comparison
  String _generateDataHash(chats.ChatsModel data) {
    if (data.records == null || data.records!.isEmpty) {
      return 'empty';
    }

    final lastMessage = data.records!.first;
    return '${data.records!.length}_${lastMessage.messageId}_${lastMessage.createdAt}';
  }

  // Initialize subscriptions to SocketEventController streams
  void _initializeSubscriptions() {
    if (_isDisposed) return;

    // Cancel any existing subscriptions first
    _disposeSubscriptions();

    //pin unpin
    _pinUnpinSubscription = _socketEventController.pinUnpinStream.listen(
      (data) {
        if (_isDisposed) return;

        _logger.d(
          "📌 Pin/unpin message update received with ${data.records?.length ?? 0} records",
        );

        // ✅ FIX 1: Process the pin/unpin update immediately
        if (data.records != null && data.records!.isNotEmpty) {
          _processPinUnpinUpdate(data.records!);
        }

        // ✅ FIX 2: Force immediate UI update
        _scheduleNotification();

        _logger.d("✅ Pin/unpin UI data updated successfully");
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Pin/unpin stream error: $error';
        _logger.e('Pin/unpin stream error: $error');
        _scheduleNotification();
      },
    );

    // ✅ NEW: Star/Unstar message listener
    _starUnstarSubscription = _socketEventController.chatsStream.listen(
      (data) {
        if (_isDisposed) return;

        _logger.d("⭐ Received star/unstar update - processing...");

        // Check if this update contains star/unstar changes
        if (data.records != null && data.records!.isNotEmpty) {
          bool hasStarChanges = false;

          for (var record in data.records!) {
            // Check if any message has star-related updates
            if (record.starredFor != null || record.stared != null) {
              hasStarChanges = true;
              break;
            }
          }

          if (hasStarChanges) {
            _logger.d("⭐ Star/unstar changes detected, updating UI");

            // Force immediate UI update for star changes
            _scheduleNotification();
          }
        }
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Star/unstar stream error: $error';
        _logger.e('Star/unstar stream error: $error');
        _scheduleNotification();
      },
    );

    // Subscribe to chat list updates
    // _chatListSubscription = _socketEventController.chatListStream.listen(
    //   (data) {
    //     if (_isDisposed) return;
    //     _logger.d("Chat list updated with ${data.chats?.length ?? 0} chats");
    //     _logger.d("Chat messages response: $data");
    //     _chatListData = data;
    //     _scheduleNotification();
    //   },
    //   onError: (error) {
    //     if (_isDisposed) return;
    //     _error = 'Chat list stream error: $error';
    //     _logger.e('Chat list stream error: $error');
    //     _scheduleNotification();
    //   },
    // );
    _chatListSubscription = _socketEventController.chatListStream.listen(
      (data) {
        if (_isDisposed) return;
        _logger.d("Chat list updated with ${data.chats.length} chats");

        // ✅ NEW: Handle pagination response
        _handleChatListPaginationResponse(data);
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Chat list stream error: $error';
        _logger.e('Chat list stream error: $error');
        _isChatListPaginationLoading = false;
        _scheduleNotification();
      },
    );

    _chatsSubscription = _socketEventController.chatsStream.listen(
      (data) {
        if (_isDisposed) return;

        _logger.d("📨 Received chat data update");

        // ✅ ALWAYS UPDATE MAIN CHAT DATA FIRST
        _chatsData = data;

        // 🗄️ CACHE THE NEW DATA
        _cacheNewChatData(data);

        // ✅ NEW: Regroup messages by date
        _regroupMessages();

        // ✅ CRITICAL: Extract pinned messages BEFORE checking pagination
        _extractPinnedMessages(data);

        // ✅ LOG FOR DEBUGGING
        final recordCount = data.records?.length ?? 0;
        final pinnedCount = _pinnedMessagesData.records?.length ?? 0;
        final pagination = data.pagination;
        final currentPage = pagination?.currentPage ?? 1;

        _logger.d(
          "📊 Chat update - Messages: $recordCount, Pinned: $pinnedCount, Page: $currentPage",
        );

        // ✅ HANDLE CHAT ID UPDATES FOR NEW CHATS
        _updateChatIdIfNeeded(data);

        // ✅ FORCE IMMEDIATE UI UPDATE
        _scheduleNotification();

        // ✅ DEBUG: Log pinned messages state
        if (pinnedCount > 0) {
          _logger.d("✅ Pinned messages available for UI: $pinnedCount");
          for (var pinnedMsg in _pinnedMessagesData.records!) {
            _logger.d(
              "  - Pinned: ${pinnedMsg.messageId} | ${pinnedMsg.messageContent}",
            );
          }
        } else {
          _logger.d("⚠️ No pinned messages in current data");
        }
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Chat messages stream error: $error';
        _logger.e('❌ Chat stream error: $error');
        _scheduleNotification();
      },
    );

    // Subscribe to other streams (chat IDs, online users, typing)
    _chatIdsSubscription = _socketEventController.chatIdsStream.listen(
      (data) {
        if (_isDisposed) return;
        _logger.d("Chat IDs updated");
        _chatIdsData = data;
        _scheduleNotification();
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Chat IDs stream error: $error';
        _logger.e('Chat IDs stream error: $error');
        _scheduleNotification();
      },
    );

    _onlineUsersSubscription = _socketEventController.onlineUsersStream.listen(
      (data) {
        if (_isDisposed) return;
        _onlineUsersData = data;
        _scheduleNotification();
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Online users stream error: $error';
        _logger.e('Online users stream error: $error');
        _scheduleNotification();
      },
    );

    _typingSubscription = _socketEventController.typingStream.listen(
      (data) {
        if (_isDisposed) return;
        _typingData = data;
        _scheduleNotification();
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Typing status stream error: $error';
        _logger.e('Typing status stream error: $error');
        _scheduleNotification();
      },
    );

    // Block updates stream
    _blockUpdatesSubscription = _socketEventController.blockUpdatesStream.listen(
      (data) {
        if (_isDisposed) return;
        _logger.i(
          'Block updates received: userId=${data.userId}, chatId=${data.chatId}, isBlocked=${data.isBlocked}',
        );
        _handleBlockUpdates(data);
      },
      onError: (error) {
        if (_isDisposed) return;
        _error = 'Block updates stream error: $error';
        _logger.e('Block updates stream error: $error');
        _scheduleNotification();
      },
    );

    // Load current user ID for permission checking
    _loadCurrentUserId();

    // Initialize with current data from the controller
    _chatListData = _socketEventController.chatListData;
    _sortChatList(); // Sort the initial data
    _chatsData = _socketEventController.chatsData;
    _chatIdsData = _socketEventController.chatIdsData;
    _onlineUsersData = _socketEventController.onlineUsersData;
    _typingData = _socketEventController.typingData;

    // CRITICAL FIX: Initialize pagination state from existing chat list data
    if (_chatListData.pagination != null) {
      final pagination = _chatListData.pagination!;
      _chatListCurrentPage = pagination.currentPage ?? 1;
      _chatListTotalPages = pagination.totalPages ?? 1;
      _hasChatListMoreData = _chatListCurrentPage < _chatListTotalPages;
      _logger.d(
        '🔄 Initialized pagination from existing data - Page: $_chatListCurrentPage/$_chatListTotalPages, HasMore: $_hasChatListMoreData',
      );
    }

    // Generate initial hash
    _lastChatsDataHash = _generateDataHash(_chatsData);
  }

  bool _isMessageInCurrentData(int messageId) {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      return false;
    }

    return _chatsData.records!.any((record) => record.messageId == messageId);
  }

  // ✅ NEW: Enhanced message matching
  bool _isMessageMatch(chats.Records existing, chats.Records updated) {
    // Primary match: message ID
    if (existing.messageId != null &&
        updated.messageId != null &&
        existing.messageId == updated.messageId) {
      return true;
    }

    // Secondary match: content + sender + chat (for edge cases)
    if (existing.messageContent == updated.messageContent &&
        existing.senderId == updated.senderId &&
        existing.chatId == updated.chatId &&
        existing.createdAt == updated.createdAt) {
      return true;
    }

    return false;
  }

  Future<void> _loadCurrentUserId() async {
    try {
      _currentUserId = await SecurePrefs.getString(SecureStorageKeys.USERID);
      _logger.d('Current user ID loaded: $_currentUserId');
    } catch (e) {
      _logger.e('Error loading current user ID: $e');
    }
  }

  // ✅ NEW: Debug helper method
  void _logCurrentChatState() {
    if (_chatsData.records != null) {
      _logger.d('🔍 Current chat has ${_chatsData.records!.length} messages:');
      for (int i = 0; i < _chatsData.records!.length && i < 3; i++) {
        final msg = _chatsData.records![i];
        _logger.d(
          '  Message ${msg.messageId}: pinned=${msg.pinned}, content="${msg.messageContent}"',
        );
      }
    } else {
      _logger.d('🔍 No messages in current chat');
    }
  }

  void _onMessageFoundAndScroll(int messageId) {
    _logger.d('✅ Message found: $messageId');

    _isMessageFound = true;
    _isSearchingForMessage = false;
    _cancelSearchTimeout();

    // Highlight the message (but don't scroll yet - let the UI handle that)
    highlightMessage(messageId);

    _scheduleNotification();
  }

  void _processPinUnpinUpdate(List<chats.Records> updatedRecords) {
    _logger.d('🔧 Processing ${updatedRecords.length} pin/unpin updates');

    bool hasUpdates = false;

    for (final updatedRecord in updatedRecords) {
      if (updatedRecord.messageId == null) {
        _logger.w('⚠️ Skipping record with null messageId');
        continue;
      }

      // ✅ UPDATE MAIN CHAT DATA
      final mainChatUpdated = _updateMessageInMainChat(updatedRecord);
      if (mainChatUpdated) {
        hasUpdates = true;
        _logger.d('✅ Updated message ${updatedRecord.messageId} in main chat');
      }

      // ✅ UPDATE PINNED MESSAGES COLLECTION
      _updatePinnedMessagesCollection(updatedRecord);
    }

    if (hasUpdates) {
      _logger.d('✅ Successfully processed pin/unpin updates');

      // ✅ FORCE REGENERATE PINNED MESSAGES FROM UPDATED MAIN CHAT
      _regeneratePinnedMessagesFromMainChat();
    } else {
      _logger.w('⚠️ No updates were applied to main chat data');
      _logCurrentChatState(); // Debug helper
    }
  }

  // ✅ NEW: Regenerate pinned messages from main chat (fallback)
  void _regeneratePinnedMessagesFromMainChat() {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      _pinnedMessagesData = chats.ChatsModel();
      return;
    }

    final pinnedMessages =
        _chatsData.records!.where((record) => record.pinned == true).toList();

    _pinnedMessagesData = chats.ChatsModel(
      records: pinnedMessages,
      pagination: chats.Pagination(
        totalRecords: pinnedMessages.length,
        currentPage: 1,
        totalPages: 1,
        recordsPerPage: pinnedMessages.length,
      ),
    );

    _logger.d(
      '🔄 Regenerated ${pinnedMessages.length} pinned messages from main chat',
    );
  }

  // Optimized notification method with debouncing
  void _scheduleNotification() {
    if (_isDisposed) return;

    _shouldNotify = true;
    _notifyTimer?.cancel();
    _notifyTimer = Timer(Duration(milliseconds: 50), () {
      if (_shouldNotify && !_isDisposed) {
        _shouldNotify = false;
        notifyListeners();
      }
    });
  }

  // ignore: unused_element
  Future<void> _searchWithPaginationEnhanced(int messageId) async {
    int searchAttempts = 0;
    const maxSearchAttempts = 15; // Increased attempts

    while (searchAttempts < maxSearchAttempts &&
        _isSearchingForMessage &&
        !_isMessageFound &&
        hasMoreMessages) {
      _logger.d(
        '🔍 Search attempt ${searchAttempts + 1} for message $messageId',
      );

      // Check current data again
      if (_isMessageInCurrentData(messageId)) {
        _onMessageFoundAndScroll(messageId);
        return;
      }

      // Load more messages if available
      if (hasMoreMessages) {
        _logger.d('📄 Loading more messages to find message $messageId');
        await loadMoreMessages();

        // Wait for pagination to complete with better timing
        await _waitForPaginationCompleteEnhanced();

        // Check again after loading with small delay for UI update
        await Future.delayed(Duration(milliseconds: 200));

        if (_isMessageInCurrentData(messageId)) {
          _onMessageFoundAndScroll(messageId);
          return;
        }
      } else {
        _logger.w('⚠️ No more messages to load, message not found');
        break;
      }

      searchAttempts++;
      // Small delay between attempts
      await Future.delayed(Duration(milliseconds: 300));
    }

    // Message not found after all attempts
    if (!_isMessageFound) {
      _logger.w(
        '❌ Message $messageId not found after $searchAttempts attempts',
      );
      _stopMessageSearch();
      _setError('Message not found in chat history');
    }
  }

  void _setError(String errorMessage) {
    _error = errorMessage;
    _logger.e(errorMessage);
    _scheduleNotification();
  }

  // ✅ NEW: Method to set pagination loading
  void _setPaginationLoading(bool loading) {
    if (_isPaginationLoading != loading) {
      _isPaginationLoading = loading;
      _scheduleNotification();
    }
  }

  // ✅ NEW: Start search timeout (prevent infinite search)
  // ignore: unused_element
  void _startSearchTimeout() {
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = Timer(Duration(seconds: 30), () {
      if (_isSearchingForMessage && !_isMessageFound) {
        _logger.w('⏰ Search timeout for message $_targetMessageId');
        _stopMessageSearch();
        _setError('Search timeout: Message not found');
      }
    });
  }

  // ✅ PRIVATE: Internal method to stop search and cleanup
  void _stopMessageSearch() {
    if (_isSearchingForMessage) {
      _logger.d('🧹 Cleaning up search state');
    }

    // Reset all search-related state
    _isSearchingForMessage = false;
    _targetMessageId = null;
    _isMessageFound = false;

    // Cancel any active timers
    _cancelSearchTimeout();

    // Clear any highlights
    _clearHighlightSilently();

    // Notify UI to update
    _scheduleNotification();

    _logger.d('🧹 Search state cleaned up');
  }

  void _updateChatIdIfNeeded(chats.ChatsModel data) {
    // Only update if we don't have a chat ID and we received one
    if ((_currentChatData.chatId == null || _currentChatData.chatId == 0) &&
        data.records != null &&
        data.records!.isNotEmpty) {
      final firstRecord = data.records!.first;
      if (firstRecord.chatId != null && firstRecord.chatId! > 0) {
        _logger.d("📝 Updating chat ID to ${firstRecord.chatId}");

        _currentChatData = ChatIds(
          chatId: firstRecord.chatId!,
          userId: _currentChatData.userId ?? 0,
        );

        _socketEventController.updateCurrentChatId(firstRecord.chatId!);
      }
    }
  }

  bool _updateMessageInMainChat(chats.Records updatedRecord) {
    if (_chatsData.records == null || _chatsData.records!.isEmpty) {
      _logger.w('⚠️ No existing chat messages to update');
      return false;
    }

    for (int i = 0; i < _chatsData.records!.length; i++) {
      final existingMessage = _chatsData.records![i];

      // ✅ MULTIPLE ID MATCHING STRATEGIES
      if (_isMessageMatch(existingMessage, updatedRecord)) {
        // ✅ CREATE COMPLETELY NEW RECORD WITH UPDATED DATA
        final updatedMessage = _createUpdatedRecord(
          existingMessage,
          updatedRecord,
        );

        // ✅ REPLACE THE MESSAGE
        _chatsData.records![i] = updatedMessage;

        _logger.d(
          '📌 Updated message ${existingMessage.messageId}: '
          'pinned ${existingMessage.pinned} -> ${updatedRecord.pinned}',
        );

        return true;
      }
    }

    _logger.w('⚠️ Message ${updatedRecord.messageId} not found in main chat');
    return false;
  }

  // ✅ NEW: Update pinned messages collection
  void _updatePinnedMessagesCollection(chats.Records updatedRecord) {
    _pinnedMessagesData.records ??= [];

    if (updatedRecord.pinned == true) {
      // ✅ MESSAGE WAS PINNED
      final existingIndex = _pinnedMessagesData.records!.indexWhere(
        (msg) => msg.messageId == updatedRecord.messageId,
      );

      if (existingIndex == -1) {
        // Add new pinned message
        _pinnedMessagesData.records!.insert(0, updatedRecord);
        _logger.d(
          '📌 Added message ${updatedRecord.messageId} to pinned collection',
        );
      } else {
        // Update existing pinned message
        _pinnedMessagesData.records![existingIndex] = updatedRecord;
        _logger.d('📌 Updated pinned message ${updatedRecord.messageId}');
      }
    } else {
      // ✅ MESSAGE WAS UNPINNED
      final initialCount = _pinnedMessagesData.records!.length;
      _pinnedMessagesData.records!.removeWhere(
        (msg) => msg.messageId == updatedRecord.messageId,
      );
      final finalCount = _pinnedMessagesData.records!.length;

      if (initialCount > finalCount) {
        _logger.d(
          '📌 Removed message ${updatedRecord.messageId} from pinned collection',
        );
      } else {
        _logger.w(
          '⚠️ Message ${updatedRecord.messageId} was not in pinned collection',
        );
      }
    }

    _updatePinnedMessagesPagination();
  }

  // ✅ NEW: Update pinned messages pagination
  void _updatePinnedMessagesPagination() {
    final pinnedCount = _pinnedMessagesData.records?.length ?? 0;
    _pinnedMessagesData.pagination = chats.Pagination(
      totalRecords: pinnedCount,
      currentPage: 1,
      totalPages: 1,
      recordsPerPage: pinnedCount,
    );
  }

  // 11. ENHANCED: Wait for pagination with better timing
  Future<void> _waitForPaginationCompleteEnhanced() async {
    int waitAttempts = 0;
    const maxWaitAttempts = 30; // Increased wait time

    while (waitAttempts < maxWaitAttempts &&
        (_isPaginationLoading || _socketEventController.isPaginationLoading)) {
      await Future.delayed(Duration(milliseconds: 200)); // Shorter intervals
      waitAttempts++;
    }

    // Additional wait for UI rendering
    await Future.delayed(Duration(milliseconds: 100));
  }
}
// Add these methods to your existing ChatProvider class

extension TypingExtension on ChatProvider {
  /// Get typing user IDs in a chat
  List<int> getTypingUserIdsInChat(int chatId) {
    try {
      if (typingData.typing == true) {
        // Since your TypingModel doesn't seem to have detailed group typing info yet,
        // we'll return an empty list for now
        // Enhance your TypingModel to include user IDs for group typing

        // Example of what this could look like when your socket sends detailed typing data:
        // if (typingData.chatId == chatId && typingData.typingUserIds != null) {
        //   return List<int>.from(typingData.typingUserIds!);
        // }

        _logger.d(
          "getTypingUserIdsInChat called for chat $chatId, but detailed typing data not available yet",
        );
        return [];
      }
      return [];
    } catch (e) {
      _logger.e("Error getting typing user IDs: $e");
      return [];
    }
  }

  /// Get typing users in a group chat (enhanced)
  List<String> getTypingUsersInChat(int chatId) {
    try {
      if (typingData.typing == true) {
        // For now, return empty list until your socket provides detailed typing info
        // Parse typing data to extract user names for the specific chat

        // Example implementation when you have detailed typing data:
        // if (typingData.chatId == chatId && typingData.typingUsers != null) {
        //   return List<String>.from(typingData.typingUsers!);
        // }

        _logger.d(
          "getTypingUsersInChat called for chat $chatId, but detailed typing data not available yet",
        );
        return [];
      }
      return [];
    } catch (e) {
      _logger.e("Error getting typing users: $e");
      return [];
    }
  }

  /// Extract group members from message list
  Map<int, chats.User> extractGroupMembersFromMessages(
    List<chats.Records> messages,
  ) {
    Map<int, chats.User> membersMap = <int, chats.User>{};

    for (final message in messages) {
      if (message.user != null && message.senderId != null) {
        final userId = message.senderId!;
        final user = message.user!;

        // Add or update user in the map
        if (!membersMap.containsKey(userId)) {
          membersMap[userId] = user;
          _logger.d("Found group member: ${user.fullName} (ID: $userId)");
        } else {
          // Update user info if it's newer
          final existingUser = membersMap[userId]!;
          if (_isUserInfoNewer(user, existingUser)) {
            membersMap[userId] = user;
            _logger.d(
              "Updated group member info: ${user.fullName} (ID: $userId)",
            );
          }
        }
      }
    }

    _logger.d("Extracted ${membersMap.length} group members from messages");
    return membersMap;
  }

  bool _isUserInfoNewer(chats.User newUser, chats.User existingUser) {
    // Compare updated timestamps
    if (newUser.updatedAt != null && existingUser.updatedAt != null) {
      final newTime = DateTime.tryParse(newUser.updatedAt!);
      final existingTime = DateTime.tryParse(existingUser.updatedAt!);
      if (newTime != null && existingTime != null) {
        return newTime.isAfter(existingTime);
      }
    }

    // If no timestamp, prefer non-empty profile data
    if (newUser.profilePic?.isNotEmpty == true &&
        existingUser.profilePic?.isEmpty == true) {
      return true;
    }

    return false; // Keep existing if can't determine
  }

  /// Determine if a chat is a group chat based on message data
  bool isGroupChatFromMessages(List<chats.Records> messages) {
    if (messages.isEmpty) return false;

    // Check for group creation message
    final hasGroupCreatedMessage = messages.any(
      (msg) => msg.messageType?.toLowerCase() == 'group-created',
    );

    if (hasGroupCreatedMessage) return true;

    // Count unique senders (excluding current user)
    final uniqueSenders = <int>{};
    for (final message in messages) {
      if (message.senderId != null) {
        uniqueSenders.add(message.senderId!);
      }
    }

    // If more than 2 unique senders, it's likely a group
    return uniqueSenders.length > 2;
  }

  /// Get online members count for a group
  int getOnlineGroupMembersCount(Map<int, User> groupMembers) {
    return groupMembers.values
        .where((user) => isUserOnline(user.userId ?? 0))
        .length;
  }

  /// ✅ NEW DEBUG METHOD: Get comprehensive debug info about message seen emissions
  Map<String, dynamic> getMessageSeenDebugInfo(int chatId) {
    final unreadMessages =
        _chatsData.records
            ?.where(
              (message) =>
                  message.senderId?.toString() != userID &&
                  message.messageSeenStatus != 'seen' &&
                  message.messageId != null &&
                  message.deletedForEveryone != true,
            )
            .toList() ??
        [];

    final emissionStats = _socketEventController.getEmissionStats();

    return {
      'chatId': chatId,
      'unreadMessagesFound': unreadMessages.length,
      'unreadMessageIds': unreadMessages.map((m) => m.messageId).toList(),
      'currentScreenState': {
        'isChatScreenActive': isChatScreenActive,
        'isAppInForeground': isAppInForeground,
        'isDisposed': _isDisposed,
        'currentChatId': _currentChatData.chatId,
      },
      'socketEmissionStats': emissionStats,
      'unseenCount': getChatUnseenCount(chatId),
    };
  }

  /// ✅ MANUAL TRIGGER: Force debug the 7 vs 4 emission issue
  Future<void> debugMessageSeenEmissions(int chatId) async {
    _logger.i(
      '🔍 MANUAL DEBUG: Starting message seen emission analysis for chat $chatId',
    );

    // Get pre-debug state
    final preDebugInfo = getMessageSeenDebugInfo(chatId);
    _logger.i('📊 PRE-DEBUG STATE: $preDebugInfo');

    // Clear emission tracking to start fresh
    _socketEventController.clearEmissionTracking();

    // Try to mark messages as seen with full debugging
    await markChatMessagesAsSeen(chatId);

    // Get post-debug state
    final postDebugInfo = getMessageSeenDebugInfo(chatId);
    _logger.i('📊 POST-DEBUG STATE: $postDebugInfo');

    // Compare and report
    final intendedEmissions = preDebugInfo['unreadMessagesFound'] as int;
    final actualEmissions =
        postDebugInfo['socketEmissionStats']['totalEmissions'] as int;

    if (intendedEmissions != actualEmissions) {
      _logger.e('🚨 CONFIRMED DISCREPANCY:');
      _logger.e('  - Intended emissions: $intendedEmissions');
      _logger.e('  - Actual emissions: $actualEmissions');
      _logger.e(
        '  - Missing: ${intendedEmissions - actualEmissions} emissions',
      );
      _logger.e(
        '  - SUCCESS RATE: ${(actualEmissions / intendedEmissions * 100).toStringAsFixed(1)}%',
      );
    } else {
      _logger.i('✅ NO DISCREPANCY: All intended messages were emitted');
    }
  }

  /// Enhanced mark messages as seen for both individual and group chats
  Future<void> markChatMessagesAsSeen(
    int chatId, {
    bool isGroupChat = false,
  }) async {
    if (_isDisposed || chatId <= 0) return;

    // Check if screen is active and app is in foreground
    if (!isChatScreenActive || !isAppInForeground) {
      _logger.d(
        'Skipping mark messages as seen - screen not active or app in background. '
        'screenActive: $isChatScreenActive, appForeground: $isAppInForeground',
      );
      return;
    }

    // Ensure we're viewing the correct chat
    if (_currentChatData.chatId != chatId) {
      _logger.d(
        'Skipping mark messages as seen - chat ID mismatch. '
        'current: ${_currentChatData.chatId}, requested: $chatId',
      );
      return;
    }

    try {
      // Get current user ID
      final currentUserId = await _getCurrentUserId();
      if (currentUserId == null) {
        _logger.w(
          'Cannot mark messages as seen - current user ID not available',
        );
        return;
      }

      // Find unread messages from OTHER users only
      final unreadMessages =
          _chatsData.records
              ?.where(
                (message) =>
                    message.senderId?.toString() !=
                        currentUserId && // Only messages from other users
                    message.messageSeenStatus != 'seen' &&
                    message.messageId != null &&
                    message.deletedForEveryone !=
                        true, // Don't mark deleted messages
              )
              .toList() ??
          [];

      if (unreadMessages.isNotEmpty) {
        _logger.d(
          'Marking ${unreadMessages.length} messages from OTHER users as seen '
          'in ${isGroupChat ? 'group' : 'individual'} chat '
          '(screen is active and app in foreground)',
        );

        // Batch processing to avoid overwhelming the server
        const batchSize = 3;
        for (int i = 0; i < unreadMessages.length; i += batchSize) {
          // Check if conditions are still met before each batch
          if (!isChatScreenActive || !isAppInForeground || _isDisposed) {
            _logger.d('Conditions changed, stopping seen marking');
            break;
          }

          final batch = unreadMessages.skip(i).take(batchSize).toList();

          for (var message in batch) {
            // Final check before marking each message
            if (!isChatScreenActive || _isDisposed) {
              _logger.d('Screen became inactive, stopping seen marking');
              return;
            }

            _logger.d(
              'Marking message ${message.messageId} as seen '
              '(from user ${message.senderId}, current user $currentUserId)',
            );

            await markMessageAsSeen(chatId, message.messageId!);
            await Future.delayed(Duration(milliseconds: 150));
          }

          // Longer delay between batches
          if (i + batchSize < unreadMessages.length) {
            await Future.delayed(Duration(milliseconds: 300));
          }
        }

        _logger.i(
          'Successfully processed ${unreadMessages.length} unread messages from other users in ${isGroupChat ? 'group' : 'individual'} chat',
        );
      } else {
        _logger.d('No unread messages from other users to mark as seen');
      }
    } catch (e) {
      _logger.e('Error marking chat messages as seen: $e');
    }
  }

  /// Block or unblock a user
  /// Uses the existing ChatRepository.blockUnblockUser method
  /// Fixed to use actual API response instead of toggle logic
  Future<bool> blockUnblockUser(int userId, int chatId) async {
    if (_isDisposed) return false;

    try {
      _logger.d(
        'Block/Unblock user via API - userId: $userId, chatId: $chatId',
      );

      // Check current block status BEFORE making API call
      final existingBlockIndex = _blockedUsers.indexWhere(
        (record) => record.blockedId == userId,
      );
      bool wasBlocked = existingBlockIndex != -1;

      _logger.d(
        'User $userId was ${wasBlocked ? 'blocked' : 'not blocked'} before API call',
      );

      // Make API call and get actual response
      final response = await _chatRepository.blockUnblockUser(userId, chatId);

      if (response != null && response['success'] == true && !_isDisposed) {
        _logger.i('User block/unblock successful via API');

        // Use ACTUAL block status from API response, not toggle logic
        final isNowBlocked = response['is_blocked'] as bool;
        final message = response['message'] as String;

        _logger.d(
          'API says user is now ${isNowBlocked ? 'BLOCKED' : 'UNBLOCKED'}: $message',
        );

        // Update local blocked users list based on ACTUAL API response
        if (isNowBlocked) {
          // User is now BLOCKED according to API
          if (existingBlockIndex == -1) {
            // Add to blocked list if not already there
            final blockedRecord = BlockedUserRecord(
              blockId: DateTime.now().millisecondsSinceEpoch, // Temporary ID
              blockedId: userId,
              userId: int.tryParse(_currentUserId ?? '0') ?? 0,
              approved: true,
              createdAt: DateTime.now().toIso8601String(),
              blocked: null, // Will be populated by background refresh
            );
            _blockedUsers.insert(0, blockedRecord); // Add to front of list
            _logger.d('✅ Added user $userId to blocked list (now blocked)');
          }
        } else {
          // User is now UNBLOCKED according to API
          if (existingBlockIndex != -1) {
            // Remove from blocked list
            _blockedUsers.removeAt(existingBlockIndex);
            _logger.d(
              '✅ Removed user $userId from blocked list (now unblocked)',
            );
          }
        }

        // Update chat list to reflect ACTUAL block status from API using new structure
        // ✅ FIXED: Use current user ID, not the peer user ID for blocked_by array
        final currentUserIdInt = int.tryParse(_currentUserId ?? '0') ?? 0;
        _updateBlockedByInChatRecords(chatId, currentUserIdInt, isNowBlocked);

        // Notify listeners IMMEDIATELY for instant UI feedback
        _scheduleNotification();

        // Background refresh to sync with server (non-blocking)
        _performBackgroundBlockSync();

        _error = null;
        return true;
      } else {
        _error = response?['message'] ?? "Failed to block/unblock user via API";
        _logger.e('Block/unblock user API failed: $_error');
        _scheduleNotification();
        return false;
      }
    } catch (e) {
      _error = "Error blocking/unblocking user: $e";
      _logger.e('Block/unblock user error: $e');
      _scheduleNotification();
      return false;
    }
  }

  /// Background sync for block operations to ensure server consistency
  void _performBackgroundBlockSync() {
    Future.microtask(() async {
      try {
        // Small delay to prevent API conflicts
        await Future.delayed(Duration(milliseconds: 500));
        if (!_isDisposed) {
          await loadBlockedUsers(page: 1); // Refresh blocked users list
          _logger.d('🔄 Background block sync completed');
        }
      } catch (e) {
        _logger.w('Background block sync failed (non-critical): $e');
      }
    });
  }

  /// Clear all messages from a chat or delete the chat via API
  /// Uses the ChatRepository.clearChat method
  /// [deleteChat] - If true, deletes the chat entirely. If false, only clears messages
  Future<bool> clearChat({required int chatId, bool deleteChat = false}) async {
    if (_isDisposed) return false;
    try {
      _logger.d(
        '${deleteChat ? 'Deleting' : 'Clearing'} chat via API - chatId: $chatId',
      );
      final success = await _chatRepository.clearChat(
        chatId: chatId,
        deleteChat: deleteChat,
      );

      if (success && !_isDisposed) {
        _logger.i('Chat ${deleteChat ? 'delete' : 'clear'} successful via API');

        // =============================================
        // CLEAR ALL LOCAL DATA FOR THIS CHAT
        // =============================================

        // 1. Clear local messages for this chat
        _groupedMessages.removeWhere((key, messageList) {
          // Remove all message groups that belong to this chat
          return messageList.any((message) => message.chatId == chatId);
        });
        _logger.d('🗑️ Cleared grouped messages for chat $chatId');

        // 1.1. Also clear current chat data if this is the active chat
        if (_currentChatData.chatId == chatId) {
          _chatsData = chats.ChatsModel();
          _pinnedMessagesData = chats.ChatsModel();
          _lastChatsDataHash = null;
          _regroupMessages();
          _logger.d('🗑️ Cleared current chat data for active chat $chatId');
        }

        // 2. Clear local cache for this chat
        await _clearLocalCacheForChat(chatId);

        // 3. Clear unseen count for this chat
        clearChatUnseenCount(chatId);
        _logger.d('🗑️ Cleared unseen count for chat $chatId');

        // 4. If deleting the chat, also remove it from the chat list
        if (deleteChat) {
          _chatListData.chats.removeWhere(
            (chat) =>
                chat.records?.any((record) => record.chatId == chatId) ?? false,
          );
          _logger.d('🗑️ Removed chat $chatId from chat list data');
        } else {
          // If only clearing messages, update the chat item to show no messages
          _updateChatListAfterClear(chatId);
        }

        // Notify listeners about the change
        _scheduleNotification();

        // Refresh chat list to ensure UI reflects the changes
        await refreshChatList();

        // 🛡️ SAFETY CHECK: Verify that the chat is actually cleared by checking server
        await _verifyChatCleared(chatId);

        _logger.i(
          '✅ Chat ${deleteChat ? 'delete' : 'clear'} completed successfully',
        );
        return true;
      } else {
        _error = "Failed to ${deleteChat ? 'delete' : 'clear'} chat";
        _logger.w(
          '${deleteChat ? 'Delete' : 'Clear'} chat failed - Invalid response',
        );
        _scheduleNotification();
        return false;
      }
    } catch (e) {
      _error = "Error ${deleteChat ? 'deleting' : 'clearing'} chat: $e";
      _logger.e('${deleteChat ? 'Delete' : 'Clear'} chat error: $e');
      _scheduleNotification();
      return false;
    }
  }

  /// Clear local cache for a specific chat
  Future<void> _clearLocalCacheForChat(int chatId) async {
    try {
      // Determine cache key format
      final chatIdString = chatId.toString();

      // Clear chat cache using ChatCacheManager
      await ChatCacheManager.clearChat(chatIdString);
      _logger.d('🗄️ Cleared cache for chat: $chatIdString');

      // Also clear user-based cache key if this is a private chat
      // Check if this chatId corresponds to a private chat by looking in current chat data
      for (final chat in _chatListData.chats) {
        if (chat.records != null) {
          for (final record in chat.records!) {
            if (record.chatId == chatId && record.chatType == 'private') {
              // This is a private chat, also clear user-based cache
              final peerUserData = chat.peerUserData;
              if (peerUserData?.userId != null) {
                final userCacheKey = 'user_${peerUserData!.userId}';
                await ChatCacheManager.clearChat(userCacheKey);
                _logger.d('🗄️ Cleared user cache for key: $userCacheKey');
              }
              break;
            }
          }
        }
      }
    } catch (e) {
      _logger.e('❌ Error clearing local cache for chat $chatId: $e');
    }
  }

  /// Update chat list after clearing messages (but not deleting chat)
  void _updateChatListAfterClear(int chatId) {
    try {
      // Find and update the chat in the chat list to reflect no messages
      for (final chat in _chatListData.chats) {
        if (chat.records != null) {
          for (final record in chat.records!) {
            if (record.chatId == chatId) {
              // Clear messages and reset counts
              record.messages?.clear();
              record.unseenCount = 0;
              _logger.d('🔄 Updated chat list item for cleared chat $chatId');
              break;
            }
          }
        }
      }
    } catch (e) {
      _logger.e('❌ Error updating chat list after clear: $e');
    }
  }

  /// Verify that the chat was actually cleared on the server
  Future<void> _verifyChatCleared(int chatId) async {
    try {
      _logger.d('🔍 Verifying chat $chatId was cleared on server...');

      // Wait a bit for server-side clearing to complete
      await Future.delayed(Duration(milliseconds: 1500));

      // Set a flag to indicate this chat was recently cleared
      _recentlyClearedChats.add(chatId);

      // Remove the flag after 30 seconds (enough time for user to navigate)
      Future.delayed(Duration(seconds: 30), () {
        _recentlyClearedChats.remove(chatId);
      });

      _logger.d('✅ Chat $chatId marked as recently cleared');
    } catch (e) {
      _logger.e('❌ Error verifying chat cleared: $e');
    }
  }

  /// Check if a user is blocked
  bool isUserBlocked(int userId) {
    return _blockedUsers.any(
      (blockedRecord) => blockedRecord.blockedId == userId,
    );
  }

  /// Check if a user is blocked with real-time data refresh across all pages
  Future<bool> isUserBlockedRealTime(int userId) async {
    try {
      // First check in current cached list
      bool foundInCache = _blockedUsers.any(
        (blockedRecord) => blockedRecord.blockedId == userId,
      );

      if (foundInCache) {
        return true;
      }

      // If not found in cache, search across all pages
      return await _searchUserInAllBlockedPages(userId);
    } catch (e) {
      _logger.e('Error checking real-time block status: $e');
      // Fallback to cached data if API fails
      return _blockedUsers.any(
        (blockedRecord) => blockedRecord.blockedId == userId,
      );
    }
  }

  /// Search for a user across all blocked user pages with a limit of 30 pages
  Future<bool> _searchUserInAllBlockedPages(int userId) async {
    try {
      int currentPage = 1;
      bool hasMorePages = true;
      const int maxPages = 30; // Limit search to 30 pages for performance

      while (hasMorePages && currentPage <= maxPages) {
        _logger.d(
          'Searching for user $userId in blocked list page $currentPage',
        );

        final blockedUserModel = await _chatRepository.getBlockedUsers(
          currentPage,
        );

        if (blockedUserModel?.records != null) {
          // Check if user is in current page
          bool foundInCurrentPage = blockedUserModel!.records!.any(
            (record) => record.blockedId == userId,
          );

          if (foundInCurrentPage) {
            _logger.d('Found user $userId in blocked list page $currentPage');
            // Add this page's data to cache if not already cached
            bool pageAlreadyCached = _blockListCurrentPage >= currentPage;
            if (!pageAlreadyCached) {
              _blockedUsers.addAll(blockedUserModel.records!);
              _blockListCurrentPage = currentPage;
            }
            return true;
          }

          // Check if there are more pages
          if (blockedUserModel.pagination != null) {
            hasMorePages =
                currentPage < (blockedUserModel.pagination!.totalPages ?? 1);
          } else {
            hasMorePages = blockedUserModel.records!.isNotEmpty;
          }
        } else {
          hasMorePages = false;
        }

        currentPage++;
      }

      if (currentPage > maxPages) {
        _logger.w(
          'Reached maximum page limit ($maxPages) while searching for user $userId in blocked list',
        );
      }

      _logger.d(
        'User $userId not found in blocked list (searched $currentPage pages)',
      );
      return false;
    } catch (e) {
      _logger.e('Error searching user across blocked pages: $e');
      return false;
    }
  }

  /// Refresh block status for UI updates - call this when opening profile views
  /// Optimized to prevent unnecessary refreshes and maintain UI responsiveness
  Future<void> refreshBlockStatus() async {
    try {
      _logger.d('🔄 Refreshing block status for UI consistency');

      // Load first page and clear existing cache for fresh data
      await loadBlockedUsers(page: 1);

      // Trigger UI update only if not disposed
      if (!_isDisposed) {
        _scheduleNotification();
      }

      _logger.d('✅ Block status refresh completed');
    } catch (e) {
      _logger.e('Error refreshing block status: $e');
    }
  }

  /// Optimized method to sync block status when app comes to foreground
  /// This helps catch block status changes that happened while app was inactive
  Future<void> syncBlockStatusOnForeground() async {
    try {
      _logger.d('🔄 Syncing block status due to app foreground');

      // Only refresh if we haven't refreshed recently (prevent spam)
      final now = DateTime.now();
      final lastRefreshTime =
          _blockListCurrentPage > 0
              ? now.subtract(Duration(minutes: 2))
              : DateTime(2000);

      if (now.difference(lastRefreshTime).inMinutes < 1) {
        _logger.d('⏭️ Skipping block sync - refreshed recently');
        return;
      }

      // Background sync to avoid blocking UI
      Future.microtask(() async {
        await refreshBlockStatus();
      });
    } catch (e) {
      _logger.e('Error syncing block status on foreground: $e');
    }
  }

  /// Check if current user is blocked by another user (for chat status)
  bool isCurrentUserBlockedBy(int userId, String currentUserId) {
    // Find chat record for this user
    for (final chat in _chatListData.chats) {
      if (chat.peerUserData?.userId == userId) {
        for (final record in chat.records ?? []) {
          if (record.blockedBy != null) {
            // BIDIRECTIONAL BLOCKING: If anyone has blocked this chat, both users should see blocked UI
            return record.blockedBy!.isNotEmpty;
          }
        }
      }
    }
    return false;
  }

  /// Load blocked users list
  Future<void> loadBlockedUsers({int page = 1}) async {
    if (_isDisposed) return;

    try {
      if (page == 1) {
        _isBlockListLoading = true;
        _blockedUsers.clear();
        _blockListCurrentPage = 1;
        _hasMoreBlockedUsers = true;
      }

      _logger.d('Loading blocked users - page: $page');

      final blockedUserModel = await _chatRepository.getBlockedUsers(page);

      if (blockedUserModel != null && !_isDisposed) {
        if (blockedUserModel.records != null) {
          _blockedUsers.addAll(blockedUserModel.records!);
          _logger.d(
            'Added ${blockedUserModel.records!.length} blocked users to list',
          );

          // Update pagination info
          _blockListCurrentPage = page;
          if (blockedUserModel.pagination != null) {
            _hasMoreBlockedUsers =
                page < (blockedUserModel.pagination!.totalPages ?? 1);
          } else {
            _hasMoreBlockedUsers = blockedUserModel.records!.isNotEmpty;
          }
        } else {
          _hasMoreBlockedUsers = false;
        }

        _error = null;
      } else {
        _error = "Failed to load blocked users";
        _logger.e('Load blocked users API returned null');
      }
    } catch (e) {
      _error = "Error loading blocked users: $e";
      _logger.e('Load blocked users error: $e');
    } finally {
      _isBlockListLoading = false;
      _scheduleNotification();
    }
  }

  /// Check if current chat is blocked
  bool isCurrentChatBlocked() {
    if (_chatListData.chats.isEmpty ||
        _currentChatData.chatId == null ||
        _currentUserId == null) {
      return false;
    }

    try {
      final currentChatData = _chatListData.chats.firstWhere(
        (chat) =>
            chat.records?.any(
              (record) => record.chatId == _currentChatData.chatId,
            ) ==
            true,
        orElse: () => Chats(),
      );

      final record = currentChatData.records?.firstWhere(
        (record) => record.chatId == _currentChatData.chatId,
        orElse: () => Records(),
      );

      // BIDIRECTIONAL BLOCKING: If anyone has blocked this chat, both users should see blocked UI
      return record?.blockedBy?.isNotEmpty ?? false;
    } catch (e) {
      _logger.e('Error checking current chat block status: $e');
      return false;
    }
  }

  /// Get block status from chat list
  bool getChatBlockStatus(int chatId) {
    if (_currentUserId == null) return false;

    try {
      final chatData = _chatListData.chats.firstWhere(
        (chat) =>
            chat.records?.any((record) => record.chatId == chatId) == true,
        orElse: () => Chats(),
      );

      final record = chatData.records?.firstWhere(
        (record) => record.chatId == chatId,
        orElse: () => Records(),
      );

      // BIDIRECTIONAL BLOCKING: If anyone has blocked this chat, both users should see blocked UI
      // This ensures that when User A blocks User B, both users see blocked state and cannot message
      final hasBlockedUsers = record?.blockedBy?.isNotEmpty ?? false;

      if (hasBlockedUsers) {
        _logger.d(
          'Chat $chatId has blocked users: ${record?.blockedBy}. Showing blocked UI for current user $_currentUserId',
        );
      }

      return hasBlockedUsers;
    } catch (e) {
      _logger.e('Error getting chat block status: $e');
      return false;
    }
  }

  /// Get block status from chat list with real-time data refresh
  Future<bool> getChatBlockStatusRealTime(int chatId) async {
    if (_currentUserId == null) return false;

    try {
      // First refresh the chat list to get latest data
      await refreshChatList();

      // Then check the block status from updated data
      final chatData = _chatListData.chats.firstWhere(
        (chat) =>
            chat.records?.any((record) => record.chatId == chatId) == true,
        orElse: () => Chats(),
      );

      final record = chatData.records?.firstWhere(
        (record) => record.chatId == chatId,
        orElse: () => Records(),
      );

      // BIDIRECTIONAL BLOCKING: If anyone has blocked this chat, both users should see blocked UI
      // This ensures that when User A blocks User B, both users see blocked state and cannot message
      final hasBlockedUsers = record?.blockedBy?.isNotEmpty ?? false;

      if (hasBlockedUsers) {
        _logger.d(
          'Real-time check - Chat $chatId has blocked users: ${record?.blockedBy}. Showing blocked UI for current user $_currentUserId',
        );
      }

      return hasBlockedUsers;
    } catch (e) {
      _logger.e('Error getting real-time chat block status: $e');
      // Fallback to cached data if API fails
      return getChatBlockStatus(chatId);
    }
  }

  /// Get instant block status for navigation (without API call)
  /// Used to determine initial UI state when navigating to chat
  bool getInstantBlockStatus(int chatId) {
    if (_currentUserId == null) return false;

    try {
      final chatData = _chatListData.chats.firstWhere(
        (chat) =>
            chat.records?.any((record) => record.chatId == chatId) == true,
        orElse: () => Chats(),
      );

      final record = chatData.records?.firstWhere(
        (r) => r.chatId == chatId,
        orElse: () => Records(),
      );

      // ✅ FIXED: Check if CURRENT USER has blocked this chat (for UserProfileView button display)
      return record?.blockedBy?.contains(_currentUserId) ?? false;
    } catch (e) {
      _logger.e('Error getting instant block status: $e');
      return false;
    }
  }

  /// Get instant block status by peer user ID (for individual chats)
  bool getInstantBlockStatusByUserId(int userId) {
    if (_currentUserId == null) return false;

    try {
      for (final chat in _chatListData.chats) {
        if (chat.peerUserData?.userId == userId) {
          for (final record in chat.records ?? []) {
            // ✅ FIXED: Check if CURRENT USER has blocked this chat (for UserProfileView button display)
            return record.blockedBy?.contains(_currentUserId) ?? false;
          }
        }
      }
      return false;
    } catch (e) {
      _logger.e('Error getting instant block status by user ID: $e');
      return false;
    }
  }

  /// Check if current user is the one who blocked (can unblock)
  bool isCurrentUserTheBlocker(int chatId) {
    if (_currentUserId == null) return false;

    try {
      final chatData = _chatListData.chats.firstWhere(
        (chat) =>
            chat.records?.any((record) => record.chatId == chatId) == true,
        orElse: () => Chats(),
      );

      final record = chatData.records?.firstWhere(
        (r) => r.chatId == chatId,
        orElse: () => Records(),
      );

      // Check if current user is in the blocked_by list (meaning they blocked the other user)
      return record?.blockedBy?.contains(_currentUserId) ?? false;
    } catch (e) {
      _logger.e('Error checking if current user is blocker: $e');
      return false;
    }
  }

  /// Check if current user is the one who blocked by peer user ID
  bool isCurrentUserTheBlockerByUserId(int userId) {
    if (_currentUserId == null) return false;

    try {
      for (final chat in _chatListData.chats) {
        if (chat.peerUserData?.userId == userId) {
          for (final record in chat.records ?? []) {
            // Check if current user is in the blocked_by list (meaning they blocked the other user)
            return record.blockedBy?.contains(_currentUserId) ?? false;
          }
        }
      }
      return false;
    } catch (e) {
      _logger.e('Error checking if current user is blocker by user ID: $e');
      return false;
    }
  }

  // =================================================================
  // NEW PROPER BLOCK STATUS METHODS
  // =================================================================

  /// Get block scenario for a specific chat using new blocked_by structure
  /// Returns: 'none', 'user_blocked_other', 'user_blocked_by_other', 'mutual_block'
  String getBlockScenario(int? chatId, int? userId) {
    if (_currentUserId == null) return 'none';

    try {
      List<String>? blockedBy;
      String? peerUserId;

      if (chatId != null) {
        final chatData = _chatListData.chats.firstWhere(
          (chat) => chat.records?.any((r) => r.chatId == chatId) == true,
          orElse: () => Chats(),
        );
        final record = chatData.records?.firstWhere(
          (r) => r.chatId == chatId,
          orElse: () => Records(),
        );
        blockedBy = record?.blockedBy;
        peerUserId = chatData.peerUserData?.userId?.toString();

        // Debug logging for mutual block issues
        _logger.d(
          '🔍 Block scenario check - ChatId: $chatId, PeerUserId: $peerUserId, CurrentUserId: $_currentUserId',
        );
        _logger.d('🔍 BlockedBy array: ${blockedBy?.join(", ")}');

        // Additional debug for chat data structure
        _logger.d(
          '🔍 Chat data found: ${chatData.records?.isNotEmpty == true}',
        );
        if (record?.blockedBy != null) {
          _logger.d('🔍 Record found with blockedBy: ${record!.blockedBy}');
        }
      } else if (userId != null) {
        peerUserId = userId.toString();

        // Find the chat record for this user
        bool foundChat = false;
        for (final chat in _chatListData.chats) {
          if (chat.peerUserData?.userId == userId) {
            for (final record in chat.records ?? []) {
              blockedBy = record.blockedBy;
              foundChat = true;
              break;
            }
            break;
          }
        }

        // Debug logging for mutual block issues
        _logger.d(
          '🔍 Block scenario check - UserId: $userId, CurrentUserId: $_currentUserId, FoundChat: $foundChat',
        );
        _logger.d('🔍 BlockedBy array: ${blockedBy?.join(", ")}');
      }

      if (blockedBy == null || blockedBy.isEmpty) {
        _logger.d('🔍 Result: none (blockedBy is null or empty)');
        return 'none'; // No block in place
      }

      // - If currentUserId is in blocked_by = user blocked this chat
      // - If peerUserId is in blocked_by = peer blocked this chat
      final currentUserBlocked = blockedBy.contains(_currentUserId);
      final peerUserBlocked =
          peerUserId != null ? blockedBy.contains(peerUserId) : false;

      _logger.d(
        '🔍 currentUserBlocked: $currentUserBlocked, peerUserBlocked: $peerUserBlocked',
      );

      if (currentUserBlocked && peerUserBlocked) {
        _logger.d('🔍 Result: mutual_block');
        return 'mutual_block'; // Both users blocked this chat
      } else if (currentUserBlocked) {
        _logger.d('🔍 Result: user_blocked_other');
        return 'user_blocked_other'; // Current user blocked this chat
      } else if (peerUserBlocked) {
        _logger.d('🔍 Result: user_blocked_by_other');
        return 'user_blocked_by_other'; // Peer user blocked this chat (current user is blocked)
      }

      _logger.d('🔍 Result: none (fallback)');
      return 'none';
    } catch (e) {
      _logger.e('Error getting block scenario: $e');
      return 'none';
    }
  }

  /// Check if chat should show blocked UI (any blocking scenario except 'none')
  /// BUT: If chat was deleted and now has new messages, don't show blocked UI
  bool shouldShowBlockedUI(int? chatId, int? userId) {
    print('🔍 shouldShowBlockedUI - chatId=$chatId, userId=$userId');

    // ✅ Check if chat was deleted but has new messages
    final isDeletedWithNewMessages = _isChatDeletedWithNewMessages();
    print('🔍 _isChatDeletedWithNewMessages=$isDeletedWithNewMessages');

    if (isDeletedWithNewMessages) {
      _logger.d('✅ Chat was deleted but has new messages - allowing input');
      print('✅ Chat was deleted but has new messages - allowing input');
      return false;
    }

    final scenario = getBlockScenario(chatId, userId);
    print('🔍 Block scenario=$scenario');

    final shouldBlock = scenario != 'none';
    print('🔍 Final shouldBlock=$shouldBlock');

    return shouldBlock;
  }

  /// Check if current chat was deleted by current user but now has new messages
  /// This checks the ChatInfo from loaded messages
  bool _isChatDeletedWithNewMessages() {
    try {
      print('🔍 _isChatDeletedWithNewMessages checking...');

      // Check if we have any messages loaded
      if (_chatsData.records == null || _chatsData.records!.isEmpty) {
        print('❌ No messages loaded in _chatsData');
        return false;
      }

      print('✅ Messages loaded: ${_chatsData.records!.length} records');

      // Get the first record which should contain the Chat info
      final firstRecord = _chatsData.records!.first;
      print('🔍 First record chatId=${firstRecord.chatId}');
      print('🔍 First record has chat object: ${firstRecord.chat != null}');

      // Check if this record has Chat info with deleted_for
      if (firstRecord.chat != null) {
        print('🔍 Chat object exists!');
        print('🔍 Chat.chatId=${firstRecord.chat!.chatId}');
        print('🔍 Chat.deletedFor=${firstRecord.chat!.deletedFor}');
        print('🔍 Chat.blockedBy=${firstRecord.chat!.blockedBy}');
      }

      if (firstRecord.chat?.deletedFor != null) {
        final deletedFor = firstRecord.chat!.deletedFor!;
        print('🔍 Chat.deletedFor=$deletedFor');

        // Check if current user is in the deleted_for array
        final currentUserIdInt = int.tryParse(_currentUserId ?? '0') ?? 0;
        print(
          '🔍 Current user ID: string=$_currentUserId, int=$currentUserIdInt',
        );

        final isDeletedByCurrentUser =
            deletedFor.contains(currentUserIdInt) ||
            deletedFor.contains(_currentUserId);
        print('🔍 isDeletedByCurrentUser=$isDeletedByCurrentUser');

        if (isDeletedByCurrentUser) {
          // Chat was deleted by current user
          // Check if there are messages (which means new messages arrived after deletion)
          final hasMessages = _chatsData.records!.isNotEmpty;
          print('🔍 hasMessages=$hasMessages');
          if (hasMessages) {
            _logger.d(
              '✅ Chat ${firstRecord.chatId} was deleted but has new messages',
            );
            print(
              '✅ RESULT: Chat was deleted but has new messages - returning TRUE',
            );
            return true;
          }
        }
      } else {
        print('❌ No Chat info or deletedFor in first record');
      }

      print('❌ RESULT: Returning FALSE');
      return false;
    } catch (e) {
      _logger.e('Error checking if chat was deleted with new messages: $e');
      print('❌ ERROR in _isChatDeletedWithNewMessages: $e');
      return false;
    }
  }

  /// Check if current user can send messages (only blocked if user_blocked_by_other or mutual_block)
  bool canCurrentUserSendMessages(int? chatId, int? userId) {
    final scenario = getBlockScenario(chatId, userId);
    return scenario != 'user_blocked_by_other' && scenario != 'mutual_block';
  }

  /// Get the name of the user who blocked the current user (for user_blocked_by_other scenario)
  String? _getBlockerName(int? chatId, int? userId) {
    try {
      if (chatId != null) {
        final chatData = _chatListData.chats.firstWhere(
          (chat) => chat.records?.any((r) => r.chatId == chatId) == true,
          orElse: () => Chats(),
        );
        // In user_blocked_by_other scenario, the peer user is the blocker
        return chatData.peerUserData?.fullName ??
            chatData.peerUserData?.userName ??
            'Someone';
      } else if (userId != null) {
        for (final chat in _chatListData.chats) {
          if (chat.peerUserData?.userId == userId) {
            // In user_blocked_by_other scenario, the peer user is the blocker
            return chat.peerUserData?.fullName ??
                chat.peerUserData?.userName ??
                'Someone';
          }
        }
      }

      return null;
    } catch (e) {
      _logger.e('Error getting blocker name: $e');
      return null;
    }
  }

  /// Get appropriate block message based on scenario
  String getBlockMessage(int? chatId, int? userId) {
    final scenario = getBlockScenario(chatId, userId);

    switch (scenario) {
      case 'user_blocked_other':
        return 'You blocked this user';
      case 'user_blocked_by_other':
        final blockerName = _getBlockerName(chatId, userId);
        return blockerName != null
            ? 'You blocked by $blockerName'
            : 'You have been blocked';
      case 'mutual_block':
        return 'You both have blocked each other';
      default:
        return '';
    }
  }

  /// Handle real-time block/unblock updates from socket using new blocked_by structure
  void _handleBlockUpdates(BlockUpdatesModel blockUpdate) {
    if (_isDisposed ||
        blockUpdate.userId == null ||
        blockUpdate.chatId == null) {
      return;
    }

    final userId = blockUpdate.userId!;
    final chatId = blockUpdate.chatId!;
    final isBlocked = blockUpdate.isBlocked ?? false;

    _logger.i('🔄 ===== SOCKET BLOCK UPDATE RECEIVED =====');
    _logger.i(
      '🔄 User $userId ${isBlocked ? 'blocked' : 'unblocked'} chat $chatId',
    );
    _logger.i('🔄 Current User ID: $_currentUserId');

    try {
      // Log the state BEFORE update
      final scenarioBefore = getBlockScenario(chatId, null);
      _logger.i('🔄 BEFORE: Block scenario was: $scenarioBefore');

      // Update blocked_by field in chat records using new structure
      _updateBlockedByInChatRecords(chatId, userId, isBlocked);

      // Log the state AFTER update
      final scenarioAfter = getBlockScenario(chatId, null);
      _logger.i('🔄 AFTER: Block scenario is now: $scenarioAfter');

      // CRITICAL FIX: Validate socket event against blocked_by array state
      // Get current blocked_by array after the update
      Records? chatRecord;
      for (final chat in _chatListData.chats) {
        if (chat.records != null) {
          for (final r in chat.records!) {
            if (r.chatId == chatId) {
              chatRecord = r;
              break;
            }
          }
          if (chatRecord != null) break;
        }
      }

      if (chatRecord?.blockedBy != null) {
        final currentBlockedBy = chatRecord!.blockedBy!;
        _logger.i(
          '🔍 SOCKET VALIDATION: Current blocked_by array: $currentBlockedBy',
        );

        // Find peer user ID to validate mutual block state
        String? peerUserId;
        for (final chat in _chatListData.chats) {
          if (chat.records?.any((r) => r.chatId == chatId) == true) {
            peerUserId = chat.peerUserData?.userId?.toString();
            break;
          }
        }

        if (peerUserId != null) {
          final currentUserInArray = currentBlockedBy.contains(_currentUserId);
          final peerUserInArray = currentBlockedBy.contains(peerUserId);

          _logger.i(
            '🔍 SOCKET VALIDATION: CurrentUser($_currentUserId) in array: $currentUserInArray',
          );
          _logger.i(
            '🔍 SOCKET VALIDATION: PeerUser($peerUserId) in array: $peerUserInArray',
          );

          // Critical validation for one-sided unblock
          if (scenarioBefore == 'mutual_block' && !isBlocked) {
            _logger.w('🚨 ONE-SIDED UNBLOCK DETECTED:');
            _logger.w('🚨 User $userId unblocked from mutual_block state');
            _logger.w('🚨 Checking if peer user still has block active...');

            if (peerUserInArray && !currentUserInArray) {
              _logger.w(
                '🚨 PEER STILL BLOCKS: Current user should remain restricted',
              );
              _logger.w('🚨 Expected scenario: user_blocked_by_other');
            } else if (currentUserInArray && !peerUserInArray) {
              _logger.w(
                '🚨 CURRENT USER STILL BLOCKS: Peer should remain restricted',
              );
              _logger.w('🚨 Expected scenario: user_blocked_other');
            } else if (!currentUserInArray && !peerUserInArray) {
              _logger.w('🚨 BOTH UNBLOCKED: No restrictions should apply');
              _logger.w('🚨 Expected scenario: none');
            }
          }

          // CRITICAL: Force re-validation of block scenario after socket event
          final revalidatedScenario = getBlockScenario(chatId, null);
          if (revalidatedScenario != scenarioAfter) {
            _logger.e('🚨 SCENARIO MISMATCH: After socket event processing');
            _logger.e('🚨 Expected: $scenarioAfter, Got: $revalidatedScenario');
            _logger.e(
              '🚨 This indicates a sync issue between socket events and blocked_by array',
            );
          }

          // Additional validation: Ensure UI restrictions match the array state
          final shouldShowBlocked = revalidatedScenario != 'none';
          final canSendMessages =
              revalidatedScenario != 'user_blocked_by_other' &&
              revalidatedScenario != 'mutual_block';

          _logger.i('🔍 UI STATE VALIDATION:');
          _logger.i('🔍 Should show blocked UI: $shouldShowBlocked');
          _logger.i('🔍 Can send messages: $canSendMessages');
          _logger.i('🔍 Final block scenario for UI: $revalidatedScenario');
        }
      }

      // Update local blocked users list for backward compatibility
      final existingBlockIndex = _blockedUsers.indexWhere(
        (record) => record.blockedId == userId,
      );

      if (isBlocked) {
        // Add to blocked list if not already present
        if (existingBlockIndex == -1) {
          _blockedUsers.add(
            BlockedUserRecord(
              blockedId: userId,
              userId: int.tryParse(_currentUserId ?? '0') ?? 0,
              approved: true,
              createdAt: DateTime.now().toIso8601String(),
              updatedAt: DateTime.now().toIso8601String(),
            ),
          );
          _logger.d('Added user $userId to blocked users list');
        }
      } else {
        // Remove from blocked list if present
        if (existingBlockIndex != -1) {
          _blockedUsers.removeAt(existingBlockIndex);
          _logger.d('Removed user $userId from blocked users list');
        }
      }

      // CRITICAL FIX: Immediate UI update with enhanced validation
      if (!_isDisposed) {
        // Force immediate scenario re-calculation to ensure UI consistency
        final immediateScenario = getBlockScenario(chatId, null);
        _logger.i(
          '🔄 IMMEDIATE: Block scenario for UI update: $immediateScenario',
        );

        // CRITICAL: Double-check socket event processing result
        Records? finalRecord;
        for (final chat in _chatListData.chats) {
          if (chat.records != null) {
            for (final r in chat.records!) {
              if (r.chatId == chatId) {
                finalRecord = r;
                break;
              }
            }
            if (finalRecord != null) break;
          }
        }

        if (finalRecord?.blockedBy != null) {
          _logger.i('🔄 FINAL ARRAY STATE: ${finalRecord!.blockedBy}');
          _logger.i(
            '🔄 UI SHOULD SHOW: $immediateScenario based on this array',
          );
        }

        _scheduleNotification();
      }

      _logger.i('Block update processed successfully');
    } catch (e) {
      _logger.e('Error processing block update: $e');
    }
  }

  /// DEBUG: Test socket event sync with blocked_by array
  void debugTestSocketEventSync(int chatId, int userAId, int userBId) {
    _logger.i('🧪 ========== SOCKET EVENT SYNC TEST ==========');
    _logger.i('🧪 Testing socket events vs blocked_by array synchronization');
    _logger.i(
      '🧪 ChatId: $chatId, UserA: $userAId, UserB: $userBId, CurrentUser: $_currentUserId',
    );

    // Simulate the exact issue scenario with socket events
    _logger.i('🧪 STEP 1: Simulate socket event - User A blocks User B');
    final blockEventA = BlockUpdatesModel(
      userId: userAId,
      chatId: chatId,
      isBlocked: true,
    );
    _handleBlockUpdates(blockEventA);

    _logger.i(
      '🧪 STEP 2: Simulate socket event - User B blocks User A (mutual)',
    );
    final blockEventB = BlockUpdatesModel(
      userId: userBId,
      chatId: chatId,
      isBlocked: true,
    );
    _handleBlockUpdates(blockEventB);

    _logger.i(
      '🧪 STEP 3: Simulate socket event - User A unblocks User B (one-sided)',
    );
    final unblockEventA = BlockUpdatesModel(
      userId: userAId,
      chatId: chatId,
      isBlocked: false,
    );
    _handleBlockUpdates(unblockEventA);

    _logger.i(
      '🧪 VALIDATION: Final state should show peer still blocking current user',
    );
    final finalScenario = getBlockScenario(chatId, null);
    _logger.i('🧪 Final scenario: $finalScenario');

    // Clean up for next test
    final cleanupEvent = BlockUpdatesModel(
      userId: userBId,
      chatId: chatId,
      isBlocked: false,
    );
    _handleBlockUpdates(cleanupEvent);

    _logger.i('🧪 ========== SOCKET EVENT SYNC TEST COMPLETED ==========');
  }

  /// DEBUG: Test the specific one-sided unblock issue
  void debugTestOneSidedUnblock(int chatId, int userAId, int userBId) {
    _logger.i('🔍 ========== ONE-SIDED UNBLOCK TEST ==========');
    _logger.i(
      '🔍 ChatId: $chatId, UserA: $userAId, UserB: $userBId, CurrentUser: $_currentUserId',
    );

    // Scenario: A blocks B, B blocks A, then A unblocks B
    _logger.i('🔍 Step 1: User A ($userAId) blocks User B ($userBId)');
    _updateBlockedByInChatRecords(chatId, userAId, true);
    var scenario = getBlockScenario(chatId, null);
    _logger.i('🔍 After A blocks B - Block scenario: $scenario');

    _logger.i('🔍 Step 2: User B ($userBId) blocks User A ($userAId)');
    _updateBlockedByInChatRecords(chatId, userBId, true);
    scenario = getBlockScenario(chatId, null);
    _logger.i('🔍 After B blocks A (mutual) - Block scenario: $scenario');

    _logger.i('🔍 Step 3: User A ($userAId) unblocks User B ($userBId)');
    _updateBlockedByInChatRecords(chatId, userAId, false);
    scenario = getBlockScenario(chatId, null);
    _logger.i('🔍 After A unblocks B - Block scenario: $scenario');
    _logger.i('🔍 CRITICAL: B still blocks A, so A should be restricted!');

    // Test from both perspectives
    if (_currentUserId == userAId.toString()) {
      _logger.i(
        '🔍 From User A perspective: Should show user_blocked_by_other (B blocked A)',
      );
    } else if (_currentUserId == userBId.toString()) {
      _logger.i(
        '🔍 From User B perspective: Should show user_blocked_other (B blocked A)',
      );
    }

    // Clean up
    _updateBlockedByInChatRecords(chatId, userBId, false);
    _logger.i('🔍 ========== ONE-SIDED UNBLOCK TEST COMPLETED ==========');
    _scheduleNotification();
  }

  /// DEBUG: Test all block scenarios comprehensively
  void debugTestAllBlockScenarios(int chatId, int userAId, int userBId) {
    _logger.i('🧪 ========== COMPREHENSIVE BLOCK SCENARIO TEST ==========');
    _logger.i(
      '🧪 ChatId: $chatId, UserA: $userAId, UserB: $userBId, CurrentUser: $_currentUserId',
    );

    // Initial state - no blocks
    _logger.i('🧪 Step 0: Initial state (no blocks)');
    var scenario = getBlockScenario(chatId, null);
    _logger.i('🧪 After Step 0 - Block scenario: $scenario (expected: none)');

    // Test Case 1: User A blocks User B
    _logger.i('🧪 Step 1: User A ($userAId) blocks User B ($userBId)');
    _updateBlockedByInChatRecords(chatId, userAId, true);
    scenario = getBlockScenario(chatId, null);
    _logger.i(
      '🧪 After Step 1 - Block scenario: $scenario (expected: user_blocked_other if current = A, user_blocked_by_other if current = B)',
    );

    // Test Case 2: User B also blocks User A (mutual block)
    _logger.i('🧪 Step 2: User B ($userBId) blocks User A ($userAId)');
    _updateBlockedByInChatRecords(chatId, userBId, true);
    scenario = getBlockScenario(chatId, null);
    _logger.i(
      '🧪 After Step 2 - Block scenario: $scenario (expected: mutual_block)',
    );

    // Test Case 3: User A unblocks User B (but B still blocks A)
    _logger.i('🧪 Step 3: User A ($userAId) unblocks User B ($userBId)');
    _updateBlockedByInChatRecords(chatId, userAId, false);
    scenario = getBlockScenario(chatId, null);
    _logger.i(
      '🧪 After Step 3 - Block scenario: $scenario (expected: user_blocked_other if current = B, user_blocked_by_other if current = A)',
    );

    // Test Case 4: User B also unblocks User A (back to normal)
    _logger.i('🧪 Step 4: User B ($userBId) unblocks User A ($userAId)');
    _updateBlockedByInChatRecords(chatId, userBId, false);
    scenario = getBlockScenario(chatId, null);
    _logger.i('🧪 After Step 4 - Block scenario: $scenario (expected: none)');

    // Edge Case: Rapid block/unblock sequence
    _logger.i('🧪 Edge Case: Rapid block/unblock sequence');
    _updateBlockedByInChatRecords(chatId, userAId, true);
    _updateBlockedByInChatRecords(chatId, userAId, false);
    _updateBlockedByInChatRecords(chatId, userBId, true);
    scenario = getBlockScenario(chatId, null);
    _logger.i('🧪 After Edge Case - Block scenario: $scenario');

    // Clean up
    _updateBlockedByInChatRecords(chatId, userBId, false);

    _logger.i('🧪 ========== BLOCK SCENARIO TEST COMPLETED ==========');
    _scheduleNotification();
  }

  /// Update blocked_by field in chat records using new structure
  void _updateBlockedByInChatRecords(int chatId, int userId, bool isBlocked) {
    try {
      _logger.d(
        '🔄 Updating blocked_by for chatId: $chatId, userId: $userId, isBlocked: $isBlocked',
      );

      // Find the chat record with the given chatId
      for (var chat in _chatListData.chats) {
        if (chat.records != null) {
          for (var record in chat.records!) {
            if (record.chatId == chatId) {
              // Initialize blockedBy if null
              record.blockedBy ??= [];

              _logger.d(
                '🔄 Found chat record. Current blocked_by: ${record.blockedBy}',
              );

              final userIdStr = userId.toString();

              if (isBlocked) {
                // Add userId to blocked_by if not already present
                if (!record.blockedBy!.contains(userIdStr)) {
                  record.blockedBy!.add(userIdStr);
                  _logger.d(
                    '✅ Added user $userId to blocked_by for chat $chatId. New array: ${record.blockedBy}',
                  );
                } else {
                  _logger.d(
                    'ℹ️ User $userId already in blocked_by for chat $chatId',
                  );
                }
              } else {
                // Remove userId from blocked_by
                final removed = record.blockedBy!.remove(userIdStr);
                if (removed) {
                  _logger.d(
                    '✅ Removed user $userId from blocked_by for chat $chatId. New array: ${record.blockedBy}',
                  );
                } else {
                  _logger.d(
                    'ℹ️ User $userId was not in blocked_by for chat $chatId',
                  );
                }
              }
              return; // Exit once we find and update the record
            }
          }
        }
      }
      _logger.w('⚠️ Chat record with ID $chatId not found for block update');
    } catch (e) {
      _logger.e('❌ Error updating blocked_by in chat records: $e');
    }
  }

  /// Search messages in a specific chat with pagination
  /// Returns search results with user information and pagination data
  Future<Map<String, dynamic>?> searchMessages({
    required String searchText,
    required int chatId,
    int page = 1,
  }) async {
    try {
      _logger.d(
        'ChatProvider: Searching messages with text: "$searchText", chatId: $chatId, page: $page',
      );

      final response = await _chatRepository.searchMessages(
        searchText: searchText,
        chatId: chatId,
        page: page,
      );

      if (response != null && response['status'] == true) {
        _logger.i('ChatProvider: Message search successful');
        return response;
      } else {
        _logger.w('ChatProvider: Message search failed');
        return null;
      }
    } catch (e) {
      _logger.e('ChatProvider: Error searching messages: $e');
      return null;
    }
  }

  Future<void> countApi() async {
    try {
      _isCountLoading = false;
      notify();

      final countModel = await _chatRepository.countRepo();

      if (countModel!.status == true) {
        _starredCount = countModel.data!.totalStaredMessages;
        _blocklistCount = countModel.data!.totalBlockedUsers;
        _notificationCount = countModel.data!.unreadNotificationCount;
        _logger.d(_starredCount.toString());
        _logger.d(_blocklistCount.toString());
      }
      notify();
    } catch (e) {
      _error = "Failed to load count";
      _logger.e('Load count API returned null');
      notify();
    } finally {
      _isCountLoading = false;
      notify();
    }
  }

  Future<void> fetchMetadata({required String url}) async {
    _logger.d('Fetching metadata for URL: $url');
    final meta = await _chatRepository.fetchMetadataRepo(
      url, //"https://www.youtube.com/watch?v=abcd1234",
    );
    _urlTitle = meta["title"] ?? "";
    _logger.d('URL Title: ${meta["title"]}');
    _urlDescri = meta["description"] ?? "";
    _logger.d('URL Description: ${meta["description"]}');
    _urlImage = meta["image"] ?? "";
    _logger.d('URL Image: ${meta["image"]}');
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    notifyListeners();
  }

  /// ✅ FIX: Clear archived chat badge count if this chat is archived
  void _clearArchivedChatBadgeIfNeeded(int chatId) {
    try {
      final archiveChatProvider = getIt<ArchiveChatProvider>();
      final currentArchivedBadgeCount = archiveChatProvider
          .getArchivedChatUnseenCount(chatId);

      if (currentArchivedBadgeCount > 0) {
        _logger.d(
          '🗃️ Clearing archived chat badge for chatId: $chatId (current count: $currentArchivedBadgeCount)',
        );
        archiveChatProvider.clearArchivedChatUnseenCount(chatId);
        _logger.d(
          '✅ Archived chat badge cleared successfully for chatId: $chatId',
        );
      } else {
        _logger.d('🔍 No archived chat badge to clear for chatId: $chatId');
      }
    } catch (e) {
      _logger.e('❌ Error clearing archived chat badge for chatId $chatId: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ DEV SOLUTION: DYNAMIC MESSAGE LOADING & SEEN STATUS MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Enhanced chat item tap handler with dynamic pageSize and unseen message management
  ///
  /// This method solves the core issue where tapping a chat with high unseen_count
  /// would only load 20 messages, causing older unseen messages to be skipped.
  ///
  /// Key Features:
  /// - Dynamic pageSize based on unseenCount (loads ALL unseen messages first)
  /// - Immediate emission of real_time_message_seen for loaded unseen messages
  /// - Proper synchronization between ChatList and ArchiveList
  /// - Comprehensive error handling and logging
  /// - Production-ready edge case handling
  ///
  /// @param chatId - The chat ID to open
  /// @param unseenCount - Number of unseen messages in this chat
  /// @param fromArchive - Whether the chat was opened from archive list
  /// @param userId - User ID for new chats (optional)
  /// @param chatName - Display name for the chat (optional)
  /// @param profilePic - Profile picture URL (optional)
  /// @param isGroupChat - Whether this is a group chat (optional)
  Future<void> onChatItemTap({
    required int chatId,
    required int unseenCount,
    bool fromArchive = false,
    int? userId,
    String? chatName,
    String? profilePic,
    bool isGroupChat = false,
  }) async {
    try {
      _logger.d(
        '🎯 onChatItemTap START: chatId=$chatId, unseenCount=$unseenCount, fromArchive=$fromArchive',
      );

      // ═════════════════════════════════════════════════════════════════
      // STEP 1: DETERMINE OPTIMAL PAGE SIZE
      // ═════════════════════════════════════════════════════════════════

      int dynamicPageSize;
      String loadingStrategy;

      if (unseenCount <= 0) {
        // No unseen messages - use default pagination
        dynamicPageSize = 20;
        loadingStrategy = "NORMAL_PAGINATION";
        _logger.d(
          '📄 No unseen messages - using default pageSize: $dynamicPageSize',
        );
      } else if (unseenCount <= 100) {
        // Load exactly the number of unseen messages (with small buffer for safety)
        dynamicPageSize = unseenCount + 5; // Add 5 message buffer
        loadingStrategy = "LOAD_ALL_UNSEEN";
        _logger.d(
          '🔢 Loading ALL unseen messages - dynamic pageSize: $dynamicPageSize (unseenCount: $unseenCount + 5 buffer)',
        );
      } else {
        // Cap at reasonable limit to prevent memory issues
        dynamicPageSize = 100;
        loadingStrategy = "LOAD_CAPPED_UNSEEN";
        _logger.w(
          '⚠️ High unseenCount ($unseenCount) - capping pageSize at $dynamicPageSize',
        );
      }

      // ═════════════════════════════════════════════════════════════════
      // STEP 2: PREPARE CHAT CONTEXT AND CLEAR PREVIOUS DATA
      // ═════════════════════════════════════════════════════════════════

      _logger.d('🧹 Clearing previous chat data and setting new context');

      // Clear existing data to ensure fresh load
      _chatsData = chats.ChatsModel();
      _pinnedMessagesData = chats.ChatsModel();
      _lastChatsDataHash = null;
      clearHighlight();

      // ✅ Clear seen message tracker for new chat session
      _processedSeenMessageIds.clear();
      _logger.d('🧹 Cleared seen message tracker for new chat session');

      _scheduleNotification();

      // Set current chat context
      _currentChatData = ChatIds(chatId: chatId, userId: userId ?? 0);
      _socketEventController.setCurrentChat(chatId, userId ?? 0);

      // ═════════════════════════════════════════════════════════════════
      // STEP 3: LOAD MESSAGES WITH DYNAMIC PAGE SIZE
      // ═════════════════════════════════════════════════════════════════

      _logger.d(
        '🌐 Loading messages with strategy: $loadingStrategy, pageSize: $dynamicPageSize',
      );

      // Track start time for performance monitoring
      final startTime = DateTime.now();

      if (chatId > 0) {
        // Load existing chat messages with dynamic page size
        await _socketEventController.emitChatMessages(
          chatId: chatId,
          page: 1,
          pageSize: dynamicPageSize,
        );
      } else if (userId != null && userId > 0) {
        // New chat scenario
        await _socketEventController.emitChatMessages(
          peerId: userId,
          page: 1,
          pageSize: dynamicPageSize,
        );
      } else {
        throw Exception('Invalid chat context: chatId=$chatId, userId=$userId');
      }

      // ═════════════════════════════════════════════════════════════════
      // STEP 4: WAIT FOR MESSAGES TO LOAD, THEN PROCESS UNSEEN MESSAGES
      // ═════════════════════════════════════════════════════════════════

      if (unseenCount > 0) {
        _logger.d(
          '⏱️ Waiting for messages to load before processing unseen messages...',
        );

        // Wait for socket response with timeout
        int attempts = 0;
        const maxAttempts = 15; // 3 seconds timeout (200ms * 15)
        bool messagesLoaded = false;

        while (attempts < maxAttempts && !_isDisposed) {
          await Future.delayed(Duration(milliseconds: 200));

          if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
            messagesLoaded = true;
            break;
          }

          attempts++;
        }

        if (messagesLoaded) {
          final loadTime = DateTime.now().difference(startTime).inMilliseconds;
          _logger.d('✅ Messages loaded successfully in ${loadTime}ms');

          // Process unseen messages immediately
          await _processUnseenMessagesAfterLoad(
            chatId: chatId,
            expectedUnseenCount: unseenCount,
            loadingStrategy: loadingStrategy,
          );
        } else {
          _logger.w(
            '⚠️ Messages not loaded within timeout - proceeding without unseen processing',
          );
        }
      }

      // ═════════════════════════════════════════════════════════════════
      // STEP 5: UPDATE CHAT LIST AND ARCHIVE STATES
      // ═════════════════════════════════════════════════════════════════

      await _syncChatListStates(chatId: chatId, fromArchive: fromArchive);

      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      _logger.d(
        '🎯 onChatItemTap COMPLETED in ${totalTime}ms - strategy: $loadingStrategy, pageSize: $dynamicPageSize',
      );
    } catch (e) {
      _logger.e('❌ Error in onChatItemTap: $e');
      // Fallback to default behavior
      if (chatId > 0 && userId != null) {
        try {
          await loadChatMessages(chatId: chatId, peerId: userId);
        } catch (fallbackError) {
          _logger.e('❌ Fallback also failed: $fallbackError');
        }
      }
      rethrow;
    }
  }

  /// Process unseen messages after initial load and emit seen events
  Future<void> _processUnseenMessagesAfterLoad({
    required int chatId,
    required int expectedUnseenCount,
    required String loadingStrategy,
  }) async {
    try {
      _logger.d(
        '🔍 Processing unseen messages - expected: $expectedUnseenCount, loaded: ${_chatsData.records?.length ?? 0}',
      );

      if (_chatsData.records == null || _chatsData.records!.isEmpty) {
        _logger.w('No messages loaded to process');
        return;
      }

      final currentUserIdStr = await _getCurrentUserId();
      if (currentUserIdStr == null || currentUserIdStr.isEmpty) {
        _logger.w(
          'Cannot process unseen messages - current user ID not available',
        );
        return;
      }

      final currentUserId = int.tryParse(currentUserIdStr);
      if (currentUserId == null) {
        _logger.w(
          'Cannot process unseen messages - invalid user ID format: $currentUserIdStr',
        );
        return;
      }

      // ═══════════════════════════════════════════════════════════════
      // STEP 1: IDENTIFY TRULY UNSEEN MESSAGES WITH STRICT FILTERING
      // ═══════════════════════════════════════════════════════════════

      final potentialUnseenMessages =
          _chatsData.records!
              .where(
                (message) =>
                    message.senderId !=
                        currentUserId && // Not from current user
                    message.messageId != null,
              ) // Has valid message ID
              .toList();

      _logger.d(
        '📋 Found ${potentialUnseenMessages.length} potential messages from other users',
      );

      // Get already processed seen message IDs from our class-level tracker
      Set<int> alreadyProcessedMessageIds = Set<int>.from(
        _processedSeenMessageIds,
      );

      _logger.d(
        '💾 Processed seen message tracker has ${alreadyProcessedMessageIds.length} previously processed messages',
      );

      // ═══════════════════════════════════════════════════════════════
      // STEP 2: APPLY RIGOROUS FILTERING TO FIND TRULY UNSEEN MESSAGES
      // ═══════════════════════════════════════════════════════════════

      final List<chats.Records> trulyUnseenMessages = [];

      for (final message in potentialUnseenMessages) {
        final messageId = message.messageId!;
        bool shouldMarkAsSeen = false;
        String reason = '';

        // Check 1: Already processed by socket controller
        if (alreadyProcessedMessageIds.contains(messageId)) {
          reason = 'already processed by socket';
        }
        // Check 2: Message seen status is explicitly 'seen'
        else if (message.messageSeenStatus == 'seen') {
          reason = 'messageSeenStatus is seen';
        }
        // Check 3: Advanced time and context-based filtering
        else if (message.createdAt != null) {
          try {
            final messageTime = DateTime.parse(message.createdAt!);
            final timeDiff = DateTime.now().difference(messageTime).inSeconds;
            final timeDiffMinutes = timeDiff / 60;

            // More intelligent time-based filtering
            if (timeDiff < 3) {
              // Very recent messages (< 3 seconds) might have been auto-seen
              reason = 'message too recent ($timeDiff seconds old)';
            } else if (timeDiff < 30 && message.messageSeenStatus == null) {
              // Recent messages without explicit seen status might be processing
              reason =
                  'recent message with null seen status (${timeDiff}s old)';
            } else if (timeDiffMinutes > 1440) {
              // > 24 hours
              // Very old messages are likely already processed
              if (message.messageSeenStatus != 'delivered' &&
                  message.messageSeenStatus != 'sent') {
                shouldMarkAsSeen = true;
                reason =
                    'old message likely unseen (${timeDiffMinutes.toStringAsFixed(1)} minutes old)';
              } else {
                reason =
                    'old message with delivery status ${message.messageSeenStatus}';
              }
            } else {
              // Normal age message - check if it should be marked as seen
              shouldMarkAsSeen = true;
              reason =
                  'normal age message (${timeDiffMinutes.toStringAsFixed(1)} minutes old)';
            }
          } catch (e) {
            // If parsing fails, assume it needs to be marked as seen
            shouldMarkAsSeen = true;
            reason = 'date parsing failed, assuming unseen';
          }
        } else {
          shouldMarkAsSeen = true;
          reason = 'no createdAt timestamp, assuming unseen';
        }

        if (shouldMarkAsSeen) {
          trulyUnseenMessages.add(message);
          _logger.d('✅ Message $messageId: $reason');
        } else {
          _logger.d('⏭️ Message $messageId: skipped - $reason');
        }
      }

      _logger.d(
        '📊 After rigorous filtering: ${trulyUnseenMessages.length} truly unseen messages (out of ${potentialUnseenMessages.length} potential)',
      );

      // ✅ Log detailed filtering debug info
      _logMessageFilteringDebugInfo(
        allMessages: _chatsData.records!,
        potentialUnseen: potentialUnseenMessages,
        trulyUnseen: trulyUnseenMessages,
        currentUserId: currentUserId,
        alreadyProcessed: alreadyProcessedMessageIds,
      );

      if (trulyUnseenMessages.isEmpty) {
        _logger.d('No truly unseen messages found - clearing unseen count');
        clearChatUnseenCount(chatId);
        return;
      }

      // ═══════════════════════════════════════════════════════════════
      // STEP 3: VALIDATE AGAINST EXPECTED COUNT
      // ═══════════════════════════════════════════════════════════════

      if (trulyUnseenMessages.length < expectedUnseenCount &&
          expectedUnseenCount > 5) {
        _logger.w(
          '⚠️ COUNT MISMATCH: Expected $expectedUnseenCount unseen messages but found ${trulyUnseenMessages.length} truly unseen',
        );
        _logger.w(
          'This is normal if some messages were already auto-marked as seen',
        );

        if (loadingStrategy == "LOAD_CAPPED_UNSEEN") {
          _logger.w(
            'Capped loading was used - some unseen messages may still be unloaded',
          );
        }
      }

      // ═══════════════════════════════════════════════════════════════
      // STEP 4: EMIT SEEN EVENTS FOR TRULY UNSEEN MESSAGES ONLY
      // ═══════════════════════════════════════════════════════════════

      int successfulEmissions = 0;
      int skippedEmissions = 0;
      final emissionStartTime = DateTime.now();

      for (final message in trulyUnseenMessages) {
        try {
          final messageId = message.messageId!;

          // Double-check: Don't emit if already in seen set (race condition protection)
          if (alreadyProcessedMessageIds.contains(messageId)) {
            skippedEmissions++;
            _logger.d(
              '⏭️ Skipping message $messageId - already processed during iteration',
            );
            continue;
          }

          // Emit seen event
          await markMessageAsSeen(chatId, messageId);
          successfulEmissions++;

          // Add to both local and class-level tracker to prevent duplicates
          alreadyProcessedMessageIds.add(messageId);
          _processedSeenMessageIds.add(messageId);

          _logger.d('✅ Successfully marked message $messageId as seen');

          // Throttle emissions for large batches
          if (trulyUnseenMessages.length > 10) {
            await Future.delayed(Duration(milliseconds: 50));
          }
        } catch (e) {
          _logger.e(
            '❌ Failed to mark message ${message.messageId} as seen: $e',
          );
        }
      }

      final finalEmissionTime =
          DateTime.now().difference(emissionStartTime).inMilliseconds;
      _logger.d(
        '📈 Emission results: $successfulEmissions successful, $skippedEmissions skipped, ${finalEmissionTime}ms total',
      );

      // ═══════════════════════════════════════════════════════════════
      // UPDATE LOCAL STATE AND LOG RESULTS
      // ═══════════════════════════════════════════════════════════════

      if (successfulEmissions > 0) {
        // Clear the unseen count locally for immediate UI feedback
        clearChatUnseenCount(chatId);

        // Also clear in archive provider if needed
        _clearArchivedChatBadgeIfNeeded(chatId);

        _logger.d(
          '✅ Successfully marked $successfulEmissions/${trulyUnseenMessages.length} messages as seen in ${finalEmissionTime}ms',
        );
      } else {
        _logger.w('⚠️ Failed to mark any truly unseen messages as seen');
      }

      // Log final statistics
      _logger.d('📈 UNSEEN PROCESSING STATS:');
      _logger.d('  - Expected unseenCount: $expectedUnseenCount');
      _logger.d(
        '  - Potential messages from others: ${potentialUnseenMessages.length}',
      );
      _logger.d(
        '  - Truly unseen messages found: ${trulyUnseenMessages.length}',
      );
      _logger.d('  - Successfully marked as seen: $successfulEmissions');
      _logger.d('  - Skipped (already processed): $skippedEmissions');
      _logger.d('  - Loading strategy: $loadingStrategy');
      _logger.d('  - Processing time: ${finalEmissionTime}ms');
    } catch (e) {
      _logger.e('❌ Error processing unseen messages: $e');
    }
  }

  /// Synchronize chat list and archive list states after chat item tap
  Future<void> _syncChatListStates({
    required int chatId,
    required bool fromArchive,
  }) async {
    try {
      _logger.d(
        '🔄 Syncing chat list states - chatId: $chatId, fromArchive: $fromArchive',
      );

      // Update main chat list unseen count
      clearChatUnseenCount(chatId);

      // Update archived chat unseen count if applicable
      _clearArchivedChatBadgeIfNeeded(chatId);

      // Trigger UI update notification
      _scheduleNotification();

      _logger.d('✅ Chat list states synchronized successfully');
    } catch (e) {
      _logger.e('❌ Error syncing chat list states: $e');
    }
  }

  /// Get current user ID asynchronously
  Future<String?> _getCurrentUserId() async {
    try {
      return await SecurePrefs.getString(SecureStorageKeys.USERID);
    } catch (e) {
      _logger.e('Error getting current user ID: $e');
      return null;
    }
  }

  /// ✅ NEW: Validate message filtering logic for debugging
  void _logMessageFilteringDebugInfo({
    required List<chats.Records> allMessages,
    required List<chats.Records> potentialUnseen,
    required List<chats.Records> trulyUnseen,
    required int currentUserId,
    required Set<int> alreadyProcessed,
  }) {
    _logger.d('🔍 MESSAGE FILTERING DEBUG INFO:');
    _logger.d('  - Total messages loaded: ${allMessages.length}');
    _logger.d(
      '  - Messages from current user: ${allMessages.where((m) => m.senderId == currentUserId).length}',
    );
    _logger.d('  - Messages from others: ${potentialUnseen.length}');
    _logger.d('  - Already processed in tracker: ${alreadyProcessed.length}');
    _logger.d('  - Truly unseen after filtering: ${trulyUnseen.length}');

    if (trulyUnseen.isNotEmpty && trulyUnseen.length <= 10) {
      _logger.d(
        '  - Truly unseen message IDs: ${trulyUnseen.map((m) => m.messageId).join(', ')}',
      );
    }

    // Sample some messages for detailed analysis
    if (potentialUnseen.isNotEmpty) {
      final sampleSize =
          potentialUnseen.length > 5 ? 5 : potentialUnseen.length;
      _logger.d('  - Sample message analysis (first $sampleSize):');

      for (int i = 0; i < sampleSize; i++) {
        final msg = potentialUnseen[i];
        final wasAlreadyProcessed = alreadyProcessed.contains(msg.messageId);
        final seenStatus = msg.messageSeenStatus ?? 'null';
        final age = _getMessageAgeInSeconds(msg.createdAt);

        _logger.d(
          '    Message ${msg.messageId}: seenStatus=$seenStatus, alreadyProcessed=$wasAlreadyProcessed, age=${age}s',
        );
      }
    }
  }

  /// Helper to get message age in seconds
  int _getMessageAgeInSeconds(String? createdAt) {
    if (createdAt == null) return -1;
    try {
      final messageTime = DateTime.parse(createdAt);
      return DateTime.now().difference(messageTime).inSeconds;
    } catch (e) {
      return -1;
    }
  }

  /// ✅ NEW: Get detailed statistics about processed seen messages
  Map<String, dynamic> getSeenMessageProcessingStats() {
    return {
      'processedSeenMessageCount': _processedSeenMessageIds.length,
      'processedSeenMessageIds': _processedSeenMessageIds.toList(),
      'lastProcessedCount': _processedSeenMessageIds.length,
    };
  }

  /// ✅ NEW: Clear seen message tracker manually (for debugging)
  void clearSeenMessageTracker() {
    final previousCount = _processedSeenMessageIds.length;
    _processedSeenMessageIds.clear();
    _logger.d(
      '🧹 Manually cleared seen message tracker (had $previousCount messages)',
    );
  }
}
