import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stanchat/featuers/report/data/models/report_types_model.dart';
import 'package:stanchat/featuers/report/provider/report_provider.dart';
import 'package:stanchat/utils/app_size_config.dart';
import 'package:stanchat/utils/preference_key/constant/app_colors.dart';
import 'package:stanchat/utils/preference_key/constant/app_text_style.dart';
import 'package:stanchat/utils/preference_key/constant/app_theme_manage.dart';
import 'package:stanchat/utils/preference_key/constant/strings.dart';
import 'package:stanchat/widgets/custom_bottomsheet.dart';
import 'package:stanchat/widgets/global.dart';

class ReportUserDialog extends StatefulWidget {
  final int userId;
  final int? groupId;
  final String userName;

  const ReportUserDialog({
    super.key,
    required this.userId,
    this.groupId,
    required this.userName,
  });

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  ReportType? selectedReportType;
  int? loadingIndex;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().fetchReportTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, reportProvider, child) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: SizeConfig.height(1)),
              if (reportProvider.isLoadingReportTypes)
                Column(
                  children: [
                    SizedBox(height: SizeConfig.height(15)),
                    commonLoading(),
                  ],
                )
              else if (reportProvider.errorMessage.isNotEmpty)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reportProvider.errorMessage,
                          style: TextStyle(color: Colors.red[600]),
                        ),
                      ),
                    ],
                  ),
                )
              else if (reportProvider.reportTypes.isEmpty)
                Column(
                  children: [
                    SizedBox(height: SizeConfig.height(15)),
                    Text(
                      AppString.reportNotAvailable,
                      style: AppTypography.innerText14(context),
                    ),
                  ],
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reportProvider.reportTypes.length,
                  itemBuilder: (context, index) {
                    final reportType = reportProvider.reportTypes[index];
                    final isLoading = loadingIndex == index;
                    return InkWell(
                      onTap: () async {
                        setState(() {
                          selectedReportType = reportType;
                          loadingIndex = index;
                          log(
                            "selectedReportType: ${selectedReportType?.reportText}",
                          );
                        });
                        if (selectedReportType != null &&
                            !reportProvider.isSubmittingReport) {
                          await _submitReport(context, reportProvider);
                        }
                        if (context.mounted) {
                          setState(() {
                            loadingIndex = null;
                          });
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              isLoading
                                  ? AppThemeManage.appTheme.borderColor
                                  : AppColors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  (index <
                                          reportProvider.reportTypes.length - 1)
                                      ? AppThemeManage.appTheme.borderColor
                                      : AppColors.transparent,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12.0,
                            horizontal: 20,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                reportType.reportText,
                                style: AppTypography.innerText12Mediu(
                                  context,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(
                                height: 15,
                                width: 15,
                                child:
                                    isLoading
                                        ? commonLoading2()
                                        : SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitReport(
    BuildContext context,
    ReportProvider reportProvider,
  ) async {
    if (selectedReportType == null) return;

    final success = await reportProvider.reportUser(
      userId: widget.userId,
      groupId: widget.groupId,
      reportTypeId: selectedReportType!.reportTypeId,
    );

    if (success) {
      Future.delayed(const Duration(seconds: 1), () {
        if (context.mounted) {
          Navigator.of(context).pop();
          snackbarNew(context, msg: AppString.yourReportSubmitted);
        }
      });
    }
  }
}

void showReportUserDialog(
  BuildContext context, {
  required int userId,
  required String userName,
}) {
  bottomSheetGobal(
    context,
    bottomsheetHeight: SizeConfig.sizedBoxHeight(350),
    borderRadius: BorderRadius.circular(20),
    title: AppString.reportString.reportAccount,
    child: ReportUserDialog(userId: userId, userName: userName),
  );
  // showDialog(
  //   context: context,
  //   builder: (context) => ReportUserDialog(userId: userId, userName: userName),
  // );
}
