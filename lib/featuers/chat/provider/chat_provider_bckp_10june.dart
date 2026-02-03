// import 'dart:async';
// import 'dart:io';

// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
// import 'package:whoxa/core/api/api_client.dart';
// import 'package:whoxa/core/services/socket/socket_event_controller.dart';
// import 'package:whoxa/featuers/chat/data/chat_ids_model.dart';
// import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
// import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
// import 'package:whoxa/featuers/chat/data/online_user_model.dart';
// import 'package:whoxa/featuers/chat/data/typing_model.dart';
// import 'package:whoxa/featuers/chat/repository/chat_repository.dart';
// import 'package:whoxa/featuers/chat/utils/message_utils.dart';
// import 'package:whoxa/utils/enums.dart';
// import 'package:whoxa/utils/logger.dart';
// import 'package:whoxa/utils/preference_key/preference_key.dart';
// import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
// import 'package:syncfusion_flutter_pdf/pdf.dart';
// import 'package:video_thumbnail/video_thumbnail.dart';

// class ChatProvider with ChangeNotifier {
//   // Dependencies
//   final ApiClient _apiClient;
//   final SocketEventController _socketEventController;
//   final ChatRepository _chatRepository;
//   final ConsoleAppLogger _logger = ConsoleAppLogger();

//   // State variables
//   ChatListModel _chatListData = ChatListModel(chats: []);
//   chats.ChatsModel _chatsData = chats.ChatsModel();
//   ChatIdsModel _chatIdsData = ChatIdsModel();
//   OnlineUsersModel _onlineUsersData = OnlineUsersModel();
//   TypingModel _typingData = TypingModel();

//   // ✅ NEW: Chat list pagination state
//   int _chatListCurrentPage = 1;
//   int _chatListTotalPages = 1;
//   bool _isChatListPaginationLoading = false;
//   bool _hasChatListMoreData = true;
//   final int _chatListPageSize = 10;

//   // ✅ NEW: Pinned messages state using your existing ChatsModel
//   chats.ChatsModel _pinnedMessagesData = chats.ChatsModel();
//   bool _isPinnedMessagesExpanded = false;
//   int? _highlightedMessageId;
//   Timer? _highlightTimer;
//   bool _isSearchingForMessage = false;
//   int? _targetMessageId;
//   Timer? _searchTimeoutTimer;
//   bool _isMessageFound = false;

//   bool _isSendingMessage = false;
//   bool _isShowAttachments = false;
//   bool _isInitializing = false;
//   bool _isDisposed = false;

//   String? _error;
//   // Current chat data
//   ChatIds _currentChatData = ChatIds();
//   // File storage
//   List<File>? _shareImage;
//   List<File>? _shareDocument;
//   List<File>? _shareVideo;

//   String _shareVideoThumbnail = "";

//   // Stream subscriptions
//   StreamSubscription? _chatListSubscription;
//   StreamSubscription? _chatsSubscription;
//   StreamSubscription? _chatIdsSubscription;
//   StreamSubscription? _onlineUsersSubscription;

//   StreamSubscription? _typingSubscription;
//   StreamSubscription? _pinUnpinSubscription;
//   StreamSubscription? _starUnstarSubscription;

//   String? _currentUserId;
//   // Debouncing and throttling
//   Timer? _notifyTimer;
//   bool _shouldNotify = false;
//   // Track last update to prevent duplicate notifications
//   String? _lastChatsDataHash;

//   // ✅ NEW: Reply state management
//   chats.Records? _replyToMessage;

//   bool _isReplyMode = false;
//   // ✅ NEW: separate pagination loading state
//   bool _isPaginationLoading = false;

//   // ✅ NEW: Chat List Pagination Getters
//   int get chatListCurrentPage => _chatListCurrentPage;
//   int get chatListTotalPages => _chatListTotalPages;
//   bool get isChatListPaginationLoading => _isChatListPaginationLoading;
//   bool get hasChatListMoreData => _hasChatListMoreData;

//   chats.ChatsModel get starredMessagesData =>
//       _socketEventController.starredMessagesData;

//   // Constructor with dependency injection
//   ChatProvider(
//     this._apiClient,
//     this._socketEventController,
//     this._chatRepository,
//   ) {
//     _logger.i('Creating ChatProvider with separated API calls');
//     _initializeSubscriptions();
//   }

//   ChatIdsModel get chatIdsData => _chatIdsData;
//   // Getters
//   ChatListModel get chatListData => _chatListData;

//   chats.ChatsModel get chatsData => _chatsData;
//   ChatIds get currentChatData => _currentChatData;

//   String? get error => _error ?? _socketEventController.lastError;
//   bool get hasMoreMessages => _socketEventController.hasMoreMessages;

//   int? get highlightedMessageId => _highlightedMessageId;

//   bool get isChatListLoading => _socketEventController.isChatListLoading;
//   bool get isChatLoading => _socketEventController.isChatLoading;
//   bool get isInitializing => _isInitializing;
//   bool get isMessageFound => _isMessageFound;
//   bool get isPaginationLoading => _isPaginationLoading;

//   bool get isPinnedMessagesExpanded => _isPinnedMessagesExpanded;
//   bool get isRefreshing => _socketEventController.isRefreshing;

//   bool get isReplyMode => _isReplyMode;
//   bool get isSearchingForMessage => _isSearchingForMessage;
//   bool get isSendingMessage => _isSendingMessage;
//   bool get isShowAttachments => _isShowAttachments;
//   OnlineUsersModel get onlineUsersData => _onlineUsersData;
//   // ✅ NEW: Pinned messages getters
//   chats.ChatsModel get pinnedMessagesData => _pinnedMessagesData;
//   // ✅ NEW: Reply getters
//   chats.Records? get replyToMessage => _replyToMessage;
//   int? get targetMessageId => _targetMessageId;
//   TypingModel get typingData => _typingData;

//   bool get isChatScreenActive => _socketEventController.isChatScreenActive;
//   bool get isAppInForeground => _socketEventController.isAppInForeground;
//   String? get activeChatScreenId => _socketEventController.activeChatScreenId;

//   void setAppForegroundState(bool isInForeground) {
//     _socketEventController.setAppForegroundState(isInForeground);
//   }

//   void setChatScreenActive(int chatId, int userId, {bool isActive = true}) {
//     _socketEventController.setChatScreenActive(
//       chatId,
//       userId,
//       isActive: isActive,
//     );
//   }

//   /// Check if current user can delete a message
//   bool canDeleteMessage(chats.Records message) {
//     if (_currentUserId == null || _currentUserId!.isEmpty) {
//       _logger.w('Current user ID not available for delete permission check');
//       return false;
//     }

//     // Convert current user ID to int for comparison
//     final currentUserIdInt = int.tryParse(_currentUserId!) ?? 0;

//     // Only the sender can delete their own messages
//     return message.senderId == currentUserIdInt;
//   }

//   /// Check if current user can delete message for everyone
//   bool canDeleteMessageForEveryone(chats.Records message) {
//     if (!canDeleteMessage(message)) return false;

//     // Additional logic can be added here, such as:
//     // - Time limit for deletion (e.g., only within 24 hours)
//     // - Admin privileges
//     // - Group chat rules

//     // For now, any user can delete their own message for everyone
//     return true;
//   }

//   ///pin unpin
//   // Check if current user can pin/unpin a message
//   bool canPinUnpinMessage(chats.Records message) {
//     if (_currentUserId == null || _currentUserId!.isEmpty) {
//       _logger.w('Current user ID not available for permission check');
//       return false;
//     }

//     // Convert current user ID to int for comparison
//     final currentUserIdInt = int.tryParse(_currentUserId!) ?? 0;

//     if (message.pinned == true) {
//       // For unpinning: Only the user who pinned the message can unpin it
//       // You might need to add a 'pinnedBy' field to your message model
//       // For now, we'll allow the message sender to unpin
//       return message.senderId == currentUserIdInt;
//     } else {
//       // For pinning: Any user can pin a message (or implement your own logic)
//       return true;
//     }
//   }

//   ///pin unpin
//   // Check if current user can pin/unpin a message
//   bool canStarUnStarMessage(chats.Records message) {
//     if (_currentUserId == null || _currentUserId!.isEmpty) {
//       _logger.w('Current user ID not available for permission check');
//       return false;
//     }

//     // Convert current user ID to int for comparison
//     final currentUserIdInt = int.tryParse(_currentUserId!) ?? 0;

//     if (message.stared == true) {
//       // For unpinning: Only the user who pinned the message can unpin it
//       // You might need to add a 'pinnedBy' field to your message model
//       // For now, we'll allow the message sender to unpin
//       return message.senderId == currentUserIdInt;
//     } else {
//       // For pinning: Any user can pin a message (or implement your own logic)
//       return true;
//     }
//   }

//   // ✅ UPDATED: Check user online status using ChatRepository
//   Future<Map<String, dynamic>?> checkUserOnlineStatus(int userId) async {
//     if (_isDisposed) return null;

//     try {
//       _logger.d('Checking online status for user: $userId via ChatRepository');
//       return await _chatRepository.checkUserOnlineStatus(userId);
//     } catch (e) {
//       _logger.e('Error checking user online status: $e');
//       return null;
//     }
//   }

//   // Clear current chat data
//   void clearCurrentChat() {
//     if (_isDisposed) return;

//     _currentChatData = ChatIds();
//     _chatsData = chats.ChatsModel();
//     _pinnedMessagesData = chats.ChatsModel();
//     _isPinnedMessagesExpanded = false;
//     _lastChatsDataHash = null;
//     clearHighlight();
//     _socketEventController.setCurrentChat(0, 0);
//     _scheduleNotification();
//   }

//   // Clear error message
//   void clearError() {
//     if (_isDisposed) return;
//     _error = null;
//     _socketEventController.clearError();
//     _scheduleNotification();
//   }

//   // ✅ NEW: Clear highlight
//   void clearHighlight() {
//     _highlightTimer?.cancel();
//     _highlightedMessageId = null;
//     _scheduleNotification();
//   }

