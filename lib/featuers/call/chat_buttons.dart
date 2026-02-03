import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:stanchat/featuers/call/call_model.dart';
import 'package:stanchat/featuers/call/call_provider.dart';
import 'package:stanchat/featuers/call/call_ui.dart';
import 'package:stanchat/utils/app_size_config.dart';
import 'package:stanchat/utils/preference_key/constant/app_assets.dart';
import 'package:stanchat/utils/preference_key/constant/app_theme_manage.dart';

class ChatCallButtons extends StatelessWidget {
  final int chatId;
  final String chatName;
  final String? profilePic;
  final int? userId; // Fallback when chatId is 0 (no existing chat)

  const ChatCallButtons({
    super.key,
    required this.chatId,
    required this.chatName,
    this.profilePic,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, provider, child) {
        // Don't show buttons if already in a call
        if (provider.isInCall) {
          return SizedBox.shrink();
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // // Audio call button
            // IconButton(
            //   padding: EdgeInsets.zero,
            //   constraints: BoxConstraints(),
            //   icon: SvgPicture.asset(
            //     AppAssets.bottomNavIcons.call1,
            //     height: SizeConfig.sizedBoxHeight(20),
            //   ),
            //   onPressed: () => _makeCall(context, CallType.audio),
            //   tooltip: 'Audio Call',
            //   style: ButtonStyle(
            //     padding: WidgetStateProperty.all(EdgeInsets.zero),
            //   ),
            // ),

            // // Video call button
            // IconButton(
            //   padding: EdgeInsets.zero,
            //   constraints: BoxConstraints(),
            //   icon: SvgPicture.asset(
            //     AppAssets.groupProfielIcons.video,
            //     height: SizeConfig.sizedBoxHeight(20),
            //   ),
            //   onPressed: () => _makeCall(context, CallType.video),
            //   tooltip: 'Video Call',
            //   style: ButtonStyle(
            //     padding: WidgetStateProperty.all(EdgeInsets.zero),
            //   ),
            // ),
            SizedBox(width: SizeConfig.width(3)),
            // Audio call button
            Tooltip(
              message: 'Audio Call',
              child: GestureDetector(
                onTap: () => _makeCall(context, CallType.audio),
                child: SvgPicture.asset(
                  AppAssets.bottomNavIcons.call1,
                  colorFilter: ColorFilter.mode(
                    AppThemeManage.appTheme.darkWhiteColor,
                    BlendMode.srcIn,
                  ),
                  height: SizeConfig.sizedBoxHeight(20),
                ),
              ),
            ),

            SizedBox(width: SizeConfig.width(5)),
            // Video call button
            Tooltip(
              message: 'Video Call',
              child: GestureDetector(
                onTap: () => _makeCall(context, CallType.video),
                child: SvgPicture.asset(
                  AppAssets.groupProfielIcons.video,
                  colorFilter: ColorFilter.mode(
                    AppThemeManage.appTheme.darkWhiteColor,
                    BlendMode.srcIn,
                  ),
                  height: SizeConfig.sizedBoxHeight(20),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _makeCall(BuildContext context, CallType callType) {
    // CRITICAL FIX: When chatId is 0 (no existing chat), pass userId as peerId
    // This allows the API to receive peer_id for new chats without chat history
    final int? peerId = (chatId == 0 && userId != null) ? userId : null;

    debugPrint(
      '📞 ChatCallButtons._makeCall: chatId=$chatId, userId=$userId, peerId=$peerId',
    );

    // Ensure we have either a valid chatId or userId
    if (chatId == 0 && userId == null) {
      debugPrint(
        '⚠️ ChatCallButtons: Cannot make call - both chatId and userId are 0 or null',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to make call. Please try again.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => CallScreen(
              chatId: chatId,
              chatName: chatName,
              callType: callType,
              isIncoming: false,
              peerId: peerId, // Pass peerId when chatId is 0
            ),
        fullscreenDialog: true,
      ),
    );
  }
}
