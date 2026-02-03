class VerifyOTPModel {
  bool? status;
  Data? data;
  String? message;
  bool? toast;

  VerifyOTPModel({this.status, this.data, this.message, this.toast});

  VerifyOTPModel.fromJson(Map<String, dynamic> json) {
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
  String? token;
  User? user;

  Data({this.token, this.user});

  Data.fromJson(Map<String, dynamic> json) {
    token = json['token'];
    user = json['user'] != null ? User.fromJson(json['user']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['token'] = token;
    if (user != null) {
      data['user'] = user!.toJson();
    }
    return data;
  }
}

class User {
  String? userName;
  String? email;
  String? mobileNum;
  String? profilePic;
  String? selfie;
  String? dob;
  int? userId;
  String? fullName;
  String? firstName;
  String? lastName;
  String? countryCode;
  // List<Null>? socketIds;
  int? otp;
  String? password;
  String? loginType;
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
  bool? isDemo;
  // List<Null>? platforms;
  String? createdAt;
  String? updatedAt;

  User({
    this.userName,
    this.email,
    this.mobileNum,
    this.profilePic,
    this.selfie,
    this.dob,
    this.userId,
    this.fullName,
    this.firstName,
    this.lastName,
    this.countryCode,
    // this.socketIds,
    this.otp,
    this.password,
    this.loginType,
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
    this.isDemo,
    // this.platforms,
    this.createdAt,
    this.updatedAt,
  });

  User.fromJson(Map<String, dynamic> json) {
    userName = json['user_name'];
    email = json['email'];
    mobileNum = json['mobile_num'];
    profilePic = json['profile_pic'];
    selfie = json['selfie'];
    dob = json['dob'];
    userId = json['user_id'];
    fullName = json['full_name'];
    firstName = json['first_name'];
    lastName = json['last_name'];
    countryCode = json['country_code'];
    // if (json['socket_ids'] != null) {
    //   socketIds = <Null>[];
    //   json['socket_ids'].forEach((v) {
    //     socketIds!.add(Null.fromJson(v));
    //   });
    // }
    otp = json['otp'];
    password = json['password'];
    loginType = json['login_type'];
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
    isDemo = json['is_demo'];
    // if (json['platforms'] != null) {
    //   platforms = <Null>[];
    //   json['platforms'].forEach((v) {
    //     platforms!.add(Null.fromJson(v));
    //   });
    // }
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_name'] = userName;
    data['email'] = email;
    data['mobile_num'] = mobileNum;
    data['profile_pic'] = profilePic;
    data['selfie'] = selfie;
    data['dob'] = dob;
    data['user_id'] = userId;
    data['full_name'] = fullName;
    data['first_name'] = firstName;
    data['last_name'] = lastName;
    data['country_code'] = countryCode;
    // if (socketIds != null) {
    //   data['socket_ids'] = socketIds!.map((v) => v.toJson()).toList();
    // }
    data['otp'] = otp;
    data['password'] = password;
    data['login_type'] = loginType;
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
    data['is_demo'] = isDemo;
    // if (platforms != null) {
    //   data['platforms'] = platforms!.map((v) => v.toJson()).toList();
    // }
    data['createdAt'] = createdAt;
    data['updatedAt'] = updatedAt;
    return data;
  }
}
