// ignore_for_file: deprecated_member_use
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/story/provider/story_provider.dart';
import 'package:whoxa/featuers/story/screens/video_play.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/global.dart';

class StoryUpload extends StatefulWidget {
  const StoryUpload({super.key});

  @override
  State<StoryUpload> createState() => _StoryUploadState();
}

class _StoryUploadState extends State<StoryUpload> {
  FocusNode typeNode = FocusNode();

  Offset cropTopLeft = Offset(50, 50);
  Offset cropBottomRight = Offset(250, 250);

  String caption = '';

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final storyProvider = Provider.of<StoryProvider>(
          context,
          listen: false,
        );
        storyProvider.selectedMediaFile = null;
        storyProvider.selectedMediaType = null;
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          leading: Padding(
            padding: const EdgeInsets.all(16.0),
            child: customeBackArrowBalck(context, color: AppColors.white),
          ),
        ),
        body: Consumer<StoryProvider>(
          builder: (context, storyProvider, _) {
            final file = storyProvider.selectedMediaFile;
            final type = storyProvider.selectedMediaType;
            return Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (file != null && type == 'image')
                        Image.file(file)
                      else if (file != null && type == 'video')
                        SizedBox(
                          height: SizeConfig.sizedBoxHeight(500),
                          width: MediaQuery.sizeOf(context).width,
                          child: VideoPreview(videoFile: file),
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: SizeConfig.sizedBoxHeight(90),
                    color: AppColors.black,
                    child: Padding(
                      padding: SizeConfig.getPaddingOnly(
                        left: 15,
                        right: 15,
                        bottom: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: storyProvider.typeMessageCtrl,
                              onEditingComplete: () {
                                FocusScope.of(context).requestFocus(typeNode);
                              },
                              onTap: () {},
                              maxLines: 2,
                              minLines: 1,
                              textInputAction: TextInputAction.newline,
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.multiline,
                              style: AppTypography.smallText(context).copyWith(
                                color: AppColors.textColor.textWhiteColor,
                              ),
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(255),
                              ],
                              focusNode: typeNode,
                              decoration: InputDecoration(
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                fillColor: AppColors.transparent,
                                filled: true,
                                hintText: AppString.storyStrings.addCaption,
                                hintStyle: AppTypography.smallText(
                                  context,
                                ).copyWith(
                                  color: AppColors.textColor.textWhiteColor,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(
                                    color: AppColors.strokeColor.c1A1919,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(
                                    color: AppColors.strokeColor.c1A1919,
                                  ),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide.none,
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(
                                    color: AppColors.textColor.textErrorColor1,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(
                                    color: AppColors.textColor.textErrorColor1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: SizeConfig.sizedBoxWidth(13)),
                          InkWell(
                            onTap: () async {
                              closeKeyboard();
                              if (storyProvider
                                  .typeMessageCtrl
                                  .text
                                  .isNotEmpty) {
                                if (!context.mounted) return;
                              }
                              final success = await storyProvider
                                  .storyUploadApi(
                                    type!,
                                    file!,
                                    storyProvider.typeMessageCtrl.text,
                                  );

                              if (success) {
                                storyProvider.typeMessageCtrl.clear();
                                if (!context.mounted) return;
                                log(storyProvider.errorMessage.toString());
                                await storyProvider.getAllStories();
                                if (!context.mounted) return;
                                Navigator.pop(context);
                              } else {
                                if (!context.mounted) return;
                                log(storyProvider.errorMessage.toString());
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.gradientColor.gradientColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: SizeConfig.getPaddingSymmetric(
                                  horizontal: 13,
                                  vertical: 11,
                                ),
                                child:
                                    storyProvider.isLoading
                                        ? SizedBox(
                                          height: SizeConfig.sizedBoxHeight(25),
                                          width: SizeConfig.sizedBoxWidth(25),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1,
                                            color: AppColors.black,
                                          ),
                                        )
                                        : Image.asset(
                                          AppAssets.send,
                                          color: AppColors.black,
                                          height: SizeConfig.sizedBoxHeight(24),
                                          width: SizeConfig.sizedBoxWidth(24),
                                        ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
