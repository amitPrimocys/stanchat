import 'package:stanchat/utils/enums.dart';

class MessageTypeUtils {
  /// Converts MessageType enum to API-compatible string format
  static String messageContentType(MessageType messageType) {
    switch (messageType) {
      case MessageType.Text:
        return "text";
      case MessageType.Image:
        return "image";
      case MessageType.File:
        return "doc";
      case MessageType.Video:
        return "video";
      case MessageType.Gif:
        return "gif";
      case MessageType.Location:
        return "location";
      case MessageType.Social:
        return "social";
      case MessageType.Contact:
        return "contact";
      case MessageType.StoryReply:
        return "story_reply";
      case MessageType.Link:
        return "link";
      case MessageType.Voice:
        return "voice";
    }
  }

  /// Converts API string format back to MessageType enum
  static MessageType messageTypeFromString(String typeString) {
    switch (typeString.toLowerCase()) {
      case "text":
        return MessageType.Text;
      case "image":
        return MessageType.Image;
      case "doc":
        return MessageType.File;
      case "video":
        return MessageType.Video;
      case "gif":
        return MessageType.Gif;
      case "location":
        return MessageType.Location;
      case "social":
        return MessageType.Social;
      case "contact":
        return MessageType.Contact;
      case "story_reply":
        return MessageType.StoryReply;
      case "link":
        return MessageType.Link;
      case "voice":
        return MessageType.Voice;
      default:
        return MessageType.Text; // Default fallback
    }
  }

  /// Get display name for message type (for UI purposes)
  static String getDisplayName(MessageType messageType) {
    switch (messageType) {
      case MessageType.Text:
        return "Text";
      case MessageType.Image:
        return "Image";
      case MessageType.File:
        return "Document";
      case MessageType.Video:
        return "Video";
      case MessageType.Gif:
        return "GIF";
      case MessageType.Location:
        return "Location";
      case MessageType.Social:
        return "Social Post";
      case MessageType.Contact:
        return "Contact";
      case MessageType.StoryReply:
        return "Story Reply";
      case MessageType.Link:
        return "Link";
      case MessageType.Voice:
        return "Voice";
    }
  }

  /// Check if message type requires file upload
  static bool requiresFileUpload(MessageType messageType) {
    return messageType == MessageType.Image ||
        messageType == MessageType.File ||
        messageType == MessageType.Video ||
        messageType == MessageType.Gif ||
        messageType == MessageType.Voice;
  }

  /// Get appropriate file picker extensions for message type
  static List<String>? getAllowedExtensions(MessageType messageType) {
    switch (messageType) {
      case MessageType.Image:
        return ['jpg', 'jpeg', 'png', 'webp', 'gif'];
      case MessageType.File:
        return ['pdf', 'doc', 'docx', 'txt'];
      case MessageType.Video:
        return ['mp4', 'mov', 'avi', 'hevc', 'h.264', 'mkv'];
      case MessageType.Gif:
        return ['gif'];
      default:
        return null;
    }
  }
}
