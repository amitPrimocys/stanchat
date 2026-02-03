// ✅ NEW: Build metadata row with star, timestamp, and status
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:stanchat/utils/app_size_config.dart';
import 'package:stanchat/utils/preference_key/constant/app_assets.dart';
import 'package:stanchat/utils/preference_key/constant/app_colors.dart';
import 'package:stanchat/featuers/chat/data/chats_model.dart' as chats;
import 'package:stanchat/utils/preference_key/constant/app_text_style.dart';

class ChatRelatedWidget {
  static Widget buildMetadataRow({
    required BuildContext context,
    required chats.Records chat,
    required bool isStarred,
    required bool isSentByMe,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Pinned indicator (only show if pinned and not starred)
        if (chat.pinned == true) ...[
          SvgPicture.asset(
            AppAssets.pinMessageIcon,
            height: 13,
            color:
                isSentByMe
                    ? AppColors.appPriSecColor.primaryColor
                    : AppColors.textColor.textGreyColor,
          ),
          SizedBox(width: SizeConfig.width(1)),
        ],

        // Star indicator (only show if starred)
        if (isStarred) ...[
          Padding(
            padding: SizeConfig.getPaddingOnly(bottom: 2),
            child: Icon(
              Icons.star,
              size: 12,
              color: AppColors.appPriSecColor.primaryColor,
            ),
          ),
          SizedBox(width: SizeConfig.width(1)),
        ],

        if (isSentByMe) ...[
          buildMessageStatus(
            context: context,
            chat: chat,
            isStarred: isStarred,
            isSentByMe: isSentByMe,
          ),
          SizedBox(width: SizeConfig.width(1)),
        ],

        // Timestamp
        Text(
          _formatTime(chat.createdAt),
          style: AppTypography.captionText(context).copyWith(
            color:
                isSentByMe
                    ? AppColors.textColor.textDarkGray
                    : AppColors.textColor.textGreyColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ✅ Message status indicators
  static Widget buildMessageStatus({
    required BuildContext context,
    required chats.Records chat,
    required bool isStarred,
    required bool isSentByMe,
  }) {
    IconData statusIcon = Icons.schedule;
    Color iconColor = AppColors.textColor.textDarkGray;

    switch (chat.messageSeenStatus?.toLowerCase()) {
      case 'seen':
        statusIcon = Icons.done_all; // Double tick
        iconColor = Colors.blue; // Blue when read
        break;
      case 'sent':
        statusIcon = Icons.done_all; // Double tick
        iconColor = AppColors.textColor.textDarkGray; // Grey when sent
        break;
      case 'pending':
      default:
        statusIcon = Icons.schedule;
        iconColor = AppColors.textColor.textDarkGray;
        break;
    }

    return Icon(statusIcon, color: iconColor, size: 12);
  }

  // ✅ Helper: Format timestamp
  static String _formatTime(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final localDateTime = dateTime.toLocal(); // Convert to local time
      return DateFormat.jm().format(localDateTime); // e.g., 12:30 PM
    } catch (e) {
      return '';
    }
  }

  // String _formatTime(String? timestamp) {
  //   if (timestamp == null) return '';

  //   try {
  //     final dateTime = DateTime.parse(timestamp);
  //     final now = DateTime.now();

  //     if (dateTime.day == now.day &&
  //         dateTime.month == now.month &&
  //         dateTime.year == now.year) {
  //       return DateFormat.jm().format(
  //         dateTime,
  //       ); //'${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  //     } else {
  //       return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  //     }
  //   } catch (e) {
  //     return '';
  //   }
  // }

  // ✅ Build text preview
  static Widget buildTextPreview({
    required BuildContext context,
    required String content,
    required bool isSentByMe,
  }) {
    return Text(
      content,
      style: AppTypography.captionText(
        context,
      ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ✅ Build text preview
  static Widget buildLinkPreview({
    required BuildContext context,
    required String content,
    required bool isSentByMe,
  }) {
    return Text(
      content,
      style: AppTypography.captionText(
        context,
      ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ✅ Build image preview
  static Widget buildImagePreview({
    required BuildContext context,
    required String imageUrl,
    required bool isSentByMe,
  }) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.galleryMsg,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: "Photo",
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build voice preview
  static Widget buildVoicePreview({
    required BuildContext context,
    required bool isSentByMe,
  }) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.voiceMic,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: "Voice message",
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build gif preview
  static Widget buildGifPreview({
    required BuildContext context,
    required String imageUrl,
    required bool isSentByMe,
  }) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.galleryMsg,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: "Gif",
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build video preview
  static Widget buildVideoPreview({
    required BuildContext context,
    required String videoUrl,
    String? thumbnailUrl,
    required bool isSentByMe,
  }) {
    // final displayThumbnail = thumbnailUrl ?? videoUrl;

    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.videoMsg,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: "Video",
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build document preview
  static Widget buildDocumentPreview(BuildContext context, bool isSentByMe) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.documentMsg,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: "Document",
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build location preview
  static Widget buildLocationPreview(BuildContext context, bool isSentByMe) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.locationMsg,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: "Location",
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ✅ Build contact preview
  static Widget buildContactPreview(BuildContext context, bool isSentByMe) {
    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SvgPicture.asset(
              AppAssets.chatMsgTypeIcon.contactMsg,
              height: 14,
              color: AppColors.textColor.textDarkGray,
            ),
          ),
          WidgetSpan(child: SizedBox(width: SizeConfig.width(1))),
          TextSpan(
            text: "Contact",
            style: AppTypography.captionText(
              context,
            ).copyWith(color: AppColors.textColor.textDarkGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static String getSenderName(
    Map<String, dynamic> parentMessage,
    String currentUserId,
  ) {
    final senderId = parentMessage['sender_id'];
    if (senderId != null && senderId.toString() == currentUserId) {
      return 'You';
    }

    if (parentMessage.containsKey('User') && parentMessage['User'] != null) {
      final userData = parentMessage['User'] as Map<String, dynamic>;
      return userData['full_name'] ?? userData['user_name'] ?? 'Unknown';
    }

    return 'User';
  }
}