//   void clearReply() {
//     _replyToMessage = null;
//     _isReplyMode = false;
//     _scheduleNotification();
//   }

//   // Connect to socket
//   Future<bool> connect() async {
//     if (_isDisposed) return false;

//     try {
//       return await _socketEventController.connect();
//     } catch (e) {
//       _error = "Failed to connect: ${e.toString()}";
//       _scheduleNotification();
//       return false;
//     }
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // MESSAGE SEEN STATUS METHODS
//   // ═══════════════════════════════════════════════════════════════════════════

//   /// Mark a specific message as seen
//   Future<void> markMessageAsSeen(int chatId, int messageId) async {
//     if (_isDisposed) return;

//     try {
//       _logger.d(
//         'Marking message as seen - chatId: $chatId, messageId: $messageId',
//       );

//       // Emit via socket controller
//       _socketEventController.emitMessageSeen(chatId, messageId);

//       // Optional: Update local state immediately for better UX
//       _updateLocalMessageSeenStatus(messageId);

//       _logger.d('Message marked as seen successfully');
//     } catch (e) {
//       _error = "Failed to mark message as seen: ${e.toString()}";
//       _logger.e('Error marking message as seen: $e');
//       _scheduleNotification();
//     }
//   }

//   /// Update local message seen status (for immediate UI feedback)
//   void _updateLocalMessageSeenStatus(int messageId) {
//     if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
//       for (var message in _chatsData.records!) {
//         if (message.messageId == messageId) {
//           message.messageSeenStatus = 'seen';
//           _logger.d('Updated local message $messageId status to seen');
//           break;
//         }
//       }
//       _scheduleNotification();
//     }
//   }

//   /// Auto-mark messages as seen when entering a chat
//   Future<void> markChatMessagesAsSeen(int chatId) async {
//     if (_isDisposed || chatId <= 0) return;

//     // ✅ CRITICAL: Only mark if ALL conditions are met
//     if (!isChatScreenActive || !isAppInForeground) {
//       _logger.d(
//         'Skipping mark messages as seen - screen not active or app in background. '
//         'screenActive: $isChatScreenActive, appForeground: $isAppInForeground',
//       );
//       return;
//     }

//     // ✅ ADDITIONAL CHECK: Ensure we're actually viewing the correct chat
//     if (_currentChatData.chatId != chatId) {
//       _logger.d(
//         'Skipping mark messages as seen - chat ID mismatch. '
//         'current: ${_currentChatData.chatId}, requested: $chatId',
//       );
//       return;
//     }

//     try {
//       // Get current user ID
//       final currentUserId = await _getCurrentUserId();
//       if (currentUserId == null) {
//         _logger.w(
//           'Cannot mark messages as seen - current user ID not available',
//         );
//         return;
//       }

//       // ✅ ENHANCED: Find unread messages from OTHER users only
//       final unreadMessages =
//           _chatsData.records
//               ?.where(
//                 (message) =>
//                     message.senderId !=
//                         currentUserId && // Only messages from other users
//                     message.messageSeenStatus != 'seen' &&
//                     message.messageId != null &&
//                     message.deletedForEveryone != true,
//               ) // Don't mark deleted messages
//               .toList() ??
//           [];

//       if (unreadMessages.isNotEmpty) {
//         _logger.d(
//           'Marking ${unreadMessages.length} messages from OTHER users as seen '
//           '(screen is active and app in foreground)',
//         );

//         // ✅ BATCH PROCESSING: Mark messages in smaller batches to avoid overwhelming the server
//         const batchSize = 3;
//         for (int i = 0; i < unreadMessages.length; i += batchSize) {
//           // Check if conditions are still met before each batch
//           if (!isChatScreenActive || !isAppInForeground || _isDisposed) {
//             _logger.d('Conditions changed, stopping seen marking');
//             break;
//           }

//           final batch = unreadMessages.skip(i).take(batchSize).toList();

//           for (var message in batch) {
//             // Final check before marking each message
//             if (!isChatScreenActive || _isDisposed) {
//               _logger.d('Screen became inactive, stopping seen marking');
//               return;
//             }

//             _logger.d(
//               'Marking message ${message.messageId} as seen '
//               '(from user ${message.senderId}, current user $currentUserId)',
//             );

//             await markMessageAsSeen(chatId, message.messageId!);

//             // Small delay between individual requests
//             await Future.delayed(Duration(milliseconds: 150));
//           }

//           // Longer delay between batches
//           if (i + batchSize < unreadMessages.length) {
//             await Future.delayed(Duration(milliseconds: 300));
//           }
//         }

//         _logger.i(
//           'Successfully processed ${unreadMessages.length} unread messages from other users',
//         );
//       } else {
//         _logger.d('No unread messages from other users to mark as seen');
//       }
//     } catch (e) {
//       _logger.e('Error marking chat messages as seen: $e');
//     }
//   }

//   /// Check if a message has been seen
//   bool isMessageSeen(int messageId) {
//     if (_chatsData.records == null || _chatsData.records!.isEmpty) {
//       return false;
//     }

//     try {
//       final message = _chatsData.records!.firstWhere(
//         (msg) => msg.messageId == messageId,
//       );
//       return message.messageSeenStatus == 'seen';
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Get current user ID for permission checks
//   Future<int?> _getCurrentUserId() async {
//     try {
//       if (_currentUserId != null && _currentUserId!.isNotEmpty) {
//         return int.tryParse(_currentUserId!);
//       }

//       final userIdString = await SecurePrefs.getString(
//         SecureStorageKeys.USERID,
//       );
//       return int.tryParse(userIdString ?? '');
//     } catch (e) {
//       _logger.e('Error getting current user ID: $e');
//       return null;
//     }
//   }

//   /// Delete message for everyone (via socket)
//   Future<bool> deleteMessageForEveryone(int chatId, int messageId) async {
//     if (_isDisposed) return false;

//     try {
//       _logger.d(
//         '🗑️ Emitting delete message for everyone - ChatID: $chatId, MessageID: $messageId',
//       );

//       // Emit socket event for delete for everyone
//       _socketEventController.emitDeleteMessageForEveryone(chatId, messageId);

//       _logger.i('✅ Delete message for everyone event emitted successfully');

//       // Clear any existing error
//       _error = null;
//       _scheduleNotification();

//       return true;
//     } catch (e) {
//       _error = "Failed to delete message: ${e.toString()}";
//       _logger.e('❌ Delete message for everyone error: $e');
//       _scheduleNotification();
//       return false;
//     }
//   }

//   Future<bool> deleteMessageForMe(int chatId, int messageId) async {
//     if (_isDisposed) return false;

//     try {
//       _logger.d(
//         '🗑️ Emitting delete message for me - ChatID: $chatId, MessageID: $messageId',
//       );

//       // Emit socket event for delete for me
//       _socketEventController.emitDeleteMessageForMe(chatId, messageId);

//       _logger.i('✅ Delete message for me event emitted successfully');

//       // Clear any existing error
//       _error = null;
//       _scheduleNotification();

//       return true;
//     } catch (e) {
//       _error = "Failed to delete message: ${e.toString()}";
//       _logger.e('❌ Delete message for me error: $e');
//       _scheduleNotification();
//       return false;
//     }
//   }

//   @override
//   void dispose() {
//     _logger.d("ChatProvider disposing");
//     _isDisposed = true;

//     // Cancel timers
//     _notifyTimer?.cancel();
//     _notifyTimer = null;
//     _highlightTimer?.cancel();
//     _highlightTimer = null;

//     // Stop any ongoing search
//     _stopMessageSearch();

//     // Dispose subscriptions
//     _disposeSubscriptions();

//     super.dispose();
//   }

//   Future<void> downloadPdfWithProgress({
//     required String pdfUrl,
//     required Function(double) onProgress,
//     required Function(String?, String?) onComplete,
//     bool isOpenPdf = false,
//   }) async {
//     try {
//       final directory = await getApplicationDocumentsDirectory();
//       final filePath = '${directory.path}/${pdfUrl.split('/').last}';
//       final file = File(filePath);

//       if (await file.exists()) {
//         String metadata = await getPdfMetadataWhenDownloaded(filePath);
//         onComplete(filePath, metadata);
//         return;
//       }

//       var request = await HttpClient().getUrl(Uri.parse(pdfUrl));
//       var response = await request.close();

//       if (response.statusCode != HttpStatus.ok) {
//         onComplete(null, "Download failed: ${response.statusCode}");
//         return;
//       }

//       var totalBytes = response.contentLength;
//       var bytesReceived = 0;
//       var fileSink = file.openWrite();

//       await response.forEach((chunk) {
//         bytesReceived += chunk.length;
//         fileSink.add(chunk);
//         double progress = bytesReceived / totalBytes;
//         onProgress(progress);
//       });

//       await fileSink.flush();
//       await fileSink.close();

//       String metadata = await getPdfMetadataWhenDownloaded(filePath);
//       onComplete(filePath, metadata);
//     } catch (e) {
//       onComplete(null, "Error: ${e.toString()}");
//     }
//   }

//   // Get chat list using socket (for real-time updates)
//   Future<void> emitChatList() async {
//     if (_isDisposed) return;

//     try {
//       _logger.d("Emitting chat list request via socket");
//       await _socketEventController.emitChatList();
//     } catch (e) {
//       _error = "Failed to get chat list: ${e.toString()}";
//       _scheduleNotification();
//     }
//   }

//   /// Load more chat list data (pagination)
//   Future<void> loadMoreChatList() async {
//     if (_isDisposed) return;

//     // Check if we can load more
//     if (_isChatListPaginationLoading || !_hasChatListMoreData) {
//       _logger.d(
//         'Chat list pagination skipped - loading: $_isChatListPaginationLoading, hasMore: $_hasChatListMoreData',
//       );
//       return;
//     }

//     // Check if we haven't reached the total pages
//     if (_chatListCurrentPage >= _chatListTotalPages) {
//       _logger.d('Reached last page of chat list');
//       _hasChatListMoreData = false;
//       return;
//     }

