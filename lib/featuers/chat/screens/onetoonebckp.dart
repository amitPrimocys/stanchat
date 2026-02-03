// import 'dart:async';
// import 'dart:io';
// import 'dart:math' as math;
// import 'dart:ui' as ui;
// import 'dart:ui';

// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:provider/provider.dart';
// import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;
// import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
// import 'package:whoxa/featuers/chat/utils/message_utils.dart';
// import 'package:whoxa/featuers/chat/utils/time_stamp_formatter.dart';
// import 'package:whoxa/featuers/chat/widgets/call_widget.dart';
// import 'package:whoxa/featuers/chat/widgets/chat_appbar_title.dart';
// import 'package:whoxa/featuers/chat/widgets/chat_files_views_handle/image_view.dart';
// import 'package:whoxa/featuers/chat/widgets/chat_files_views_handle/video_view.dart';
// import 'package:whoxa/featuers/chat/widgets/chat_keyboard.dart';
// import 'package:whoxa/featuers/chat/widgets/chat_type_dialog.dart';
// import 'package:whoxa/featuers/chat/widgets/current_chat_widget/lastseen_widget.dart';
// import 'package:whoxa/featuers/chat/widgets/current_chat_widget/message_content_widget.dart';
// import 'package:whoxa/featuers/chat/widgets/current_chat_widget/pin_duration_dialog.dart';
// import 'package:whoxa/featuers/chat/widgets/pinned_widget.dart';
// import 'package:whoxa/utils/app_size_config.dart';
// import 'package:whoxa/utils/enums.dart';
// import 'package:whoxa/utils/logger.dart';
// import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
// import 'package:whoxa/utils/preference_key/constant/app_routes.dart';
// import 'package:whoxa/utils/preference_key/constant/app_text_style.dart';
// import 'package:whoxa/utils/preference_key/preference_key.dart';
// import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
// import 'package:whoxa/widgets/cusotm_blur_appbar.dart';

// class OneToOneChat extends StatefulWidget {
//   final int userId;
//   final String profilePic;
//   final String fullName;
//   final int? chatId;
//   final String? updatedAt;

//   const OneToOneChat({
//     super.key,
//     required this.userId,
//     required this.chatId,
//     required this.profilePic,
//     required this.fullName,
//     this.updatedAt,
//   });

//   @override
//   State<OneToOneChat> createState() => _OneToOneChatScreenState();
// }

// class _OneToOneChatScreenState extends State<OneToOneChat>
//     with WidgetsBindingObserver {
//   static const double _paginationThreshold =
//       200.0; // Distance from top to trigger
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final ConsoleAppLogger _logger = ConsoleAppLogger();

//   final FocusNode _messageFocusNode = FocusNode();
//   Timer? _typingTimer;
//   bool _isTyping = false;
//   bool _isAttachmentMenuOpen = false;
//   bool _isInitialized = false;
//   bool _isInitializing = false;

//   bool _isDisposed = false;
//   // Add loading states
//   bool _isLoadingCurrentUser = true;
//   bool _hasError = false;

//   String? _errorMessage;

//   // Cache for provider to avoid repeated lookups
//   ChatProvider? _chatProvider;
//   // File storage for message attachments
//   List<File>? _selectedImages;
//   List<File>? _selectedDocuments;
//   List<File>? _selectedVideos;

//   String _videoThumbnail = "";

//   //current loggedin user
//   String? _currentUserId;
//   // user online check when user not in chatlist
//   bool _isUserOnlineFromApi = false;
//   bool _isLoadingOnlineStatus = false;

//   String? _lastSeenFromApi;
//   // ✅ SIMPLIFIED PAGINATION STATE

//   Timer? _paginationDebounceTimer;
//   bool _hasTriggeredPagination = false;

//   final Map<int, GlobalKey> _messageKeys = {};
//   bool _isScrolling = false;
//   Timer? _scrollDebounceTimer;
//   String? _pendingHighlightMessageId;
//   final Map<int, double> _messageHeightCache = {};
//   bool _isInitialLoadComplete = false;

//   //chat focus tracking
//   bool _isScreenActive = false;
//   bool _hasInitializedFocus = false;

//   @override
//   Widget build(BuildContext context) {
//     if (_isDisposed) {
//       return Container(); // Return empty container if disposed
//     }

//     return WillPopScope(
//       onWillPop: () async {
//         _logger.d("🔙 System back button pressed - clearing chat focus");
//         _setScreenActive(false);

//         // Allow navigation after clearing focus
//         await Future.delayed(Duration(milliseconds: 100));
//         return true;
//       },
//       child: Scaffold(
//         backgroundColor: AppColors.white,
//         appBar: PreferredSize(
//           preferredSize: Size.fromHeight(SizeConfig.sizedBoxHeight(65)),
//           child: AppBar(
//             leadingWidth: 50,
//             leading: Padding(
//               padding: SizeConfig.getPadding(12),
//               child: IconButton(
//                 icon: Icon(Icons.arrow_back, color: Colors.white),
//                 onPressed: _navigateBack, // ✅ Use custom navigation method
//               ),
//             ),
//             flexibleSpace: flexibleSpaceSplash(),
//             backgroundColor: Colors.transparent,
//             shadowColor: Colors.transparent,
//             elevation: 0,
//             automaticallyImplyLeading: false,
//             titleSpacing: 5,
//             title: _buildAppBarTitle(),
//             actions: [CallWidget(onTapAudio: () {}, onTapVideo: () {})],
//           ),
//         ),
//         body: GestureDetector(
//           onTap: () {
//             if (mounted && !_isDisposed) {
//               setState(() {
//                 _isAttachmentMenuOpen = false;
//               });
//               FocusScope.of(context).unfocus();
//             }
//           },
//           child: innerContainer(
//             context,
//             child: Stack(
//               children: [
//                 Column(
//                   children: [
//                     _buildPinnedMessagesWidget(),
//                     Expanded(
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.only(
//                           topLeft: Radius.circular(32),
//                           topRight: Radius.circular(32),
//                         ),
//                         child: _buildChatContent(),
//                       ),
//                     ),
//                   ],
//                 ),
//                 _buildInputField(),
//                 _buildAttachmentMenu(),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();

//     if (!_isDisposed) {
//       _chatProvider = Provider.of<ChatProvider>(context, listen: false);

//       // Ensure focus is set when dependencies change
//       if (!_hasInitializedFocus && _chatProvider != null) {
//         _setScreenActive(true);
//         _hasInitializedFocus = true;
//       }
//     }
//   }

//   @override
//   void didUpdateWidget(OneToOneChat oldWidget) {
//     super.didUpdateWidget(oldWidget);

//     if (oldWidget.chatId != widget.chatId ||
//         oldWidget.userId != widget.userId) {
//       _logger.d("Chat changed, updating focus");
//       _setScreenActive(true);
//     }

//     _logger.d(
//       "didUpdateWidget called - old chatId: ${oldWidget.chatId}, new chatId: ${widget.chatId}",
//     );

//     // Only reinitialize if the chat ID actually changed and we have a valid new ID
//     if (!_isDisposed &&
//         oldWidget.chatId != widget.chatId &&
//         widget.chatId != null &&
//         widget.chatId! > 0) {
//       _logger.d("Chat ID changed, reinitializing chat");
//       _isInitialized = false;
//       _initializeChat();
//     }
//   }

//   // ✅ NEW: Handle app lifecycle changes
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);

//     _logger.d('App lifecycle state changed: $state');

//     if (_chatProvider != null) {
//       switch (state) {
//         case AppLifecycleState.resumed:
//           // App came to foreground
//           _chatProvider!.setAppForegroundState(true);

//           // ✅ Wait a moment for app to fully resume, then reactivate chat focus
//           Future.delayed(Duration(milliseconds: 500), () {
//             if (_isScreenActive && !_isDisposed && mounted) {
//               _setScreenActive(true); // Reactivate chat focus
//             }
//           });
//           break;

//         case AppLifecycleState.paused:
//         case AppLifecycleState.inactive:
//         case AppLifecycleState.detached:
//         case AppLifecycleState.hidden:
//           // App went to background or became inactive
//           _chatProvider!.setAppForegroundState(false);
//           break;
//       }
//     }
//   }

//   // ✅ NEW: Set screen active/inactive state
//   void _setScreenActive(bool isActive) {
//     if (_isDisposed || _chatProvider == null) return;

//     _isScreenActive = isActive;

//     _logger.d(
//       'Setting OneToOneChat screen active: $isActive, chatId: ${widget.chatId}, userId: ${widget.userId}',
//     );

//     // ✅ IMMEDIATE FOCUS UPDATE
//     _chatProvider!.setChatScreenActive(
//       widget.chatId ?? 0,
//       widget.userId,
//       isActive: isActive,
//     );

//     // ✅ ADDITIONAL LOGGING FOR DEBUGGING
//     if (!isActive) {
//       _logger.d('🚫 Chat screen deactivated - should stop auto-mark seen');
//     }

//     // ✅ ENHANCED: Mark messages as seen when screen becomes active (only for existing chats)
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

//   void _navigateBack() {
//     if (_isDisposed) return;

//     _logger.d("🔙 Navigating back - clearing chat focus first");

//     // ✅ CRITICAL: Clear focus BEFORE navigation
//     _setScreenActive(false);

//     // Small delay to ensure focus is cleared
//     Future.delayed(Duration(milliseconds: 100), () {
//       if (mounted && !_isDisposed) {
//         Navigator.of(context).pop();
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _logger.d("OneToOneChat dispose called");
//     _isDisposed = true;

