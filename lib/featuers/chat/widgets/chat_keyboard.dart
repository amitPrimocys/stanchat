import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:stanchat/utils/app_size_config.dart';
import 'package:stanchat/utils/preference_key/constant/app_assets.dart';
import 'package:stanchat/utils/preference_key/constant/app_colors.dart';
import 'package:stanchat/utils/preference_key/constant/app_text_style.dart';
import 'package:stanchat/utils/preference_key/constant/app_theme_manage.dart';
import 'package:stanchat/utils/preference_key/constant/strings.dart';
import 'package:stanchat/widgets/global.dart';

class ChatKeyboard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final Function() onTapSendMsg;
  final Function() onTapVoiceRecordOpen;
  final Function() onTapPin;
  final Function() onTapCamera;
  final Function(String)? onChanged;
  final Function()? onTap;
  final bool isLoading;

  const ChatKeyboard({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onTapSendMsg,
    required this.onTapVoiceRecordOpen,
    required this.onTapPin,
    required this.onTapCamera,
    this.onChanged,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SizeConfig.sizedBoxHeight(75),
      color: AppThemeManage.appTheme.darkGreyColor,
      child: Padding(
        padding: SizeConfig.getPaddingOnly(left: 15, right: 15, bottom: 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                onEditingComplete: () {
                  FocusScope.of(context).requestFocus(focusNode);
                },
                onChanged: onChanged,
                onTap: onTap,
                maxLines: 2,
                style: AppTypography.smallText(context).copyWith(
                  color:
                      isURL(controller.text.trim())
                          ? Colors.blueAccent
                          : AppThemeManage.appTheme.darkWhiteColor,
                ),
                minLines: 1,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                focusNode: focusNode,
                readOnly: isLoading ? true : false,
                decoration: InputDecoration(
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  fillColor: AppColors.transparent,
                  filled: true,
                  hintText: AppString.typeMessage,
                  hintStyle: AppTypography.smallText(
                    context,
                  ).copyWith(color: AppColors.textColor.textGreyColor),
                  suffixIcon: Padding(
                    padding: SizeConfig.getPaddingOnly(left: 13, right: 13),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          color: AppColors.transparent,
                          child: Padding(
                            padding: SizeConfig.getPaddingOnly(
                              left: 10,
                              bottom: 2,
                              top: 2,
                            ),
                            child: InkWell(
                              onTap: onTapPin,
                              child: Image.asset(
                                AppAssets.pin,
                                scale: 3.5,
                                color: AppThemeManage.appTheme.pinColor,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: SizeConfig.sizedBoxWidth(10)),
                        Container(
                          color: AppColors.transparent,
                          child: Padding(
                            padding: SizeConfig.getPaddingOnly(
                              left: 5,
                              bottom: 2,
                              top: 2,
                            ),
                            child: InkWell(
                              onTap: onTapCamera,
                              child: Image.asset(
                                AppAssets.camera,
                                scale: 3.5,
                                color: AppThemeManage.appTheme.pinColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(
                      color: AppThemeManage.appTheme.borderColor,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(
                      color: AppThemeManage.appTheme.borderColor,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(
                      color: AppColors.textColor.textErrorColor1,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(
                      color: AppColors.textColor.textErrorColor1,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: SizeConfig.sizedBoxWidth(13)),
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return hasText
                    ? InkWell(
                      onTap: isLoading ? null : onTapSendMsg,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.appPriSecColor.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          child:
                              isLoading
                                  ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: ThemeColorPalette.getTextColor(
                                        AppColors.appPriSecColor.primaryColor,
                                      ), //AppThemeManage.appTheme.darkWhiteColor,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Image.asset(
                                    AppAssets.send,
                                    color: ThemeColorPalette.getTextColor(
                                      AppColors.appPriSecColor.primaryColor,
                                    ), //AppThemeManage.appTheme.darkWhiteColor,
                                    height: SizeConfig.sizedBoxHeight(24),
                                    width: SizeConfig.sizedBoxWidth(24),
                                  ),
                        ),
                      ),
                    )
                    : InkWell(
                      onTap: onTapVoiceRecordOpen,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.appPriSecColor.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: SizeConfig.getPaddingSymmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          child:
                              isLoading
                                  ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: ThemeColorPalette.getTextColor(
                                        AppColors.appPriSecColor.primaryColor,
                                      ), //AppThemeManage.appTheme.darkWhiteColor,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : SvgPicture.asset(
                                    "assets/images/call/microphone-on.svg",
                                    color: ThemeColorPalette.getTextColor(
                                      AppColors.appPriSecColor.primaryColor,
                                    ), //AppThemeManage.appTheme.darkWhiteColor,
                                    height: SizeConfig.sizedBoxHeight(24),
                                    width: SizeConfig.sizedBoxWidth(24),
                                  ),
                        ),
                      ),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}
