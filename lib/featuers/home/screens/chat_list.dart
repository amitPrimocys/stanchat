// ignore_for_file: use_build_context_synchronously, duplicate_ignore

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:stanchat/core/services/socket/socket_event_controller.dart';
import 'package:stanchat/featuers/chat/data/chat_list_model.dart';
import 'package:stanchat/featuers/chat/provider/chat_provider.dart';
import 'package:stanchat/featuers/chat/provider/archive_chat_provider.dart';
import 'package:stanchat/featuers/chat/services/contact_name_service.dart';
import 'package:stanchat/featuers/contacts/provider/contact_provider.dart';
import 'package:stanchat/featuers/profile/screens/user_profile_view.dart';
import 'package:stanchat/featuers/project-config/provider/config_provider.dart';
import 'package:stanchat/utils/app_size_config.dart';
import 'package:stanchat/utils/preference_key/constant/app_assets.dart';
import 'package:stanchat/utils/preference_key/constant/app_colors.dart';
import 'package:stanchat/utils/preference_key/constant/app_direction_manage.dart';
import 'package:stanchat/utils/preference_key/constant/app_text_style.dart';
import 'package:stanchat/utils/preference_key/constant/app_theme_manage.dart';
import 'package:stanchat/utils/preference_key/constant/strings.dart';
import 'package:stanchat/widgets/custom_bottomsheet.dart';
import 'package:stanchat/widgets/global.dart';
import 'package:stanchat/featuers/chat/services/call_display_service.dart';
import 'package:stanchat/featuers/chat/services/call_preview_mapper.dart';

class ChatList extends StatefulWidget {
  // Enhanced onTap function to include groupIcon and groupDescription
  final Function(
    int chatId,
    PeerUserData peerUser, {
    String? chatType,
    String? groupName,
    String? groupIcon,
    String? groupDescription,
  })
  onTap;

