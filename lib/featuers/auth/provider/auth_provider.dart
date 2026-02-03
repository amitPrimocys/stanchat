// ignore_for_file: avoid_print, prefer_typing_uninitialized_variables

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/app_life_cycle.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/core/services/socket/socket_manager.dart';
import 'package:whoxa/core/services/socket/socket_service.dart';
import 'package:whoxa/dependency_injection.dart';
import 'package:whoxa/featuers/auth/data/repositories/login_repository.dart';
import 'package:whoxa/featuers/auth/data/models/avatar_model.dart';
import 'package:whoxa/featuers/auth/services/onesignal_service.dart';
import 'package:whoxa/featuers/contacts/provider/contact_provider.dart';
import 'package:whoxa/featuers/language_method/provider/language_provider.dart';
import 'package:whoxa/featuers/chat/utils/chat_cache_manager.dart'; // ✅ Import cache manager
import 'package:whoxa/utils/enums.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/packages/phone_field/countries.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart';

class AuthProvider extends ChangeNotifier {
  final ConsoleAppLogger _logger = ConsoleAppLogger();
  TextEditingController mobilecontroller = TextEditingController();
  TextEditingController emailcontroller = TextEditingController();
  TextEditingController otpController = TextEditingController();
  TextEditingController userNameController = TextEditingController();
  TextEditingController fNameController = TextEditingController();
  TextEditingController lNameController = TextEditingController();
  TextEditingController countryController = TextEditingController();

  String isSelected = '';
  String isSelectLoginType = loginType.isNotEmpty ? loginType : AppString.phone;

  bool isOtpValidationTriggered = false;

  String defaultSelectedCountry = 'India';
  String selectedCountrycode = '+91';
  String defaultCountrySortName = 'IN';

  Country? selectedCountry;

  bool isInvalidNumber = false;

  void setLoginType(String type) {
    isSelectLoginType = type;
    noty();
  }

  void setGenderType(String type) {
    isSelected = type;
    noty();
  }

  void validateInput() {
    if (phone == null || phone!.isEmpty || mobilecontroller.text.isEmpty) {
      isInvalidNumber = true;
      noty();
    } else {
      isInvalidNumber = false;
      noty();
    }
  }

  bool isValidEmail(String email) {
    final emailRegExp = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    return emailRegExp.hasMatch(email);
  }

  void noty() {
    notifyListeners();
  }

  Future<void> initializeData() async {
    _logger.i('<<<initializeData call>>>');

    // ✅ CRITICAL FIX: Check if user is logged in before auto-selecting avatar
    String? userToken = await SecurePrefs.getString(SecureStorageKeys.TOKEN);
    String? userIdValue = await SecurePrefs.getString(SecureStorageKeys.USERID);
    bool isUserLoggedIn =
        (userToken != null && userToken.isNotEmpty) ||
        (userIdValue != null && userIdValue.isNotEmpty);

    _logger.i(
      '🔍 InitializeData - userToken exists: ${userToken?.isNotEmpty ?? false}',
    );
    _logger.i(
      '🔍 InitializeData - userID exists: ${userIdValue?.isNotEmpty ?? false}',
    );
    _logger.i('🔍 InitializeData - isUserLoggedIn: $isUserLoggedIn');

    // Only auto-select avatar if user is logged in
    loadAvatars(isSelected: isUserLoggedIn);

    String? login = await SecurePrefs.getString(SecureStorageKeys.TYPE);
    String? emailID = await SecurePrefs.getString(SecureStorageKeys.EMAIL);
    String? countryCD = await SecurePrefs.getString(
      SecureStorageKeys.COUNTRY_CODE,
    );
    String? mobile = await SecurePrefs.getString(SecureStorageKeys.MOBILE_NUM);
    debugPrint("loginType:$loginType");
    debugPrint("emailID:${emailID.toString()}");
    debugPrint("mobile:${mobile.toString()}");
    selectedCountrycode = countryCD.toString();
    emailcontroller.text = emailID.toString();
    mobilecontroller.text = mobile.toString();
    isSelectLoginType = login.toString();
  }

