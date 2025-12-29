import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:new_amst_flutter/Model/getLeaveType.dart';
import 'dart:io' show Platform;

class Repository {
  Map<String, String> get _formHeaders => const {
    'Accept': 'application/json',
    'Content-Type': 'application/x-www-form-urlencoded',
  };

  final registerUrl =
      "http://teaapis.mezangrp.com/amstea/index.php?route=api/user/signup";

  final loginUrl =
      "http://teaapis.mezangrp.com/amstea/index.php?route=api/user/login";
  final attendanceUrl =
      "http://services.zankgroup.com/amslive/index.php?route=api/most/attendance";

      final String baSalesCreateUrl =
    "https://tapex.mezangrp.com/ords/tea/ba_sales/create/";


Future<http.Response> createBaSale({
  required String skuId,
  required String skuName,
  required String skuPrice,  // e.g. "500"
  required String skuQty,    // e.g. "10"
  required String brandName, // e.g. "Mezan"
  required String baCode,    // e.g. "001"
  required String createdBy, // e.g. "XYZ"
}) async {
  try {
    final uri = Uri.parse(baSalesCreateUrl);
    debugPrint('➡️ [ba_sales/create] POST $uri');

    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(_acceptOnlyHeaders) // must NOT contain Content-Type
      ..fields['sku_id']    = skuId
      ..fields['sku_name']  = skuName
      ..fields['sku_price'] = skuPrice
      ..fields['sku_qty']   = skuQty
      ..fields['brand_name'] = brandName
      ..fields['ba_code']    = baCode
      ..fields['created_by'] = createdBy;

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);

    debugPrint('⬅️ [ba_sales/create] ${res.statusCode}: ${res.body}');
    return res;
  } on TimeoutException {
    debugPrint('TimeoutException');
    return http.Response(
      jsonEncode({
        "isSuccess": false,
        "message": "Request timed out. Please try again.",
      }),
      408,
    );
  } catch (e, st) {
    debugPrint('createBaSale error: $e\n$st');
    return http.Response(
      jsonEncode({"isSuccess": false, "message": "Unexpected error: $e"}),
      520,
    );
  }
}

//       Future<http.Response> createBaSale({
//           required String skuid, 
//   required String skuPrice,  // e.g. "500"
//   required String skuQty,    // e.g. "10"
//   required String brandName, // e.g. "Mezan"
//   required String baCode,    // e.g. "001"
//   required String createdBy, // e.g. "XYZ"
// }) async {
//   try {
//     final uri = Uri.parse(baSalesCreateUrl);
//     debugPrint('➡️ [ba_sales/create] POST $uri');

//     // Use MultipartRequest to mimic Postman "form-data" (text only).
//     final req = http.MultipartRequest('POST', uri)
//       ..headers.addAll(_acceptOnlyHeaders) // only "Accept: application/json"
//        ..fields['sku_id']  = skuid
//       ..fields['sku_price']  = skuPrice
//       ..fields['sku_qty']    = skuQty
//       ..fields['brand_name'] = brandName
//       ..fields['ba_code']    = baCode
//       ..fields['created_by'] = createdBy;

//     final streamed = await req.send().timeout(const Duration(seconds: 30));
//     final res = await http.Response.fromStream(streamed);