//     if (_chatProvider != null) {
//       _chatProvider!.setChatScreenActive(
//         widget.chatId ?? 0,
//         widget.userId,
//         isActive: false,
//       );
//       _logger.d("✅ Chat screen focus cleared in dispose");
//     }
//     WidgetsBinding.instance.removeObserver(this);

//     // Clean up controller and timer first
//     _messageController.dispose();
//     _typingTimer?.cancel();
//     _scrollController.removeListener(_onScroll);
//     _scrollController.dispose();
//     _scrollDebounceTimer?.cancel();
//     _messageFocusNode.dispose();
//     _paginationDebounceTimer?.cancel();

//     // Reset current chat in provider safely with post frame callback
//     if (_chatProvider != null) {
//       // Use addPostFrameCallback to avoid calling setState during dispose
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         try {
//           // Check if the provider is still available and not disposed
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

//   @override
//   void initState() {
//     super.initState();
//     _logger.d("OneToOneChat initState called");
//     // ✅ NEW: Add app lifecycle observer
//     WidgetsBinding.instance.addObserver(this);

//     // Initialize everything in sequence
//     _initializeScreen();

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _setScreenActive(true);
//     });

//     // ✅ SIMPLIFIED SCROLL LISTENER
//     _scrollController.addListener(_onScroll);
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

//   // ✅ NEW: Auto-paginate until message is found
//   Future<void> _autoPaginateToFindMessage(
//     int messageId,
//     ChatProvider chatProvider,
//   ) async {
//     int attemptCount = 0;
//     const maxAttempts = 10; // Prevent infinite loops

//     _logger.d('🔄 Starting auto-pagination for message $messageId');

//     while (attemptCount < maxAttempts) {
//       // Check if we can load more messages
//       if (!chatProvider.hasMoreMessages) {
//         _logger.w('❌ No more messages to load, message $messageId not found');
//         throw Exception('Message not found in chat history');
//       }

//       // Check if provider is busy
//       if (chatProvider.isChatLoading || chatProvider.isRefreshing) {
//         _logger.d('⏳ Provider busy, waiting...');
//         await _waitForProviderToBeReady(chatProvider);
//       }

//       attemptCount++;
//       _logger.d(
//         '🔄 Auto-pagination attempt $attemptCount for message $messageId',
//       );

//       // Update loader with progress
//       _updateSearchProgress(attemptCount, messageId);

//       try {
//         // ✅ CRITICAL: Wait for the API response and data processing
//         await _loadMoreMessagesAndWait(chatProvider);

//         // ✅ Check if message is now loaded after the API response
//         if (_isMessageInCurrentData(messageId, chatProvider)) {
//           _logger.d('✅ Message $messageId found after $attemptCount attempts');

//           // Clear loader and scroll to message
//           if (mounted) {
//             ScaffoldMessenger.of(context).clearSnackBars();
//             await _scrollToMessageAndHighlight(messageId, chatProvider);
//           }
//           return;
//         }

//         _logger.d(
//           '📭 Message $messageId still not found after attempt $attemptCount',
//         );
//       } catch (e) {
//         _logger.e('❌ Error during auto-pagination attempt $attemptCount: $e');

//         // Wait a bit before retrying on error
//         await Future.delayed(Duration(milliseconds: 1000));
//       }
//     }

//     // If we reach here, we've exhausted all attempts
//     throw Exception(
//       'Message $messageId not found after $maxAttempts pagination attempts',
//     );
//   }

//   // ✅ NEW: Wait for provider to be ready
//   Future<void> _waitForProviderToBeReady(ChatProvider chatProvider) async {
//     int waitCount = 0;
//     const maxWaitCount = 20; // Maximum 10 seconds (20 * 500ms)

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

//   // ✅ NEW: Load more messages and wait for completion
//   Future<void> _loadMoreMessagesAndWait(ChatProvider chatProvider) async {
//     _logger.d('📡 Starting API call to load more messages');

//     // Store current message count to detect new messages
//     final currentMessageCount = chatProvider.chatsData.records?.length ?? 0;

//     // Trigger the API call
//     await chatProvider.loadMoreMessages();

//     // ✅ CRITICAL: Wait for the data to be actually processed and UI updated
//     await _waitForNewMessagesToLoad(chatProvider, currentMessageCount);

//     _logger.d('✅ API response processed and new messages loaded');
//   }

//   // ✅ NEW: Wait for new messages to be loaded and processed
//   Future<void> _waitForNewMessagesToLoad(
//     ChatProvider chatProvider,
//     int previousMessageCount,
//   ) async {
//     int waitCount = 0;
//     const maxWaitCount = 20; // Maximum 10 seconds

//     while (waitCount < maxWaitCount) {
//       if (_isDisposed || !mounted) {
//         throw Exception('Component disposed while waiting for messages');
//       }

//       // Check if provider is no longer loading
//       if (!chatProvider.isChatLoading && !chatProvider.isRefreshing) {
//         // Check if new messages were actually added
//         final currentMessageCount = chatProvider.chatsData.records?.length ?? 0;

//         if (currentMessageCount > previousMessageCount) {
//           _logger.d(
//             '📬 New messages detected: $previousMessageCount → $currentMessageCount',
//           );

//           // ✅ IMPORTANT: Give UI time to rebuild with new messages
//           await Future.delayed(Duration(milliseconds: 300));
//           return;
//         }

//         // If no new messages but provider says there are more, continue waiting
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

//   Widget _buildAppBarTitle() {
//     return Consumer<ChatProvider>(
//       builder: (context, chatProvider, _) {
//         final isOnline = _isUserOnlineFromChatListOrApi(chatProvider);

//         // Enhanced typing detection logic
//         bool isTyping = false;
//         final currentChatId = chatProvider.currentChatData.chatId ?? 0;

//         if (chatProvider.typingData.typing == true) {
//           isTyping = chatProvider.isUserTypingInChat(currentChatId);
//         }

//         // Get last seen time with API fallback
//         String? lastSeenTime = _getLastSeenTimeFromChatListOrApi(chatProvider);
//         _logger.d('lastSeenTime check : $lastSeenTime');

//         return ChatAppbarTitle(
//           profile: widget.profilePic,
//           title: widget.fullName,
//           statusWidget: LiveLastSeenWidget(
//             timestamp: lastSeenTime,
//             isOnline: isOnline,
//             isTyping: isTyping,
//           ),
//           onTap: () {
//             Navigator.pushNamed(context, AppRoutes.chatProfile);
//           },
//         );
//       },
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

//   Widget _buildChatContent() {
//     if (_hasError) {
//       return _buildErrorState();
//     }

//     if (_isLoadingCurrentUser || (_isInitializing && _currentUserId != null)) {
//       return _buildLoadingIndicator();
//     }

//     if (_currentUserId == null) {
//       return _buildErrorState();
//     }

//     return Consumer<ChatProvider>(
//       builder: (context, chatProvider, _) {
//         // ✅ NEW: Show search loading indicator when searching for message
//         // if (chatProvider.isSearchingForMessage) {
//         //   return _buildSearchLoadingIndicator(chatProvider);
//         // }

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
//             "Send a message to ${widget.fullName}",
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
//               // ✅ NEW: Reply preview widget
//               if (replyMessage != null)
//                 _buildReplyPreview(replyMessage, chatProvider),

//               // Chat keyboard
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

//                   // Handle typing indicator
//                   if (text.isNotEmpty && !_isTyping) {
//                     _isTyping = true;
//                     _sendTypingEvent(true);
//                   } else if (text.isEmpty && _isTyping) {
//                     _isTyping = false;
//                     _sendTypingEvent(false);
//                   }

//                   // Reset timer
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

//   // ✅ SOLUTION 10: Enhanced message widget with stable keys
//   Widget _buildMessageBubble(chats.Records chat) {
//     final messageId = chat.messageId!;

//     // ✅ CRITICAL: Create stable GlobalKey but preserve your UI
//     final key = _messageKeys.putIfAbsent(messageId, () {
//       _logger.d("🔑 Creating GlobalKey for message $messageId");
//       return GlobalKey();
//     });

//     return Consumer<ChatProvider>(
//       builder: (context, chatProvider, _) {
//         assert(
//           _currentUserId != null,
//           "Current user ID should not be null at this point",
//         );

//         final isSentByMe = chat.senderId.toString() == _currentUserId;
//         final isPinned = chat.pinned == true;

//         // ✅ GET REAL-TIME STAR STATUS FROM PROVIDER
//         final isStarred = chatProvider.isMessageStarred(messageId);

//         // ✅ ENHANCED: Better highlight detection (RESEARCH-BASED)
//         final isHighlighted = chatProvider.highlightedMessageId == messageId;
//         final isSearchTarget =
//             chatProvider.targetMessageId == messageId &&
//             chatProvider.isSearchingForMessage;

//         // ✅ FIX: Only apply animation styles when actually highlighted/searching
//         // This prevents unwanted animations on new messages
//         BoxDecoration? containerDecoration;
//         EdgeInsets containerPadding = EdgeInsets.zero;
//         Duration animationDuration =
//             Duration.zero; // ✅ KEY: Default to no animation

//         if (isHighlighted) {
//           // Strong highlight for found message with animation
//           containerDecoration = BoxDecoration(
//             color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.2),
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(
//               color: AppColors.appPriSecColor.primaryColor,
//               width: 2.5,
//             ),
//             boxShadow: [
//               BoxShadow(
//                 color: AppColors.appPriSecColor.primaryColor.withValues(alpha: 0.4),
//                 blurRadius: 12,
//                 offset: Offset(0, 4),
//                 spreadRadius: 2,
//               ),
//             ],
//           );
//           containerPadding = EdgeInsets.all(12);
//           animationDuration = Duration(
//             milliseconds: 600,
//           ); // ✅ Animation only for highlights
//         } else if (isSearchTarget) {
//           // Subtle highlight for search target
//           containerDecoration = BoxDecoration(
//             color: AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.1),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(
//               color: AppColors.appPriSecColor.secondaryColor.withValues(alpha: 0.6),
//               width: 1.5,
//             ),
//           );
//           containerPadding = EdgeInsets.all(8);
//           animationDuration = Duration(
//             milliseconds: 400,
//           ); // ✅ Shorter animation for search
//         }

//         // ✅ FIXED: Conditional AnimatedContainer
//         Widget messageContainer = Column(
//           crossAxisAlignment:
//               isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//           children: [
//             // ✅ NEW: Show star indicator at the top if message is starred
//             if (isStarred)
//               Padding(
//                 padding: EdgeInsets.only(
//                   left: isSentByMe ? 0 : 12,
//                   right: isSentByMe ? 12 : 0,
//                   bottom: 4,
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // ✅ Animated star icon with real-time updates
//                     TweenAnimationBuilder<double>(
//                       duration: Duration(milliseconds: 300),
//                       tween: Tween(begin: 0.8, end: 1.0),
//                       builder: (context, scale, child) {
//                         return Transform.scale(
//                           scale: scale,
//                           child: Icon(
//                             Icons.star,
//                             size: 14,
//                             color: Colors.amber,
//                           ),
//                         );
//                       },
//                     ),
//                     SizedBox(width: 4),
//                     Text(
//                       'Starred',
//                       style: AppTypography.captionText(context).copyWith(
//                         color: Colors.amber[700],
//                         fontSize: 11,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//             // ✅ KEEP YOUR ORIGINAL PIN INDICATOR
//             if (isPinned)
//               Padding(
//                 padding: EdgeInsets.only(
//                   left: isSentByMe ? 0 : 12,
//                   right: isSentByMe ? 12 : 0,
//                   bottom: 6,
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(
//                       Icons.push_pin,
//                       size: 14,
//                       color:
//                           isHighlighted
//                               ? AppColors.appPriSecColor.primaryColor
//                               : AppColors.appPriSecColor.primaryColor
//                                   .withValues(alpha: 0.7),
//                     ),
//                     SizedBox(width: 6),
//                     Text(
//                       'Pinned',
//                       style: AppTypography.captionText(context).copyWith(
//                         color:
//                             isHighlighted
//                                 ? AppColors.appPriSecColor.primaryColor
//                                 : AppColors.appPriSecColor.primaryColor
//                                     .withValues(alpha: 0.7),
//                         fontSize: 11,
//                         fontWeight:
//                             isHighlighted ? FontWeight.w700 : FontWeight.w500,
//                       ),
//                     ),
//                     // ✅ ENHANCED: "FOUND" indicator
//                     if (isHighlighted) ...[
//                       SizedBox(width: 10),
//                       TweenAnimationBuilder<double>(
//                         duration: Duration(milliseconds: 1500),
//                         tween: Tween(begin: 0.6, end: 1.0),
//                         builder: (context, scale, child) {
//                           return Transform.scale(
//                             scale: scale,
//                             child: Container(
//                               padding: EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 3,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: AppColors.appPriSecColor.primaryColor,
//                                 borderRadius: BorderRadius.circular(10),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: AppColors.appPriSecColor.primaryColor
//                                         .withValues(alpha: 0.3),
//                                     blurRadius: 4,
//                                     offset: Offset(0, 2),
//                                   ),
//                                 ],
//                               ),
//                               child: Text(
//                                 'FOUND',
//                                 style: AppTypography.captionText(
//                                   context,
//                                 ).copyWith(
//                                   color: Colors.white,
//                                   fontSize: 9,
//                                   fontWeight: FontWeight.bold,
//                                   letterSpacing: 0.5,
//                                 ),
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ],
//                   ],
//                 ),
//               ),

//             // ✅ CRITICAL: Assign GlobalKey to MessageContentWidget wrapper
//             KeyedSubtree(
//               key: key, // ✅ THIS IS THE KEY FOR SCROLLING
//               child: MessageContentWidget(
//                 chat: chat,
//                 currentUserId: _currentUserId!,
//                 chatProvider: chatProvider,
//                 onImageTap: _handleImageTap,
//                 onVideoTap: _handleVideoTap,
//                 onDocumentTap: _handleDocumentTap,
//                 onLocationTap: _handleLocationTap,
//                 // ✅ Pass the real-time star status to MessageContentWidget
//                 isStarred: isStarred,
//               ),
//             ),
//           ],
//         );

//         // ✅ KEY FIX: Only wrap with AnimatedContainer when there's actual animation needed
//         if (containerDecoration != null && animationDuration > Duration.zero) {
//           return Container(
//             margin: EdgeInsets.symmetric(vertical: 3),
//             alignment:
//                 isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
//             child: AnimatedContainer(
//               duration: animationDuration,
//               curve: Curves.easeInOut,
//               decoration: containerDecoration,
//               padding: containerPadding,
//               child: InkWell(
//                 onLongPress: () => _handleLongPress(chat),
//                 borderRadius: BorderRadius.circular(12),
//                 child: messageContainer,
//               ),
//             ),
//           );
//         } else {
//           // ✅ NO ANIMATION: Use regular Container for normal messages
//           return Container(
//             margin: EdgeInsets.symmetric(vertical: 3),
//             alignment:
//                 isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
//             child: InkWell(
//               onLongPress: () => _handleLongPress(chat),
//               borderRadius: BorderRadius.circular(12),
//               child: messageContainer,
//             ),
//           );
//         }
//       },
//     );
//   }

//   // ✅ SIMPLIFIED MESSAGES LIST BUILDER
//   // ✅ Your existing build method with enhanced message builder
//   Widget _buildMessagesList(List<dynamic> messages, ChatProvider chatProvider) {
//     // ✅ Use ChatProvider's pagination loading state
//     final totalItemCount =
//         messages.length + (chatProvider.isPaginationLoading ? 1 : 0);

//     return ListView.builder(
//       key: PageStorageKey(
//         'enhanced_chat_list_${widget.chatId}_${widget.userId}',
//       ),
//       padding: const EdgeInsets.only(
//         left: 10.0,
//         right: 10.0,
//         top: 10.0,
//         bottom: 120.0,
//       ),
//       reverse: true,
//       controller: _scrollController,
//       physics: const AlwaysScrollableScrollPhysics(),
//       cacheExtent: 1000,
//       itemCount: totalItemCount,
//       itemBuilder: (context, index) {
//         // ✅ Check ChatProvider's loading state
//         if (chatProvider.isPaginationLoading) {
//           return _buildPaginationLoader();
//         }

//         // Otherwise, build a normal message bubble
//         final message = messages[index];
//         return RepaintBoundary(child: _buildMessageBubble(message));
//       },
//     );
//   }

//   // ✅ SIMPLIFIED PAGINATION LOADER
//   Widget _buildPaginationLoader() {
//     return Container(
//       padding: EdgeInsets.all(16.0),
//       alignment: Alignment.center,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           SizedBox(
//             width: 20,
//             height: 20,
//             child: CircularProgressIndicator(
//               strokeWidth: 2.0,
//               valueColor: AlwaysStoppedAnimation<Color>(
//                 AppColors.appPriSecColor.primaryColor,
//               ),
//             ),
//           ),
//           SizedBox(width: 12),
//           Text(
//             'Loading older messages...',
//             style: AppTypography.smallText(
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

//         // ✅ NEW: Use the enhanced pinned messages widget
//         return PinnedMessagesWidget(
//           key: ValueKey(
//             'pinned_${pinnedMessages.length}_${pinnedMessages.hashCode}',
//           ),
//           scrollController: _scrollController,
//           onMessageTap: _handlePinnedMessageTap, // ✅ Uses your enhanced method
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

//   // ✅ NEW: Build reply preview widget
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

//   double _calculateBaseHeight(dynamic message) {
//     double baseHeight = 80.0; // Base message height with padding

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
//         // Enhanced text height calculation
//         baseHeight += _calculateTextHeight(content);
//     }

//     // Additional elements
//     if (message.replyTo != null) baseHeight += 60.0;
//     if (message.pinned == true) baseHeight += 30.0;

//     return baseHeight.clamp(80.0, 400.0);
//   }

//   // ✅ SOLUTION 6: Improved scroll offset calculation
//   double _calculateEnhancedScrollOffset(
//     int targetIndex,
//     List<dynamic> messages,
//   ) {
//     if (!_scrollController.hasClients) return 0.0;

//     double totalHeight = 0.0;

//     // Calculate height from bottom (newest) to target message
//     for (int i = 0; i < targetIndex; i++) {
//       totalHeight += _getImprovedMessageHeight(i, messages[i]);
//     }

//     // Add half of target message height for centering
//     totalHeight +=
//         _getImprovedMessageHeight(targetIndex, messages[targetIndex]) / 2;

//     // Calculate viewport center offset
//     final viewportHeight = _scrollController.position.viewportDimension;
//     final targetScrollOffset = totalHeight - (viewportHeight / 2);

//     // Clamp to valid scroll bounds
//     final minOffset = _scrollController.position.minScrollExtent;
//     final maxOffset = _scrollController.position.maxScrollExtent;

//     final clampedOffset = targetScrollOffset.clamp(minOffset, maxOffset);

//     _logger.d(
//       '📐 Enhanced calculation - Target: ${targetScrollOffset.toInt()}, Clamped: ${clampedOffset.toInt()}',
//     );

//     return clampedOffset;
//   }

//   double _calculateOptimalScrollPosition(int targetMessageIndex) {
//     if (!_scrollController.hasClients) return 0.0;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//     final messages = chatProvider.chatsData.records;

//     if (messages == null || targetMessageIndex >= messages.length) {
//       return 0.0;
//     }

//     // ✅ CRITICAL: For reverse ListView, calculate from the newest message (index 0)
//     double totalHeightFromBottom = 0.0;

//     // Sum heights from index 0 (newest) to target index (exclusive)
//     for (int i = 0; i < targetMessageIndex; i++) {
//       totalHeightFromBottom += _getAccurateMessageHeight(i);
//     }

//     // Add half of target message height to center it
//     final targetMessageHeight = _getAccurateMessageHeight(targetMessageIndex);
//     totalHeightFromBottom += (targetMessageHeight / 2);

//     // Calculate position to center the message in viewport
//     final viewportHeight = _scrollController.position.viewportDimension;
//     final targetScrollOffset = totalHeightFromBottom - (viewportHeight / 2);

//     // ✅ IMPORTANT: Clamp to valid scroll bounds
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

//   double _calculateTextHeight(String text) {
//     if (text.isEmpty) return 20.0;

//     // Count lines considering word wrap
//     const double averageCharsPerLine = 35.0;
//     const double lineHeight = 22.0;

//     final explicitLines = '\n'.allMatches(text).length + 1;
//     final wrappedLines = (text.length / averageCharsPerLine).ceil();
//     final totalLines = math.max(explicitLines, wrappedLines);

//     return (totalLines * lineHeight).clamp(20.0, 200.0);
//   }

//   double _calculateTextMessageHeight(String content) {
//     if (content.isEmpty) return 30.0;

//     // Count explicit line breaks
//     final explicitLines = '\n'.allMatches(content).length + 1;

//     // Estimate wrapped lines based on content length
//     // Adjust this value based on your actual message bubble width
//     const double averageCharsPerLine = 40.0; // Tune this for your UI
//     final estimatedWrappedLines = (content.length / averageCharsPerLine).ceil();

//     // Use the maximum of explicit and wrapped lines
//     final totalLines = math.max(explicitLines, estimatedWrappedLines);

//     // Each line is approximately 22px + line spacing
//     const double lineHeight = 24.0;

//     return (totalLines * lineHeight).clamp(30.0, 200.0);
//   }

//   // Add this method to check online status via API using ChatProvider
//   Future<void> _checkUserOnlineStatusFromApi() async {
//     if (_isDisposed || !mounted) return;

//     try {
//       setState(() {
//         _isLoadingOnlineStatus = true;
//       });

//       final chatProvider =
//           _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

//       // Call the online status API through ChatProvider
//       final response = await chatProvider.checkUserOnlineStatus(widget.userId);

//       if (!_isDisposed && mounted && response != null) {
//         setState(() {
//           _isUserOnlineFromApi = response['isOnline'] ?? false;
//           _lastSeenFromApi =
//               response['udatedAt']; // Note: API returns 'udatedAt'
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

//         // Check if there are pinned messages in main chat data
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

//   // Future<void> _ensureMessageIsBuilt(int messageId, int messageIndex) async {
//   //   if (_isDisposed || !mounted || !_scrollController.hasClients) return;

//   //   _logger.d('🔨 Ensuring message $messageId at index $messageIndex is built');

//   //   // Calculate approximate position of the message
//   //   double approximatePosition = 0.0;
//   //   for (int i = 0; i < messageIndex; i++) {
//   //     approximatePosition += _getAccurateMessageHeight(i);
//   //   }

//   //   // Scroll near the message to trigger its build
//   //   final targetOffset = approximatePosition.clamp(
//   //     _scrollController.position.minScrollExtent,
//   //     _scrollController.position.maxScrollExtent,
//   //   );

//   //   // Jump to approximate position to trigger widget build
//   //   _scrollController.jumpTo(targetOffset);

//   //   // Wait for multiple frames to ensure widget is built
//   //   for (int i = 0; i < 5; i++) {
//   //     await Future.delayed(Duration(milliseconds: 16)); // One frame
//   //     if (!_isDisposed && mounted) {
//   //       final key = _messageKeys[messageId];
//   //       if (key?.currentContext != null) {
//   //         _logger.d(
//   //           '✅ Message $messageId context available after ${i + 1} frames',
//   //         );
//   //         return;
//   //       }
//   //     }
//   //   }

//   //   // Force a rebuild if still not available
//   //   if (!_isDisposed && mounted) {
//   //     setState(() {
//   //       // Force rebuild
//   //     });

//   //     // Wait additional frames after forced rebuild
//   //     for (int i = 0; i < 3; i++) {
//   //       await Future.delayed(Duration(milliseconds: 16));
//   //       if (!_isDisposed && mounted) {
//   //         final key = _messageKeys[messageId];
//   //         if (key?.currentContext != null) {
//   //           _logger.d(
//   //             '✅ Message $messageId context available after forced rebuild',
//   //           );
//   //           return;
//   //         }
//   //       }
//   //     }
//   //   }

//   //   _logger.w('⚠️ Could not ensure message $messageId is built');
//   // }

//   Future<void> _ensureMessageIsBuilt(int messageId, int messageIndex) async {
//     if (_isDisposed || !mounted || !_scrollController.hasClients) return;

//     // ✅ FIX: Validate messageIndex before using it
//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//     final messages = chatProvider.chatsData.records ?? [];

//     // If messageIndex is invalid, find the correct one
//     int validIndex = messageIndex;
//     if (messageIndex < 0 || messageIndex >= messages.length) {
//       validIndex = messages.indexWhere((msg) => msg.messageId == messageId);
//       if (validIndex == -1) {
//         _logger.w('⚠️ Cannot build message $messageId - not found in messages');
//         return;
//       }
//     }

//     _logger.d('⚡ Ensuring message $messageId at index $validIndex is built');

//     // Strategy 1: Check if GlobalKey context already exists
//     final existingKey = _messageKeys[messageId];
//     if (existingKey?.currentContext != null) {
//       _logger.d('✅ Message $messageId context already available');
//       return;
//     }

//     // Strategy 2: Simple position jump
//     double targetPosition = _calculateOptimalScrollPosition(validIndex);

//     _logger.d('⚡ Jumping to position: ${targetPosition.toInt()}');
//     _scrollController.jumpTo(targetPosition);

//     // Wait for build
//     await WidgetsBinding.instance.endOfFrame;
//     await Future.delayed(Duration(milliseconds: 100));

//     // Strategy 3: Simple retry with small adjustments
//     for (int attempt = 0; attempt < 3; attempt++) {
//       if (_isDisposed || !mounted) return;

//       // Check if context is now available
//       final key = _messageKeys[messageId];
//       if (key?.currentContext != null) {
//         _logger.d(
//           '✅ Message $messageId context available after attempt $attempt',
//         );
//         return;
//       }

//       // Small position adjustment
//       double adjustedPosition =
//           targetPosition + (attempt * 100.0 * (attempt % 2 == 0 ? 1 : -1));
//       adjustedPosition = adjustedPosition.clamp(
//         _scrollController.position.minScrollExtent,
//         _scrollController.position.maxScrollExtent,
//       );

//       _scrollController.jumpTo(adjustedPosition);
//       await Future.delayed(Duration(milliseconds: 100));
//     }

//     // Strategy 4: Force rebuild if still not available
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

//   Future<void> _systematicScrollSearch(int messageId, int messageIndex) async {
//     if (_isDisposed || !mounted || !_scrollController.hasClients) return;

//     _logger.d('⚡ Starting fast jump search for message $messageId');

//     final totalMessages = _chatProvider?.chatsData.records?.length ?? 0;
//     if (totalMessages == 0 || messageIndex >= totalMessages) return;

//     // Calculate search range
//     final estimatedHeight = _getAccurateMessageHeight(messageIndex);
//     final targetPosition = _calculateOptimalScrollPosition(messageIndex);

//     // Wider search range for jump method
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

//     // Fast jumps with larger increments
//     const double jumpIncrement = 100.0;
//     double currentPos = startPosition;

//     while (currentPos <= endPosition &&
//         _messageKeys[messageId]?.currentContext == null) {
//       if (_isDisposed || !mounted) return;

//       _scrollController.jumpTo(currentPos);
//       await Future.delayed(Duration(milliseconds: 30)); // Very short delay

//       // Check if message is now built
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

//   Future<void> _executePinUnpinAction(
//     ChatProvider chatProvider,
//     int chatId,
//     int messageId,
//     int days,
//   ) async {
//     try {
//       // ✅ DEBUG: Log current state before pin/unpin
//       _logger.d('🔧 Pin/Unpin Request:');
//       _logger.d('  Message ID: $messageId');
//       _logger.d('  Chat ID: $chatId');
//       _logger.d('  Duration (days): $days');
//       _logger.d('  Current User ID: $_currentUserId');

//       // Show loading indicator
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
//                 Text("${days == 0 ? 'Unpinning' : 'Pinning'} message..."),
//               ],
//             ),
//             backgroundColor: AppColors.appPriSecColor.primaryColor,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }

//       // ✅ EXECUTE PIN/UNPIN VIA API WITH DAYS PARAMETER
//       final success = await chatProvider.pinUnpinMessage(
//         chatId,
//         messageId,
//         days, // Pass the selected days
//       );

//       // Clear loading snackbar
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//       }

//       // ✅ DEBUG: Log result
//       _logger.d('🔧 Pin/Unpin Result: $success');

//       if (success && mounted) {
//         // Success feedback with duration info
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

//         // ✅ DEBUG: Force UI update after successful pin/unpin
//         _logger.d('🔧 Forcing UI update after pin/unpin');
//         if (mounted) {
//           setState(() {
//             // This will trigger a rebuild
//           });
//         }
//       } else if (mounted) {
//         // Error feedback
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

//       // ✅ DEBUG: Log current pinned messages count after operation
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

//       // Clear loading snackbar on error
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

//   Future<void> _findAndScrollToMessage(
//     int messageId,
//     ChatProvider chatProvider,
//   ) async {
//     if (_isDisposed || !mounted) return;

//     _logger.d('🔍 Starting auto-pagination search for message $messageId');

//     // Show loading indicator to user
//     _showSearchingLoader(messageId);

//     try {
//       // First check if message is already loaded
//       if (_isMessageInCurrentData(messageId, chatProvider)) {
//         _logger.d('✅ Message $messageId already loaded, scrolling directly');
//         ScaffoldMessenger.of(context).clearSnackBars();
//         await _scrollToMessageAndHighlight(messageId, chatProvider);
//         return;
//       }

//       // Start auto-pagination to find the message
//       await _autoPaginateToFindMessage(messageId, chatProvider);
//     } catch (e) {
//       _logger.e('❌ Error in auto-pagination search: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//         _showMessageNotFoundFeedback();
//       }
//     }
//   }

//   // ✅ MORE ACCURATE MESSAGE HEIGHT CALCULATION
//   double _getAccurateMessageHeight(int messageIndex) {
//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//     final messages = chatProvider.chatsData.records;

//     if (messages == null || messageIndex >= messages.length) {
//       return 120.0; // Safe fallback
//     }

//     final message = messages[messageIndex];
//     double height = 90.0; // Base height including padding, margins, avatar

//     // ✅ IMPROVED: More accurate height based on content analysis
//     final messageType = message.messageType?.toLowerCase() ?? 'text';
//     final content = message.messageContent ?? '';

//     switch (messageType) {
//       case 'image':
//       case 'photo':
//         height = 280.0; // Consistent image height
//         break;

//       case 'video':
//         height = 250.0; // Video with controls
//         break;

//       case 'gif':
//         height = 200.0; // GIF container
//         break;

//       case 'document':
//       case 'file':
//       case 'pdf':
//         height = 120.0; // Document preview
//         break;

//       case 'location':
//         height = 180.0; // Map preview
//         break;

//       case 'audio':
//       case 'voice':
//         height = 80.0; // Audio player
//         break;

//       case 'contact':
//         height = 110.0; // Contact card
//         break;

//       default:
//         // ✅ ENHANCED: Better text height calculation
//         height += _calculateTextMessageHeight(content);
//     }

//     // ✅ ADD HEIGHT FOR ADDITIONAL ELEMENTS
//     if (message.replyTo != null) {
//       height += 60.0; // Reply preview
//     }

//     if (message.pinned == true) {
//       height += 35.0; // Pinned indicator
//     }

//     // Message metadata (timestamp, status)
//     height += 25.0;

//     // ✅ ENSURE REASONABLE BOUNDS
//     return height.clamp(90.0, 450.0);
//   }

//   // ✅ SOLUTION 7: Improved message height calculation with caching
//   double _getImprovedMessageHeight(int index, dynamic message) {
//     final messageId = message.messageId as int;

//     // Use cached height if available
//     if (_messageHeightCache.containsKey(messageId)) {
//       return _messageHeightCache[messageId]!;
//     }

//     // Calculate height based on content
//     double height = _calculateBaseHeight(message);

//     // Cache the calculated height
//     _messageHeightCache[messageId] = height;

//     return height;
//   }

//   // NEW: Method to get last seen time with multiple fallback sources
//   String? _getLastSeenTimeFromChatListOrApi(ChatProvider chatProvider) {
//     _logger.d(
//       "Getting last seen time from chat list for userId: ${widget.userId}",
//     );

//     final chatListData = chatProvider.chatListData;
//     if (chatListData.chats == null || chatListData.chats!.isEmpty) {
//       _logger.w("No chat list data available, using API data");
//       return _lastSeenFromApi; // Use API data if no chat list
//     }

//     _logger.d("Searching through ${chatListData.chats!.length} chats");

//     // Find the chat with matching peer user
//     for (final chat in chatListData.chats!) {
//       final peerUserData = chat.peerUserData;

//       if (peerUserData != null && peerUserData.userId == widget.userId) {
//         _logger.d("Found matching peer user data for userId: ${widget.userId}");

//         // Get the updatedAt from PeerUserData
//         final lastSeen = peerUserData.updatedAt;

//         if (lastSeen != null && lastSeen.trim().isNotEmpty) {
//           _logger.i("Found last seen from peer user data: $lastSeen");
//           return lastSeen;
//         } else {
//           _logger.w("PeerUserData.updatedAt is null or empty");
//         }

//         // If PeerUserData.updatedAt is not available, try createdAt
//         final createdAt = peerUserData.createdAt;
//         if (createdAt != null && createdAt.trim().isNotEmpty) {
//           _logger.i("Using createdAt as fallback: $createdAt");
//           return createdAt;
//         }
//       }
//     }

//     _logger.w("User ${widget.userId} not found in chat list, using API data");

//     // If user not found in chat list, use API data
//     return _lastSeenFromApi ?? widget.updatedAt;
//   }

//   // ✅ NEW: Get preview text for reply
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

//   //DELETE MESSAGE
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

//       // Check permissions first
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

//       // Show confirmation dialog for delete for everyone
//       if (isDeleteForEveryone) {
//         final confirmed = await _showDeleteConfirmationDialog(
//           isDeleteForEveryone,
//         );
//         if (!confirmed) return;
//       }

//       // Show loading indicator
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

//       // Execute deletion
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

//       // Clear loading snackbar
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//       }

//       if (success && mounted) {
//         // Success feedback
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
//         // Error feedback
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

//   void _handleDocumentTap(chats.Records chat) {
//     if (_isDisposed || !mounted) return;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

//     // Handle document download and opening
//     chatProvider.downloadPdfWithProgress(
//       pdfUrl: chat.messageContent!,
//       onProgress: (progress) {
//         // Show download progress if needed
//         _logger.d("Download progress: ${(progress * 100).toInt()}%");
//       },
//       onComplete: (filePath, metadata) {
//         if (filePath != null) {
//           _logger.d("Document downloaded: $filePath");
//           // Open the document
//           _openDocument(filePath);
//         } else {
//           _logger.e("Document download failed: $metadata");
//           // Show error message
//           _showDocumentError(metadata ?? "Download failed");
//         }
//       },
//     );
//   }

//   // ========================================
//   // Message handling methods to add to OneToOneChat
//   // ========================================

//   void _handleImageTap(String imageUrl) {
//     if (_isDisposed || !mounted) return;

//     context.viewImage(
//       imageSource: imageUrl,
//       imageTitle: 'Chat Image',
//       heroTag: imageUrl, // hero tag
//     );
//   }

//   void _handleLocationTap(double latitude, double longitude) {
//     if (_isDisposed || !mounted) return;
//   }

//   void _handleLongPress(chats.Records message) {
//     if (!_isDisposed && mounted && message.deletedForEveryone != true) {
//       final chatProvider = Provider.of<ChatProvider>(context, listen: false);

//       // ✅ Get real-time star status from provider
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
//         // ✅ Pass the current real-time star status to your dialog
//         isStarred: isCurrentlyStarred,
//       );
//     }
//   }

//   // ✅ Enhanced pinned message tap handler
//   // void _handlePinnedMessageTap(int messageId) {
//   //   if (_isDisposed || !mounted) return;

//   //   final chatProvider = Provider.of<ChatProvider>(context, listen: false);

//   //   _logger.d('🎯 Enhanced pinned message tapped: $messageId');

//   //   try {
//   //     // Collapse pinned widget first
//   //     if (chatProvider.isPinnedMessagesExpanded) {
//   //       chatProvider.setPinnedMessagesExpanded(false);
//   //     }

//   //     // Wait for UI update, then start search with auto-pagination
//   //     WidgetsBinding.instance.addPostFrameCallback((_) {
//   //       if (_isDisposed || !mounted) return;
//   //       _findAndScrollToMessage(messageId, chatProvider);
//   //     });
//   //   } catch (e) {
//   //     _logger.e('❌ Error handling enhanced pinned message tap: $e');
//   //     _showHighlightErrorFeedback();
//   //   }
//   // }

//   void _handlePinnedMessageTap(int messageId) {
//     if (_isDisposed || !mounted) return;

//     final chatProvider = Provider.of<ChatProvider>(context, listen: false);

//     _logger.d('🎯 Pinned message tapped: $messageId');

//     try {
//       // Collapse pinned widget first
//       if (chatProvider.isPinnedMessagesExpanded) {
//         chatProvider.setPinnedMessagesExpanded(false);
//       }

//       // Wait for UI update, then scroll with simple reliable method
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (_isDisposed || !mounted) return;

//         // Use the fixed scroll method
//         _scrollToMessageAndHighlight(messageId, chatProvider);
//       });
//     } catch (e) {
//       _logger.e('❌ Error handling pinned message tap: $e');
//       _showHighlightErrorFeedback();
//     }
//   }

//   Future<void> _handlePinUnpinMessage(chats.Records message) async {
//     if (_isDisposed || !mounted || _currentUserId == null) return;

//     try {
//       final chatProvider =
//           _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//       final chatId = widget.chatId ?? 0;

//       if (chatId <= 0 || message.messageId == null) {
//         _logger.w("Invalid chat ID or message ID for pin/unpin");
//         return;
//       }

//       // ✅ CHECK PERMISSIONS FIRST
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

//       // ✅ IF MESSAGE IS ALREADY PINNED, UNPIN DIRECTLY
//       if (message.pinned == true) {
//         await _executePinUnpinAction(
//           chatProvider,
//           chatId,
//           message.messageId!,
//           0,
//         );
//         return;
//       }

//       // ✅ IF MESSAGE IS NOT PINNED, SHOW DURATION SELECTION DIALOG
//       showDialog(
//         context: context,
//         barrierDismissible: true,
//         builder: (BuildContext context) {
//           return PinDurationDialog(
//             onDurationSelected: (int days) async {
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

//   Future<void> _handleStarUnstarMessage(chats.Records message) async {
//     if (_isDisposed || !mounted || _currentUserId == null) return;

//     try {
//       final chatProvider = Provider.of<ChatProvider>(context, listen: false);

//       // ✅ Get current star status from provider for accurate feedback
//       final isCurrentlyStarred = chatProvider.isMessageStarred(
//         message.messageId!,
//       );

//       if (message.messageId == null) {
//         _logger.w("Invalid message ID for star/unstar");
//         return;
//       }

//       // ✅ Check permissions first
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

//       // Show loading indicator with current action
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

//       // ✅ Execute star/unstar via API
//       final success = await chatProvider.starUnstarMessage(message.messageId!);

//       // Clear loading snackbar
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//       }

//       if (success && mounted) {
//         // ✅ Success feedback based on previous state
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

//         // ✅ UI will automatically update via socket listener
//         // No manual refresh needed - the Consumer will rebuild automatically

//         _logger.d(
//           '⭐ Star/unstar completed, UI will update automatically via socket',
//         );
//       } else if (mounted) {
//         // Error feedback
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

//   // Handle reply from dialog
//   void _handleReply(chats.Records message) {
//     if (_isDisposed || !mounted) return;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

//     // Set the message to reply to
//     chatProvider.setReplyToMessage(message);

//     // Focus on the text input
//     _messageFocusNode.requestFocus();

//     _logger.d('Reply set for message: ${message.messageId}');
//   }

//   // ✅ NEW: Handle unpin message directly from pinned messages widget
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

//       // ✅ DIRECT UNPIN: Since this is called from the pinned widget,
//       // we know the message is pinned, so we're unpinning it
//       _logger.d('🔧 Unpin Request from Pinned Widget:');
//       _logger.d('  Message ID: ${message.messageId}');
//       _logger.d('  Chat ID: $chatId');
//       _logger.d('  Current User ID: $_currentUserId');

//       // ✅ CHECK PERMISSIONS FIRST
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

//       // Show loading indicator
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

//       // ✅ EXECUTE UNPIN VIA API
//       final success = await chatProvider.pinUnpinMessage(
//         chatId,
//         message.messageId!,
//       );

//       // Clear loading snackbar
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//       }

//       // ✅ DEBUG: Log result
//       _logger.d('🔧 Unpin Result: $success');

//       if (success && mounted) {
//         // Success feedback
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

//         // ✅ AUTO-COLLAPSE: Collapse pinned messages if this was the last one
//         final remainingPinnedCount =
//             chatProvider.pinnedMessagesData.records?.length ?? 0;
//         if (remainingPinnedCount <= 1 &&
//             chatProvider.isPinnedMessagesExpanded) {
//           // Small delay to let the UI update, then collapse
//           Future.delayed(Duration(milliseconds: 500), () {
//             if (!_isDisposed && mounted) {
//               chatProvider.setPinnedMessagesExpanded(false);
//             }
//           });
//         }

//         // ✅ FORCE UI UPDATE
//         if (mounted) {
//           setState(() {
//             // This will trigger a rebuild
//           });
//         }
//       } else if (mounted) {
//         // Error feedback
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

//       // ✅ DEBUG: Log current pinned messages count after operation
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

//       // Clear loading snackbar on error
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

//   // ✅ NEW: Handle unpin message directly from pinned messages widget
//   Future<void> _handleUnStarMessage(chats.Records message) async {
//     if (_isDisposed || !mounted || _currentUserId == null) return;

//     try {
//       final chatProvider =
//           _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//       final chatId = widget.chatId ?? 0;

//       if (chatId <= 0 || message.messageId == null) {
//         _logger.w("Invalid chat ID or message ID for unpin");
//         return;
//       }

//       // ✅ DIRECT UNPIN: Since this is called from the pinned widget,
//       // we know the message is pinned, so we're unpinning it
//       _logger.d('🔧 UnStar Request from Pinned Widget:');
//       _logger.d('  Message ID: ${message.messageId}');
//       _logger.d('  Chat ID: $chatId');
//       _logger.d('  Current User ID: $_currentUserId');

//       // ✅ CHECK PERMISSIONS FIRST
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

//       // Show loading indicator
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

//       // ✅ EXECUTE UNPIN VIA API
//       final success = await chatProvider.starUnstarMessage(message.messageId!);

//       // Clear loading snackbar
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//       }

//       // ✅ DEBUG: Log result
//       _logger.d('🔧 Unstar Result: $success');

//       if (success && mounted) {
//         // Success feedback
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Row(
//               children: [
//                 Icon(Icons.check_circle, color: Colors.white, size: 20),
//                 SizedBox(width: 8),
//                 Text("Message unstar successfully"),
//               ],
//             ),
//             backgroundColor: AppColors.appPriSecColor.primaryColor,
//             duration: Duration(seconds: 2),
//           ),
//         );

//         // ✅ FORCE UI UPDATE
//         if (mounted) {
//           setState(() {
//             // This will trigger a rebuild
//           });
//         }
//       } else if (mounted) {
//         // Error feedback
//         final errorMessage = chatProvider.error ?? "Failed to unstar message";

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
//       _logger.e("❌ Error handling unstar message: $e");

//       // Clear loading snackbar on error
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

//   void _handleVideoTap(String videoUrl) {
//     if (_isDisposed || !mounted) return;
//     debugPrint('video tap url : $videoUrl');
//     context.viewVideo(videoUrl: videoUrl);
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
//         // Use the improved method to load chat messages
//         await chatProvider.loadChatMessages(
//           chatId: chatId,
//           peerId: widget.userId,
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

//   /// Initialize the entire screen with proper error handling
//   Future<void> _initializeScreen() async {
//     if (_isDisposed) return;

//     try {
//       _logger.d("🚀 Starting screen initialization");
//       _isInitializing = true;

//       // Load current user ID first
//       await _loadCurrentUserId();

//       if (_isDisposed) return;

//       // Get provider instance
//       _chatProvider = Provider.of<ChatProvider>(context, listen: false);

//       if (_chatProvider == null) {
//         throw Exception('ChatProvider not available');
//       }

//       // CRITICAL: Always set current chat BEFORE loading messages
//       _logger.d(
//         "📝 Setting current chat context: chatId=${widget.chatId}, userId=${widget.userId}",
//       );
//       _chatProvider!.setCurrentChat(widget.chatId ?? 0, widget.userId);

//       // CRITICAL: Wait a moment for context to be set
//       await Future.delayed(Duration(milliseconds: 100));

//       if (_isDisposed) return;

//       // Load chat messages with proper context
//       _logger.d("📨 Loading chat messages");
//       await _chatProvider!.loadChatMessages(
//         chatId: widget.chatId ?? 0,
//         peerId: widget.userId,
//         clearExisting: true,
//       );

//       if (_isDisposed) return;

//       // ✅ IMPORTANT: Give time for socket response and pinned data processing
//       await Future.delayed(Duration(milliseconds: 500));

//       if (_isDisposed) return;

//       // Check online status if user not in chat list
//       await _checkUserOnlineStatusFromApi();

//       _isInitialized = true;
//       _isInitializing = false;
//       _hasError = false;
//       _errorMessage = null;

//       if (mounted) {
//         setState(() {});
//       }

//       _logger.d("✅ Screen initialization completed successfully");

//       // ✅ DEBUG: Check pinned messages state after initialization
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

//   // ✅ ENHANCED: Better check for message in current data
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

//       // ✅ DEBUG: Log some message IDs for debugging
//       final messageIds = messages.take(5).map((m) => m.messageId).toList();
//       _logger.d('📋 Sample loaded message IDs: $messageIds');
//     }

//     return found;
//   }

//   bool _isUserOnlineFromChatListOrApi(ChatProvider chatProvider) {
//     // First check if user is in online users from socket
//     final isOnlineFromSocket = chatProvider.isUserOnline(widget.userId);

//     if (isOnlineFromSocket) {
//       return true; // Socket data takes priority
//     }

//     // Check if user exists in chat list
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

//     // If user not in chat list, use API data
//     if (!userFoundInChatList) {
//       return _isUserOnlineFromApi;
//     }

//     // If user in chat list but not online via socket, return false
//     return false;
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

//   // ✅ SIMPLIFIED LOAD MORE MESSAGES
//   Future<void> _loadMoreMessages() async {
//     // ❌ REMOVE local state management
//     // if (_isPaginationLoading) {
//     //   _logger.d('⏭️ Already loading pagination, skipping');
//     //   return;
//     // }

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

//     // ✅ Use only ChatProvider's state checks
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

//     // ❌ REMOVE local state setting
//     // setState(() {
//     //   _isPaginationLoading = true;
//     // });

//     try {
//       // ✅ Let ChatProvider handle its own loading state
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
//     // ❌ REMOVE local state cleanup
//     // finally {
//     //   if (mounted) {
//     //     setState(() {
//     //       _isPaginationLoading = false;
//     //     });
//     //   }
//     // }
//   }

//   // ✅ SOLUTION 11: Optimized scroll listener
//   void _onScroll() {
//     if (_isDisposed || !_scrollController.hasClients || !mounted) return;

//     // Debounce scroll events
//     _scrollDebounceTimer?.cancel();
//     _scrollDebounceTimer = Timer(const Duration(milliseconds: 100), () {
//       _updateScrollState();
//     });
//   }

//   void _openDocument(String filePath) {
//     // Implement document opening logic
//     // You can use packages like url_launcher or open_file
//     _logger.d("Opening document: $filePath");
//   }

//   // ✅ SOLUTION 5: Enhanced index-based scroll with improved calculations
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

//     // Highlight the message immediately
//     chatProvider.highlightMessage(messageId);

//     // Calculate target position with improved accuracy
//     final targetOffset = _calculateEnhancedScrollOffset(messageIndex, messages);

//     if (!_scrollController.hasClients) {
//       throw Exception('ScrollController not available');
//     }

//     // Perform smooth scroll with multiple steps
//     await _performSmoothScroll(targetOffset);

//     // Verify and adjust position if needed
//     await _verifyAndAdjustPosition(messageId, targetOffset);

//     _showHighlightSuccessFeedback();
//   }

//   // ✅ SOLUTION 8: Smooth multi-step scrolling
//   Future<void> _performSmoothScroll(double targetOffset) async {
//     if (!_scrollController.hasClients) return;

//     final currentOffset = _scrollController.offset;
//     final distance = (targetOffset - currentOffset).abs();

//     _logger.d(
//       '⚡ Fast jump: ${currentOffset.toInt()} → ${targetOffset.toInt()} (${distance.toInt()}px)',
//     );

//     // ✅ ALWAYS USE JUMP FOR SPEED - No animation
//     _scrollController.jumpTo(targetOffset);

//     // Very short wait for UI to update
//     await Future.delayed(Duration(milliseconds: 50));

//     _logger.d('⚡ Fast jump completed instantly');
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

//       // ✅ Use the provider's refresh method
//       await chatProvider.refreshChatMessages(
//         chatId: chatId,
//         peerId: widget.userId,
//       );

//       _logger.d("✅ Chat refresh completed successfully");
//     } catch (e) {
//       _logger.e("❌ Error refreshing chat messages: $e");

//       // Show error message to user
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text("Failed to refresh messages: ${e.toString()}"),
//             backgroundColor: AppColors.textColor.textErrorColor,
//             duration: Duration(seconds: 2),
//           ),
//         );
//       }
//       rethrow; // Important: rethrow to let RefreshIndicator know about the error
//     }
//   }

//   // Auto-scroll to bottom when new messages arrive
//   void _scrollToBottom({bool animated = true}) {
//     if (_isDisposed || !_scrollController.hasClients || !mounted) return;

//     _logger.d('📍 Scrolling to bottom - animated: $animated');

//     if (animated) {
//       _scrollController.animateTo(
//         0.0, // For reverse: true, 0.0 is the bottom
//         duration: Duration(milliseconds: 300),
//         curve: Curves.easeOut,
//       );
//     } else {
//       _scrollController.jumpTo(0.0);
//     }
//   }

//   // Future<void> _scrollToMessageAndHighlight(
//   //   int messageId,
//   //   ChatProvider chatProvider,
//   // ) async {
//   //   if (_isDisposed || !mounted) return;

//   //   _logger.d('🎯 Enhanced scroll to message: $messageId');

//   //   try {
//   //     // Store pending highlight for retry attempts
//   //     _pendingHighlightMessageId = messageId.toString();

//   //     // Method 1: Try immediate GlobalKey scroll
//   //     if (await _tryGlobalKeyScroll(messageId, chatProvider)) {
//   //       return;
//   //     }

//   //     // Method 2: Check if message is loaded, if not auto-paginate
//   //     if (!_isMessageInCurrentData(messageId, chatProvider)) {
//   //       _logger.d('🔄 Message not loaded, starting auto-pagination');
//   //       await _autoPaginateToFindMessage(messageId, chatProvider);

//   //       // After auto-pagination, try GlobalKey scroll again
//   //       if (await _tryGlobalKeyScroll(messageId, chatProvider)) {
//   //         return;
//   //       }
//   //     }

//   //     // Method 3: Find message index and ensure it's built
//   //     final messages = chatProvider.chatsData.records ?? [];
//   //     final messageIndex = messages.indexWhere(
//   //       (msg) => msg.messageId == messageId,
//   //     );

//   //     if (messageIndex == -1) {
//   //       throw Exception(
//   //         'Message $messageId not found even after auto-pagination',
//   //       );
//   //     }

//   //     // Method 4: Ensure message is built then try GlobalKey again
//   //     await _ensureMessageIsBuilt(messageId, messageIndex);
//   //     if (await _tryGlobalKeyScroll(messageId, chatProvider)) {
//   //       return;
//   //     }

//   //     // Method 5: Enhanced index-based scroll as final fallback
//   //     await _performEnhancedIndexScroll(messageId, chatProvider);
//   //   } catch (e) {
//   //     _logger.e('❌ Error in enhanced scroll with auto-pagination: $e');

//   //     // Clear any loaders
//   //     if (mounted) {
//   //       ScaffoldMessenger.of(context).clearSnackBars();
//   //     }

//   //     _showHighlightErrorFeedback();
//   //   } finally {
//   //     _pendingHighlightMessageId = null;

//   //     // Ensure loader is cleared
//   //     if (mounted) {
//   //       WidgetsBinding.instance.addPostFrameCallback((_) {
//   //         if (mounted) {
//   //           ScaffoldMessenger.of(context).clearSnackBars();
//   //         }
//   //       });
//   //     }
//   //   }
//   // }

//   Future<void> _scrollToMessageAndHighlight(
//     int messageId,
//     ChatProvider chatProvider,
//   ) async {
//     if (_isDisposed || !mounted) return;

//     _logger.d('🎯 Simple reliable scroll to message: $messageId');

//     try {
//       // Clear any search loaders
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//       }

//       // Method 1: Try immediate GlobalKey scroll (most reliable)
//       final key = _messageKeys[messageId];
//       if (key?.currentContext != null) {
//         _logger.d('✅ GlobalKey available, scrolling directly');

//         // Highlight first
//         chatProvider.highlightMessage(messageId);

//         // Simple ensureVisible - no complex logic
//         await Scrollable.ensureVisible(
//           key!.currentContext!,
//           duration: Duration(milliseconds: 600),
//           curve: Curves.easeInOut,
//           alignment: 0.5,
//         );

//         _showMessageFoundFeedback();
//         return;
//       }

//       // Method 2: Check if message is loaded, if not auto-paginate
//       if (!_isMessageInCurrentData(messageId, chatProvider)) {
//         _logger.d('🔄 Message not loaded, starting auto-pagination');
//         await _autoPaginateToFindMessage(messageId, chatProvider);

//         // After pagination, try GlobalKey again
//         final keyAfterPagination = _messageKeys[messageId];
//         if (keyAfterPagination?.currentContext != null) {
//           chatProvider.highlightMessage(messageId);
//           await Scrollable.ensureVisible(
//             keyAfterPagination!.currentContext!,
//             duration: Duration(milliseconds: 600),
//             curve: Curves.easeInOut,
//             alignment: 0.5,
//           );
//           _showMessageFoundFeedback();
//           return;
//         }
//       }

//       // Method 3: Simple index-based fallback (GUARANTEED TO WORK)
//       final messages = chatProvider.chatsData.records ?? [];
//       final messageIndex = messages.indexWhere(
//         (msg) => msg.messageId == messageId,
//       );

//       if (messageIndex == -1) {
//         throw Exception('Message $messageId not found in loaded messages');
//       }

//       _logger.d(
//         '📍 Using index-based scroll for message $messageId at index $messageIndex',
//       );

//       // Highlight the message
//       chatProvider.highlightMessage(messageId);

//       // Calculate simple scroll position
//       final targetPosition = _calculateOptimalScrollPosition(messageIndex);

//       // Simple direct scroll - no complex building
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           targetPosition,
//           duration: Duration(milliseconds: 800),
//           curve: Curves.easeInOut,
//         );
//       }

//       _showMessageFoundFeedback();
//     } catch (e) {
//       _logger.e('❌ Error in scroll: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//         _showHighlightErrorFeedback();
//       }
//     }
//   }

//   void _sendAttachmentMessage(MessageType messageType) {
//     if (_isDisposed || !mounted) return;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//     final chatId = widget.chatId ?? 0;

//     // Set the files in the provider before sending
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

//     // Send the message using MessageType enum
//     chatProvider
//         .sendMessage(
//           chatId,
//           "",
//           messageType: messageType, // Pass the enum directly
//         )
//         .then((success) {
//           if (!_isDisposed && mounted && success) {
//             // Reset selected files
//             _selectedImages = null;
//             _selectedDocuments = null;
//             _selectedVideos = null;
//             _videoThumbnail = "";

//             // Scroll to bottom to show the new message
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               _scrollToBottom();
//             });
//           }
//         });

//     if (mounted) {
//       setState(() {
//         _isAttachmentMenuOpen = false;
//       });
//     }
//   }

//   Future<void> _sendDocument() async {
//     if (_isDisposed || !mounted) return;

//     // Use the utility to get allowed extensions
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
//       _sendAttachmentMessage(
//         MessageType.File,
//       ); // Use MessageType.File instead of Document
//     }
//   }

//   Future<void> _sendGif() async {
//     if (_isDisposed || !mounted) return;

//     // Use the utility to get allowed extensions for GIFs
//     final allowedExtensions = MessageTypeUtils.getAllowedExtensions(
//       MessageType.Gif,
//     );

//     FilePickerResult? pickedFile = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowMultiple: false,
//       allowedExtensions: allowedExtensions,
//     );

//     if (pickedFile != null && !_isDisposed && mounted) {
//       _selectedImages =
//           pickedFile.files.map((platformFile) {
//             return File(platformFile.path!);
//           }).toList();
//       _sendAttachmentMessage(MessageType.Gif);
//     }
//   }

//   Future<void> _sendImage({bool isFromGallery = true}) async {
//     if (_isDisposed || !mounted) return;

//     if (isFromGallery) {
//       // Use the utility to get allowed extensions
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

//   void _sendLocation() {
//     if (_isDisposed || !mounted) return;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);
//     final chatId = widget.chatId ?? 0;

//     // For location, you might want to get current location first
//     // Then send with coordinates as message content
//     // Example: "latitude,longitude" or JSON format

//     // Placeholder implementation - replace with actual location logic
//     const locationData = "40.7128,-74.0060"; // Example: NYC coordinates

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

//   // SENDING MESSAGES METHODS
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

//     // Send the message with reply
//     chatProvider
//         .sendMessage(
//           chatId,
//           _messageController.text.trim(),
//           messageType: MessageType.Text,
//           replyToMessageId: replyToMessageId,
//         )
//         .then((success) {
//           if (!_isDisposed && mounted && success) {
//             // ✅ FIXED: Clear message field first, then scroll
//             _messageController.clear();
//             _sendTypingEvent(false);

//             // ✅ ENHANCED: Auto-scroll after message is sent
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               if (!_isDisposed && mounted) {
//                 _scrollToBottom(animated: true);
//               }
//             });
//           }
//         });
//   }

//   void _sendTypingEvent(bool isTyping) {
//     if (_isDisposed || !mounted) return;

//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

//     // Use current chat ID from provider
//     final currentChatId = chatProvider.currentChatData.chatId ?? 0;

//     _logger.d(
//       "Sending typing event - ChatId: $currentChatId, UserId: ${widget.userId}, IsTyping: $isTyping",
//     );

//     chatProvider.sendTypingStatus(currentChatId, isTyping);
//   }

//   Future<void> _sendVideo() async {
//     if (_isDisposed || !mounted) return;

//     // Use the utility to get allowed extensions
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

//   /// Show delete confirmation dialog
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

//   void _showDocumentError(String error) {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text("Document error: $error"),
//         backgroundColor: AppColors.textColor.textErrorColor,
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

//   // ✅ SOLUTION 12: Enhanced feedback methods
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

//   // ✅ UPDATED: Enhanced success feedback with message found indicator
//   void _showMessageFoundFeedback() {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Container(
//               padding: EdgeInsets.all(4),
//               decoration: BoxDecoration(
//                 color: Colors.white.withValues(alpha: 0.2),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(Icons.check_circle, color: Colors.white, size: 16),
//             ),
//             SizedBox(width: 8),
//             Text('Message found and highlighted'),
//           ],
//         ),
//         duration: Duration(seconds: 2),
//         backgroundColor: AppColors.appPriSecColor.primaryColor,
//         behavior: SnackBarBehavior.floating,
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
//         duration: Duration(seconds: 30), // Long duration for search
//         backgroundColor: AppColors.appPriSecColor.primaryColor,
//       ),
//     );
//   }

//   // ✅ SIMPLIFIED PAGINATION TRIGGER
//   void _triggerPagination() {
//     final chatProvider =
//         _chatProvider ?? Provider.of<ChatProvider>(context, listen: false);

//     // ✅ Use ChatProvider's state
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

//   // ✅ SOLUTION 2: Improved GlobalKey scrolling with proper timing
//   // Future<bool> _tryGlobalKeyScroll(
//   //   int messageId,
//   //   ChatProvider chatProvider,
//   // ) async {
//   //   final key = _messageKeys[messageId];
//   //   if (key?.currentContext == null) {
//   //     _logger.d('🔑 GlobalKey context not available for message $messageId');
//   //     return false;
//   //   }

//   //   try {
//   //     _logger.d('🔑 Attempting GlobalKey scroll for message $messageId');

//   //     // Clear any search loaders
//   //     if (mounted) {
//   //       ScaffoldMessenger.of(context).clearSnackBars();
//   //     }

//   //     // Highlight first for immediate visual feedback
//   //     chatProvider.highlightMessage(messageId);

//   //     // Wait for highlight to be applied
//   //     await Future.delayed(Duration(milliseconds: 100));

//   //     // Ensure the context is still available after delay
//   //     if (key?.currentContext == null) {
//   //       _logger.w('🔑 Context became null after highlight delay');
//   //       return false;
//   //     }

//   //     // Use ensureVisible with better parameters
//   //     await Scrollable.ensureVisible(
//   //       key!.currentContext!,
//   //       duration: const Duration(milliseconds: 600),
//   //       curve: Curves.easeInOutCubic,
//   //       alignment: 0.5, // Center the message
//   //       alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
//   //     );

//   //     // Show success feedback
//   //     _showMessageFoundFeedback();
//   //     _logger.d('✅ GlobalKey scroll completed successfully');
//   //     return true;
//   //   } catch (e) {
//   //     _logger.e('❌ GlobalKey scroll failed: $e');
//   //   }

//   //   return false;
//   // }

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

//       // Clear any search loaders
//       if (mounted) {
//         ScaffoldMessenger.of(context).clearSnackBars();
//       }

//       // Highlight first
//       chatProvider.highlightMessage(messageId);

//       // Wait for highlight to be applied
//       await Future.delayed(Duration(milliseconds: 50));

//       // Ensure the context is still available after delay
//       if (key?.currentContext == null) {
//         _logger.w('🔑 Context became null after highlight delay');
//         return false;
//       }

//       // Use simple ensureVisible - reliable and tested
//       await Scrollable.ensureVisible(
//         key!.currentContext!,
//         duration: Duration(milliseconds: 600),
//         curve: Curves.easeInOut,
//         alignment: 0.5,
//         alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
//       );

//       // Show success feedback
//       _showMessageFoundFeedback();
//       _logger.d('✅ GlobalKey scroll completed successfully');
//       return true;
//     } catch (e) {
//       _logger.e('❌ GlobalKey scroll failed: $e');
//       return false;
//     }
//   }

//   Future<void> _performEnhancedIndexScrollWithBuilding(
//     int messageId,
//     int messageIndex,
//     ChatProvider chatProvider,
//   ) async {
//     _logger.d(
//       '⚡ Fast index jump for message $messageId at index $messageIndex',
//     );

//     // Highlight the message immediately
//     chatProvider.highlightMessage(messageId);

//     // Calculate target position
//     final targetOffset = _calculateOptimalScrollPosition(messageIndex);

//     if (!_scrollController.hasClients) {
//       throw Exception('ScrollController not available');
//     }

//     // ✅ FAST: Direct jump instead of smooth scroll
//     _scrollController.jumpTo(targetOffset);
//     await Future.delayed(Duration(milliseconds: 50));

//     // Ensure the message is built at the target position
//     await _ensureMessageIsBuilt(messageId, messageIndex);

//     // ✅ FAST: Quick position verification with jump
//     await _verifyAndAdjustPositionFast(messageId, targetOffset);

//     // Try GlobalKey scroll one more time after building
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
//     await Future.delayed(Duration(milliseconds: 100)); // Shorter delay

//     if (!_scrollController.hasClients) return;

//     final currentOffset = _scrollController.offset;
//     final error = (targetOffset - currentOffset).abs();

//     if (error > 30) {
//       _logger.d(
//         '⚡ Fast position adjustment needed - Error: ${error.toInt()}px',
//       );

//       // ✅ FAST: Jump instead of animate for adjustment
//       _scrollController.jumpTo(targetOffset);
//     }

//     _logger.d('✅ Fast position verified - Error: ${error.toInt()}px');
//   }

//   void _updateScrollState() {
//     if (!mounted) return;

//     final currentPosition = _scrollController.position.pixels;
//     final maxScrollExtent = _scrollController.position.maxScrollExtent;

//     // Update scroll state for pagination
//     if (maxScrollExtent - currentPosition <= 200) {
//       _triggerPagination();
//     }

//     // Update initial load state
//     if (!_isInitialLoadComplete && maxScrollExtent > 0) {
//       _isInitialLoadComplete = true;
//     }
//   }

//   // ✅ NEW: Update search progress in loader
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
//                 value: attemptCount / 10, // Show progress out of 10 attempts
//               ),
//             ),
//             SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 'Searching for message... (${attemptCount}/10)',
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

//   // ✅ SOLUTION 9: Position verification and adjustment
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

//       // Fine adjustment
//       await _scrollController.animateTo(
//         targetOffset,
//         duration: const Duration(milliseconds: 200),
//         curve: Curves.easeInOut,
//       );
//     }

//     _logger.d('✅ Final position verified - Error: ${error.toInt()}px');
//   }
// }
