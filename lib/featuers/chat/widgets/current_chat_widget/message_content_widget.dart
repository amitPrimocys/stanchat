// ========================================
// message_content_widget.dart - Final Version with Star Support
// ========================================

import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/delete_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/document_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/gif_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/group_created_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/image_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/link_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/location_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/story_reply_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/text_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/video_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/call_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/contact_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/block_unblock_message_widget.dart';
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/voice_message_widget.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';

/// Main widget that determines which message type to display
/// Updated MessageContentWidget with star support
class MessageContentWidget extends StatelessWidget {
  final chats.Records chat;
  final String currentUserId;
  final int? index;
  final ChatProvider? chatProvider;
  final Function(String)? onImageTap;
  final Function(String)? onVideoTap;
  final Function(chats.Records)? onDocumentTap;
  final Function(double, double)? onLocationTap;
  final bool isStarred; // ✅ STAR Flag
  final Function(int)? onReplyTap; // ✅ NEW: Callback for reply tap
  final int? peerUserId; // ✅ NEW: Peer user ID for call direction
  final _logger = ConsoleAppLogger.forModule('MessageContentWidget');

  // ✅ ANTI-FLICKER: Static cache to preserve actionedUser data across rebuilds
  static final Map<int, chats.User> _actionedUserCache = {};

  MessageContentWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.chatProvider,
    this.index,
    this.onImageTap,
    this.onVideoTap,
    this.onDocumentTap,
    this.onLocationTap,
    this.isStarred = false, // ✅ STAR Flag
    this.onReplyTap, // ✅ NEW: Optional callback for reply tap
    this.peerUserId, // ✅ NEW: Optional peer user ID for call direction
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Use the passed star status instead of checking from chat data
    return _buildMessageContent(context);
  }

  // ✅ IMPROVED: Use passed star status for real-time updates
  Widget _buildMessageContent(BuildContext context) {
    // ✅ Check if the message is deleted first, regardless of message type
    // Check multiple conditions to ensure deleted messages are properly handled
    if (chat.messageContent == 'This message was deleted.' ||
        chat.messageContent == 'This message was deleted' ||
        chat.deletedForEveryone == true) {
      return DeletedMessageWidget(chat: chat, currentUserId: currentUserId);
    }

    switch (chat.messageType?.toLowerCase()) {
      case 'text':
        return TextMessageWidget(
          chat: chat,
          currentUserId: currentUserId,
          isStarred: isStarred, // ✅ Pass real-time star status
          onReplyTap: onReplyTap, // ✅ NEW: Pass reply tap callback
        );

      case 'link':
        return LinkMessageWidget(
          chat: chat,
          currentUserId: currentUserId,
          isStarred: isStarred, // ✅ Pass real-time star status
          onReplyTap: onReplyTap, // ✅ NEW: Pass reply tap callback
          isForPinned: false,
        );

      case 'voice':
        return VoiceMessageWidget(
          chat: chat,
          currentUserId: currentUserId,
          onTap: () => onImageTap?.call(chat.messageContent ?? ''),
          isStarred: isStarred, // ✅ Pass real-time star status
          onReplyTap: onReplyTap, // ✅ NEW: Pass reply tap callback
          isForPinned: false,
        );

      case 'image':
        return ImageMessageWidget(
          chat: chat,
          currentUserId: currentUserId,
          onTap: () => onImageTap?.call(chat.messageContent ?? ''),
          isStarred: isStarred, // ✅ Pass real-time star status
          onReplyTap: onReplyTap, // ✅ NEW: Pass reply tap callback
          isForPinned: false,
        );

      case 'gif':
        return GifMessageWidget(
          chat: chat,
          currentUserId: currentUserId,
          onTap: () => onImageTap?.call(chat.messageContent ?? ''),
          isStarred: isStarred,
          onReplyTap: onReplyTap,
          isForPinned: false,
        );

      case 'document':
      case 'doc':
      case 'pdf':
        return DocumentMessageWidget(
          chat: chat,
          currentUserId: currentUserId,
          onTap: () => onDocumentTap?.call(chat),
          chatProvider: chatProvider!,
          isStarred: isStarred, // ✅ Pass real-time star status
          onReplyTap: onReplyTap,
          isForPinned: false,
        );

      case 'video':
        return VideoMessageWidget(
          chat: chat,
          currentUserId: currentUserId,
          onTap: () => onVideoTap?.call(chat.messageContent ?? ''),
          thumbnailUrl: chat.messageThumbnail,
          isStarred: isStarred, // ✅ Pass real-time star status
          onReplyTap: onReplyTap,
          isForPinned: false,
        );

      case 'location':
        return LocationMessageWidget(
          chat: chat,
          currentUserId: currentUserId,
          onTap: () {
            if (chat.messageContent != null) {
              final coordinates = chat.messageContent!.split(',');
              if (coordinates.length >= 2) {
                final lat = double.tryParse(coordinates[0].trim());
                final lng = double.tryParse(coordinates[1].trim());
                if (lat != null && lng != null) {
                  onLocationTap?.call(lat, lng);
                }
              }
            }
          },
          latitude: _getLatitude(),
          longitude: _getLongitude(),
          isStarred: isStarred, // ✅ Pass real-time star status
          onReplyTap: onReplyTap,
          isForPinned: false,
        );

      case 'story_reply':
        return StoryReplyMessageWidget(
          chat: chat,
          currentUserId: currentUserId,
          isStarred: isStarred, // ✅ Pass real-time star status
          onReplyTap: onReplyTap, // ✅ NEW: Pass reply tap callback
          isForPinned: false,
        );

      case 'call':
        _logger.d('chat check for pass CallMessageWidget: ${chat.toJson()}');
        return CallMessageWidget(
          key: ValueKey('call_${chat.messageId}_${chat.messageContent}'),
          chat: chat,
          currentUserId: currentUserId,
          isStarred: isStarred,
          onReplyTap: onReplyTap,
          peerUserId: peerUserId,
        );

      case 'group-created':
        final currentUserIdInt = int.tryParse(currentUserId);
        final creatorName =
            chat.senderId == currentUserIdInt
                ? "You"
                : chat.user?.fullName ?? "Someone";
        return GroupCreatedMessageWidget(creatorName: creatorName);

      case 'member-removed':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: Text(
              _buildMemberActionMessage(chat, 'removed'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        );

      case 'member-added':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: Text(
              _buildMemberActionMessage(chat, 'added'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        );

      case 'member-left':
        final currentUserIdInt = int.tryParse(currentUserId);
        final messageId = chat.messageId;

        String leftMessage;

        // ✅ CACHE LOGIC: Save actionedUser to cache if present, retrieve from cache if missing
        chats.User? actionedUser = chat.actionedUser;

        if (actionedUser != null && messageId != null) {
          // Save to cache for future rebuilds
          _actionedUserCache[messageId] = actionedUser;
          _logger.d(
            '💾 Cached actionedUser for message $messageId: ${actionedUser.userId}',
          );
        } else if (actionedUser == null &&
            messageId != null &&
            _actionedUserCache.containsKey(messageId)) {
          // Restore from cache if current message doesn't have it
          actionedUser = _actionedUserCache[messageId];
          _logger.d(
            '♻️ Restored actionedUser from cache for message $messageId: ${actionedUser?.userId}',
          );
        }

        // ✅ ANTI-FLICKER: Always prioritize actionedUser field (including cached)
        if (actionedUser != null && actionedUser.userId != null) {
          final actionedUserId = actionedUser.userId;
          final actionedUserName =
              actionedUser.fullName ?? actionedUser.userName ?? 'Someone';

          // Debug logging to trace the issue
          _logger.d('=== member-left message debug (MessageContentWidget) ===');
          _logger.d('messageId: $messageId');
          _logger.d('actionedUserId: $actionedUserId');
          _logger.d('currentUserIdInt: $currentUserIdInt');
          _logger.d('actionedUserName: $actionedUserName');
          _logger.d('Match: ${actionedUserId == currentUserIdInt}');
          _logger.d('From cache: ${chat.actionedUser == null}');
          _logger.d(
            '=========================================================',
          );

          // ✅ ROBUST COMPARISON: Ensure both IDs are valid before comparison
          if (actionedUserId != null &&
              currentUserIdInt != null &&
              actionedUserId == currentUserIdInt) {
            leftMessage = 'You left the group.';
          } else if (actionedUserName.isNotEmpty) {
            // ✅ STABLE: Once we have valid actionedUser data, always use it
            leftMessage = '$actionedUserName left the group.';
          } else {
            leftMessage = 'Someone left the group.';
          }
        } else {
          // ⚠️ FALLBACK: Only use this when actionedUser is completely unavailable
          // This fallback should rarely execute now with caching
          _logger.w(
            '⚠️ ActionedUser not available (even from cache) for message ${chat.messageId}',
          );

          String? rawContent = chat.messageContent;
          if (rawContent != null && rawContent.isNotEmpty) {
            // Try to parse the message content as last resort
            if (rawContent.contains('You left') ||
                rawContent.contains('Youleft')) {
              leftMessage = 'You left the group.';
            } else {
              // Try to add spaces to the message content
              leftMessage = rawContent
                  .replaceAll('Youleftthisgroup', 'You left this group')
                  .replaceAll('leftthisgroup', ' left this group')
                  .replaceAll('.', '.');
            }
          } else {
            leftMessage = 'A member left the group.';
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: Text(
              leftMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        );

      case 'contact':
        return ContactMessageWidget(
          chat: chat,
          currentUserId: currentUserId,
          isStarred: isStarred,
          onReplyTap: onReplyTap,
          isForPinned: false,
        );

      case 'block':
      case 'unblock':
        return BlockUnblockMessageWidget(
          chat: chat,
          currentUserId: currentUserId,
          isStarred: isStarred,
          onReplyTap: onReplyTap,
        );

      case 'promoted-as-admin':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: Text(
              _buildAdminActionMessage(chat, 'promoted'),
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        );

      case 'removed-as-admin':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: Text(
              _buildAdminActionMessage(chat, 'removed'),
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        );

      default:
        return _buildUnsupportedMessage(context);
    }
  }

  // ✅ IMPROVED: Unsupported message with real-time star support
  Widget _buildUnsupportedMessage(BuildContext context) {
    return Container(
      padding: SizeConfig.getPaddingSymmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.grey,
        borderRadius: BorderRadius.circular(8),
        // ✅ Add border for starred unsupported messages using real-time status
        border:
            isStarred
                ? Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                  width: 1,
                )
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Unsupported message type: ${chat.messageType}',
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textGreyColor),
          ),

          // ✅ Show star and metadata for unsupported messages using real-time status
          if (isStarred) ...[
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ✅ Simple star indicator for unsupported messages
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      'Starred',
                      style: AppTypography.captionText(context).copyWith(
                        color: Colors.amber[700],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatTime(chat.createdAt),
                  style: AppTypography.captionText(context).copyWith(
                    color: AppColors.textColor.textGreyColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  double? _getLatitude() {
    if (chat.messageContent == null) return null;
    final coordinates = chat.messageContent!.split(',');
    if (coordinates.isNotEmpty) {
      return double.tryParse(coordinates[0].trim());
    }
    return null;
  }

  double? _getLongitude() {
    if (chat.messageContent == null) return null;
    final coordinates = chat.messageContent!.split(',');
    if (coordinates.length >= 2) {
      return double.tryParse(coordinates[1].trim());
    }
    return null;
  }

  // ✅ Helper method to format time
  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();

      if (dateTime.day == now.day &&
          dateTime.month == now.month &&
          dateTime.year == now.year) {
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  // Helper method to build member action messages
  String _buildMemberActionMessage(chats.Records chat, String action) {
    final currentUserIdInt = int.tryParse(currentUserId);
    final messageId = chat.messageId;

    // ✅ CACHE LOGIC: Restore actionedUser from cache if missing (same as member-left)
    chats.User? actionedUser = chat.actionedUser;

    if (actionedUser != null && messageId != null) {
      // Save to cache for future rebuilds
      _actionedUserCache[messageId] = actionedUser;
      _logger.d(
        '💾 Cached actionedUser for $action message $messageId: ${actionedUser.userId}',
      );
    } else if (actionedUser == null &&
        messageId != null &&
        _actionedUserCache.containsKey(messageId)) {
      // Restore from cache if current message doesn't have it
      actionedUser = _actionedUserCache[messageId];
      _logger.d(
        '♻️ Restored actionedUser from cache for $action message $messageId: ${actionedUser?.userId}',
      );
    }

    final actionedUserName =
        actionedUser?.userId == currentUserIdInt
            ? 'You'
            : (actionedUser?.fullName ?? actionedUser?.userName ?? 'Someone');
    final actorName =
        chat.senderId == currentUserIdInt
            ? 'You'
            : (chat.user?.fullName ?? chat.user?.userName ?? 'Someone');

    // ✅ Debug logging for member-removed/added
    _logger.d('=== $action message debug ===');
    _logger.d('messageId: $messageId');
    _logger.d('actionedUserId: ${actionedUser?.userId}');
    _logger.d('actionedUserName: $actionedUserName');
    _logger.d('actorName: $actorName');
    _logger.d('From cache: ${chat.actionedUser == null}');
    _logger.d('===========================');

    // Check if the actor and actioned user are the same (self-action)
    final isSelfAction = chat.senderId == actionedUser?.userId;

    if (isSelfAction) {
      // When someone removes/adds themselves
      if (action == 'removed') {
        return chat.senderId == currentUserIdInt
            ? 'You left the group.'
            : '$actionedUserName left the group.';
      } else {
        return chat.senderId == currentUserIdInt
            ? 'You joined the group.'
            : '$actionedUserName joined the group.';
      }
    } else {
      // When someone else removes/adds the user
      if (action == 'removed') {
        return '$actionedUserName was removed from this group by $actorName.';
      } else {
        return '$actionedUserName was added to this group by $actorName.';
      }
    }
  }

  // Helper method to build admin action messages
  String _buildAdminActionMessage(chats.Records chat, String action) {
    final currentUserIdInt = int.tryParse(currentUserId);
    final messageId = chat.messageId;

    // ✅ CACHE LOGIC: Restore actionedUser from cache if missing (same as member actions)
    chats.User? actionedUser = chat.actionedUser;

    if (actionedUser != null && messageId != null) {
      // Save to cache for future rebuilds
      _actionedUserCache[messageId] = actionedUser;
      _logger.d(
        '💾 Cached actionedUser for admin $action message $messageId: ${actionedUser.userId}',
      );
    } else if (actionedUser == null &&
        messageId != null &&
        _actionedUserCache.containsKey(messageId)) {
      // Restore from cache if current message doesn't have it
      actionedUser = _actionedUserCache[messageId];
      _logger.d(
        '♻️ Restored actionedUser from cache for admin $action message $messageId: ${actionedUser?.userId}',
      );
    }

    final actionedUserName =
        actionedUser?.userId == currentUserIdInt
            ? 'You'
            : (actionedUser?.fullName ?? actionedUser?.userName ?? 'Someone');
    final actorName =
        chat.senderId == currentUserIdInt
            ? 'You'
            : (chat.user?.fullName ?? chat.user?.userName ?? 'Someone');

    // ✅ Debug logging for admin promoted/removed
    _logger.d('=== admin $action message debug ===');
    _logger.d('messageId: $messageId');
    _logger.d('actionedUserId: ${actionedUser?.userId}');
    _logger.d('actionedUserName: $actionedUserName');
    _logger.d('actorName: $actorName');
    _logger.d('From cache: ${chat.actionedUser == null}');
    _logger.d('===================================');

    // Check if the actor and actioned user are the same (self-action)
    final isSelfAction = chat.senderId == actionedUser?.userId;

    if (isSelfAction) {
      // When someone changes their own admin status (unlikely but handle gracefully)
      if (action == 'promoted') {
        return chat.senderId == currentUserIdInt
            ? 'You became an admin.'
            : '$actionedUserName became an admin.';
      } else {
        return chat.senderId == currentUserIdInt
            ? 'You are no longer an admin.'
            : '$actionedUserName is no longer an admin.';
      }
    } else {
      // When someone else promotes/removes admin status
      if (action == 'promoted') {
        return '$actionedUserName was promoted to admin by $actorName.';
      } else {
        return '$actionedUserName was removed as admin by $actorName.';
      }
    }
  }
}
