// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_svg/svg.dart';
// import 'package:provider/provider.dart';
// import 'package:whoxa/core/navigation_helper.dart';
// import 'package:whoxa/core/services/socket/socket_event_controller.dart';
// import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
// import 'package:whoxa/featuers/home/provider/home_provider.dart';
// import 'package:whoxa/featuers/home/screens/chat_list.dart';
// import 'package:whoxa/utils/app_size_config.dart';
// import 'package:whoxa/utils/logger.dart';
// import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
// import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
// import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
// import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
// import 'package:whoxa/widgets/custom_bottomsheet.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
//   bool isBtnShow = true;
//   bool _initializing = true;
//   String? _error;
//   final ConsoleAppLogger _logger = ConsoleAppLogger();

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);

//     // Initialize socket connection and fetch chat list after frame is rendered
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       await _initializeSocket();
//     });
//   }

//   Future<void> _initializeSocket() async {
//     _logger.i('Initializing socket on HomeScreen');
//     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
//     // Get SocketEventController directly from provider
//     final socketEventController = Provider.of<SocketEventController>(
//       context,
//       listen: false,
//     );

//     setState(() {
//       _initializing = true;
//       _error = null;
//     });

//     try {
//       // Check if socket is already connected through the controller
//       if (!socketEventController.isConnected) {
//         _logger.i('Socket not connected, connecting...');
//         final connected = await chatProvider.connect();
//         if (!connected) {
//           setState(() {
//             _error = "Could not connect to chat server";
//             _initializing = false;
//           });
//           return;
//         }
//       }

//       // Request chat list
//       await chatProvider.refreshChatList();

//       setState(() {
//         _initializing = false;
//       });
//     } catch (e) {
//       _logger.e('Error during socket initialization', e);
//       setState(() {
//         _error = "Error connecting: ${e.toString()}";
//         _initializing = false;
//       });
//     }
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   @override
//   void didChangeMetrics() {
//     final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
//     setState(() {
//       isBtnShow = bottomInset == 0.0;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     SizeConfig().init(context);
//     SystemChrome.setSystemUIOverlayStyle(
//       const SystemUiOverlayStyle(
//         statusBarColor: Colors.transparent,
//         statusBarIconBrightness: Brightness.dark,
//         statusBarBrightness: Brightness.light,
//       ),
//     );

//     return Container(
//       decoration: BoxDecoration(
//         image: DecorationImage(
//           image: AssetImage(AppAssets.splash1),
//           fit: BoxFit.cover,
//         ),
//       ),
//       child: Scaffold(
//         backgroundColor: AppColors.transparent,
//         appBar: AppBar(
//           backgroundColor: AppColors.transparent,
//           flexibleSpace: Container(
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.center,
//                 colors: [
//                   AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.08),
//                   AppColors.transparent,
//                 ],
//               ),
//             ),
//           ),
//           leading: Padding(
//             padding: SizeConfig.getPaddingOnly(left: 10),
//             child: Image.asset(AppAssets.rabtahLogo, fit: BoxFit.cover),
//           ),
//           toolbarHeight: 40,
//           actions: [
//             // Anywhere in your UI (e.g. from a FAB on HomeScreen):
//             TextButton(
//               child: Text('New Group'),
//               onPressed: () {
//                 Navigator.of(context).pushNamed(
//                   AppRoutes.contactListScreen,
//                   arguments: {'createGroupMode': true},
//                 );
//               },
//             ),

//             SvgPicture.asset(AppAssets.homeIcons.statusSvg),
//             SizedBox(width: SizeConfig.width(3)),
//             SvgPicture.asset(AppAssets.homeIcons.notification),
//             SizedBox(width: SizeConfig.width(5)),
//           ],
//         ),
//         body: Consumer<HomeProvider>(
//           builder: (context, homeProvider, child) {
//             if (_initializing) {
//               return const Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     CircularProgressIndicator(),
//                     SizedBox(height: 20),
//                     Text("Connecting to chat service..."),
//                   ],
//                 ),
//               );
//             }

//             if (_error != null) {
//               return Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.error_outline, size: 48, color: Colors.red),
//                     SizedBox(height: 16),
//                     Text(_error!, style: AppTypography.h4(context)),
//                     SizedBox(height: 16),
//                     ElevatedButton(
//                       onPressed: () => _initializeSocket(),
//                       child: Text("Retry"),
//                     ),
//                   ],
//                 ),
//               );
//             }

