import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'package:new_amst_flutter/Model/loginModel.dart';

class LocalSession {
  static const _kLoginModelKey = 'login_model_json';
  static final GetStorage _box = GetStorage();

  static Future<void> saveLogin(LoginModel model) async {
    await _box.write(_kLoginModelKey, jsonEncode(model.toJson()));
  }

  static LoginModel? readLogin() {
    final raw = _box.read(_kLoginModelKey);
    if (raw is String && raw.isNotEmpty) {
      try {
        return LoginModel.fromJson(jsonDecode(raw));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> clearLogin() => _box.remove(_kLoginModelKey);
}
