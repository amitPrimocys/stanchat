// // import 'dart:async';

// // import 'package:flutter/foundation.dart';
// // import 'package:flutter/material.dart';
// // import 'package:provider/provider.dart';
// // import 'package:get_it/get_it.dart';
// // import 'package:whoxa/core/services/socket_service.dart';
// // import 'package:whoxa/core/services/socket_event_controller.dart';
// // import 'package:whoxa/featuers/chat/data/chat_list_model.dart' as chatlist;
// // import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
// // import 'package:whoxa/featuers/chat/screens/chat_screen.dart';
// // import 'package:whoxa/utils/preference_key/constant/app_colors.dart';
// // import 'package:whoxa/utils/logger.dart';

// // class ChatListScreen extends StatefulWidget {
// //   const ChatListScreen({Key? key}) : super(key: key);

// //   @override
// //   State<ChatListScreen> createState() => _ChatListScreenState();
// // }

// // class _ChatListScreenState extends State<ChatListScreen>
// //     with AutomaticKeepAliveClientMixin {
// //   final SocketService _socketService = GetIt.instance<SocketService>();
// //   final SocketEventController _socketEventController =
// //       GetIt.instance<SocketEventController>();
// //   final ConsoleAppLogger _logger = ConsoleAppLogger();

// //   // Flag to track initialization
// //   bool _initialized = false;

// //   // Scroll controller for pagination
// //   final ScrollController _scrollController = ScrollController();

// //   bool _wasDisconnected = false;

// //   // Keep alive when in a TabView
// //   @override
// //   bool get wantKeepAlive => true;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _initializeChat();
// //     _setupScrollListener();

// //     _setupConnectionChecker();
// //   }

// //   void _setupConnectionChecker() {
// //     // Check connection state periodically
// //     Timer.periodic(const Duration(seconds: 2), (timer) {
// //       if (!mounted) {
// //         timer.cancel();
// //         return;
// //       }

// //       // Detect reconnection (was disconnected, now connected)
// //       if (_wasDisconnected && _socketService.isConnected) {
// //         _wasDisconnected = false;
// //         _handleReconnection();
// //       } else if (!_socketService.isConnected) {
// //         _wasDisconnected = true;
// //       }
// //     });
// //   }

// //   void _handleReconnection() {
// //     if (!mounted) return;

// //     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
// //     if (chatProvider.chatListData.chats.isNotEmpty) {
// //       // Already have data, do a silent refresh
// //       _silentRefreshChatList(chatProvider);
// //     } else {
// //       // No data yet, do a normal refresh
// //       chatProvider.refreshChatList();
// //     }
// //   }

// //   void _silentRefreshChatList(ChatProvider provider) {
// //     // Don't call setState or change loading state flags
// //     if (_socketService.isConnected) {
// //       provider.emitChatList();
// //     }
// //   }

// //   @override
// //   void dispose() {
// //     _scrollController.dispose();
// //     super.dispose();
// //   }

// //   // Set up pagination with scroll listener
// //   void _setupScrollListener() {
// //     _scrollController.addListener(() {
// //       if (_scrollController.position.pixels >=
// //           _scrollController.position.maxScrollExtent - 500) {
// //         // Load more chats when we're near the end of the list
// //         final provider = Provider.of<ChatProvider>(context, listen: false);
// //         if (!provider.isChatListLoading && provider.hasMoreMessages) {
// //           provider.loadMoreMessages();
// //         }
// //       }
// //     });
// //   }

