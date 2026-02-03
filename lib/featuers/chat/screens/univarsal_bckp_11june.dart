// import 'dart:async';
// import 'dart:io';
// import 'dart:math' as math;
// import 'dart:ui' as ui;
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:provider/provider.dart';
// import 'package:stanchat/featuers/chat/data/chats_model.dart' as chats;
// import 'package:stanchat/featuers/chat/provider/chat_provider.dart';
// import 'package:stanchat/featuers/chat/utils/message_utils.dart';
// import 'package:stanchat/featuers/chat/utils/time_stamp_formatter.dart';
// import 'package:stanchat/featuers/chat/widgets/call_widget.dart';
// import 'package:stanchat/featuers/chat/widgets/chat_appbar_title.dart';
// import 'package:stanchat/featuers/chat/widgets/chat_files_views_handle/image_view.dart';
// import 'package:stanchat/featuers/chat/widgets/chat_files_views_handle/video_view.dart';
// import 'package:stanchat/featuers/chat/widgets/chat_keyboard.dart';
// import 'package:stanchat/featuers/chat/widgets/chat_type_dialog.dart';
// import 'package:stanchat/featuers/chat/widgets/current_chat_widget/lastseen_widget.dart';
// import 'package:stanchat/featuers/chat/widgets/current_chat_widget/message_content_widget.dart';
// import 'package:stanchat/featuers/chat/widgets/current_chat_widget/pin_duration_dialog.dart';
// import 'package:stanchat/featuers/chat/widgets/pinned_widget.dart';
// import 'package:stanchat/featuers/home/screens/chat_list.dart';
// import 'package:stanchat/utils/app_size_config.dart';
// import 'package:stanchat/utils/enums.dart';
// import 'package:stanchat/utils/logger.dart';
// import 'package:stanchat/utils/packages/scroll_to_index/scroll_to_index.dart';
// import 'package:stanchat/utils/preference_key/constant/app_colors.dart';
// import 'package:stanchat/utils/preference_key/constant/app_routes.dart';
// import 'package:stanchat/utils/preference_key/constant/app_text_style.dart';
// import 'package:stanchat/utils/preference_key/preference_key.dart';
// import 'package:stanchat/utils/preference_key/sharedpref_key.dart';
// import 'package:stanchat/widgets/cusotm_blur_appbar.dart';

// /// OneToOneChat Screen - Main chat interface for private conversations
// ///
// /// This screen handles:
// /// - Real-time messaging with text, images, videos, documents, location
// /// - Message starring, pinning, replying, deleting
// /// - Auto-pagination for loading older messages
// /// - Message highlighting and searching
// /// - Typing indicators and online status
// /// - Chat focus management for marking messages as seen
// class UniversalChatScreen extends StatefulWidget {
//   final int? userId; // For individual chats
//   final String profilePic;
//   final String chatName; // User name or group name
//   final int? chatId;
//   final String? updatedAt;
//   final bool isGroupChat; // Flag to distinguish chat types
//   final String? groupDescription; // Group description if available

//   const UniversalChatScreen({
//     super.key,
//     this.userId,
//     required this.profilePic,
//     required this.chatName,
//     this.chatId,
//     this.updatedAt,
//     this.isGroupChat = false,
//     this.groupDescription,
//   });

//   @override
//   State<UniversalChatScreen> createState() => _UniversalChatScreenState();
// }

// class _UniversalChatScreenState extends State<UniversalChatScreen>
//     with WidgetsBindingObserver {
//   // ═══════════════════════════════════════════════════════════════════════════
//   // CONSTANTS & CONFIGURATION
//   // ═══════════════════════════════════════════════════════════════════════════

//   static const double _paginationThreshold = 200.0;

//   // ═══════════════════════════════════════════════════════════════════════════
//   // CONTROLLERS & FOCUS NODES
//   // ═══════════════════════════════════════════════════════════════════════════

//   final TextEditingController _messageController = TextEditingController();
//   // final ScrollController _scrollController = ScrollController();
//   late AutoScrollController _scrollController;
//   final FocusNode _messageFocusNode = FocusNode();

//   // ═══════════════════════════════════════════════════════════════════════════
//   // CORE STATE VARIABLES
//   // ═══════════════════════════════════════════════════════════════════════════

//   final ConsoleAppLogger _logger = ConsoleAppLogger();
//   ChatProvider? _chatProvider;
//   String? _currentUserId;
//   bool _isDisposed = false;
//   bool _isInitialized = false;
//   bool _isInitializing = false;

//   // ═══════════════════════════════════════════════════════════════════════════
//   // UI STATE VARIABLES
//   // ═══════════════════════════════════════════════════════════════════════════

//   bool _isLoadingCurrentUser = true;
//   bool _hasError = false;
//   String? _errorMessage;
//   bool _isAttachmentMenuOpen = false;

//   // ═══════════════════════════════════════════════════════════════════════════
//   // TYPING & FOCUS MANAGEMENT
//   // ═══════════════════════════════════════════════════════════════════════════

//   Timer? _typingTimer;
//   bool _isTyping = false;
//   bool _isScreenActive = false;
//   bool _hasInitializedFocus = false;

//   // ═══════════════════════════════════════════════════════════════════════════
//   // ONLINE STATUS & USER MANAGEMENT
//   // ═══════════════════════════════════════════════════════════════════════════

//   bool _isUserOnlineFromApi = false;
//   bool _isLoadingOnlineStatus = false;
//   String? _lastSeenFromApi;

//   // ═══════════════════════════════════════════════════════════════════════════
//   // FILE ATTACHMENTS
//   // ═══════════════════════════════════════════════════════════════════════════

//   List<File>? _selectedImages;
//   List<File>? _selectedDocuments;
//   List<File>? _selectedVideos;
//   String _videoThumbnail = "";

//   // ═══════════════════════════════════════════════════════════════════════════
//   // PAGINATION & SCROLLING
//   // ═══════════════════════════════════════════════════════════════════════════

//   Timer? _paginationDebounceTimer;
//   bool _hasTriggeredPagination = false;
//   Timer? _scrollDebounceTimer;
//   bool _isScrolling = false;
//   bool _isInitialLoadComplete = false;

//   // ═══════════════════════════════════════════════════════════════════════════
//   // MESSAGE HIGHLIGHTING & NAVIGATION
//   // ═══════════════════════════════════════════════════════════════════════════

//   final Map<int, GlobalKey> _messageKeys = {};
//   String? _pendingHighlightMessageId;
//   final Map<int, double> _messageHeightCache = {};

//   // Helper getters
//   bool get isGroupChat => widget.isGroupChat;
//   bool get isIndividualChat => !widget.isGroupChat;
//   int get chatPartnerId => widget.userId ?? 0;
//   List<chats.User> get groupMembers => _groupMembersMap.values.toList();
//   int get groupMemberCount => _groupMembersMap.length;

//   // ═══════════════════════════════════════════════════════════════════════════
//   //  GROUP MEMBER MANAGMENT
//   // ═══════════════════════════════════════════════════════════════════════════

//   // Dynamic group member management
//   Map<int, chats.User> _groupMembersMap = {}; // userId -> User
//   Set<int> _onlineGroupMembers = {};
//   Map<int, String> _typingGroupMembers = {}; // userId -> userName

//   // ═══════════════════════════════════════════════════════════════════════════
//   // MULTI-DELETE STATE VARIABLES (Add to existing state variables section)
//   // ═══════════════════════════════════════════════════════════════════════════

//   // Multi-delete functionality
//   bool _isMultiDeleteMode = false;
//   Set<int> _selectedMessageIds = <int>{};
//   bool _isDeletingMessages = false;
//   int _totalMessagesToDelete = 0;
//   int _deletedMessagesCount = 0;

//   // Multi-delete getters
//   bool get isMultiDeleteMode => _isMultiDeleteMode;
//   Set<int> get selectedMessageIds => _selectedMessageIds;
//   bool get hasSelectedMessages => _selectedMessageIds.isNotEmpty;
//   int get selectedMessagesCount => _selectedMessageIds.length;
//   bool get isDeletingMessages => _isDeletingMessages;

//   // ═══════════════════════════════════════════════════════════════════════════
//   // WIDGET LIFECYCLE METHODS
//   // ═══════════════════════════════════════════════════════════════════════════

//   @override
//   void initState() {
//     super.initState();
//     _logger.d("OneToOneChat initState called");
//     _scrollController = AutoScrollController(
//       axis: Axis.vertical,

//       // if your ListView is reversed:
//     );
//     debugPrint('chat name: ${widget.chatName}');

//     WidgetsBinding.instance.addObserver(this);
//     _initializeScreen();

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _setScreenActive(true);
//     });

//     _scrollController.addListener(_onScroll);
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();

//     if (!_isDisposed) {
//       _chatProvider = Provider.of<ChatProvider>(context, listen: false);

//       if (!_hasInitializedFocus && _chatProvider != null) {
//         _setScreenActive(true);
//         _hasInitializedFocus = true;
//       }
//     }
//   }

//   @override
//   void didUpdateWidget(UniversalChatScreen oldWidget) {
//     super.didUpdateWidget(oldWidget);

//     if (oldWidget.chatId != widget.chatId ||
//         oldWidget.userId != widget.userId) {
//       _logger.d("Chat changed, updating focus");
//       _setScreenActive(true);
//     }

//     if (!_isDisposed &&
//         oldWidget.chatId != widget.chatId &&
//         widget.chatId != null &&
//         widget.chatId! > 0) {
//       _logger.d("Chat ID changed, reinitializing chat");
//       _isInitialized = false;
//       _initializeChat();
//     }
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);
//     _logger.d('App lifecycle state changed: $state');

//     if (_chatProvider != null) {
//       switch (state) {
//         case AppLifecycleState.resumed:
//           _chatProvider!.setAppForegroundState(true);
//           Future.delayed(Duration(milliseconds: 500), () {
//             if (_isScreenActive && !_isDisposed && mounted) {
//               _setScreenActive(true);
//             }
//           });
//           break;
//         case AppLifecycleState.paused:
//         case AppLifecycleState.inactive:
//         case AppLifecycleState.detached:
//         case AppLifecycleState.hidden:
//           _chatProvider!.setAppForegroundState(false);
//           break;
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _logger.d("OneToOneChat dispose called");
//     _isDisposed = true;

//     if (_chatProvider != null) {
//       _chatProvider!.setChatScreenActive(
//         widget.chatId ?? 0,
//         widget.userId ?? 0,
//         isActive: false,
//       );
//     }

//     WidgetsBinding.instance.removeObserver(this);
//     _messageController.dispose();
//     _typingTimer?.cancel();
//     _scrollController.removeListener(_onScroll);
//     _scrollController.dispose();
//     _scrollDebounceTimer?.cancel();
//     _messageFocusNode.dispose();
//     _paginationDebounceTimer?.cancel();

//     if (_chatProvider != null) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         try {
//           if (_chatProvider != null) {
//             _chatProvider!.setCurrentChat(0, 0);
//           }
//         } catch (e) {
//           _logger.e("Error resetting chat in post-dispose: $e");
//         }
//       });
//     }

//     super.dispose();
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // MAIN BUILD METHOD
//   // ═══════════════════════════════════════════════════════════════════════════

//   @override
//   Widget build(BuildContext context) {
//     if (_isDisposed) {
//       return Container();
//     }

//     return WillPopScope(
//       onWillPop: () async {
//         _logger.d("🔙 System back button pressed - clearing chat focus");
//         _setScreenActive(false);
//         await Future.delayed(Duration(milliseconds: 100));
//         return true;
//       },
//       child: Scaffold(
//         backgroundColor: AppColors.white,
//         appBar: _buildAppBar(),
//         body: _buildBody(),
//       ),
//     );
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // UI BUILDING METHODS
//   // ═══════════════════════════════════════════════════════════════════════════

//   PreferredSize _buildAppBar() {
//     return PreferredSize(
//       preferredSize: Size.fromHeight(SizeConfig.sizedBoxHeight(65)),
//       child: AppBar(
//         leadingWidth: 50,
//         leading: Padding(
//           padding: SizeConfig.getPadding(12),
//           child: IconButton(
//             icon: Icon(Icons.arrow_back, color: Colors.white),
//             onPressed: _navigateBack,
//           ),
//         ),
//         flexibleSpace: flexibleSpaceSplash(),
//         backgroundColor: Colors.transparent,
//         shadowColor: Colors.transparent,
//         elevation: 0,
//         automaticallyImplyLeading: false,
//         titleSpacing: 5,
//         title: _buildAppBarTitle(),
//         actions: [CallWidget(onTapAudio: () {}, onTapVideo: () {})],
//       ),
//     );
//   }

