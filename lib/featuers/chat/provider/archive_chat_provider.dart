import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:whoxa/core/services/socket/socket_service.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
import 'package:whoxa/utils/logger.dart';

class ArchiveChatProvider with ChangeNotifier {
  final SocketService _socketService;
  final ConsoleAppLogger _logger = ConsoleAppLogger();
  
  // ✅ NEW: Callback to notify ChatProvider of archive changes
  Function(int chatId, bool isArchived)? _onArchiveStatusChanged;

  List<Chats> _archivedChats = [];
  Pagination? _pagination;
  bool _isLoading = false;
  bool _hasMoreData = true;
  final int _pageSize = 10;

  ArchiveChatProvider(this._socketService);

  List<Chats> get archivedChats => _archivedChats;
  Pagination? get pagination => _pagination;
  bool get isLoading => _isLoading;
  bool get hasMoreData => _hasMoreData;
  bool get hasArchivedChats => _archivedChats.isNotEmpty;
  
  // ✅ NEW: Set callback for archive status changes
  void setOnArchiveStatusChanged(Function(int chatId, bool isArchived) callback) {
    _onArchiveStatusChanged = callback;
  }

  // ✅ CRITICAL: Store the last requested chat ID for context
  int? _lastRequestedChatId;

  // ✅ NEW: Track archive operation status
  bool _lastArchiveSuccess = false;
  String? _lastArchiveError;

  void setLastRequestedChatId(int chatId) {
    _lastRequestedChatId = chatId;
  }

  bool get lastArchiveSuccess => _lastArchiveSuccess;
  String? get lastArchiveError => _lastArchiveError;

  void handleArchiveChat(dynamic chatData) {
    try {
      _logger.d('handleArchiveChat called with data: $chatData (type: ${chatData.runtimeType})');

      // ✅ HANDLE BOTH STRING AND MAP RESPONSES
      // If the response is a String (e.g., for demo accounts or errors)
      if (chatData is String) {
        _logger.w('Received String response for archive_chat: $chatData');
        _lastArchiveSuccess = false;
        _lastArchiveError = chatData;

        // Clear the last requested chat ID
        if (_lastRequestedChatId != null) {
          _lastRequestedChatId = null;
        }

        notifyListeners();
        return;
      }

      // ✅ HANDLE MAP RESPONSE (normal case)
      if (chatData is! Map<String, dynamic>) {
        _logger.e('Unexpected data type for archive_chat: ${chatData.runtimeType}');
        _lastArchiveSuccess = false;
        _lastArchiveError = 'Invalid response format';
        notifyListeners();
        return;
      }

      // ✅ FIXED: Handle the actual response format from the socket
      // Response format: {success: true, message: "chat archived : false/true"}
      if (chatData['success'] == true && chatData['message'] != null) {
        final message = chatData['message'].toString();
        _logger.d('Archive response message: $message');

        // ✅ NEW: Mark as success
        _lastArchiveSuccess = true;
        _lastArchiveError = null;

        // Extract archive status from message
        final isArchived = message.contains('archived : true');
        final isUnarchived = message.contains('archived : false');

        if (_lastRequestedChatId != null) {
          final chatId = _lastRequestedChatId!;

          if (isArchived) {
            _logger.d('Chat $chatId was archived');
            // Note: For archive, we don't add to _archivedChats here because
            // the archived chat list will be refreshed separately
            _onArchiveStatusChanged?.call(chatId, true);
          } else if (isUnarchived) {
            _logger.d('Chat $chatId was unarchived - notifying ChatProvider to add back to main list');

            // ✅ CRITICAL: Remove from archived list first
            _archivedChats.removeWhere((chat) => chat.records?.first.chatId == chatId);

            // ✅ ENHANCED: Always notify ChatProvider to add back to main list
            _onArchiveStatusChanged?.call(chatId, false);
          }

          // Clear the last requested chat ID after processing
          _lastRequestedChatId = null;
        } else {
          _logger.w('No chat ID context available for archive response');
        }
      } else {
        // ✅ NEW: Mark as failure
        _lastArchiveSuccess = false;
        _lastArchiveError = chatData['message']?.toString() ?? 'Unknown error occurred';
        _logger.w('Archive operation failed: $_lastArchiveError');
        _logger.w('Unexpected archive response format: $chatData');

        // Clear the last requested chat ID after processing
        if (_lastRequestedChatId != null) {
          _lastRequestedChatId = null;
        }
      }

      // ✅ NEW: Always notify listeners for real-time UI updates
      notifyListeners();
    } catch (e) {
      _logger.e('Error handling archive chat event: $e');
      // ✅ NEW: Still notify listeners even on error to ensure UI consistency
      notifyListeners();
    }
  }

