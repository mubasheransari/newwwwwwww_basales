import 'dart:convert';


LoginModel loginModelFromJson(String str) =>
    LoginModel.fromJson(json.decode(str) as Map<String, dynamic>);

String loginModelToJson(LoginModel data) => json.encode(data.toJson());

class LoginModel {
  final String? status;
  final String? message;
  final Userinfo? userinfo;
  final List<Region> regions; // default: []
  final String? userDevice;

  const LoginModel({
    this.status,
    this.message,
    this.userinfo,
    this.regions = const [],
    this.userDevice,
  });

  factory LoginModel.fromJson(Map<String, dynamic> json) => LoginModel(
        status: json['status'] as String?,
        message: json['message'] as String?,
        userinfo: (json['userinfo'] is Map<String, dynamic>)
            ? Userinfo.fromJson(json['userinfo'] as Map<String, dynamic>)
            : null,
        regions: (json['regions'] is List)
            ? (json['regions'] as List)
                .whereType<Map<String, dynamic>>()
                .map(Region.fromJson)
                .toList()
            : const <Region>[],
        userDevice: json['user_device'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'status': status,
        'message': message,
        'userinfo': userinfo?.toJson(),
        'regions': regions.map((x) => x.toJson()).toList(),
        'user_device': userDevice,
      };
}

class Region {
  final String? name;

  const Region({this.name});

  factory Region.fromJson(Map<String, dynamic> json) =>
      Region(name: json['name'] as String?);

  Map<String, dynamic> toJson() => {'name': name};
}

class Userinfo {
  final String? code;
  final String? empnam;
  final String? empfnam;
  final String? desnam;
  final String? descod;
  final String? depnam;
  final String? phone;
  final String? phone2;
  final String? adres1;
  final String? checkLocation;
  final String? checkPhoto;
  final String? markAttendance;
  final String? markExpense;
  final String? expenseReport;
  final String? leaveReport;
  final String? tracking;
  final String? trackingTime;
  final String? dsfStatus;
  final String? segment;
  final String? teaOrder;
  final String? oilOrder;
  final String? moduleId;
  final dynamic attachment; // keep dynamic, can be null or any type
  final String? region;
  final String? flag;
  final String? dsfType;
  final String? attendRequest;
  final String? restrictMock;
  final String? auditForm;
  final String? restrictAttendance;
  final String? radiusAttendance;
  final String? screenshot;
  final String? attendMechanism;

  const Userinfo({
    this.code,
    this.empnam,
    this.empfnam,
    this.desnam,
    this.descod,
    this.depnam,
    this.phone,
    this.phone2,
    this.adres1,
    this.checkLocation,
    this.checkPhoto,
    this.markAttendance,
    this.markExpense,
    this.expenseReport,
    this.leaveReport,
    this.tracking,
    this.trackingTime,
    this.dsfStatus,
    this.segment,
    this.teaOrder,
    this.oilOrder,
    this.moduleId,
    this.attachment,
    this.region,
    this.flag,
    this.dsfType,
    this.attendRequest,
    this.restrictMock,
    this.auditForm,
    this.restrictAttendance,
    this.radiusAttendance,
    this.screenshot,
    this.attendMechanism,
  });

  factory Userinfo.fromJson(Map<String, dynamic> json) => Userinfo(
        code: json['code'] as String?,
        empnam: json['empnam'] as String?,
        empfnam: json['empfnam'] as String?,
        desnam: json['desnam'] as String?,
        descod: json['descod'] as String?,
        depnam: json['depnam'] as String?,
        phone: json['phone'] as String?,
        phone2: json['phone2'] as String?,
        adres1: json['adres1'] as String?,
        checkLocation: json['check_location'] as String?,
        checkPhoto: json['check_photo'] as String?,
        markAttendance: json['mark_attendance'] as String?,
        markExpense: json['mark_expense'] as String?,
        expenseReport: json['expense_report'] as String?,
        leaveReport: json['leave_report'] as String?,
        tracking: json['tracking'] as String?,
        trackingTime: json['tracking_time'] as String?,
        dsfStatus: json['dsf_status'] as String?,
        segment: json['segment'] as String?,
        teaOrder: json['tea_order'] as String?,
        oilOrder: json['oil_order'] as String?,
        moduleId: json['module_id'] as String?,
        attachment: json['attachment'],
        region: json['region'] as String?,
        flag: json['flag'] as String?,
        dsfType: json['dsf_type'] as String?,
        attendRequest: json['attend_request'] as String?,
        restrictMock: json['restrict_mock'] as String?,
        auditForm: json['audit_form'] as String?,
        restrictAttendance: json['restrict_attendance'] as String?,
        radiusAttendance: json['radius_attendance'] as String?,
        screenshot: json['screenshot'] as String?,
        attendMechanism: json['attend_mechanism'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'empnam': empnam,
        'empfnam': empfnam,
        'desnam': desnam,
        'descod': descod,
        'depnam': depnam,
        'phone': phone,
        'phone2': phone2,
        'adres1': adres1,
        'check_location': checkLocation,
        'check_photo': checkPhoto,
        'mark_attendance': markAttendance,
        'mark_expense': markExpense,
        'expense_report': expenseReport,
        'leave_report': leaveReport,
        'tracking': tracking,
        'tracking_time': trackingTime,
        'dsf_status': dsfStatus,
        'segment': segment,
        'tea_order': teaOrder,
        'oil_order': oilOrder,
        'module_id': moduleId,
        'attachment': attachment,
        'region': region,
        'flag': flag,
        'dsf_type': dsfType,
        'attend_request': attendRequest,
        'restrict_mock': restrictMock,
        'audit_form': auditForm,
        'restrict_attendance': restrictAttendance,
        'radius_attendance': radiusAttendance,
        'screenshot': screenshot,
        'attend_mechanism': attendMechanism,
      };
}