// //   void _initializeChat() {
// //     // Use post-frame callback to ensure context is available
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       if (!_initialized && mounted) {
// //         _checkSocketConnection();
// //         _initializeChatProvider();
// //         _initialized = true;
// //       }
// //     });
// //   }

// //   Future<void> _checkSocketConnection() async {
// //     _logger.i('Checking socket connection in ChatListScreen');

// //     // Store previous connection state to detect reconnection
// //     final bool wasConnected = _socketService.isConnected;

// //     // Check if socket is connected, if not try to connect
// //     if (!_socketService.isConnected) {
// //       try {
// //         await _socketService.connect();
// //         _logger.i('Socket connected successfully in ChatListScreen');

// //         // If this is a reconnection and we already have data, use silentRefresh
// //         if (!wasConnected && mounted) {
// //           final chatProvider = Provider.of<ChatProvider>(
// //             context,
// //             listen: false,
// //           );
// //           if (chatProvider.chatListData.chats.isNotEmpty) {
// //             // Use silent refresh to update data without showing loader
// //             chatProvider.silentRefresh();
// //           } else {
// //             // Only do a full refresh with loader if we have no data
// //             chatProvider.refreshChatList();
// //           }
// //         }
// //       } catch (e) {
// //         _logger.e('Error connecting socket in ChatListScreen', e);
// //         // Handle connection error
// //         if (mounted) {
// //           ScaffoldMessenger.of(context).showSnackBar(
// //             SnackBar(
// //               content: Text('Connection error: $e'),
// //               backgroundColor: Colors.red,
// //               action: SnackBarAction(
// //                 label: 'Retry',
// //                 onPressed: _checkSocketConnection,
// //               ),
// //             ),
// //           );
// //         }
// //       }
// //     } else {
// //       _logger.i('Socket already connected in ChatListScreen');
// //     }
// //   }

// //   void _initializeChatProvider() {
// //     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
// //     chatProvider.initialize();

// //     // Manually request chat list if already connected
// //     if (_socketService.isConnected) {
// //       _logger.i('Manually emitting chat list from ChatListScreen');
// //       chatProvider.emitChatList();
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     super.build(context); // Required for AutomaticKeepAliveClientMixin

// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text(
// //           "Chats",
// //           style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
// //         ),
// //         backgroundColor: Colors.white,
// //         elevation: 0,
// //         centerTitle: true,
// //         actions: [
// //           // Connection status indicator
// //           Padding(
// //             padding: const EdgeInsets.all(8.0),
// //             child: Container(
// //               width: 12,
// //               height: 12,
// //               decoration: BoxDecoration(
// //                 shape: BoxShape.circle,
// //                 color: _socketService.isConnected ? Colors.green : Colors.red,
// //               ),
// //             ),
// //           ),
// //           IconButton(
// //             icon: const Icon(Icons.refresh, color: Colors.black),
// //             onPressed: () {
// //               if (_socketService.isConnected) {
// //                 Provider.of<ChatProvider>(
// //                   context,
// //                   listen: false,
// //                 ).refreshChatList();
// //               } else {
// //                 _checkSocketConnection().then((_) {
// //                   if (_socketService.isConnected) {
// //                     Provider.of<ChatProvider>(
// //                       context,
// //                       listen: false,
// //                     ).refreshChatList();
// //                   }
// //                 });
// //               }
// //             },
// //           ),
// //         ],
// //       ),
// //       body: Consumer<ChatProvider>(
// //         builder: (context, provider, _) {
// //           // If there's an error, show error message
// //           if (provider.error != null) {
// //             return _buildErrorView(provider);
// //           }

// //           // If not connected, show connection error
// //           if (!_socketService.isConnected) {
// //             return _buildNotConnectedView();
// //           }

// //           // Show chat list with loading state
// //           return _buildChatList(provider);
// //         },
// //       ),
// //     );
// //   }

// //   // Extract UI components for better organization

// //   Widget _buildErrorView(ChatProvider provider) {
// //     return Center(
// //       child: Column(
// //         mainAxisAlignment: MainAxisAlignment.center,
// //         children: [
// //           const Icon(Icons.error_outline, size: 48, color: Colors.red),
// //           const SizedBox(height: 16),
// //           Text(
// //             'Error: ${provider.error}',
// //             textAlign: TextAlign.center,
// //             style: const TextStyle(fontSize: 16),
// //           ),
// //           const SizedBox(height: 16),
// //           ElevatedButton(
// //             onPressed: () {
// //               provider.clearError();
// //               if (_socketService.isConnected) {
// //                 provider.refreshChatList();
// //               } else {
// //                 _checkSocketConnection().then((_) {
// //                   if (_socketService.isConnected) {
// //                     provider.refreshChatList();
// //                   }
// //                 });
// //               }
// //             },
// //             child: const Text('Retry'),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildNotConnectedView() {
// //     return Center(
// //       child: Column(
// //         mainAxisAlignment: MainAxisAlignment.center,
// //         children: [
// //           const Icon(Icons.signal_wifi_off, size: 48, color: Colors.grey),
// //           const SizedBox(height: 16),
// //           const Text(
// //             'Not connected to chat server',
// //             style: TextStyle(fontSize: 16),
// //           ),
// //           const SizedBox(height: 16),
// //           ElevatedButton(
// //             onPressed: () {
// //               _checkSocketConnection().then((_) {
// //                 if (_socketService.isConnected) {
// //                   Provider.of<ChatProvider>(
// //                     context,
// //                     listen: false,
// //                   ).refreshChatList();
// //                 }
// //               });
// //             },
// //             child: const Text('Connect'),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildChatList(ChatProvider provider) {
// //     // Handle empty and loading states
// //     if (provider.isChatListLoading && provider.chatListData.chats.isEmpty) {
// //       return const Center(child: CircularProgressIndicator());
// //     }

// //     if (!provider.isChatListLoading && provider.chatListData.chats.isEmpty) {
// //       return Center(
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
// //             const SizedBox(height: 16),
// //             const Text("No chats found", style: TextStyle(fontSize: 16)),
// //             const SizedBox(height: 16),
// //             ElevatedButton(
// //               onPressed: () => provider.refreshChatList(),
// //               child: const Text('Refresh'),
// //             ),
// //           ],
// //         ),
// //       );
// //     }

// //     return Stack(
// //       children: [
// //         // Main chat list
// //         RefreshIndicator(
// //           onRefresh: () async {
// //             if (_socketService.isConnected) {
// //               await provider.refreshChatList();
// //             } else {
// //               await _checkSocketConnection();
// //               if (_socketService.isConnected) {
// //                 await provider.refreshChatList();
// //               }
// //             }
// //           },
// //           child: ListView.separated(
// //             controller: _scrollController,
// //             padding: const EdgeInsets.symmetric(vertical: 8),
// //             itemCount:
// //                 provider.chatListData.chats.length +
// //                 (provider.isChatListLoading &&
// //                         provider.chatListData.chats.isNotEmpty
// //                     ? 1
// //                     : 0),
// //             separatorBuilder: (_, __) => const Divider(height: 1),
// //             itemBuilder: (context, index) {
// //               // Show loading indicator at the bottom for pagination
// //               if (index == provider.chatListData.chats.length) {
// //                 return const Center(
// //                   child: Padding(
// //                     padding: EdgeInsets.all(16.0),
// //                     child: CircularProgressIndicator(strokeWidth: 2),
// //                   ),
// //                 );
// //               }

// //               final chat = provider.chatListData.chats[index];
// //               return _buildChatItem(context, provider, chat);
// //             },
// //           ),
// //         ),

// //         // Floating connection status at the top if disconnected
// //         if (!_socketService.isConnected)
// //           Positioned(
// //             top: 0,
// //             left: 0,
// //             right: 0,
// //             child: Material(
// //               color: Colors.red,
// //               child: InkWell(
// //                 onTap: () => _checkSocketConnection(),
// //                 child: const Padding(
// //                   padding: EdgeInsets.all(8.0),
// //                   child: Center(
// //                     child: Text(
// //                       "Not connected - tap to reconnect",
// //                       style: TextStyle(color: Colors.white),
// //                     ),
// //                   ),
// //                 ),
// //               ),
// //             ),
// //           ),
// //       ],
// //     );
// //   }

// //   Widget _buildChatItem(
// //     BuildContext context,
// //     ChatProvider provider,
// //     chatlist.Chats chat,
// //   ) {
// //     // Make sure records collection exists
// //     if (chat.records == null || chat.records!.isEmpty) {
// //       return const ListTile(
// //         title: Text('Invalid chat data'),
// //         subtitle: Text('This chat has no records'),
// //       );
// //     }

// //     final peer = chat.peerUserData;
// //     final record = chat.records![0];
// //     final message =
// //         record.messages?.isNotEmpty == true ? record.messages![0] : null;
// //     final unseen = record.unseenCount ?? 0;

// //     // Use optimized online status check
// //     final bool isOnline =
// //         peer?.userId != null
// //             ? _socketEventController.isUserOnline(peer!.userId.toString())
// //             : false;

// //     // Use optimized typing status check
// //     final bool isTyping =
// //         record.chatId != null
// //             ? _socketEventController.isUserTypingInChat(
// //               record.chatId.toString(),
// //             )
// //             : false;

// //     return ListTile(
// //       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
// //       leading: _buildUserAvatar(peer, isOnline),
// //       title: Text(
// //         peer?.fullName?.isNotEmpty == true
// //             ? peer!.fullName!
// //             : (peer?.userName?.isNotEmpty == true
// //                 ? peer!.userName!
// //                 : 'Unknown User'),
// //         style: TextStyle(
// //           fontWeight: unseen > 0 ? FontWeight.bold : FontWeight.normal,
// //         ),
// //       ),
// //       subtitle: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Text(
// //             message?.messageContent ?? 'No message',
// //             maxLines: 1,
// //             overflow: TextOverflow.ellipsis,
// //             style: TextStyle(color: unseen > 0 ? Colors.black : Colors.grey),
// //           ),
// //           if (isTyping)
// //             const Text(
// //               'Typing...',
// //               style: TextStyle(
// //                 fontStyle: FontStyle.italic,
// //                 color: Colors.green,
// //                 fontSize: 12,
// //               ),
// //             ),
// //         ],
// //       ),
// //       trailing: _buildTrailingWidget(message, unseen),
// //       onTap: () {
// //         // if (record.chatId != null) {
// //         //   Navigator.push(
// //         //     context,
// //         //     MaterialPageRoute(
// //         //       builder:
// //         //           (_) => ChatScreen(chatId: record.chatId!, peerUser: peer),
// //         //     ),
// //         //   ).then((_) {
// //         //     // Refresh chat list when returning from chat screen
// //         //     provider.refreshChatList();
// //         //   });
// //         // }
// //       },
// //     );
// //   }

// //   Widget _buildUserAvatar(chatlist.PeerUserData? peer, bool isOnline) {
// //     return Stack(
// //       children: [
// //         CircleAvatar(
// //           radius: 24,
// //           backgroundImage:
// //               (peer?.profilePic != null && peer!.profilePic!.isNotEmpty)
// //                   ? NetworkImage(_getProfileImageUrl(peer.profilePic!))
// //                   : null,
// //           child:
// //               (peer?.profilePic == null || peer!.profilePic!.isEmpty)
// //                   ? const Icon(Icons.person, color: Colors.grey)
// //                   : null,
// //         ),
// //         if (isOnline)
// //           Positioned(
// //             right: 0,
// //             bottom: 0,
// //             child: Container(
// //               width: 12,
// //               height: 12,
// //               decoration: BoxDecoration(
// //                 color: Colors.green,
// //                 shape: BoxShape.circle,
// //                 border: Border.all(color: Colors.white, width: 2),
// //               ),
// //             ),
// //           ),
// //       ],
// //     );
// //   }

// //   Widget _buildTrailingWidget(chatlist.Messages? message, int unseen) {
// //     return Column(
// //       mainAxisAlignment: MainAxisAlignment.center,
// //       crossAxisAlignment: CrossAxisAlignment.end,
// //       mainAxisSize: MainAxisSize.min,
// //       children: [
// //         Text(_formatTime(message?.createdAt)),
// //         if (unseen > 0)
// //           Container(
// //             margin: const EdgeInsets.only(top: 4),
// //             padding: const EdgeInsets.all(6),
// //             decoration: BoxDecoration(
// //               color: AppColors.appPriSecColor.primaryColor,
// //               shape: BoxShape.circle,
// //             ),
// //             child: Text(
// //               unseen > 99 ? '99+' : unseen.toString(),
// //               style: const TextStyle(
// //                 color: Colors.white,
// //                 fontSize: 10,
// //                 fontWeight: FontWeight.bold,
// //               ),
// //             ),
// //           ),
// //       ],
// //     );
// //   }

// //   // Helper method to format profile image URL
// //   String _getProfileImageUrl(String url) {
// //     if (url.startsWith('/')) {
// //       return 'http://192.168.0.10:3002$url';
// //     }
// //     return url;
// //   }

// //   // Helper method to format timestamp
// //   String _formatTime(String? time) {
// //     if (time == null || time.isEmpty) return '';

// //     try {
// //       final dt = DateTime.parse(time);
// //       final now = DateTime.now();

// //       if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
// //         return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
// //       } else if (dt.year == now.year) {
// //         return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
// //       } else {
// //         return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}";
// //       }
// //     } catch (_) {
// //       return '';
// //     }
// //   }
// // }

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:get_it/get_it.dart';
// import 'package:whoxa/core/services/socket/socket_service.dart';
// import 'package:whoxa/core/services/socket/socket_event_controller.dart';
// import 'package:whoxa/featuers/chat/screens/one_to_one_chats.dart';
// import 'package:whoxa/featuers/chat/data/chat_list_model.dart';
// import 'package:whoxa/featuers/chat/provider/chat_provider.dart';
// import 'package:whoxa/utils/logger.dart';
// import 'package:whoxa/utils/preference_key/constant/app_colors.dart';

// class ChatListScreen extends StatefulWidget {
//   const ChatListScreen({super.key});

//   @override
//   State<ChatListScreen> createState() => _ChatListScreenState();
// }

// class _ChatListScreenState extends State<ChatListScreen>
//     with AutomaticKeepAliveClientMixin {
//   final SocketService _socketService = GetIt.instance<SocketService>();
//   final SocketEventController _socketEventController =
//       GetIt.instance<SocketEventController>();
//   final ConsoleAppLogger _logger = ConsoleAppLogger();

//   // Flag to track initialization
//   bool _initialized = false;

//   // Scroll controller for pagination
//   final ScrollController _scrollController = ScrollController();

//   // Flag to track if socket was disconnected
//   bool _wasDisconnected = false;

//   // Keep alive when in a TabView
//   @override
//   bool get wantKeepAlive => true;

//   Timer? _connectionCheckerTimer;

//   @override
//   void initState() {
//     super.initState();
//     _initializeChat();
//     _setupScrollListener();
//     _setupConnectionChecker();
//   }

//   // Periodically check socket connection status
//   void _setupConnectionChecker() {
//     _connectionCheckerTimer = Timer.periodic(const Duration(seconds: 2), (
//       timer,
//     ) {
//       if (!mounted) {
//         timer.cancel();
//         return;
//       }

//       // Detect reconnection (was disconnected, now connected)
//       if (_wasDisconnected && _socketService.isConnected) {
//         _wasDisconnected = false;
//         _handleReconnection();
//       } else if (!_socketService.isConnected) {
//         _wasDisconnected = true;
//       }
//     });
//   }

//   // Handle socket reconnection
//   void _handleReconnection() {
//     if (!mounted) return;

//     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
//     if (chatProvider.chatListData.chats.isNotEmpty) {
//       // Already have data, do a silent refresh
//       chatProvider.silentRefresh();
//     } else {
//       // No data yet, do a normal refresh
//       chatProvider.refreshChatList();
//     }
//   }

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     _connectionCheckerTimer?.cancel();
//     super.dispose();
//   }

//   // Set up pagination with scroll listener
//   void _setupScrollListener() {
//     _scrollController.addListener(() {
//       if (_scrollController.position.pixels >=
//           _scrollController.position.maxScrollExtent - 500) {
//         // Load more chats when we're near the end of the list
//         final provider = Provider.of<ChatProvider>(context, listen: false);
//         if (!provider.isChatListLoading && provider.hasMoreMessages) {
//           provider.loadMoreMessages();
//         }
//       }
//     });
//   }

//   // Initialize chat with socket connection
//   void _initializeChat() {
//     // Use post-frame callback to ensure context is available
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!_initialized && mounted) {
//         _checkSocketConnection();
//         _initializeChatProvider();
//         _initialized = true;
//       }
//     });
//   }

//   // Check and establish socket connection
//   Future<void> _checkSocketConnection() async {
//     _logger.i('Checking socket connection in ChatListScreen');

//     // Store previous connection state to detect reconnection
//     final bool wasConnected = _socketService.isConnected;

//     // Check if socket is connected, if not try to connect
//     if (!_socketService.isConnected) {
//       try {
//         await _socketService.connect();
//         _logger.i('Socket connected successfully in ChatListScreen');

//         // If this is a reconnection and we already have data, use silentRefresh
//         if (!wasConnected && mounted) {
//           final chatProvider = Provider.of<ChatProvider>(
//             context,
//             listen: false,
//           );
//           if (chatProvider.chatListData.chats.isNotEmpty) {
//             // Use silent refresh to update data without showing loader
//             chatProvider.silentRefresh();
//           } else {
//             // Only do a full refresh with loader if we have no data
//             chatProvider.refreshChatList();
//           }
//         }
//       } catch (e) {
//         _logger.e('Error connecting socket in ChatListScreen', e);
//         // Handle connection error
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Connection error: $e'),
//               backgroundColor: Colors.red,
//               action: SnackBarAction(
//                 label: 'Retry',
//                 onPressed: _checkSocketConnection,
//               ),
//             ),
//           );
//         }
//       }
//     } else {
//       _logger.i('Socket already connected in ChatListScreen');
//     }
//   }

//   // Initialize chat provider
//   void _initializeChatProvider() {
//     final chatProvider = Provider.of<ChatProvider>(context, listen: false);
//     chatProvider.initialize();

//     // Manually request chat list if already connected
//     if (_socketService.isConnected) {
//       _logger.i('Manually emitting chat list from ChatListScreen');
//       chatProvider.emitChatList();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     super.build(context); // Required for AutomaticKeepAliveClientMixin

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           "Chats",
//           style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         centerTitle: true,
//         actions: [
//           // Connection status indicator
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Container(
//               width: 12,
//               height: 12,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: _socketService.isConnected ? Colors.green : Colors.red,
//               ),
//             ),
//           ),
//           IconButton(
//             icon: const Icon(Icons.refresh, color: Colors.black),
//             onPressed: () {
//               if (_socketService.isConnected) {
//                 Provider.of<ChatProvider>(
//                   context,
//                   listen: false,
//                 ).refreshChatList();
//               } else {
//                 _checkSocketConnection().then((_) {
//                   if (_socketService.isConnected) {
//                     Provider.of<ChatProvider>(
//                       context,
//                       listen: false,
//                     ).refreshChatList();
//                   }
//                 });
//               }
//             },
//           ),
//         ],
//       ),
//       body: Consumer<ChatProvider>(
//         builder: (context, provider, _) {
//           // If there's an error, show error message
//           if (provider.error != null) {
//             return _buildErrorView(provider);
//           }

//           // If not connected, show connection error
//           if (!_socketService.isConnected) {
//             return _buildNotConnectedView();
//           }

//           // Show chat list with loading state
//           return _buildChatList(provider);
//         },
//       ),
//     );
//   }

//   // Extract UI components for better organization

//   // Error view when provider has an error
//   Widget _buildErrorView(ChatProvider provider) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.error_outline, size: 48, color: Colors.red),
//           const SizedBox(height: 16),
//           Text(
//             'Error: ${provider.error}',
//             textAlign: TextAlign.center,
//             style: const TextStyle(fontSize: 16),
//           ),
//           const SizedBox(height: 16),
//           ElevatedButton(
//             onPressed: () {
//               provider.clearError();
//               if (_socketService.isConnected) {
//                 provider.refreshChatList();
//               } else {
//                 _checkSocketConnection().then((_) {
//                   if (_socketService.isConnected) {
//                     provider.refreshChatList();
//                   }
//                 });
//               }
//             },
//             child: const Text('Retry'),
//           ),
//         ],
//       ),
//     );
//   }

//   // Not connected view when socket is disconnected
//   Widget _buildNotConnectedView() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(Icons.signal_wifi_off, size: 48, color: Colors.grey),
//           const SizedBox(height: 16),
//           const Text(
//             'Not connected to chat server',
//             style: TextStyle(fontSize: 16),
//           ),
//           const SizedBox(height: 16),
//           ElevatedButton(
//             onPressed: () {
//               _checkSocketConnection().then((_) {
//                 if (_socketService.isConnected) {
//                   Provider.of<ChatProvider>(
//                     context,
//                     listen: false,
//                   ).refreshChatList();
//                 }
//               });
//             },
//             child: const Text('Connect'),
//           ),
//         ],
//       ),
//     );
//   }

//   // Chat list view with refresh and pagination
//   Widget _buildChatList(ChatProvider provider) {
//     // Handle empty and loading states
//     if (provider.isChatListLoading && provider.chatListData.chats.isEmpty) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     if (!provider.isChatListLoading && provider.chatListData.chats.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
//             const SizedBox(height: 16),
//             const Text("No chats found", style: TextStyle(fontSize: 16)),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () => provider.refreshChatList(),
//               child: const Text('Refresh'),
//             ),
//           ],
//         ),
//       );
//     }

//     return Stack(
//       children: [
//         // Main chat list
//         RefreshIndicator(
//           onRefresh: () async {
//             if (_socketService.isConnected) {
//               await provider.refreshChatList();
//             } else {
//               await _checkSocketConnection();
//               if (_socketService.isConnected) {
//                 await provider.refreshChatList();
//               }
//             }
//           },
//           child: ListView.separated(
//             controller: _scrollController,
//             padding: const EdgeInsets.symmetric(vertical: 8),
//             itemCount:
//                 provider.chatListData.chats.length +
//                 (provider.isChatListLoading &&
//                         provider.chatListData.chats.isNotEmpty
//                     ? 1
//                     : 0),
//             separatorBuilder: (_, __) => const Divider(height: 1),
//             itemBuilder: (context, index) {
//               // Show loading indicator at the bottom for pagination
//               if (index == provider.chatListData.chats.length) {
//                 return const Center(
//                   child: Padding(
//                     padding: EdgeInsets.all(16.0),
//                     child: CircularProgressIndicator(strokeWidth: 2),
//                   ),
//                 );
//               }

//               final chat = provider.chatListData.chats[index];
//               return _buildChatItem(context, provider, chat);
//             },
//           ),
//         ),

//         // Floating connection status at the top if disconnected
//         if (!_socketService.isConnected)
//           Positioned(
//             top: 0,
//             left: 0,
//             right: 0,
//             child: Material(
//               color: Colors.red,
//               child: InkWell(
//                 onTap: () => _checkSocketConnection(),
//                 child: const Padding(
//                   padding: EdgeInsets.all(8.0),
//                   child: Center(
//                     child: Text(
//                       "Not connected - tap to reconnect",
//                       style: TextStyle(color: Colors.white),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }

//   // Chat list item
//   Widget _buildChatItem(
//     BuildContext context,
//     ChatProvider provider,
//     Chats chat,
//   ) {
//     // Make sure records collection exists
//     if (chat.records == null || chat.records!.isEmpty) {
//       return const ListTile(
//         title: Text('Invalid chat data'),
//         subtitle: Text('This chat has no records'),
//       );
//     }

//     final peer = chat.peerUserData;
//     final record = chat.records![0];
//     final message =
//         record.messages?.isNotEmpty == true ? record.messages![0] : null;
//     final unseen = record.unseenCount ?? 0;

//     // Get chat type and determine display name
//     final String chatType = record.chatType ?? 'Private';
//     final String displayName = _getDisplayName(chatType, record, peer);

//     // Use socket event controller to check online status (only for private chats)
//     final bool isOnline =
//         chatType.toLowerCase() == 'private' && peer?.userId != null
//             ? _socketEventController.isUserOnline(peer!.userId ?? 0)
//             : false;

//     // Use socket event controller to check typing status
//     final bool isTyping =
//         record.chatId != null
//             ? _socketEventController.isUserTypingInChat(record.chatId ?? 0)
//             : false;

//     return ListTile(
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       leading: _buildChatAvatar(chatType, peer, isOnline),
//       title: Text(
//         displayName,
//         style: TextStyle(
//           fontWeight: unseen > 0 ? FontWeight.bold : FontWeight.normal,
//         ),
//       ),
//       subtitle: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             message?.messageContent ?? 'No message',
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(color: unseen > 0 ? Colors.black : Colors.grey),
//           ),
//           if (isTyping)
//             const Text(
//               'Typing...',
//               style: TextStyle(
//                 fontStyle: FontStyle.italic,
//                 color: Colors.green,
//                 fontSize: 12,
//               ),
//             ),
//         ],
//       ),
//       trailing: _buildTrailingWidget(message, unseen),
//       onTap: () {
//         debugPrint('button is pressed');
//         if (record.chatId != null) {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder:
//                   (_) => OneToOneChat(
//                     chatId: record.chatId ?? 0,
//                     userId: peer?.userId! ?? 0,
//                     fullName: displayName,
//                     profilePic: peer?.profilePic ?? '',
//                   ),
//             ),
//           ).then((_) {
//             // Refresh chat list when returning from chat screen
//             provider.refreshChatList();
//           });
//         }
//       },
//     );
//   }

//   // Helper method to determine display name based on chat type
//   String _getDisplayName(String chatType, Records record, PeerUserData? peer) {
//     if (chatType.toLowerCase() == 'group') {
//       // For group chats, show group name
//       if (record.groupName != null && record.groupName!.isNotEmpty) {
//         return record.groupName!;
//       } else {
//         return 'Group Chat'; // Fallback if group name is empty
//       }
//     } else {
//       // For private chats, show peer user info
//       if (peer?.fullName?.isNotEmpty == true) {
//         return peer!.fullName!;
//       } else if (peer?.userName?.isNotEmpty == true) {
//         return peer!.userName!;
//       } else {
//         return 'Unknown User';
//       }
//     }
//   }

//   // Updated avatar builder to handle both private and group chats
//   Widget _buildChatAvatar(String chatType, PeerUserData? peer, bool isOnline) {
//     if (chatType.toLowerCase() == 'group') {
//       // For group chats, show group icon
//       return const CircleAvatar(
//         radius: 24,
//         backgroundColor: Colors.blue,
//         child: Icon(Icons.group, color: Colors.white, size: 24),
//       );
//     } else {
//       // For private chats, show user avatar with online indicator
//       return Stack(
//         children: [
//           CircleAvatar(
//             radius: 24,
//             backgroundImage:
//                 (peer?.profilePic != null && peer!.profilePic!.isNotEmpty)
//                     ? NetworkImage(_getProfileImageUrl(peer.profilePic!))
//                     : null,
//             child:
//                 (peer?.profilePic == null || peer!.profilePic!.isEmpty)
//                     ? const Icon(Icons.person, color: Colors.grey)
//                     : null,
//           ),
//           if (isOnline)
//             Positioned(
//               right: 0,
//               bottom: 0,
//               child: Container(
//                 width: 12,
//                 height: 12,
//                 decoration: BoxDecoration(
//                   color: Colors.green,
//                   shape: BoxShape.circle,
//                   border: Border.all(color: Colors.white, width: 2),
//                 ),
//               ),
//             ),
//         ],
//       );
//     }
//   }

//   // Message time and unread count indicator
//   Widget _buildTrailingWidget(Messages? message, int unseen) {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       crossAxisAlignment: CrossAxisAlignment.end,
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Text(_formatTime(message?.createdAt)),
//         if (unseen > 0)
//           Container(
//             margin: const EdgeInsets.only(top: 4),
//             padding: const EdgeInsets.all(6),
//             decoration: BoxDecoration(
//               color: AppColors.appPriSecColor.primaryColor,
//               shape: BoxShape.circle,
//             ),
//             child: Text(
//               unseen > 99 ? '99+' : unseen.toString(),
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 10,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//       ],
//     );
//   }

//   // Helper method to format profile image URL
//   String _getProfileImageUrl(String url) {
//     if (url.startsWith('/')) {
//       // If the URL is a relative path, prepend the base URL
//       return 'https://api.example.com$url';
//     }
//     return url;
//   }

//   // Helper method to format timestamp
//   String _formatTime(String? time) {
//     if (time == null || time.isEmpty) return '';

//     try {
//       final dt = DateTime.parse(time);
//       final now = DateTime.now();

//       // Today - show time only
//       if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
//         return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
//       }
//       // This year - show day and month
//       else if (dt.year == now.year) {
//         return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
//       }
//       // Different year - show day, month and year
//       else {
//         return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}";
//       }
//     } catch (_) {
//       return '';
//     }
//   }
// }
