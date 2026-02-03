import 'package:flutter/material.dart';
import 'package:stanchat/core/error/app_error.dart';
import 'package:stanchat/featuers/language_method/data/model/lang_list_model.dart'
    as langlist;
import 'package:stanchat/featuers/language_method/data/model/word_list_model.dart'
    as word_list;
import 'package:stanchat/featuers/language_method/data/repository/language_repo.dart';
import 'package:stanchat/utils/logger.dart';
import 'package:stanchat/utils/preference_key/preference_key.dart';
import 'package:stanchat/utils/preference_key/sharedpref_key.dart';
import 'package:stanchat/widgets/global.dart';

class LanguageProvider extends ChangeNotifier {
  LanguageProvider(this.languageRepository);
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  final LanguageRepository languageRepository;
  bool _isLanguagLoading = false;
  bool _isGetLanguagsLoading = false;
  String? _errorMessage;

  bool get isLanguagLoading => _isLanguagLoading;
  bool get isGetLanguagsLoading => _isGetLanguagsLoading;

  String? get errorMessage => _errorMessage;

  TextDirection currentDirection = TextDirection.ltr;

  void loadTextDirection() async {
    String? savedDirection = await SecurePrefs.getString(
      SecureStorageKeys.textDirection,
    );
    userTextDirection = savedDirection ?? "LTR";
    currentDirection =
        userTextDirection == "RTL" ? TextDirection.rtl : TextDirection.ltr;
  }

  void notify() {
    notifyListeners();
  }

  List<langlist.Records> languageListData = <langlist.Records>[];
  Future<void> languageListApi() async {
    try {
      _isLanguagLoading = true;
      _errorMessage = null;
      notify();

      final result = await languageRepository.langListRepo();
      languageListData.clear();
      if (result.status == true) {
        languageListData.addAll(result.data!.records);
      } else {
        _errorMessage = result.message;
      }
      _isLanguagLoading = false;
      notify();
    } on AppError catch (e) {
      _isLanguagLoading = false;
      _errorMessage = e.message;
      notify();
    } catch (e) {
      _isLanguagLoading = false;
      _errorMessage = 'Unexpected error occurred';
      _logger.i('Error loading features: $e');
      notify();
    }
  }

  List<word_list.Records> wordListData = <word_list.Records>[];
  Future<bool> wordListApi({required String languageId}) async {
    try {
      _isGetLanguagsLoading = true;
      _errorMessage = null;
      notify();

      final result = await languageRepository.wordListRepo(
        languageId: languageId,
      );
      wordListData.clear();
      if (result.status == true) {
        wordListData.addAll(result.data!.records!);
        _errorMessage = result.message;
        _isGetLanguagsLoading = false;
        notify();
        return true;
      } else {
        _errorMessage = result.message;
        _isGetLanguagsLoading = false;
        notify();
        return false;
      }
    } on AppError catch (e) {
      _isGetLanguagsLoading = false;
      _errorMessage = e.message;
      notify();
      return false;
    } catch (e) {
      _isGetLanguagsLoading = false;
      _errorMessage = 'Unexpected error occurred';
      _logger.i('Error loading features: $e');
      notify();
      return false;
    }
  }

  String textTranslate(String text) {
    return wordListData.isEmpty
        ? text
        : wordListData.where((element) => element.key == text).isEmpty
        ? text
        : wordListData
                .where((element) => element.key == text)
                .first
                .translation ==
            null
        ? text
        : wordListData
            .where((element) => element.key == text)
            .first
            .translation!;
  }

  void fetchLangData() async {
    await languageListApi();
    if (langID.isNotEmpty) {
      await wordListApi(languageId: langID);
    } else {
      // await wordListApi(
      //   languageId:
      //       languageListData
      //           .firstWhere((element) => element.language == "English")
      //           .languageId
      //           .toString(),
      // );
    }
  }

  void loginDeleteTineUse() async {
    final languageId =
        languageListData
            .firstWhere((element) => element.language == "English")
            .languageId
            .toString();

    await SecurePrefs.setString(SecureStorageKeys.LANG_ID, languageId);
    String? langD = (await SecurePrefs.getString(SecureStorageKeys.LANG_ID))!;
    langID = langD;

    currentDirection =
        languageListData
                    .firstWhere((element) => element.language == "English")
                    .languageAlignment ==
                'RTL'
            ? TextDirection.rtl
            : TextDirection.ltr;
    await SecurePrefs.setString(
      SecureStorageKeys.textDirection,
      currentDirection == TextDirection.rtl ? "RTL" : "LTR",
    );
    String? direction =
        (await SecurePrefs.getString(SecureStorageKeys.textDirection))!;

    userTextDirection = direction;
  }
}