  void handleArchivedChatList(Map<String, dynamic> payload) {
    try {
      _logger.d('handleArchivedChatList called with payload: $payload');

      _isLoading = false;
      
      // ✅ FIXED: Better null safety and validation
      if (payload.isEmpty) {
        _logger.w('Empty payload received for archived chat list');
        notifyListeners();
        return;
      }
      
      _pagination = payload['pagination'] != null
          ? Pagination.fromJson(payload['pagination'])
          : null;

      List<Chats> newChats = [];
      if (payload['Chats'] != null && payload['Chats'] is List) {
        try {
          newChats = List<Chats>.from(
            payload['Chats'].map((e) => Chats.fromJson(e)),
          );
        } catch (e) {
          _logger.e('Error parsing archived chats data: $e');
          notifyListeners();
          return;
        }
      }

      // ✅ FIXED: Better pagination handling
      final currentPage = _pagination?.currentPage ?? 1;
      if (currentPage == 1) {
        _archivedChats = newChats;
      } else {
        // ✅ FIXED: Prevent duplicates when adding to existing list
        final existingChatIds = _archivedChats
            .map((chat) => chat.records?.first.chatId)
            .where((id) => id != null)
            .toSet();
        
        final newUniqueChats = newChats.where((chat) {
          final chatId = chat.records?.first.chatId;
          return chatId != null && !existingChatIds.contains(chatId);
        }).toList();
        
        _archivedChats.addAll(newUniqueChats);
      }

      _hasMoreData = _pagination != null && _pagination!.currentPage != null && _pagination!.totalPages != null
          ? (_pagination!.currentPage! < _pagination!.totalPages!)
          : false;

      // ✅ IMPROVED: Only notify for new chats to prevent redundant updates
      if (_onArchiveStatusChanged != null && currentPage == 1) {
        for (final chat in newChats) {
          final chatId = chat.records?.first.chatId;
          if (chatId != null) {
            _onArchiveStatusChanged!(chatId, true);
          }
        }
      }

      notifyListeners();
    } catch (e) {
      _logger.e('Error handling archived chat list event: $e');
      _isLoading = false;
      // ✅ FIXED: Ensure state is consistent even on error
      _hasMoreData = false;
      notifyListeners();
    }
  }

  Future<void> fetchArchivedChats({int page = 1}) async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      notifyListeners();

      _socketService.emit('archived_chat_list', data: {
        'pageSize': _pageSize,
        'page': page,
      });

      _logger.d('Fetching archived chats for page: $page');

