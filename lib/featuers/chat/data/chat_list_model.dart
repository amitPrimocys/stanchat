import 'package:flutter/foundation.dart';
import 'package:stanchat/featuers/chat/data/chats_model.dart';

// class ChatListModel {
//   Pagination? pagination;
//   List<Chats>? chats;
//
//   ChatListModel({this.pagination, this.chats});
//
//   ChatListModel.fromJson(Map<String, dynamic> json) {
//     pagination = json["pagination"] == null
//         ? null
//         : Pagination.fromJson(json["pagination"]);
//     chats = json["Chats"] == null
//         ? null
//         : (json["Chats"] as List).map((e) => Chats.fromJson(e)).toList();
//   }
//
//   static List<ChatListModel> fromList(List<Map<String, dynamic>> list) {
//     return list.map(ChatListModel.fromJson).toList();
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = <String, dynamic>{};
//     if (pagination != null) {
//       data["pagination"] = pagination?.toJson();
//     }
//     if (chats != null) {
//       data["Chats"] = chats?.map((e) => e.toJson()).toList();
//     }
//     return data;
//   }
// }
//
// class Chats {
//   List<Records>? records;
//   PeerUserData? peerUserData;
//
//   Chats({this.records, this.peerUserData});
//
//   Chats.fromJson(Map<String, dynamic> json) {
//     records = json["Records"] == null
//         ? null
//         : (json["Records"] as List).map((e) => Records.fromJson(e)).toList();
//     peerUserData = json["PeerUserData"] == null
//         ? null
//         : PeerUserData.fromJson(json["PeerUserData"]);
//   }
//
//   static List<Chats> fromList(List<Map<String, dynamic>> list) {
//     return list.map(Chats.fromJson).toList();
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = <String, dynamic>{};
//     if (records != null) {
//       data["Records"] = records?.map((e) => e.toJson()).toList();
//     }
//     if (peerUserData != null) {
//       data["PeerUserData"] = peerUserData?.toJson();
//     }
//     return data;
//   }
// }
//
// class PeerUserData {
//   String? profilePic;
//   int? userId;
//   String? fullName;
//   String? userName;
//   String? email;
//   String? countryCode;
//   String? country;
//   String? gender;
//   String? bio;
//   bool? profileVerificationStatus;
//   bool? loginVerificationStatus;
//   String? socketId;
//   String? createdAt;
//   String? updatedAt;
//
//   PeerUserData(
//       {this.profilePic,
//       this.userId,
//       this.fullName,
//       this.userName,
//       this.email,
//       this.countryCode,
//       this.country,
//       this.gender,
//       this.bio,
//       this.profileVerificationStatus,
//       this.loginVerificationStatus,
//       this.socketId,
//       this.createdAt,
//       this.updatedAt});
//
//   PeerUserData.fromJson(Map<String, dynamic> json) {
//     profilePic = json["profile_pic"];
//     userId = json["user_id"];
//     fullName = json["full_name"];
//     userName = json["user_name"];
//     email = json["email"];
//     countryCode = json["country_code"];
//     country = json["country"];
//     gender = json["gender"];
//     bio = json["bio"];
//     profileVerificationStatus = json["profile_verification_status"];
//     loginVerificationStatus = json["login_verification_status"];
//     socketId = json["socket_id"];
//     createdAt = json["createdAt"];
//     updatedAt = json["updatedAt"];
//   }
//
//   static List<PeerUserData> fromList(List<Map<String, dynamic>> list) {
//     return list.map(PeerUserData.fromJson).toList();
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = <String, dynamic>{};
//     data["profile_pic"] = profilePic;
//     data["user_id"] = userId;
//     data["full_name"] = fullName;
//     data["user_name"] = userName;
//     data["email"] = email;
//     data["country_code"] = countryCode;
//     data["country"] = country;
//     data["gender"] = gender;
//     data["bio"] = bio;
//     data["profile_verification_status"] = profileVerificationStatus;
//     data["login_verification_status"] = loginVerificationStatus;
//     data["socket_id"] = socketId;
//     data["createdAt"] = createdAt;
//     data["updatedAt"] = updatedAt;
//     return data;
//   }
// }
//
// class Records {
//   String? groupIcon;
//   int? chatId;
//   String? chatType;
//   String? groupName;
//   String? createdAt;
//   String? updatedAt;
//   List<Messages>? messages;
//   int? unseenCount;
//
//   Records({
//     this.groupIcon,
//     this.chatId,
//     this.chatType,
//     this.groupName,
//     this.createdAt,
//     this.updatedAt,
//     this.messages,
//     this.unseenCount,
//   });
//
//   Records.fromJson(Map<String, dynamic> json) {
//     groupIcon = json["group_icon"];
//     chatId = json["chat_id"];
//     chatType = json["chat_type"];
//     groupName = json["group_name"];
//     createdAt = json["createdAt"];
//     updatedAt = json["updatedAt"];
//     messages = json["Messages"] == null
//         ? null
//         : (json["Messages"] as List).map((e) => Messages.fromJson(e)).toList();
//     unseenCount = json["unseen_count"];
//   }
//
//   static List<Records> fromList(List<Map<String, dynamic>> list) {
//     return list.map(Records.fromJson).toList();
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = <String, dynamic>{};
//     data["group_icon"] = groupIcon;
//     data["chat_id"] = chatId;
//     data["chat_type"] = chatType;
//     data["group_name"] = groupName;
//     data["createdAt"] = createdAt;
//     data["updatedAt"] = updatedAt;
//     if (messages != null) {
//       data["Messages"] = messages?.map((e) => e.toJson()).toList();
//     }
//     data["unseen_count"] = unseenCount;
//     return data;
//   }
// }
//
// class Messages {
//   String? messageContent;
//   int? replyTo;
//   int? socialId;
//   int? messageId;
//   String? messageType;
//   String? messageThumbnail;
//   String? messageLength;
//   String? messageSize;
//   String? createdAt;
//   String? updatedAt;
//   int? chatId;
//   int? senderId;
//   User? user;
//   Social? social;
//
//   Messages(
//       {this.messageContent,
//       this.replyTo,
//       this.socialId,
//       this.messageId,
//       this.messageType,
//       this.messageThumbnail,
//       this.messageLength,
//       this.messageSize,
//       this.createdAt,
//       this.updatedAt,
//       this.chatId,
//       this.senderId,
//       this.user,
//       this.social});
//
//   Messages.fromJson(Map<String, dynamic> json) {
//     messageContent = json["message_content"];
//     replyTo = json["reply_to"];
//     socialId = json["social_id"];
//     messageId = json["message_id"];
//     messageType = json["message_type"];
//     messageThumbnail = json["message_thumbnail"];
//     messageLength = json["message_length"];
//     messageSize = json["message_size"];
//     createdAt = json["createdAt"];
//     updatedAt = json["updatedAt"];
//     chatId = json["chat_id"];
//     senderId = json["sender_id"];
//     user = json["User"] == null ? null : User.fromJson(json["User"]);
//     social = json["Social"] == null ? null : Social.fromJson(json["Social"]);
//   }
//
//   static List<Messages> fromList(List<Map<String, dynamic>> list) {
//     return list.map(Messages.fromJson).toList();
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = <String, dynamic>{};
//     data["message_content"] = messageContent;
//     data["reply_to"] = replyTo;
//     data["social_id"] = socialId;
//     data["message_id"] = messageId;
//     data["message_type"] = messageType;
//     data["message_thumbnail"] = messageThumbnail;
//     data["message_length"] = messageLength;
//     data["message_size"] = messageSize;
//     data["createdAt"] = createdAt;
//     data["updatedAt"] = updatedAt;
//     data["chat_id"] = chatId;
//     data["sender_id"] = senderId;
//     if (user != null) {
//       data["User"] = user?.toJson();
//     }
//     if (social != null) {
//       data["Social"] = social?.toJson();
//     }
//     return data;
//   }
// }
//
// class Social {
//   String? reelThumbnail;
//   int? socialId;
//   String? socialDesc;
//   String? socialType;
//   String? aspectRatio;
//   String? videoHight;
//   String? location;
//   int? totalViews;
//   int? totalSaves;
//   int? totalShares;
//   int? totalLikes;
//   int? totalComments;
//   String? country;
//   String? createdAt;
//   String? updatedAt;
//   int? userId;
//   List<Media>? media;
//   User? user;
//   bool? isLiked;
//
//   Social({
//     this.reelThumbnail,
//     this.socialId,
//     this.socialDesc,
//     this.socialType,
//     this.aspectRatio,
//     this.videoHight,
//     this.location,
//     this.totalViews,
//     this.totalSaves,
//     this.totalShares,
//     this.totalLikes,
//     this.totalComments,
//     this.country,
//     this.createdAt,
//     this.updatedAt,
//     this.userId,
//     this.media,
//     this.user,
//     this.isLiked,
//   });
//
//   Social.fromJson(Map<String, dynamic> json) {
//     reelThumbnail = json["reel_thumbnail"];
//     socialId = json["social_id"];
//     socialDesc = json["social_desc"];
//     socialType = json["social_type"];
//     aspectRatio = json["aspect_ratio"];
//     videoHight = json["video_hight"];
//     location = json["location"];
//     totalViews = json["total_views"];
//     totalSaves = json["total_saves"];
//     totalShares = json["total_shares"];
//     totalLikes = json["total_likes"];
//     totalComments = json["total_comments"];
//     country = json["country"];
//     createdAt = json["createdAt"];
//     updatedAt = json["updatedAt"];
//     userId = json["user_id"];
//     media = json["Media"] == null
//         ? null
//         : (json["Media"] as List).map((e) => Media.fromJson(e)).toList();
//     user = json["User"] == null ? null : User.fromJson(json["User"]);
//     isLiked = json["isLiked"];
//   }
//
//   static List<Social> fromList(List<Map<String, dynamic>> list) {
//     return list.map(Social.fromJson).toList();
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = <String, dynamic>{};
//     data["reel_thumbnail"] = reelThumbnail;
//     data["social_id"] = socialId;
//     data["social_desc"] = socialDesc;
//     data["social_type"] = socialType;
//     data["aspect_ratio"] = aspectRatio;
//     data["video_hight"] = videoHight;
//     data["location"] = location;
//     data["total_views"] = totalViews;
//     data["total_saves"] = totalSaves;
//     data["total_shares"] = totalShares;
//     data["total_likes"] = totalLikes;
//     data["total_comments"] = totalComments;
//     data["country"] = country;
//     data["createdAt"] = createdAt;
//     data["updatedAt"] = updatedAt;
//     data["user_id"] = userId;
//     if (media != null) {
//       data["Media"] = media?.map((e) => e.toJson()).toList();
//     }
//     if (user != null) {
//       data["User"] = user?.toJson();
//     }
//     data["isLiked"] = isLiked;
//     return data;
//   }
// }
//
// class Media {
//   int? socialId;
//   String? mediaLocation;
//   int? mediaId;
//   String? createdAt;
//   String? updatedAt;
//
//   Media(
//       {this.socialId,
//       this.mediaLocation,
//       this.mediaId,
//       this.createdAt,
//       this.updatedAt});
//
//   Media.fromJson(Map<String, dynamic> json) {
//     socialId = json["social_id"];
//     mediaLocation = json["media_location"];
//     mediaId = json["media_id"];
//     createdAt = json["createdAt"];
//     updatedAt = json["updatedAt"];
//   }
//
//   static List<Media> fromList(List<Map<String, dynamic>> list) {
//     return list.map(Media.fromJson).toList();
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = <String, dynamic>{};
//     data["social_id"] = socialId;
//     data["media_location"] = mediaLocation;
//     data["media_id"] = mediaId;
//     data["createdAt"] = createdAt;
//     data["updatedAt"] = updatedAt;
//     return data;
//   }
// }
//
// class User {
//   String? profilePic;
//   int? userId;
//   String? fullName;
//   String? userName;
//   String? email;
//   String? countryCode;
//   String? country;
//   String? gender;
//   String? bio;
//   bool? profileVerificationStatus;
//   bool? loginVerificationStatus;
//   String? socketId;
//   String? createdAt;
//   String? updatedAt;
//
//   User(
//       {this.profilePic,
//       this.userId,
//       this.fullName,
//       this.userName,
//       this.email,
//       this.countryCode,
//       this.country,
//       this.gender,
//       this.bio,
//       this.profileVerificationStatus,
//       this.loginVerificationStatus,
//       this.socketId,
//       this.createdAt,
//       this.updatedAt});
//
//   User.fromJson(Map<String, dynamic> json) {
//     profilePic = json["profile_pic"];
//     userId = json["user_id"];
//     fullName = json["full_name"];
//     userName = json["user_name"];
//     email = json["email"];
//     countryCode = json["country_code"];
//     country = json["country"];
//     gender = json["gender"];
//     bio = json["bio"];
//     profileVerificationStatus = json["profile_verification_status"];
//     loginVerificationStatus = json["login_verification_status"];
//     socketId = json["socket_id"];
//     createdAt = json["createdAt"];
//     updatedAt = json["updatedAt"];
//   }
//
//   static List<User> fromList(List<Map<String, dynamic>> list) {
//     return list.map(User.fromJson).toList();
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = <String, dynamic>{};
//     data["profile_pic"] = profilePic;
//     data["user_id"] = userId;
//     data["full_name"] = fullName;
//     data["user_name"] = userName;
//     data["email"] = email;
//     data["country_code"] = countryCode;
//     data["country"] = country;
//     data["gender"] = gender;
//     data["bio"] = bio;
//     data["profile_verification_status"] = profileVerificationStatus;
//     data["login_verification_status"] = loginVerificationStatus;
//     data["socket_id"] = socketId;
//     data["createdAt"] = createdAt;
//     data["updatedAt"] = updatedAt;
//     return data;
//   }
// }
//
// class Pagination {
//   int? totalPages;
//   int? totalRecords;
//   int? currentPage;
//   int? recordsPerPage;
//
//   Pagination(
//       {this.totalPages,
//       this.totalRecords,
//       this.currentPage,
//       this.recordsPerPage});
//
//   Pagination.fromJson(Map<String, dynamic> json) {
//     totalPages = json["total_pages"];
//     totalRecords = json["total_records"];
//     currentPage = json["current_page"];
//     recordsPerPage = json["records_per_page"];
//   }
//
//   static List<Pagination> fromList(List<Map<String, dynamic>> list) {
//     return list.map(Pagination.fromJson).toList();
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = <String, dynamic>{};
//     data["total_pages"] = totalPages;
//     data["total_records"] = totalRecords;
//     data["current_page"] = currentPage;
//     data["records_per_page"] = recordsPerPage;
//     return data;
//   }
// }