//   Widget _buildBody() {
//     return GestureDetector(
//       onTap: () {
//         if (mounted && !_isDisposed) {
//           setState(() {
//             _isAttachmentMenuOpen = false;
//           });
//           FocusScope.of(context).unfocus();
//         }
//       },
//       child: innerContainer(
//         context,
//         child: Stack(
//           children: [
//             Column(
//               children: [
//                 _buildPinnedMessagesWidget(),
//                 Expanded(
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.only(
//                       topLeft: Radius.circular(32),
//                       topRight: Radius.circular(32),
//                     ),
//                     child: _buildChatContent(),
//                   ),
//                 ),
//               ],
//             ),
//             _buildInputField(),
//             _buildAttachmentMenu(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAppBarTitle() {
//     return Consumer<ChatProvider>(
//       builder: (context, chatProvider, _) {
//         if (isGroupChat) {
//           return _buildGroupChatTitle(chatProvider);
//         } else {
//           return _buildIndividualChatTitle(chatProvider);
//         }
//       },
//     );
//   }

//   Widget _buildGroupChatTitle(ChatProvider chatProvider) {
//     final onlineCount = _getOnlineGroupMembersCount(chatProvider);
//     final typingUsers = _getTypingUsersInGroup();

//     return ChatAppbarTitle(
//       profile: widget.profilePic,
//       title: widget.chatName,

//       statusWidget: GroupChatStatusWidget(
//         memberCount: groupMemberCount,
//         onlineCount: onlineCount,
//         typingUsers: typingUsers,
//       ),
//       onTap: () {
//         _navigateToGroupInfo();
//       },
//     );
//   }

//   Widget _buildIndividualChatTitle(ChatProvider chatProvider) {
//     final isOnline = _isUserOnlineFromChatListOrApi(chatProvider);
//     bool isTyping = false;
//     final currentChatId = chatProvider.currentChatData.chatId ?? 0;

//     if (chatProvider.typingData.typing == true) {
//       isTyping = chatProvider.isUserTypingInChat(currentChatId);
//     }

//     String? lastSeenTime = _getLastSeenTimeFromChatListOrApi(chatProvider);

//     return ChatAppbarTitle(
//       profile: widget.profilePic,
//       title: widget.chatName,
//       statusWidget: LiveLastSeenWidget(
//         timestamp: lastSeenTime,
//         isOnline: isOnline,
//         isTyping: isTyping,
//       ),
//       onTap: () {
//         Navigator.pushNamed(context, AppRoutes.chatProfile);
//       },
//     );
//   }

//   Widget _buildChatContent() {
//     if (_hasError) return _buildErrorState();
//     if (_isLoadingCurrentUser || (_isInitializing && _currentUserId != null)) {
//       return _buildLoadingIndicator();
//     }
//     if (_currentUserId == null) return _buildErrorState();

//     return Consumer<ChatProvider>(
//       builder: (context, chatProvider, _) {
//         if (!_isInitialized && _isInitializing) {
//           return _buildLoadingIndicator();
//         }

//         if (chatProvider.isChatLoading &&
//             (chatProvider.chatsData.records == null ||
//                 chatProvider.chatsData.records!.isEmpty)) {
//           return _buildLoadingIndicator();
//         }

//         if (_isInitialized &&
//             !chatProvider.isChatLoading &&
//             (chatProvider.chatsData.records == null ||
//                 chatProvider.chatsData.records!.isEmpty)) {
//           return _buildEmptyState();
//         }

//         final messages = chatProvider.chatsData.records ?? [];

//         if (messages.isNotEmpty) {
//           return RefreshIndicator(
//             onRefresh: () async {
//               if (!_isDisposed && mounted) {
//                 try {
//                   await _refreshChatMessages();
//                   WidgetsBinding.instance.addPostFrameCallback((_) {
//                     if (!_isDisposed && mounted) {
//                       _scrollToBottom(animated: false);
//                     }
//                   });
//                 } catch (e) {
//                   _logger.e("RefreshIndicator error: $e");
//                 }
//               }
//             },
//             child: _buildMessagesList(messages, chatProvider),
//           );
//         }

//         return _buildEmptyState();
//       },
//     );
//   }

//   Widget _buildMessagesList(
//     List<chats.Records> messages,
//     ChatProvider chatProvider,
//   ) {
//     // Update group members from messages
//     if (isGroupChat) {
//       _updateGroupMembersFromMessages(messages);
//     }

//     final totalItemCount =
//         messages.length + (chatProvider.hasMoreMessages ? 1 : 0);

//     return ListView.builder(
//       key: PageStorageKey('universal_chat_list_${widget.chatId}'),
//       controller: _scrollController,
//       reverse: true,
//       physics: const AlwaysScrollableScrollPhysics(),
//       padding: const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 120),
//       cacheExtent: 1000,
//       itemCount: totalItemCount,
//       itemBuilder: (context, index) {
//         if (chatProvider.hasMoreMessages && index == messages.length) {
//           return _buildPaginationLoader();
//         }

//         final message = messages[index];
//         return RepaintBoundary(
//           child: _buildMessageBubble(message, index, messages),
//         );
//       },
//     );
//   }

//   Widget _buildMessageBubble(
//     chats.Records chat,
//     int index,
//     List<chats.Records> messages,
//   ) {
//     final messageId = chat.messageId!;
//     final key = _messageKeys.putIfAbsent(messageId, () => GlobalKey());

//     return Consumer<ChatProvider>(
//       builder: (context, chatProvider, _) {
//         final isSentByMe = chat.senderId.toString() == _currentUserId;
//         final isPinned = chat.pinned == true;
//         final isStarred = chatProvider.isMessageStarred(messageId);
//         final isHighlighted = chatProvider.highlightedMessageId == messageId;

//         final showSenderInfo =
//             isGroupChat &&
//             !isSentByMe &&
//             _shouldShowSenderInfo(chat, index, messages);

//         // Wrap with AutoScrollTag for scroll_to_index functionality
//         return AutoScrollTag(
//           key: ValueKey(messageId),
//           controller: _scrollController,
//           index: index,
//           child: _buildMessageContainer(
//             chat: chat,
//             key: key,
//             isSentByMe: isSentByMe,
//             isPinned: isPinned,
//             isStarred: isStarred,
//             isHighlighted: isHighlighted,
//             showSenderInfo: showSenderInfo,
//             chatProvider: chatProvider,
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildMessageContainer({
//     required chats.Records chat,
//     required GlobalKey key,
//     required bool isSentByMe,
//     required bool isPinned,
//     required bool isStarred,
//     required bool isHighlighted,
//     required bool showSenderInfo,
//     required ChatProvider chatProvider,
//   }) {
//     BoxDecoration? containerDecoration;
//     EdgeInsets containerPadding = EdgeInsets.zero;
//     Duration animationDuration = Duration.zero;

//     if (isHighlighted) {
//       containerDecoration = BoxDecoration(
//         color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.2),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(
//           color: AppColors.appPriSecColor.primaryColor,
//           width: 2.5,
//         ),
//       );
//       containerPadding = EdgeInsets.all(12);
//       animationDuration = Duration(milliseconds: 600);
//     }

//     Widget messageContainer = Column(
//       crossAxisAlignment:
//           isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//       children: [
//         if (isStarred) _buildStarIndicator(isSentByMe),
//         if (isPinned) _buildPinIndicator(isSentByMe, isHighlighted),
//         if (showSenderInfo) _buildGroupSenderInfo(chat),
//         KeyedSubtree(
//           key: key,
//           child: MessageContentWidget(
//             chat: chat,
//             currentUserId: _currentUserId!,
//             chatProvider: chatProvider,
//             onImageTap: _handleImageTap,
//             onVideoTap: _handleVideoTap,
//             onDocumentTap: _handleDocumentTap,
//             onLocationTap: _handleLocationTap,
//             isStarred: isStarred,
//           ),
//         ),
//       ],
//     );

//     return Container(
//       margin: EdgeInsets.symmetric(vertical: 3),
//       alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
//       child: InkWell(
//         onLongPress: () => _handleLongPress(chat),
//         borderRadius: BorderRadius.circular(12),
//         child:
//             containerDecoration != null && animationDuration > Duration.zero
//                 ? AnimatedContainer(
//                   duration: animationDuration,
//                   curve: Curves.easeInOut,
//                   decoration: containerDecoration,
//                   padding: containerPadding,
//                   child: messageContainer,
//                 )
//                 : messageContainer,
//       ),
//     );
//   }

//   Widget _buildGroupSenderInfo(chats.Records chat) {
//     final user = chat.user;
//     if (user == null) return SizedBox.shrink();

//     return Padding(
//       padding: EdgeInsets.only(left: 12, bottom: 4, top: 8),
//       child: GestureDetector(
//         onTap: () => _onSenderTap(user),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             CircleAvatar(
//               radius: 10,
//               backgroundColor: _getAvatarColor(user.userId ?? 0),
//               backgroundImage:
//                   user.profilePic != null && user.profilePic!.isNotEmpty
//                       ? NetworkImage(user.profilePic!)
//                       : null,
//               child:
//                   user.profilePic == null || user.profilePic!.isEmpty
//                       ? Text(
//                         _getSenderInitial(user.fullName ?? 'U'),
//                         style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.white,
//                         ),
//                       )
//                       : null,
//             ),
//             SizedBox(width: 6),
//             Text(
//               user.fullName ?? 'Unknown User',
//               style: AppTypography.captionText(context).copyWith(
//                 color: _getAvatarColor(user.userId ?? 0),
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Group management methods
//   void _updateGroupMembersFromMessages(List<chats.Records> messages) {
//     for (final message in messages) {
//       if (message.user != null && message.senderId != null) {
//         final userId = message.senderId!;
//         final user = message.user!;

//         // Add or update user in the map
//         if (!_groupMembersMap.containsKey(userId)) {
//           _groupMembersMap[userId] = user;
//           _logger.d("Added group member: ${user.fullName} (ID: $userId)");
//         } else {
//           // Update user info if it's newer
//           final existingUser = _groupMembersMap[userId]!;
//           if (_isUserInfoNewer(user, existingUser)) {
//             _groupMembersMap[userId] = user;
//             _logger.d("Updated group member: ${user.fullName} (ID: $userId)");
//           }
//         }
//       }
//     }

//     _logger.d("Group now has ${_groupMembersMap.length} members");
//   }

//   bool _isUserInfoNewer(chats.User newUser, chats.User existingUser) {
//     // Compare updated timestamps or other criteria
//     if (newUser.updatedAt != null && existingUser.updatedAt != null) {
//       final newTime = DateTime.tryParse(newUser.updatedAt!);
//       final existingTime = DateTime.tryParse(existingUser.updatedAt!);
//       if (newTime != null && existingTime != null) {
//         return newTime.isAfter(existingTime);
//       }
//     }
//     return false; // Keep existing if can't determine
//   }

//   chats.User? getGroupMember(int userId) {
//     return _groupMembersMap[userId];
//   }

//   List<chats.User> getActiveGroupMembers() {
//     return _groupMembersMap.values.where((user) {
//       final chatProvider =
//           _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//       return chatProvider.isUserOnline(user.userId ?? 0);
//     }).toList();
//   }

//   // Group chat helper methods
//   bool _shouldShowSenderInfo(
//     chats.Records message,
//     int index,
//     List<chats.Records> messages,
//   ) {
//     if (index >= messages.length - 1) return true;

//     final nextMessage = messages[index + 1];
//     return message.senderId != nextMessage.senderId;
//   }

//   Color _getAvatarColor(int userId) {
//     final colors = [
//       Colors.blue,
//       Colors.green,
//       Colors.orange,
//       Colors.purple,
//       Colors.teal,
//       Colors.indigo,
//       Colors.pink,
//       Colors.brown,
//       Colors.cyan,
//       Colors.amber,
//       Colors.red,
//       Colors.lime,
//     ];
//     return colors[userId % colors.length];
//   }

//   String _getSenderInitial(String name) {
//     return name.isNotEmpty ? name[0].toUpperCase() : 'U';
//   }

//   void _onSenderTap(chats.User user) {
//     if (user.userId != null) {
//       // Show user profile or start individual chat
//       _showUserActionSheet(user);
//     }
//   }

//   void _showUserActionSheet(chats.User user) {
//     // showModalBottomSheet(
//     //   context: context,
//     //   builder:
//     //       (context) => UserActionSheet(
//     //         user: user,
//     //         onViewProfile: () {
//     //           Navigator.pop(context);
//     //           _navigateToUserProfile(user);
//     //         },
//     //         onStartChat: () {
//     //           Navigator.pop(context);
//     //           _startIndividualChatWithUser(user);
//     //         },
//     //       ),
//     // );
//   }

//   // void _navigateToUserProfile(User user) {
//   //   Navigator.pushNamed(
//   //     context,
//   //     AppRoutes.userProfile,
//   //     arguments: {'userId': user.userId},
//   //   );
//   // }

//   void _startIndividualChatWithUser(chats.User user) {
//     Navigator.pushNamed(
//       context,
//       AppRoutes.universalChat,
//       arguments: {
//         'userId': user.userId,
//         'chatName': user.fullName ?? 'User',
//         'profilePic': user.profilePic ?? '',
//         'isGroupChat': false,
//       },
//     );
//   }

//   void _navigateToGroupInfo() {
//     Navigator.pushNamed(
//       context,
//       AppRoutes.groupInfo,
//       arguments: {
//         'groupId': widget.chatId,
//         'groupName': widget.chatName,
//         'groupDescription': widget.groupDescription,
//         'groupImage': widget.profilePic,
//         'memberCount': groupMemberCount,

//         'onGroupDeleted': () {
//           // Navigate back to chat list when group is deleted
//           Navigator.of(context).popUntil((route) => route.isFirst);
//         },
//       },
//     );
//   }

//   int _getOnlineGroupMembersCount(ChatProvider chatProvider) {
//     if (!isGroupChat) return 0;

//     return _groupMembersMap.values
//         .where((user) => chatProvider.isUserOnline(user.userId ?? 0))
//         .length;
//   }

//   List<String> _getTypingUsersInGroup() {
//     if (!isGroupChat) return [];

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//     final currentChatId = chatProvider.currentChatData.chatId ?? 0;

//     if (chatProvider.typingData.typing == true) {
//       // Get typing user IDs and convert to names
//       final typingUserIds = chatProvider.getTypingUserIdsInChat(currentChatId);
//       return typingUserIds.map((userId) {
//         final user = _groupMembersMap[userId];
//         return user?.fullName ?? 'Someone';
//       }).toList();
//     }

//     return [];
//   }

//   Widget _buildStarIndicator(bool isSentByMe) {
//     return Padding(
//       padding: EdgeInsets.only(
//         left: isSentByMe ? 0 : 12,
//         right: isSentByMe ? 12 : 0,
//         bottom: 4,
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           TweenAnimationBuilder<double>(
//             duration: Duration(milliseconds: 300),
//             tween: Tween(begin: 0.8, end: 1.0),
//             builder: (context, scale, child) {
//               return Transform.scale(
//                 scale: scale,
//                 child: Icon(Icons.star, size: 14, color: Colors.amber),
//               );
//             },
//           ),
//           SizedBox(width: 4),
//           Text(
//             'Starred',
//             style: AppTypography.captionText(context).copyWith(
//               color: Colors.amber[700],
//               fontSize: 11,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPinIndicator(bool isSentByMe, bool isHighlighted) {
//     return Padding(
//       padding: EdgeInsets.only(
//         left: isSentByMe ? 0 : 12,
//         right: isSentByMe ? 12 : 0,
//         bottom: 6,
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             Icons.push_pin,
//             size: 14,
//             color:
//                 isHighlighted
//                     ? AppColors.appPriSecColor.primaryColor
//                     : AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.7),
//           ),
//           SizedBox(width: 6),
//           Text(
//             'Pinned',
//             style: AppTypography.captionText(context).copyWith(
//               color:
//                   isHighlighted
//                       ? AppColors.appPriSecColor.primaryColor
//                       : AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.7),
//               fontSize: 11,
//               fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
//             ),
//           ),
//           if (isHighlighted) ...[
//             SizedBox(width: 10),
//             TweenAnimationBuilder<double>(
//               duration: Duration(milliseconds: 1500),
//               tween: Tween(begin: 0.6, end: 1.0),
//               builder: (context, scale, child) {
//                 return Transform.scale(
//                   scale: scale,
//                   child: Container(
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                     decoration: BoxDecoration(
//                       color: AppColors.appPriSecColor.primaryColor,
//                       borderRadius: BorderRadius.circular(10),
//                       boxShadow: [
//                         BoxShadow(
//                           color: AppColors.appPriSecColor.primaryColor
//                               .withValues(alpha: 0.3),
//                           blurRadius: 4,
//                           offset: Offset(0, 2),
//                         ),
//                       ],
//                     ),
//                     child: Text(
//                       'FOUND',
//                       style: AppTypography.captionText(context).copyWith(
//                         color: Colors.white,
//                         fontSize: 9,
//                         fontWeight: FontWeight.bold,
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildPaginationLoader() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 16.0),
//       child: Center(
//         child: SizedBox(
//           width: 24,
//           height: 24,
//           child: CircularProgressIndicator(strokeWidth: 2),
//         ),
//       ),
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.chat_bubble_outline,
//             size: 64,
//             color: AppColors.textColor.textGreyColor,
//           ),
//           SizedBox(height: 16),
//           Text(
//             "Start your conversation",
//             style: AppTypography.h4(
//               context,
//             ).copyWith(color: AppColors.textColor.textGreyColor),
//           ),
//           SizedBox(height: 8),
//           Text(
//             "Send a message to ${widget.chatName}",
//             style: AppTypography.mediumText(
//               context,
//             ).copyWith(color: AppColors.textColor.textGreyColor),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildErrorState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.error_outline,
//             size: 64,
//             color: AppColors.textColor.textErrorColor,
//           ),
//           SizedBox(height: 16),
//           Text(
//             "Something went wrong",
//             style: AppTypography.h4(
//               context,
//             ).copyWith(color: AppColors.textColor.textBlackColor),
//           ),
//           SizedBox(height: 8),
//           Text(
//             _errorMessage ?? "Please try again",
//             textAlign: TextAlign.center,
//             style: AppTypography.mediumText(
//               context,
//             ).copyWith(color: AppColors.textColor.textGreyColor),
//           ),
//           SizedBox(height: 16),
//           ElevatedButton(
//             onPressed: () {
//               _hasError = false;
//               _initializeScreen();
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.appPriSecColor.primaryColor,
//               foregroundColor: Colors.white,
//             ),
//             child: Text("Retry"),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoadingIndicator() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(
//               AppColors.appPriSecColor.primaryColor,
//             ),
//           ),
//           SizedBox(height: 16),
//           Text(
//             _isLoadingCurrentUser ? "Loading..." : "Loading messages...",
//             style: AppTypography.mediumText(
//               context,
//             ).copyWith(color: AppColors.textColor.textGreyColor),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPinnedMessagesWidget() {
//     return Consumer<ChatProvider>(
//       builder: (context, chatProvider, _) {
//         final pinnedMessages = chatProvider.pinnedMessagesData.records;

//         if (pinnedMessages == null || pinnedMessages.isEmpty) {
//           return SizedBox.shrink();
//         }

//         return PinnedMessagesWidget(
//           key: ValueKey(
//             'pinned_${pinnedMessages.length}_${pinnedMessages.hashCode}',
//           ),
//           scrollController: _scrollController,
//           onMessageTap: _handlePinnedMessageTap,
//           onUnpinMessage: _handleUnpinMessage,
//           currentUserId: _currentUserId ?? '0',
//           pinnedMessages: pinnedMessages,
//           isExpanded: chatProvider.isPinnedMessagesExpanded,
//           onToggleExpansion: () {
//             chatProvider.togglePinnedMessagesExpansion();
//           },
//         );
//       },
//     );
//   }

//   Widget _buildInputField() {
//     if (_isDisposed || !mounted) return SizedBox.shrink();
//     if (_isLoadingCurrentUser || _hasError || _currentUserId == null) {
//       return SizedBox.shrink();
//     }

//     return Align(
//       alignment: Alignment.bottomCenter,
//       child: Consumer<ChatProvider>(
//         builder: (context, chatProvider, _) {
//           final isLoading = chatProvider.isSendingMessage;
//           final replyMessage = chatProvider.replyToMessage;

//           return Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               if (replyMessage != null)
//                 _buildReplyPreview(replyMessage, chatProvider),
//               ChatKeyboard(
//                 controller: _messageController,
//                 focusNode: _messageFocusNode,
//                 onTapSendMsg: () {
//                   if (!_isDisposed &&
//                       mounted &&
//                       !isLoading &&
//                       _messageController.text.trim().isNotEmpty) {
//                     _sendTextMessage();
//                   }
//                 },
//                 onTapPin: () {
//                   if (!_isDisposed && mounted) {
//                     setState(() {
//                       _isAttachmentMenuOpen = !_isAttachmentMenuOpen;
//                     });
//                   }
//                 },
//                 onTapCamera: () => _sendImage(isFromGallery: false),
//                 onChanged: (text) {
//                   if (_isDisposed || !mounted) return;

//                   if (text.isNotEmpty && !_isTyping) {
//                     _isTyping = true;
//                     _sendTypingEvent(true);
//                   } else if (text.isEmpty && _isTyping) {
//                     _isTyping = false;
//                     _sendTypingEvent(false);
//                   }

//                   _typingTimer?.cancel();
//                   _typingTimer = Timer(Duration(seconds: 2), () {
//                     if (!_isDisposed && mounted && _isTyping) {
//                       _isTyping = false;
//                       _sendTypingEvent(false);
//                     }
//                   });
//                 },
//                 isLoading: isLoading,
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildReplyPreview(
//     chats.Records replyMessage,
//     ChatProvider chatProvider,
//   ) {
//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       padding: EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: AppColors.white.withValues(alpha: 0.8),
//         borderRadius: BorderRadius.circular(8),
//         border: Border(
//           left: BorderSide(
//             color: AppColors.appPriSecColor.primaryColor,
//             width: 4,
//           ),
//         ),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             Icons.reply,
//             size: 16,
//             color: AppColors.appPriSecColor.primaryColor,
//           ),
//           SizedBox(width: 8),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Replying to ${replyMessage.user?.fullName ?? 'Unknown'}',
//                   style: AppTypography.captionText(context).copyWith(
//                     color: AppColors.appPriSecColor.primaryColor,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   _getReplyPreviewText(replyMessage),
//                   style: AppTypography.captionText(
//                     context,
//                   ).copyWith(color: AppColors.textColor.textGreyColor),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(width: 8),
//           GestureDetector(
//             onTap: () => chatProvider.clearReply(),
//             child: Icon(
//               Icons.close,
//               size: 20,
//               color: AppColors.textColor.textGreyColor,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildAttachmentMenu() {
//     if (_isDisposed || !mounted || !_isAttachmentMenuOpen)
//       return SizedBox.shrink();

//     return Positioned(
//       bottom: 100,
//       left: 0,
//       right: 0,
//       child: Container(
//         margin: EdgeInsets.symmetric(horizontal: 24),
//         padding: EdgeInsets.symmetric(vertical: 10),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(10),
//           color: Colors.white,
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withValues(alpha: 0.1),
//               blurRadius: 10,
//               offset: Offset(0, 5),
//             ),
//           ],
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _buildAttachmentOption(
//               icon: Icons.photo,
//               title: "Photo",
//               onTap: () => _sendImage(),
//             ),
//             _buildAttachmentOption(
//               icon: Icons.videocam,
//               title: "Video",
//               onTap: _sendVideo,
//             ),
//             _buildAttachmentOption(
//               icon: Icons.insert_drive_file,
//               title: "Document",
//               onTap: _sendDocument,
//             ),
//             _buildAttachmentOption(
//               icon: Icons.location_on,
//               title: "Location",
//               onTap: _sendLocation,
//               isDivider: false,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildAttachmentOption({
//     required IconData icon,
//     required String title,
//     required VoidCallback onTap,
//     bool isDivider = true,
//   }) {
//     return Column(
//       children: [
//         InkWell(
//           onTap: onTap,
//           child: Padding(
//             padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//             child: Row(
//               children: [
//                 Container(
//                   padding: EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: AppColors.appPriSecColor.secondaryColor.withValues(alpha:
//                       0.1,
//                     ),
//                     borderRadius: BorderRadius.circular(50),
//                   ),
//                   child: Icon(
//                     icon,
//                     color: AppColors.appPriSecColor.primaryColor,
//                     size: 20,
//                   ),
//                 ),
//                 SizedBox(width: 16),
//                 Text(title, style: AppTypography.mediumText(context)),
//               ],
//             ),
//           ),
//         ),
//         if (isDivider)
//           Divider(
//             height: 1,
//             thickness: 0.5,
//             color: Colors.grey[300],
//             indent: 60,
//           ),
//       ],
//     );
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // INITIALIZATION & NAVIGATION METHODS
//   // ═══════════════════════════════════════════════════════════════════════════

//   Future<void> _initializeScreen() async {
//     if (_isDisposed) return;

//     try {
//       _logger.d("🚀 Starting screen initialization");
//       _isInitializing = true;

//       await _loadCurrentUserId();
//       if (_isDisposed) return;

//       _chatProvider = Provider.of<ChatProvider>(context, listen: false);
//       if (_chatProvider == null) {
//         throw Exception('ChatProvider not available');
//       }

//       _logger.d(
//         "📝 Setting current chat context: chatId=${widget.chatId}, userId=${widget.userId}",
//       );
//       _chatProvider!.setCurrentChat(widget.chatId ?? 0, widget.userId ?? 0);

//       await Future.delayed(Duration(milliseconds: 100));
//       if (_isDisposed) return;

//       _logger.d("📨 Loading chat messages");
//       await _chatProvider!.loadChatMessages(
//         chatId: widget.chatId ?? 0,
//         peerId: widget.userId ?? 0,
//         clearExisting: true,
//       );

//       if (_isDisposed) return;

//       await Future.delayed(Duration(milliseconds: 500));
//       if (_isDisposed) return;

//       await _checkUserOnlineStatusFromApi();

//       _isInitialized = true;
//       _isInitializing = false;
//       _hasError = false;
//       _errorMessage = null;

//       if (mounted) {
//         setState(() {});
//       }

//       _logger.d("✅ Screen initialization completed successfully");
//       _debugPinnedMessagesState();
//     } catch (e, stackTrace) {
//       _logger.e("❌ Error during initialization: $e");
//       _logger.e("📍 Stack trace: $stackTrace");

//       _hasError = true;
//       _errorMessage = e.toString();
//       _isInitializing = false;

//       if (mounted) {
//         setState(() {});
//       }
//     }
//   }

//   Future<void> _initializeChat() async {
//     if (_isDisposed || _isInitializing || _currentUserId == null) {
//       _logger.d(
//         "Chat initialization skipped - disposed: $_isDisposed, initializing: $_isInitializing, currentUserId: $_currentUserId",
//       );
//       return;
//     }

//     _isInitializing = true;

//     try {
//       final chatProvider =
//           _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//       int chatId = widget.chatId ?? 0;

//       _logger.d(
//         "Initializing chat with chatId: $chatId, userId: ${widget.userId}",
//       );

//       if (!_isDisposed && mounted) {
//         await chatProvider.loadChatMessages(
//           chatId: chatId,
//           peerId: widget.userId ?? 0,
//           clearExisting: true,
//         );
//       }

//       if (!_isDisposed) {
//         _isInitialized = true;
//         _logger.d("Chat initialization completed successfully");
//       }
//     } catch (e) {
//       _logger.e("Error initializing chat: $e");
//       if (!_isDisposed) {
//         setState(() {
//           _hasError = true;
//           _errorMessage = "Failed to load chat: ${e.toString()}";
//         });
//       }
//     } finally {
//       if (!_isDisposed) {
//         _isInitializing = false;
//         if (mounted) {
//           setState(() {});
//         }
//       }
//     }
//   }

//   Future<void> _loadCurrentUserId() async {
//     try {
//       _currentUserId = await SecurePrefs.getString(SecureStorageKeys.USERID);
//       _logger.d("Current user ID loaded: $_currentUserId");

//       if (_currentUserId == null || _currentUserId!.isEmpty) {
//         throw Exception("User ID is null or empty");
//       }

//       if (!_isDisposed) {
//         setState(() {
//           _isLoadingCurrentUser = false;
//         });
//       }
//     } catch (e) {
//       _logger.e("Error loading current user ID: $e");
//       rethrow;
//     }
//   }

//   void _navigateBack() {
//     if (_isDisposed) return;

//     _logger.d("🔙 Navigating back - clearing chat focus first");
//     _setScreenActive(false);

//     Future.delayed(Duration(milliseconds: 100), () {
//       if (mounted && !_isDisposed) {
//         Navigator.of(context).pop();
//       }
//     });
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // FOCUS & TYPING MANAGEMENT
//   // ═══════════════════════════════════════════════════════════════════════════

//   void _setScreenActive(bool isActive) {
//     if (_isDisposed || _chatProvider == null) return;

//     _isScreenActive = isActive;

//     _logger.d(
//       'Setting OneToOneChat screen active: $isActive, chatId: ${widget.chatId}, userId: ${widget.userId}',
//     );

//     _chatProvider!.setChatScreenActive(
//       widget.chatId ?? 0,
//       widget.userId ?? 0,
//       isActive: isActive,
//     );

//     if (!isActive) {
//       _logger.d('🚫 Chat screen deactivated - should stop auto-mark seen');
//     }

//     if (isActive && widget.chatId != null && widget.chatId! > 0) {
//       Future.delayed(Duration(milliseconds: 1000), () {
//         if (!_isDisposed &&
//             _isScreenActive &&
//             _chatProvider != null &&
//             _chatProvider!.isChatScreenActive &&
//             _chatProvider!.isAppInForeground) {
//           _logger.d('📱 Screen is fully active, marking messages as seen');
//           _chatProvider!.markChatMessagesAsSeen(widget.chatId!);
//         }
//       });
//     }
//   }

//   void _sendTypingEvent(bool isTyping) {
//     if (_isDisposed || !mounted) return;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

//     final currentChatId = chatProvider.currentChatData.chatId ?? 0;

//     _logger.d(
//       "Sending typing event - ChatId: $currentChatId, UserId: ${widget.userId}, IsTyping: $isTyping",
//     );

//     chatProvider.sendTypingStatus(currentChatId, isTyping);
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // ONLINE STATUS & USER DATA METHODS
//   // ═══════════════════════════════════════════════════════════════════════════

//   bool _isUserOnlineFromChatListOrApi(ChatProvider chatProvider) {
//     final isOnlineFromSocket = chatProvider.isUserOnline(widget.userId ?? 0);

//     if (isOnlineFromSocket) {
//       return true;
//     }

//     final chatListData = chatProvider.chatListData;
//     bool userFoundInChatList = false;

//     if (chatListData.chats != null && chatListData.chats!.isNotEmpty) {
//       for (final chat in chatListData.chats!) {
//         final peerUserData = chat.peerUserData;
//         if (peerUserData != null && peerUserData.userId == widget.userId) {
//           userFoundInChatList = true;
//           break;
//         }
//       }
//     }

//     if (!userFoundInChatList) {
//       return _isUserOnlineFromApi;
//     }

//     return false;
//   }

//   String? _getLastSeenTimeFromChatListOrApi(ChatProvider chatProvider) {
//     _logger.d(
//       "Getting last seen time from chat list for userId: ${widget.userId}",
//     );

//     final chatListData = chatProvider.chatListData;
//     if (chatListData.chats == null || chatListData.chats!.isEmpty) {
//       _logger.w("No chat list data available, using API data");
//       return _lastSeenFromApi;
//     }

//     _logger.d("Searching through ${chatListData.chats!.length} chats");

//     for (final chat in chatListData.chats!) {
//       final peerUserData = chat.peerUserData;

//       if (peerUserData != null && peerUserData.userId == widget.userId) {
//         _logger.d("Found matching peer user data for userId: ${widget.userId}");

//         final lastSeen = peerUserData.updatedAt;

//         if (lastSeen != null && lastSeen.trim().isNotEmpty) {
//           _logger.i("Found last seen from peer user data: $lastSeen");
//           return lastSeen;
//         } else {
//           _logger.w("PeerUserData.updatedAt is null or empty");
//         }

//         final createdAt = peerUserData.createdAt;
//         if (createdAt != null && createdAt.trim().isNotEmpty) {
//           _logger.i("Using createdAt as fallback: $createdAt");
//           return createdAt;
//         }
//       }
//     }

//     _logger.w("User ${widget.userId} not found in chat list, using API data");
//     return _lastSeenFromApi ?? widget.updatedAt;
//   }

//   Future<void> _checkUserOnlineStatusFromApi() async {
//     if (_isDisposed || !mounted) return;

//     try {
//       setState(() {
//         _isLoadingOnlineStatus = true;
//       });

//       final chatProvider =
//           _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

//       final response = await chatProvider.checkUserOnlineStatus(
//         widget.userId ?? 0,
//       );

//       if (!_isDisposed && mounted && response != null) {
//         setState(() {
//           _isUserOnlineFromApi = response['isOnline'] ?? false;
//           _lastSeenFromApi = response['udatedAt'];
//           _isLoadingOnlineStatus = false;
//         });

//         _logger.d(
//           "User ${widget.userId} online status from API: $_isUserOnlineFromApi, lastSeen: $_lastSeenFromApi",
//         );
//       } else {
//         if (!_isDisposed && mounted) {
//           setState(() {
//             _isLoadingOnlineStatus = false;
//           });
//         }
//       }
//     } catch (e) {
//       _logger.e("Error checking user online status from API: $e");
//       if (!_isDisposed && mounted) {
//         setState(() {
//           _isLoadingOnlineStatus = false;
//         });
//       }
//     }
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // MESSAGE SENDING METHODS
//   // ═══════════════════════════════════════════════════════════════════════════

//   void _sendTextMessage() {
//     if (_isDisposed || !mounted || _messageController.text.trim().isEmpty)
//       return;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//     final chatId = widget.chatId ?? 0;
//     final replyToMessageId = chatProvider.replyToMessage?.messageId;

//     _logger.d(
//       "Sending message to ${chatId == 0 ? 'new user' : 'existing chat'}: ${widget.userId}, replyTo: $replyToMessageId",
//     );

//     chatProvider
//         .sendMessage(
//           chatId,
//           _messageController.text.trim(),
//           messageType: MessageType.Text,
//           replyToMessageId: replyToMessageId,
//         )
//         .then((success) {
//           if (!_isDisposed && mounted && success) {
//             _messageController.clear();
//             _sendTypingEvent(false);

//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               if (!_isDisposed && mounted) {
//                 _scrollToBottom(animated: true);
//               }
//             });
//           }
//         });
//   }

//   void _sendAttachmentMessage(MessageType messageType) {
//     if (_isDisposed || !mounted) return;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//     final chatId = widget.chatId ?? 0;

//     switch (messageType) {
//       case MessageType.Image:
//       case MessageType.Gif:
//         if (_selectedImages != null) {
//           chatProvider.setShareImage(_selectedImages!);
//         }
//         break;
//       case MessageType.File:
//         if (_selectedDocuments != null) {
//           chatProvider.setShareDocument(_selectedDocuments!);
//         }
//         break;
//       case MessageType.Video:
//         if (_selectedVideos != null) {
//           chatProvider.setShareVideo(_selectedVideos!, _videoThumbnail);
//         }
//         break;
//       default:
//         break;
//     }

//     chatProvider.sendMessage(chatId, "", messageType: messageType).then((
//       success,
//     ) {
//       if (!_isDisposed && mounted && success) {
//         _selectedImages = null;
//         _selectedDocuments = null;
//         _selectedVideos = null;
//         _videoThumbnail = "";

//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           _scrollToBottom();
//         });
//       }
//     });

//     if (mounted) {
//       setState(() {
//         _isAttachmentMenuOpen = false;
//       });
//     }
//   }

//   Future<void> _sendImage({bool isFromGallery = true}) async {
//     if (_isDisposed || !mounted) return;

//     if (isFromGallery) {
//       final allowedExtensions = MessageTypeUtils.getAllowedExtensions(
//         MessageType.Image,
//       );

//       FilePickerResult? pickedFile = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowMultiple: false,
//         allowedExtensions: allowedExtensions,
//       );

//       if (pickedFile != null && !_isDisposed && mounted) {
//         _selectedImages =
//             pickedFile.files.map((platformFile) {
//               return File(platformFile.path!);
//             }).toList();
//         _sendAttachmentMessage(MessageType.Image);
//       }
//     } else {
//       final images = await pickImages(source: ImageSource.camera);
//       if (images != null && images.isNotEmpty && !_isDisposed && mounted) {
//         _selectedImages = images;
//         _sendAttachmentMessage(MessageType.Image);
//       }
//     }
//   }

//   Future<void> _sendVideo() async {
//     if (_isDisposed || !mounted) return;

//     final allowedExtensions = MessageTypeUtils.getAllowedExtensions(
//       MessageType.Video,
//     );

//     FilePickerResult? pickedFile = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowMultiple: false,
//       allowedExtensions: allowedExtensions,
//     );

//     if (pickedFile != null && !_isDisposed && mounted) {
//       _selectedVideos =
//           pickedFile.files.map((platformFile) {
//             return File(platformFile.path!);
//           }).toList();

//       _sendAttachmentMessage(MessageType.Video);
//     }
//   }

//   Future<void> _sendDocument() async {
//     if (_isDisposed || !mounted) return;

//     final allowedExtensions = MessageTypeUtils.getAllowedExtensions(
//       MessageType.File,
//     );

//     FilePickerResult? pickedFile = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowMultiple: false,
//       allowedExtensions: allowedExtensions,
//     );

//     if (pickedFile != null && !_isDisposed && mounted) {
//       _selectedDocuments =
//           pickedFile.files.map((platformFile) {
//             return File(platformFile.path!);
//           }).toList();
//       _sendAttachmentMessage(MessageType.File);
//     }
//   }

//   void _sendLocation() {
//     if (_isDisposed || !mounted) return;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//     final chatId = widget.chatId ?? 0;

//     const locationData = "40.7128,-74.0060"; // Example coordinates

//     chatProvider
//         .sendMessage(chatId, locationData, messageType: MessageType.Location)
//         .then((success) {
//           if (!_isDisposed && mounted && success) {
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               _scrollToBottom();
//             });
//           }
//         });
//   }

//   Future<List<File>?> pickImages({required ImageSource source}) async {
//     if (_isDisposed || !mounted) return null;

//     try {
//       final XFile? pickedImage = await ImagePicker().pickImage(
//         source: source,
//         imageQuality: 70,
//       );

//       if (pickedImage != null && !_isDisposed && mounted) {
//         return [File(pickedImage.path)];
//       }
//       return null;
//     } catch (e) {
//       _logger.e('Error picking image: $e');
//       return null;
//     }
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // MESSAGE INTERACTION HANDLERS
//   // ═══════════════════════════════════════════════════════════════════════════

//   void _handleLongPress(chats.Records message) {
//     if (!_isDisposed && mounted && message.deletedForEveryone != true) {
//       final chatProvider = Provider.of<ChatProvider>(context, listen: false);

//       final isCurrentlyStarred = chatProvider.isMessageStarred(
//         message.messageId!,
//       );

//       _logger.d(
//         'Long press on message ${message.messageId} - currently starred: $isCurrentlyStarred',
//       );

//       chatTypeDailog(
//         context,
//         message: message,
//         onPinUnpin: _handlePinUnpinMessage,
//         onReply: _handleReply,
//         onDelete: _handleDeleteMessage,
//         onStarUnstar: _handleStarUnstarMessage,
//         isStarred: isCurrentlyStarred,
//       );
//     }
//   }

//   void _handleReply(chats.Records message) {
//     if (_isDisposed || !mounted) return;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

//     chatProvider.setReplyToMessage(message);
//     _messageFocusNode.requestFocus();

//     _logger.d('Reply set for message: ${message.messageId}');
//   }

//   void _handleImageTap(String imageUrl) {
//     if (_isDisposed || !mounted) return;

//     context.viewImage(
//       imageSource: imageUrl,
//       imageTitle: 'Chat Image',
//       heroTag: imageUrl,
//     );
//   }

//   void _handleVideoTap(String videoUrl) {
//     if (_isDisposed || !mounted) return;
//     debugPrint('video tap url : $videoUrl');
//     context.viewVideo(videoUrl: videoUrl);
//   }

//   void _handleDocumentTap(chats.Records chat) {
//     if (_isDisposed || !mounted) return;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

//     chatProvider.downloadPdfWithProgress(
//       pdfUrl: chat.messageContent!,
//       onProgress: (progress) {
//         _logger.d("Download progress: ${(progress * 100).toInt()}%");
//       },
//       onComplete: (filePath, metadata) {
//         if (filePath != null) {
//           _logger.d("Document downloaded: $filePath");
//           _openDocument(filePath);
//         } else {
//           _logger.e("Document download failed: $metadata");
//           _showDocumentError(metadata ?? "Download failed");
//         }
//       },
//     );
//   }

//   void _handleLocationTap(double latitude, double longitude) {
//     if (_isDisposed || !mounted) return;
//     // Implement location viewing logic
//   }

//   void _openDocument(String filePath) {
//     _logger.d("Opening document: $filePath");
//     // Implement document opening logic
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // PIN/UNPIN MESSAGE METHODS
//   // ═══════════════════════════════════════════════════════════════════════════

//   // ═══════════════════════════════════════════════════════════════════════════
//   // PIN/UNPIN MESSAGE HANDLER
//   // ═══════════════════════════════════════════════════════════════════════════

//   /// Handles pin/unpin message operations
//   ///
//   /// This method:
//   /// - Validates permissions before allowing pin/unpin operations
//   /// - Shows duration selection dialog for pinning new messages
//   /// - Directly unpins if message is already pinned
//   /// - Provides user feedback throughout the process
//   /// - Handles errors gracefully with appropriate notifications
//   Future<void> _handlePinUnpinMessage(chats.Records message) async {
//     if (_isDisposed || !mounted || _currentUserId == null) return;

//     try {
//       final chatProvider =
//           _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//       final chatId = widget.chatId ?? 0;

//       // Validate chat ID and message ID
//       if (chatId <= 0 || message.messageId == null) {
//         _logger.w("Invalid chat ID or message ID for pin/unpin");
//         return;
//       }

//       // Check if user has permission to pin/unpin messages
//       if (!chatProvider.canPinUnpinMessage(message)) {
//         final permissionText = chatProvider.getPinUnpinPermissionText(message);

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(permissionText),
//               backgroundColor: AppColors.textColor.textErrorColor,
//               duration: Duration(seconds: 3),
//             ),
//           );
//         }
//         return;
//       }

//       // If message is already pinned, unpin it directly
//       if (message.pinned == true) {
//         _logger.d(
//           '🔧 Message ${message.messageId} is pinned, unpinning directly',
//         );
//         await _executePinUnpinAction(
//           chatProvider,
//           chatId,
//           message.messageId!,
//           0, // 0 days means unpin
//         );
//         return;
//       }

//       // If message is not pinned, show duration selection dialog
//       _logger.d(
//         '🔧 Message ${message.messageId} is not pinned, showing duration dialog',
//       );
//       showDialog(
//         context: context,
//         barrierDismissible: true,
//         builder: (BuildContext context) {
//           return PinDurationDialog(
//             onDurationSelected: (int days) async {
//               _logger.d('🔧 Duration selected: $days days');
//               await _executePinUnpinAction(
//                 chatProvider,
//                 chatId,
//                 message.messageId!,
//                 days,
//               );
//             },
//           );
//         },
//       );
//     } catch (e) {
//       _logger.e("❌ Error handling pin/unpin message: $e");

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.error, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Expanded(child: Text("Error: ${e.toString()}")),
//               ],
//             ),
//             backgroundColor: AppColors.textColor.textErrorColor,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }

//   /// Executes the actual pin/unpin operation via API
//   ///
//   /// Parameters:
//   /// - [chatProvider]: The chat provider instance
//   /// - [chatId]: The chat ID
//   /// - [messageId]: The message ID to pin/unpin
//   /// - [days]: Duration in days (0 = unpin, -1 = lifetime, >0 = specific duration)
//   Future<void> _executePinUnpinAction(
//     ChatProvider chatProvider,
//     int chatId,
//     int messageId,
//     int days,
//   ) async {
//     try {
//       // Log the operation details
//       _logger.d('🔧 Pin/Unpin Request:');
//       _logger.d('  Message ID: $messageId');
//       _logger.d('  Chat ID: $chatId');
//       _logger.d('  Duration (days): $days');
//       _logger.d('  Current User ID: $_currentUserId');

//       // Clear any existing notifications
//       ScaffoldMessenger.of(context).clearSnackBars();

//       // Show loading indicator
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: Colors.white,
//                   ),
//                 ),
//                 SizedBox(width: 12),
//                 Text("${days == 0 ? 'Unpinning' : 'Pinning'} message..."),
//               ],
//             ),
//             backgroundColor: AppColors.appPriSecColor.primaryColor,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }

//       // Execute the pin/unpin operation via API
//       final success = await chatProvider.pinUnpinMessage(
//         chatId,
//         messageId,
//         days, // Pass the selected days duration
//       );

//       // Clear loading indicator
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//       }

//       // Log the result
//       _logger.d('🔧 Pin/Unpin Result: $success');

//       if (success && mounted) {
//         // Show success message with appropriate text
//         String successMessage;
//         if (days == 0) {
//           successMessage = "Message unpinned successfully";
//         } else if (days == -1) {
//           successMessage = "Message pinned for lifetime";
//         } else {
//           successMessage = "Message pinned for $days day${days > 1 ? 's' : ''}";
//         }

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.check_circle, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Expanded(child: Text(successMessage)),
//               ],
//             ),
//             backgroundColor: AppColors.appPriSecColor.primaryColor,
//             duration: Duration(seconds: 2),
//           ),
//         );

//         // Force UI update to reflect the changes
//         _logger.d('🔧 Forcing UI update after pin/unpin');
//         if (mounted) {
//           setState(() {
//             // This will trigger a rebuild to show updated pin status
//           });
//         }
//       } else if (mounted) {
//         // Show error message if operation failed
//         final errorMessage =
//             chatProvider.error ??
//             "Failed to ${days == 0 ? 'unpin' : 'pin'} message";

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.error, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Expanded(child: Text(errorMessage)),
//               ],
//             ),
//             backgroundColor: AppColors.textColor.textErrorColor,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }

//       // Debug: Log current pinned messages count after operation
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (!_isDisposed && mounted) {
//           final currentPinnedCount =
//               chatProvider.pinnedMessagesData.records?.length ?? 0;
//           _logger.d(
//             '🔧 After pin/unpin - Pinned messages count: $currentPinnedCount',
//           );
//         }
//       });
//     } catch (e) {
//       _logger.e("❌ Error executing pin/unpin action: $e");

//       // Clear loading indicator on error
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();

//         // Show error notification
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.error, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Expanded(child: Text("Error: ${e.toString()}")),
//               ],
//             ),
//             backgroundColor: AppColors.textColor.textErrorColor,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }

//   Future<void> _handleUnpinMessage(chats.Records message) async {
//     if (_isDisposed || !mounted || _currentUserId == null) return;

//     try {
//       final chatProvider =
//           _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//       final chatId = widget.chatId ?? 0;

//       if (chatId <= 0 || message.messageId == null) {
//         _logger.w("Invalid chat ID or message ID for unpin");
//         return;
//       }

//       if (!chatProvider.canPinUnpinMessage(message)) {
//         final permissionText = chatProvider.getPinUnpinPermissionText(message);

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(permissionText),
//               backgroundColor: AppColors.textColor.textErrorColor,
//               duration: Duration(seconds: 3),
//             ),
//           );
//         }
//         return;
//       }

//       ScaffoldMessenger.of(context).clearSnackBars();

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: Colors.white,
//                   ),
//                 ),
//                 SizedBox(width: 12),
//                 Text("Unpinning message..."),
//               ],
//             ),
//             backgroundColor: AppColors.appPriSecColor.primaryColor,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }

//       final success = await chatProvider.pinUnpinMessage(
//         chatId,
//         message.messageId!,
//       );

//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//       }

//       _logger.d('🔧 Unpin Result: $success');

//       if (success && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.check_circle, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Text("Message unpinned successfully"),
//               ],
//             ),
//             backgroundColor: AppColors.appPriSecColor.primaryColor,
//             duration: Duration(seconds: 2),
//           ),
//         );

//         final remainingPinnedCount =
//             chatProvider.pinnedMessagesData.records?.length ?? 0;
//         if (remainingPinnedCount <= 1 &&
//             chatProvider.isPinnedMessagesExpanded) {
//           Future.delayed(Duration(milliseconds: 500), () {
//             if (!_isDisposed && mounted) {
//               chatProvider.setPinnedMessagesExpanded(false);
//             }
//           });
//         }

//         if (mounted) {
//           setState(() {
//             // This will trigger a rebuild
//           });
//         }
//       } else if (mounted) {
//         final errorMessage = chatProvider.error ?? "Failed to unpin message";

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.error, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Expanded(child: Text(errorMessage)),
//               ],
//             ),
//             backgroundColor: AppColors.textColor.textErrorColor,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }

//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (!_isDisposed && mounted) {
//           final currentPinnedCount =
//               chatProvider.pinnedMessagesData.records?.length ?? 0;
//           _logger.d(
//             '🔧 After unpin - Pinned messages count: $currentPinnedCount',
//           );
//         }
//       });
//     } catch (e) {
//       _logger.e("❌ Error handling unpin message: $e");

//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.error, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Expanded(child: Text("Error: ${e.toString()}")),
//               ],
//             ),
//             backgroundColor: AppColors.textColor.textErrorColor,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }

//   void _handlePinnedMessageTap(int messageId) {
//     if (_isDisposed || !mounted) return;

//     final chatProvider = Provider.of<ChatProvider>(context, listen: false);

//     _logger.d('🎯 Pinned message tapped: $messageId');

//     try {
//       if (chatProvider.isPinnedMessagesExpanded) {
//         chatProvider.setPinnedMessagesExpanded(false);
//       }

//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (_isDisposed || !mounted) return;
//         _scrollToMessageAndHighlight(messageId, chatProvider);
//       });
//     } catch (e) {
//       _logger.e('❌ Error handling pinned message tap: $e');
//       _showHighlightErrorFeedback();
//     }
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // STAR/UNSTAR MESSAGE METHODS
//   // ═══════════════════════════════════════════════════════════════════════════

//   Future<void> _handleStarUnstarMessage(chats.Records message) async {
//     if (_isDisposed || !mounted || _currentUserId == null) return;

//     try {
//       final chatProvider = Provider.of<ChatProvider>(context, listen: false);

//       final isCurrentlyStarred = chatProvider.isMessageStarred(
//         message.messageId!,
//       );

//       if (message.messageId == null) {
//         _logger.w("Invalid message ID for star/unstar");
//         return;
//       }

//       if (!chatProvider.canStarUnStarMessage(message)) {
//         final permissionText = chatProvider.getStarUnstarPermissionText(
//           message,
//         );

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(permissionText),
//               backgroundColor: AppColors.textColor.textErrorColor,
//               duration: Duration(seconds: 3),
//             ),
//           );
//         }
//         return;
//       }

//       ScaffoldMessenger.of(context).clearSnackBars();

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: Colors.white,
//                   ),
//                 ),
//                 SizedBox(width: 12),
//                 Text(
//                   "${isCurrentlyStarred ? 'Unstarring' : 'Starring'} message...",
//                 ),
//               ],
//             ),
//             backgroundColor: AppColors.appPriSecColor.primaryColor,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }

//       final success = await chatProvider.starUnstarMessage(message.messageId!);

//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//       }

//       if (success && mounted) {
//         String successMessage =
//             isCurrentlyStarred
//                 ? "Message unstarred successfully"
//                 : "Message starred successfully";

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(
//                   isCurrentlyStarred ? Icons.star_border : Icons.star,
//                   color: Colors.white,
//                   size: 20,
//                 ),
//                 SizedBox(width: 8),
//                 Text(successMessage),
//               ],
//             ),
//             backgroundColor: AppColors.appPriSecColor.primaryColor,
//             duration: Duration(seconds: 2),
//           ),
//         );

//         _logger.d(
//           '⭐ Star/unstar completed, UI will update automatically via socket',
//         );
//       } else if (mounted) {
//         final errorMessage =
//             chatProvider.error ?? "Failed to star/unstar message";

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.error, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Expanded(child: Text(errorMessage)),
//               ],
//             ),
//             backgroundColor: AppColors.textColor.textErrorColor,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     } catch (e) {
//       _logger.e("❌ Error handling star/unstar message: $e");

//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.error, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Expanded(child: Text("Error: ${e.toString()}")),
//               ],
//             ),
//             backgroundColor: AppColors.textColor.textErrorColor,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // DELETE MESSAGE METHODS
//   // ═══════════════════════════════════════════════════════════════════════════

//   Future<void> _handleDeleteMessage(
//     chats.Records message,
//     bool isDeleteForEveryone,
//   ) async {
//     if (_isDisposed || !mounted || _currentUserId == null) return;

//     try {
//       final chatProvider =
//           _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//       final chatId = widget.chatId ?? 0;

//       if (chatId <= 0 || message.messageId == null) {
//         _logger.w("Invalid chat ID or message ID for deletion");
//         return;
//       }

//       if (!chatProvider.canDeleteMessage(message)) {
//         final permissionText = chatProvider.getDeletePermissionText(message);

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(permissionText),
//               backgroundColor: AppColors.textColor.textErrorColor,
//               duration: Duration(seconds: 3),
//             ),
//           );
//         }
//         return;
//       }

//       if (isDeleteForEveryone) {
//         final confirmed = await _showDeleteConfirmationDialog(
//           isDeleteForEveryone,
//         );
//         if (!confirmed) return;
//       }

//       ScaffoldMessenger.of(context).clearSnackBars();

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: Colors.white,
//                   ),
//                 ),
//                 SizedBox(width: 12),
//                 Text("Deleting message..."),
//               ],
//             ),
//             backgroundColor: AppColors.appPriSecColor.primaryColor,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }

//       final success =
//           isDeleteForEveryone
//               ? await chatProvider.deleteMessageForEveryone(
//                 chatId,
//                 message.messageId!,
//               )
//               : await chatProvider.deleteMessageForMe(
//                 chatId,
//                 message.messageId!,
//               );

//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//       }

//       if (success && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.check_circle, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Text(
//                   isDeleteForEveryone
//                       ? "Message deleted for everyone"
//                       : "Message deleted for you",
//                 ),
//               ],
//             ),
//             backgroundColor: AppColors.appPriSecColor.primaryColor,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       } else if (mounted) {
//         final errorMessage = chatProvider.error ?? "Failed to delete message";

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.error, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Expanded(child: Text(errorMessage)),
//               ],
//             ),
//             backgroundColor: AppColors.textColor.textErrorColor,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     } catch (e) {
//       _logger.e("❌ Error handling delete message: $e");

//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.error, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Expanded(child: Text("Error: ${e.toString()}")),
//               ],
//             ),
//             backgroundColor: AppColors.textColor.textErrorColor,
//             duration: Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }

//   Future<bool> _showDeleteConfirmationDialog(bool isDeleteForEveryone) async {
//     return await showDialog<bool>(
//           context: context,
//           builder: (BuildContext context) {
//             return AlertDialog(
//               title: Text(
//                 isDeleteForEveryone
//                     ? "Delete for Everyone?"
//                     : "Delete for You?",
//                 style: AppTypography.h4(context),
//               ),
//               content: Text(
//                 isDeleteForEveryone
//                     ? "This message will be deleted for everyone in the chat."
//                     : "This message will be deleted for you only.",
//                 style: AppTypography.mediumText(context),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop(false),
//                   child: Text(
//                     "Cancel",
//                     style: AppTypography.buttonText(
//                       context,
//                     ).copyWith(color: AppColors.textColor.textGreyColor),
//                   ),
//                 ),
//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop(true),
//                   child: Text(
//                     "Delete",
//                     style: AppTypography.buttonText(
//                       context,
//                     ).copyWith(color: AppColors.textColor.textErrorColor),
//                   ),
//                 ),
//               ],
//             );
//           },
//         ) ??
//         false;
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // SCROLLING & PAGINATION METHODS
//   // ═══════════════════════════════════════════════════════════════════════════

//   void _onScroll() {
//     if (_isDisposed || !_scrollController.hasClients || !mounted) return;

//     _scrollDebounceTimer?.cancel();
//     _scrollDebounceTimer = Timer(const Duration(milliseconds: 100), () {
//       _updateScrollState();
//     });
//   }

//   void _updateScrollState() {
//     if (!mounted) return;

//     final currentPosition = _scrollController.position.pixels;
//     final maxScrollExtent = _scrollController.position.maxScrollExtent;

//     if (maxScrollExtent - currentPosition <= 200) {
//       _triggerPagination();
//     }

//     if (!_isInitialLoadComplete && maxScrollExtent > 0) {
//       _isInitialLoadComplete = true;
//     }
//   }

//   void _triggerPagination() {
//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

//     if (chatProvider.isPaginationLoading ||
//         !chatProvider.hasMoreMessages ||
//         chatProvider.isChatLoading ||
//         chatProvider.isRefreshing ||
//         _isInitializing ||
//         _isLoadingCurrentUser) {
//       return;
//     }

//     _hasTriggeredPagination = true;
//     _loadMoreMessages();
//   }

//   Future<void> _loadMoreMessages() async {
//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

//     if (chatProvider.isPaginationLoading ||
//         !chatProvider.hasMoreMessages ||
//         chatProvider.isChatLoading ||
//         chatProvider.isRefreshing ||
//         _isInitializing ||
//         _isLoadingCurrentUser) {
//       _logger.d('⏭️ Pagination conditions not met, skipping');
//       return;
//     }

//     _logger.d('🔄 Starting pagination load');

//     try {
//       await chatProvider.loadMoreMessages();
//       _logger.d('✅ Pagination completed successfully');
//     } catch (e) {
//       _logger.e("❌ Error loading more messages: $e");
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text("Failed to load more messages"),
//             backgroundColor: AppColors.textColor.textErrorColor,
//           ),
//         );
//       }
//     }
//   }

//   Future<void> _refreshChatMessages() async {
//     if (_isDisposed || !mounted || _currentUserId == null) {
//       return;
//     }

//     try {
//       final chatProvider =
//           _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//       final chatId = widget.chatId ?? 0;

//       _logger.d(
//         "🔄 Starting refresh - chatId: $chatId, userId: ${widget.userId}",
//       );

//       await chatProvider.refreshChatMessages(
//         chatId: chatId,
//         peerId: widget.userId ?? 0,
//       );

//       _logger.d("✅ Chat refresh completed successfully");
//     } catch (e) {
//       _logger.e("❌ Error refreshing chat messages: $e");

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text("Failed to refresh messages: ${e.toString()}"),
//             backgroundColor: AppColors.textColor.textErrorColor,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//       rethrow;
//     }
//   }

//   void _scrollToBottom({bool animated = true}) {
//     if (_isDisposed || !_scrollController.hasClients || !mounted) return;

//     _logger.d('📍 Scrolling to bottom - animated: $animated');

//     if (animated) {
//       _scrollController.animateTo(
//         0.0,
//         duration: Duration(milliseconds: 300),
//         curve: Curves.easeOut,
//       );
//     } else {
//       _scrollController.jumpTo(0.0);
//     }
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // MESSAGE HIGHLIGHTING & SEARCH METHODS
//   // ═══════════════════════════════════════════════════════════════════════════

//   Future<void> _scrollToMessageAndHighlight(
//     int messageId,
//     ChatProvider chatProvider,
//   ) async {
//     if (_isDisposed || !mounted) return;

//     _logger.d('🎯 scrollToMessageAndHighlight: $messageId');
//     ScaffoldMessenger.of(context).clearSnackBars();

//     try {
//       // 1️⃣ If we already have a GlobalKey for that message -> ensureVisible
//       final key = _messageKeys[messageId];
//       if (key?.currentContext != null) {
//         _logger.d('✅ GlobalKey found – scrolling via ensureVisible');
//         chatProvider.highlightMessage(messageId);
//         await Scrollable.ensureVisible(
//           key!.currentContext!,
//           duration: Duration(milliseconds: 400),
//           curve: Curves.easeInOut,
//           alignment: 0.5,
//         );
//         _showMessageFoundFeedback();
//         return;
//       }

//       // 2️⃣ Not in the current batch? auto-paginate and retry ensureVisible
//       if (!_isMessageInCurrentData(messageId, chatProvider)) {
//         _logger.d('🔄 Message not loaded – auto-paginating');
//         await _autoPaginateToFindMessage(messageId, chatProvider);

//         final key2 = _messageKeys[messageId];
//         if (key2?.currentContext != null) {
//           chatProvider.highlightMessage(messageId);
//           await Scrollable.ensureVisible(
//             key2!.currentContext!,
//             duration: Duration(milliseconds: 400),
//             curve: Curves.easeInOut,
//             alignment: 0.5,
//           );
//           _showMessageFoundFeedback();
//           return;
//         }
//       }

//       // 3️⃣ Fallback: scroll_to_index by list index
//       final messages = chatProvider.chatsData.records ?? [];
//       final idx = messages.indexWhere((m) => m.messageId == messageId);
//       if (idx == -1) {
//         throw Exception('Message $messageId still not found after pagination');
//       }

//       _logger.d('📍 Fallback – scroll_to_index at index $idx');
//       await _scrollController.scrollToIndex(
//         idx,
//         duration: Duration(milliseconds: 400),

//         preferPosition: AutoScrollPosition.middle,
//       );

//       // finally highlight in place
//       chatProvider.highlightMessage(messageId);
//       _showMessageFoundFeedback();
//     } catch (e, st) {
//       _logger.e('❌ Error in scrollToMessage: $e\n$st');
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//         _showHighlightErrorFeedback();
//       }
//     }
//   }

//   Future<void> _autoPaginateToFindMessage(
//     int messageId,
//     ChatProvider chatProvider,
//   ) async {
//     _logger.d('🔄 Starting auto-pagination for message $messageId');

//     int attemptCount = 0;

//     // Keep going while there's more data to load
//     while (chatProvider.hasMoreMessages) {
//       // If the provider is still in the middle of loading/refreshing, wait
//       if (chatProvider.isChatLoading || chatProvider.isRefreshing) {
//         _logger.d('⏳ Provider busy – waiting...');
//         await _waitForProviderToBeReady(chatProvider);
//         continue;
//       }

//       attemptCount++;
//       _logger.d(
//         '🔄 Auto-pagination attempt #$attemptCount for message $messageId',
//       );
//       _updateSearchProgress(attemptCount, messageId);

//       try {
//         // Trigger your normal “load next page” + await until it's done
//         await _loadMoreMessagesAndWait(chatProvider);

//         // Once new data’s in, check if our target arrived
//         if (_isMessageInCurrentData(messageId, chatProvider)) {
//           _logger.d('✅ Message $messageId found after $attemptCount attempts');
//           return;
//         } else {
//           _logger.d(
//             '📭 Message $messageId still not found (attempt $attemptCount)',
//           );
//         }
//       } catch (e, st) {
//         _logger.e(
//           '❌ Error during pagination attempt #$attemptCount: $e',
//           e,
//           st,
//         );
//         // small back-off before retrying
//         await Future.delayed(const Duration(milliseconds: 500));
//       }
//     }

//     // If we exit the loop, hasMoreMessages is now false
//     _logger.w('❌ No more messages to load – message $messageId not found');
//     throw Exception(
//       'Message $messageId not found after loading all available pages',
//     );
//   }

//   Future<void> _waitForProviderToBeReady(ChatProvider chatProvider) async {
//     int waitCount = 0;
//     const maxWaitCount = 20;

//     while ((chatProvider.isChatLoading || chatProvider.isRefreshing) &&
//         waitCount < maxWaitCount) {
//       await Future.delayed(Duration(milliseconds: 500));
//       waitCount++;

//       if (_isDisposed || !mounted) {
//         throw Exception('Component disposed while waiting');
//       }
//     }

//     if (waitCount >= maxWaitCount) {
//       _logger.w('⚠️ Timeout waiting for provider to be ready');
//     }
//   }

//   Future<void> _loadMoreMessagesAndWait(ChatProvider chatProvider) async {
//     _logger.d('📡 Starting API call to load more messages');

//     final currentMessageCount = chatProvider.chatsData.records?.length ?? 0;

//     await chatProvider.loadMoreMessages();

//     await _waitForNewMessagesToLoad(chatProvider, currentMessageCount);

//     _logger.d('✅ API response processed and new messages loaded');
//   }

//   Future<void> _waitForNewMessagesToLoad(
//     ChatProvider chatProvider,
//     int previousMessageCount,
//   ) async {
//     int waitCount = 0;
//     const maxWaitCount = 20;

//     while (waitCount < maxWaitCount) {
//       if (_isDisposed || !mounted) {
//         throw Exception('Component disposed while waiting for messages');
//       }

//       if (!chatProvider.isChatLoading && !chatProvider.isRefreshing) {
//         final currentMessageCount = chatProvider.chatsData.records?.length ?? 0;

//         if (currentMessageCount > previousMessageCount) {
//           _logger.d(
//             '📬 New messages detected: $previousMessageCount → $currentMessageCount',
//           );

//           await Future.delayed(Duration(milliseconds: 300));
//           return;
//         }

//         if (!chatProvider.hasMoreMessages) {
//           _logger.d('📭 No more messages available from server');
//           return;
//         }
//       }

//       await Future.delayed(Duration(milliseconds: 500));
//       waitCount++;
//     }

//     if (waitCount >= maxWaitCount) {
//       _logger.w('⚠️ Timeout waiting for new messages to load');
//     }
//   }

//   bool _isMessageInCurrentData(int messageId, ChatProvider chatProvider) {
//     final messages = chatProvider.chatsData.records;
//     if (messages == null || messages.isEmpty) {
//       _logger.d('📭 No messages loaded yet');
//       return false;
//     }

//     final found = messages.any((record) => record.messageId == messageId);

//     if (found) {
//       _logger.d(
//         '✅ Message $messageId found in ${messages.length} loaded messages',
//       );
//     } else {
//       _logger.d(
//         '❌ Message $messageId not found in ${messages.length} loaded messages',
//       );

//       final messageIds = messages.take(5).map((m) => m.messageId).toList();
//       _logger.d('📋 Sample loaded message IDs: $messageIds');
//     }

//     return found;
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // CALCULATION & UTILITY METHODS
//   // ═══════════════════════════════════════════════════════════════════════════
//   double _calculateOptimalScrollPosition(int targetMessageIndex) {
//     if (!_scrollController.hasClients) return 0.0;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//     final messages = chatProvider.chatsData.records;

//     if (messages == null || targetMessageIndex >= messages.length) {
//       return 0.0;
//     }

//     double totalHeightFromBottom = 0.0;

//     for (int i = 0; i < targetMessageIndex; i++) {
//       totalHeightFromBottom += _getAccurateMessageHeight(i);
//     }

//     final targetMessageHeight = _getAccurateMessageHeight(targetMessageIndex);
//     totalHeightFromBottom += (targetMessageHeight / 2);

//     final viewportHeight = _scrollController.position.viewportDimension;
//     final targetScrollOffset = totalHeightFromBottom - (viewportHeight / 2);

//     final minOffset = _scrollController.position.minScrollExtent;
//     final maxOffset = _scrollController.position.maxScrollExtent;

//     final clampedOffset = targetScrollOffset.clamp(minOffset, maxOffset);

//     _logger.d(
//       '📐 Scroll calculation for message $targetMessageIndex:\n'
//       '  - Height from bottom: ${totalHeightFromBottom.toInt()}\n'
//       '  - Target height: ${targetMessageHeight.toInt()}\n'
//       '  - Viewport height: ${viewportHeight.toInt()}\n'
//       '  - Raw target offset: ${targetScrollOffset.toInt()}\n'
//       '  - Clamped offset: ${clampedOffset.toInt()}\n'
//       '  - Scroll bounds: [${minOffset.toInt()}, ${maxOffset.toInt()}]',
//     );

//     return clampedOffset;
//   }

//   double _getAccurateMessageHeight(int messageIndex) {
//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//     final messages = chatProvider.chatsData.records;

//     if (messages == null || messageIndex >= messages.length) {
//       return 120.0;
//     }

//     final message = messages[messageIndex];
//     double height = 90.0;

//     final messageType = message.messageType?.toLowerCase() ?? 'text';
//     final content = message.messageContent ?? '';

//     switch (messageType) {
//       case 'image':
//       case 'photo':
//         height = 280.0;
//         break;
//       case 'video':
//         height = 250.0;
//         break;
//       case 'gif':
//         height = 200.0;
//         break;
//       case 'document':
//       case 'file':
//       case 'pdf':
//         height = 120.0;
//         break;
//       case 'location':
//         height = 180.0;
//         break;
//       case 'audio':
//       case 'voice':
//         height = 80.0;
//         break;
//       case 'contact':
//         height = 110.0;
//         break;
//       default:
//         height += _calculateTextMessageHeight(content);
//     }

//     if (message.replyTo != null) {
//       height += 60.0;
//     }

//     if (message.pinned == true) {
//       height += 35.0;
//     }

//     height += 25.0;

//     return height.clamp(90.0, 450.0);
//   }

//   double _calculateTextMessageHeight(String content) {
//     if (content.isEmpty) return 30.0;

//     final explicitLines = '\n'.allMatches(content).length + 1;
//     const double averageCharsPerLine = 40.0;
//     final estimatedWrappedLines = (content.length / averageCharsPerLine).ceil();
//     final totalLines = math.max(explicitLines, estimatedWrappedLines);
//     const double lineHeight = 24.0;

//     return (totalLines * lineHeight).clamp(30.0, 200.0);
//   }

//   String _getReplyPreviewText(chats.Records message) {
//     switch (message.messageType?.toLowerCase()) {
//       case 'image':
//         return '📷 Image';
//       case 'video':
//         return '🎥 Video';
//       case 'document':
//       case 'doc':
//       case 'pdf':
//         return '📄 Document';
//       case 'location':
//         return '📍 Location';
//       case 'text':
//       default:
//         return message.messageContent ?? 'Message';
//     }
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // FEEDBACK & NOTIFICATION METHODS
//   // ═══════════════════════════════════════════════════════════════════════════
//   void _showMessageFoundFeedback() {
//     if (!mounted) return;
//     final messenger = ScaffoldMessenger.of(context);

//     // This will immediately dismiss the progress bar:
//     messenger.hideCurrentSnackBar();

//     // Then show your “found” confirmation:
//     messenger.showSnackBar(
//       SnackBar(
//         content: Text('✅ Message found!'),
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }

//   void _showHighlightSuccessFeedback() {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(4),
//               decoration: BoxDecoration(
//                 color: Colors.white.withValues(alpha: 0.2),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(
//                 Icons.center_focus_strong,
//                 color: Colors.white,
//                 size: 16,
//               ),
//             ),
//             const SizedBox(width: 8),
//             const Text('Message found and highlighted'),
//           ],
//         ),
//         duration: const Duration(seconds: 2),
//         backgroundColor: AppColors.appPriSecColor.primaryColor,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }

//   void _showHighlightErrorFeedback() {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             const Icon(Icons.search_off, color: Colors.white, size: 20),
//             const SizedBox(width: 8),
//             const Text('Unable to locate message'),
//           ],
//         ),
//         backgroundColor: AppColors.textColor.textErrorColor,
//       ),
//     );
//   }

//   void _showMessageNotFoundFeedback() {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(Icons.search_off, color: Colors.white, size: 20),
//             SizedBox(width: 8),
//             Text('Message not found in chat history'),
//           ],
//         ),
//         backgroundColor: AppColors.textColor.textErrorColor,
//       ),
//     );
//   }

//   void _showSearchingLoader(int messageId) {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).clearSnackBars();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 color: Colors.white,
//               ),
//             ),
//             SizedBox(width: 12),
//             Text('Searching for message...'),
//           ],
//         ),
//         duration: Duration(seconds: 30),
//         backgroundColor: AppColors.appPriSecColor.primaryColor,
//       ),
//     );
//   }

//   void _updateSearchProgress(int attemptCount, int messageId) {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).clearSnackBars();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 color: Colors.white,
//                 value: attemptCount / 10,
//               ),
//             ),
//             SizedBox(width: 12),
//             //we don't know the count that's why use while loop
//             Expanded(
//               child: Text(
//                 // 'Searching for message... (${attemptCount})',
//                 'Searching for message...',
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//           ],
//         ),
//         duration: Duration(seconds: 30),
//         backgroundColor: AppColors.appPriSecColor.primaryColor,
//       ),
//     );
//   }

//   void _showDocumentError(String error) {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text("Document error: $error"),
//         backgroundColor: AppColors.textColor.textErrorColor,
//       ),
//     );
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // DEBUG & UTILITY METHODS
//   // ═══════════════════════════════════════════════════════════════════════════

//   void _debugPinnedMessagesState() {
//     if (_chatProvider != null) {
//       final pinnedCount =
//           _chatProvider!.pinnedMessagesData.records?.length ?? 0;
//       final chatCount = _chatProvider!.chatsData.records?.length ?? 0;

//       _logger.d(
//         "🔍 DEBUG - Chat messages: $chatCount, Pinned messages: $pinnedCount",
//       );

//       if (pinnedCount > 0) {
//         _logger.d("✅ Pinned messages available after initialization:");
//         for (var msg in _chatProvider!.pinnedMessagesData.records!) {
//           _logger.d("  - ${msg.messageId}: ${msg.messageContent}");
//         }
//       } else {
//         _logger.d("⚠️ No pinned messages found after initialization");

//         if (chatCount > 0) {
//           final pinnedInMain =
//               _chatProvider!.chatsData.records!
//                   .where((r) => r.pinned == true)
//                   .toList();
//           if (pinnedInMain.isNotEmpty) {
//             _logger.w(
//               "🚨 Found ${pinnedInMain.length} pinned messages in main chat data but not in pinned collection!",
//             );
//           }
//         }
//       }
//     }
//   }

//   // ═══════════════════════════════════════════════════════════════════════════
//   // ADVANCED SCROLLING METHODS (Unused but kept for reference)
//   // ═══════════════════════════════════════════════════════════════════════════

//   Future<void> _ensureMessageIsBuilt(int messageId, int messageIndex) async {
//     if (_isDisposed || !mounted || !_scrollController.hasClients) return;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//     final messages = chatProvider.chatsData.records ?? [];

//     int validIndex = messageIndex;
//     if (messageIndex < 0 || messageIndex >= messages.length) {
//       validIndex = messages.indexWhere((msg) => msg.messageId == messageId);
//       if (validIndex == -1) {
//         _logger.w('⚠️ Cannot build message $messageId - not found in messages');
//         return;
//       }
//     }

//     _logger.d('⚡ Ensuring message $messageId at index $validIndex is built');

//     final existingKey = _messageKeys[messageId];
//     if (existingKey?.currentContext != null) {
//       _logger.d('✅ Message $messageId context already available');
//       return;
//     }

//     double targetPosition = _calculateOptimalScrollPosition(validIndex);

//     _logger.d('⚡ Jumping to position: ${targetPosition.toInt()}');
//     _scrollController.jumpTo(targetPosition);

//     await WidgetsBinding.instance.endOfFrame;
//     await Future.delayed(Duration(milliseconds: 100));

//     for (int attempt = 0; attempt < 3; attempt++) {
//       if (_isDisposed || !mounted) return;

//       final key = _messageKeys[messageId];
//       if (key?.currentContext != null) {
//         _logger.d(
//           '✅ Message $messageId context available after attempt $attempt',
//         );
//         return;
//       }

//       double adjustedPosition =
//           targetPosition + (attempt * 100.0 * (attempt % 2 == 0 ? 1 : -1));
//       adjustedPosition = adjustedPosition.clamp(
//         _scrollController.position.minScrollExtent,
//         _scrollController.position.maxScrollExtent,
//       );

//       _scrollController.jumpTo(adjustedPosition);
//       await Future.delayed(Duration(milliseconds: 100));
//     }

//     if (_messageKeys[messageId]?.currentContext == null && mounted) {
//       _logger.d('🔄 Force rebuild for message $messageId');
//       setState(() {
//         // Force rebuild
//       });

//       await WidgetsBinding.instance.endOfFrame;
//       await Future.delayed(Duration(milliseconds: 100));
//     }

//     final finalKey = _messageKeys[messageId];
//     if (finalKey?.currentContext != null) {
//       _logger.d('✅ Message $messageId successfully built');
//     } else {
//       _logger.w('⚠️ Could not build message $messageId after all attempts');
//     }
//   }

//   Future<bool> _tryGlobalKeyScroll(
//     int messageId,
//     ChatProvider chatProvider,
//   ) async {
//     final key = _messageKeys[messageId];
//     if (key?.currentContext == null) {
//       _logger.d('🔑 GlobalKey context not available for message $messageId');
//       return false;
//     }

//     try {
//       _logger.d(
//         '🔑 Attempting reliable GlobalKey scroll for message $messageId',
//       );

//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//       }

//       chatProvider.highlightMessage(messageId);

//       await Future.delayed(Duration(milliseconds: 50));

//       if (key?.currentContext == null) {
//         _logger.w('🔑 Context became null after highlight delay');
//         return false;
//       }

//       await Scrollable.ensureVisible(
//         key!.currentContext!,
//         duration: Duration(milliseconds: 600),
//         curve: Curves.easeInOut,
//         alignment: 0.5,
//         alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
//       );

//       _showMessageFoundFeedback();
//       _logger.d('✅ GlobalKey scroll completed successfully');
//       return true;
//     } catch (e) {
//       _logger.e('❌ GlobalKey scroll failed: $e');
//       return false;
//     }
//   }

//   Future<void> _performSmoothScroll(double targetOffset) async {
//     if (!_scrollController.hasClients) return;

//     final currentOffset = _scrollController.offset;
//     final distance = (targetOffset - currentOffset).abs();

//     _logger.d(
//       '⚡ Fast jump: ${currentOffset.toInt()} → ${targetOffset.toInt()} (${distance.toInt()}px)',
//     );

//     _scrollController.jumpTo(targetOffset);

//     await Future.delayed(Duration(milliseconds: 50));

//     _logger.d('⚡ Fast jump completed instantly');
//   }

//   Future<void> _systematicScrollSearch(int messageId, int messageIndex) async {
//     if (_isDisposed || !mounted || !_scrollController.hasClients) return;

//     _logger.d('⚡ Starting fast jump search for message $messageId');

//     final totalMessages = _chatProvider?.chatsData.records?.length ?? 0;
//     if (totalMessages == 0 || messageIndex >= totalMessages) return;

//     final estimatedHeight = _getAccurateMessageHeight(messageIndex);
//     final targetPosition = _calculateOptimalScrollPosition(messageIndex);

//     final searchRange = estimatedHeight * 4;
//     final startPosition = (targetPosition - searchRange).clamp(
//       _scrollController.position.minScrollExtent,
//       _scrollController.position.maxScrollExtent,
//     );
//     final endPosition = (targetPosition + searchRange).clamp(
//       _scrollController.position.minScrollExtent,
//       _scrollController.position.maxScrollExtent,
//     );

//     _logger.d(
//       '⚡ Jump search range: ${startPosition.toInt()} to ${endPosition.toInt()}',
//     );

//     const double jumpIncrement = 100.0;
//     double currentPos = startPosition;

//     while (currentPos <= endPosition &&
//         _messageKeys[messageId]?.currentContext == null) {
//       if (_isDisposed || !mounted) return;

//       _scrollController.jumpTo(currentPos);
//       await Future.delayed(Duration(milliseconds: 30));

//       if (_messageKeys[messageId]?.currentContext != null) {
//         _logger.d(
//           '✅ Found message $messageId at position ${currentPos.toInt()}',
//         );
//         return;
//       }

//       currentPos += jumpIncrement;
//     }

//     _logger.d('⚡ Fast jump search completed for message $messageId');
//   }

//   Future<void> _performEnhancedIndexScroll(
//     int messageId,
//     ChatProvider chatProvider,
//   ) async {
//     final messages = chatProvider.chatsData.records ?? [];
//     final messageIndex = messages.indexWhere(
//       (msg) => msg.messageId == messageId,
//     );

//     if (messageIndex == -1) {
//       throw Exception('Message $messageId not found in current messages');
//     }

//     _logger.d(
//       '📍 Enhanced index scroll for message $messageId at index $messageIndex',
//     );

//     chatProvider.highlightMessage(messageId);

//     final targetOffset = _calculateEnhancedScrollOffset(messageIndex, messages);

//     if (!_scrollController.hasClients) {
//       throw Exception('ScrollController not available');
//     }

//     await _performSmoothScroll(targetOffset);

//     await _verifyAndAdjustPosition(messageId, targetOffset);

//     _showHighlightSuccessFeedback();
//   }

//   double _calculateEnhancedScrollOffset(
//     int targetIndex,
//     List<dynamic> messages,
//   ) {
//     if (!_scrollController.hasClients) return 0.0;

//     double totalHeight = 0.0;

//     for (int i = 0; i < targetIndex; i++) {
//       totalHeight += _getImprovedMessageHeight(i, messages[i]);
//     }

//     totalHeight +=
//         _getImprovedMessageHeight(targetIndex, messages[targetIndex]) / 2;

//     final viewportHeight = _scrollController.position.viewportDimension;
//     final targetScrollOffset = totalHeight - (viewportHeight / 2);

//     final minOffset = _scrollController.position.minScrollExtent;
//     final maxOffset = _scrollController.position.maxScrollExtent;

//     final clampedOffset = targetScrollOffset.clamp(minOffset, maxOffset);

//     _logger.d(
//       '📐 Enhanced calculation - Target: ${targetScrollOffset.toInt()}, Clamped: ${clampedOffset.toInt()}',
//     );

//     return clampedOffset;
//   }

//   double _getImprovedMessageHeight(int index, dynamic message) {
//     final messageId = message.messageId as int;

//     if (_messageHeightCache.containsKey(messageId)) {
//       return _messageHeightCache[messageId]!;
//     }

//     double height = _calculateBaseHeight(message);

//     _messageHeightCache[messageId] = height;

//     return height;
//   }

//   double _calculateBaseHeight(dynamic message) {
//     double baseHeight = 80.0;

//     final messageType = message.messageType?.toLowerCase() ?? 'text';
//     final content = message.messageContent ?? '';

//     switch (messageType) {
//       case 'image':
//       case 'gif':
//         baseHeight = 280.0;
//         break;
//       case 'video':
//         baseHeight = 250.0;
//         break;
//       case 'document':
//       case 'file':
//       case 'pdf':
//         baseHeight = 130.0;
//         break;
//       case 'location':
//         baseHeight = 180.0;
//         break;
//       case 'audio':
//       case 'voice':
//         baseHeight = 90.0;
//         break;
//       default:
//         baseHeight += _calculateTextHeight(content);
//     }

//     if (message.replyTo != null) baseHeight += 60.0;
//     if (message.pinned == true) baseHeight += 30.0;

//     return baseHeight.clamp(80.0, 400.0);
//   }

//   double _calculateTextHeight(String text) {
//     if (text.isEmpty) return 20.0;

//     const double averageCharsPerLine = 35.0;
//     const double lineHeight = 22.0;

//     final explicitLines = '\n'.allMatches(text).length + 1;
//     final wrappedLines = (text.length / averageCharsPerLine).ceil();
//     final totalLines = math.max(explicitLines, wrappedLines);

//     return (totalLines * lineHeight).clamp(20.0, 200.0);
//   }

//   Future<void> _verifyAndAdjustPosition(
//     int messageId,
//     double targetOffset,
//   ) async {
//     await Future.delayed(const Duration(milliseconds: 200));

//     if (!_scrollController.hasClients) return;

//     final currentOffset = _scrollController.offset;
//     final error = (targetOffset - currentOffset).abs();

//     if (error > 30) {
//       _logger.d('🔧 Position adjustment needed - Error: ${error.toInt()}px');

//       await _scrollController.animateTo(
//         targetOffset,
//         duration: const Duration(milliseconds: 200),
//         curve: Curves.easeInOut,
//       );
//     }

//     _logger.d('✅ Final position verified - Error: ${error.toInt()}px');
//   }

//   Future<void> _performEnhancedIndexScrollWithBuilding(
//     int messageId,
//     int messageIndex,
//     ChatProvider chatProvider,
//   ) async {
//     _logger.d(
//       '⚡ Fast index jump for message $messageId at index $messageIndex',
//     );

//     chatProvider.highlightMessage(messageId);

//     final targetOffset = _calculateOptimalScrollPosition(messageIndex);

//     if (!_scrollController.hasClients) {
//       throw Exception('ScrollController not available');
//     }

//     _scrollController.jumpTo(targetOffset);
//     await Future.delayed(Duration(milliseconds: 50));

//     await _ensureMessageIsBuilt(messageId, messageIndex);

//     await _verifyAndAdjustPositionFast(messageId, targetOffset);

//     final finalKey = _messageKeys[messageId];
//     if (finalKey?.currentContext != null) {
//       _logger.d('⚡ Final fast GlobalKey jump attempt after building');
//       try {
//         final RenderObject renderObject =
//             finalKey!.currentContext!.findRenderObject()!;
//         final RenderAbstractViewport viewport = RenderAbstractViewport.of(
//           renderObject,
//         );
//         final double exactOffset =
//             viewport.getOffsetToReveal(renderObject, 0.5).offset;

//         _scrollController.jumpTo(
//           exactOffset.clamp(
//             _scrollController.position.minScrollExtent,
//             _scrollController.position.maxScrollExtent,
//           ),
//         );
//       } catch (e) {
//         _logger.w('⚡ Final fast jump failed: $e');
//       }
//     }

//     _showHighlightSuccessFeedback();
//   }

//   Future<void> _verifyAndAdjustPositionFast(
//     int messageId,
//     double targetOffset,
//   ) async {
//     await Future.delayed(Duration(milliseconds: 100));

//     if (!_scrollController.hasClients) return;

//     final currentOffset = _scrollController.offset;
//     final error = (targetOffset - currentOffset).abs();

//     if (error > 30) {
//       _logger.d(
//         '⚡ Fast position adjustment needed - Error: ${error.toInt()}px',
//       );

//       _scrollController.jumpTo(targetOffset);
//     }

//     _logger.d('✅ Fast position verified - Error: ${error.toInt()}px');
//   }

//   Future<void> _findAndScrollToMessage(
//     int messageId,
//     ChatProvider chatProvider,
//   ) async {
//     if (_isDisposed || !mounted) return;

//     _logger.d('🔍 Starting auto-pagination search for message $messageId');

//     _showSearchingLoader(messageId);

//     try {
//       if (_isMessageInCurrentData(messageId, chatProvider)) {
//         _logger.d('✅ Message $messageId already loaded, scrolling directly');
//         ScaffoldMessenger.of(context).clearSnackBars();
//         await _scrollToMessageAndHighlight(messageId, chatProvider);
//         return;
//       }

//       await _autoPaginateToFindMessage(messageId, chatProvider);
//     } catch (e) {
//       _logger.e('❌ Error in auto-pagination search: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//         _showMessageNotFoundFeedback();
//       }
//     }
//   }
// }
