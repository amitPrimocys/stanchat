import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';

/// Reusable message status widget for all message types
/// Shows timestamp and status ticks for sent messages
class MessageStatusWidget extends StatelessWidget {
  final chats.Records chat;
  final String currentUserId;
  final bool isDarkMode;
  final bool isStarred;

  const MessageStatusWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
    this.isDarkMode = false,
    this.isStarred = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSentByMe = chat.senderId.toString() == currentUserId;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Timestamp
          Text(
            _formatTime(),
            style: AppTypography.captionText(context).copyWith(
              color: isDarkMode 
                  ? Colors.white70 
                  : AppColors.textColor.textGreyColor,
              fontSize: 10,
            ),
          ),

          // Message status (for sent messages)
          if (isSentByMe) ...[
            SizedBox(width: SizeConfig.width(1)),
            _buildMessageStatusIcon(context),
          ],
        ],
      ),
    );
  }

  /// Build message status icon based on message seen status
  Widget _buildMessageStatusIcon(BuildContext context) {
    IconData statusIcon = Icons.schedule;
    Color iconColor = isDarkMode ? Colors.white70 : AppColors.textColor.textGreyColor;
    
    // ✅ DEBUG: Log message status for troubleshooting
    final messageStatus = chat.messageSeenStatus?.toLowerCase();
    debugPrint('📱 UI DEBUG: Message ${chat.messageId} status: "$messageStatus"');

    switch (messageStatus) {
      case 'seen':
        statusIcon = Icons.done_all; // Double tick
        iconColor = Colors.blue; // Blue when read
        debugPrint('📱 UI DEBUG: Message ${chat.messageId} showing BLUE ticks (seen)');
        break;
      case 'sent':
      case 'delivered':
        statusIcon = Icons.done_all; // Double tick
        iconColor = isDarkMode ? Colors.white70 : AppColors.textColor.textGreyColor; // Grey when sent
        debugPrint('📱 UI DEBUG: Message ${chat.messageId} showing GREY ticks (sent/delivered)');
        break;
      case 'pending':
      case null:
      default:
        statusIcon = Icons.schedule;
        iconColor = isDarkMode ? Colors.white70 : AppColors.textColor.textGreyColor;
        debugPrint('📱 UI DEBUG: Message ${chat.messageId} showing CLOCK (pending/unknown)');
        break;
    }

    return Icon(
      statusIcon, 
      color: iconColor, 
      size: 12,
    );
  }

  /// Format timestamp for display prioritizing updatedAt over createdAt
  String _formatTime() {
    // Get the actual timestamp to use (updatedAt or createdAt)
    final timestamp = _getMessageTimestamp();
    if (timestamp == null || timestamp.isEmpty) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();

      // Convert to 12-hour format with AM/PM
      final hour12 = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
      final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
      final timeString = '${hour12.toString()}:${dateTime.minute.toString().padLeft(2, '0')} $amPm';

      if (dateTime.day == now.day &&
          dateTime.month == now.month &&
          dateTime.year == now.year) {
        return timeString;
      } else {
        return '${dateTime.day}/${dateTime.month} $timeString';
      }
    } catch (e) {
      return '';
    }
  }

  /// Get message timestamp prioritizing updatedAt over createdAt
  String? _getMessageTimestamp() {
    // Priority: updatedAt -> createdAt -> null
    if (chat.updatedAt != null && chat.updatedAt!.trim().isNotEmpty) {
      return chat.updatedAt;
    }
    
    if (chat.createdAt != null && chat.createdAt!.trim().isNotEmpty) {
      return chat.createdAt;
    }
    
    return null;
  }
}