  const ChatList({super.key, required this.onTap});

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;
  bool _isContactsLoading = true; // 🎯 NEW: Track contact loading state

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Initialize contact name service and load contacts cache
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeContactsForNameDisplay();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Initialize contacts for name display with loading state management
  void _initializeContactsForNameDisplay() async {
    try {
      // Initialize CallDisplayService to cache user ID for smooth call widgets
      await CallDisplayService().initializeWithUserId();

      // Check if widget is still mounted before using context
      if (!context.mounted) return;

      // Debug the current configuration
      final configProvider = Provider.of<ProjectConfigProvider>(
        context, // ignore: use_build_context_synchronously
        listen: false,
      );
      configProvider.debugLogConfigValues();

      // 🎯 NEW: Preload contacts with loading state management
      final contactProvider = Provider.of<ContactListProvider>(
        context, // ignore: use_build_context_synchronously
        listen: false,
      );

      // Set loading state to prevent UI from rendering prematurely
      if (mounted) {
        setState(() {
          _isContactsLoading = true;
        });
      }

      // Initialize contacts and wait for completion
      await contactProvider.initializeContacts();

      // Also ensure ContactNameService is properly loaded
      await ContactNameService.instance.loadAndCacheContacts();

      // Wait a brief moment to ensure all contact data is fully processed
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('✅ Contact initialization completed for name display');
      debugPrint(
        '✅ ContactNameService cache: ${ContactNameService.instance.cachedContactsCount} contacts',
      );

      // Clear loading state
      if (mounted) {
        setState(() {
          _isContactsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error initializing contacts for name display: $e');
      // Clear loading state even on error
      if (mounted) {
        setState(() {
          _isContactsLoading = false;
        });
      }
      // Continue without contacts - will show user names instead
    }
  }

  /// Handle scroll events for pagination
  void _onScroll() {
    final distanceToEnd =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;

    // Debug logging to track scroll events
    debugPrint(
      '📜 Scroll - Position: ${_scrollController.position.pixels.toInt()}, Max: ${_scrollController.position.maxScrollExtent.toInt()}, Distance to end: ${distanceToEnd.toInt()}',
    );

    if (distanceToEnd <= 100 && !_isLoadingMore) {
      debugPrint('🚀 SCROLL TRIGGER: Pagination should load more chats!');
      _loadMoreChats();
    }
  }

  /// Refresh both chat list and archived chats
  Future<void> _refreshAllChats(ChatProvider chatProvider) async {
    // Refresh main chat list
    await chatProvider.refreshChatList();

    // Also refresh archived chats
    if (!context.mounted) return;
    final archiveChatProvider = Provider.of<ArchiveChatProvider>(
      context,
      listen: false,
    );
    await archiveChatProvider.fetchArchivedChats();
  }

  /// Load more chats when user scrolls near bottom
  void _loadMoreChats() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    // Enhanced debug logging
    debugPrint('🔄 _loadMoreChats called');
    debugPrint('📊 hasChatListMoreData: ${chatProvider.hasChatListMoreData}');
    debugPrint(
      '⏳ isChatListPaginationLoading: ${chatProvider.isChatListPaginationLoading}',
    );
    debugPrint('🔒 _isLoadingMore: $_isLoadingMore');
    debugPrint('📄 Current page: ${chatProvider.chatListCurrentPage}');
    debugPrint('📈 Total pages: ${chatProvider.chatListTotalPages}');
    debugPrint(
      '💬 Current chats count: ${chatProvider.chatListData.chats.length}',
    );

    // Check if we can load more - improved conditions
    if (!chatProvider.hasChatListMoreData) {
      debugPrint('No more data available');
      return;
    }

    if (chatProvider.isChatListPaginationLoading || _isLoadingMore) {
      debugPrint('Already loading more chats');
      return;
    }

    debugPrint('Starting to load more chats');
    setState(() {
      _isLoadingMore = true;
    });

    try {
      await chatProvider.loadMoreChatList();
      debugPrint('Successfully loaded more chats');
    } catch (e) {
      debugPrint('Error loading more chats: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<
      ChatProvider,
      SocketEventController,
      ProjectConfigProvider,
      ContactListProvider
    >(
      builder: (
        context,
        chatProvider,
        socketEventController,
        configProvider,
        contactProvider,
        _,
      ) {
        final chats = chatProvider.chatListData.chats;
        final isLoading = chatProvider.isChatListLoading;
        final error = chatProvider.error;
        final isPaginationLoading = chatProvider.isChatListPaginationLoading;

        // 🎯 NEW: Handle contact resolution loading state
        if (_isContactsLoading) {
          debugPrint(
            'DEBUG: Contact loading state - resolving names before display',
          );
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                commonLoading(),
                SizedBox(height: 16),
                Text(
                  "Preparing contacts...",
                  style: AppTypography.innerText14(context),
                ),
              ],
            ),
          );
        }

        // Handle initial loading state
        if (isLoading && chats.isEmpty) {
          debugPrint(
            'DEBUG: Loading state - isLoading: $isLoading, chats.length: ${chats.length}, totalPages: ${chatProvider.chatListTotalPages}',
          );
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                commonLoading(),
                SizedBox(height: 16),
                Text(
                  "${AppString.loadingChats}...",
                  style: AppTypography.innerText14(context),
                ),
              ],
            ),
          );
        }

        // Handle error state
        if (error != null && chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: AppTypography.smallText(
                    context,
                  ).copyWith(color: Colors.red),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => chatProvider.refreshChatList(),
                  child: Text("Retry"),
                ),
              ],
            ),
          );
        }

        // Handle empty state - but check if there are more pages
        if (chats.isEmpty) {
          // If pagination shows more records but current page is empty, try next page
          if (chatProvider.chatListTotalPages > 1 &&
              chatProvider.chatListCurrentPage == 1) {
            // Auto-load next page since first page is empty
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (chatProvider.hasChatListMoreData &&
                  !chatProvider.isChatListPaginationLoading) {
                debugPrint(
                  'DEBUG: First page empty but total pages > 1, loading next page...',
                );
                chatProvider.loadMoreChatList();
              }
            });
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  commonLoading(),
                  SizedBox(height: 16),
                  Text("${AppString.loadingChats}..."),
                ],
              ),
            );
          }

          return Center(
            child: Column(
              // mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: SizeConfig.height(20)),
                SvgPicture.asset(
                  AppAssets.emptyDataIcons.noChatListFound,
                  colorFilter: ColorFilter.mode(
                    AppColors.appPriSecColor.secondaryColor,
                    BlendMode.srcIn,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  AppString.emptyDataString.startNewChat,
                  style: AppTypography.h3(context),
                ),
                SizedBox(height: 5),
                Text(
                  AppString.emptyDataString.beginFreshConversationAnytime,
                  style: AppTypography.innerText12Ragu(
                    context,
                  ).copyWith(color: AppColors.textColor.textDarkGray),
                ),
              ],
            ),
          );
        }

        // Show chat list with pagination
        return Column(
          children: [
            // Enhanced pagination info (for debugging)
            // if (kDebugMode)
            //   Container(
            //     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),

            //     decoration: BoxDecoration(
            //       color: Colors.blue.withValues(alpha: 0.1),
            //       border: Border(
            //         bottom: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
            //       ),
            //     ),
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //       children: [
            //         Text(
            //           'Page ${chatProvider.chatListCurrentPage} of ${chatProvider.chatListTotalPages}',
            //           style: AppTypography.smallText(context).copyWith(
            //             color: AppColors.appPriSecColor.primaryColor,
            //             fontWeight: FontWeight.w400,
            //           ),
            //         ),
            //         Row(
            //           children: [
            //             Text(
            //               '${chats.length} chats',
            //               style: AppTypography.smallText(context).copyWith(
            //                 color: Colors.blue,
            //                 fontWeight: FontWeight.w400,
            //                 fontStyle: FontStyle.italic,
            //               ),
            //             ),
            //             SizedBox(width: 8),
            //             if (chatProvider.hasChatListMoreData)
            //               Icon(Icons.more_horiz, color: Colors.grey, size: 16)
            //             else
            //               Icon(
            //                 Icons.check_circle,
            //                 color: Colors.green,
            //                 size: 16,
            //               ),
            //           ],
            //         ),
            //       ],
            //     ),
            //   ),
            SizedBox(height: SizeConfig.height(1)),
            // Chat list
            Expanded(
              child: RefreshIndicator(
                color: AppColors.appPriSecColor.primaryColor,
                onRefresh: () => _refreshAllChats(chatProvider),
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: chats.length + (isPaginationLoading ? 1 : 0),
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Add bottom padding to ensure list is always scrollable
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.of(context).size.height *
                        0.2, // 20% of screen height
                  ),
                  separatorBuilder: (context, index) {
                    if (index >= chats.length) return SizedBox.shrink();
                    return Divider(color: AppThemeManage.appTheme.borderColor);
                  },
                  itemBuilder: (context, index) {
                    // Show loading indicator at the bottom while paginating
                    if (index >= chats.length) {
                      return _buildPaginationLoader();
                    }

                    final chat = chats[index];
                    return _buildChatItem(
                      chat,
                      socketEventController,
                      chatProvider,
                      configProvider,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build pagination loader widget
  Widget _buildPaginationLoader() {
    return Container(
      padding: EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 20, height: 20, child: commonLoading()),
          SizedBox(width: 12),
          Text(
            "Loading more chats...",
            style: AppTypography.smallText(
              context,
            ).copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// Build individual chat item with enhanced group support
  Widget _buildChatItem(
    dynamic chat,
    SocketEventController socketEventController,
    ChatProvider chatProvider,
    ProjectConfigProvider configProvider,
  ) {
    // Handle potential null values safely
    final peer = chat.peerUserData ?? PeerUserData();
    final record =
        chat.records?.isNotEmpty == true ? chat.records!.first : null;
    final lastMessage =
        record?.messages?.isNotEmpty == true ? record!.messages!.first : null;
    final unseenCount = record?.unseenCount ?? 0;
    final chatType = record?.chatType ?? 'Private';
    final isGroupChat = chatType.toLowerCase() == 'group';

    // 🎯 FIXED: Anti-flickering name handling using stable method
    final String displayName =
        isGroupChat
            ? _getGroupDisplayName(record, peer)
            : _getResolvedDisplayName(peer, configProvider);
    final String profilePic = _getProfilePic(isGroupChat, record, peer);

    int userId = peer.userId ?? 0;
    int chatId = record?.chatId ?? 0;

    // Check for blocking scenario - hide typing/online status if blocked
    final blockScenario = chatProvider.getBlockScenario(chatId, userId);
    final isAnyBlockActive = blockScenario != 'none';

    // Check if user is online (only for individual chats and not blocked)
    final isOnline =
        !isGroupChat &&
        !isAnyBlockActive &&
        socketEventController.isUserOnline(userId);

    // Check if someone is typing (hide if blocked)
    final isTyping =
        !isAnyBlockActive && socketEventController.isUserTypingInChat(chatId);

    // Debug prints to help identify issues
    // debugPrint('Chat Item Debug:');
    // debugPrint('ChatType: $chatType, IsGroup: $isGroupChat');
    // debugPrint('GroupName: ${record?.groupName}');
    // debugPrint('PeerFullName: ${peer.fullName}');
    // debugPrint('PeerUserName: ${peer.userName}');
    // debugPrint('DisplayName: $displayName');
    // debugPrint('---');

    return InkWell(
      onTap: () {
        if (record?.chatId != null) {
          // Enhanced onTap with groupIcon and groupDescription support
          widget.onTap(
            record!.chatId!,
            peer,
            chatType: chatType,
            groupName:
                isGroupChat
                    ? displayName
                    : null, // Use displayName instead of record.groupName
            groupIcon: isGroupChat ? record.groupIcon : null,
            groupDescription: isGroupChat ? record.groupDescription : null,
          );
        }
      },
      onLongPress: () {
        _showChatOptions(
          context,
          isGroupChat,
          record,
          peer,
          displayName,
          profilePic,
        );
      },
      child: Padding(
        padding: SizeConfig.getPaddingSymmetric(horizontal: 17, vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                // User/Group avatar
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

                // Group indicator or online status
                if (isGroupChat)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.appPriSecColor.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemeManage.appTheme.borderColor,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.group,
                        color: ThemeColorPalette.getTextColor(
                          AppColors.appPriSecColor.primaryColor,
                        ), //AppThemeManage.appTheme.whiteBlck,
                        size: 12,
                      ),
                    ),
                  )
                else if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppThemeManage.appTheme.borderColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: SizeConfig.width(3)),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          displayName.toString().isNotEmpty
                              ? displayName.toString()[0].toUpperCase() +
                                  displayName.toString().substring(1)
                              : '', // This should now show proper names
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.innerText14(context).copyWith(
                            fontWeight:
                                //unseenCount > 0 ?
                                FontWeight.w600,
                            //  : FontWeight.w400,
                          ),
                        ),
                      ),
                      Text(
                        "  ${chatProvider.formatTime(_getChatTimestamp(record))}",
                        style: AppTypography.innerText10(context).copyWith(
                          color: AppThemeManage.appTheme.textGreyWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // _buildMessagePreview(
                      //   context,
                      //   isTyping,
                      //   isGroupChat,
                      //   lastMessage,
                      //   record,
                      // ),
                    ],
                  ),
                  SizedBox(height: SizeConfig.height(0.7)),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMessagePreview(
                          context,
                          isTyping,
                          isGroupChat,
                          lastMessage,
                          record,
                          chatProvider,
                        ),
                      ),
                      unseenCount > 0
                          ? Padding(
                            padding: AppDirectionality.appDirectionPadding
                                .paddingStart(10),
                            child: chatCountContainer(
                              context,
                              count: unseenCount,
                            ),
                          )
                          : const SizedBox(height: 20, width: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎯 NEW: Get resolved display name with anti-flickering logic
  String _getResolvedDisplayName(
    PeerUserData? peer,
    ProjectConfigProvider configProvider,
  ) {
    // Use the stable method that prevents flickering
    return ContactNameService.instance.getDisplayNameStable(
      userId: peer?.userId,
      configProvider: configProvider,
      contextFullName: peer?.fullName, // Pass the full name from chat list API
    );
  }

  /// Group display name logic - kept separate for group chats
  String _getGroupDisplayName(Records? record, PeerUserData? peer) {
    // For group chats, prioritize group name
    if (record?.groupName != null && record!.groupName!.trim().isNotEmpty) {
      return record.groupName!;
    }
    // If no group name, try to get from peer data as fallback
    if (peer?.fullName != null && peer!.fullName!.trim().isNotEmpty) {
      return "${peer.fullName!} (Group)";
    }
    if (peer?.userName != null && peer!.userName!.trim().isNotEmpty) {
      return "${peer.userName!} (Group)";
    }
    return 'Group Chat'; // Final fallback
  }

  /// Build avatar widget
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

  /// Build message preview with typing indicator and group sender name
  Widget _buildMessagePreview(
    BuildContext context,
    bool isTyping,
    bool isGroupChat,
    dynamic lastMessage,
    dynamic record,
    ChatProvider chatProvider,
  ) {
    return RichText(
      text: TextSpan(
        children: [
          if (isGroupChat && lastMessage?.user != null)
            TextSpan(
              text:
                  '${_getSenderName(lastMessage, chatProvider.currentUserId)}: ',
              style: AppTypography.captionText(context).copyWith(
                color: AppColors.appPriSecColor.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _buildMessageText(context, isTyping, lastMessage, record),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    // Row(
    //   children: [
    //     // Show sender name for group chats - FIXED (only if lastMessage exists)
    //     if (isGroupChat && lastMessage?.user != null)
    //       Text(
    //         '${_getSenderName(lastMessage)}: ',
    //         style: AppTypography.captionText(context).copyWith(
    //           color: AppColors.appPriSecColor.primaryColor,
    //           fontWeight: FontWeight.w500,
    //         ),
    //       ),
    //     Expanded(child: _buildMessageText(context, lastMessage, record)),
    //   ],
    // );
  }

  /// Build message text with special handling for call messages using CallDisplayService
  Widget _buildMessageText(
    BuildContext context,
    bool isTyping,
    dynamic lastMessage,
    dynamic record,
  ) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final currentUserId = chatProvider.currentUserId;

        if (isTyping) {
          return Row(
            children: [
              Text(
                "Typing...",
                style: AppTypography.smallText(context).copyWith(
                  color: AppColors.appPriSecColor.primaryColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          );
        }

        // Handle empty messages case
        if (lastMessage == null) {
          return Text(
            "No messages yet",
            maxLines: 1,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.smallText(context).copyWith(
              color: AppColors.textColor.textGreyColor,
              fontStyle: FontStyle.italic,
            ),
          );
        }

        // Use the unified call preview mapper for consistent call display
        final callPreview = CallPreviewMapper().mapCallMessageToPreview(
          calls: lastMessage?.calls,
          messageContent: lastMessage?.messageContent,
          messageType: lastMessage?.messageType,
          currentUserId: int.tryParse(currentUserId?.toString() ?? ''),
          messageSenderId: lastMessage?.senderId,
        );

        // Debug logging for call preview mapping
        if (callPreview != null) {
          debugPrint(
            'Call preview in _buildMessageText: "${callPreview.displayText}"',
          );
        }

        // If we have call preview info, show the call widget
        if (callPreview != null) {
          return RichText(
            text: TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.bottom,
                  baseline: TextBaseline.alphabetic,
                  child: SizedBox(height: 15, child: callPreview.icon),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  baseline: TextBaseline.alphabetic,
                  child: SizedBox(width: 4),
                ),
                TextSpan(
                  text: callPreview.displayText,
                  style: AppTypography.innerText12Mediu(
                    context,
                  ).copyWith(color: callPreview.color),
                ),
              ],
            ),
            maxLines: 1,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
          );
        }

        // Default message content for non-call messages
        return (lastMessage?.messageType == 'text' ||
                lastMessage?.messageType == 'group-created' ||
                lastMessage?.messageType == 'member-removed' ||
                lastMessage?.messageType == 'member-added' ||
                lastMessage?.messageType == 'member-left' ||
                lastMessage?.messageType == 'promoted-as-admin' ||
                lastMessage?.messageType == 'removed-as-admin' ||
                lastMessage?.messageContent == 'unblocked' ||
                lastMessage?.messageContent == 'blocked')
            ? RichText(
              text: TextSpan(
                text: messageContentWithEmojiSafe(
                  lastMessage?.messageType,
                  lastMessage?.messageContent,
                  actionedUser: lastMessage?.actionedUser,
                  currentUserId: int.tryParse(currentUserId?.toString() ?? ''),
                ),
                style: AppTypography.innerText12Mediu(
                  context,
                ).copyWith(color: AppColors.textColor.textGreyColor),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
            : RichText(
              text: TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    baseline: TextBaseline.alphabetic,
                    child: messageContentIcon(
                      context,
                      messageType: lastMessage?.messageType,
                    ),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    baseline: TextBaseline.alphabetic,
                    child: SizedBox(width: 5),
                  ),
                  TextSpan(
                    text: messageContentWithEmojiSafe(
                      lastMessage?.messageType,
                      lastMessage?.messageContent,
                      actionedUser: lastMessage?.actionedUser,
                      currentUserId: int.tryParse(
                        currentUserId?.toString() ?? '',
                      ),
                    ),
                    style: AppTypography.innerText12Mediu(
                      context,
                    ).copyWith(color: AppColors.textColor.textDarkGray),
                  ),
                ],
              ),
              maxLines: 1,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
            );
      },
    );
  }

  /// FIXED: Better sender name extraction with 'You' support
  String _getSenderName(dynamic lastMessage, String? currentUserId) {
    try {
      if (lastMessage?.user != null) {
        final user = lastMessage.user;
        int? currentUserIdInt = int.tryParse(currentUserId?.toString() ?? '');
        int? messageUserId;

        // Handle different user data structures
        if (user is Map<String, dynamic>) {
          // If user is a Map
          final userName =
              user['user_name']?.toString() ?? user['userName']?.toString();
          final fullName =
              user['full_name']?.toString() ?? user['fullName']?.toString();
          final userId =
              user['user_id']?.toString() ?? user['userId']?.toString();
          messageUserId = int.tryParse(userId ?? '');

          // Check if this is the current user
          if (currentUserIdInt != null &&
              messageUserId != null &&
              messageUserId == currentUserIdInt) {
            return 'You';
          }

          if (fullName != null && fullName.trim().isNotEmpty) {
            return fullName;
          }
          if (userName != null && userName.trim().isNotEmpty) {
            return userName;
          }
          if (userId != null && userId.trim().isNotEmpty) {
            return 'User $userId';
          }
        } else {
          // If user is an object with properties
          messageUserId = user.userId;

          // Check if this is the current user
          if (currentUserIdInt != null &&
              messageUserId != null &&
              messageUserId == currentUserIdInt) {
            return 'You';
          }

          if (user.fullName != null && user.fullName!.trim().isNotEmpty) {
            return user.fullName!;
          }
          if (user.userName != null && user.userName!.trim().isNotEmpty) {
            return user.userName!;
          }
          if (user.userId != null) {
            return 'User ${user.userId}';
          }
        }
      }

      // Also check lastMessage.senderId for current user comparison
      if (lastMessage?.senderId != null && currentUserId != null) {
        int? currentUserIdInt = int.tryParse(currentUserId);
        if (currentUserIdInt != null &&
            lastMessage.senderId == currentUserIdInt) {
          return 'You';
        }
      }
    } catch (e) {
      debugPrint('Error getting sender name: $e');
    }

    return 'Unknown User';
  }

  /// Get chat timestamp with updatedAt priority and createdAt fallback
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

  /// Get profile picture URL
  String _getProfilePic(bool isGroupChat, Records? record, PeerUserData? peer) {
    if (isGroupChat) {
      // For group chats, prioritize groupIcon over other sources
      if (record?.groupIcon != null && record!.groupIcon!.isNotEmpty) {
        return record.groupIcon!;
      }
      // Fallback to peer profile pic if available
      return peer?.profilePic ?? '';
    } else {
      return peer?.profilePic ?? '';
    }
  }

  /// Show chat options bottom sheet
  void _showChatOptions(
    BuildContext context,
    bool isGroupChat,
    Records? record,
    PeerUserData? peer,
    String displayName,
    String profilePic,
  ) {
    // Refresh block status when bottom sheet opens
    if (!isGroupChat && peer != null) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.refreshBlockStatus();
    }

    bottomSheetGobalWithoutTitle(
      context,
      bottomsheetHeight:
          isGroupChat
              ? SizeConfig.sizedBoxHeight(250)
              : SizeConfig.sizedBoxHeight(305),
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chat info header
          Container(
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: AppColors.appPriSecColor.secondaryColor.withValues(
                alpha: 0.15,
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppThemeManage.appTheme.borderColor,
                  width: 1.5,
                ),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
                child:
                    profilePic.isEmpty
                        ? Icon(
                          isGroupChat ? Icons.group : Icons.person,
                          color: AppThemeManage.appTheme.darkWhiteColor,
                        )
                        : null,
              ),
              title: Text(displayName),
              titleTextStyle: AppTypography.innerText14(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
              subtitle: Text(isGroupChat ? 'Group Chat' : 'Individual Chat'),
              subtitleTextStyle: AppTypography.innerText12Ragu(
                context,
              ).copyWith(color: AppColors.textColor.textDarkGray),
            ),
          ),

          // Options
          if (isGroupChat) ...[
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppThemeManage.appTheme.borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.group,
                  color: AppThemeManage.appTheme.darkWhiteColor,
                ),
                title: Text(AppString.homeScreenString.groupInfo),
                titleTextStyle: AppTypography.innerText14(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to group profile/info
                },
              ),
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppThemeManage.appTheme.borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: ListTile(
                leading: SvgPicture.asset(
                  AppAssets.settingsIcosn.profile,
                  colorFilter: ColorFilter.mode(
                    AppThemeManage.appTheme.darkWhiteColor,
                    BlendMode.srcIn,
                  ),
                  height: 22,
                ),
                title: Text(AppString.homeScreenString.viewProfile),
                titleTextStyle: AppTypography.innerText14(
                  context,
                ).copyWith(fontWeight: FontWeight.w600),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => UserProfileView(
                            userId: peer?.userId ?? 0,
                            chatId: record?.chatId,
                          ),
                    ),
                  );

                  // Refresh chat list if block status changed
                  if (result == true && mounted) {
                    if (!context.mounted) return;
                    final chatProvider = Provider.of<ChatProvider>(
                      context,
                      listen: false,
                    );
                    await chatProvider.refreshChatList();
                  }
                },
              ),
            ),
          ],

          // ListTile(
          //   leading: Icon(Icons.volume_off),
          //   title: Text('Mute Notifications'),
          //   onTap: () {
          //     Navigator.pop(context);
          //     // Implement mute functionality
          //   },
          // ),

          // Archive option
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppThemeManage.appTheme.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: ListTile(
              leading: Icon(
                Icons.archive_outlined,
                color: AppThemeManage.appTheme.darkWhiteColor,
              ),
              title: Text(AppString.homeScreenString.archiveChat),
              titleTextStyle: AppTypography.innerText14(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
              onTap: () {
                Navigator.pop(context);
                _performArchiveAction(
                  context,
                  record?.chatId ?? 0,
                  displayName,
                );
                // _showArchiveDialog(context, record?.chatId ?? 0, displayName);
              },
            ),
          ),

          // Block/Unblock option (only for individual chats)
          if (!isGroupChat && peer != null) ...[
            Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final currentUserId = chatProvider.currentUserId;
                final isUserBlocked =
                    record?.blockedBy?.contains(currentUserId) ?? false;

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppThemeManage.appTheme.borderColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: ListTile(
                    leading: SvgPicture.asset(
                      AppAssets.groupProfielIcons.userBock,
                      height: SizeConfig.sizedBoxHeight(20),
                    ),
                    // Icon(
                    //   isUserBlocked ? Icons.block : Icons.block,
                    //   color: isUserBlocked ? Colors.orange : Colors.red,
                    // ),
                    title: Text(
                      isUserBlocked
                          ? AppString.blockUserStrings.unbolockUser
                          : AppString.blockUserStrings.blockUser,
                    ),
                    titleTextStyle: AppTypography.innerText14(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                    textColor:
                        AppColors
                            .textColor
                            .textErrorColor1, //isUserBlocked ? Colors.orange : Colors.red,
                    onTap: () async {
                      Navigator.pop(context);
                      // await _handleBlockUnblock(
                      //   context,
                      //   peer.userId!,
                      //   displayName,
                      //   isUserBlocked,
                      //   record?.chatId ?? 0,
                      // );
                      Future.delayed(Duration(milliseconds: 100), () {
                        if (!context.mounted) return;
                        final rootContext =
                            Navigator.of(context, rootNavigator: true).context;

                        _handleBlockUnblock(
                          rootContext,
                          peer.userId!,
                          displayName,
                          isUserBlocked,
                          record?.chatId ?? 0,
                        );
                      });
                    },
                  ),
                );
              },
            ),
          ],

          // ✅ DEMO MODE: Show delete chat option for all users, but show alert for demo accounts
          ListTile(
            leading: SvgPicture.asset(
              AppAssets.groupProfielIcons.trash1,
              height: SizeConfig.sizedBoxHeight(23),
            ), //Icon(Icons.delete, color: Colors.red),
            title: Text(
              AppString.deleteChatString.deleteChat,
              style: AppTypography.innerText14(context).copyWith(
                color: AppColors.textColor.textErrorColor1,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context);

              // ✅ Check if demo account and show alert
              if (isDemo) {
                Future.delayed(Duration(milliseconds: 100), () {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please use real account to test this feature',
                      ),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                });
                return;
              }

              // For real accounts, proceed with delete confirmation
              Future.delayed(Duration(milliseconds: 100), () {
                if (!context.mounted) return;
                final rootContext =
                    Navigator.of(context, rootNavigator: true).context;

                _showDeleteConfirmation(
                  rootContext,
                  isGroupChat,
                  record?.chatId ?? 0,
                  displayName,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  /// Perform the actual delete chat action using the clear chat API
  Future<void> _performDeleteChat(
    BuildContext context,
    int chatId,
    String displayName,
  ) async {
    try {
      if (chatId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppString.unableToDeleteChatInvalidChatID),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: commonLoading()),
              SizedBox(width: 16),
              Text('${AppString.deleting} "$displayName"...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      // Call the clear chat API with delete_chat parameter
      final success = await chatProvider.clearChat(
        chatId: chatId,
        deleteChat: true,
      );

      if (mounted && success) {
        // No need to refresh - ChatProvider already removes the chat from local list
        // This preserves user's scroll position in paginated data

        // Show success message
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppString.chat} "$displayName" ${AppString.deletedSuccessfully}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppString.failedToDeleteChat} "$displayName", ${AppString.pleaseTryAgain}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppString.failedToDeleteChat}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show delete confirmation dialog
  void _showDeleteConfirmation(
    BuildContext context,
    bool isGroupChat,
    int chatId,
    String displayName,
  ) {
    bottomSheetGobalWithoutTitle(
      context,
      bottomsheetHeight: SizeConfig.height(25),
      isCrossIconHide: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.height(3)),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
            child: Text(
              AppString.deleteChatString.deleteChat,
              textAlign: TextAlign.start,
              style: AppTypography.captionText(context).copyWith(
                fontSize: SizeConfig.getFontSize(15),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: SizeConfig.height(2)),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
            child: Text(
              '${AppString.deleteChatString.areYouSureYouWantToDeleteThis} ${isGroupChat ? AppString.deleteChatString.group : AppString.deleteChatString.chat}? ${AppString.deleteChatString.thisActionCannotbBeUndone}',
              textAlign: TextAlign.start,
              style: AppTypography.captionText(context).copyWith(
                color: AppColors.textColor.textGreyColor,
                fontSize: SizeConfig.getFontSize(13),
              ),
            ),
          ),
          SizedBox(height: SizeConfig.height(4)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: customBorderBtn(
                  context,
                  onTap: () {
                    Navigator.pop(context);
                  },
                  title: AppString.cancel,
                ),
              ),
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: customBtn2(
                  context,
                  onTap: () {
                    Navigator.pop(context);
                    _performDeleteChat(context, chatId, displayName);
                  },
                  child: Text(
                    AppString.deleteChatString.delete,
                    style: AppTypography.h5(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: ThemeColorPalette.getTextColor(
                        AppColors.appPriSecColor.primaryColor,
                      ), //AppColors.textColor.textBlackColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Perform the actual archive action
  Future<void> _performArchiveAction(
    BuildContext context,
    int chatId,
    String displayName,
  ) async {
    try {
      // ✅ NEW: Check if this is a demo account
      if (isDemo) {
        // Show error snackbar for demo account
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archive feature is not available in demo account'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return; // Exit early, don't proceed with archive
      }

      final archiveChatProvider = Provider.of<ArchiveChatProvider>(
        context,
        listen: false,
      );

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: commonLoading()),
              SizedBox(width: 16),
              Text('${AppString.archiving} "$displayName"...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Call archive function
      await archiveChatProvider.archiveUnarchiveChat(chatId);

      // ✅ NEW: Wait a moment for the socket response to be processed
      await Future.delayed(Duration(milliseconds: 500));

      // ✅ NEW: Check if archive was successful before updating UI
      if (!context.mounted) return;

      if (archiveChatProvider.lastArchiveSuccess) {
        // ✅ NEW: Only remove from main chat list on success
        if (!context.mounted) return;
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        chatProvider.addArchivedChatId(chatId);

        // ✅ NEW: Force refresh of archived chats to update the archive widget
        await archiveChatProvider.fetchArchivedChats();

        // Show success message
        if (mounted) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppString.chat} "$displayName" ${AppString.archivedSuccessfully}',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // ✅ NEW: Show error message if archive failed
        final errorMsg =
            archiveChatProvider.lastArchiveError ?? 'Unknown error occurred';
        if (mounted) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to archive "$displayName": $errorMsg'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppString.failedToArchiveChat}: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Handle block/unblock user functionality
  Future<void> _handleBlockUnblock(
    BuildContext context,
    int userId,
    String displayName,
    bool isCurrentlyBlocked,
    int chatId,
  ) async {
    // ✅ DEMO MODE: Block user blocking/unblocking for demo accounts
    if (isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demo accounts cannot block or unblock users'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bottomSheetGobalWithoutTitle(
      context,
      bottomsheetHeight: SizeConfig.height(25),
      isCrossIconHide: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: SizeConfig.height(3)),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
            child: Text(
              isCurrentlyBlocked
                  ? AppString.blockUserStrings.unbolockUser
                  : AppString.blockUserStrings.blockUser,
              textAlign: TextAlign.start,
              style: AppTypography.captionText(context).copyWith(
                fontSize: SizeConfig.getFontSize(15),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: SizeConfig.height(2)),
          Padding(
            padding: SizeConfig.getPaddingSymmetric(horizontal: 30),
            child: Text(
              isCurrentlyBlocked
                  ? '${AppString.blockUserStrings.areYouSureYouWantToUnblock} $displayName? ${AppString.blockUserStrings.youWillBeAbleToChatWithThemAgain}'
                  : '${AppString.blockUserStrings.areYouSureYouWantToBlock} $displayName? ${AppString.blockUserStrings.youWillBeNotAbleToChatWithThem}',
              textAlign: TextAlign.start,
              style: AppTypography.captionText(context).copyWith(
                color: AppColors.textColor.textGreyColor,
                fontSize: SizeConfig.getFontSize(13),
              ),
            ),
          ),
          SizedBox(height: SizeConfig.height(4)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: customBorderBtn(
                  context,
                  onTap: () {
                    Navigator.pop(context);
                  },
                  title: AppString.cancel,
                ),
              ),
              SizedBox(
                height: SizeConfig.height(5),
                width: SizeConfig.width(35),
                child: customBtn2(
                  context,
                  onTap: () async {
                    Navigator.pop(context);

                    final chatProvider = Provider.of<ChatProvider>(
                      context,
                      listen: false,
                    );
                    final success = await chatProvider.blockUnblockUser(
                      userId,
                      chatId,
                    );

                    if (mounted) {
                      if (success) {
                        // Safely show success snackbar
                        try {
                          if (!context.mounted) return;
                          snackbarNew(
                            context,
                            msg:
                                isCurrentlyBlocked
                                    ? '$displayName ${AppString.blockUserStrings.hasBeenUnblocked}'
                                    : '$displayName ${AppString.blockUserStrings.hasBeenBlocked}',
                          );
                          // ScaffoldMessenger.of(context).showSnackBar(
                          //   SnackBar(
                          //     content: Text(
                          //       isCurrentlyBlocked
                          //           ? '$displayName ${AppString.blockUserStrings.hasBeenUnblocked}'
                          //           : '$displayName ${AppString.blockUserStrings.hasBeenBlocked}',
                          //     ),
                          //     backgroundColor:
                          //         isCurrentlyBlocked
                          //             ? Colors.green
                          //             : Colors.orange,
                          //   ),
                          // );
                        } catch (e) {
                          // If context is deactivated, just log the success
                          debugPrint(
                            'ChatList: Block/unblock successful but cannot show snackbar - context deactivated',
                          );
                        }
                        // The ChatProvider.blockUnblockUser already handles refreshing the chat list
                      } else {
                        // Safely show error snackbar
                        try {
                          if (!context.mounted) return;
                          snackbarNew(
                            context,
                            msg:
                                '${AppString.blockUserStrings.failedto} ${isCurrentlyBlocked ? AppString.blockUserStrings.unblockS : AppString.blockUserStrings.blockS} $displayName. ${AppString.pleaseTryAgain}',
                          );
                          // ScaffoldMessenger.of(context).showSnackBar(
                          //   SnackBar(
                          //     content: Text(
                          //       '${AppString.blockUserStrings.failedto} ${isCurrentlyBlocked ? AppString.blockUserStrings.unblockS : AppString.blockUserStrings.blockS} $displayName. ${AppString.blockUserStrings.pleaseTryAgain}',
                          //     ),
                          //     backgroundColor: Colors.red,
                          //   ),
                          // );
                        } catch (e) {
                          // If context is deactivated, just log the error
                          debugPrint(
                            'ChatList: Block/unblock failed but cannot show snackbar - context deactivated',
                          );
                        }
                      }
                    }
                  },
                  child: Text(
                    isCurrentlyBlocked
                        ? AppString.blockUserStrings.unblockU
                        : AppString.blockUserStrings.blockU,
                    style: AppTypography.h5(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: ThemeColorPalette.getTextColor(
                        AppColors.appPriSecColor.primaryColor,
                      ), //AppColors.textColor.textBlackColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper function for message content with emoji support
String messageContentWithEmojiSafe(
  String? messageType,
  String? messageContent, {
  dynamic actionedUser,
  int? currentUserId,
}) {
  switch (messageType?.toLowerCase()) {
    case 'group-created':
      return 'Group was created';
    case 'voice':
      return 'Voice message';
    case 'image':
      return 'Photo';
    case 'video':
      return 'Video';
    case 'document':
    case 'file':
    case 'doc':
      return 'Document';
    case 'location':
      return 'Location';
    case 'audio':
      return 'Audio';
    case 'gif':
      return 'GIF';
    case 'contact':
      return 'Contact';
    case 'member-removed':
      // Handle member-removed with proper user name (same logic as member-left)
      if (actionedUser != null && currentUserId != null) {
        // Extract user ID and name from actionedUser
        int? actionedUserId;
        String? actionedUserName;

        // Handle different data types safely
        if (actionedUser is Map) {
          actionedUserId =
              actionedUser['user_id'] as int? ?? actionedUser['userId'] as int?;
          actionedUserName =
              actionedUser['full_name'] as String? ??
              actionedUser['fullName'] as String? ??
              actionedUser['user_name'] as String? ??
              actionedUser['userName'] as String?;
        } else {
          // Assume it's a User object
          try {
            actionedUserId = (actionedUser as dynamic).userId as int?;
            actionedUserName =
                (actionedUser as dynamic).fullName as String? ??
                (actionedUser as dynamic).userName as String?;
          } catch (e) {
            debugPrint('Error parsing actionedUser in member-removed: $e');
          }
        }

        // Debug logging
        debugPrint('=== member-removed message debug ===');
        debugPrint('actionedUserId: $actionedUserId');
        debugPrint('currentUserId: $currentUserId');
        debugPrint('actionedUserName: $actionedUserName');
        debugPrint('====================================');

        // Compare user IDs
        if (actionedUserId != null && actionedUserId == currentUserId) {
          return 'You were removed';
        } else if (actionedUserName != null && actionedUserName.isNotEmpty) {
          return '$actionedUserName was removed';
        }
      }
      return messageContent ?? 'Member removed';
    case 'member-added':
      // Handle member-added with proper user name
      if (actionedUser != null && currentUserId != null) {
        // Extract user ID and name from actionedUser
        int? actionedUserId;
        String? actionedUserName;

        // Handle different data types safely
        if (actionedUser is Map) {
          actionedUserId =
              actionedUser['user_id'] as int? ?? actionedUser['userId'] as int?;
          actionedUserName =
              actionedUser['full_name'] as String? ??
              actionedUser['fullName'] as String? ??
              actionedUser['user_name'] as String? ??
              actionedUser['userName'] as String?;
        } else {
          // Assume it's a User object
          try {
            actionedUserId = (actionedUser as dynamic).userId as int?;
            actionedUserName =
                (actionedUser as dynamic).fullName as String? ??
                (actionedUser as dynamic).userName as String?;
          } catch (e) {
            debugPrint('Error parsing actionedUser in member-added: $e');
          }
        }

        // Compare user IDs
        if (actionedUserId != null && actionedUserId == currentUserId) {
          return 'You were added';
        } else if (actionedUserName != null && actionedUserName.isNotEmpty) {
          return '$actionedUserName was added';
        }
      }
      return messageContent ?? 'Member added';
    case 'promoted-as-admin':
      // Handle promoted-as-admin with proper user name
      if (actionedUser != null && currentUserId != null) {
        int? actionedUserId;
        String? actionedUserName;

        if (actionedUser is Map) {
          actionedUserId =
              actionedUser['user_id'] as int? ?? actionedUser['userId'] as int?;
          actionedUserName =
              actionedUser['full_name'] as String? ??
              actionedUser['fullName'] as String? ??
              actionedUser['user_name'] as String? ??
              actionedUser['userName'] as String?;
        } else {
          try {
            actionedUserId = (actionedUser as dynamic).userId as int?;
            actionedUserName =
                (actionedUser as dynamic).fullName as String? ??
                (actionedUser as dynamic).userName as String?;
          } catch (e) {
            debugPrint('Error parsing actionedUser in promoted-as-admin: $e');
          }
        }

        if (actionedUserId != null && actionedUserId == currentUserId) {
          return '👑 You were promoted to admin';
        } else if (actionedUserName != null && actionedUserName.isNotEmpty) {
          return '👑 $actionedUserName was promoted to admin';
        }
      }
      return '👑 Admin promoted';
    case 'removed-as-admin':
      // Handle removed-as-admin with proper user name
      if (actionedUser != null && currentUserId != null) {
        int? actionedUserId;
        String? actionedUserName;

        if (actionedUser is Map) {
          actionedUserId =
              actionedUser['user_id'] as int? ?? actionedUser['userId'] as int?;
          actionedUserName =
              actionedUser['full_name'] as String? ??
              actionedUser['fullName'] as String? ??
              actionedUser['user_name'] as String? ??
              actionedUser['userName'] as String?;
        } else {
          try {
            actionedUserId = (actionedUser as dynamic).userId as int?;
            actionedUserName =
                (actionedUser as dynamic).fullName as String? ??
                (actionedUser as dynamic).userName as String?;
          } catch (e) {
            debugPrint('Error parsing actionedUser in removed-as-admin: $e');
          }
        }

        if (actionedUserId != null && actionedUserId == currentUserId) {
          return '👑 You were removed as admin';
        } else if (actionedUserName != null && actionedUserName.isNotEmpty) {
          return '👑 $actionedUserName was removed as admin';
        }
      }
      return '👑 Admin removed';
    case 'member-left':
      // Handle member-left with proper user name
      if (actionedUser != null && currentUserId != null) {
        // Extract user ID and name from actionedUser
        int? actionedUserId;
        String? actionedUserName;

        // Handle different data types safely
        if (actionedUser is Map) {
          actionedUserId =
              actionedUser['user_id'] as int? ?? actionedUser['userId'] as int?;
          actionedUserName =
              actionedUser['full_name'] as String? ??
              actionedUser['fullName'] as String? ??
              actionedUser['user_name'] as String? ??
              actionedUser['userName'] as String?;
        } else {
          // Assume it's a User object
          try {
            actionedUserId = (actionedUser as dynamic).userId as int?;
            actionedUserName =
                (actionedUser as dynamic).fullName as String? ??
                (actionedUser as dynamic).userName as String?;
          } catch (e) {
            debugPrint('Error parsing actionedUser in member-left: $e');
          }
        }

        // Debug logging to trace the issue
        debugPrint('=== member-left message debug ===');
        debugPrint('actionedUserId: $actionedUserId');
        debugPrint('currentUserId: $currentUserId');
        debugPrint('actionedUserName: $actionedUserName');
        debugPrint('Match: ${actionedUserId == currentUserId}');
        debugPrint('================================');

        // Compare user IDs - ensure both are valid before comparison
        if (actionedUserId != null && actionedUserId == currentUserId) {
          return 'You left the group';
        } else if (actionedUserName != null && actionedUserName.isNotEmpty) {
          return '$actionedUserName left the group';
        }
      }
      // Fallback to message content if actionedUser info not available
      return messageContent ?? 'Someone left the group';
    default:
      return messageContent ?? '';
  }
}

// Fixed GroupChatStatusWidget
class GroupChatStatusWidget extends StatelessWidget {
  final int memberCount;
  final int onlineCount;
  final List<String> typingUsers;

  const GroupChatStatusWidget({
    super.key,
    required this.memberCount,
    required this.onlineCount,
    required this.typingUsers,
  });

  @override
  Widget build(BuildContext context) {
    if (typingUsers.isNotEmpty) {
      return _buildTypingIndicator(context);
    }
    return _buildMemberStatus(context);
  }

  Widget _buildTypingIndicator(BuildContext context) {
    String typingText;
    if (typingUsers.length == 1) {
      typingText = '${typingUsers.first} is typing...';
    } else if (typingUsers.length == 2) {
      typingText = '${typingUsers[0]} and ${typingUsers[1]} are typing...';
    } else {
      typingText = '${typingUsers.length} people are typing...';
    }

    return Row(
      children: [
        SizedBox(width: 12, height: 12, child: commonLoading()),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            typingText,
            style: AppTypography.captionText(context).copyWith(
              color: AppColors.appPriSecColor.primaryColor,
              fontStyle: FontStyle.italic,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberStatus(BuildContext context) {
    return Text(
      '$memberCount members${onlineCount > 0 ? ', $onlineCount online' : ''}',
      style: AppTypography.captionText(
        context,
      ).copyWith(color: AppColors.textColor.textDarkGray),
    );
  }
}