class ChatListModel {
  Pagination? pagination;
  List<Chats> chats;

  ChatListModel({this.pagination, List<Chats>? chats}) : chats = chats ?? [];

  factory ChatListModel.fromJson(Map<String, dynamic> json) {
    return ChatListModel(
      pagination:
          json['pagination'] != null
              ? Pagination.fromJson(json['pagination'])
              : null,
      chats:
          json['Chats'] != null
              ? List<Chats>.from(json['Chats'].map((x) => Chats.fromJson(x)))
              : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pagination': pagination?.toJson(),
      'Chats': chats.map((x) => x.toJson()).toList(),
    };
  }
}

class Pagination {
  int? totalPages;
  int? totalRecords;
  int? currentPage;
  int? recordsPerPage;

  Pagination({
    this.totalPages,
    this.totalRecords,
    this.currentPage,
    this.recordsPerPage,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      totalPages: json['total_pages'],
      totalRecords: json['total_records'],
      currentPage: json['current_page'],
      recordsPerPage: json['records_per_page'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_pages': totalPages,
      'total_records': totalRecords,
      'current_page': currentPage,
      'records_per_page': recordsPerPage,
    };
  }
}

class Chats {
  List<Records>? records;
  PeerUserData? peerUserData;

  Chats({this.records, this.peerUserData});

