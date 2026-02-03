import 'package:flutter/material.dart';
import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';

class ContactListItem extends StatelessWidget {
  final ContactModel contact;
  final bool isChat;
  final VoidCallback onTap;
  final bool isSelected;
  final Widget? trailing; // ✅ ENHANCED: Trailing widget support
  final bool isForHorizontalView;

  const ContactListItem({
    super.key,
    required this.contact,
    required this.isChat,
    required this.onTap,

    this.isSelected = false,
    this.isForHorizontalView = false,
    this.trailing, // ✅ ENHANCED: Optional trailing widget
  });

  @override
  Widget build(BuildContext context) {
    return isForHorizontalView
        ? Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildAvatar(),
                Positioned(
                  top: -3,
                  right: -3,
                  child: InkWell(
                    onTap: onTap,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.appPriSecColor.secondaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemeManage.appTheme.whiteBlck,
                          width: 1.1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 11,
                          color: ThemeColorPalette.getTextColor(
                            AppColors.appPriSecColor.primaryColor,
                          ), //AppColors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 3),
            _getContactName(context),
          ],
        )
        : Container(
          decoration: BoxDecoration(
            color:
                // isSelected
                //     ? AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.05)
                //     :
                Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Contact Avatar with selection indicator
                  _buildAvatar(),
                  const SizedBox(width: 12),
                  // Contact Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _getContactName(context),
                        const SizedBox(height: 4),
                        Text(
                          contact.formattedPhoneNumber,
                          style: AppTypography.smallText(context).copyWith(
                            color: AppColors.textColor.textDarkGray,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // ✅ ENHANCED: Show trailing widget if provided, otherwise show action button
                  trailing != null ? trailing! : _buildActionButton(context),
                ],
              ),
            ),
          ),
        );
  }

  Widget _getContactName(BuildContext context) {
    return SizedBox(
      width: isForHorizontalView ? SizeConfig.width(19) : null,
      child: Text(
        contact.name,
        style:
            isForHorizontalView
                ? AppTypography.text12(context)
                : AppTypography.h5(
                  context,
                ).copyWith(fontWeight: FontWeight.w500),
        textAlign: isForHorizontalView ? TextAlign.center : null,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        _buildCircleAvatar(),
        // Selection indicator
        // if (isSelected)
        //   Positioned(
        //     right: 0,
        //     bottom: 0,
        //     child: Container(
        //       padding: const EdgeInsets.all(2),
        //       decoration: BoxDecoration(
        //         color: AppColors.appPriSecColor.primaryColor,
        //         shape: BoxShape.circle,
        //         border: Border.all(color: Colors.white, width: 2),
        //       ),
        //       child: const Icon(Icons.check, color: Colors.white, size: 12),
        //     ),
        //   ),
      ],
    );
  }

  Widget _buildCircleAvatar() {
    // Check if we have a backend profile picture URL
    if (contact.profilePicUrl != null && contact.profilePicUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: isForHorizontalView ? 20 : 24,
        backgroundColor: AppColors.textColor.textDarkGray,
        child: ClipOval(
          child: Image.network(
            contact.profilePicUrl!,
            width: (isForHorizontalView ? 20 : 24) * 2,
            height: (isForHorizontalView ? 20 : 24) * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // If image fails to load, show initials
              debugPrint(
                'Error loading profile image for ${contact.name}: $error',
              );
              return _buildInitialsAvatar();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              // Show initials while loading
              return _buildInitialsAvatar();
            },
          ),
        ),
      );
    }

    // Fallback to initials avatar
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    return CircleAvatar(
      radius: isForHorizontalView ? 20 : 24,
      backgroundColor: AppColors.textColor.textDarkGray,
      child: Text(
        contact.initials,
        style: TextStyle(
          color: AppColors.textColor.textWhiteColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (isChat) {
      // For chat contacts, show message icon or selection checkbox
      return isSelected
          ? Container(
            decoration: BoxDecoration(
              color: AppColors.appPriSecColor.secondaryColor,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(3),
              child: Icon(
                Icons.check_rounded,
                color: ThemeColorPalette.getTextColor(
                  AppColors.appPriSecColor.primaryColor,
                ), //AppColors.black,
                size: 18,
              ),
            ),
          )
          : Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.appPriSecColor.secondaryColor,
                width: 1.5,
              ),
              color: Colors.transparent,

              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.check_rounded,
                color: Colors.transparent,
                size: 18,
              ),
            ),
          );
      // IconButton(
      //   icon: Icon(
      //     Icons.chat_bubble_outline,
      //     color: AppColors.appPriSecColor.primaryColor,
      //   ),
      //   onPressed: onTap,
      // );
    } else {
      // For invite contacts, show invite button
      return TextButton(
        onPressed: onTap,
        child: Text(
          'Invite',
          style: AppTypography.mediumText(
            context,
          ).copyWith(color: AppColors.appPriSecColor.primaryColor),
        ),
      );
    }
  }
}