//     try {
//       _logger.d('🔄 Loading more chat list - page ${_chatListCurrentPage + 1}');
//       _isChatListPaginationLoading = true;
//       _scheduleNotification();

//       // Request next page
//       final nextPage = _chatListCurrentPage + 1;
//       await emitChatListWithPage(nextPage);

//       _logger.d('✅ Chat list pagination request sent for page $nextPage');
//     } catch (e) {
//       _error = "Failed to load more chat list: ${e.toString()}";
//       _logger.e("❌ Chat list pagination error: $e");
//       _isChatListPaginationLoading = false;
//       _scheduleNotification();
//     }
//   }

//   /// Request chat list with specific page
//   Future<void> emitChatListWithPage(int page) async {
//     try {
//       _logger.d('Requesting chat list for page $page');

//       // Emit socket event with pagination
//       _socketEventController.emitChatList(
//         page: page,
//         pageSize: _chatListPageSize,
//       );
//     } catch (e) {
//       _setError('Error requesting chat list: ${e.toString()}');
//       _isChatListPaginationLoading = false;
//       _scheduleNotification();
//     }
//   }

//   void _handleChatListPaginationResponse(ChatListModel newChatListData) {
//     try {
//       final pagination = newChatListData.pagination;
//       if (pagination != null) {
//         _chatListCurrentPage = pagination.currentPage ?? 1;
//         _chatListTotalPages = pagination.totalPages ?? 1;
//         _hasChatListMoreData = _chatListCurrentPage < _chatListTotalPages;

//         _logger.d(
//           '📊 Chat list pagination updated - Page: $_chatListCurrentPage/$_chatListTotalPages, HasMore: $_hasChatListMoreData',
//         );
//       }

//       if (_chatListCurrentPage == 1) {
//         // First page - replace all data
//         _chatListData = newChatListData;
//         _logger.d(
//           '📄 First page chat list loaded with ${_chatListData.chats.length} chats',
//         );
//       } else {
//         // Subsequent pages - append data
//         _appendChatListData(newChatListData);
//       }

//       _isChatListPaginationLoading = false;
//       _scheduleNotification();
//     } catch (e) {
//       _logger.e('Error handling chat list pagination response: $e');
//       _isChatListPaginationLoading = false;
//       _scheduleNotification();
//     }
//   }

//   /// Append new chat list data to existing data
//   void _appendChatListData(ChatListModel newChatListData) {
//     if (newChatListData.chats.isEmpty) {
//       _logger.w('⚠️ No new chats in pagination response');
//       return;
//     }

//     // Get existing chat IDs to prevent duplicates
//     final existingChatIds =
//         _chatListData.chats
//             .where((chat) => chat.records?.isNotEmpty == true)
//             .map((chat) => chat.records!.first.chatId)
//             .where((id) => id != null)
//             .toSet();

//     // Filter out duplicate chats
//     final uniqueNewChats =
//         newChatListData.chats.where((chat) {
//           if (chat.records?.isNotEmpty == true) {
//             final chatId = chat.records!.first.chatId;
//             return chatId != null && !existingChatIds.contains(chatId);
//           }
//           return false;
//         }).toList();

//     if (uniqueNewChats.isNotEmpty) {
//       _chatListData.chats.addAll(uniqueNewChats);
//       _logger.d(
//         '📑 Appended ${uniqueNewChats.length} unique chats. Total: ${_chatListData.chats.length}',
//       );
//     } else {
//       _logger.w(
//         '⚠️ All ${newChatListData.chats.length} new chats were duplicates',
//       );
//     }

//     // Update pagination metadata
//     _chatListData.pagination = newChatListData.pagination;
//   }

//   void resetChatListPagination() {
//     _chatListCurrentPage = 1;
//     _chatListTotalPages = 1;
//     _hasChatListMoreData = true;
//     _isChatListPaginationLoading = false;
//     _chatListData = ChatListModel(chats: []);
//     _scheduleNotification();
//   }

//   void forceHighlightRefresh(int messageId) {
//     if (_highlightedMessageId == messageId) {
//       _logger.d('🔄 Force refreshing highlight for message: $messageId');

//       // Clear current highlight
//       _highlightedMessageId = null;
//       _scheduleNotification();

//       // Re-apply highlight after a brief moment with extended duration
//       Future.delayed(Duration(milliseconds: 150), () {
//         if (!_isDisposed) {
//           _highlightedMessageId = messageId;
//           _scheduleNotification();

//           // Clear any existing highlight timer
//           _highlightTimer?.cancel();

//           // Extended highlight duration for better visibility
//           _highlightTimer = Timer(Duration(seconds: 8), () {
//             // Increased to 8 seconds
//             if (!_isDisposed) {
//               _logger.d(
//                 '⏰ Clearing refreshed highlight for message: $messageId',
//               );
//               _highlightedMessageId = null;
//               _scheduleNotification();
//             }
//           });

//           _logger.d('✨ Message $messageId highlight refreshed for 8 seconds');
//         }
//       });
//     } else {
//       // Direct highlight if not currently highlighted
//       highlightMessage(messageId);
//     }
//   }

//   // Format time for UI
//   String formatTime(String? time) {
//     return _socketEventController.formatTime(time);
//   }

//   // Generate video thumbnail
//   Future<String?> generateVideoThumbnail(String videoPath) async {
//     try {
//       final tempDir = await getTemporaryDirectory();
//       final thumbnailPath = await VideoThumbnail.thumbnailFile(
//         video: videoPath,
//         thumbnailPath: tempDir.path,
//         imageFormat: ImageFormat.PNG,
//         maxWidth: 300,
//         maxHeight: 300,
//         quality: 75,
//       );

//       _logger.d("Thumbnail generated: $thumbnailPath");
//       return thumbnailPath;
//     } catch (e) {
//       _logger.e("Failed to generate video thumbnail: $e");
//       return null;
//     }
//   }

//   /// Get delete permission text for UI
//   String getDeletePermissionText(chats.Records message) {
//     if (!canDeleteMessage(message)) {
//       return 'You can only delete your own messages';
//     }
//     return 'Delete Message';
//   }

//   // PDF related functionality (unchanged)
//   Future<String> getPdfMetadata(String pdfUrl) async {
//     try {
//       final response = await http.get(Uri.parse(pdfUrl));
//       if (response.statusCode != 200) return "Unknown PDF";

//       final PdfDocument document = PdfDocument(inputBytes: response.bodyBytes);
//       int pageCount = document.pages.count;
//       double fileSizeMB = response.bodyBytes.length / (1024 * 1024);

//       document.dispose();
//       return "$pageCount Pages • PDF • ${fileSizeMB.toStringAsFixed(2)} MB";
//     } catch (e) {
//       return "Error loading PDF";
//     }
//   }

//   Future<String> getPdfMetadataWhenDownloaded(String filePath) async {
//     try {
//       final file = File(filePath);

//       if (!await file.exists()) {
//         return "Unknown PDF";
//       }

//       final PdfDocument document = PdfDocument(
//         inputBytes: await file.readAsBytes(),
//       );
//       int pageCount = document.pages.count;
//       double fileSizeMB = file.lengthSync() / (1024 * 1024);

//       document.dispose();
//       return "$pageCount Pages • PDF • ${fileSizeMB.toStringAsFixed(2)} MB";
//     } catch (e) {
//       _logger.e("PDF Metadata Error: $e");
//       return "Error loading PDF";
//     }
//   }

//   /// Get pin/unpin permission text for UI
//   String getPinUnpinPermissionText(chats.Records message) {
//     if (!canPinUnpinMessage(message)) {
//       if (message.pinned == true) {
//         return 'Only the user who pinned this message can unpin it';
//       } else {
//         return 'You cannot pin this message';
//       }
//     }

//     return message.pinned == true ? 'Unpin Message' : 'Pin Message';
//   }

//   /// Get star/unstar permission text for UI
//   String getStarUnstarPermissionText(chats.Records message) {
//     if (!canStarUnStarMessage(message)) {
//       if (message.stared == true) {
//         return 'You cannot unstar this message';
//       } else {
//         return 'You cannot star this message';
//       }
//     }

//     return message.stared == true ? 'Unstar Message' : 'Star Message';
//   }

//   // ✅ ENHANCED: Highlight message method
//   void highlightMessage(int messageId) {
//     _logger.d('🎯 Highlighting message: $messageId');

//     _highlightedMessageId = messageId;
//     _scheduleNotification();

//     // Clear any existing highlight timer
//     _highlightTimer?.cancel();

//     // Extended highlight duration for better visibility
//     _highlightTimer = Timer(Duration(seconds: 5), () {
//       // Increased from 3 to 5 seconds
//       if (!_isDisposed) {
//         _logger.d('⏰ Clearing highlight for message: $messageId');
//         _highlightedMessageId = null;
//         _scheduleNotification();
//       }
//     });

//     _logger.d('✨ Message $messageId highlighted for 5 seconds');
//   }

//   // Initialize provider
//   initialize() async {
//     if (_isDisposed) return;

//     _logger.i('Initializing ChatProvider');
//     _isInitializing = true;
//     _scheduleNotification();

//     try {
//       // Re-initialize subscriptions
//       _initializeSubscriptions();

//       // Connect to socket if not already connected
//       if (!_socketEventController.isConnected) {
//         await connect();
//       }

//       // Refresh chat list data
//       await emitChatList();

//       // Get online users
//       _socketEventController.emitInitialOnlineUser();

//       _isInitializing = false;
//       _scheduleNotification();
//     } catch (e) {
//       _error = "Failed to initialize: ${e.toString()}";
//       _isInitializing = false;
//       _scheduleNotification();
//     }
//   }

//   // ✅ ADD NEW METHOD: Check if a message is pinned
//   bool isMessagePinned(int messageId) {
//     if (_chatsData.records == null || _chatsData.records!.isEmpty) {
//       return false;
//     }

