// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:stanchat/core/services/socket_event_controller.dart';

// class ConnectionStatusWidget extends StatelessWidget {
//   final VoidCallback? onRetry;

//   const ConnectionStatusWidget({Key? key, this.onRetry}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<SocketEventController>(
//       builder: (context, controller, _) {
//         if (controller.isConnected) {
//           return const SizedBox.shrink(); // No indicator when connected
//         }

//         return Container(
//           padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
//           margin: const EdgeInsets.only(bottom: 8),
//           decoration: BoxDecoration(
//             color: Colors.red.withValues(alpha: 0.1),
//             borderRadius: BorderRadius.circular(4),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Icon(
//                 Icons.wifi_off,
//                 size: 16,
//                 color: Colors.red,
//               ),
//               const SizedBox(width: 4),
//               const Text(
//                 'Disconnected',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.red,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               GestureDetector(
//                 onTap: () {
//                   if (onRetry != null) {
//                     onRetry!();
//                   } else {
//                     controller.connectSocket();
//                   }
//                 },
//                 child: const Text(
//                   'Retry',
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.red,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
