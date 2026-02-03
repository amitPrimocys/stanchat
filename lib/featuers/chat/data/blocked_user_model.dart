class BlockedUserModel {
  List<BlockedUserRecord>? records;
  Pagination? pagination;

  BlockedUserModel({this.records, this.pagination});

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) {
    return BlockedUserModel(
      records: json['Records'] != null
          ? List<BlockedUserRecord>.from(
              json['Records'].map((x) => BlockedUserRecord.fromJson(x)))
          : [],
      pagination: json['Pagination'] != null
          ? Pagination.fromJson(json['Pagination'])
          : null,
    );
  }
}

class BlockedUserRecord {
  int? blockId;
  bool? approved;
  String? createdAt;
  String? updatedAt;
  int? userId;
  int? blockedId;
  BlockedUserData? blocked;

  BlockedUserRecord({
    this.blockId,
    this.approved,
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.blockedId,
    this.blocked,
  });

  factory BlockedUserRecord.fromJson(Map<String, dynamic> json) {
    return BlockedUserRecord(
      blockId: json['block_id'],
      approved: json['approved'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      userId: json['user_id'],
      blockedId: json['blocked_id'],
      blocked: json['blocked'] != null
          ? BlockedUserData.fromJson(json['blocked'])
          : null,
    );
  }
}

class BlockedUserData {
  String? userName;
  String? email;
  String? mobileNum;
  String? profilePic;
  String? selfie;
  String? dob;
  int? userId;
  String? firstName;
  String? lastName;
  String? fullName;
  String? countryCode;
  List<String>? socketIds;
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
  List<String>? platforms;
  String? deletedAt;
  bool? blokedByAdmin;
  List<ContactDetail>? contactDetails;
  String? createdAt;
  String? updatedAt;

  BlockedUserData({
    this.userName,
    this.email,
    this.mobileNum,
    this.profilePic,
    this.selfie,
    this.dob,
    this.userId,
    this.firstName,
    this.lastName,
    this.fullName,
    this.countryCode,
    this.socketIds,
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
    this.platforms,
    this.deletedAt,
    this.blokedByAdmin,
    this.contactDetails,
    this.createdAt,
    this.updatedAt,
  });

  factory BlockedUserData.fromJson(Map<String, dynamic> json) {
    return BlockedUserData(
      userName: json['user_name'],
      email: json['email'],
      mobileNum: json['mobile_num']?.toString(),
      profilePic: json['profile_pic'],
      selfie: json['selfie'],
      dob: json['dob'],
      userId: json['user_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      fullName: json['full_name'],
      countryCode: json['country_code'],
      socketIds: json['socket_ids'] != null
          ? List<String>.from(json['socket_ids'])
          : [],
      otp: json['otp'],
      password: json['password'],
      loginType: json['login_type'],
      gender: json['gender'],
      country: json['country'],
      countryShortName: json['country_short_name'],
      state: json['state'],
      city: json['city'],
      bio: json['bio'],
      deviceToken: json['device_token'],
      profileVerificationStatus: json['profile_verification_status'],
      loginVerificationStatus: json['login_verification_status'],
      isPrivate: json['is_private'],
      isAdmin: json['is_admin'],
      platforms: json['platforms'] != null
          ? List<String>.from(json['platforms'])
          : [],
      deletedAt: json['deleted_at'],
      blokedByAdmin: json['bloked_by_admin'],
      contactDetails: json['contact_details'] != null
          ? List<ContactDetail>.from(
              json['contact_details'].map((x) => ContactDetail.fromJson(x)))
          : [],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }
}

class ContactDetail {
  String? name;
  String? number;
  int? userId;

  ContactDetail({this.name, this.number, this.userId});

  factory ContactDetail.fromJson(Map<String, dynamic> json) {
    return ContactDetail(
      name: json['name'],
      number: json['number']?.toString(),
      userId: json['user_id'],
    );
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
}