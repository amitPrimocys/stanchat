class ViewedUserListModel {
  bool? status;
  Data? data;
  String? message;
  bool? toast;

  ViewedUserListModel({this.status, this.data, this.message, this.toast});

  ViewedUserListModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
    message = json['message'];
    toast = json['toast'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['message'] = message;
    data['toast'] = toast;
    return data;
  }
}

class Data {
  int? storyId;
  String? caption;
  String? media;
  String? storyType;
  String? expiresAt;
  List<Views>? views;
  String? createdAt;
  String? updatedAt;
  int? userId;

  Data({
    this.storyId,
    this.caption,
    this.media,
    this.storyType,
    this.expiresAt,
    this.views,
    this.createdAt,
    this.updatedAt,
    this.userId,
  });

  Data.fromJson(Map<String, dynamic> json) {
    storyId = json['story_id'];
    caption = json['caption'];
    media = json['media'];
    storyType = json['story_type'];
    expiresAt = json['expiresAt'];
    if (json['views'] != null) {
      views = <Views>[];
      json['views'].forEach((v) {
        views!.add(Views.fromJson(v));
      });
    }
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    userId = json['user_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['story_id'] = storyId;
    data['caption'] = caption;
    data['media'] = media;
    data['story_type'] = storyType;
    data['expiresAt'] = expiresAt;
    if (views != null) {
      data['views'] = views!.map((v) => v.toJson()).toList();
    }
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['user_id'] = userId;
    return data;
  }
}

class Views {
  int? userId;
  String? fullName;
  String? firstName;
  String? lastName;
  String? userName;
  String? email;
  String? countryCode;
  List<String>? socketIds;
  String? mobileNum;
  int? otp;
  String? password;
  String? loginType;
  String? profilePic;
  String? selfie;
  String? gender;
  String? country;
  String? countryShortName;
  String? state;
  String? city;
  String? bio;
  String? deviceToken;
  bool? profileVerificationStatus;
  bool? loginVerificationStatus;
  bool? isPrivate;
  bool? isAdmin;
  List<String>? platforms;
  bool? blokedByAdmin;
  String? createdAt;
  String? updatedAt;
  String? viewedAt;

  Views({
    this.userId,
    this.fullName,
    this.firstName,
    this.lastName,
    this.userName,
    this.email,
    this.countryCode,
    this.socketIds,
    this.mobileNum,
    this.otp,
    this.password,
    this.loginType,
    this.profilePic,
    this.selfie,
    this.gender,
    this.country,
    this.countryShortName,
    this.state,
    this.city,
    this.bio,
    this.deviceToken,
    this.profileVerificationStatus,
    this.loginVerificationStatus,
    this.isPrivate,
    this.isAdmin,
    this.platforms,
    this.blokedByAdmin,
    this.createdAt,
    this.updatedAt,
    this.viewedAt,
  });

  Views.fromJson(Map<String, dynamic> json) {
    userId = json['user_id'];
    fullName = json['full_name'];
    firstName = json['first_name'];
    lastName = json['last_name'];
    userName = json['user_name'];
    email = json['email'];
    countryCode = json['country_code'];
    socketIds = json['socket_ids'].cast<String>();
    mobileNum = json['mobile_num'];
    otp = json['otp'];
    password = json['password'];
    loginType = json['login_type'];
    profilePic = json['profile_pic'];
    selfie = json['selfie'];
    gender = json['gender'];
    country = json['country'];
    countryShortName = json['country_short_name'];
    state = json['state'];
    city = json['city'];
    bio = json['bio'];
    deviceToken = json['device_token'];
    profileVerificationStatus = json['profile_verification_status'];
    loginVerificationStatus = json['login_verification_status'];
    isPrivate = json['is_private'];
    isAdmin = json['is_admin'];
    platforms = json['platforms'].cast<String>();
    blokedByAdmin = json['bloked_by_admin'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    viewedAt = json['viewed_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_id'] = userId;
    data['full_name'] = fullName;
    data['first_name'] = firstName;
    data['last_name'] = lastName;
    data['user_name'] = userName;
    data['email'] = email;
    data['country_code'] = countryCode;
    data['socket_ids'] = socketIds;
    data['mobile_num'] = mobileNum;
    data['otp'] = otp;
    data['password'] = password;
    data['login_type'] = loginType;
    data['profile_pic'] = profilePic;
    data['selfie'] = selfie;
    data['gender'] = gender;
    data['country'] = country;
    data['country_short_name'] = countryShortName;
    data['state'] = state;
    data['city'] = city;
    data['bio'] = bio;
    data['device_token'] = deviceToken;
    data['profile_verification_status'] = profileVerificationStatus;
    data['login_verification_status'] = loginVerificationStatus;
    data['is_private'] = isPrivate;
    data['is_admin'] = isAdmin;
    data['platforms'] = platforms;
    data['bloked_by_admin'] = blokedByAdmin;
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    data['viewed_at'] = viewedAt;
    return data;
  }
}