//     debugPrint('⬅️ [ba_sales/create] ${res.statusCode}: ${res.body}');
//     return res;
//   } on TimeoutException {
//         debugPrint('TimeoutException');
//     return http.Response(
//       jsonEncode({
//         "isSuccess": false,
//         "message": "Request timed out. Please try again.",
//       }),
//       408,
//     );
//   } catch (e, st) {
//     debugPrint('createBaSale error: $e\n$st');
//     return http.Response(
//       jsonEncode({"isSuccess": false, "message": "Unexpected error: $e"}),
//       520,
//     );
//   }
// }


  Future<http.Response> registerUser({
    required String code,
    required String name,
    required String cnic,
    required String address,
    required String mobile1,
    required String mobile2,
    required String email,
    required String password,
    required String distribution,
    required String territory,
    required String channel,
    required String latitude, // keep as String if backend expects string
    required String longitude, // keep as String if backend expects string
    required String deviceId,
    required String regToken, // keep as String if backend expects string
  }) async {
    final payload = <String, dynamic>{
      "code": code,
      "name": name,
      "cnic": cnic,
      "address": address,
      "mobile1": mobile1,
      "mobile2": mobile2,
      "email": email,
      "password": password,
      "distribution": distribution,
      "territory": territory,
      "channel": channel,
      "latitude": latitude,
      "longitude": longitude,
      "deviceid": deviceId,
      "regtoken": regToken,
    };

    final formBody = {"request": jsonEncode(payload)};

    try {
      final res = await http
          .post(Uri.parse(registerUrl), headers: _formHeaders, body: formBody)
          .timeout(const Duration(seconds: 30));
      debugPrint("⬅️ /register ${res.statusCode}: ${res.body}");
      return res;
    } on TimeoutException {
      return http.Response(
        jsonEncode({
          "isSuccess": false,
          "message": "Request timed out. Please try again.",
        }),
        408,
      );
    } catch (e, st) {
      debugPrint('registerUser error: $e\n$st');
      return http.Response(
        jsonEncode({"isSuccess": false, "message": "Unexpected error: $e"}),
        520,
      );
    }
  }

  static ({bool ok, String message}) parseApiMessage(String body, int status) {
    try {
      final obj = jsonDecode(body);
      // Handle common shapes
      if (obj is Map) {
        final msg = (obj['message'] ?? obj['Message'] ?? obj['msg'] ?? '')
            .toString();
        final ok =
            (obj['isSuccess'] == true) || (status >= 200 && status < 300);
        return (ok: ok, message: msg.isEmpty ? 'Done' : msg);
      }
    } catch (_) {}
    // Fallback
    final ok = status >= 200 && status < 300;
    return (ok: ok, message: ok ? 'Done' : 'Request failed ($status)');
  }

  Future<http.Response> submitAttendance({
    required int type, // 1
    required String code, // "4310"
    required String latitude, // "24.8871334"
    required String longitude, // "66.9788572"
    required String deviceId, // "3d61adab1be4b2f2"
    required String actType, // "ATTENDANCE"
    required String action, // "IN" | "OUT"
    required String attTime, // "13:06:57"
    required String attDate, // "24-Jun-2025"


  }) async {
    final payload = <String, dynamic>{
      "type": type,
      "code": code,
      "latitude": latitude,
      "longitude": longitude,
      "device_id": deviceId,
      "act_type": actType,
      "action": action,
      "att_time": attTime,
      "att_date": attDate,
      "remarks": "jhvrbjhvbre",
      "app_version": "2.0.2",
      "regtoken": "0",
    };

    final body = {"request": jsonEncode(payload)};

    try {
      final res = await http
          .post(Uri.parse(attendanceUrl), headers: _formHeaders, body: body)
          .timeout(const Duration(seconds: 30));

      debugPrint("⬅️ /attendance ${res.statusCode}: ${res.body}");
      return res;
    } on TimeoutException {
      return http.Response(
        jsonEncode({
          "isSuccess": false,
          "message": "Request timed out. Please try again.",
        }),
        408,
      );
    } catch (e, st) {
      debugPrint('submitAttendance error: $e\n$st');
      return http.Response(
        jsonEncode({"isSuccess": false, "message": "Unexpected error: $e"}),
        520,
      );
    }
  }

  Future<http.Response> login({
    required String email,
    required String pass,
    required String latitude, // keep as String if backend expects string
    required String longitude, // keep as String if backend expects string
    required String actType, // e.g. "LOGIN"
    required String action, // e.g. "IN"
    required String attTime, // e.g. "11:20:52"
    required String attDate, // e.g. "13-Nov-2025"
    required String appVersion, // e.g. "2.0.2"
    required String add, // address/notes
    required String deviceId, // e.g. "0d6bb3238ca24544"
  }) async {
    final payload = <String, dynamic>{
      "email": email,
      "pass": pass,
      "latitude": latitude,
      "longitude": longitude,
      "act_type": actType,
      "action": action,
      "att_time": attTime,
      "att_date": attDate,
      "app_version": appVersion,
      "add": add,
      "device_id": deviceId,
    };

    final formBody = {"request": jsonEncode(payload)};

    try {
      final res = await http
          .post(Uri.parse(loginUrl), headers: _formHeaders, body: formBody)
          .timeout(const Duration(seconds: 30));

      debugPrint("⬅️ /login ${res.statusCode}: ${res.body}");
      return res;
    } on TimeoutException {
      return http.Response(
        jsonEncode({
          "isSuccess": false,
          "message": "Request timed out. Please try again.",
        }),
        408,
      );
    } catch (e, st) {
      debugPrint('login error: $e\n$st');
      return http.Response(
        jsonEncode({"isSuccess": false, "message": "Unexpected error: $e"}),
        520,
      );
    }
  }


  static const String _lanHost = '192.168.1.73'; // physical device target
  static const String _androidEmuHost = '10.0.2.2'; // Android emulator → host
  static const String _iosSimHost = '127.0.0.1'; // iOS simulator → host

  /// Picks the right host for the current runtime.
  String _hostForRuntime() {
    if (kIsWeb) return _lanHost;

    // If you are using Android emulator, this is correct.
    if (Platform.isAndroid) return _androidEmuHost;

    // iOS simulator on same Mac as the server:
    if (Platform.isIOS) return _iosSimHost;

    // Fallback (desktop/flutter run on same machine as server)
    return _lanHost;
  }

  String get _base =>
      'http://${_hostForRuntime()}/amstea/index.php?route=api/user';
  String get _leaveTypeUrl => '$_base/getLeaveType';

  Map<String, String> get _acceptOnlyHeaders => const {
    'Accept': 'application/json',
  };

  /// High-level call: tries multipart, then x-www-form-urlencoded, then GET.
  Future<GetLeaveTypeModel> getLeaveTypes({
    required String userId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final r1 = await _tryMultipart(_leaveTypeUrl, {'user_id': userId}, timeout);
    if (_looksOk(r1)) return GetLeaveTypeModel.fromBody(r1.body!);

    final r2 = await _tryForm(_leaveTypeUrl, {'user_id': userId}, timeout);
    if (_looksOk(r2)) return GetLeaveTypeModel.fromBody(r2.body!);

    final r3 = await _tryGet(_leaveTypeUrl, {'user_id': userId}, timeout);
    if (_looksOk(r3)) return GetLeaveTypeModel.fromBody(r3.body!);

    final sc = r1.code ?? r2.code ?? r3.code ?? -1;
    final msg = r1.err ?? r2.err ?? r3.err ?? 'no_valid_response';
    return GetLeaveTypeModel(
      status: '0',
      message: 'http_$sc:$msg',
      items: const [],
    );
  }

  /* --------------------------- raw variants --------------------------- */

  Future<_CallResult> _tryMultipart(
    String url,
    Map<String, String> fields,
    Duration timeout,
  ) async {
    try {
      final uri = Uri.parse(url);
      debugPrint('➡️ [multipart] POST $uri  fields: $fields');
      final req = http.MultipartRequest('POST', uri)
        ..headers.addAll(_acceptOnlyHeaders)
        ..fields.addAll(fields);
      final streamed = await req.send().timeout(timeout);
      final res = await http.Response.fromStream(streamed);
      debugPrint('⬅️ [multipart] ${res.statusCode} ${res.reasonPhrase}');
      debugPrint('⬅️ body: ${res.body}');
      return _CallResult(code: res.statusCode, body: res.body);
    } catch (e) {
      debugPrint('❌ [multipart] error: $e');
      return _CallResult(err: '$e');
    }
  }

  Future<_CallResult> _tryForm(
    String url,
    Map<String, String> fields,
    Duration timeout,
  ) async {
    try {
      final uri = Uri.parse(url);
      debugPrint('➡️ [form] POST $uri  fields: $fields');
      final res = await http
          .post(uri, headers: _formHeaders, body: fields)
          .timeout(timeout);
      debugPrint('⬅️ [form] ${res.statusCode} ${res.reasonPhrase}');
      debugPrint('⬅️ body: ${res.body}');
      return _CallResult(code: res.statusCode, body: res.body);
    } catch (e) {
      debugPrint('❌ [form] error: $e');
      return _CallResult(err: '$e');
    }
  }

  Future<_CallResult> _tryGet(
    String url,
    Map<String, String> qp,
    Duration timeout,
  ) async {
    try {
      final u = Uri.parse(url);
      final uri = u.replace(queryParameters: {...u.queryParameters, ...qp});
      debugPrint('➡️ [GET] $uri');
      final res = await http
          .get(uri, headers: _acceptOnlyHeaders)
          .timeout(timeout);
      debugPrint('⬅️ [GET] ${res.statusCode} ${res.reasonPhrase}');
      debugPrint('⬅️ body: ${res.body}');
      return _CallResult(code: res.statusCode, body: res.body);
    } catch (e) {
      debugPrint('❌ [GET] error: $e');
      return _CallResult(err: '$e');
    }
  }

  bool _looksOk(_CallResult r) {
    if (r.code != 200 || r.body == null || r.body!.isEmpty) return false;
    try {
      final m = jsonDecode(r.body!);
      if (m is! Map) return false;
      final status = m['status']?.toString();
      final items = m['items'];
      return status == '1' && items is List;
    } catch (_) {
      return false;
    }
  }
}

class _CallResult {
  final int? code;
  final String? body;
  final String? err;
  _CallResult({this.code, this.body, this.err});
}