//     try {
//       final message = _chatsData.records!.firstWhere(
//         (msg) => msg.messageId == messageId,
//       );
//       return message.pinned == true;
//     } catch (e) {
//       return false;
//     }
//   }

//   Future<bool> isPdfDownloaded(String pdfUrl) async {
//     final directory = await getApplicationDocumentsDirectory();
//     final filePath = '${directory.path}/${pdfUrl.split('/').last}';
//     return File(filePath).exists();
//   }

//   // Check if a user is online
//   bool isUserOnline(int userId) {
//     if (_isDisposed) return false;
//     return _socketEventController.isUserOnline(userId);
//   }

//   // Check if someone is typing in a chat
//   bool isUserTypingInChat(int chatId) {
//     if (_isDisposed) return false;

//     bool result = _socketEventController.isUserTypingInChat(chatId);
//     _logger.d("ChatProvider: isUserTypingInChat($chatId) = $result");
//     return result;
//   }

//   // Future<void> loadChatMessages({
//   //   required int chatId,
//   //   required int peerId,
//   //   bool clearExisting = true,
//   // }) async {
//   //   if (_isDisposed) return;

//   //   try {
//   //     _logger.d("Loading chat messages - chatId: $chatId, peerId: $peerId");

//   //     // Set the current chat context
//   //     setCurrentChat(chatId, peerId);

//   //     if (clearExisting) {
//   //       // Clear existing messages
//   //       _chatsData = chats.ChatsModel();
//   //       _pinnedMessagesData = chats.ChatsModel();
//   //       _lastChatsDataHash = null;
//   //       _scheduleNotification();
//   //     }

//   //     // Load messages from socket
//   //     if (chatId > 0) {
//   //       // Existing chat
//   //       await _socketEventController.emitChatMessages(chatId: chatId);
//   //     } else {
//   //       // New chat with user
//   //       await _socketEventController.emitChatMessages(peerId: peerId);
//   //     }

//   //     _logger.d("Chat messages loading initiated");
//   //   } catch (e) {
//   //     _error = "Failed to load chat messages: ${e.toString()}";
//   //     _logger.e("Error loading chat messages: $e");
//   //     _scheduleNotification();
//   //   }
//   // }

//   Future<void> loadChatMessages({
//     required int chatId,
//     required int peerId,
//     bool clearExisting = true,
//   }) async {
//     if (_isDisposed) return;

//     try {
//       _logger.d("Loading chat messages - chatId: $chatId, peerId: $peerId");

//       // Set the current chat context
//       setCurrentChat(chatId, peerId);

//       if (clearExisting) {
//         // Clear existing messages
//         _chatsData = chats.ChatsModel();
//         _pinnedMessagesData = chats.ChatsModel();
//         _lastChatsDataHash = null;
//         _scheduleNotification();
//       }

//       // Load messages from socket
//       if (chatId > 0) {
//         // Existing chat
//         await _socketEventController.emitChatMessages(chatId: chatId);

//         // ✅ ENHANCED: Wait for messages to load, then mark as seen
//         Future.delayed(Duration(milliseconds: 2000), () async {
//           if (!_isDisposed && _currentChatData.chatId == chatId) {
//             // Ensure messages are actually loaded
//             if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
//               _logger.d('Messages loaded, now marking unread messages as seen');
//               await markChatMessagesAsSeen(chatId);
//             } else {
//               _logger.w('Messages not loaded yet after 2 seconds');
//             }
//           }
//         });
//       } else {
//         // New chat with user
//         await _socketEventController.emitChatMessages(peerId: peerId);
//       }

//       _logger.d("Chat messages loading initiated");
//     } catch (e) {
//       _error = "Failed to load chat messages: ${e.toString()}";
//       _logger.e("Error loading chat messages: $e");
//       _scheduleNotification();
//     }
//   }

//   // Load more messages (for pagination)
//   // Future<void> loadMoreMessages() async {
//   //   if (_isDisposed) return;

//   //   // ✅ SIMPLE CHECKS: Only check what's essential
//   //   if (_isPaginationLoading || !hasMoreMessages) {
//   //     _logger.d(
//   //       'Pagination skipped - loading: $_isPaginationLoading, hasMore: $hasMoreMessages',
//   //     );
//   //     return;
//   //   }

//   //   try {
//   //     _logger.d('🔄 Starting pagination load');
//   //     _setPaginationLoading(true);

//   //     // ✅ DELEGATE TO SOCKET CONTROLLER: Let it handle the complexity
//   //     await _socketEventController.loadMoreMessages();

//   //     _logger.d('✅ Pagination load completed');
//   //   } catch (e) {
//   //     _error = "Failed to load more messages: ${e.toString()}";
//   //     _logger.e("❌ Pagination error: $e");
//   //     _scheduleNotification();
//   //   } finally {
//   //     // ✅ ALWAYS RESET LOADING STATE
//   //     _setPaginationLoading(false);
//   //   }
//   // }

//   Future<void> loadMoreMessages() async {
//     if (_isDisposed) return;

//     // ✅ Check all conditions including our own loading state
//     if (_isPaginationLoading ||
//         !hasMoreMessages ||
//         isChatLoading ||
//         isRefreshing) {
//       _logger.d(
//         'Pagination skipped - loading: $_isPaginationLoading, hasMore: $hasMoreMessages, chatLoading: $isChatLoading, refreshing: $isRefreshing',
//       );
//       return;
//     }

//     try {
//       _logger.d('🔄 Starting pagination load');

//       // ✅ CRITICAL: Set loading state BEFORE calling socket controller
//       _setPaginationLoading(true);

//       // ✅ DELEGATE TO SOCKET CONTROLLER
//       await _socketEventController.loadMoreMessages();

//       _logger.d('✅ Pagination load completed');
//     } catch (e) {
//       _error = "Failed to load more messages: ${e.toString()}";
//       _logger.e("❌ Pagination error: $e");
//       _scheduleNotification();
//     } finally {
//       // ✅ ALWAYS RESET LOADING STATE
//       _setPaginationLoading(false);
//     }
//   }

//   /// Pin or unpin a message
//   Future<bool> pinUnpinMessage(
//     int chatId,
//     int messageId, [
//     int inDays = 1,
//   ]) async {
//     if (_isDisposed) return false;

//     try {
//       // Find the message to check permissions
//       chats.Records? targetMessage;
//       if (_chatsData.records != null) {
//         try {
//           targetMessage = _chatsData.records!.firstWhere(
//             (msg) => msg.messageId == messageId,
//           );
//         } catch (e) {
//           _logger.w('Message not found in current chat data: $messageId');
//         }
//       }

//       // Check permissions if message found
//       if (targetMessage != null && !canPinUnpinMessage(targetMessage)) {
//         _error = getPinUnpinPermissionText(targetMessage);
//         _scheduleNotification();
//         return false;
//       }

//       // If message is currently pinned and no specific duration provided, unpin it
//       if (targetMessage?.pinned == true && inDays == 1) {
//         inDays = 0; // Set to unpin
//       }

//       _logger.d(
//         'Pin/Unpin message via API - chatId: $chatId, messageId: $messageId, inDays: $inDays',
//       );

//       // ✅ USE API TO PIN/UNPIN MESSAGE WITH DURATION
//       final success = await _chatRepository.pinUnpinMessage(
//         chatId: chatId,
//         messageId: messageId,
//         inDays: inDays,
//       );

//       if (success && !_isDisposed) {
//         // ✅ API SUCCESS - Socket listener will handle UI updates
//         // No need to manually refresh as socket will send updated data
//         _logger.i('Message pin/unpin successful via API');

//         // Optional: Clear any existing error
//         _error = null;
//         _scheduleNotification();

//         return true;
//       } else {
//         _error = "Failed to pin/unpin message via API";
//         _logger.e('Pin/unpin message API returned false');
//         _scheduleNotification();
//         return false;
//       }
//     } catch (e) {
//       _error = "Failed to pin/unpin message: ${e.toString()}";
//       _logger.e('Pin/unpin message error: $e');
//       _scheduleNotification();
//       return false;
//     }
//   }

//   bool isMessageStarred(int messageId) {
//     if (_chatsData.records == null || _chatsData.records!.isEmpty) {
//       return false;
//     }

//     try {
//       final message = _chatsData.records!.firstWhere(
//         (msg) => msg.messageId == messageId,
//       );

//       // Check both stared field and starredFor array
//       if (message.stared == true) {
//         return true;
//       }

//       // Check if current user is in starredFor array
//       if (message.starredFor != null && message.starredFor!.isNotEmpty) {
//         return message.starredFor!.contains(_currentUserId);
//       }

//       return false;
//     } catch (e) {
//       _logger.w('Message $messageId not found for star check: $e');
//       return false;
//     }
//   }

//   /// Star or Unstar a message method
//   Future<bool> starUnstarMessage(int messageId) async {
//     if (_isDisposed) return false;

//     try {
//       // Find the message to check permissions and current state
//       chats.Records? targetMessage;
//       if (_chatsData.records != null) {
//         try {
//           targetMessage = _chatsData.records!.firstWhere(
//             (msg) => msg.messageId == messageId,
//           );
//         } catch (e) {
//           _logger.w('Message not found in current chat data: $messageId');
//         }
//       }

//       // Check permissions if message found
//       if (targetMessage != null && !canStarUnStarMessage(targetMessage)) {
//         _error = getStarUnstarPermissionText(targetMessage);
//         _scheduleNotification();
//         return false;
//       }

//       _logger.d('Star/Unstar message via API - messageId: $messageId');

//       // ✅ USE API TO STAR/UNSTAR MESSAGE
//       final success = await _chatRepository.starUnStarMessage(
//         messageId: messageId,
//       );

//       if (success && !_isDisposed) {
//         // ✅ API SUCCESS - Socket listener will handle UI updates automatically
//         _logger.i('Message Star/UnStar successful via API');

//         // Optional: Clear any existing error
//         _error = null;
//         _scheduleNotification();

