// ignore_for_file: constant_identifier_names
import 'package:stanchat/utils/preference_key/sharedpref_key.dart';
import 'package:stanchat/widgets/global.dart';

class SecureStorageKeys {
  static const String TOKEN = "TOKEN";
  static const String USERID = "USERID";
  static const String USER_NAME = "USER_NAME";
  static const String FIRST_NAME = "FIRST_NAME";
  static const String LAST_NAME = "LAST_NAME";
  static const String GENDER = "GENDER";
  static const String COUNTRY_CODE = "COUNTRY_CODE";
  static const String MOBILE_NUM = "MOBILE_NUM";
  static const String COUNTRY_NAME = "COUNTRY_NAME";
  static const String COUNTRY_SHORT_NAME = "COUNTRY_SHORT_NAME";
  static const String EMAIL = "EMAIL";
  static const String STATUSBIO = "STATUSBIO";
  static const String TYPE = "TYPE";
  static const String PERMISSION = "PERMISSION"; // Change this to String
  static const String APP_VERSION = "APP_VERSION";
  static const String USER_PROFILE = "USER_PROFILE";
  static const String IS_PHONE_AUTH = "IS_PHONE_AUTH";
  static const String IS_EMAIL_AUTH = "IS_EMAIL_AUTH";
  static const String APP_LOGO = "APP_LOGO";
  static const String APP_LOGO_DARK = "APP_LOGO_DARK";
  static const String APP_NAME = "APP_NAME";
  static const String LANG_ID = "LANG_ID";
  static const String textDirection = "textDirection";
  static const isLightMode = 'isLightMode';
  static const String customThemeColor = 'customThemeColor';
  static const String IS_DEMO = "IS_DEMO";
  static const String PROJECT_CONFIG =
      "PROJECT_CONFIG"; // ✅ Cache for project configuration
  static const String DEMO_CREDENTIAL = "DEMO_CREDENTIAL";

  // Contact sync data (stores timestamp + contacts snapshot for diff detection)
  static const String CONTACT_SYNC_DATA = "CONTACT_SYNC_DATA";

  // Cached registered contacts from get-contacts API (for instant UI load)
  static const String CACHED_CONTACTS = "CACHED_CONTACTS";

  Map<String, void Function(String)> prefSetters = {
    TOKEN: (val) => authToken = val,
    USERID: (val) => userID = val,
    USER_NAME: (val) => userName = val,
    FIRST_NAME: (val) => firstName = val,
    LAST_NAME: (val) => lastName = val,
    GENDER: (val) => gender = val,
    COUNTRY_CODE: (val) => contrycode = val,
    MOBILE_NUM: (val) => mobileNum = val,
    COUNTRY_NAME: (val) => country = val,
    COUNTRY_SHORT_NAME: (val) => countryShortName = val,
    EMAIL: (val) => email = val,
    STATUSBIO: (val) => bio = val,
    TYPE: (val) => loginType = val,
    USER_PROFILE: (val) => userProfile = val,
    LANG_ID: (val) => langID = val,
    textDirection: (val) => userTextDirection = val,
  };

  Map<String, void Function(bool)> isPhoneEmailSetter = {
    IS_PHONE_AUTH: (val) => isPhoneAuthEnabled = val,
    IS_EMAIL_AUTH: (val) => isEmailAuthEnabled = val,
    IS_DEMO: (val) => isDemo = val,
  };

  Future<void> loadeBoolValuePrefes() async {
    for (final entry in isPhoneEmailSetter.entries) {
      final value = await SecurePrefs.getBool(entry.key);
      entry.value(value);
    }
  }

  Future<void> loadUserFromPrefs() async {
    for (final entry in prefSetters.entries) {
      final value = await SecurePrefs.getString(entry.key) ?? "";
      entry.value(value);
    }
    // ✅ FIXED: Load permission from SecureStorage as boolean (outside the loop)
    permission = await SecurePrefs.getBool(SecureStorageKeys.PERMISSION);
  }

  // Function to check permission and update SecureStorage
  static Future<void> checkPermissionStatus() async {
    // Assuming you've already requested the necessary permissions
    // (e.g. camera, location, etc.) through the native code or Flutter packages.

    // Simulate a permission check for illustration purposes:
    bool isPermissionGranted = await checkIfPermissionGranted();

    // Update the permission in secure storage
    await SecurePrefs.setBool(
      SecureStorageKeys.PERMISSION,
      isPermissionGranted,
    );

    // Update the global variable based on permission status
    permission = isPermissionGranted;
  }

  // Simulated permission check (you would replace this with actual permission checking logic)
  static Future<bool> checkIfPermissionGranted() async {
    // Example: Check if permission is granted (You can replace this with actual logic like permission_handler package)
    return true; // Simulating granted permission
  }
}
