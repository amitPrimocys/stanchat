import 'dart:convert';
import 'dart:developer' as developer;
import 'package:stanchat/featuers/chat/data/chats_model.dart';
import 'package:stanchat/utils/preference_key/sharedpref_key.dart';

/// Service responsible for caching paginated chat data for the Universal Screen
///
/// Features:
/// - Page-based caching with persistent storage
/// - Session-based cache for fast access
/// - Cache invalidation and cleanup
/// - Memory-efficient storage management
class ChatCacheService {
  static const String _cacheKeyPrefix = 'chat_cache_';
  static const String _cacheMetaKey = 'chat_cache_meta_';
  static const int _maxCachedPages = 10; // Limit cache size
  static const Duration _cacheExpiry = Duration(hours: 24);

  // In-memory cache for current session
  final Map<String, Map<int, List<Records>>> _sessionCache = {};
  final Map<String, Map<int, DateTime>> _cacheTimestamps = {};
  final Map<String, ChatPaginationInfo> _paginationInfo = {};

  /// Get cache key for a specific chat and page
  String _getCacheKey(String chatId, int page) =>
      '$_cacheKeyPrefix${chatId}_page_$page';

  /// Get metadata cache key for a chat
  String _getMetaKey(String chatId) => '$_cacheMetaKey$chatId';

  /// Initialize cache for a specific chat
  Future<void> initializeCacheForChat(String chatId) async {
    try {
      developer.log('🔧 Initializing cache for chat: $chatId');

      // Load pagination metadata
      final metaJson = await SecurePrefs.getString(_getMetaKey(chatId));
      if (metaJson != null) {
        final metaData = jsonDecode(metaJson);
        _paginationInfo[chatId] = ChatPaginationInfo.fromJson(metaData);
        developer.log('📊 Loaded pagination info for chat $chatId');
      }

      // Initialize session cache if not exists
      _sessionCache[chatId] ??= {};
      _cacheTimestamps[chatId] ??= {};

      developer.log('✅ Cache initialized for chat: $chatId');
    } catch (e) {
      developer.log('❌ Error initializing cache for chat $chatId: $e');
    }
  }