//         // ✅ The socket listener will automatically update the UI when the
//         // starUnstarMessage event is received, so no manual update needed here

//         return true;
//       } else {
//         _error = "Failed to Star/UnStar message via API";
//         _logger.e('Star/UnStar message API returned false');
//         _scheduleNotification();
//         return false;
//       }
//     } catch (e) {
//       _error = "Failed to Star/UnStar message: ${e.toString()}";
//       _logger.e('Star/UnStar message error: $e');
//       _scheduleNotification();
//       return false;
//     }
//   }

//   // Handle refreshing chat list
//   // Future<void> refreshChatList() async {
//   //   if (_isDisposed) return;

//   //   try {
//   //     await _socketEventController.refreshChatList();
//   //   } catch (e) {
//   //     _logger.e("Error refreshing chat list: $e");
//   //   }
//   // }

//   /// Handle refreshing chat list (updated for pagination)
//   Future<void> refreshChatList() async {
//     if (_isDisposed) return;

//     try {
//       _logger.d("🔄 Refreshing chat list from first page");

//       // Reset pagination state
//       resetChatListPagination();

//       // Request first page
//       await emitChatListWithPage(1);
//     } catch (e) {
//       _logger.e("Error refreshing chat list: $e");
//       _error = "Failed to refresh chat list: ${e.toString()}";
//       _scheduleNotification();
//     }
//   }

//   Future<void> refreshChatMessages({
//     required int chatId,
//     required int peerId,
//   }) async {
//     if (_isDisposed) return;

//     // Prevent multiple simultaneous refreshes
//     if (isRefreshing) {
//       _logger.d('Already refreshing, ignoring duplicate request');
//       return;
//     }

//     try {
//       _logger.d(
//         "🔄 Starting chat messages refresh - chatId: $chatId, peerId: $peerId",
//       );

//       // Use the socket controller's dedicated refresh method
//       await _socketEventController.refreshChatMessages(chatId, peerId);

//       _logger.d("✅ Chat messages refresh completed");
//     } catch (e) {
//       _logger.e("❌ Error refreshing chat messages: $e");
//       _error = "Failed to refresh chat messages: ${e.toString()}";
//       _scheduleNotification();
//       rethrow;
//     }
//   }

//   void scrollToPinnedMessage(int messageId, ScrollController scrollController) {
//     if (_chatsData.records == null || _chatsData.records!.isEmpty) {
//       _logger.w('No chat messages to scroll to');
//       return;
//     }

//     try {
//       // Find the index of the message in the chat list
//       final messageIndex = _chatsData.records!.indexWhere(
//         (message) => message.messageId == messageId,
//       );

//       if (messageIndex != -1) {
//         // Highlight the message
//         highlightMessage(messageId);

//         // Calculate scroll position (approximate)
//         // Assuming each message bubble is roughly 80 pixels high
//         const double averageMessageHeight = 80.0;
//         final double targetPosition = messageIndex * averageMessageHeight;

//         // Scroll to the message
//         scrollController.animateTo(
//           targetPosition,
//           duration: Duration(milliseconds: 500),
//           curve: Curves.easeInOut,
//         );

//         _logger.d('Scrolling to pinned message at index $messageIndex');
//       } else {
//         _logger.w(
//           'Pinned message with ID $messageId not found in current chat',
//         );
//       }
//     } catch (e) {
//       _logger.e('Error scrolling to pinned message: $e');
//     }
//   }

//   // ✅ UPDATED: Send message using ChatRepository
//   Future<bool> sendMessage(
//     int chatId,
//     String messageContent, {
//     required MessageType messageType,
//     int? userId,
//     Uint8List? bytes,
//     int? replyToMessageId, // ✅ NEW: Add reply parameter
//   }) async {
//     if (_isDisposed) return false;

//     try {
//       _isSendingMessage = true;
//       _isShowAttachments = false;
//       _scheduleNotification();

//       // Determine if this is a new chat
//       bool isNewChat = chatId == 0;
//       final peerID = _currentChatData.userId;

//       _logger.d(
//         'Sending message to ${isNewChat ? "new user" : "existing chat"}: $chatId, peer ID: $peerID, type: $messageType, replyTo: $replyToMessageId',
//       );
//       // Handle message content for different types
//       String finalMessageContent = messageContent;
//       if (messageContent.isEmpty) {
//         switch (messageType) {
//           case MessageType.Video:
//             finalMessageContent = "Shared a video";
//             break;
//           case MessageType.Image:
//             finalMessageContent = "Shared an image";
//             break;
//           case MessageType.File:
//             finalMessageContent = "Shared a document";
//             break;
//           case MessageType.Gif:
//             finalMessageContent = "Shared a GIF";
//             break;
//           default:
//             finalMessageContent = messageContent;
//         }
//       }

//       // Prepare file paths for attachments
//       Map<String, dynamic> filePaths = {};

//       if (MessageTypeUtils.requiresFileUpload(messageType)) {
//         _logger.d('Processing file upload for type: $messageType');

//         switch (messageType) {
//           case MessageType.Image:
//             if (_shareImage != null && _shareImage!.isNotEmpty) {
//               filePaths['files'] = _shareImage![0].path;
//               _logger.d('Added image file: ${_shareImage![0].path}');
//             }
//             break;

//           case MessageType.File:
//             if (_shareDocument != null && _shareDocument!.isNotEmpty) {
//               filePaths['files'] = _shareDocument![0].path;
//               _logger.d('Added document file: ${_shareDocument![0].path}');
//             }
//             break;

//           case MessageType.Video:
//             List<String> videoFiles = [];

//             if (_shareVideo != null && _shareVideo!.isNotEmpty) {
//               String videoPath = _shareVideo![0].path;
//               String thumbnailPath = _shareVideoThumbnail;

//               // Generate thumbnail if missing
//               if (_shareVideoThumbnail.isEmpty ||
//                   !File(_shareVideoThumbnail).existsSync()) {
//                 _logger.w('Video thumbnail not available, generating...');
//                 final generatedThumbnail = await generateVideoThumbnail(
//                   videoPath,
//                 );
//                 if (generatedThumbnail != null &&
//                     generatedThumbnail.isNotEmpty) {
//                   thumbnailPath = generatedThumbnail;
//                   _shareVideoThumbnail = thumbnailPath;
//                   _logger.d('Generated thumbnail: $thumbnailPath');
//                 }
//               }

//               // Add thumbnail first, then video
//               if (thumbnailPath.isNotEmpty &&
//                   File(thumbnailPath).existsSync()) {
//                 videoFiles.add(thumbnailPath);
//                 _logger.d('Added thumbnail: $thumbnailPath');
//               }

//               videoFiles.add(videoPath);
//               _logger.d('Added video file: $videoPath');

//               filePaths['files'] = videoFiles;
//             } else {
//               _logger.e('No video file available for upload');
//               throw Exception('No video file selected');
//             }
//             break;

//           case MessageType.Gif:
//             if (_shareImage != null && _shareImage!.isNotEmpty) {
//               filePaths['files'] = _shareImage![0].path;
//               _logger.d('Added GIF file: ${_shareImage![0].path}');
//             }
//             break;

//           default:
//             _logger.w(
//               'Unknown message type or no file processing needed: $messageType',
//             );
//             break;
//         }
//       }

//       // Validate that required files are present
//       if (MessageTypeUtils.requiresFileUpload(messageType) &&
//           filePaths.isEmpty) {
//         throw Exception(
//           'File upload required but no files provided for message type: $messageType',
//         );
//       }

//       // ✅ UPDATED: Use ChatRepository to send message
//       final response = await _chatRepository.sendMessage(
//         chatId: chatId,
//         messageContent: finalMessageContent,
//         messageType: messageType,
//         userId: isNewChat ? peerID : null,
//         filePaths: filePaths.isNotEmpty ? filePaths : null,
//         replyToMessageId: replyToMessageId, // ✅ NEW: Pass reply ID
//       );

//       // Process the response
//       if (response != null && !_isDisposed) {
//         _logger.d('Send message response: $response');

//         //Clear reply state after successful send
//         if (replyToMessageId != null) {
//           clearReply();
//         }

//         // Handle new chat creation and message refresh
//         if (isNewChat && response['data'] != null) {
//           var newChatId = 0;
//           if (response['data']['chat_id'] != null) {
//             newChatId = int.parse(response['data']['chat_id'].toString());
//           }

//           if (newChatId > 0 && !_isDisposed) {
//             _logger.i('New chat created with ID: $newChatId');
//             _currentChatData = ChatIds(chatId: newChatId, userId: peerID ?? 0);
//             _socketEventController.setCurrentChat(newChatId, peerID ?? 0);

//             await Future.delayed(Duration(milliseconds: 500));
//             if (!_isDisposed) {
//               await _socketEventController.emitChatMessages(
//                 chatId: newChatId,
//                 peerId: peerID ?? 0,
//               );
//             }
//           }
//         } else if (!isNewChat && !_isDisposed) {
//           await Future.delayed(Duration(milliseconds: 300));
//           if (!_isDisposed) {
//             await _socketEventController.emitChatMessages(
//               chatId: chatId,
//               peerId: peerID ?? 0,
//             );
//           }
//         }

//         // Clear file storage after successful send
//         _shareImage = null;
//         _shareDocument = null;
//         _shareVideo = null;
//         _shareVideoThumbnail = "";

//         if (!_isDisposed) {
//           refreshChatList();
//         }

//         _isSendingMessage = false;
//         _scheduleNotification();
//         return true;
//       } else {
//         _error = "Failed to send message: Server returned null response";
//         _isSendingMessage = false;
//         _scheduleNotification();
//         return false;
//       }
//     } catch (e) {
//       _error = "Failed to send message: ${e.toString()}";
//       _isSendingMessage = false;
//       _logger.e('Send message failed: $e');
//       _scheduleNotification();
//       return false;
//     }
//   }

//   // Send typing status
//   void sendTypingStatus(int chatId, bool isTyping) {
//     if (_isDisposed) return;

