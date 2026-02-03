import 'package:stanchat/core/api/api_client.dart';
import 'package:stanchat/core/api/api_endpoint.dart';
import 'package:stanchat/featuers/language_method/data/model/lang_list_model.dart';
import 'package:stanchat/featuers/language_method/data/model/word_list_model.dart';
import 'package:stanchat/utils/logger.dart';

class LanguageRepository {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  LanguageRepository(this._apiClient);

  WordListModel? wordListModel;
  LanguageListModel? languageListModel;

  Future<LanguageListModel> langListRepo() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.getlanguage,
        method: 'POST',
        body: {},
      );

      _logger.i("Language List Get");
      return languageListModel = LanguageListModel.fromJson(response);
    } catch (e) {
      _logger.e('Error get language list:', e.toString());
      rethrow;
    }
  }

  Future<WordListModel> wordListRepo({required String languageId}) async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.worldList,
        method: 'POST',
        body: {'language_id': languageId},
      );

      _logger.i("Language word List Get");
      return wordListModel = WordListModel.fromJson(response);
    } catch (e) {
      _logger.e('Error get language word list:', e.toString());
      rethrow;
    }
  }
}
