import 'dart:math';
import 'package:flutter/material.dart';
import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
import 'package:whoxa/featuers/chat/widgets/current_chat_widget/chat_related_widget.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_direction_manage.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

class TextMessageWidget extends StatelessWidget {
  final chats.Records chat;
  final String currentUserId;
  final bool isStarred; // ✅ NEW: Star status parameter
  final Function(int)? onReplyTap; // ✅ NEW: Callback for reply tap
  final bool openedFromStarred; // If Opened from the Starred Messages Screen

  const TextMessageWidget({
    super.key,
    required this.chat,
    required this.currentUserId,
    this.isStarred = false, // ✅ NEW: Default to false
    this.onReplyTap, // ✅ NEW: Optional callback for reply tap
    this.openedFromStarred =
        false, // If Opened from the Starred Messages Screen
  });

  @override
  Widget build(BuildContext context) {
    final isSentByMe = chat.senderId.toString() == currentUserId;
    final hasParentMessage = chat.parentMessage != null;

    final messageText = chat.messageContent ?? '';
    final parentText = chat.parentMessage?['message_content'] ?? '';
    final senderName = ChatRelatedWidget.getSenderName(
      chat.parentMessage ?? {},
      currentUserId,
    );
    final messageType = chat.messageType ?? 'text';
    final parentType = chat.parentMessage?['message_type'] ?? 'text';

    final messageWidth = _calculateTextWidth1(
      context,
      messageText,
      messageType,
    );
    final parentWidth =
        hasParentMessage
            ? _calculateTextWidth1(context, parentText, parentType)
            : 0.0;
    final senderNameWidth = _calculateTextWidth1(context, senderName, 'text');

    final totalBubbleWidth = min(
      SizeConfig.width(70),
      max(max(messageWidth, parentWidth), senderNameWidth) + 30,
    ); // 30 for padding

    return Column(
      crossAxisAlignment:
          openedFromStarred
              ? CrossAxisAlignment.start
              : isSentByMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: totalBubbleWidth),
          decoration: BoxDecoration(
            color:
                isSentByMe
                    ? AppColors.appPriSecColor.secondaryColor
                    : AppThemeManage.appTheme.chatOppText,
            borderRadius:
                openedFromStarred
                    ? BorderRadius.circular(hasParentMessage ? 9 : 12)
                    : AppDirectionality.appDirectionBorderRadius
                        .chatBubbleRadius(
                          isSentByMe: isSentByMe,
                          hasParentMessage: hasParentMessage,
                        ),
            // isSentByMe
            //     ? openedFromStarred
            //         ? BorderRadius.circular(hasParentMessage ? 9 : 12)
            //         : BorderRadius.only(
            //           topLeft: Radius.circular(hasParentMessage ? 9 : 12),
            //           bottomLeft: Radius.circular(
            //             hasParentMessage ? 9 : 12,
            //           ),
            //           topRight: Radius.circular(hasParentMessage ? 9 : 12),
            //         )
            //     : BorderRadius.only(
            //       topRight: Radius.circular(hasParentMessage ? 9 : 12),
            //       bottomRight: Radius.circular(hasParentMessage ? 9 : 12),
            //       topLeft: Radius.circular(hasParentMessage ? 9 : 12),
            //     ),
          ),
          child: Padding(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: hasParentMessage ? 3 : 15,
              vertical: hasParentMessage ? 3 : 8,
            ),
            child: Column(
              crossAxisAlignment:
                  isSentByMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ ENHANCED: Show parent message if this is a reply
                if (hasParentMessage) ...[
                  _buildParentMessagePreview(
                    context,
                    isSentByMe,
                    totalBubbleWidth,
                  ),
                  SizedBox(height: 8),
                ],

                // Main message content
                Padding(
                  padding: SizeConfig.getPaddingOnly(
                    left: hasParentMessage ? 10 : 0,
                    right: hasParentMessage ? 8 : 0,
                  ),
                  child: Text(
                    chat.messageContent ?? '',
                    style: AppTypography.innerText12Ragu(context).copyWith(
                      color:
                          isSentByMe
                              ? ThemeColorPalette.getTextColor(
                                AppColors.appPriSecColor.primaryColor,
                              )
                              : AppThemeManage.appTheme.textColor,
                    ),
                  ),
                ),
                isSentByMe
                    ? hasParentMessage
                        ? SizedBox(height: SizeConfig.height(2))
                        : SizedBox.shrink()
                    : SizedBox.shrink(),
              ],
            ),
          ),
        ),
        // ✅ NEW: Add metadata row with star
        SizedBox(height: SizeConfig.height(1)),
        if (!openedFromStarred)
          ChatRelatedWidget.buildMetadataRow(
            context: context,
            chat: chat,
            isStarred: isStarred,
            isSentByMe: isSentByMe,
          ),
        if (!openedFromStarred) SizedBox(height: SizeConfig.height(0)),
      ],
    );
  }

  // ✅ ENHANCED: Build parent message preview with media support and tap functionality
  Widget _buildParentMessagePreview(
    BuildContext context,
    bool isSentByMe,
    double width,
  ) {
    final parentMessage = chat.parentMessage!;
    final parentContent = parentMessage['message_content'] ?? 'Message';
    final parentType = parentMessage['message_type'] ?? 'text';
    final parentThumbnail = parentMessage['message_thumbnail'];
    final parentMessageId = parentMessage['message_id'];

    return GestureDetector(
      onTap: () {
        // ✅ NEW: Handle tap to navigate to original message
        if (onReplyTap != null && parentMessageId != null) {
          onReplyTap!(parentMessageId as int);
        }
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Container(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: AppThemeManage.appTheme.bg488DarkGrey,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with reply icon and sender name
              Row(
                children: [
                  Text(
                    ChatRelatedWidget.getSenderName(
                      parentMessage,
                      currentUserId,
                    ),
                    style: AppTypography.captionText(context).copyWith(
                      color: AppColors.appPriSecColor.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1),

              // ✅ Media preview or text content
              _buildParentMessageContent(
                context,
                parentType,
                parentContent,
                parentThumbnail,
                isSentByMe,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Build parent message content based on type
  Widget _buildParentMessageContent(
    BuildContext context,
    String messageType,
    String content,
    String? thumbnail,
    bool isSentByMe,
  ) {
    // ✅ Check if the message is deleted and show only text
    if (content == 'This message was deleted.' ||
        content == 'This message was deleted' ||
        content.isEmpty) {
      return ChatRelatedWidget.buildTextPreview(
        context: context,
        content: 'This message was deleted.',
        isSentByMe: isSentByMe,
      );
    }

    switch (messageType.toLowerCase()) {
      case 'voice':
        return ChatRelatedWidget.buildVoicePreview(
          context: context,
          isSentByMe: isSentByMe,
        );
      case 'image':
        return ChatRelatedWidget.buildImagePreview(
          context: context,
          imageUrl: content,
          isSentByMe: isSentByMe,
        );
      case 'gif':
        return ChatRelatedWidget.buildGifPreview(
          context: context,
          imageUrl: content,
          isSentByMe: isSentByMe,
        );
      case 'video':
        return ChatRelatedWidget.buildVideoPreview(
          context: context,
          videoUrl: content,
          thumbnailUrl: thumbnail,
          isSentByMe: isSentByMe,
        );
      case 'document':
      case 'doc':
      case 'pdf':
        return ChatRelatedWidget.buildDocumentPreview(context, isSentByMe);
      case 'location':
        return ChatRelatedWidget.buildLocationPreview(context, isSentByMe);
      case 'contact':
        return ChatRelatedWidget.buildContactPreview(context, isSentByMe);
      case 'link':
        return ChatRelatedWidget.buildLinkPreview(
          context: context,
          content: content,
          isSentByMe: isSentByMe,
        );
      case 'text':
      default:
        return ChatRelatedWidget.buildTextPreview(
          context: context,
          content: content,
          isSentByMe: isSentByMe,
        );
    }
  }

  // double _calculateTextWidth(BuildContext context, String text) {
  //   final TextPainter textPainter = TextPainter(
  //     text: TextSpan(text: text, style: AppTypography.mediumText(context)),
  //     maxLines: 1,
  //     textDirection: TextDirection.ltr,
  //   )..layout();

  //   // Add some padding so text doesn't hit the edge
  //   return textPainter.size.width + 24;
  // }

  double _calculateTextWidth1(
    BuildContext context,
    String messageContent,
    String messageType,
  ) {
    String displayText;

    switch (messageType.toLowerCase()) {
      case 'text':
        displayText = messageContent;
        break;
      case 'image':
        displayText = 'Image';
        break;
      case 'video':
        displayText = 'Video';
        break;
      case 'document':
      case 'doc':
      case 'pdf':
        displayText = 'Document';
        break;
      case 'location':
        displayText = 'Location';
        break;
      case 'gif':
        displayText = 'gif';
        break;
      default:
        displayText = '';
    }

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: AppTypography.mediumText(context),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    return textPainter.size.width + 24; // 24 = padding
  }
}