//     _logger.d(
//       "ChatProvider: Sending typing status - ChatId: $chatId, IsTyping: $isTyping",
//     );
//     _socketEventController.sendTypingIndicator(chatId.toString(), isTyping);
//   }

//   // Set current chat

//   // void setCurrentChat(int chatId, int userId) {
//   //   if (_isDisposed) return;

//   //   _logger.d("Setting current chat - chatId: $chatId, userId: $userId");

//   //   // ✅ CLEAR OLD CHAT DATA FIRST
//   //   _chatsData = chats.ChatsModel();
//   //   _pinnedMessagesData = chats.ChatsModel(); // ✅ Clear pinned messages
//   //   _isPinnedMessagesExpanded = false;
//   //   _lastChatsDataHash = null;
//   //   clearHighlight();

//   //   // ✅ SET NEW CHAT DATA
//   //   _currentChatData = ChatIds(chatId: chatId, userId: userId);
//   //   _socketEventController.setCurrentChat(chatId, userId);

//   //   _scheduleNotification();
//   // }

//   void setCurrentChat(int chatId, int userId) {
//     if (_isDisposed) return;

//     _logger.d("Setting current chat - chatId: $chatId, userId: $userId");

//     // Clear old chat data first
//     _chatsData = chats.ChatsModel();
//     _pinnedMessagesData = chats.ChatsModel();
//     _isPinnedMessagesExpanded = false;
//     _lastChatsDataHash = null;
//     clearHighlight();

//     // Set new chat data
//     _currentChatData = ChatIds(chatId: chatId, userId: userId);
//     _socketEventController.setCurrentChat(chatId, userId);

//     // ✅ ENHANCED: Only auto-mark if screen is active and it's an existing chat
//     if (chatId > 0) {
//       // Longer delay to ensure all chat data is loaded and conditions are stable
//       Future.delayed(Duration(milliseconds: 2000), () async {
//         if (!_isDisposed &&
//             _currentChatData.chatId == chatId &&
//             isChatScreenActive &&
//             isAppInForeground) {
//           // ✅ CRITICAL: Double-check we have messages loaded before marking as seen
//           if (_chatsData.records != null && _chatsData.records!.isNotEmpty) {
//             _logger.d(
//               'Chat data loaded and screen active, marking messages as seen',
//             );
//             await markChatMessagesAsSeen(chatId);
//           } else {
//             _logger.d('Chat data not yet loaded, skipping auto-mark seen');
//           }
//         } else {
//           _logger.d(
//             'Skipping auto-mark seen on setCurrentChat - conditions not met. '
//             'disposed: $_isDisposed, '
//             'chatMatch: ${_currentChatData.chatId == chatId}, '
//             'screenActive: $isChatScreenActive, '
//             'appForeground: $isAppInForeground',
//           );
//         }
//       });
//     }

//     _scheduleNotification();
//   }

//   void setPinnedMessagesExpanded(bool expanded) {
//     if (_isPinnedMessagesExpanded != expanded) {
//       _isPinnedMessagesExpanded = expanded;
//       _scheduleNotification();
//     }
//   }

//   // ✅ NEW: Reply methods
//   void setReplyToMessage(chats.Records? message) {
//     _replyToMessage = message;
//     _isReplyMode = message != null;
//     _scheduleNotification();
//   }

//   // Set document for sharing
//   void setShareDocument(List<File> documents) {
//     if (_isDisposed) return;
//     _shareDocument = documents;
//     _logger.d("Set share document: ${documents.length} files");
//     _scheduleNotification();
//   }

//   // Set image for sharing
//   void setShareImage(List<File> images) {
//     if (_isDisposed) return;
//     _shareImage = images;
//     _logger.d("Set share image: ${images.length} files");
//     _scheduleNotification();
//   }

//   // Set video for sharing
//   void setShareVideo(List<File> videos, String thumbnail) {
//     if (_isDisposed) return;
//     _shareVideo = videos;
//     _shareVideoThumbnail = thumbnail;
//     _logger.d("Set share video: ${videos.length} files, thumbnail: $thumbnail");
//     _scheduleNotification();
//   }

//   Future<void> setShareVideoWithThumbnail(List<File> videos) async {
//     if (_isDisposed || videos.isEmpty) return;

//     try {
//       _logger.d("Setting share video with thumbnail generation");

//       _shareVideo = videos;

//       // Generate thumbnail for the first video
//       final videoFile = videos.first;
//       final thumbnailPath = await generateVideoThumbnail(videoFile.path);

//       _shareVideoThumbnail = thumbnailPath ?? "";

//       _logger.d(
//         "Video set successfully - Video: ${videoFile.path}, Thumbnail: $_shareVideoThumbnail",
//       );
//       _scheduleNotification();
//     } catch (e) {
//       _logger.e("Error setting video with thumbnail: $e");
//       _shareVideo = videos;
//       _shareVideoThumbnail = "";
//       _scheduleNotification();
//     }
//   }

//   // Silent refresh that doesn't show loading indicators
//   Future<void> silentRefresh() async {
//     if (_isDisposed) return;

//     try {
//       await _socketEventController.silentRefresh();
//     } catch (e) {
//       _logger.e("Error in silent refresh: $e");
//     }
//   }

//   // ✅ NEW: Stop message search
//   void stopMessageSearch() {
//     if (!_isSearchingForMessage) {
//       _logger.d('⚠️ No active search to stop');
//       return;
//     }

//     _logger.d('🛑 Stopping message search by user request');

//     // Call the private method that handles cleanup
//     _stopMessageSearch();

//     // Optional: Show feedback that search was cancelled
//     _logger.i('✅ Message search stopped successfully');
//   }

//   // Toggle attachment menu
//   void toggleAttachments() {
//     if (_isDisposed) return;

//     _isShowAttachments = !_isShowAttachments;
//     _scheduleNotification();
//   }

//   // ✅ NEW: Pinned messages methods
//   void togglePinnedMessagesExpansion() {
//     _isPinnedMessagesExpanded = !_isPinnedMessagesExpanded;
//     _scheduleNotification();
//   }

//   // ✅ NEW: Cancel search timeout
//   void _cancelSearchTimeout() {
//     _searchTimeoutTimer?.cancel();
//     _searchTimeoutTimer = null;
//   }

//   void _clearHighlightSilently() {
//     if (_highlightTimer != null) {
//       _highlightTimer!.cancel();
//       _highlightTimer = null;
//     }
//     _highlightedMessageId = null;
//   }

//   // ✅ NEW: Create updated record preserving all data
//   chats.Records _createUpdatedRecord(
//     chats.Records existing,
//     chats.Records updated,
//   ) {
//     return chats.Records(
//       messageContent: existing.messageContent,
//       replyTo: existing.replyTo,
//       socialId: existing.socialId,
//       messageId: existing.messageId,
//       messageType: existing.messageType,
//       messageLength: existing.messageLength,
//       messageSeenStatus: existing.messageSeenStatus,
//       messageSize: existing.messageSize,
//       deletedFor: existing.deletedFor,
//       starredFor: existing.starredFor,
//       deletedForEveryone: existing.deletedForEveryone,
//       // ✅ UPDATE PIN-RELATED FIELDS
//       pinned: updated.pinned,
//       pinLifetime: updated.pinLifetime,
//       pinnedTill: updated.pinnedTill,
//       // ✅ PRESERVE ORIGINAL DATA
//       createdAt: existing.createdAt,
//       updatedAt: updated.updatedAt ?? existing.updatedAt,
//       chatId: existing.chatId,
//       senderId: existing.senderId,
//       parentMessage: existing.parentMessage,
//       replies: existing.replies,
//       user: existing.user,
//       peerUserData: existing.peerUserData,
//     );
//   }

//   // Dispose of all subscriptions
//   void _disposeSubscriptions() {
//     _chatListSubscription?.cancel();
//     _chatsSubscription?.cancel();
//     _chatIdsSubscription?.cancel();
//     _onlineUsersSubscription?.cancel();
//     _typingSubscription?.cancel();
//     _pinUnpinSubscription?.cancel();
//     _starUnstarSubscription?.cancel();

//     _chatListSubscription = null;
//     _chatsSubscription = null;
//     _chatIdsSubscription = null;
//     _onlineUsersSubscription = null;
//     _typingSubscription = null;
//     _pinUnpinSubscription = null;
//     _starUnstarSubscription = null;
//   }

//   /// ✅ NEW: Extract pinned messages from chat response using your actual model
//   void _extractPinnedMessages(chats.ChatsModel data) {
//     try {
//       _logger.d("🔍 Extracting pinned messages from chat data");

//       // ✅ PRIORITY 1: Check if socket controller has pinned data first
//       final socketPinnedData = _socketEventController.pinnedMessagesData;
//       if (socketPinnedData.records != null &&
//           socketPinnedData.records!.isNotEmpty) {
//         _logger.d(
//           "✅ Found ${socketPinnedData.records!.length} pinned messages from socket controller",
//         );

//         // Verify these belong to current chat
//         final currentChatId = _currentChatData.chatId ?? 0;
//         if (currentChatId > 0) {
//           final relevantPinnedMessages =
//               socketPinnedData.records!
//                   .where((record) => record.chatId == currentChatId)
//                   .toList();

//           if (relevantPinnedMessages.isNotEmpty) {
//             _pinnedMessagesData = chats.ChatsModel(
//               records: relevantPinnedMessages,
//               pagination: chats.Pagination(
//                 totalRecords: relevantPinnedMessages.length,
//                 currentPage: 1,
//                 totalPages: 1,
//                 recordsPerPage: relevantPinnedMessages.length,
//               ),
//             );
//             _logger.d(
//               "✅ Set ${relevantPinnedMessages.length} pinned messages from socket controller",
//             );
//             return;
//           }
//         }
//       }

//       // ✅ PRIORITY 2: Extract from current chat data
//       if (data.records != null && data.records!.isNotEmpty) {
//         final pinnedMessages =
//             data.records!.where((record) => record.pinned == true).toList();

