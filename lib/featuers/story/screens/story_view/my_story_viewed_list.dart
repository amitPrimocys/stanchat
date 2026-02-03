import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:stanchat/featuers/story/provider/story_provider.dart';
import 'package:stanchat/utils/app_size_config.dart';
import 'package:stanchat/utils/packages/read_more/read_more_text.dart';
import 'package:stanchat/utils/packages/story/src/controller/flutter_story_controller.dart';
import 'package:stanchat/utils/preference_key/constant/app_assets.dart';
import 'package:stanchat/utils/preference_key/constant/app_colors.dart';
import 'package:stanchat/utils/preference_key/constant/app_text_style.dart';
import 'package:stanchat/utils/preference_key/constant/app_theme_manage.dart';
import 'package:stanchat/utils/preference_key/constant/strings.dart';
import 'package:stanchat/widgets/custom_bottomsheet.dart';
import 'package:stanchat/widgets/global.dart';

class MyStoryViewList extends StatelessWidget {
  const MyStoryViewList({
    super.key,
    required this.controller,
    required this.storycaption,
  });

  final FlutterStoryController controller;
  final String storycaption;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: SizeConfig.height(22),
        width: SizeConfig.screenWidth,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.6), // 👈 nice opacity
            ],
          ),
        ),
        child: Padding(
          padding: SizeConfig.getPaddingOnly(
            left: 15,
            right: 15,
            bottom: MediaQuery.of(context).padding.bottom + 10,
          ),
          child: Consumer<StoryProvider>(
            builder: (context, storyProvider, _) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    child: ReadMoreText(
                      storycaption,
                      trimLines: 2,
                      trimMode: TrimMode.Line,
                      trimExpandedText: "Read less",
                      trimCollapsedText: "Read more",
                      moreStyle: AppTypography.innerText12Mediu(
                        context,
                      ).copyWith(color: AppColors.appPriSecColor.primaryColor),
                      lessStyle: AppTypography.innerText12Mediu(
                        context,
                      ).copyWith(color: AppColors.appPriSecColor.primaryColor),
                      style: AppTypography.innerText12Mediu(
                        context,
                      ).copyWith(color: AppColors.white),
                    ),
                  ),
                  SizedBox(height: SizeConfig.height(1)),
                  storyProvider.viewedUserList.isEmpty
                      ? SizedBox.shrink()
                      : InkWell(
                        onTap: () async {
                          controller.pause();
                          await bottomSheetDesign(context, storyProvider);
                        },
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  AppAssets.eyeStory,
                                  height: SizeConfig.sizedBoxHeight(20),
                                  colorFilter: ColorFilter.mode(
                                    AppColors.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                SizedBox(width: SizeConfig.width(2)),
                                Text(
                                  storyProvider.viewedUserList.length
                                      .toString(),
                                  style: AppTypography.inputPlaceholderSmall(
                                    context,
                                  ).copyWith(
                                    fontFamily:
                                        AppTypography.fontFamily.poppins,
                                    color: AppColors.textColor.textWhiteColor,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.keyboard_arrow_up_outlined,
                              size: SizeConfig.sizedBoxHeight(30),
                              color: AppColors.white,
                            ),
                          ],
                        ),
                      ),
                  SizedBox(height: SizeConfig.height(1)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future bottomSheetDesign(BuildContext context, StoryProvider storyProvider) {
    return bottomSheetGobal(
      context,
      bottomsheetHeight: SizeConfig.sizedBoxHeight(350),
      title: AppString.storyStrings.viewedBy,
      insetPadding: SizeConfig.getPaddingSymmetric(
        horizontal: 20,
      ).copyWith(bottom: 10),
      child: ListView.separated(
        shrinkWrap: true,
        physics: AlwaysScrollableScrollPhysics(),
        scrollDirection: Axis.vertical,
        separatorBuilder: (context, index) {
          return Divider(color: AppThemeManage.appTheme.borderColor);
        },
        itemCount: storyProvider.viewedUserList.length,
        itemBuilder: (context, index) {
          final user = storyProvider.viewedUserList[index];
          return ListTile(
            contentPadding: SizeConfig.getPaddingSymmetric(horizontal: 10),
            dense: true,
            leading: Container(
              height: SizeConfig.sizedBoxHeight(40),
              width: SizeConfig.sizedBoxWidth(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: CachedNetworkImage(
                  imageUrl: user.profilePic.toString(),
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) =>
                          Image.asset(AppAssets.gpimage, fit: BoxFit.cover),
                ),
              ),
            ),
            title: Text(
              (user.userName != null && user.userName!.isNotEmpty)
                  ? user.userName.toString()
                  : user.fullName
                      .toString(), //"${user.firstName} ${user.lastName!}",
              style: AppTypography.h4(
                context,
              ).copyWith(fontSize: SizeConfig.getFontSize(14)),
            ),
            subtitle: Text(
              formatTimeAgo(user.viewedAt!),
              style: AppTypography.smallText(context).copyWith(
                color: AppColors.textColor.textGreyColor,
                fontSize: SizeConfig.getFontSize(11),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      controller.play();
    });
  }
}
