import 'package:dio/dio.dart';
import 'package:stanchat/core/api/api_client.dart';
import 'package:stanchat/core/api/api_endpoint.dart';
import 'package:stanchat/featuers/report/data/models/report_types_model.dart';
import 'package:stanchat/featuers/report/data/models/report_response_model.dart';

class ReportRepository {
  final ApiClient _apiClient;

  ReportRepository(this._apiClient);

  Future<ReportTypesResponse> getReportTypes() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.reportTypes,
        method: 'POST',
      );
      return ReportTypesResponse.fromJson(response);
    } on DioException catch (e) {
      throw Exception('Failed to get report types: ${e.message}');
    } catch (e) {
      throw Exception('Failed to get report types: $e');
    }
  }

  Future<ReportResponse> reportUser({
    required int userId,
    required int reportTypeId,
    int? groupId,
  }) async {
    try {
      final reportRequest = ReportUserRequest(
        userId: userId,
        reportTypeId: reportTypeId,
        groupId: groupId,
      );

      final response = await _apiClient.request(
        ApiEndpoints.reportUser,
        method: 'POST',
        body: reportRequest.toJson(),
      );

      return ReportResponse.fromJson(response);
    } on DioException catch (e) {
      throw Exception('Failed to report user: ${e.message}');
    } catch (e) {
      throw Exception('Failed to report user: $e');
    }
  }
}