      // Add timeout to prevent indefinite loading
      Timer(Duration(seconds: 10), () {
        if (_isLoading) {
          _logger.w('Archived chats fetch timed out after 10 seconds');
          _isLoading = false;
          notifyListeners();
        }
      });
    } catch (e) {
      _logger.e('Error fetching archived chats: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> archiveUnarchiveChat(int chatId) async {
    try {
      // ✅ CRITICAL: Store the chat ID context before making the request
      setLastRequestedChatId(chatId);
      
      _socketService.emit('archive_chat', data: {
        'chat_id': chatId,
      });

      _logger.d('Archive/unarchive chat with ID: $chatId');
      
      // ✅ NEW: Force UI update after emit
      notifyListeners();
    } catch (e) {
      _logger.e('Error archiving/unarchiving chat: $e');
      // Clear the context on error
      _lastRequestedChatId = null;
      // ✅ NEW: Still notify listeners even on error
      notifyListeners();
    }
  }

  Future<void> loadMoreArchivedChats() async {
    if (!_hasMoreData || _isLoading) {
      _logger.d('loadMoreArchivedChats: Cannot load more - hasMoreData: $_hasMoreData, isLoading: $_isLoading');
      return;
    }

    final nextPage = (_pagination?.currentPage ?? 0) + 1;
    _logger.d('loadMoreArchivedChats: Loading page $nextPage');
    await fetchArchivedChats(page: nextPage);
  }

  void clearArchivedChats() {
    _archivedChats.clear();
    _pagination = null;
    _hasMoreData = true;
    notifyListeners();
  }

  /// ✅ NEW: Update archived chat with new message (real-time updates)
  void updateArchivedChatWithNewMessage(dynamic newMessage) {
    try {
      _logger.d('🗃️ Updating archived chat with new message: chatId=${newMessage?.chatId}, senderId=${newMessage?.senderId}');
      _logger.d('🗃️ Current archived chats count: ${_archivedChats.length}');

      if (newMessage?.chatId == null) {
        _logger.w('Cannot update archived chat - no chat ID in message');
        return;
      }

      final messageChatId = newMessage.chatId;
      bool chatUpdated = false;

      // If no archived chats are loaded, check if this message is for an archived chat
      if (_archivedChats.isEmpty) {
        _logger.d('🔄 No archived chats loaded, checking if message is for archived chat...');
        
        // Check if the message has archive information
        final chatData = newMessage.chat;
        if (chatData != null && chatData.archivedFor != null) {
          _logger.d('📦 Message has archive info: ${chatData.archivedFor}');
          
          // If this chat is archived, we should load archived chats to show the update
          if (chatData.archivedFor.isNotEmpty) {
            _logger.d('🔄 Message is for archived chat, fetching archived chats...');
            Future.microtask(() => fetchArchivedChats());
            return; // Exit early, fetchArchivedChats will load the data
          }
        }
      }

      // Find the matching archived chat
      for (int i = 0; i < _archivedChats.length; i++) {
        final chat = _archivedChats[i];
        final record = chat.records?.isNotEmpty == true ? chat.records!.first : null;
        
        if (record?.chatId == messageChatId) {
          _logger.d('📝 Found matching archived chat at index $i - updating with new message');
          
          // Update the chat record with new message
          _updateArchivedChatRecord(record!, newMessage, i);
          chatUpdated = true;
          break;
        }
      }

      if (chatUpdated) {
        // Notify listeners for real-time UI updates
        notifyListeners();
        _logger.d('✅ Archived chat updated successfully');
      } else {
        _logger.d('🔍 No matching archived chat found for chatId: $messageChatId');
      }

    } catch (e) {
      _logger.e('❌ Error updating archived chat with new message: $e');
    }
  }

  /// ✅ HELPER: Update archived chat record with new message
  void _updateArchivedChatRecord(dynamic chatRecord, dynamic newMessage, int chatIndex) {
    try {
      // Move the updated chat to the top of the list (like main chat list)
      if (chatIndex > 0) {
        final updatedChat = _archivedChats.removeAt(chatIndex);
        _archivedChats.insert(0, updatedChat);
        _logger.d('📈 Moved updated archived chat to top of list');
      }

      // Update or add the new message to the chat record
      if (chatRecord.messages?.isNotEmpty == true) {
        final existingMessage = chatRecord.messages!.first;
        
        // Update the existing message with new message data
        existingMessage.messageContent = newMessage.messageContent ?? existingMessage.messageContent;
        existingMessage.messageType = newMessage.messageType ?? existingMessage.messageType;
        existingMessage.createdAt = newMessage.createdAt ?? existingMessage.createdAt;
        existingMessage.senderId = newMessage.senderId ?? existingMessage.senderId;
        existingMessage.messageId = newMessage.messageId ?? existingMessage.messageId;
        
        // Update call data if present
        if (newMessage.calls != null) {
          existingMessage.calls = newMessage.calls;
        }
        
        _logger.d('📝 Updated existing message in archived chat');
      } else {
        // Create new Messages object using the Messages.fromJson method
        try {
          final newMessageData = {
            'message_content': newMessage.messageContent,
            'message_type': newMessage.messageType,
            'message_id': newMessage.messageId,
            'chat_id': newMessage.chatId,
            'sender_id': newMessage.senderId,
            'createdAt': newMessage.createdAt,
            'updatedAt': newMessage.updatedAt,
            'Calls': newMessage.calls,
            'User': newMessage.user,
            'message_seen_status': newMessage.messageSeenStatus,
            'deleted_for': newMessage.deletedFor ?? [],
            'starred_for': newMessage.starredFor ?? [],
            'deleted_for_everyone': newMessage.deletedForEveryone ?? false,
            'pinned': newMessage.pinned ?? false,
          };
          
          // Use the Messages.fromJson to create proper message object
          final messageObj = Messages.fromJson(newMessageData);
          chatRecord.messages = [messageObj];
          _logger.d('🆕 Created new properly formatted message for archived chat');
        } catch (e) {
          _logger.e('❌ Error creating message object: $e');
          // Fallback to simple update
          chatRecord.messages = [_createSimpleArchivedChatMessage(newMessage)];
        }
      }

      // Update chat record timestamps and unseen count
      if (newMessage.createdAt != null) {
        chatRecord.updatedAt = newMessage.createdAt;
      }
      
      // Update unseen count if available
      if (newMessage.unseenCount != null) {
        chatRecord.unseenCount = newMessage.unseenCount;
      }

    } catch (e) {
      _logger.e('❌ Error updating archived chat record: $e');
    }
  }

  /// ✅ HELPER: Create a properly formatted archived chat message (fallback)
  dynamic _createSimpleArchivedChatMessage(dynamic newMessage) {
    // Create a simple message object as fallback
    return {
      'message_content': newMessage.messageContent,
      'message_type': newMessage.messageType,
      'message_id': newMessage.messageId,
      'chat_id': newMessage.chatId,
      'sender_id': newMessage.senderId,
      'createdAt': newMessage.createdAt,
      'updatedAt': newMessage.updatedAt,
      'calls': newMessage.calls,
    };
  }

  /// ✅ NEW: Clear unseen count for a specific archived chat
  void clearArchivedChatUnseenCount(int chatId) {
    try {
      _logger.d('🗃️ Clearing unseen count for archived chat: $chatId');
      
      bool updated = false;
      for (int i = 0; i < _archivedChats.length; i++) {
        final chat = _archivedChats[i];
        final record = chat.records?.isNotEmpty == true ? chat.records!.first : null;
        
        if (record?.chatId == chatId) {
          final oldCount = record?.unseenCount ?? 0;
          if (oldCount > 0) {
            record!.unseenCount = 0;
            updated = true;
            _logger.d('✅ Cleared archived chat $chatId unseen count: $oldCount → 0');
          }
          break;
        }
      }
      
      if (updated) {
        notifyListeners();
      } else {
        _logger.d('🔍 Archived chat $chatId not found or already has 0 unseen count');
      }
    } catch (e) {
      _logger.e('❌ Error clearing archived chat unseen count: $e');
    }
  }

  /// ✅ NEW: Get current unseen count for a specific archived chat
  int getArchivedChatUnseenCount(int chatId) {
    try {
      for (final chat in _archivedChats) {
        final record = chat.records?.isNotEmpty == true ? chat.records!.first : null;
        if (record?.chatId == chatId) {
          return record?.unseenCount ?? 0;
        }
      }
    } catch (e) {
      _logger.e('❌ Error getting archived chat unseen count: $e');
    }
    return 0;
  }
}