//             return Column(
//               children: [
//                 SizedBox(height: SizeConfig.height(2.5)),
//                 _buildTabs(homeProvider),
//                 SizedBox(height: SizeConfig.height(2.5)),
//                 Expanded(
//                   child: PageView(
//                     controller: homeProvider.pageController,
//                     onPageChanged: homeProvider.updateIndex,
//                     children: [
//                       _buildChatTab(),
//                       Center(child: Text("Ibadah Group Tab")),
//                       Center(child: Text("Ummah Updates Tab")),
//                     ],
//                   ),
//                 ),
//               ],
//             );
//           },
//         ),
//         floatingActionButton:
//             isBtnShow
//                 ? FloatingActionButton(
//                   backgroundColor: AppColors.appPriSecColor.primaryColor,
//                   child: Icon(Icons.add, color: Colors.white),
//                   onPressed: () => bottomSheetDesigin(),
//                 )
//                 : null,
//       ),
//     );
//   }

//   Widget _buildChatTab() {
//     return Consumer2<ChatProvider, SocketEventController>(
//       builder: (context, chatProvider, socketEventController, _) {
//         // Get socket connection status from the SocketEventController
//         final isConnected = socketEventController.isConnected;

//         return Column(
//           children: [
//             // Connection status indicator
//             if (!isConnected)
//               Container(
//                 width: double.infinity,
//                 color: Colors.orange.withValues(alpha: 0.7),
//                 padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
//                 child: Row(
//                   children: [
//                     Icon(Icons.wifi_off, size: 16, color: Colors.white),
//                     SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         "Connection to chat server lost. Reconnecting...",
//                         style: TextStyle(color: Colors.white, fontSize: 12),
//                       ),
//                     ),
//                     InkWell(
//                       onTap: () => chatProvider.connect(),
//                       child: Icon(Icons.refresh, size: 16, color: Colors.white),
//                     ),
//                   ],
//                 ),
//               ),

//             // Chat list (takes remaining space)
//             Expanded(
//               child: RefreshIndicator(
//                 onRefresh: () => chatProvider.refreshChatList(),
//                 child: Padding(
//                   padding: const EdgeInsets.only(bottom: 20),
//                   child: ChatList(
//                     onTap: (chatId, peerUser) {
//                       // Navigator.pushNamed(
//                       //   context,
//                       //   AppRoutes.singleChat,
//                       //   arguments: {"chatId": chatId, "peerUser": peerUser},
//                       // );
//                       NavigationHelper.navigateToChat(
//                         context,
//                         chatId: chatId,
//                         userId: peerUser.userId!,
//                         fullName: peerUser.fullName ?? 'unknown',
//                         profilePic: peerUser.profilePic ?? '',
//                       );
//                     },
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildTabs(HomeProvider homeProvider) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//       children: [
//         _buildTabItem(homeProvider, "Chat", 0),
//         _buildTabItem(homeProvider, "Ibadah Group", 1),
//         _buildTabItem(homeProvider, "Ummah Updates", 2),
//       ],
//     );
//   }

