import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/call/call_history/models/call_history_model.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/widgets/global.dart';

class CallHistoryRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  CallHistoryRepository(this._apiClient);

  //=============================================================================================================================
  //===================================================== Get Call History method =============================================
  //=============================================================================================================================
  Future<CallHistoryResponse> getCallHistory({int page = 1}) async {
    _logger.i('Fetching call history for user: $userID, page: $page');
    try {
      final response = await _apiClient.request(
        ApiEndpoints.callHistory,
        method: 'POST',
        body: {'user_id': userID, 'page': page},
      );

      _logger.i('Call history fetched successfully for page $page');
      _logger.d('Response structure: $response');
      return CallHistoryResponse.fromJson(response);
    } catch (e) {
      _logger.e('Error fetching call history:', e.toString());
      rethrow;
    }
  }
}
