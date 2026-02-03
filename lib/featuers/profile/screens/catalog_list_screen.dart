import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';
import 'package:whoxa/featuers/profile/screens/catalog_detail_screen.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';

class CatalogListScreen extends StatelessWidget {
  final List<Catalog> catalogs;
  final String businessName;

  const CatalogListScreen({
    super.key,
    required this.catalogs,
    required this.businessName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
      appBar: AppBar(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: AppThemeManage.appTheme.darkWhiteColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$businessName ${AppString.catalog}',
          style: AppTypography.h5(context).copyWith(
            color: AppThemeManage.appTheme.textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body:
          catalogs.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: catalogs.length,
                itemBuilder: (context, index) {
                  final catalog = catalogs[index];
                  return _buildCatalogCard(context, catalog);
                },
              ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: AppThemeManage.appTheme.textGreyWhite,
            ),
            SizedBox(height: 16),
            Text(
              AppString.noCatalogItemAvailable, //'No Catalogs Available',
              style: AppTypography.h4(context).copyWith(
                fontWeight: FontWeight.w600,
                color: AppThemeManage.appTheme.textColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              AppString
                  .thisBusinessHasnt, //'This business hasn\'t added any catalog items yet.',
              textAlign: TextAlign.center,
              style: AppTypography.innerText14(context).copyWith(
                color: AppThemeManage.appTheme.textGreyWhite,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogCard(BuildContext context, Catalog catalog) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppThemeManage.appTheme.darkGreyColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
            color: AppColors.shadowColor.c000000.withValues(alpha: 0.1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToCatalogDetail(context, catalog),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section
              _buildCardImage(catalog),

              SizedBox(width: 12),

              // Content section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Price Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Expanded(
                          child: Text(
                            catalog.title ?? 'No title',
                            style: AppTypography.innerText16(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.appPriSecColor.primaryColor,
                            ),
                          ),
                        ),

                        // Price
                        if (catalog.price != null && catalog.price! > 0)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.appPriSecColor.primaryColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '\$${catalog.price!.toStringAsFixed(catalog.price! % 1 == 0 ? 0 : 2)}',
                              style: AppTypography.innerText12Ragu(
                                context,
                              ).copyWith(
                                color: AppColors.appPriSecColor.primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: 8),

                    // Description
                    if (catalog.description?.isNotEmpty == true)
                      Text(
                        catalog.description!,
                        style: AppTypography.innerText12Ragu(context).copyWith(
                          color: AppThemeManage.appTheme.textGreyWhite,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                color: AppThemeManage.appTheme.textGreyWhite,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardImage(Catalog catalog) {
    final images = catalog.catalogImages ?? [];
    final imageUrl = images.isNotEmpty ? images.first.image : null;

    return Container(
      width: SizeConfig.width(25),
      height: SizeConfig.height(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppThemeManage.appTheme.greyBorder,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            imageUrl != null
                ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: SizeConfig.width(25),
                  height: SizeConfig.height(12),
                  placeholder:
                      (context, url) => Container(
                        color: AppThemeManage.appTheme.shimmerBaseColor,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.appPriSecColor.primaryColor,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        color: AppThemeManage.appTheme.shimmerBaseColor,
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: AppThemeManage.appTheme.textGreyWhite,
                            size: 24,
                          ),
                        ),
                      ),
                )
                : Container(
                  color: AppThemeManage.appTheme.shimmerBaseColor,
                  child: Center(
                    child: Icon(
                      Icons.inventory_2,
                      color: AppThemeManage.appTheme.textGreyWhite,
                      size: 24,
                    ),
                  ),
                ),
      ),
    );
  }

  void _navigateToCatalogDetail(BuildContext context, Catalog catalog) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CatalogDetailScreen(catalog: catalog),
      ),
    );
  }
}