//   Widget _buildTabItem(HomeProvider homeProvider, String title, int index) {
//     bool isSelected = homeProvider.selectedIndex == index;
//     return InkWell(
//       onTap:
//           () => homeProvider.pageController.animateToPage(
//             index,
//             duration: Duration(milliseconds: 300),
//             curve: Curves.easeInOut,
//           ),
//       child: Column(
//         children: [
//           Text(
//             title,
//             style:
//                 isSelected
//                     ? AppTypography.h4(context)
//                     : AppTypography.smallText(context),
//           ),
//           Container(
//             height: 2,
//             width: 20,
//             color:
//                 isSelected
//                     ? AppColors.appPriSecColor.primaryColor
//                     : Colors.transparent,
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> bottomSheetDesigin() {
//     return bottomSheetGobal(
//       context,
//       bottomsheetHeight: SizeConfig.height(23),
//       title: "Create Group",
//       child: Container(), // customize as needed
//     );
//   }
// }

// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/core/navigation_helper.dart';
import 'package:whoxa/core/services/socket/socket_event_controller.dart';
import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
import 'package:whoxa/featuers/chat/provider/archive_chat_provider.dart';
import 'package:whoxa/featuers/chat/screens/archived_chat_list_screen.dart';
import 'package:whoxa/featuers/home/provider/home_provider.dart';
import 'package:whoxa/featuers/home/screens/chat_list.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/utils/app_size_config.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/utils/preference_key/constant/app_assets.dart';
import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
import 'package:whoxa/utils/preference_key/constant/app_theme_manage.dart';
import 'package:whoxa/utils/preference_key/constant/strings.dart';
import 'package:whoxa/widgets/cusotm_blur_appbar.dart';
import 'package:whoxa/widgets/custom_bottomsheet.dart';
import 'package:whoxa/widgets/global.dart';
import 'package:whoxa/widgets/global_textfield.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  bool isBtnShow = true;
  bool _initializing = false;
  String? _error;
  final ConsoleAppLogger _logger = ConsoleAppLogger();
  bool _hasInitialized = false;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  FocusNode searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize socket connection and fetch chat list after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      searchFocusNode = FocusNode();
      if (!_hasInitialized) {
        await _initializeSocket();
      }
    });
  }

  Future<void> _initializeSocket() async {
    if (kDebugMode) {
      _logger.i('Initializing socket on HomeScreen');
    }
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final socketEventController = Provider.of<SocketEventController>(
      context,
      listen: false,
    );
    final archiveChatProvider = Provider.of<ArchiveChatProvider>(
      context,
      listen: false,
    );

    // Check if already connected and has data - skip reloading
    if (socketEventController.isConnected &&
        chatProvider.chatListData.chats.isNotEmpty &&
        _hasInitialized) {
      if (kDebugMode) {
        _logger.i('Socket already connected and data loaded, skipping reload');
      }
      return;
    }

    setState(() {
      _initializing = true;
      _error = null;
    });

    try {
      // ✅ UPDATED: Archive chat provider is already set up in provider_list.dart at app startup
      // But we still set up the callback for archive status changes here
      archiveChatProvider.setOnArchiveStatusChanged((chatId, isArchived) {
        if (isArchived) {
          chatProvider.addArchivedChatId(chatId);
        } else {
          chatProvider.removeArchivedChatId(chatId);
        }
      });

      // Check if socket is already connected through the controller
      if (!socketEventController.isConnected) {
        if (kDebugMode) {
          _logger.i('Socket not connected, connecting...');
        }
        final connected = await chatProvider.connect();
        if (!connected) {
          setState(() {
            _error = "Could not connect to chat server";
            _initializing = false;
          });
          return;
        }
      }

      // Only fetch chat list if not already loaded
      if (chatProvider.chatListData.chats.isEmpty) {
        if (kDebugMode) {
          _logger.i('Chat list empty, fetching data...');
        }
        await chatProvider.refreshChatList();
      } else {
        if (kDebugMode) {
          _logger.i('Chat list already loaded, skipping API call');
        }
      }

      // ✅ NEW: Initialize archived chats (completely optional and non-blocking)
      // Only fetch if not already loaded and the backend might support it
      if (archiveChatProvider.archivedChats.isEmpty) {
        try {
          if (kDebugMode) {
            _logger.i('Fetching archived chats...');
          }
          await archiveChatProvider.fetchArchivedChats();
        } catch (e) {
          if (kDebugMode) {
            _logger.w('Archived chats feature not available: $e');
          }
        }
      }

      setState(() {
        _initializing = false;
        _hasInitialized = true;
      });
    } catch (e) {
      if (kDebugMode) {
        _logger.e('Error during socket initialization', e);
      }
      setState(() {
        _error = "Error connecting: ${e.toString()}";
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    setState(() {
      isBtnShow = bottomInset == 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    SizeConfig().init(context);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppThemeManage.appTheme.scaffoldBackColor,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          elevation: 0,
          backgroundColor: AppColors.transparent,
          systemOverlayStyle: systemUI(),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  AppColors.appPriSecColor.secondaryColor.withValues(
                    alpha: 0.08,
                  ),
                  AppColors.transparent,
                ],
              ),
            ),
          ),
          title: AppThemeManage.appTheme.appHomelogo,
          toolbarHeight: kToolbarHeight,
          actions: [
            Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                return InkWell(
                  onTap: () {
                    Provider.of<ProjectConfigProvider>(
                      context,
                      listen: false,
                    ).fetchNotificationList();
                    Navigator.pushNamed(context, AppRoutes.notification).then((
                      _,
                    ) async {
                      await chatProvider.countApi();
                    });
                  },
                  child: Container(
                    height: SizeConfig.sizedBoxHeight(36),
                    width: SizeConfig.sizedBoxWidth(36),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppThemeManage.appTheme.borderColor,
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: SizeConfig.getPadding(8),
                          child: SvgPicture.asset(
                            AppAssets.homeIcons.notification,
                            color: AppThemeManage.appTheme.darkWhiteColor,
                            height: SizeConfig.sizedBoxHeight(20),
                          ),
                        ),
                        Positioned(
                          right: 5.5,
                          top: 2,
                          child:
                              chatProvider.notificationCount == 0
                                  ? SizedBox.shrink()
                                  : Container(
                                    height: SizeConfig.sizedBoxHeight(14),
                                    width: SizeConfig.sizedBoxWidth(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      color:
                                          AppColors.appPriSecColor.primaryColor,
                                    ),
                                    child: Center(
                                      child: Text(
                                        chatProvider.notificationCount
                                            .toString(),
                                        style: AppTypography.innerText10(
                                          context,
                                        ).copyWith(fontSize: 9),
                                      ),
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(width: SizeConfig.width(5)),
          ],
        ),
        body: Consumer<HomeProvider>(
          builder: (context, homeProvider, child) {
            if (_initializing) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    commonLoading(),
                    SizedBox(height: 20),
                    Text("${AppString.connectingToChatService}..."),
                  ],
                ),
              );
            }

            if (_error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    SizedBox(height: 16),
                    Text(_error!, style: AppTypography.h4(context)),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _initializeSocket(),
                      child: Text(AppString.retry),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                SizedBox(height: SizeConfig.height(2)),
                Padding(
                  padding: SizeConfig.getPaddingSymmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppString.homeScreenString.chats,
                        style: AppTypography.h2(context).copyWith(
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTypography.fontFamily.poppinsBold,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.contactListScreen,
                            arguments: {
                              'isAddMemberMode': true,
                              // 'createGroupMode': true,
                            },
                          );
                        },
                        child: Container(
                          height: SizeConfig.sizedBoxHeight(30),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.appPriSecColor.secondaryColor,
                          ),
                          child: Padding(
                            padding: SizeConfig.getPaddingSymmetric(
                              horizontal: 10,
                            ),
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  AppAssets.homeIcons.newgp,
                                  color: ThemeColorPalette.getTextColor(
                                    AppColors.appPriSecColor.primaryColor,
                                  ),
                                  height: SizeConfig.sizedBoxHeight(15),
                                ),
                                SizedBox(width: SizeConfig.width(1)),
                                Text(
                                  AppString.homeScreenString.newGroup,
                                  style: AppTypography.text12(context).copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: ThemeColorPalette.getTextColor(
                                      AppColors.appPriSecColor.primaryColor,
                                    ),
                                    //AppThemeManage.appTheme.darkWhiteColor,
                                    fontSize: SizeConfig.getFontSize(10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // SizedBox(height: SizeConfig.height(1)),

                // Add search bar only for chat tab
                if (homeProvider.selectedIndex == 0) _buildSearchBar(),
                SizedBox(height: SizeConfig.height(1.5)),
                Expanded(child: _buildChatTab()),
              ],
            );
          },
        ),
        // floatingActionButton:
        //     isBtnShow
        //         ? FloatingActionButton(
        //           backgroundColor: AppColors.appPriSecColor.primaryColor,
        //           child: Icon(Icons.add, color: Colors.white),
        //           onPressed: () => bottomSheetDesigin(),
        //         )
        //         : null,
      ),
    );
  }

  Widget _buildChatTab() {
    return Consumer2<ChatProvider, SocketEventController>(
      builder: (context, chatProvider, socketEventController, _) {
        // Get socket connection status from the SocketEventController
        final isConnected = socketEventController.isConnected;

        if (kDebugMode) {
          debugPrint(
            '🔌 _buildChatTab: isConnected = $isConnected (from SocketEventController)',
          );
        }

        return Column(
          children: [
            // Connection status indicator - Fixed to properly respond to reconnection
            // AnimatedSwitcher(
            //   duration: Duration(milliseconds: 300),
            //   child:
            //       !isConnected
            //           ? Container(
            //             key: ValueKey('disconnected'),
            //             width: double.infinity,
            //             color: Colors.orange.withValues(alpha: 0.7),
            //             padding: EdgeInsets.symmetric(
            //               vertical: 4,
            //               horizontal: 16,
            //             ),
            //             child: Row(
            //               children: [
            //                 Icon(Icons.wifi_off, size: 16, color: Colors.white),
            //                 SizedBox(width: 8),
            //                 Expanded(
            //                   child: Text(
            //                     "${AppString.connectionTochatServerlostReconnecting}...",
            //                     style: TextStyle(
            //                       color: Colors.white,
            //                       fontSize: 12,
            //                     ),
            //                   ),
            //                 ),
            //                 InkWell(
            //                   onTap: () => chatProvider.connect(),
            //                   child: Icon(
            //                     Icons.refresh,
            //                     size: 16,
            //                     color: Colors.white,
            //                   ),
            //                 ),
            //               ],
            //             ),
            //           )
            //           : SizedBox(
            //             key: ValueKey('connected'),
            //             width: double.infinity,
            //             height: 0, // Hide when connected
            //           ),
            // ),

            // ✅ UPDATED: Chat list (with pagination support)
            // Expanded(
            //   child: RefreshIndicator(
            //     onRefresh: () => chatProvider.refreshChatList(),
            //     child: Padding(
            //       padding: const EdgeInsets.only(bottom: 20),
            //       child: ChatList(
            //         onTap: (
            //           chatId,
            //           peerUser, {
            //           chatType,
            //           groupName,
            //           groupIcon,
            //         }) {
            //           if (chatType?.toLowerCase() == 'group') {
            //             NavigationHelper.navigateToGroupChat(
            //               context,
            //               chatId: chatId,
            //               groupName: groupName ?? 'Group Chat',
            //               groupProfilePic:
            //                   groupIcon ??
            //                   peerUser.profilePic ??
            //                   '', // Use groupIcon first, fallback to peerUser profilePic
            //             );
            //           } else {
            //             NavigationHelper.navigateToChat(
            //               context,
            //               chatId: chatId,
            //               userId: peerUser.userId!,
            //               fullName: peerUser.fullName ?? 'unknown',
            //               profilePic: peerUser.profilePic ?? '',
            //             );
            //           }
            //         },
            //       ),
            //     ),
            //   ),
            // ),
            Expanded(
              child: Column(
                children: [
                  // ✅ NEW: Archived Chats Section
                  Consumer<ArchiveChatProvider>(
                    builder: (context, archiveChatProvider, _) {
                      // if (archiveChatProvider.hasArchivedChats) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppThemeManage.appTheme.borderColor,
                            ),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: SizeConfig.getPaddingOnly(
                            left: 30,
                            right: 20,
                          ),
                          leading: Icon(
                            Icons.archive_outlined,
                            color: AppColors.appPriSecColor.primaryColor,
                            size: SizeConfig.sizedBoxHeight(30),
                          ),
                          title: Text(
                            AppString.homeScreenString.archived,
                            style: AppTypography.innerText14(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppThemeManage.appTheme.textGreyWhite,
                            ),
                          ),

                          trailing: chatCountContainer(
                            context,
                            count: archiveChatProvider.archivedChats.length,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ArchivedChatListScreen(
                                      onChatTap: (
                                        chatId,
                                        peerUser, {
                                        chatType,
                                        groupName,
                                        groupIcon,
                                        groupDescription,
                                      }) {
                                        // Navigate to the chat from archived screen
                                        // Note: We don't pop the archived screen so back navigation works correctly
                                        if (chatType?.toLowerCase() ==
                                            'group') {
                                          NavigationHelper.navigateToGroupChat(
                                            context,
                                            chatId: chatId,
                                            groupName:
                                                groupName ?? 'Group Chat',
                                            groupProfilePic: groupIcon ?? '',
                                            groupDescription: groupDescription,
                                            fromArchive:
                                                true, // Mark as from archive
                                          );
                                        } else {
                                          NavigationHelper.navigateToChat(
                                            context,
                                            chatId: chatId,
                                            userId: peerUser.userId!,
                                            fullName:
                                                peerUser.fullName ?? 'unknown',
                                            profilePic:
                                                peerUser.profilePic ?? '',
                                            fromArchive:
                                                true, // Mark as from archive
                                          );
                                        }
                                      },
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                      // } else {
                      //   return const SizedBox.shrink();
                      // }
                    },
                  ),

                  // ✅ Chat List with Search Integration
                  Expanded(
                    child: Consumer<ChatProvider>(
                      builder: (context, chatProvider, _) {
                        // Show search results if searching, otherwise show regular chat list
                        if (chatProvider.isSearching) {
                          return _buildSearchResults(context, chatProvider);
                        } else {
                          return _buildRegularChatList(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ✅ NEW: Global pagination loading indicator at bottom
            if (kDebugMode && chatProvider.isChatListPaginationLoading)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8),
                color: AppColors.appPriSecColor.primaryColor.withValues(
                  alpha: 0.05,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: commonLoading()),
                    SizedBox(width: 8),
                    Text(
                      "${AppString.loadingMoreChats}...",
                      style: AppTypography.smallText(context).copyWith(
                        color: AppColors.appPriSecColor.primaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build search bar widget
  Widget _buildSearchBar() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return Padding(
          padding: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 0),
          child: GlobalTextField1(
            controller: _searchController,
            onEditingComplete: () {},
            hintText: AppString.homeScreenString.searchUser,
            context: context,
            preffixIcon: Padding(
              padding: SizeConfig.getPadding(15),
              child: SvgPicture.asset(
                AppAssets.homeIcons.search,
                colorFilter: ColorFilter.mode(
                  AppColors.textColor.textDarkGray,
                  BlendMode.srcIn,
                ),
                height: SizeConfig.safeHeight(2),
              ),
            ),
            suffixIcon:
                chatProvider.isSearching || _searchController.text.isNotEmpty
                    ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: AppColors.textColor.textDarkGray,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        chatProvider.clearSearch();
                      },
                    )
                    : null,
            keyboardType: TextInputType.name,
            onChanged: (value) {
              // Cancel previous timer
              _searchDebounceTimer?.cancel();

              if (value.trim().isEmpty) {
                // Clear search immediately if empty
                chatProvider.clearSearch();
                return;
              }

              // Debounced search - wait 500ms after user stops typing
              _searchDebounceTimer = Timer(
                const Duration(milliseconds: 500),
                () {
                  if (value.trim().isNotEmpty) {
                    chatProvider.searchChats(value.trim());
                  }
                },
              );
            },
          ),
        );
        // Container(
        //   margin: SizeConfig.getPaddingSymmetric(horizontal: 20, vertical: 2),
        //   height: 45, // Fixed compact height
        //   decoration: BoxDecoration(
        //     color: AppColors.strokeColor.cF9F9F9,
        //     borderRadius: BorderRadius.circular(10),
        //     border: Border.all(
        //       color: AppColors.strokeColor.cECECEC,
        //       // chatProvider.isSearching
        //       //     ? AppColors.appPriSecColor.primaryColor
        //       //     : Colors.grey[300]!,
        //       width: 1,
        //     ),
        //     boxShadow: [
        //       BoxShadow(
        //         color: Colors.black.withValues(alpha: 0.05),
        //         blurRadius: 4,
        //         offset: Offset(0, 2),
        //       ),
        //     ],
        //   ),
        //   child: TextFormField(
        //     controller: _searchController,
        //     textAlignVertical: TextAlignVertical.center,
        //     style: AppTypography.text12(
        //       context,
        //     ).copyWith(fontSize: SizeConfig.getFontSize(13)),
        //     autofocus: false,
        //     focusNode: searchFocusNode,
        //     onChanged: (value) {
        //       // Cancel previous timer
        //       _searchDebounceTimer?.cancel();

        //       if (value.trim().isEmpty) {
        //         // Clear search immediately if empty
        //         chatProvider.clearSearch();
        //         return;
        //       }

        //       // Debounced search - wait 500ms after user stops typing
        //       _searchDebounceTimer = Timer(
        //         const Duration(milliseconds: 500),
        //         () {
        //           if (value.trim().isNotEmpty) {
        //             chatProvider.searchChats(value.trim());
        //           }
        //         },
        //       );
        //     },
        //     decoration: InputDecoration(
        //       hintText: AppString.homeScreenString.searchUser,
        //       hintStyle: AppTypography.text12(context).copyWith(
        //         fontSize: SizeConfig.getFontSize(13),
        //         color: Colors.grey[600],
        //       ),
        //       prefixIcon: Padding(
        //         padding: SizeConfig.getPadding(15),
        //         child: SvgPicture.asset(
        //           AppAssets.homeIcons.search,
        //           colorFilter: ColorFilter.mode(
        //             AppColors.textColor.textDarkGray,
        //             BlendMode.srcIn,
        //           ),
        //           height: SizeConfig.safeHeight(2),
        //         ),
        //       ),
        //       suffixIcon:
        //           chatProvider.isSearching || _searchController.text.isNotEmpty
        //               ? IconButton(
        //                 icon: Icon(
        //                   Icons.clear,
        //                   color: AppColors.textColor.textDarkGray,
        //                   size: 18,
        //                 ),
        //                 onPressed: () {
        //                   _searchController.clear();
        //                   chatProvider.clearSearch();
        //                 },
        //               )
        //               : null,
        //       border: InputBorder.none,
        //       contentPadding: SizeConfig.getPaddingSymmetric(
        //         horizontal: 12,
        //         vertical: 8,
        //       ),
        //       isDense: true,
        //     ),
        //   ),
        // );
      },
    );
  }

  /// Build search results view
  Widget _buildSearchResults(BuildContext context, ChatProvider chatProvider) {
    // Loading state
    if (chatProvider.isSearchLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            commonLoading(),
            SizedBox(height: 16),
            Text("Searching chats..."),
          ],
        ),
      );
    }

    final searchResults = chatProvider.searchResults.chats;

    // Empty results
    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              chatProvider.currentSearchQuery.isNotEmpty
                  ? 'No chats found for "${chatProvider.currentSearchQuery}"'
                  : 'No search results',
              textAlign: TextAlign.center,
              style: AppTypography.h4(
                context,
              ).copyWith(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: AppTypography.smallText(
                context,
              ).copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Search Results List
    return Column(
      children: [
        // Results header
        // Container(
        //   padding: SizeConfig.getPaddingSymmetric(horizontal: 16, vertical: 8),
        //   child: Row(
        //     children: [
        //       Icon(
        //         Icons.search,
        //         size: 16,
        //         color: AppColors.appPriSecColor.primaryColor,
        //       ),
        //       SizedBox(width: 8),
        //       Text(
        //         '${searchResults.length} result(s) found',
        //         style: AppTypography.smallText(context).copyWith(
        //           color: AppColors.appPriSecColor.primaryColor,
        //           fontWeight: FontWeight.w500,
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        SizedBox(height: SizeConfig.height(1)),

        // Results list using the same ChatList widget for consistency
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ListView.separated(
              itemCount: searchResults.length,
              separatorBuilder: (context, index) {
                return Divider(color: AppThemeManage.appTheme.borderColor);
              },
              itemBuilder: (context, index) {
                final chat = searchResults[index];
                return _buildSearchResultItem(chat);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Build individual search result item
  Widget _buildSearchResultItem(dynamic chat) {
    return Consumer2<ProjectConfigProvider, ChatProvider>(
      builder: (context, configProvider, chatProvider, _) {
        // Handle potential null values safely
        final peer = chat.peerUserData ?? PeerUserData();
        final record =
            chat.records?.isNotEmpty == true ? chat.records!.first : null;
        final lastMessage =
            record?.messages?.isNotEmpty == true
                ? record!.messages!.first
                : null;
        final chatType = record?.chatType ?? 'Private';
        final isGroupChat = chatType.toLowerCase() == 'group';

        // Get display name using the same logic as regular chat list
        final String displayName =
            isGroupChat
                ? _getGroupDisplayName(record, peer)
                : ContactNameService.instance.getDisplayName(
                  userId: peer.userId,
                  userFullName: peer.fullName,
                  userName: peer.userName,
                  userEmail: peer.email,
                  configProvider: configProvider,
                );

        final String profilePic = _getProfilePic(isGroupChat, record, peer);

        return InkWell(
          onTap: () {
            FocusScope.of(context).unfocus();
            searchFocusNode.unfocus();
            if (record?.chatId != null) {
              if (chatType.toLowerCase() == 'group') {
                NavigationHelper.navigateToGroupChat(
                  context,
                  chatId: record!.chatId!,
                  groupName: displayName,
                  groupProfilePic: profilePic,
                  groupDescription: record.groupDescription,
                );
              } else {
                if (kDebugMode) {
                  debugPrint(
                    'HomeScreen: Navigating to individual chat from search with peerUser.userId: ${peer.userId}',
                  );
                }
                NavigationHelper.navigateToChat(
                  context,
                  chatId: record!.chatId!,
                  userId: peer.userId!,
                  fullName: peer.fullName ?? 'unknown',
                  profilePic: peer.profilePic ?? '',
                );
              }
            }
          },
          child: Container(
            padding: SizeConfig.getPaddingSymmetric(
              horizontal: 17,
              vertical: 5,
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  height: SizeConfig.sizedBoxHeight(50),
                  width: SizeConfig.sizedBoxWidth(50),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(55),
                    color: AppColors.white,
                    border: Border.all(
                      color: AppThemeManage.appTheme.borderColor,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(55),
                    child: _buildAvatar(profilePic, isGroupChat),
                  ),
                ),

                SizedBox(width: SizeConfig.width(3)),

                // Chat Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chat name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: AppTypography.innerText14(
                                context,
                              ).copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Chat type indicator
                          if (isGroupChat) ...[
                            Icon(
                              Icons.group,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ],
                          Text(
                            "  ${chatProvider.formatTime(_getChatTimestamp(record))}",
                            style: AppTypography.innerText10(context).copyWith(
                              color: AppColors.textColor.textGreyColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 4),

                      // Last message preview
                      if (lastMessage != null)
                        Row(
                          children: [
                            messageContentIcon(context, lastMessage),
                            SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                _getMessagePreview(lastMessage),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.smallText(
                                  context,
                                ).copyWith(
                                  color: AppColors.textColor.textGreyColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _getChatTimestamp(Records? record) {
    if (record == null) return null;

    // Priority: updatedAt -> createdAt -> null
    if (record.updatedAt != null && record.updatedAt!.trim().isNotEmpty) {
      return record.updatedAt;
    }

    if (record.createdAt != null && record.createdAt!.trim().isNotEmpty) {
      return record.createdAt;
    }

    return null;
  }

  /// Group display name logic - same as main chat list
  String _getGroupDisplayName(Records? record, PeerUserData? peer) {
    if (record?.groupName != null && record!.groupName!.trim().isNotEmpty) {
      return record.groupName!;
    }
    if (peer?.fullName != null && peer!.fullName!.trim().isNotEmpty) {
      return "${peer.fullName!} (Group)";
    }
    if (peer?.userName != null && peer!.userName!.trim().isNotEmpty) {
      return "${peer.userName!} (Group)";
    }
    return 'Group Chat';
  }

  /// Get profile picture URL - same as main chat list
  String _getProfilePic(bool isGroupChat, Records? record, PeerUserData? peer) {
    if (isGroupChat) {
      if (record?.groupIcon != null && record!.groupIcon!.isNotEmpty) {
        return record.groupIcon!;
      }
      return peer?.profilePic ?? '';
    } else {
      return peer?.profilePic ?? '';
    }
  }

  /// Build avatar widget - same as main chat list
  Widget _buildAvatar(String profilePic, bool isGroupChat) {
    if (profilePic.isNotEmpty) {
      return Image.network(
        profilePic,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(AppAssets.defaultUser, fit: BoxFit.cover);
        },
      );
    } else {
      return Image.asset(AppAssets.defaultUser, fit: BoxFit.cover);
    }
  }

  /// Get message preview text
  String _getMessagePreview(Messages message) {
    switch (message.messageType?.toLowerCase()) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      case 'document':
      case 'doc':
      case 'pdf':
      case 'file':
        return 'Document';
      case 'location':
        return 'Location';
      case 'audio':
        return 'Audio';
      case 'gif':
        return 'GIF';
      case 'contact':
        return 'Contact';
      default:
        return message.messageContent ?? '';
    }
  }

  Widget messageContentIcon(BuildContext context, Messages message) {
    switch (message.messageType?.toLowerCase()) {
      case 'image':
        return SvgPicture.asset(
          AppAssets.chatMsgTypeIcon.galleryMsg,
          height: SizeConfig.sizedBoxHeight(14),
          color: AppColors.textColor.textDarkGray,
        );
      case 'video':
        return SvgPicture.asset(
          AppAssets.chatMsgTypeIcon.videoMsg,
          height: SizeConfig.sizedBoxHeight(14),
          color: AppColors.textColor.textDarkGray,
        );
      case 'document':
      case 'doc':
      case 'pdf':
      case 'file':
        return SvgPicture.asset(
          AppAssets.chatMsgTypeIcon.documentMsg,
          height: SizeConfig.sizedBoxHeight(14),
          color: AppColors.textColor.textDarkGray,
        );
      case 'location':
        return SvgPicture.asset(
          AppAssets.chatMsgTypeIcon.locationMsg,
          height: SizeConfig.sizedBoxHeight(14),
          color: AppColors.textColor.textDarkGray,
        );
      // case 'audio':
      //   return SvgPicture.asset(assetName);
      case 'gif':
        return SvgPicture.asset(
          AppAssets.chatMsgTypeIcon.gifMsg,
          height: SizeConfig.sizedBoxHeight(14),
          color: AppColors.textColor.textDarkGray,
        );
      case 'contact':
        return SvgPicture.asset(
          AppAssets.chatMsgTypeIcon.contactMsg,
          height: SizeConfig.sizedBoxHeight(14),
          color: AppColors.textColor.textDarkGray,
        );
      case 'link':
        return Transform.rotate(
          angle: math.pi / 1.5,
          child: Icon(
            Icons.link,
            size: SizeConfig.sizedBoxHeight(15),
            color: AppColors.textColor.textDarkGray,
          ),
        );
      default:
        return SizedBox.shrink();
    }
  }

  /// Build regular chat list view
  Widget _buildRegularChatList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ChatList(
        onTap: (
          chatId,
          peerUser, {
          chatType,
          groupName,
          groupIcon,
          groupDescription,
        }) {
          FocusScope.of(context).unfocus();
          searchFocusNode.unfocus();
          if (chatType?.toLowerCase() == 'group') {
            NavigationHelper.navigateToGroupChat(
              context,
              chatId: chatId,
              groupName: groupName ?? 'Group Chat',
              groupProfilePic: groupIcon ?? '',
              groupDescription: groupDescription,
            );
          } else {
            if (kDebugMode) {
              debugPrint(
                'HomeScreen: Navigating to individual chat with peerUser.userId: ${peerUser.userId}',
              );
            }
            toUserProfileCall = peerUser.profilePic ?? '';
            NavigationHelper.navigateToChat(
              context,
              chatId: chatId,
              userId: peerUser.userId!,
              fullName: peerUser.fullName ?? 'unknown',
              profilePic: peerUser.profilePic ?? '',
            );
          }
        },
      ),
    );
  }

  Future<void> bottomSheetDesigin() {
    return bottomSheetGobal(
      context,
      bottomsheetHeight: SizeConfig.height(23),
      title: "Create Group",
      child: Container(), // customize as needed
    );
  }
}
