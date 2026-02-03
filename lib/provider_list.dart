import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:stanchat/core/services/socket/socket_event_controller.dart';
import 'package:stanchat/dependency_injection.dart';
import 'package:stanchat/featuers/auth/provider/auth_provider.dart';
import 'package:stanchat/featuers/chat/group/provider/group_provider.dart';
import 'package:stanchat/featuers/chat/provider/chat_provider.dart';
import 'package:stanchat/featuers/chat/provider/archive_chat_provider.dart';
import 'package:stanchat/featuers/home/provider/home_provider.dart';
import 'package:stanchat/featuers/language_method/provider/language_provider.dart';
import 'package:stanchat/featuers/onboarding/Provider/onboarding_provider.dart';
import 'package:stanchat/featuers/call/call_provider.dart';
import 'package:stanchat/featuers/profile/provider/profile_provider.dart';
import 'package:stanchat/featuers/project-config/provider/config_provider.dart';
import 'package:stanchat/featuers/provider/theme_provider.dart';
import 'package:stanchat/featuers/provider/voice_provider.dart';
import 'package:stanchat/featuers/story/provider/story_provider.dart';
import 'package:stanchat/featuers/contacts/provider/contact_provider.dart';
import 'package:stanchat/featuers/provider/tabbar_provider.dart';
import 'package:stanchat/featuers/report/provider/report_provider.dart';
import 'package:stanchat/featuers/call/call_history/providers/call_history_provider.dart';

List<SingleChildWidget> appProviders = [
  // Core providers
  // Project Configuration Provider (should be first)
  ChangeNotifierProvider<ProjectConfigProvider>(
    create: (_) => getIt<ProjectConfigProvider>(),
  ),
  ChangeNotifierProvider<AuthProvider>(create: (_) => getIt<AuthProvider>()),
  ChangeNotifierProvider<TabbarProvider>(
    create: (_) => getIt<TabbarProvider>(),
  ),
  ChangeNotifierProvider<ProfileProvider>(
    create: (_) => getIt<ProfileProvider>(),
  ),
  ChangeNotifierProvider<ContactListProvider>(
    create: (_) => getIt<ContactListProvider>(),
  ),

  // ✅ FIXED: ArchiveChatProvider is now registered and linked in dependency_injection.dart
  ChangeNotifierProvider<ArchiveChatProvider>(
    create: (_) => getIt<ArchiveChatProvider>(),
  ),

  // Socket-related providers - FIXED ORDER AND INITIALIZATION
  // Use .value constructor to share the same instance across the app
  ChangeNotifierProvider<SocketEventController>.value(
    value: getIt<SocketEventController>(),
  ),

  // ChatProvider gets the shared SocketEventController instance
  ChangeNotifierProvider<ChatProvider>(
    create: (context) {
      // Get the SocketEventController from the context (already provided above)
      final socketEventController = context.read<SocketEventController>();
      final chatProvider = ChatProvider(
        getIt(),
        socketEventController,
        getIt(),
      );

      // Only initialize if socket is connected
      // The SocketManager will handle connection initialization
      return chatProvider;
    },
  ),

  // Feature providers
  ChangeNotifierProvider<HomeProvider>(create: (_) => getIt<HomeProvider>()),
  ChangeNotifierProvider<LanguageProvider>(
    create: (_) => getIt<LanguageProvider>(),
  ),
  ChangeNotifierProvider<OnboardingProvider>(
    create: (_) => getIt<OnboardingProvider>(),
  ),
  ChangeNotifierProvider<StoryProvider>(create: (_) => getIt<StoryProvider>()),
  ChangeNotifierProvider<GroupProvider>(create: (_) => getIt<GroupProvider>()),
  ChangeNotifierProvider<ReportProvider>(
    create: (_) => getIt<ReportProvider>(),
  ),
  ChangeNotifierProvider<ThemeProvider>(create: (_) => getIt<ThemeProvider>()),

  // Call-related providers
  ChangeNotifierProvider<CallHistoryProvider>(
    create: (_) => getIt<CallHistoryProvider>(),
  ),

  // ✅ Opus Call Provider (using dependency injection)
  ChangeNotifierProvider<CallProvider>(create: (_) => getIt<CallProvider>()),
  ChangeNotifierProvider<VoiceProvider>(create: (_) => getIt<VoiceProvider>()),
];
