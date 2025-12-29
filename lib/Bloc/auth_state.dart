import 'package:equatable/equatable.dart';
import 'package:new_amst_flutter/Model/getLeaveType.dart';
import 'package:new_amst_flutter/Model/loginModel.dart';




enum GetLeavesTypeStatus { initial, loading, success, failure }
enum LoginStatus { initial, loading, success, failure }

enum MapLoadStatus { initial, creating, almostReady, ready }

class AuthState extends Equatable {
  final GetLeavesTypeStatus getLeavesTypeStatus;
  final LoginStatus loginStatus;
  final GetLeaveTypeModel? getLeaveTypeModel;
  // Legacy API login model (kept for compatibility in older screens)
  final LoginModel? loginModel;

  // ✅ Firebase session/profile
  final String? firebaseUid;
  final String? firebaseEmail;
  final String? userName;
  final String? userCode;
  final bool isAdmin;
  final bool isSupervisor;
  final String? error;

  // 🔥 NEW: map load status
  final MapLoadStatus mapLoadStatus;

  const AuthState({
    this.getLeavesTypeStatus = GetLeavesTypeStatus.initial,
    this.loginStatus = LoginStatus.initial,
    this.getLeaveTypeModel,
    this.loginModel,
    this.firebaseUid,
    this.firebaseEmail,
    this.userName,
    this.userCode,
    this.isAdmin = false,
    this.isSupervisor = false,
    this.error,
    this.mapLoadStatus = MapLoadStatus.initial, // default
  });

  AuthState copyWith({
    GetLeavesTypeStatus? getLeavesTypeStatus,
    LoginStatus? loginStatus,
    GetLeaveTypeModel? getLeaveTypeModel,
    LoginModel? loginModel,
    String? firebaseUid,
    String? firebaseEmail,
    String? userName,
    String? userCode,
    bool? isAdmin,
    bool? isSupervisor,
    String? error,
    MapLoadStatus? mapLoadStatus,
  }) {
    return AuthState(
      getLeavesTypeStatus: getLeavesTypeStatus ?? this.getLeavesTypeStatus,
      loginStatus: loginStatus ?? this.loginStatus,
      getLeaveTypeModel: getLeaveTypeModel ?? this.getLeaveTypeModel,
      loginModel: loginModel ?? this.loginModel,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      firebaseEmail: firebaseEmail ?? this.firebaseEmail,
      userName: userName ?? this.userName,
      userCode: userCode ?? this.userCode,
      isAdmin: isAdmin ?? this.isAdmin,
      isSupervisor: isSupervisor ?? this.isSupervisor,
      error: error,
      mapLoadStatus: mapLoadStatus ?? this.mapLoadStatus,
    );
  }

  // 🔥 optional helper getters
  bool get isMapAlmostReady => mapLoadStatus == MapLoadStatus.almostReady;
  bool get isMapReady => mapLoadStatus == MapLoadStatus.ready;

  @override
  List<Object?> get props => [
        getLeavesTypeStatus,
        loginStatus,
        getLeaveTypeModel,
        loginModel,
        firebaseUid,
        firebaseEmail,
        userName,
        userCode,
        isAdmin,
        isSupervisor,
        error,
        mapLoadStatus,
      ];
}