//         _pinnedMessagesData = chats.ChatsModel(
//           records: pinnedMessages,
//           pagination: chats.Pagination(
//             totalRecords: pinnedMessages.length,
//             currentPage: 1,
//             totalPages: 1,
//             recordsPerPage: pinnedMessages.length,
//           ),
//         );

//         _logger.d(
//           "✅ Extracted ${pinnedMessages.length} pinned messages from current chat data",
//         );
//         return;
//       }

//       // ✅ DEFAULT: Clear pinned messages if nothing found
//       _pinnedMessagesData = chats.ChatsModel();
//       _logger.d("No pinned messages found, clearing pinned data");
//     } catch (e) {
//       _logger.e("❌ Error extracting pinned messages: $e");
//       _pinnedMessagesData = chats.ChatsModel();
//     }
//   }

//   // Helper method to generate hash for data comparison
//   String _generateDataHash(chats.ChatsModel data) {
//     if (data.records == null || data.records!.isEmpty) {
//       return 'empty';
//     }

//     final lastMessage = data.records!.first;
//     return '${data.records!.length}_${lastMessage.messageId}_${lastMessage.createdAt}';
//   }

//   // Initialize subscriptions to SocketEventController streams
//   void _initializeSubscriptions() {
//     if (_isDisposed) return;

//     // Cancel any existing subscriptions first
//     _disposeSubscriptions();

//     //pin unpin
//     _pinUnpinSubscription = _socketEventController.pinUnpinStream.listen(
//       (data) {
//         if (_isDisposed) return;

//         _logger.d(
//           "📌 Pin/unpin message update received with ${data.records?.length ?? 0} records",
//         );

//         // ✅ FIX 1: Process the pin/unpin update immediately
//         if (data.records != null && data.records!.isNotEmpty) {
//           _processPinUnpinUpdate(data.records!);
//         }

//         // ✅ FIX 2: Force immediate UI update
//         _scheduleNotification();

//         _logger.d("✅ Pin/unpin UI data updated successfully");
//       },
//       onError: (error) {
//         if (_isDisposed) return;
//         _error = 'Pin/unpin stream error: $error';
//         _logger.e('Pin/unpin stream error: $error');
//         _scheduleNotification();
//       },
//     );

//     // ✅ NEW: Star/Unstar message listener
//     _starUnstarSubscription = _socketEventController.chatsStream.listen(
//       (data) {
//         if (_isDisposed) return;

//         _logger.d("⭐ Received star/unstar update - processing...");

//         // Check if this update contains star/unstar changes
//         if (data.records != null && data.records!.isNotEmpty) {
//           bool hasStarChanges = false;

//           for (var record in data.records!) {
//             // Check if any message has star-related updates
//             if (record.starredFor != null || record.stared != null) {
//               hasStarChanges = true;
//               break;
//             }
//           }

//           if (hasStarChanges) {
//             _logger.d("⭐ Star/unstar changes detected, updating UI");

//             // Force immediate UI update for star changes
//             _scheduleNotification();
//           }
//         }
//       },
//       onError: (error) {
//         if (_isDisposed) return;
//         _error = 'Star/unstar stream error: $error';
//         _logger.e('Star/unstar stream error: $error');
//         _scheduleNotification();
//       },
//     );

//     // Subscribe to chat list updates
//     // _chatListSubscription = _socketEventController.chatListStream.listen(
//     //   (data) {
//     //     if (_isDisposed) return;
//     //     _logger.d("Chat list updated with ${data.chats?.length ?? 0} chats");
//     //     _logger.d("Chat messages response: $data");
//     //     _chatListData = data;
//     //     _scheduleNotification();
//     //   },
//     //   onError: (error) {
//     //     if (_isDisposed) return;
//     //     _error = 'Chat list stream error: $error';
//     //     _logger.e('Chat list stream error: $error');
//     //     _scheduleNotification();
//     //   },
//     // );
//     _chatListSubscription = _socketEventController.chatListStream.listen(
//       (data) {
//         if (_isDisposed) return;
//         _logger.d("Chat list updated with ${data.chats?.length ?? 0} chats");

//         // ✅ NEW: Handle pagination response
//         _handleChatListPaginationResponse(data);
//       },
//       onError: (error) {
//         if (_isDisposed) return;
//         _error = 'Chat list stream error: $error';
//         _logger.e('Chat list stream error: $error');
//         _isChatListPaginationLoading = false;
//         _scheduleNotification();
//       },
//     );

//     _chatsSubscription = _socketEventController.chatsStream.listen(
//       (data) {
//         if (_isDisposed) return;

//         _logger.d("📨 Received chat data update");

//         // ✅ ALWAYS UPDATE MAIN CHAT DATA FIRST
//         _chatsData = data;

//         // ✅ CRITICAL: Extract pinned messages BEFORE checking pagination
//         _extractPinnedMessages(data);

//         // ✅ LOG FOR DEBUGGING
//         final recordCount = data.records?.length ?? 0;
//         final pinnedCount = _pinnedMessagesData.records?.length ?? 0;
//         final pagination = data.pagination;
//         final currentPage = pagination?.currentPage ?? 1;

//         _logger.d(
//           "📊 Chat update - Messages: $recordCount, Pinned: $pinnedCount, Page: $currentPage",
//         );

//         // ✅ HANDLE CHAT ID UPDATES FOR NEW CHATS
//         _updateChatIdIfNeeded(data);

//         // ✅ FORCE IMMEDIATE UI UPDATE
//         _scheduleNotification();

//         // ✅ DEBUG: Log pinned messages state
//         if (pinnedCount > 0) {
//           _logger.d("✅ Pinned messages available for UI: $pinnedCount");
//           for (var pinnedMsg in _pinnedMessagesData.records!) {
//             _logger.d(
//               "  - Pinned: ${pinnedMsg.messageId} | ${pinnedMsg.messageContent}",
//             );
//           }
//         } else {
//           _logger.d("⚠️ No pinned messages in current data");
//         }
//       },
//       onError: (error) {
//         if (_isDisposed) return;
//         _error = 'Chat messages stream error: $error';
//         _logger.e('❌ Chat stream error: $error');
//         _scheduleNotification();
//       },
//     );

//     // Subscribe to other streams (chat IDs, online users, typing)
//     _chatIdsSubscription = _socketEventController.chatIdsStream.listen(
//       (data) {
//         if (_isDisposed) return;
//         _logger.d("Chat IDs updated");
//         _chatIdsData = data;
//         _scheduleNotification();
//       },
//       onError: (error) {
//         if (_isDisposed) return;
//         _error = 'Chat IDs stream error: $error';
//         _logger.e('Chat IDs stream error: $error');
//         _scheduleNotification();
//       },
//     );

//     _onlineUsersSubscription = _socketEventController.onlineUsersStream.listen(
//       (data) {
//         if (_isDisposed) return;
//         _onlineUsersData = data;
//         _scheduleNotification();
//       },
//       onError: (error) {
//         if (_isDisposed) return;
//         _error = 'Online users stream error: $error';
//         _logger.e('Online users stream error: $error');
//         _scheduleNotification();
//       },
//     );

//     _typingSubscription = _socketEventController.typingStream.listen(
//       (data) {
//         if (_isDisposed) return;
//         _typingData = data;
//         _scheduleNotification();
//       },
//       onError: (error) {
//         if (_isDisposed) return;
//         _error = 'Typing status stream error: $error';
//         _logger.e('Typing status stream error: $error');
//         _scheduleNotification();
//       },
//     );

//     // Load current user ID for permission checking
//     _loadCurrentUserId();

//     // Initialize with current data from the controller
//     _chatListData = _socketEventController.chatListData;
//     _chatsData = _socketEventController.chatsData;
//     _chatIdsData = _socketEventController.chatIdsData;
//     _onlineUsersData = _socketEventController.onlineUsersData;
//     _typingData = _socketEventController.typingData;

//     // Generate initial hash
//     _lastChatsDataHash = _generateDataHash(_chatsData);
//   }

//   bool _isMessageInCurrentData(int messageId) {
//     if (_chatsData.records == null || _chatsData.records!.isEmpty) {
//       return false;
//     }

//     return _chatsData.records!.any((record) => record.messageId == messageId);
//   }

//   // ✅ NEW: Enhanced message matching
//   bool _isMessageMatch(chats.Records existing, chats.Records updated) {
//     // Primary match: message ID
//     if (existing.messageId != null &&
//         updated.messageId != null &&
//         existing.messageId == updated.messageId) {
//       return true;
//     }

//     // Secondary match: content + sender + chat (for edge cases)
//     if (existing.messageContent == updated.messageContent &&
//         existing.senderId == updated.senderId &&
//         existing.chatId == updated.chatId &&
//         existing.createdAt == updated.createdAt) {
//       return true;
//     }

//     return false;
//   }

//   Future<void> _loadCurrentUserId() async {
//     try {
//       _currentUserId = await SecurePrefs.getString(SecureStorageKeys.USERID);
//       _logger.d('Current user ID loaded: $_currentUserId');
//     } catch (e) {
//       _logger.e('Error loading current user ID: $e');
//     }
//   }

//   // ✅ NEW: Debug helper method
//   void _logCurrentChatState() {
//     if (_chatsData.records != null) {
//       _logger.d('🔍 Current chat has ${_chatsData.records!.length} messages:');
//       for (int i = 0; i < _chatsData.records!.length && i < 3; i++) {
//         final msg = _chatsData.records![i];
//         _logger.d(
//           '  Message ${msg.messageId}: pinned=${msg.pinned}, content="${msg.messageContent}"',
//         );
//       }
//     } else {
//       _logger.d('🔍 No messages in current chat');
//     }
//   }

//   void _onMessageFoundAndScroll(int messageId) {
//     _logger.d('✅ Message found: $messageId');

//     _isMessageFound = true;
//     _isSearchingForMessage = false;
//     _cancelSearchTimeout();

//     // Highlight the message (but don't scroll yet - let the UI handle that)
//     highlightMessage(messageId);

