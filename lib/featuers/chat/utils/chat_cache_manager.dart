import 'dart:developer' as developer;
import 'package:stanchat/featuers/chat/data/chats_model.dart';
import 'package:stanchat/featuers/chat/services/chat_cache_service.dart';

/// Utility class for managing chat cache operations
///
/// This provides a simplified interface for cache operations
/// and can be used by any widget or provider that needs caching
class ChatCacheManager {
  static final ChatCacheService _cacheService = ChatCacheService();

  /// Initialize cache for a chat
  static Future<void> initializeChat(String chatId) async {
    await _cacheService.initializeCacheForChat(chatId);
  }

  /// Check if page is cached
  static bool hasPage(String chatId, int page) {
    return _cacheService.hasPageInCache(chatId, page);
  }

  /// Get cached page
  static Future<List<Records>?> getPage(String chatId, int page) async {
    return await _cacheService.getCachedPage(chatId, page);
  }

  /// Cache a page
  static Future<void> cachePage(
    String chatId,
    int page,
    List<Records> messages, {
    Pagination? pagination,
  }) async {
    ChatPaginationInfo? paginationInfo;

    if (pagination != null) {
      paginationInfo = ChatPaginationInfo(
        currentPage: pagination.currentPage ?? page,
        totalPages: pagination.totalPages ?? 1,
        totalRecords: pagination.totalRecords ?? 0,
        hasMore:
            (pagination.currentPage ?? page) < (pagination.totalPages ?? 1),
      );
    }

    await _cacheService.cachePage(
      chatId,
      page,
      messages,
      paginationInfo: paginationInfo,
    );
  }

  /// Get cached pages list
  static List<int> getCachedPages(String chatId) {
    return _cacheService.getCachedPages(chatId);
  }

  /// Clear cache for a chat
  static Future<void> clearChat(String chatId) async {
    await _cacheService.clearChatCache(chatId);
  }

  /// Clear all cache
  static Future<void> clearAll() async {
    await _cacheService.clearAllCache();
  }

  /// Update cached message
  static Future<void> updateMessage(String chatId, Records message) async {
    await _cacheService.updateMessage(chatId, message);
  }

  /// Add new message to cache
  static Future<void> addMessage(String chatId, Records message) async {
    await _cacheService.addNewMessage(chatId, message);
  }

  /// Get cache info for debugging
  static Map<String, dynamic> getCacheInfo() {
    return _cacheService.getCacheInfo();
  }

  /// Create a ChatsModel from cached data
  static ChatsModel createChatModelFromCache(
    List<Records> messages,
    int currentPage,
    int totalPages,
  ) {
    final pagination = Pagination(
      currentPage: currentPage,
      totalPages: totalPages,
      totalRecords: messages.length,
      recordsPerPage: messages.length,
    );

    return ChatsModel(records: messages, pagination: pagination);
  }

  /// Log cache statistics
  static void logCacheStats(String chatId) {
    final cachedPages = getCachedPages(chatId);
    final cacheInfo = getCacheInfo();

    developer.log('📊 Cache Stats for $chatId:');
    developer.log('   Cached Pages: $cachedPages');
    developer.log('   Cache Info: $cacheInfo');
  }
}