  /// Check if data exists in cache for a specific page
  bool hasPageInCache(String chatId, int page) {
    // First check session cache
    if (_sessionCache[chatId]?.containsKey(page) == true) {
      // Check if cache is still valid
      final timestamp = _cacheTimestamps[chatId]?[page];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return true;
      } else {
        // Remove expired cache
        _sessionCache[chatId]?.remove(page);
        _cacheTimestamps[chatId]?.remove(page);
      }
    }
    return false;
  }

  /// Get cached messages for a specific page
  Future<List<Records>?> getCachedPage(String chatId, int page) async {
    try {
      // First try session cache
      if (hasPageInCache(chatId, page)) {
        developer.log(
          '🎯 Retrieved page $page from session cache for chat $chatId',
        );
        return _sessionCache[chatId]![page];
      }

      // Try persistent storage
      final cacheKey = _getCacheKey(chatId, page);
      final cachedJson = await SecurePrefs.getString(cacheKey);

      if (cachedJson != null) {
        final cachedData = jsonDecode(cachedJson);
        final timestamp = DateTime.parse(cachedData['timestamp']);

        // Check if cache is still valid
        if (DateTime.now().difference(timestamp) < _cacheExpiry) {
          final messages =
              (cachedData['messages'] as List)
                  .map((json) => Records.fromJson(json))
                  .toList();

          // Update session cache
          _sessionCache[chatId] ??= {};
          _cacheTimestamps[chatId] ??= {};
          _sessionCache[chatId]![page] = messages;
          _cacheTimestamps[chatId]![page] = timestamp;

          developer.log(
            '💾 Retrieved page $page from persistent cache for chat $chatId',
          );
          return messages;
        } else {
          // Remove expired cache
          await SecurePrefs.remove(cacheKey);
          developer.log(
            '🗑️ Removed expired cache for chat $chatId page $page',
          );
        }
      }

      return null;
    } catch (e) {
      developer.log(
        '❌ Error retrieving cached page $page for chat $chatId: $e',
      );
      return null;
    }
  }

  /// Cache messages for a specific page
  Future<void> cachePage(
    String chatId,
    int page,
    List<Records> messages, {
    ChatPaginationInfo? paginationInfo,
  }) async {
    try {
      developer.log(
        '💾 Caching page $page for chat $chatId with ${messages.length} messages',
      );

      // Update session cache
      _sessionCache[chatId] ??= {};
      _cacheTimestamps[chatId] ??= {};
      _sessionCache[chatId]![page] = List.from(messages);
      _cacheTimestamps[chatId]![page] = DateTime.now();

      // Update pagination info if provided
      if (paginationInfo != null) {
        _paginationInfo[chatId] = paginationInfo;
        await SecurePrefs.setString(
          _getMetaKey(chatId),
          jsonEncode(paginationInfo.toJson()),
        );
      }

      // Save to persistent storage
      final cacheKey = _getCacheKey(chatId, page);
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'messages': messages.map((msg) => msg.toJson()).toList(),
      };

      await SecurePrefs.setString(cacheKey, jsonEncode(cacheData));

      // Clean up old cache if needed
      await _cleanupOldCache(chatId);

      developer.log('✅ Successfully cached page $page for chat $chatId');
    } catch (e) {
      developer.log('❌ Error caching page $page for chat $chatId: $e');
    }
  }

  /// Get all cached pages for a chat
  List<int> getCachedPages(String chatId) {
    final sessionPages = _sessionCache[chatId]?.keys.toList() ?? [];
    return sessionPages..sort();
  }

  /// Get cached messages for multiple pages
  Future<Map<int, List<Records>>> getCachedPagesData(
    String chatId,
    List<int> pages,
  ) async {
    final Map<int, List<Records>> result = {};

    for (final page in pages) {
      final messages = await getCachedPage(chatId, page);
      if (messages != null) {
        result[page] = messages;
      }
    }

    return result;
  }

  /// Get pagination info for a chat
  ChatPaginationInfo? getPaginationInfo(String chatId) {
    return _paginationInfo[chatId];
  }

  /// Clear cache for a specific chat
  Future<void> clearChatCache(String chatId) async {
    try {
      developer.log('🗑️ Clearing cache for chat: $chatId');

      // Clear session cache
      _sessionCache.remove(chatId);
      _cacheTimestamps.remove(chatId);
      _paginationInfo.remove(chatId);

      // Clear persistent storage
      // Get all possible cached pages and remove them
      for (int page = 1; page <= _maxCachedPages; page++) {
        final cacheKey = _getCacheKey(chatId, page);
        await SecurePrefs.remove(cacheKey);
      }

      // Remove metadata
      await SecurePrefs.remove(_getMetaKey(chatId));

      developer.log('✅ Cache cleared for chat: $chatId');
    } catch (e) {
      developer.log('❌ Error clearing cache for chat $chatId: $e');
    }
  }

  /// Clear all cache data
  Future<void> clearAllCache() async {
    try {
      developer.log('🗑️ Clearing all chat cache');

      _sessionCache.clear();
      _cacheTimestamps.clear();
      _paginationInfo.clear();

      developer.log('✅ All cache cleared');
    } catch (e) {
      developer.log('❌ Error clearing all cache: $e');
    }
  }

  /// Clean up old cache entries to prevent storage bloat
  Future<void> _cleanupOldCache(String chatId) async {
    try {
      final cachedPages = getCachedPages(chatId);

      if (cachedPages.length > _maxCachedPages) {
        // Remove oldest pages (keep most recent ones)
        final pagesToRemove = cachedPages.take(
          cachedPages.length - _maxCachedPages,
        );

        for (final page in pagesToRemove) {
          _sessionCache[chatId]?.remove(page);
          _cacheTimestamps[chatId]?.remove(page);
          await SecurePrefs.remove(_getCacheKey(chatId, page));
        }

        developer.log(
          '🧹 Cleaned up ${pagesToRemove.length} old cache pages for chat $chatId',
        );
      }
    } catch (e) {
      developer.log('❌ Error cleaning up cache: $e');
    }
  }

  /// Get cache size info for debugging
  Map<String, dynamic> getCacheInfo() {
    final info = <String, dynamic>{};

    for (final chatId in _sessionCache.keys) {
      info[chatId] = {
        'cached_pages': getCachedPages(chatId),
        'total_messages':
            _sessionCache[chatId]?.values.fold<int>(
              0,
              (sum, messages) => sum + messages.length,
            ) ??
            0,
      };
    }

    return info;
  }

  /// Update cached messages (for real-time updates)
  Future<void> updateMessage(String chatId, Records updatedMessage) async {
    try {
      // Update in all cached pages that contain this message
      final cachedPages = getCachedPages(chatId);
      bool messageUpdated = false;

      for (final page in cachedPages) {
        final messages = _sessionCache[chatId]![page]!;
        final messageIndex = messages.indexWhere(
          (msg) => msg.messageId == updatedMessage.messageId,
        );

        if (messageIndex != -1) {
          messages[messageIndex] = updatedMessage;
          messageUpdated = true;

          // Update persistent cache for this page
          await cachePage(chatId, page, messages);
          developer.log(
            '🔄 Updated message ${updatedMessage.messageId} in cached page $page',
          );
        }
      }

      if (!messageUpdated) {
        developer.log(
          '⚠️ Message ${updatedMessage.messageId} not found in cache for update',
        );
      }
    } catch (e) {
      developer.log('❌ Error updating cached message: $e');
    }
  }

  /// Add new message to cache (for real-time messages)
  Future<void> addNewMessage(String chatId, Records newMessage) async {
    try {
      // Add to the first page (most recent messages)
      const int firstPage = 1;

      if (hasPageInCache(chatId, firstPage)) {
        final messages = _sessionCache[chatId]![firstPage]!;

        // Add at the beginning (most recent)
        messages.insert(0, newMessage);

        // Update cache
        await cachePage(chatId, firstPage, messages);
        developer.log('➕ Added new message to cached page $firstPage');
      }
    } catch (e) {
      developer.log('❌ Error adding new message to cache: $e');
    }
  }
}

/// Pagination information for cached chat data
class ChatPaginationInfo {
  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final bool hasMore;

  ChatPaginationInfo({
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.hasMore,
  });

  Map<String, dynamic> toJson() => {
    'currentPage': currentPage,
    'totalPages': totalPages,
    'totalRecords': totalRecords,
    'hasMore': hasMore,
  };

  factory ChatPaginationInfo.fromJson(Map<String, dynamic> json) =>
      ChatPaginationInfo(
        currentPage: json['currentPage'] ?? 1,
        totalPages: json['totalPages'] ?? 1,
        totalRecords: json['totalRecords'] ?? 0,
        hasMore: json['hasMore'] ?? false,
      );
}
