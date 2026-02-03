import 'package:flutter/material.dart';
import 'package:stanchat/featuers/report/data/models/report_types_model.dart';
import 'package:stanchat/featuers/report/data/repositories/report_repository.dart';

class ReportProvider extends ChangeNotifier {
  final ReportRepository _reportRepository;

  ReportProvider(this._reportRepository);

  List<ReportType> _reportTypes = [];
  bool _isLoadingReportTypes = false;
  bool _isSubmittingReport = false;
  String _errorMessage = '';
  String _successMessage = '';

  List<ReportType> get reportTypes => _reportTypes;
  bool get isLoadingReportTypes => _isLoadingReportTypes;
  bool get isSubmittingReport => _isSubmittingReport;
  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;

  Future<void> fetchReportTypes() async {
    _isLoadingReportTypes = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await _reportRepository.getReportTypes();
      if (response.status) {
        _reportTypes = response.data.reportTypes;
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingReportTypes = false;
      notifyListeners();
    }
  }

  Future<bool> reportUser({
    required int userId,
    required int reportTypeId,
    int? groupId,
  }) async {
    _isSubmittingReport = true;
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();

    try {
      final response = await _reportRepository.reportUser(
        userId: userId,
        groupId: groupId,
        reportTypeId: reportTypeId,
      );

      if (response.status) {
        _successMessage = response.message;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isSubmittingReport = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();
  }
}
