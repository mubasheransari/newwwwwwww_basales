import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';
import 'package:new_amst_flutter/Bloc/auth_event.dart';
import 'package:new_amst_flutter/Bloc/auth_state.dart';
import 'package:new_amst_flutter/Firebase/firebase_services.dart';
import 'package:new_amst_flutter/Repository/repository.dart';
import 'package:bloc/bloc.dart';



var storage = GetStorage();

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final Repository repo;

  AuthBloc(this.repo) : super(const AuthState()) {
    on<LoginEvent>(_onLogin);

    // 🔥 map load handlers
    on<MapLoadStarted>(_onMapLoadStarted);
    on<MapCreatedEvent>(_onMapCreated);
    on<MapLoadReset>(_onMapLoadReset);

    // If Firebase already has a signed-in user, hydrate state.
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      emit(state.copyWith(
        firebaseUid: u.uid,
        firebaseEmail: u.email,
        userName: u.displayName,
      ));
    }
  }

  /* --------------------------- LOGIN --------------------------- */

  Future<void> _onLogin(LoginEvent e, Emitter<AuthState> emit) async {
    emit(state.copyWith(loginStatus: LoginStatus.loading, error: null));

    try {
      final cred = await Fb.auth.signInWithEmailAndPassword(
        email: e.email.trim(),
        password: e.password.trim(),
      );

      final user = cred.user;
      if (user == null) {
        emit(state.copyWith(
          loginStatus: LoginStatus.failure,
          error: 'Login failed: user not found',
        ));
        return;
      }

      // Load profile from Firestore (includes allowed attendance location)
      final profile = await FbUserRepo.getOrCreateProfile(user: user);

      // ✅ Admin check (single login screen). Admin accounts are stored in
      // Firestore as `admins/{uid}`.
      final isAdmin = await FbAdminRepo.isAdmin(user.uid);

      // ✅ Supervisor check. Supervisor accounts are stored in
      // Firestore as `supervisors/{uid}`.
      final isSupervisor = await FbSupervisorRepo.isSupervisor(user.uid);

      emit(state.copyWith(
        loginStatus: LoginStatus.success,
        firebaseUid: user.uid,
        firebaseEmail: user.email,
        userName: profile.name,
        userCode: profile.empCode,
        isAdmin: isAdmin,
        isSupervisor: isSupervisor,
        error: null,
      ));
    } on FirebaseAuthException catch (ex) {
      emit(state.copyWith(
        loginStatus: LoginStatus.failure,
        error: ex.message ?? ex.code,
      ));
    } catch (err) {
      emit(state.copyWith(
        loginStatus: LoginStatus.failure,
        error: '$err',
      ));
    }
  }

  /* --------------------------- MAP LOAD HANDLERS --------------------------- */

  void _onMapLoadStarted(
    MapLoadStarted event,
    Emitter<AuthState> emit,
  ) {
    // reset map load state
    emit(state.copyWith(mapLoadStatus: MapLoadStatus.initial));
  }

  Future<void> _onMapCreated(
    MapCreatedEvent event,
    Emitter<AuthState> emit,
  ) async {
    // GoogleMap onMapCreated called
    emit(state.copyWith(mapLoadStatus: MapLoadStatus.creating));

    // simulate tiles drawing -> treat this as "90% loaded"
    await Future.delayed(const Duration(milliseconds: 800));
    emit(state.copyWith(mapLoadStatus: MapLoadStatus.almostReady));

    // fully ready
    await Future.delayed(const Duration(milliseconds: 400));
    emit(state.copyWith(mapLoadStatus: MapLoadStatus.ready));
  }

  void _onMapLoadReset(
    MapLoadReset event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(mapLoadStatus: MapLoadStatus.initial));
  }
}
