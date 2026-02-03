import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stanchat/featuers/chat/data/chats_model.dart';
import 'package:stanchat/utils/preference_key/constant/app_colors.dart';
import 'package:stanchat/utils/preference_key/constant/app_text_style.dart';

class ChatDateGrouper {
  static Map<String, List<Records>> groupMessagesByDate(
    List<Records> messages,
  ) {
    final Map<String, List<Records>> groupedMessages = {};

    for (final message in messages) {
      final timestamp = _getMessageTimestamp(message);
      if (timestamp != null) {
        final dateKey = _getDateKey(timestamp);
        groupedMessages.putIfAbsent(dateKey, () => []).add(message);
      }
    }

    // Sort messages within each date group by timestamp (oldest first)
    for (final dateKey in groupedMessages.keys) {
      groupedMessages[dateKey]!.sort((a, b) {
        final timestampA = _getMessageTimestamp(a);
        final timestampB = _getMessageTimestamp(b);

        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return -1;
        if (timestampB == null) return 1;

        try {
          final dateA = DateTime.parse(timestampA);
          final dateB = DateTime.parse(timestampB);
          return dateA.compareTo(dateB); // Oldest first within each group
        } catch (e) {
          return 0;
        }
      });
    }

    return groupedMessages;
  }

  /// Get message timestamp prioritizing createdAt over updatedAt for chronological ordering
  static String? _getMessageTimestamp(Records message) {
    // Priority: createdAt -> updatedAt -> null (for proper chronological order)
    if (message.createdAt != null && message.createdAt!.trim().isNotEmpty) {
      return message.createdAt;
    }

    if (message.updatedAt != null && message.updatedAt!.trim().isNotEmpty) {
      return message.updatedAt;
    }

    return null;
  }

  static String _getDateKey(String timestamp) {
    try {
      final messageDate = DateTime.parse(timestamp);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final msgDate = DateTime(
        messageDate.year,
        messageDate.month,
        messageDate.day,
      );

      if (msgDate == today) {
        return 'Today';
      } else if (msgDate == yesterday) {
        return 'Yesterday';
      } else {
        return DateFormat('dd MMMM yyyy').format(messageDate);
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  static List<Widget> buildGroupedMessageList(
    Map<String, List<Records>> groupedMessages,
    Function(Records) messageBuilder,
  ) {
    final List<Widget> widgets = [];

    // Sort date groups (Today -> Yesterday -> Older dates) for reverse ListView
    final sortedKeys =
        groupedMessages.keys.toList()
          ..sort((a, b) => sortDateKeysForReversedList(a, b));

    for (final dateKey in sortedKeys) {
      // For reversed ListView, we want messages in each group to be in reverse order too
      final messages = groupedMessages[dateKey]!;

      // Add messages for this date (in reverse order within the group)
      for (int i = messages.length - 1; i >= 0; i--) {
        Widget messageWidget = messageBuilder(messages[i]);
        widgets.add(messageWidget);
      }

      // Add date header last (it will appear at the top of the group in reversed ListView)
      widgets.add(buildDateHeader(dateKey));
    }

    return widgets;
  }

  static Widget buildDateHeader(String dateKey) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: AppColors.appPriSecColor.primaryColor,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(
            dateKey,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: AppTypography.fontFamily.poppinsMedium,
              color: ThemeColorPalette.getTextColor(
                AppColors.appPriSecColor.primaryColor,
              ), //AppThemeManage.appTheme.darkWhiteColor,
            ),
          ),
        ),
      ),
    );
  }

  static int sortDateKeysForReversedList(String a, String b) {
    if (a == 'Today') return -1;
    if (b == 'Today') return 1;
    if (a == 'Yesterday') return -1;
    if (b == 'Yesterday') return 1;

    try {
      final dateA = DateFormat('dd MMMM yyyy').parse(a);
      final dateB = DateFormat('dd MMMM yyyy').parse(b);
      return dateB.compareTo(dateA); // Newer dates first for reversed ListView
    } catch (e) {
      return 0;
    }
  }
}
