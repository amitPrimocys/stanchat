enum UserNameStatus { initial, success, error, loading }

enum ApiRequestType { POST, PUT, GET, DELETE }

enum ChatType {
  text,
  image,
  location,
  document,
  video,
  audio,
  link,
  gif,
  contact,
  story_reply,
  voice,
}
// ignore_for_file: constant_identifier_names

enum PaginationFrom {
  MainComment,
  Followers,
  Following,
  Chats,
  GiftHistory,
  CoinHistory,
  ProfileSocial,
  PeerProfileSocial,
  ProfileLikesSocial,
  PeerProfileLikesSocial,
  ProfileGifts,
  PeerProfileGifts,
  LiveUsersList,
  BookmarkList,
}

enum PeerProfileFromWhere {
  HomeReels,
  FollowerScreen,
  FollowingScreren,
  ExploreUser,
  SearchUser,
  Chat,
  Bookmark,
}

enum ReportBlockFromWhere { HomeReels, PeerProfile }

enum ReelsFromWhere {
  HomeReels,
  MyProfile,
  PeerProfile,
  Chat,
  ProfileLikesSocial,
  PeerProfileLikesSocial,
  Bookmark,

  /// LIVE STREAM FOR GIFT ONLY
  LiveStream,
}

enum MessageType {
  Text,
  Image,
  Video,
  File,
  Gif,
  Location,
  Social,
  Contact,
  StoryReply,
  Link,
  Voice,
}

enum PaymentMethods { Stripe, ApplePay, GooglePay, Paypal }

enum PaymentStatus { Success, Failed }

enum WithrawMethods { Paypal, Stripe, Bank }

MessageType stringToMessageType(String? messageTypeString) {
  switch (messageTypeString?.toLowerCase()) {
    case 'text':
      return MessageType.Text;
    case 'image':
    case 'photo':
      return MessageType.Image;
    case 'file':
    case 'document':
    case 'doc':
      return MessageType.File;
    case 'video':
      return MessageType.Video;
    case 'gif':
      return MessageType.Gif;
    case 'location':
      return MessageType.Location;
    case 'social':
      return MessageType.Social;
    case 'contact':
      return MessageType.Contact;
    case 'story_reply':
      return MessageType.StoryReply;
    case 'link':
      return MessageType.Link;
    case 'voice':
      return MessageType.Voice;
    default:
      return MessageType.Text;
  }
}

//message type show in chatlist
String messageContentWithEmojiSafe(
  dynamic messageType,
  String? messageContent,
) {
  MessageType type = MessageType.Text; // Default

  if (messageType is MessageType) {
    type = messageType;
  } else if (messageType is String) {
    type = stringToMessageType(messageType);
  } else if (messageType is int) {
    // If stored as integer index
    type =
        MessageType.values[messageType.clamp(0, MessageType.values.length - 1)];
  }

  switch (type) {
    case MessageType.Text:
      return messageContent ?? "No messages yet";
    case MessageType.Image:
      return "📷 Photo";
    case MessageType.File:
      return "📄 Document";
    case MessageType.Video:
      return "🎥 Video";
    case MessageType.Gif:
      return "🎭 GIF";
    case MessageType.Location:
      return "📍 Location";
    case MessageType.Link:
      return "🔗 Link";
    case MessageType.Contact:
      return "👤 Contact";
    case MessageType.StoryReply:
      return "Story Reply";
    case MessageType.Voice:
      return "🎙️ Voice";
    default:
      return "💬 Message";
  }
}