//     _scheduleNotification();
//   }

//   void _processPinUnpinUpdate(List<chats.Records> updatedRecords) {
//     _logger.d('🔧 Processing ${updatedRecords.length} pin/unpin updates');

//     bool hasUpdates = false;

//     for (final updatedRecord in updatedRecords) {
//       if (updatedRecord.messageId == null) {
//         _logger.w('⚠️ Skipping record with null messageId');
//         continue;
//       }

//       // ✅ UPDATE MAIN CHAT DATA
//       final mainChatUpdated = _updateMessageInMainChat(updatedRecord);
//       if (mainChatUpdated) {
//         hasUpdates = true;
//         _logger.d('✅ Updated message ${updatedRecord.messageId} in main chat');
//       }

//       // ✅ UPDATE PINNED MESSAGES COLLECTION
//       _updatePinnedMessagesCollection(updatedRecord);
//     }

//     if (hasUpdates) {
//       _logger.d('✅ Successfully processed pin/unpin updates');

//       // ✅ FORCE REGENERATE PINNED MESSAGES FROM UPDATED MAIN CHAT
//       _regeneratePinnedMessagesFromMainChat();
//     } else {
//       _logger.w('⚠️ No updates were applied to main chat data');
//       _logCurrentChatState(); // Debug helper
//     }
//   }

//   // ✅ NEW: Regenerate pinned messages from main chat (fallback)
//   void _regeneratePinnedMessagesFromMainChat() {
//     if (_chatsData.records == null || _chatsData.records!.isEmpty) {
//       _pinnedMessagesData = chats.ChatsModel();
//       return;
//     }

//     final pinnedMessages =
//         _chatsData.records!.where((record) => record.pinned == true).toList();

//     _pinnedMessagesData = chats.ChatsModel(
//       records: pinnedMessages,
//       pagination: chats.Pagination(
//         totalRecords: pinnedMessages.length,
//         currentPage: 1,
//         totalPages: 1,
//         recordsPerPage: pinnedMessages.length,
//       ),
//     );

//     _logger.d(
//       '🔄 Regenerated ${pinnedMessages.length} pinned messages from main chat',
//     );
//   }

//   // Optimized notification method with debouncing
//   void _scheduleNotification() {
//     if (_isDisposed) return;

//     _shouldNotify = true;
//     _notifyTimer?.cancel();
//     _notifyTimer = Timer(Duration(milliseconds: 50), () {
//       if (_shouldNotify && !_isDisposed) {
//         _shouldNotify = false;
//         notifyListeners();
//       }
//     });
//   }

//   Future<void> _searchWithPaginationEnhanced(int messageId) async {
//     int searchAttempts = 0;
//     const maxSearchAttempts = 15; // Increased attempts

//     while (searchAttempts < maxSearchAttempts &&
//         _isSearchingForMessage &&
//         !_isMessageFound &&
//         hasMoreMessages) {
//       _logger.d(
//         '🔍 Search attempt ${searchAttempts + 1} for message $messageId',
//       );

//       // Check current data again
//       if (_isMessageInCurrentData(messageId)) {
//         _onMessageFoundAndScroll(messageId);
//         return;
//       }

//       // Load more messages if available
//       if (hasMoreMessages) {
//         _logger.d('📄 Loading more messages to find message $messageId');
//         await loadMoreMessages();

//         // Wait for pagination to complete with better timing
//         await _waitForPaginationCompleteEnhanced();

//         // Check again after loading with small delay for UI update
//         await Future.delayed(Duration(milliseconds: 200));

//         if (_isMessageInCurrentData(messageId)) {
//           _onMessageFoundAndScroll(messageId);
//           return;
//         }
//       } else {
//         _logger.w('⚠️ No more messages to load, message not found');
//         break;
//       }

//       searchAttempts++;
//       // Small delay between attempts
//       await Future.delayed(Duration(milliseconds: 300));
//     }

//     // Message not found after all attempts
//     if (!_isMessageFound) {
//       _logger.w(
//         '❌ Message $messageId not found after $searchAttempts attempts',
//       );
//       _stopMessageSearch();
//       _setError('Message not found in chat history');
//     }
//   }

//   void _setError(String errorMessage) {
//     _error = errorMessage;
//     _logger.e(errorMessage);
//     _scheduleNotification();
//   }

//   // ✅ NEW: Method to set pagination loading
//   void _setPaginationLoading(bool loading) {
//     if (_isPaginationLoading != loading) {
//       _isPaginationLoading = loading;
//       _scheduleNotification();
//     }
//   }

//   // ✅ NEW: Start search timeout (prevent infinite search)
//   void _startSearchTimeout() {
//     _searchTimeoutTimer?.cancel();
//     _searchTimeoutTimer = Timer(Duration(seconds: 30), () {
//       if (_isSearchingForMessage && !_isMessageFound) {
//         _logger.w('⏰ Search timeout for message $_targetMessageId');
//         _stopMessageSearch();
//         _setError('Search timeout: Message not found');
//       }
//     });
//   }

//   // ✅ PRIVATE: Internal method to stop search and cleanup
//   void _stopMessageSearch() {
//     if (_isSearchingForMessage) {
//       _logger.d('🧹 Cleaning up search state');
//     }

//     // Reset all search-related state
//     _isSearchingForMessage = false;
//     _targetMessageId = null;
//     _isMessageFound = false;

//     // Cancel any active timers
//     _cancelSearchTimeout();

//     // Clear any highlights
//     _clearHighlightSilently();

//     // Notify UI to update
//     _scheduleNotification();

//     _logger.d('🧹 Search state cleaned up');
//   }

//   void _updateChatIdIfNeeded(chats.ChatsModel data) {
//     // Only update if we don't have a chat ID and we received one
//     if ((_currentChatData.chatId == null || _currentChatData.chatId == 0) &&
//         data.records != null &&
//         data.records!.isNotEmpty) {
//       final firstRecord = data.records!.first;
//       if (firstRecord.chatId != null && firstRecord.chatId! > 0) {
//         _logger.d("📝 Updating chat ID to ${firstRecord.chatId}");

//         _currentChatData = ChatIds(
//           chatId: firstRecord.chatId!,
//           userId: _currentChatData.userId ?? 0,
//         );

//         _socketEventController.updateCurrentChatId(firstRecord.chatId!);
//       }
//     }
//   }

//   bool _updateMessageInMainChat(chats.Records updatedRecord) {
//     if (_chatsData.records == null || _chatsData.records!.isEmpty) {
//       _logger.w('⚠️ No existing chat messages to update');
//       return false;
//     }

//     for (int i = 0; i < _chatsData.records!.length; i++) {
//       final existingMessage = _chatsData.records![i];

//       // ✅ MULTIPLE ID MATCHING STRATEGIES
//       if (_isMessageMatch(existingMessage, updatedRecord)) {
//         // ✅ CREATE COMPLETELY NEW RECORD WITH UPDATED DATA
//         final updatedMessage = _createUpdatedRecord(
//           existingMessage,
//           updatedRecord,
//         );

//         // ✅ REPLACE THE MESSAGE
//         _chatsData.records![i] = updatedMessage;

//         _logger.d(
//           '📌 Updated message ${existingMessage.messageId}: '
//           'pinned ${existingMessage.pinned} -> ${updatedRecord.pinned}',
//         );

//         return true;
//       }
//     }

//     _logger.w('⚠️ Message ${updatedRecord.messageId} not found in main chat');
//     return false;
//   }

//   // ✅ NEW: Update pinned messages collection
//   void _updatePinnedMessagesCollection(chats.Records updatedRecord) {
//     _pinnedMessagesData.records ??= [];

//     if (updatedRecord.pinned == true) {
//       // ✅ MESSAGE WAS PINNED
//       final existingIndex = _pinnedMessagesData.records!.indexWhere(
//         (msg) => msg.messageId == updatedRecord.messageId,
//       );

//       if (existingIndex == -1) {
//         // Add new pinned message
//         _pinnedMessagesData.records!.insert(0, updatedRecord);
//         _logger.d(
//           '📌 Added message ${updatedRecord.messageId} to pinned collection',
//         );
//       } else {
//         // Update existing pinned message
//         _pinnedMessagesData.records![existingIndex] = updatedRecord;
//         _logger.d('📌 Updated pinned message ${updatedRecord.messageId}');
//       }
//     } else {
//       // ✅ MESSAGE WAS UNPINNED
//       final initialCount = _pinnedMessagesData.records!.length;
//       _pinnedMessagesData.records!.removeWhere(
//         (msg) => msg.messageId == updatedRecord.messageId,
//       );
//       final finalCount = _pinnedMessagesData.records!.length;

//       if (initialCount > finalCount) {
//         _logger.d(
//           '📌 Removed message ${updatedRecord.messageId} from pinned collection',
//         );
//       } else {
//         _logger.w(
//           '⚠️ Message ${updatedRecord.messageId} was not in pinned collection',
//         );
//       }
//     }

//     _updatePinnedMessagesPagination();
//   }

//   // ✅ NEW: Update pinned messages pagination
//   void _updatePinnedMessagesPagination() {
//     final pinnedCount = _pinnedMessagesData.records?.length ?? 0;
//     _pinnedMessagesData.pagination = chats.Pagination(
//       totalRecords: pinnedCount,
//       currentPage: 1,
//       totalPages: 1,
//       recordsPerPage: pinnedCount,
//     );
//   }

//   // 11. ENHANCED: Wait for pagination with better timing
//   Future<void> _waitForPaginationCompleteEnhanced() async {
//     int waitAttempts = 0;
//     const maxWaitAttempts = 30; // Increased wait time

//     while (waitAttempts < maxWaitAttempts &&
//         (_isPaginationLoading || _socketEventController.isPaginationLoading)) {
//       await Future.delayed(Duration(milliseconds: 200)); // Shorter intervals
//       waitAttempts++;
//     }

//     // Additional wait for UI rendering
//     await Future.delayed(Duration(milliseconds: 100));
//   }
// }
