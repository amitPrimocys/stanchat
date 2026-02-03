import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stanchat/core/api/api_client.dart';
import 'package:stanchat/core/api/api_endpoint.dart';
import 'package:stanchat/featuers/chat/data/blocked_user_model.dart';
import 'package:stanchat/featuers/chat/data/count_model.dart';
import 'package:stanchat/featuers/chat/data/starred_messages_model.dart';
import 'package:stanchat/featuers/chat/data/models/chat_media_model.dart';
import 'package:stanchat/featuers/chat/utils/message_utils.dart';
import 'package:stanchat/main.dart';
import 'package:stanchat/utils/enums.dart';
import 'package:stanchat/utils/logger.dart';
import 'package:stanchat/utils/preference_key/sharedpref_key.dart';
import 'package:http/http.dart' as http;

class ChatRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  ChatRepository(this._apiClient);

  /// Check user online status via API
  /// Returns a map with 'isOnline' and 'updatedAt' keys
  Future<Map<String, dynamic>?> checkUserOnlineStatus(int userId) async {
    try {
      _logger.d('Checking online status for user: $userId');
      final response = await _apiClient.request(
        "${ApiEndpoints.checkUserOnlineStatus}/$userId",
        method: 'GET',
      );
      _logger.d('Online status response: $response');

      if (response != null && response['status'] == true) {
        final data = response['data'];
        if (data != null) {
          return {
            'isOnline': data['isOnline'] ?? false,
            'updatedAt': data['updatedAt'], // Note: API returns 'updatedAt'
          };
        }
      }

      _logger.w('Invalid response from online status API');
      return null;
    } catch (e) {
      _logger.e('Error checking user online status: $e');
      return null;
    }
  }

  /// Send message via API
  /// Handles both text and file messages
  Future<Map<String, dynamic>?> sendMessage({
    int? chatId,
    required String messageContent,
    required MessageType messageType,
    int? userId,
    int? storyId,
    Map<String, dynamic>? filePaths,
    int? replyToMessageId, // ✅ NEW: Added reply parameter
  }) async {
    try {
      // Convert MessageType enum to API-compatible string
      final messageTypeString = MessageTypeUtils.messageContentType(
        messageType,
      );

      // Determine if this is a new chat
      bool isNewChat = chatId == 0;

      _logger.d(
        'Sending message to ${isNewChat ? "new user" : "existing chat"}: ${userId ?? chatId}, type: $messageTypeString${replyToMessageId != null ? ", replyTo: $replyToMessageId" : ""}',
      );

      // Create the request data
      Map<String, dynamic> requestData = {
        'message_type': messageTypeString,
        'message_content': messageContent,
      };

      // ✅ FIX: Only include chat_id if it's greater than 0 (existing chat)
      if (!isNewChat && chatId != null && chatId > 0) {
        requestData['chat_id'] = chatId.toString();
        _logger.d('Adding chat_id to request: $chatId');
      }

      // ✅ FIX: Include user_id for new chats or when explicitly provided
      if (userId != null) {
        requestData['user_id'] = userId.toString();
        _logger.d('Adding user_id to request: $userId');
      }

      if (storyId != null) {
        requestData['story_id'] = storyId;
        _logger.d('Adding story_id to request: $storyId');
      }

      // ✅ NEW: Add reply_to field if replying to a message
      if (replyToMessageId != null && replyToMessageId > 0) {
        requestData['reply_to'] = replyToMessageId.toString();
        _logger.d('Adding reply_to field: $replyToMessageId');
      }

      // Special handling for different message types
      if (messageType == MessageType.Image) {
        requestData['pictureType'] = "chat_image";
      } else if (messageType == MessageType.Social) {
        requestData['social_id'] = messageContent;
        requestData['message_content'] = "Shared a post";
      }

      if (messageType == MessageType.Voice) {
        logger.d("voice sending");
        requestData['pictureType'] = "chat_voice";
      }

      _logger.d('Send message request data: $requestData');

      // Prepare file paths for upload
      Map<String, dynamic> finalFilePaths = filePaths ?? {};

      // Validate that required files are present
      // Special case: GIF URLs from external sources (like Giphy) don't need files
      bool isGifUrl =
          messageType == MessageType.Gif &&
          messageContent.startsWith('http') &&
          messageContent.contains('gif');

      _logger.d(
        'Repository - File upload validation - MessageType: $messageType, RequiresUpload: ${MessageTypeUtils.requiresFileUpload(messageType)}, FilePaths empty: ${finalFilePaths.isEmpty}, IsGifUrl: $isGifUrl',
      );

      if (MessageTypeUtils.requiresFileUpload(messageType) &&
          finalFilePaths.isEmpty &&
          !isGifUrl) {
        _logger.e(
          'Repository - File upload validation failed - throwing exception',
        );
        throw Exception(
          'File upload required but no files provided for message type: $messageType',
        );
      }

      _logger.d(
        'Repository - File upload validation passed - proceeding with API call',
      );

      // Send the message using the API client
      final response = await _apiClient.multipartRequest(
        ApiEndpoints.sendMessage,
        body: requestData,
        files: finalFilePaths,
      );

      _logger.d('Send message response: $response');
      return response;
    } catch (e) {
      _logger.e('Send message failed: $e');
      rethrow;
    }
  }

  /// Pin or unpin message via API
  /// [chatId] - The chat ID where the message belongs
  /// [messageId] - The ID of the message to pin/unpin
  /// Returns true if successful, false otherwise
  Future<bool> pinUnpinMessage({
    required int chatId,
    required int messageId,
    required int inDays,
  }) async {
    try {
      _logger.d(
        'Pin/Unpin message - chatId: $chatId, messageId: $messageId, inDays: $inDays',
      );

      // Determine pin_lifetime value based on inDays
      String pinLifetime;
      if (inDays == 0) {
        // Unpinning
        pinLifetime = '0';
      } else if (inDays == -1) {
        // Lifetime
        pinLifetime = '-1';
      } else {
        // Specific number of days
        pinLifetime = inDays.toString();
      }

      final requestData = {
        'chat_id': chatId,
        'message_id': messageId,
        'pin_lifetime': pinLifetime,
      };

      _logger.d('Pin/Unpin message request data: $requestData');

      final response = await _apiClient.request(
        ApiEndpoints.pinUnpinMessage,
        method: 'POST',
        body: requestData,
      );

      _logger.d('Pin/Unpin message response: $response');

      if (response != null && response['status'] == true) {
        _logger.i('Message pin/unpin successful');
        return true;
      } else {
        _logger.w('Pin/Unpin message failed - Invalid response');
        return false;
      }
    } catch (e) {
      _logger.e('Pin/Unpin message error: $e');
      return false;
    }
  }

  /// Pin or unpin message via API
  /// [chatId] - The chat ID where the message belongs
  /// [messageId] - The ID of the message to pin/unpin
  /// Returns true if successful, false otherwise
  Future<bool> starUnStarMessage({required int messageId}) async {
    try {
      _logger.d('Star/Unstar message - messageId: $messageId');

      final requestData = {'message_id': messageId};

      _logger.d('Star/Unstar message data: $requestData');

      final response = await _apiClient.request(
        ApiEndpoints.starUnstarMessage,
        method: 'POST',
        body: requestData,
      );

      _logger.d('Star/Unstar message response: $response');

      if (response != null && response['status'] == true) {
        _logger.i('Message Star/Unstar successful');
        return true;
      } else {
        _logger.w('Star/Unstar message failed - Invalid response');
        return false;
      }
    } catch (e) {
      _logger.e('Star/Unstar message error: $e');
      return false;
    }
  }

  /// Forward message to another chat via API
  /// [fromChatId] - Source chat ID where the message currently exists
  /// [toChatId] - Destination chat ID where the message should be forwarded
  /// [messageId] - ID of the message to forward
  /// Returns true if successful, false otherwise
  Future<bool> forwardMessage({
    required int fromChatId,
    required int toChatId,
    required int messageId,
  }) async {
    try {
      _logger.d(
        'Forwarding message via API - fromChatId: $fromChatId, toChatId: $toChatId, messageId: $messageId',
      );

      // Validate input parameters
      if (fromChatId <= 0 || toChatId <= 0 || messageId <= 0) {
        _logger.e('Invalid parameters for forward message');
        throw Exception('Invalid chat IDs or message ID');
      }

      // Prepare request data according to API specification
      final requestData = {
        'from_chat_id': fromChatId,
        'to_chat_id': toChatId,
        'message_id': messageId,
      };

      _logger.d('Forward message request data: $requestData');

      // Make API call to forward-message endpoint
      final response = await _apiClient.request(
        ApiEndpoints.forwardMessage, // ✅ API endpoint as specified
        method: 'POST',
        body: requestData,
      );

      _logger.d('Forward message response: $response');

      // Check if the response indicates success
      if (response != null && response['status'] == true) {
        _logger.i(
          'Message forward successful - messageId: $messageId, fromChat: $fromChatId, toChat: $toChatId',
        );
        return true;
      } else {
        _logger.w(
          'Forward message failed - Invalid response or status false. Response: $response',
        );
        return false;
      }
    } catch (e) {
      _logger.e('Forward message error for messageId $messageId: $e');
      return false;
    }
  }

  /// Forward multiple messages in batch (optimized version)
  /// [fromChatId] - Source chat ID
  /// [toChatId] - Destination chat ID
  /// [messageIds] - List of message IDs to forward
  /// Returns a map with success/failure counts and any error messages
  Future<Map<String, dynamic>> forwardMultipleMessages({
    required int fromChatId,
    required int toChatId,
    required List<int> messageIds,
  }) async {
    int successCount = 0;
    int failureCount = 0;
    List<String> errors = [];

    try {
      _logger.d(
        'Forwarding ${messageIds.length} messages from chat $fromChatId to chat $toChatId',
      );

      // Forward messages one by one
      // Note: If your API supports batch forwarding, you can modify this to send all at once
      for (int i = 0; i < messageIds.length; i++) {
        final messageId = messageIds[i];

        try {
          final success = await forwardMessage(
            fromChatId: fromChatId,
            toChatId: toChatId,
            messageId: messageId,
          );

          if (success) {
            successCount++;
            _logger.d(
              '✅ Message $messageId forwarded successfully (${i + 1}/${messageIds.length})',
            );
          } else {
            failureCount++;
            errors.add('Failed to forward message $messageId');
            _logger.e(
              '❌ Message $messageId forward failed (${i + 1}/${messageIds.length})',
            );
          }

          // Small delay between requests to avoid overwhelming the server
          if (i < messageIds.length - 1) {
            await Future.delayed(Duration(milliseconds: 200));
          }
        } catch (e) {
          failureCount++;
          errors.add('Error forwarding message $messageId: $e');
          _logger.e('❌ Exception forwarding message $messageId: $e');
        }
      }

      _logger.i(
        'Batch forward completed - Success: $successCount, Failures: $failureCount',
      );

      return {
        'success': true,
        'total_messages': messageIds.length,
        'success_count': successCount,
        'failure_count': failureCount,
        'errors': errors,
      };
    } catch (e) {
      _logger.e('Critical error in batch forward: $e');
      return {
        'success': false,
        'total_messages': messageIds.length,
        'success_count': successCount,
        'failure_count': failureCount,
        'errors': [...errors, 'Critical error: $e'],
      };
    }
  }

  /// Forward message to a new user (creates new chat if needed)
  /// [fromChatId] - Source chat ID where the message currently exists
  /// [toUserId] - Target user ID to forward the message to
  /// [messageId] - ID of the message to forward
  /// Returns true if successful, false otherwise
  Future<bool> forwardMessageToUser({
    required int fromChatId,
    required int toUserId,
    required int messageId,
  }) async {
    try {
      _logger.d(
        'Forwarding message to user via API - fromChatId: $fromChatId, toUserId: $toUserId, messageId: $messageId',
      );

      // Validate input parameters
      if (fromChatId <= 0 || toUserId <= 0 || messageId <= 0) {
        _logger.e('Invalid parameters for forward message to user');
        throw Exception('Invalid chat ID, user ID, or message ID');
      }

      // Prepare request data for forwarding to user
      final requestData = {
        'from_chat_id': fromChatId,
        // 'to_user_id': toUserId,
        'user_id': toUserId,
        'message_id': messageId,
      };

      _logger.d('Forward message to user request data: $requestData');

      // Make API call to forward-message endpoint (same endpoint, different params)
      final response = await _apiClient.request(
        ApiEndpoints.forwardMessage,
        method: 'POST',
        body: requestData,
      );

      _logger.d('Forward message to user response: $response');

      // Check if the response indicates success
      if (response != null && response['status'] == true) {
        _logger.i(
          'Message forward to user successful - messageId: $messageId, fromChat: $fromChatId, toUser: $toUserId',
        );
        return true;
      } else {
        _logger.w(
          'Forward message to user failed - Invalid response or status false. Response: $response',
        );
        return false;
      }
    } catch (e) {
      _logger.e('Forward message to user error for messageId $messageId: $e');
      return false;
    }
  }

  /// Check if a message can be forwarded (validation method)
  /// [messageId] - Message ID to check
  /// Returns true if the message can be forwarded, false otherwise
  Future<bool> canForwardMessage(int messageId) async {
    try {
      // You can implement additional validation here if needed
      // For example, checking message type, permissions, etc.

      // Basic validation - message ID should be positive
      if (messageId <= 0) {
        _logger.w('Invalid message ID for forward check: $messageId');
        return false;
      }

      // Add any other business logic here
      // For example:
      // - Check if message is deleted
      // - Check if message type is forwardable
      // - Check user permissions

      return true;
    } catch (e) {
      _logger.e('Error checking forward permission for message $messageId: $e');
      return false;
    }
  }

  /// Get available chats for forwarding (helper method)
  /// Returns a list of chats that the user can forward messages to
  Future<List<Map<String, dynamic>>> getAvailableChatsForForward() async {
    try {
      _logger.d('Getting available chats for forwarding');

      // This would typically call an API endpoint to get user's chats
      // For now, we'll return an empty list as this would depend on your specific API

      // Example API call (uncomment and modify as needed):
      /*
    final response = await _apiClient.request(
      'get-user-chats', // Your endpoint for getting user's chats
      method: 'GET',
    );

    if (response != null && response['status'] == true) {
      final chats = response['data'] as List<dynamic>? ?? [];
      return chats.map((chat) => {
        'chat_id': chat['chat_id'],
        'chat_name': chat['chat_name'],
        'chat_type': chat['chat_type'], // individual, group, etc.
        'last_message_time': chat['last_message_time'],
      }).toList();
    }
    */

      _logger.d('Available chats retrieval completed');
      return [];
    } catch (e) {
      _logger.e('Error getting available chats for forward: $e');
      return [];
    }
  }

  /// Block or unblock a user via API
  /// [userId] - The ID of the user to block/unblock
  /// [chatId] - The ID of the chat
  /// Returns Map with success status and actual block state from server
  Future<Map<String, dynamic>?> blockUnblockUser(int userId, int chatId) async {
    try {
      _logger.d('Block/Unblock user - userId: $userId, chatId: $chatId');

      final requestData = <String, dynamic>{'user_id': userId};

      // Only include chat_id if it's not 0
      if (chatId != 0) {
        requestData['chat_id'] = chatId;
      }

      _logger.d('Block/Unblock user request data: $requestData');

      final response = await _apiClient.request(
        ApiEndpoints.blockUnblock,
        method: 'POST',
        body: requestData,
      );

      _logger.d('Block/Unblock user response: $response');

      if (response != null && response['status'] == true) {
        _logger.i('User block/unblock successful');

        // Extract the actual block status from API response
        final data = response['data'] as Map<String, dynamic>?;
        final isBlocked = data?['is_blocked'] ?? false;

        return {
          'success': true,
          'is_blocked': isBlocked,
          'message': response['message'] ?? '',
        };
      } else {
        _logger.w('Block/Unblock user failed - Invalid response');
        return {
          'success': false,
          'is_blocked': false,
          'message': response?['message'] ?? 'Failed to block/unblock user',
        };
      }
    } catch (e) {
      _logger.e('Block/Unblock user error: $e');
      return {'success': false, 'is_blocked': false, 'message': 'Error: $e'};
    }
  }

  /// Get list of blocked users via API
  /// [page] - Page number for pagination
  /// Returns BlockedUserModel containing blocked users list
  Future<BlockedUserModel?> getBlockedUsers(int page) async {
    try {
      _logger.d('Getting blocked users - page: $page');

      final requestData = {'page': page};

      _logger.d('Get blocked users request data: $requestData');

      final response = await _apiClient.request(
        ApiEndpoints.blockList,
        method: 'POST',
        body: requestData,
      );

      _logger.d('Get blocked users response: $response');

      if (response != null && response['status'] == true) {
        _logger.i('Get blocked users successful');
        final data = response['data'];
        if (data != null) {
          return BlockedUserModel.fromJson(data);
        }
      } else {
        _logger.w('Get blocked users failed - Invalid response');
      }
      return null;
    } catch (e) {
      _logger.e('Get blocked users error: $e');
      return null;
    }
  }

  CountModel? countModel;
  Future<CountModel?> countRepo() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.getCounts,
        method: 'POST',
        body: {},
      );
      _logger.d('Get count starred/block response: $response');

      return countModel = CountModel.fromJson(response);
    } catch (e) {
      _logger.e('Get count starred/block error: $e');
      return null;
    }
  }

  /// Get list of starred messages via API
  /// [page] - Page number for pagination (optional, defaults to 1)
  /// [limit] - Number of records per page (optional, defaults to 10)
  /// Returns StarredMessagesResponse containing starred messages list
  Future<StarredMessagesResponse?> getStarredMessages({
    int page = 1,
    int limit = 10000,
    int? chatId,
  }) async {
    try {
      _logger.d(
        'Getting starred messages - page: $page, limit: $limit, chatId: $chatId',
      );

      final requestData = {'page': page, 'pageSize': limit};
      if (chatId != null) {
        requestData['chat_id'] = chatId;
        _logger.d('Adding chat_id to request: $chatId');
      } else {
        _logger.d('No chatId provided, fetching all starred messages');
      }

      _logger.d('Get starred messages request data: $requestData');

      final response = await _apiClient.request(
        ApiEndpoints.starredMessages,
        method: 'POST',
        body: requestData,
      );

      _logger.d('Get starred messages response: $response');

      if (response != null && response['status'] == true) {
        _logger.i('Get starred messages successful');
        return StarredMessagesResponse.fromJson(response);
      } else {
        _logger.w('Get starred messages failed - Invalid response');
        return null;
      }
    } catch (e) {
      _logger.e('Get starred messages error: $e');
      return null;
    }
  }

  /// Clear all messages from a chat or delete the chat via API
  /// [chatId] - The ID of the chat to clear
  /// [deleteChat] - If true, deletes the chat entirely. If false, only clears messages
  /// Returns true if successful, false otherwise
  Future<bool> clearChat({required int chatId, bool deleteChat = false}) async {
    try {
      _logger.d(
        '${deleteChat ? 'Deleting' : 'Clearing'} chat - chatId: $chatId',
      );
      final requestData = <String, dynamic>{'chat_id': chatId};

      // Add delete_chat parameter if we want to delete the chat
      if (deleteChat) {
        requestData['delete_chat'] = true;
      }

      _logger.d('Clear/Delete chat request data: $requestData');

      final response = await _apiClient.request(
        ApiEndpoints.clearChat,
        method: 'POST',
        body: requestData,
      );

      _logger.d('Clear chat response: $response');

      if (response != null && response['status'] == true) {
        _logger.i('Chat ${deleteChat ? 'delete' : 'clear'} successful');
        return true;
      } else {
        _logger.w(
          '${deleteChat ? 'Delete' : 'Clear'} chat failed - Invalid response',
        );
        return false;
      }
    } catch (e) {
      _logger.e('${deleteChat ? 'Delete' : 'Clear'} chat error: $e');
      return false;
    }
  }

  /// Get chat media files via API
  /// [chatId] - The ID of the chat to get media for
  /// Returns ChatMediaResponse containing media messages
  Future<ChatMediaResponse?> getChatMedia({
    required int chatId,
    required String type,
  }) async {
    try {
      _logger.d('Getting chat media for chatId: $chatId');

      final requestData = {
        'chat_id': chatId, 'message_type': type, //'media'
      };

      _logger.d('Get chat media request data: $requestData');

      final response = await _apiClient.request(
        ApiEndpoints.chatMedia,
        method: 'POST',
        body: requestData,
      );

      _logger.d('Get chat media response: $response');

      if (response != null && response['status'] == true) {
        _logger.i('Get chat media successful');
        return ChatMediaResponse.fromJson(response);
      } else {
        _logger.w('Get chat media failed - Invalid response');
        return null;
      }
    } catch (e) {
      _logger.e('Get chat media error: $e');
      return null;
    }
  }

  /// Search chats via API
  /// [searchText] - The search query text
  /// Returns a Map containing the search results with the same structure as chat list
  Future<Map<String, dynamic>?> searchChats({
    required String searchText,
  }) async {
    try {
      _logger.d('Searching chats with query: $searchText');

      final requestData = {'searchText': searchText};

      _logger.d('Search chats request data: $requestData');

      final response = await _apiClient.request(
        ApiEndpoints.searchChat,
        method: 'POST',
        body: requestData,
      );

      _logger.d('Search chats response: $response');

      if (response != null && response['status'] == true) {
        _logger.i(
          'Search chats successful - ${response['message'] ?? 'No message'}',
        );
        return response;
      } else {
        _logger.w('Search chats failed - Invalid response');
        return null;
      }
    } catch (e) {
      _logger.e('Search chats error: $e');
      return null;
    }
  }

  /// Search messages in a specific chat
  /// Returns paginated search results with message details
  Future<Map<String, dynamic>?> searchMessages({
    required String searchText,
    required int chatId,
    int page = 1,
  }) async {
    try {
      _logger.d(
        'Searching messages with text: "$searchText", chatId: $chatId, page: $page',
      );

      final requestData = {
        'search_text': searchText,
        'chat_id': chatId,
        'page': page,
      };

      _logger.d('Search messages request data: $requestData');

      final response = await _apiClient.request(
        "/chat/search-message",
        method: 'POST',
        body: requestData,
      );

      _logger.d('Search messages response: $response');

      if (response != null && response['status'] == true) {
        _logger.i(
          'Search messages successful - ${response['message'] ?? 'No message'}',
        );
        return response;
      } else {
        _logger.w('Search messages failed - Invalid response');
        return null;
      }
    } catch (e) {
      _logger.e('Search messages error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchMetadataRepo(String url) async {
    final localStorageKey = 'metadata_${Uri.encodeComponent(url)}';

    try {
      // ✅ Check cache
      final cachedData = await SecurePrefs.getString(localStorageKey);
      if (cachedData != null) {
        return Map<String, dynamic>.from(jsonDecode(cachedData));
      }

      // ✅ Make POST request with url in params (body)
      final response = await http.post(
        Uri.parse("https://api.microlink.io"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"url": url}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];

        final metadata = {
          "title": data["title"] ?? "",
          "description": data["description"] ?? "",
          "image": data["image"]?["url"] ?? data["logo"]?["url"] ?? "",
        };

        // ✅ Save in secure prefs
        await SecurePrefs.setString(localStorageKey, jsonEncode(metadata));

        return metadata;
      } else {
        return {"title": "", "description": "", "image": ""};
      }
    } catch (e) {
      debugPrint("❌ Error fetching metadata: $e");
      return {"title": "", "description": "", "image": ""};
    }
  }
}
