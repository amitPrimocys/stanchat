import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stanchat/utils/app_size_config.dart';
import 'package:stanchat/utils/preference_key/constant/app_assets.dart';
import 'package:stanchat/utils/preference_key/constant/app_colors.dart';
import 'package:stanchat/utils/preference_key/constant/app_text_style.dart';
import 'package:stanchat/widgets/global.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.userName,
    required this.userProfile,
    required this.fName,
    required this.lName,
    required this.isMyStory,
    required this.storyTime,
    required this.onPauseRequested,
  });
  final String userName;
  final String userProfile;
  final String fName;
  final String lName;
  final bool isMyStory;
  final String storyTime;
  final VoidCallback onPauseRequested;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30, left: 15, right: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(1),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: userProfile,
                    errorWidget: (context, url, error) {
                      return Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: SvgPicture.asset(
                          AppAssets.settingsIcosn.profile,
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            AppColors.appPriSecColor.primaryColor,
                            BlendMode.srcIn,
                          ),
                        ),
                      );
                    },
                    height: 35,
                    width: 35,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: AppTypography.innerText14(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor.textWhiteColor,
                    ),
                  ),
                  Text(
                    formatStoryTime(storyTime),
                    style: AppTypography.innerText10(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textColor.textDarkGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
          isMyStory
              ? InkWell(
                onTap: () {
                  onPauseRequested();
                },
                child: Icon(
                  Icons.more_horiz,
                  size: SizeConfig.sizedBoxHeight(25),
                  color: AppColors.white,
                ),
              )
              : SizedBox.shrink(),
        ],
      ),
    );
  }
}