  factory Chats.fromJson(Map<String, dynamic> json) {
    try {
      return Chats(
        records:
            json['Records'] != null
                ? List<Records>.from(
                  json['Records'].map((x) => Records.fromJson(x)),
                )
                : null,
        peerUserData:
            json['PeerUserData'] != null
                ? PeerUserData.fromJson(json['PeerUserData'])
                : null,
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing Chats: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('JSON: $json');
      // Return a mostly empty object that won't crash the UI
      return Chats(records: [], peerUserData: null);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'Records': records?.map((x) => x.toJson()).toList(),
      'PeerUserData': peerUserData?.toJson(),
    };
  }
}

class Records {
  int? chatId;
  String? groupIcon;
  String? chatType;
  String? groupName;
  String? groupDescription;
  String? deletedAt;
  String? createdAt;
  String? updatedAt;
  List<Messages>? messages;
  int? unseenCount;
  List<String>? blockedBy;
  List<dynamic>? archivedFor;

  Records({
    this.chatId,
    this.groupIcon,
    this.chatType,
    this.groupName,
    this.groupDescription,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
    this.messages,
    this.unseenCount,
    this.blockedBy,
    this.archivedFor,
  });

  factory Records.fromJson(Map<String, dynamic> json) {
    try {
      return Records(
        chatId: json['chat_id'],
        groupIcon: json['group_icon'],
        chatType: json['chat_type'],
        groupName: json['group_name'],
        groupDescription: json['group_description'],
        deletedAt: json['deleted_at'],
        createdAt: json['createdAt'],
        updatedAt: json['updatedAt'],
        messages:
            json['Messages'] != null
                ? List<Messages>.from(
                  json['Messages'].map((x) => Messages.fromJson(x)),
                )
                : [],
        unseenCount: json['unseen_count'] ?? 0,
        blockedBy:
            json['blocked_by'] != null
                ? List<String>.from(json['blocked_by'])
                : [],
        archivedFor: json['archived_for'] ?? [],
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing Records: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('JSON: $json');
      // Return default values
      return Records(
        chatId: 0,
        messages: [],
        unseenCount: 0,
        blockedBy: [],
        archivedFor: [],
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'group_icon': groupIcon,
      'chat_type': chatType,
      'group_name': groupName,
      'group_description': groupDescription,
      'deleted_at': deletedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'Messages': messages?.map((x) => x.toJson()).toList(),
      'unseen_count': unseenCount,
      'blocked_by': blockedBy,
      'archived_for': archivedFor,
    };
  }
}

class Messages {
  String? messageContent;
  int? replyTo;
  int? socialId;
  int? messageId;
  String? messageType;
  String? messageLength;
  String? messageSeenStatus;
  String? messageSize;
  List<dynamic>? deletedFor;
  List<dynamic>? starredFor;
  bool? deletedForEveryone;
  bool? pinned;
  String? createdAt;
  String? updatedAt;
  int? chatId;
  dynamic senderId;
  dynamic user;
  User? actionedUser;
  Social? social;
  List<CallData>? calls;

  Messages({
    this.messageContent,
    this.replyTo,
    this.socialId,
    this.messageId,
    this.messageType,
    this.messageLength,
    this.messageSeenStatus,
    this.messageSize,
    this.deletedFor,
    this.starredFor,
    this.deletedForEveryone,
    this.pinned,
    this.createdAt,
    this.updatedAt,
    this.chatId,
    this.senderId,
    this.user,
    this.actionedUser,
    this.social,
    this.calls,
  });

  factory Messages.fromJson(Map<String, dynamic> json) {
    try {
      return Messages(
        messageContent: json['message_content'],
        replyTo: json['reply_to'],
        socialId: json['social_id'],
        messageId: json['message_id'],
        messageType: json['message_type'],
        messageLength: json['message_length'],
        messageSeenStatus: json['message_seen_status'],
        messageSize: json['message_size'],
        deletedFor: json['deleted_for'],
        starredFor: json['starred_for'],
        deletedForEveryone: json['deleted_for_everyone'],
        pinned: json['pinned'],
        createdAt: json['createdAt'],
        updatedAt: json['updatedAt'],
        chatId: json['chat_id'],
        senderId: json['sender_id'],
        user: json['User'],
        actionedUser:
            json['ActionedUser'] != null
                ? User.fromJson(json['ActionedUser'])
                : null,
        // Add social property if present in your model
        social: json['social'] != null ? Social.fromJson(json['social']) : null,
        // Parse Calls array
        calls:
            json['Calls'] != null
                ? (json['Calls'] as List)
                    .map((call) => CallData.fromJson(call))
                    .toList()
                : null,
      );
    } catch (e) {
      debugPrint('Error parsing Messages: $e');
      return Messages(
        messageContent: 'Error parsing message',
        messageType: 'text',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'message_content': messageContent,
      'reply_to': replyTo,
      'social_id': socialId,
      'message_id': messageId,
      'message_type': messageType,
      'message_length': messageLength,
      'message_seen_status': messageSeenStatus,
      'message_size': messageSize,
      'deleted_for': deletedFor,
      'starred_for': starredFor,
      'deleted_for_everyone': deletedForEveryone,
      'pinned': pinned,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'chat_id': chatId,
      'sender_id': senderId,
      'User': user,
      'ActionedUser': actionedUser?.toJson(),
      'social': social?.toJson(),
      'Calls': calls?.map((x) => x.toJson()).toList(),
    };
  }
}

class PeerUserData {
  String? userName;
  String? email;
  String? profilePic;
  int? userId;
  String? fullName;
  String? countryCode;
  String? phoneNumber;
  String? country;
  String? gender;
  String? bio;
  bool? profileVerificationStatus;
  bool? loginVerificationStatus;
  List<String>? socketIds;
  String? updatedAt;
  String? createdAt;

  PeerUserData({
    this.userName,
    this.email,
    this.profilePic,
    this.userId,
    this.fullName,
    this.countryCode,
    this.phoneNumber,
    this.country,
    this.gender,
    this.bio,
    this.profileVerificationStatus,
    this.loginVerificationStatus,
    this.socketIds,
    this.updatedAt,
    this.createdAt,
  });

  factory PeerUserData.fromJson(Map<String, dynamic> json) {
    try {
      return PeerUserData(
        userName: json['user_name'],
        email: json['email'],
        profilePic: json['profile_pic'],
        userId: json['user_id'],
        fullName: json['full_name'] ?? '', // Use empty string if null
        countryCode: json['country_code'],
        phoneNumber: json['mobile_num'],
        country: json['country'],
        gender: json['gender'],
        bio: json['bio'],
        profileVerificationStatus: json['profile_verification_status'],
        loginVerificationStatus: json['login_verification_status'],
        socketIds:
            json['socket_ids'] != null
                ? List<String>.from(json['socket_ids'])
                : [],
        updatedAt: json['updatedAt'],
        createdAt: json['createdAt'],
      );
    } catch (e) {
      debugPrint('Error parsing PeerUserData: $e');
      return PeerUserData(userId: 0, fullName: 'Unknown User');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'user_name': userName,
      'email': email,
      'profile_pic': profilePic,
      'user_id': userId,
      'full_name': fullName,
      'country_code': countryCode,
      'mobile_num': phoneNumber,
      'country': country,
      'gender': gender,
      'bio': bio,
      'profile_verification_status': profileVerificationStatus,
      'login_verification_status': loginVerificationStatus,
      'socket_ids': socketIds,
      'updatedAt': updatedAt,
      'createdAt': createdAt,
    };
  }
}

class Social {
  String? reelThumbnail;
  int? socialId;
  String? socialDesc;
  String? socialType;
  int? totalViews;
  int? totalSaves;
  int? totalShares;
  User? user;

  Social({
    this.reelThumbnail,
    this.socialId,
    this.socialDesc,
    this.socialType,
    this.totalViews,
    this.totalSaves,
    this.totalShares,
    this.user,
  });

  factory Social.fromJson(Map<String, dynamic> json) {
    return Social(
      reelThumbnail: json['reel_thumbnail'],
      socialId: json['social_id'],
      socialDesc: json['social_desc'],
      socialType: json['social_type'],
      totalViews: json['total_views'],
      totalSaves: json['total_saves'],
      totalShares: json['total_shares'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reel_thumbnail': reelThumbnail,
      'social_id': socialId,
      'social_desc': socialDesc,
      'social_type': socialType,
      'total_views': totalViews,
      'total_saves': totalSaves,
      'total_shares': totalShares,
      'user': user?.toJson(),
    };
  }
}

class User {
  int? userId;
  String? userName;
  String? fullName;
  String? profilePic;

  User({this.userId, this.userName, this.fullName, this.profilePic});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      userName: json['user_name'],
      fullName: json['full_name'],
      profilePic: json['profile_pic'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'full_name': fullName,
      'profile_pic': profilePic,
    };
  }
}
