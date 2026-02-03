import 'package:flutter/material.dart';
import 'package:whoxa/featuers/auth/screens/avatar_profile.dart';
import 'package:whoxa/featuers/chat/group/screens/group_info.dart';
import 'package:whoxa/featuers/chat/screens/starred_messages_screen.dart';
import 'package:whoxa/featuers/chat/screens/chat_media_screen.dart';
import 'package:whoxa/featuers/chat/screens/universal_chat_screen.dart';
import 'package:whoxa/featuers/auth/screens/add_info.dart';
import 'package:whoxa/featuers/auth/screens/login.dart';
import 'package:whoxa/featuers/auth/screens/otp.dart';
import 'package:whoxa/featuers/auth/screens/signin_method.dart';
import 'package:whoxa/featuers/bloc_user/screens/block_list.dart';
import 'package:whoxa/featuers/contacts/screen/contact_list.dart';
import 'package:whoxa/featuers/home/screens/home_screen.dart';
import 'package:whoxa/featuers/notification/notiification_list.dart';
import 'package:whoxa/featuers/onboarding/screens/onboarding.dart';
import 'package:whoxa/featuers/profile/screens/profile.dart';
import 'package:whoxa/featuers/profile/screens/profile_status.dart';
import 'package:whoxa/featuers/profile/screens/status.dart';
import 'package:whoxa/featuers/profile/screens/write_status.dart';
import 'package:whoxa/featuers/profile/screens/catalog_detail_screen.dart';
import 'package:whoxa/featuers/profile/screens/catalog_list_screen.dart';
import 'package:whoxa/featuers/story/screens/my_story_view.dart';
import 'package:whoxa/featuers/story/screens/story_list.dart';
import 'package:whoxa/featuers/story/screens/story_upload.dart';
import 'package:whoxa/screens/new_tabbar.dart';
import 'package:whoxa/screens/settings/settings.dart';
import 'package:whoxa/screens/settings/theme_color_picker.dart';
import 'package:whoxa/screens/splash_screen.dart';
import 'package:whoxa/featuers/auth/data/models/user_name_check_model.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String sigingMethod = '/sigingMethod';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String addinfo = '/addinfo';
  static const String avatarProfile = '/avatarProfile';
  static const String tabbar = '/tabbar';
  static const String home = '/home';
  static const String notification = "/notification";
  // halaqa screens navigation
  static const String halaqa = "/halaqa";
  static const String halaqaAudio = '/halaqaAudio';
  // dua screens navigation
  static const String dua = '/dua';
  static const String addDua = '/addDua';
  // constac screens navigation
  static const String contact = '/contact';
  // settings screens navigation
  static const String settingScreen = '/settingScreen';
  static const String profileStatus = '/profileStatus';
  static const String block = '/block';
  static const String subscription = '/subscription';
  static const String story = '/story';
  static const String bio = '/bio';
  static const String profile = '/profile';
  static const String statuswrite = '/statuswrite';
  static const String themeColorPicker = '/themeColorPicker';
  // ummah group screens navigation
  static const String ummahInformation = '/ummahInformation';
  static const String ummahAddDetail1 = '/ummahAddDetail1';
  static const String ummahAddDetail2 = '/ummahAddDetail2';
  static const String ummahChatScreen = '/ummanhChatScreen';
  static const String ummahProfile = '/ummahProfile';
  // Single chat screens navigations
  static const String universalChat = '/universalChat';
  static const String chatProfile = '/chatProfile';
  static const String contactListScreen = '/contactListScreen';
  static const String starredMessages = '/starredMessages';
  static const String chatMedia = '/chatMedia';
  // Catalog screens navigation
  static const String catalogDetail = '/catalogDetail';
  static const String catalogList = '/catalogList';

  //group
  static const String groupInfo = '/group-info';
  // Story chat screens navigations
  static const String storyUpload = '/storyUpload';
  static const String myStoryView = "/myStoryView";

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case sigingMethod:
        return MaterialPageRoute(builder: (_) => const SigninMethodScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case otp:
        return MaterialPageRoute(builder: (_) => const OtpScreen());
      case addinfo:
        return MaterialPageRoute(builder: (_) => const AddInfoScreen());
      case avatarProfile:
        return MaterialPageRoute(builder: (_) => const AvatarProfile());
      case tabbar:
        return MaterialPageRoute(builder: (_) => const NewTabbarScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case notification:
        return MaterialPageRoute(builder: (_) => const NotiificationList());
      //====================== settings screens ====================================
      case settingScreen:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case profileStatus:
        return MaterialPageRoute(builder: (_) => const ProfileStatus());
      case block:
        return MaterialPageRoute(builder: (_) => const BlockListScreen());
      case story:
        return MaterialPageRoute(builder: (_) => const StoryList());
      case bio:
        return MaterialPageRoute(builder: (_) => const StatusScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case statuswrite:
        return MaterialPageRoute(builder: (_) => const StatusWriteScreen());
      case themeColorPicker:
        return MaterialPageRoute(builder: (_) => const ThemeColorPicker());
      //*********************** single chat screens ***********************************
      // case singleChat:
      //   // Extract arguments for the chat screen
      //   final args = settings.arguments as Map<String, dynamic>?;

      //   if (args == null) {
      //     // Handle case where arguments are missing
      //     return MaterialPageRoute(
      //       builder:
      //           (_) => Scaffold(
      //             body: Center(child: Text('Invalid chat arguments')),
      //           ),
      //     );
      //   }

      //   return MaterialPageRoute(
      //     builder:
      //         (_) => OneToOneChat(
      //           chatId: args['chatId'] as int? ?? 0,
      //           userId: args['userId'] as int,
      //           fullName: args['fullName'] as String? ?? '',
      //           profilePic: args['profilePic'] as String? ?? '',
      //           updatedAt: args['updatedAt'] as String?,
      //         ),
      //   );
      //✅ UPDATED: Universal chat screens for both individual and group
      case groupInfo:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder:
              (_) => GroupInfoScreen(
                groupName: args?['groupName'] ?? 'Unknown Group',
                groupDescription: args?['groupDescription'],
                groupImage: args?['groupImage'],
                groupId: args?['groupId'],
                memberCount: args?['memberCount'] ?? 0,
                onGroupDeleted: args?['onGroupDeleted'],
              ),
        );
      case universalChat:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) {
          return MaterialPageRoute(
            builder:
                (_) => Scaffold(
                  body: Center(child: Text('Invalid chat arguments')),
                ),
          );
        }

        return MaterialPageRoute(
          builder:
              (_) => UniversalChatScreen(
                //              key: ValueKey(
                //   'chat_${args['chatId'] ?? args['userId']}_${args['isGroupChat'] ?? false}',
                // ),
                userId: args['userId'] as int?,
                profilePic: args['profilePic'] as String? ?? '',
                chatName: args['chatName'] as String? ?? '',
                chatId: args['chatId'] as int?,
                updatedAt: args['updatedAt'] as String?,
                isGroupChat: args['isGroupChat'] as bool? ?? false,
                groupDescription: args['groupDescription'] as String?,
                blockFlag:
                    args['blockFlag'] as bool? ??
                    false, // Pass instant block status
                highlightMessageId:
                    args['highlightMessageId']
                        as int?, // Pass highlight message ID
                fromArchive:
                    args['fromArchive'] as bool? ??
                    false, // Pass navigation source flag
              ),
          settings: settings,
        );

      //====================== Contact screens ======================================
      // case contactListScreen:
      //   return MaterialPageRoute(builder: (_) => const ContactListScreen());
      case contactListScreen:
        // Expecting: {'createGroupMode': true, 'isAddMemberMode': false, 'groupId': 'some-id'} or {}
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final createGroupMode = args['createGroupMode'] as bool? ?? false;
        final isAddMemberMode = args['isAddMemberMode'] as bool? ?? false;
        final groupId = args['groupId'] as int?;
        final existingMemberIds = args['existingMemberIds'] as List<int>?;
        final isForAddMoreMember = args['isForAddMoreMember'] as bool? ?? false;

        return MaterialPageRoute(
          builder:
              (_) => ContactListScreen(
                createGroupMode: createGroupMode,
                isAddMemberMode: isAddMemberMode,
                groupId: groupId,
                isForAddMoreMember: isForAddMoreMember,
                existingMemberIds: existingMemberIds,
              ),
        );

      //********************** STORY SCREENS *****************************************/
      case storyUpload:
        return MaterialPageRoute(builder: (_) => const StoryUpload());
      case myStoryView:
        return MaterialPageRoute(
          builder: (_) => MyStoriesView(isMyStory: true, initialIndex: 0),
        );

      //********************** STARRED MESSAGES SCREEN *****************************/
      case starredMessages:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder:
              (_) => StarredMessagesScreen(
                chatId: args?['chatId'] as int?,
                chatName: args?['chatName'] as String?,
                fromProfileOrGroupInfo:
                    args?['fromProfileOrGroupInfo'] as bool? ?? false,
              ),
          settings: settings,
        );

      //********************** CHAT MEDIA SCREEN *****************************/
      case chatMedia:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder:
              (_) => ChatMediaScreen(
                chatId: args?['chatId'] as int? ?? 0,
                chatName: args?['chatName'] as String? ?? 'Chat',
              ),
          settings: settings,
        );

      //********************** CATALOG SCREENS *****************************/
      case catalogDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        final catalog = args?['catalog'] as Catalog;
        return MaterialPageRoute(
          builder: (_) => CatalogDetailScreen(catalog: catalog),
          settings: settings,
        );

      case catalogList:
        final args = settings.arguments as Map<String, dynamic>?;
        final catalogs = args?['catalogs'] as List<Catalog>;
        final businessName = args?['businessName'] as String? ?? 'Business';
        return MaterialPageRoute(
          builder:
              (_) => CatalogListScreen(
                catalogs: catalogs,
                businessName: businessName,
              ),
          settings: settings,
        );

      case '/': // Handle root route
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      default:
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
                body: Center(
                  child: Text('No route defined for ${settings.name}'),
                ),
              ),
        );
    }
  }
}
