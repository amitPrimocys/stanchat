class ReportResponse {
  final bool status;
  final Map<String, dynamic> data;
  final String message;
  final bool toast;

  ReportResponse({
    required this.status,
    required this.data,
    required this.message,
    required this.toast,
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      status: json['status'] ?? false,
      data: json['data'] ?? {},
      message: json['message'] ?? '',
      toast: json['toast'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'data': data, 'message': message, 'toast': toast};
  }
}

class ReportUserRequest {
  final int userId;
  final int reportTypeId;
  final int? groupId;

  ReportUserRequest({
    required this.userId,
    required this.reportTypeId,
    this.groupId,
  });

  Map<String, dynamic> toJson() {
    return {
      if (userId != -1) 'user_id': userId,
      'report_type_id': reportTypeId,
      if (groupId != null) 'chat_id': groupId,
    };
  }
}
