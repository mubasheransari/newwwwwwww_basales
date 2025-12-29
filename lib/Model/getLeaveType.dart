import 'dart:convert';


class GetLeaveTypeModel {
  final String? status;
  final String? message;
  final List<LeaveType> items;

  GetLeaveTypeModel({
    required this.status,
    required this.message,
    required this.items,
  });

  factory GetLeaveTypeModel.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List?) ?? const [];
    return GetLeaveTypeModel(
      status: json['status']?.toString(),
      message: json['message']?.toString(),
      items: list
          .map((e) => LeaveType.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  static GetLeaveTypeModel fromBody(String body) {
    final decoded = jsonDecode(body);
    return GetLeaveTypeModel.fromJson((decoded as Map).cast<String, dynamic>());
  }
}

class LeaveType {
  final String id;
  final String name;

  LeaveType({required this.id, required this.name});

  factory LeaveType.fromJson(Map<String, dynamic> json) => LeaveType(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );
}
