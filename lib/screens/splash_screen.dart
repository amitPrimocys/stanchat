import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:stanchat/core/api/api_endpoint.dart';
import 'package:stanchat/core/navigation_helper.dart';
import 'package:stanchat/featuers/auth/provider/auth_provider.dart';
import 'package:stanchat/featuers/language_method/provider/language_provider.dart';
import 'package:stanchat/featuers/project-config/provider/config_provider.dart';
import 'package:stanchat/featuers/provider/tabbar_provider.dart';
import 'package:stanchat/core/services/cold_start_handler.dart';
import 'package:stanchat/utils/app_size_config.dart';
import 'package:stanchat/utils/preference_key/constant/app_assets.dart';
import 'package:stanchat/utils/preference_key/constant/app_routes.dart';
import 'package:stanchat/utils/preference_key/constant/app_theme_manage.dart';
import 'package:stanchat/utils/preference_key/preference_key.dart';
import 'package:stanchat/utils/preference_key/sharedpref_key.dart';
import 'package:stanchat/widgets/cusotm_blur_appbar.dart';
import 'package:stanchat/widgets/global.dart';
import 'package:stanchat/utils/logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? animationController;
  Animation<double>? animation;
  final ConsoleAppLogger _logger = ConsoleAppLogger();
  final String splashId = DateTime.now().millisecondsSinceEpoch.toString();

  // Track initialization status
  bool _projectConfigLoaded = false;
  bool _oneSignalInitialized = false;

  // Call navigation state tracking
  bool _isNavigatingToCall = false;
  bool _shouldSkipSplashNavigation = false;

  // Prevent double navigation
  static bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    debugPrint("Welcome to splash - Instance ID: $splashId");
    _logger.i("Splash screen initialized - Instance ID: $splashId");

    // ✅ CRITICAL FIX: If navigation already happened, don't initialize anything
    if (_hasNavigated) {
      _logger.i(
        "⚠️ Navigation already completed - skipping initialization to prevent double navigation",
      );
      return;
    }

    _logger.i("🔄 First splash instance - ready for navigation");

    _initializeAnimation();

    // ✅ FIX: Defer initialization until after build phase to prevent setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppInBackground();
    });
  }

  void _initializeAnimation() {
    animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    animation = CurvedAnimation(
      parent: animationController!,
      curve: Curves.easeOut,
    );

    animation!.addListener(() => setState(() {}));
    animationController!.forward();
  }

  void _initializeAppInBackground() async {
    // 1. Wait for project config to load
    await _initializeProjectConfigAndOneSignal();
    _logger.i("✅ Project config loaded");

    // 2. Check for pending call notifications
    await _handlePendingCallNotification();
    _logger.i("✅ Call notification check complete");

    // 3. Wait minimum 2 seconds for splash animation
    await Future.delayed(Duration(seconds: 2));

    // 4. Navigate only if not already navigated and not navigating to call
    if (!_shouldSkipSplashNavigation && mounted && !_hasNavigated) {
      _logger.i("✅ All initialization complete - navigating");
      navigationPage();
    } else {
      _logger.i(
        "⏭️ Skipping navigation - already navigated or navigating to call",
      );
    }
  }

  /// Wait for project config to load
  Future<void> _initializeProjectConfigAndOneSignal() async {
    try {
      _logger.i('🚀 Loading project configuration...');

      final configProvider = Provider.of<ProjectConfigProvider>(
        context,
        listen: false,
      );

      final langProvider = Provider.of<LanguageProvider>(
        context,
        listen: false,
      );

      // Wait for config to load - always fetch fresh from API on app startup
      await configProvider.initializeProjectConfig(forceRefresh: true);

      // Load language data
      langProvider.fetchLangData();

      if (mounted) {
        setState(() {
          _projectConfigLoaded = true;
          _oneSignalInitialized = true;
        });
      }

      _logger.i('✅ Project config loaded: ${configProvider.appName}');
      _logger.i('✅ Dynamic logo should now be visible');
    } catch (e) {
      _logger.e('❌ Error loading config: $e');
      // Continue anyway with defaults
      if (mounted) {
        setState(() {
          _projectConfigLoaded = true;
          _oneSignalInitialized = true;
        });
      }
    }
  }

  void navigationPage() async {
    _logger.i('🧭 navigationPage() called - checking conditions');

    if (!mounted) {
      _logger.i('🚫 Not mounted - returning');
      return;
    }

    // ✅ PREVENT DOUBLE NAVIGATION: Check if navigation already happened
    if (_hasNavigated) {
      _logger.i('🚫 Skipping navigation - already navigated (flag=true)');
      return;
    }

    // ✅ CRITICAL: Skip navigation if already navigating to call or should skip
    if (_isNavigatingToCall || _shouldSkipSplashNavigation) {
      _logger.i('🚫 Skipping splash navigation - call screen priority active');
      SplashNavigationTracker.markSkipped();
      return;
    }

    // ✅ CRITICAL: Mark as navigated FIRST to prevent race conditions
    _hasNavigated = true;
    _logger.i('✅ Navigation flag set to true - proceeding with navigation');

    _logger.i('🧭 Starting navigation logic');
    _logger.i(
      '📊 Initialization status: Config=$_projectConfigLoaded, OneSignal=$_oneSignalInitialized',
    );

    // Small delay to ensure safe context usage
    await Future.delayed(Duration(milliseconds: 100));

    if (!mounted) return;

    // Navigation for calls is handled from NavigationHelper
    if (!NavigationHelper.getIsNavigatingCall) {
      String route = await _handleCurrentScreen();

      // ✅ Check if widget is still mounted before navigation
      if (!mounted) {
        _logger.i('🚫 Widget not mounted - canceling navigation');
        return;
      }

      _logger.i('🚀 NAVIGATING TO: $route');
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (Route<dynamic> route) => false,
      );
      _logger.i('✅ Navigation completed to: $route');
    }
  }

  /// Handle pending call notifications
  Future<void> _handlePendingCallNotification() async {
    try {
      final coldStartHandler = ColdStartHandler();

      if (coldStartHandler.hasPendingCallData) {
        _logger.i('📞 Pending call notification - handling immediately');

        _isNavigatingToCall = true;
        _shouldSkipSplashNavigation = true;

        await Future.delayed(Duration(milliseconds: 2000));

        if (!mounted) return;

        await coldStartHandler.handlePendingNotification();

        _logger.i('✅ Call notification handled');
        return;
      }

      _logger.d('No pending call notifications');
    } catch (e) {
      _logger.e('❌ Error handling call notification: $e');
      _isNavigatingToCall = false;
      _shouldSkipSplashNavigation = false;
    }
  }

  @override
  void dispose() {
    animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUI(),
      child: Consumer<ProjectConfigProvider>(
        builder: (context, configProvider, _) {
          return Scaffold(
            backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
            body: Center(
              child: Stack(
                children: [
                  SvgPicture.asset(AppAssets.splashLine),
                  Column(
                    children: [
                      // SizedBox(height: SizeConfig.height(40)),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Use dynamic logo from project config
                            Center(
                              child:
                                  _projectConfigLoaded
                                      ? (isLightModeGlobal
                                          ? appDynamicLogo()
                                          : appDynamicLogoDark())
                                      : SizedBox(
                                        height: SizeConfig.sizedBoxHeight(65),
                                        width: SizeConfig.sizedBoxHeight(65),
                                        child: Center(child: commonLoading()),
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<String> _handleCurrentScreen() async {
    // ✅ CRITICAL FIX: Native iOS approach handles first run detection in AppDelegate
    // iOS will clear FlutterSecureStorage automatically on first run after uninstall
    bool hasCompletedOnboarding = await SecurePrefs.getBool(
      SecureStorageKeys.PERMISSION,
    );
    String token = authToken;
    bool hasAnyUserData =
        userName.isNotEmpty || userID.isNotEmpty || token.isNotEmpty;

    // 🔍 DEBUG: Log navigation decision factors
    _logger.i("🧭 Navigation Debug:");
    _logger.i(
      "  hasCompletedOnboarding (SecurePrefs): $hasCompletedOnboarding",
    );
    _logger.i("  permission (global variable): $permission");
    _logger.i("  authToken: '${token.isEmpty ? 'EMPTY' : 'PRESENT'}'");
    _logger.i("  userName: '${userName.isEmpty ? 'EMPTY' : userName}'");
    _logger.i(
      "  userProfile: '${userProfile.isEmpty ? 'EMPTY' : userProfile}'",
    );
    _logger.i("  hasAnyUserData: $hasAnyUserData");

    // ✅ CRITICAL FIX: Simplified logic - if no onboarding completion or no user data, go to onboarding
    // The native iOS approach handles data clearing for fresh installs
    if (!hasCompletedOnboarding && !hasAnyUserData) {
      _logger.i(
        "🎯 Going to: ONBOARDING (No completed onboarding or no user data)",
      );
      return AppRoutes.onboarding;
    }

    // If token not available then navigate to signin method
    if (token.isEmpty) {
      _logger.i("🎯 Going to: LOGIN (no token)");
      return AppRoutes.login;
    }

    // Check user info completion - CRITICAL: Check firstName (mandatory field)
    String? firstName =
        await SecurePrefs.getString(SecureStorageKeys.FIRST_NAME) ?? "";
    String username = userName;

    _logger.i("🔍 Splash firstName from SecureStorage: '$firstName'");
    _logger.i("🔍 Splash userName: '$username'");

    // CRITICAL: Check firstName first - this is the mandatory field for profile completion
    if (firstName.isEmpty) {
      _logger.i(
        "🎯 Going to: ADD_INFO (firstName is empty - profile incomplete)",
      );
      Future.microtask(() {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).initializeData();
        }
      });
      return AppRoutes.login;
    }

    // Secondary check: username
    if (username.isEmpty) {
      _logger.i("🎯 Going to: ADD_INFO (no username)");
      Future.microtask(() {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).initializeData();
        }
      });
      return AppRoutes.login;
    }

    // ✅ ANDROID FIX: Read userProfile directly from secure storage to ensure fresh data
    // Don't rely on global variable which might not be updated on app restart
    String? userprofile =
        await SecurePrefs.getString(SecureStorageKeys.USER_PROFILE) ?? "";
    _logger.i("🔍 Splash userProfile from SecureStorage: '$userprofile'");
    _logger.i("🔍 Splash userProfile global variable: '$userProfile'");

    // ✅ Update global variable to ensure consistency
    userProfile = userprofile;

    if (userprofile.isEmpty) {
      // Before going to avatar, check if firstName is still empty (user might have incomplete profile)
      if (firstName.isEmpty) {
        _logger.i(
          "🎯 Going to: ADD_INFO (empty profile but firstName also empty - profile incomplete)",
        );
        Future.microtask(() {
          if (mounted) {
            Provider.of<AuthProvider>(context, listen: false).initializeData();
          }
        });
        return AppRoutes.login;
      }

      _logger.i(
        "🎯 Going to: AVATAR_PROFILE (empty profile from secure storage)",
      );
      Future.microtask(() {
        if (mounted) {
          Provider.of<AuthProvider>(
            context,
            listen: false,
          ).loadAvatars(isSelected: true);
        }
      });
      return AppRoutes.avatarProfile;
    } else if (userprofile ==
        "${ApiEndpoints.socketUrl}/uploads/not-found-images/profile-image.png") {
      // Before going to avatar, check if firstName is still empty (user might have incomplete profile)
      if (firstName.isEmpty) {
        _logger.i(
          "🎯 Going to: ADD_INFO (default profile but firstName also empty - profile incomplete)",
        );
        Future.microtask(() {
          if (mounted) {
            Provider.of<AuthProvider>(context, listen: false).initializeData();
          }
        });
        return AppRoutes.login;
      }

      _logger.i(
        "🎯 Going to: AVATAR_PROFILE (default profile image from secure storage)",
      );
      Future.microtask(() {
        if (mounted) {
          Provider.of<AuthProvider>(
            context,
            listen: false,
          ).loadAvatars(isSelected: true);
        }
      });
      return AppRoutes.avatarProfile;
    }

    // All checks passed, go to main app
    _logger.i("🎯 Going to: TABBAR (all checks passed)");
    Future.microtask(() {
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).initializeData();
        Provider.of<TabbarProvider>(context, listen: false).navigateToIndex(0);
      }
    });

    return AppRoutes.tabbar;
  }
}

// this is check for call screen redirection and again go to the tabbar
class SplashNavigationTracker {
  static bool wasSkipped = false;
  static bool cameFromNotificationTap = false;

  /// Reset the tracker after call navigation is complete
  static void reset() {
    wasSkipped = false;
    cameFromNotificationTap = false;
  }

  /// Mark splash as skipped for call navigation
  static void markSkipped() {
    wasSkipped = true;
  }

  /// Mark that user came from notification tap
  static void markCameFromNotification() {
    cameFromNotificationTap = true;
  }
}
