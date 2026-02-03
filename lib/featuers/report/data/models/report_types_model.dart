class ReportTypesResponse {
  final bool status;
  final ReportTypesData data;
  final String message;
  final bool toast;

  ReportTypesResponse({
    required this.status,
    required this.data,
    required this.message,
    required this.toast,
  });

  factory ReportTypesResponse.fromJson(Map<String, dynamic> json) {
    return ReportTypesResponse(
      status: json['status'] ?? false,
      data: ReportTypesData.fromJson(json['data'] ?? {}),
      message: json['message'] ?? '',
      toast: json['toast'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'data': data.toJson(),
      'message': message,
      'toast': toast,
    };
  }
}

class ReportTypesData {
  final List<ReportType> reportTypes;

  ReportTypesData({
    required this.reportTypes,
  });

  factory ReportTypesData.fromJson(Map<String, dynamic> json) {
    return ReportTypesData(
      reportTypes: (json['ReportTypes'] as List<dynamic>? ?? [])
          .map((item) => ReportType.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ReportTypes': reportTypes.map((item) => item.toJson()).toList(),
    };
  }
}

class ReportType {
  final int reportTypeId;
  final String reportText;
  final String reportFor;
  final String createdAt;
  final String updatedAt;

  ReportType({
    required this.reportTypeId,
    required this.reportText,
    required this.reportFor,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportType.fromJson(Map<String, dynamic> json) {
    return ReportType(
      reportTypeId: json['report_type_id'] ?? 0,
      reportText: json['report_text'] ?? '',
      reportFor: json['report_for'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'report_type_id': reportTypeId,
      'report_text': reportText,
      'report_for': reportFor,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}