  //==============================================================  Repositories Define =============================================================
  final LoginRepository loginRepository;

  AuthProvider(this.loginRepository);
  //==================================================================================================================================================
  //=============================================================== LOGIN EMAIL/MOBILE APIS ==========================================================
  //==================================================================================================================================================

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage; // Getter for error message

  Future<bool> loginApi(BuildContext context, String email) async {
    _isLoading = true;
    _errorMessage = null;
    noty();

    try {
      final result = await loginRepository.emailLoginRepository(email);

      if (result.status == true) {
        _isLoading = false;
        _errorMessage = result.message;
        noty();
      } else {
        _isLoading = false;
        _errorMessage = result.message;
        noty();
      }
      return true;
    } on AppError catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      noty();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Unexpected error occurred';
      noty();
      return false;
    }
  }

  Future<bool> loginMobileApi(
    BuildContext context, {
    required String countryCode,
    required String phoneNumber,
    required String countryFullName,
    required String selectedCountrySortName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    noty();
    try {
      final result = await loginRepository.mobileLoginRepository(
        countryCode,
        phoneNumber,
        countryFullName,
        selectedCountrySortName,
      );

      if (result.status == true) {
        _isLoading = false;
        _errorMessage = result.message;
        noty();
      } else {
        _isLoading = false;
        _errorMessage = result.message;
        noty();
      }
      return true;
    } on AppError catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      noty();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Unexpected error occurred';
      _logger.i('Error loading features: $e');
      noty();
      return false;
    }
  }

  //==================================================================================================================================================
  //=============================================================== OTP EMAIL/MOBILE APIS ============================================================
  //==================================================================================================================================================

  bool _isLoadingOtp = false;

  bool get isLoadingOtp => _isLoadingOtp;

  Future<bool> otpVerifyApi(
    BuildContext context, {
    required String countryCode,
    required String phoneNumber,
    required bool isEmail,
    required String email,
    required String otp,
    required String fcmtoken,
  }) async {
    debugPrint("isSelectLoginType:$isSelectLoginType");
    try {
      _isLoadingOtp = true;
      _errorMessage = null;
      noty();

      // ✅ Get OneSignal Player ID
      final oneSignalService = OneSignalService();
      String? oneSignalPlayerId = await oneSignalService.getPlayerIdAsync();

      // If OneSignal is not initialized or player ID is not available, use fallback
      if (oneSignalPlayerId == null || oneSignalPlayerId.isEmpty) {
        oneSignalPlayerId = "not_available";
        _logger.w('OneSignal Player ID not available, using fallback');
      } else {
        _logger.i('Using OneSignal Player ID: $oneSignalPlayerId');
      }

      final result = await loginRepository.otpRepository(
        isEmail: isEmail,
        countryCode: countryCode,
        phoneNumber: phoneNumber,
        email: email,
        otp: otp,
        fcmtoken: fcmtoken,
        oneSignalId: oneSignalPlayerId,
      );
      if (result.status == true) {
        // ✅ FIX: Handle OneSignal user registration with error handling
        bool oneSignalSuccess = true;
        if (result.data!.user!.userId != null &&
            oneSignalService.isInitialized) {
          oneSignalSuccess = await oneSignalService.setExternalUserId(
            result.data!.user!.userId.toString(),
          );

          // ✅ Show alert if OneSignal registration failed
          if (!oneSignalSuccess && context.mounted) {
            _showOneSignalWarningDialog(context);
          }
        }
        // Store token, save user info, etc.

        if (result.data!.user!.userName != null) {
          userNameController.text = result.data!.user!.userName!.toString();
        }
        fNameController.text = result.data!.user!.firstName.toString();
        lNameController.text = result.data!.user!.lastName.toString();
        countryController.text = result.data!.user!.country.toString();
        isSelected = result.data!.user!.gender.toString();

        await SecurePrefs.setMultiple({
          SecureStorageKeys.TOKEN: result.data!.token.toString(),
          SecureStorageKeys.USERID: result.data!.user!.userId.toString(),

          SecureStorageKeys.USER_NAME:
              (result.data!.user!.userName != null)
                  ? result.data!.user!.userName.toString()
                  : "",
          SecureStorageKeys.FIRST_NAME: result.data!.user!.firstName.toString(),
          SecureStorageKeys.LAST_NAME: result.data!.user!.lastName.toString(),
          SecureStorageKeys.COUNTRY_NAME: result.data!.user!.country.toString(),
          SecureStorageKeys.GENDER: result.data!.user!.gender.toString(),
          SecureStorageKeys.EMAIL: email,
          SecureStorageKeys.COUNTRY_CODE: result.data!.user!.countryCode,
          SecureStorageKeys.MOBILE_NUM: result.data!.user!.mobileNum.toString(),
          SecureStorageKeys.TYPE: isSelectLoginType.toString(),
          SecureStorageKeys.USER_PROFILE:
              result.data!.user!.profilePic.toString(),
        });

        // ✅ ANDROID FIX: Set permission flag to true after successful OTP verification
        // This prevents the app from redirecting to onboarding screen on app restart
        await SecurePrefs.setBool(SecureStorageKeys.PERMISSION, true);

        // ✅ NEW: Store demo account flag from API response
        await SecurePrefs.setBool(
          SecureStorageKeys.IS_DEMO,
          result.data!.user!.isDemo ?? false,
        );
        debugPrint("TYPE:$isSelectLoginType");
        await SecureStorageKeys().loadUserFromPrefs();
        // ✅ CRITICAL FIX: Load boolean values including isDemo, isPhoneAuthEnabled, isEmailAuthEnabled
        await SecureStorageKeys().loadeBoolValuePrefes();

        debugPrint("authToken:$authToken");
        debugPrint("isDemo:$isDemo"); // Debug log to verify isDemo is loaded

        // IMPORTANT: Initialize socket connections after successful login
        // ✅ Check if context is still mounted before using it across async gap
        if (context.mounted) {
          await handleSuccessfulLogin(context);
        }

        _isLoadingOtp = false;
        noty();
        return true;
      } else {
        _isLoadingOtp = false;
        _errorMessage = result.message ?? AppString.failedToAddOTP;
        noty();
        return false;
      }
    } on AppError catch (e) {
      _isLoadingOtp = false;
      _errorMessage = e.message;
      _logger.i('Error loading features: ${e.message}');
      noty();
      return false;
    } catch (e) {
      _isLoadingOtp = false;
      _errorMessage = 'Unexpected error occurred';
      _logger.i('Error loading features_catch: $e');
      noty();
      return false;
    }
  }

  //==================================================================================================================================================
  //=============================================================== USER NAME CHECK ==================================================================
  //==================================================================================================================================================
  bool isCheckuserName = false;
  bool _isLoadingName = false;
  String userNameError = '';

  UserNameStatus _userNameStatus = UserNameStatus.initial;
  Timer? _debounce;

  bool get isLoadingName => _isLoadingName;
  UserNameStatus get userNameStatus => _userNameStatus;
  String get currentUserName => userNameController.text.trim();

  /* ================= RESET ================= */

  void resetUserNameState() {
    _debounce?.cancel();
    _userNameStatus = UserNameStatus.initial;
    _isLoadingName = false;
    userNameError = '';
    _errorMessage = null;
    isCheckuserName = false;

    // userNameController.clear(); // Add this
    notifyListeners();
  }

  /* ================= USERNAME CHANGE ================= */

  void onUserNameChanged(String value) {
    final trimmed = value.trim();

    _debounce?.cancel();

    if (trimmed.isEmpty) {
      userNameError = '';
      setUserNameStatus(UserNameStatus.initial);
      notifyListeners();
      return;
    }

    // show loader immediately
    userNameError = '';
    setUserNameStatus(UserNameStatus.loading);
    notifyListeners();

    _debounce = Timer(const Duration(milliseconds: 800), () {
      userNameCheckApi(trimmed);
    });
  }

  /* ================= API CALL ================= */

  Future<void> userNameCheckApi(String xyz) async {
    if (xyz.isEmpty) return;

    try {
      _isLoadingName = true;
      _errorMessage = null;
      userNameError = '';
      noty();

      final result = await loginRepository.userNameCheckRepo(xyz);

      _isLoadingName = false;
      noty();

      if (result.status == true) {
        setUserNameStatus(UserNameStatus.success);
        userNameError = '';
      } else {
        setUserNameStatus(UserNameStatus.error);
        _errorMessage = result.message;
        userNameError = result.message!;
      }
    } on AppError catch (e) {
      _isLoadingName = false;
      _errorMessage = e.message;
      setUserNameStatus(UserNameStatus.error);
      noty();
    } catch (e) {
      _isLoadingName = false;
      setUserNameStatus(UserNameStatus.error);
      _errorMessage = 'Unexpected error occurred';
      _logger.i('Error loading features: $e');
      userNameError = "Please enter your user name";
      noty();
    }
  }

  void setUserNameStatus(UserNameStatus status) {
    _userNameStatus = status;
    noty();
  }

  void clearUserName() {
    userNameController.clear();
    userNameError = '';
    setUserNameStatus(UserNameStatus.initial);
    _debounce?.cancel();
    noty();
  }

  void setUserNameSafely() {
    final safeName = userNameController.text.trim();
    if (safeName.isEmpty || safeName == "null") {
      userNameController.clear();
    } else {
      userNameController.text = safeName;
    }
  }

  //==================================================================================================================================================
  //=============================================================== USER Profile add =================================================================
  //==================================================================================================================================================
  bool _isUserProfile = false;

  bool get isUserProfile => _isUserProfile;

  Future<bool> userProfileApi(BuildContext context) async {
    debugPrint("_selectedAvatar:$_selectedAvatar");
    debugPrint("_pictureType:$_pictureType");
    _logger.i(
      '🔍 UserProfileApi - selectedAvatar: ${_selectedAvatar?.avatarMedia}',
    );
    _logger.i('🔍 UserProfileApi - pictureType: $_pictureType');
    _logger.i('🔍 UserProfileApi - image file: $image');
    try {
      _isUserProfile = true;
      _errorMessage = null;
      noty();

      final result = await loginRepository.userProfileAddRepo(
        image,
        userName: userNameController.text,
        fname: fNameController.text,
        lname: lNameController.text,
        country: defaultSelectedCountry,
        gender: isSelected,
        deviceToken: "",
        // email: emailcontroller.text,
        countryCode: selectedCountrycode,
        mobile: mobilecontroller.text,
        avatarUrl: _selectedAvatar?.avatarMedia,
        pictureType: _pictureType,
      );

      if (result.status == true) {
        await SecurePrefs.setMultiple({
          SecureStorageKeys.USER_NAME: (result.data?.userName ?? '').toString(),
          SecureStorageKeys.FIRST_NAME:
              (result.data?.firstName ?? '').toString(),
          SecureStorageKeys.LAST_NAME: (result.data?.lastName ?? '').toString(),
          SecureStorageKeys.COUNTRY_NAME:
              (result.data?.country ?? '').toString(),
          SecureStorageKeys.GENDER: (result.data?.gender ?? '').toString(),
          SecureStorageKeys.EMAIL: email,
          SecureStorageKeys.COUNTRY_CODE: result.data!.countryCode,
          SecureStorageKeys.MOBILE_NUM:
              (result.data?.mobileNum ?? '').toString(),
          SecureStorageKeys.USER_PROFILE:
              (result.data?.profilePic ?? '').toString(),
        });
        await SecureStorageKeys().loadUserFromPrefs();
        if (result.data?.profilePic != null && result.data?.profilePic != "") {
          userProfile = result.data!.profilePic.toString();
        }
        _isUserProfile = false;
        _errorMessage = result.message;
        noty();
        return true;
      } else {
        _isUserProfile = false;
        _errorMessage = result.message ?? "Something went wrong";
        noty();
        return false;
      }
    } on AppError catch (e) {
      _isUserProfile = false;
      _errorMessage = e.message;
      noty();
      return false;
    } catch (e) {
      _isUserProfile = false;
      _errorMessage = 'Unexpected error occurred';
      _logger.i('Error loading features: $e');
      noty();
      return false;
    }
  }

  //==================================================================================================================================================
  //=============================================================== AVATAR UPDATE ONLY ==============================================================
  //==================================================================================================================================================
  Future<bool> updateAvatarApi(BuildContext context) async {
    debugPrint("_selectedAvatar:$_selectedAvatar");
    debugPrint("_pictureType:$_pictureType");
    try {
      _isUserProfile = true;
      _errorMessage = null;
      noty();

      final result = await loginRepository.updateAvatarRepo(
        image: image,
        avatarUrl: _selectedAvatar?.avatarMedia,
        pictureType: _pictureType,
      );

      if (result.status == true) {
        await SecurePrefs.setString(
          SecureStorageKeys.USER_PROFILE,
          result.data!.profilePic.toString(),
        );
        await SecureStorageKeys().loadUserFromPrefs();
        _isUserProfile = false;
        _errorMessage = result.message;
        noty();
        return true;
      } else {
        _isUserProfile = false;
        _errorMessage = result.message ?? "Something went wrong";
        noty();
        return false;
      }
    } on AppError catch (e) {
      _isUserProfile = false;
      _errorMessage = e.message;
      noty();
      return false;
    } catch (e) {
      _isUserProfile = false;
      _errorMessage = 'Unexpected error occurred';
      _logger.i('Error updating avatar: $e');
      noty();
      return false;
    }
  }

  //==================================================================================================================================================
  //=============================================================== USER Profile GET =================================================================
  //==================================================================================================================================================
  File? image;
  final picker = ImagePicker();
  bool _isGetProfile = false;

  bool get isGetProfile => _isGetProfile;
  String? profileImageUrl;
  bool hasLoadedOnce = false;
  bool isInternetIssue = false;

  // Avatar related variables
  List<Records> _avatars = [];
  List<Records> get avatars => _avatars;
  bool _isLoadingAvatars = false;
  bool get isLoadingAvatars => _isLoadingAvatars;
  Records? _selectedAvatar;
  Records? get selectedAvatar => _selectedAvatar;
  Records? _tempSelectedAvatar;
  Records? get tempSelectedAvatar => _tempSelectedAvatar;
  String _pictureType = 'profile_pic';
  String get pictureType => _pictureType;

  Future<void> userProfileApiGet() async {
    if (!hasLoadedOnce) {
      _isGetProfile = true;
    }
    _errorMessage = null;
    isInternetIssue = false;
    hasLoadedOnce = false;
    noty();
    try {
      final result = await loginRepository.userProfileGetRepo();

      if (result.status == true) {
        userNameController.text = (result.data?.userName ?? '').toString();
        if (result.data?.userName?.isNotEmpty == true) {
          _userNameStatus = UserNameStatus.success;
        }
        fNameController.text = (result.data?.firstName ?? '').toString();
        lNameController.text = (result.data?.lastName ?? '').toString();
        emailcontroller.text = (result.data?.email ?? '').toString();
        selectedCountrycode = (result.data?.countryCode ?? '').toString();
        mobilecontroller.text = (result.data?.mobileNum ?? '').toString();
        countryController.text = (result.data?.country ?? '').toString();
        profileImageUrl = result.data?.profilePic;
        debugPrint("profileImageUrl:$profileImageUrl");
        isSelected = (result.data?.gender ?? '').toString();
        await SecurePrefs.setMultiple({
          SecureStorageKeys.USER_NAME: (result.data?.userName ?? '').toString(),
          SecureStorageKeys.FIRST_NAME:
              (result.data?.firstName ?? '').toString(),
          SecureStorageKeys.LAST_NAME: (result.data?.lastName ?? '').toString(),
          SecureStorageKeys.COUNTRY_NAME:
              (result.data?.country ?? '').toString(),
          SecureStorageKeys.GENDER: (result.data?.gender ?? '').toString(),
          SecureStorageKeys.EMAIL: (result.data?.email ?? '').toString(),
          SecureStorageKeys.COUNTRY_CODE:
              (result.data?.countryCode ?? '').toString(),
          SecureStorageKeys.MOBILE_NUM:
              (result.data?.mobileNum ?? '').toString(),
          SecureStorageKeys.USER_PROFILE:
              (result.data?.profilePic ?? '').toString(),
        });
        await SecureStorageKeys().loadUserFromPrefs();

        hasLoadedOnce = true;
        _isGetProfile = false;
        _selectedAvatar = null;
        noty();
      } else {
        _isGetProfile = false;
        noty();
        _errorMessage = result.message ?? "Something went wrong";
      }
    } on AppError catch (e) {
      //===== APP ERROR SHOW =====
      _isGetProfile = false;
      final data = extractErrorData(e);
      _errorMessage = data?['message'] ?? 'Unknown error';
      isInternetIssue = errorMessage!.contains(AppString.connectionError);
      noty();
      //==========================
    } catch (e) {
      //====== CATCH ERROR =======
      _errorMessage = 'Unexpected error occurred';
      isInternetIssue = false;
      _logger.i('Error loading features: $e');
      noty();
      //==========================
    } finally {
      _isGetProfile = false;
      noty();
    }
  }

  Future getImageFromCamera() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      image = File(pickedFile.path);
      _selectedAvatar = null;
      _pictureType = 'profile_pic';
      noty();
    } else {
      debugPrint('No image selected.');
    }
  }

  Future getImageFromGallery() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      image = File(pickedFile.path);
      _selectedAvatar = null;
      _pictureType = 'profile_pic';
      noty();
    } else {
      debugPrint('No image selected.');
    }
  }

  // Avatar related methods

  Future<void> loadAvatars({required bool isSelected}) async {
    _logger.i('loadAvatars call>>>');
    _isLoadingAvatars = true;
    noty();

    try {
      final result = await loginRepository.getAllAvatarsRepo();
      if (result.status == true && result.data != null) {
        _avatars = result.data!.records!;
        if (isSelected) {
          selectAvatar(_avatars[0]);
        }
      } else {
        _avatars = [];
      }
    } catch (e) {
      _logger.e('Error loading avatars: $e');
      _avatars = [];
    } finally {
      _isLoadingAvatars = false;
      noty();
    }
  }

  void selectAvatar(Records avatar) {
    _selectedAvatar = avatar;
    image = null;
    _pictureType = 'avatar';
    noty();
  }

  void selectAvatarTemp(Records avatar) {
    _tempSelectedAvatar = avatar;
    noty();
  }

  void clearImageSelection() {
    image = null;
    _selectedAvatar = null;
    _pictureType = 'profile_pic';
    noty();
  }

  //==================================================================================================================================================
  //=============================================================== USER DELETE ACC ==================================================================
  //==================================================================================================================================================
  bool _isDeleteAcc = false;
  bool get isDeleteAcc => _isDeleteAcc;

  bool _isLogout = false;
  bool get isLogout => _isLogout;

  Future<bool> userDeleteAccApi() async {
    try {
      _isDeleteAcc = true;
      _errorMessage = null;
      noty();

      final result = await loginRepository.deleteUserRepo();

      if (result.status == true) {
        _isDeleteAcc = false;
        _errorMessage = result.message;
        noty();
        return true;
      } else {
        _isDeleteAcc = false;
        _errorMessage = result.message;
        noty();
        return false;
      }
    } on AppError catch (e) {
      _isDeleteAcc = false;
      _errorMessage = e.message;
      noty();
      return false;
    } catch (e) {
      _isDeleteAcc = false;
      noty();
      return false;
    }
  }

  Future<bool> userLogoutApi({String? socketId}) async {
    try {
      _logger.i('Calling logout API with socket_id: $socketId');
      final result = await loginRepository.logoutUserRepo(socketId: socketId);

      if (result.status == true) {
        _logger.i('Logout API successful: ${result.message}');
        return true;
      } else {
        _logger.w('Logout API failed: ${result.message}');
        _errorMessage = result.message;
        return false;
      }
    } on AppError catch (e) {
      _logger.e('Logout API error: ${e.message}');
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _logger.e('Logout API unexpected error: $e');
      return false;
    }
  }

  /// Handle successful login with socket initialization
  Future<void> handleSuccessfulLogin(BuildContext context) async {
    try {
      _logger.i('Handling successful login - initializing socket connections');

      // Initialize socket connections after successful login
      await initializeSocketAfterLogin();

      // Notify app lifecycle manager if available
      if (context.mounted) {
        context.lifecycleManager?.onUserLoggedIn();
      }

      _logger.i('Socket connections initialized successfully after login');
    } catch (e) {
      _logger.e('Error initializing socket connections after login', e);
      // Don't fail the login process if socket initialization fails
      // The user can still use the app, socket will retry later
    }
  }

  /// Handle logout with proper socket cleanup
  Future<void> handleLogout(BuildContext context) async {
    try {
      _isLogout = true;
      notifyListeners();
      _logger.i('Handling logout - calling API and cleaning up');

      // Get current socket ID before logout
      String? currentSocketId;
      try {
        final socketService = GetIt.instance<SocketService>();
        currentSocketId = socketService.socketId;
        _logger.i('Current socket ID for logout: $currentSocketId');
      } catch (e) {
        _logger.w('Could not get socket ID for logout: $e');
      }

      // ✅ FIXED: Clean up socket connections BEFORE clearing secure storage
      // This prevents the socket from trying to reconnect with cleared tokens
      _logger.i('Cleaning up socket connections before token cleanup');
      await cleanupSocketAfterLogout();

      // ✅ CRITICAL FIX: Clear chat cache to prevent old user's messages showing to new user
      _logger.i('Clearing chat cache to remove old user data');
      try {
        await ChatCacheManager.clearAll();
        _logger.i('✅ Chat cache cleared successfully');
      } catch (e) {
        _logger.w('⚠️ Error clearing chat cache: $e');
        // Continue with logout even if cache clear fails
      }

      // Call logout API with current socket ID
      await userLogoutApi(socketId: currentSocketId);

      // ✅ CRITICAL FIX: Logout from OneSignal to disassociate device from user
      _logger.i('Logging out from OneSignal...');
      try {
        final oneSignalService = OneSignalService();
        await oneSignalService.logout();
        _logger.i('✅ OneSignal logout completed');
      } catch (e) {
        _logger.w('⚠️ Error during OneSignal logout: $e');
        // Continue with logout even if OneSignal logout fails
      }

      // Notify app lifecycle manager about logout
      if (context.mounted) {
        context.lifecycleManager?.onUserLoggedOut();
      }
      if (context.mounted) {
        final languageProvider = Provider.of<LanguageProvider>(
          context,
          listen: false,
        );
        await languageProvider.wordListApi(
          languageId:
              languageProvider.languageListData
                  .firstWhere((element) => element.language == "English")
                  .languageId
                  .toString(),
        );
      }

      // Clear all stored data AFTER socket cleanup
      await SecurePrefs.clear();
      isLightModeGlobal = await SecurePrefs.getBoolLighDark(
        SecureStorageKeys.isLightMode,
      );
      debugPrint("isLightModeGlobal:$isLightModeGlobal");

      _logger.i('Secure storage cleared after socket cleanup');

      if (context.mounted) {
        final languageProvider = Provider.of<LanguageProvider>(
          context,
          listen: false,
        );
        languageProvider.loginDeleteTineUse();
      }

      // Reset contact provider state for new user
      try {
        // Try to get contact provider from context if available
        if (context.mounted) {
          try {
            final contactProvider = Provider.of<ContactListProvider>(
              context,
              listen: false,
            );
            contactProvider.resetContactProvider();
            _logger.i('ContactListProvider reset completed via Provider.of');
          } catch (e) {
            _logger.w(
              'Could not reset ContactListProvider via Provider.of: $e',
            );

            // Fallback: Try GetIt
            try {
              final contactProvider = GetIt.instance.get<ContactListProvider>();
              contactProvider.resetContactProvider();
              _logger.i('ContactListProvider reset completed via GetIt');
            } catch (e2) {
              _logger.w('Could not reset ContactListProvider via GetIt: $e2');
            }
          }
        } else {
          _logger.w('Context not mounted, cannot reset ContactListProvider');
        }
      } catch (e) {
        _logger.w('General error resetting ContactListProvider: $e');
        // Non-critical error, continue with logout
      }

      // Clear form controllers
      _clearControllers();

      // ✅ CRITICAL FIX: Clear avatar selection to prevent old user's avatar being used by new user
      _logger.i('🧹 Clearing avatar selection and image data...');
      clearImageSelection();
      _logger.i(
        '✅ Avatar cleanup completed - _selectedAvatar: $_selectedAvatar, _pictureType: $_pictureType, image: $image',
      );

      // Reset state
      isSelectLoginType = AppString.phone;
      isSelected = '';
      _errorMessage = null;

      _logger.i('Logout cleanup completed successfully');

      // Reset logout loading state
      _isLogout = false;

      // Notify listeners
      notifyListeners();
    } catch (e) {
      _logger.e('Error during logout cleanup', e);
      // Reset logout loading state on error
      _isLogout = false;
      notifyListeners();
      // Continue with logout even if cleanup fails
    }
  }

  /// Handle account deletion with proper socket cleanup
  Future<bool> handleAccountDeletion(BuildContext context) async {
    try {
      _logger.i('Handling account deletion');

      // Call the API to delete account
      final success = await userDeleteAccApi();

      if (success) {
        // Keep delete loading state during logout cleanup
        _isDeleteAcc = true;
        notifyListeners();

        // If deletion was successful, clean up everything
        if (context.mounted) {
          await handleLogout(context);
        }

        // Reset delete loading state after cleanup
        _isDeleteAcc = false;
        notifyListeners();

        _logger.i('Account deletion and cleanup completed successfully');
        return true;
      } else {
        _logger.w('Account deletion API failed');
        return false;
      }
    } catch (e) {
      _logger.e('Error during account deletion', e);
      // Ensure loading state is reset on error
      _isDeleteAcc = false;
      notifyListeners();
      return false;
    }
  }

  void _clearControllers() {
    emailcontroller.clear();
    mobilecontroller.clear();
    otpController.clear();
    userNameController.clear();
    fNameController.clear();
    lNameController.clear();
    countryController.clear();
  }

  /// Check if socket is connected (utility method)
  bool get isSocketConnected {
    try {
      return GetIt.instance<SocketManager>().isConnected;
    } catch (e) {
      _logger.e('Error checking socket connection status', e);
      return false;
    }
  }

  /// Get socket connection status stream
  ValueNotifier<bool> get socketConnectionStatus {
    try {
      return GetIt.instance<SocketManager>().connectionStatus;
    } catch (e) {
      _logger.e('Error getting socket connection status stream', e);
      return ValueNotifier<bool>(false);
    }
  }

  /// ✅ Show warning dialog when OneSignal registration fails
  /// This informs the user that notifications may not work properly
  void _showOneSignalWarningDialog(BuildContext context) {
    // Show dialog after a short delay to avoid showing during navigation
    Future.delayed(Duration(milliseconds: 500), () {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Notification Warning'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Push notifications may not work properly for your account.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This can happen due to:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Your user ID is blocked by notification service\n'
                    '• Network connectivity issues\n'
                    '• Service timeout',
                    style: TextStyle(fontSize: 13),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'You can still use the app, but you may miss incoming call notifications.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
    });
  }

  @override
  void dispose() {
    userNameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
