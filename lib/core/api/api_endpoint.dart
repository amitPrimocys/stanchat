class ApiEndpoints {
  // static const String baseUrl = 'https://api.example.com';
  //live
  // static const String baseUrl = 'https://advance.whoxachat.com/api';
  // static const String socketUrl = 'https://advance.whoxachat.com';

  static const String baseUrl = 'http://192.168.0.27:3047/api';
  static const String socketUrl = 'http://192.168.0.27:3047';

  static const String projectConfig = "/config/";
  static const String registerEmail = "/users/signup";
  static const String registerPhone = "/users/signup";
  static const String verifyOtpPhone = "/users/verfyOtp";
  static const String verifyOtpEmail = "/users/verfyOtp";
  static const String userNameCheck = "/users/find-user";
  static const String userCreateProfile = "/users/updateUser";
  static const String userCreateContact = "/contacts/create-contacts";
  static const String getContacts = "/contacts/get-contacts";
  static const String syncContacts = "/contacts/sync-contacts";
  static const String deleteAcc = "/users/";
  static const String logout = "/users/logout";
  static const String storyUpload = "/story/upload-story";
  static const String storyGetAll = "/story/get-stories";
  static const String storyView = "/story/view-story";
  static const String storyDelete = "/story/remove-story";
  static const String getStory = '/story/get-story';
  static const String sendMessage = "/chat/send-message";
  static const String checkUserOnlineStatus = "/users/is-online";
  static const String pinUnpinMessage = "/chat/pin-unpin-message";
  static const String forwardMessage = "/chat/forward-message";
  static const String starUnstarMessage = "/chat/star-unstar-message";
  static const String starredMessages = "/chat/starred-messages";
  static const String groupCreate = '/chat/create-group';
  static const String groupUpdate = '/chat/update-group';
  static const String groupMembers = '/chat/group-members';

  static const String removeMember = "/chat/remove-member";
  static const String addMember = "/chat/add-member";
  static const String makeGroupAdmin = "/chat/create-group-admin";
  static const String removeGroupAdmin = "/chat/remove-group-admin";
  static const String getAllAvatars = "/avatar/get-all-avatars";
  static const String blockUnblock = "/block/block-unblock";
  static const String blockList = "/block/block-list";
  static const String clearChat = "/chat/clear-chat";
  static const String reportTypes = "/report/report-types";
  static const String reportUser = "/report/report-user";
  static const String chatMedia = "/chat/chat-media";
  static const String callHistory = "/chat/call-history";
  static const String searchChat = "/chat/search-chat";
  static const String makeCall = "/call/make-call";
  static const String getCounts = "/users/get-counts";
  static const String broadcastNotification =
      "/users/list-broadcast-notification";
  static const String markAsSeenNotification =
      "/users/mark-as-seen-broadcast-notification";

  static const String getlanguage = "/language/get-language";
  static const String worldList = "/language/get-language-words";

  // Add more endpoints as needed
}
