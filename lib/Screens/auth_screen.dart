import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_amst_flutter/Firebase/firebase_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:new_amst_flutter/Bloc/auth_event.dart';
import 'package:new_amst_flutter/Bloc/auth_state.dart';
import 'package:new_amst_flutter/Repository/repository.dart';
import 'package:new_amst_flutter/Screens/app_shell.dart';
import 'package:new_amst_flutter/Admin/admin_dashboard_screen.dart';
import 'package:new_amst_flutter/Supervisor/home_supervisor_screen.dart';
import 'package:new_amst_flutter/Widgets/custom_Dialogs.dart';
import 'package:new_amst_flutter/Widgets/custom_toast_widget.dart';
import 'package:new_amst_flutter/Widgets/watermarked_widget.dart';
import 'dart:ui' as ui;
import 'package:new_amst_flutter/Bloc/auth_bloc.dart';
import 'dart:math';


class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int tab = 0;
  bool remember = true;

  final _scrollCtrl = ScrollController();
  double _scrollY = 0.0;

  // Device ID (generated once & stored)
  String _deviceId = 'Loading...';
  final box = GetStorage();

  // Form keys
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  // login
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  bool _loginObscure = true;

  // signup
  final _empCodeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _mob1Ctrl = TextEditingController();
  final _mob2Ctrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPassCtrl = TextEditingController();
  final _signupConfirmPassCtrl = TextEditingController();
  String? _signupLocationId;
  final _distCtrl = TextEditingController();
  final _territoryCtrl = TextEditingController();
  String? _channelType;

  bool _signupObscure = true;
  bool _signupConfirmObscure = true;

  // loading flags
  final bool _loginLoading = false; // bloc controls real loading
  bool _signupLoading = false;

  final _repo = Repository();

  static const _hardcodedEmail = '';
static const _hardcodedPassword = '';

  @override
  void initState() {
    super.initState();

    _loginEmailCtrl.text = _hardcodedEmail;
  _loginPassCtrl.text = _hardcodedPassword;
    _scrollCtrl.addListener(() {
      if (!_scrollCtrl.hasClients) return;
      if (tab != 1) return;
      final off = _scrollCtrl.offset;
      if (off != _scrollY) {
        setState(() => _scrollY = off);
      }
    });
    _initDeviceId();
  }

  Future<void> _initDeviceId() async {

    final existing = box.read<String>('device_id');

    if (existing != null && existing.isNotEmpty) {
      setState(() => _deviceId = existing);
      return;
    }

    // Generate 8 random bytes → 16 hex characters
    final rand = Random.secure();
    final bytes = List<int>.generate(8, (_) => rand.nextInt(256));
    final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    print("DEVICE ID INFO $id");
    print("DEVICE ID INFO $id");

    print("DEVICE ID INFO $id");
    print("DEVICE ID INFO $id");
    print("DEVICE ID INFO $id");

    await box.write('device_id', id);

    if (!mounted) return;
    setState(() => _deviceId = id);
  }



  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _empCodeCtrl.dispose();
    _nameCtrl.dispose();
    _cnicCtrl.dispose();
    _addressCtrl.dispose();
    _mob1Ctrl.dispose();
    _mob2Ctrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPassCtrl.dispose();
    _signupConfirmPassCtrl.dispose();
    _distCtrl.dispose();
    _territoryCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ----------------- validators (same as before) -----------------
  String? _validateLoginEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Enter a valid email';
  }

  String? _validateSignupEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Enter a valid email';
  }

  String? _validateLoginPassword(String? v) {
    if ((v ?? '').isEmpty) return 'Password is required';
    if (v!.length < 2) return 'Use at least 6 characters';
    return null;
  }

  String? _validateSignupPassword(String? v) {
    if ((v ?? '').isEmpty) return 'Password is required';
    if (v!.length < 2) return 'Use at least 8 characters';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Confirm password is required';
    if (s != _signupPassCtrl.text.trim()) return 'Passwords do not match';
    return null;
  }

  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Name is required';
    if (s.length < 2) return 'Enter a valid name';
    return null;
  }

  String? _req(String? v) {
    if ((v ?? '').trim().isEmpty) return 'This field is required';
    return null;
  }

  String? _cnic(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'CNIC is required';
    if (digits.length != 13) return 'Enter 13 digits';
    return null;
  }

  String? _pkMobile(String? v, {bool required = true}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return required ? 'Mobile is required' : null;
    final ok = RegExp(r'^(03\d{9}|92\d{10})$').hasMatch(s);
    return ok ? null : 'Use 03XXXXXXXXX or 92XXXXXXXXXX';
  }
Future<void> _submitLogin() async {
  final form = _loginFormKey.currentState;
  if (form == null) return;

  FocusScope.of(context).unfocus();

  // Validate form first (if you want validation even for hardcoded)
  if (!form.validate()) {
    return;
  }

  final email = _loginEmailCtrl.text.trim();
  final password = _loginPassCtrl.text.trim();

  // ✅ Hardcoded supervisor login
  if (email == "supervisor@gmail.com" && password == "123") {
         box.write("supervisor_loggedIn","1");
  
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JourneyPlanMapScreen(),
      ),
    );
    return; // ⬅️ important: don’t call API after this
  }

  // ✅ Normal login (API / Bloc)
  context.read<AuthBloc>().add(
        LoginEvent(email, password),
      );
}

//   Future<void> _submitLogin() async {
//     final form = _loginFormKey.currentState;
//     if (form == null) return;

//     FocusScope.of(context).unfocus(); 

//     if (!form.validate()) {
//       return;
//     }
//     if(_loginEmailCtrl.text.trim() == "testsupervisor@gmail.com" && _loginPassCtrl.text.trim()== "Testing@123"){
// Navigator.push(context, MaterialPageRoute(builder: (context)=> JourneyPlanMapScreen()));
//     }
//     context.read<AuthBloc>().add(
//       LoginEvent(_loginEmailCtrl.text.trim(), _loginPassCtrl.text),
//     );
//   }

  Future<void> _submitSignup() async {
    final form = _signupFormKey.currentState;
    if (form == null) return;

    FocusScope.of(context).unfocus();

    if (!form.validate()) return;

    final pass = _signupPassCtrl.text;
    final confirm = _signupConfirmPassCtrl.text;
    if (pass != confirm) {
      showAppToast(
        context,
        'Password and Confirm Password must match',
        type: ToastType.error,
      );
      return;
    }

    if (_signupLocationId == null) {
      showAppToast(
        context,
        'Please select a location',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _signupLoading = true);
    try {
      // 1) Create Firebase Auth user
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _signupEmailCtrl.text.trim(),
        password: pass,
      );

      final user = cred.user;
      if (user == null) {
        throw Exception('Signup failed: user is null');
      }

      await user.updateDisplayName(_nameCtrl.text.trim());

      // 2) Read chosen master location
      final locDoc = await Fb.db.collection('locations').doc(_signupLocationId).get();
      if (!locDoc.exists) {
        throw Exception('Selected location no longer exists. Ask admin to re-add it.');
      }
      final loc = FbLocation.fromDoc(locDoc.id, locDoc.data()!);

      // 3) Save user profile with locked attendance coordinates
      await Fb.db.collection('users').doc(user.uid).set({
        'email': _signupEmailCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'cnic': _cnicCtrl.text.trim(),
        'empCode': _signupEmailCtrl.text.trim(),
        'locationId': loc.id,
        'locationName': loc.name,
        'allowedLocation': GeoPoint(loc.lat, loc.lng),
        'allowedRadiusMeters': loc.radiusMeters,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await showAccountCreatedDialog(context);

      // Switch to login tab
      if (!mounted) return;
      setState(() {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(0);
        }
        tab = 0;
        _scrollY = 0;
      });
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? e.code;
      showAppToast(context, msg, type: ToastType.error);
    } catch (e) {
      showAppToast(context, 'Signup failed: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _signupLoading = false);
    }
  }

  void _copyDeviceId(BuildContext context) {
    if (_deviceId.isEmpty || _deviceId == 'Loading...') return;
    Clipboard.setData(ClipboardData(text: _deviceId));
    print("Device ID copied");
    print("Device ID copied");
    print("Device ID copied");
    //   showToast(context, 'Device ID copied', success: true);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final double baseTop = tab == 0 ? 23.0 : 0.0;
    final double logoTop = tab == 1 ? (baseTop - _scrollY) : baseTop;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: Stack(
        children: [
          const WatermarkTiledSmall(tileScale: 25.0),

          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width < 380 ? 16 : 22,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        controller: _scrollCtrl,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // space for logo
                            const SizedBox(height: 150),

                            _AuthToggle(
                              activeIndex: tab,
                              onChanged: (i) {
                                FocusScope.of(
                                  context,
                                ).unfocus(); // close keyboard
                                _loginFormKey.currentState?.reset();
                                _signupFormKey.currentState?.reset();
                                if (_scrollCtrl.hasClients) {
                                  _scrollCtrl.jumpTo(0);
                                }
                                setState(() {
                                  tab = i;
                                  _scrollY = 0;
                                });
                              },
                            ),
                            const SizedBox(height: 18),

                            // ------------- LOGIN -------------
                            if (tab == 0)
                              Form(
                                key: _loginFormKey,
                                autovalidateMode: AutovalidateMode.disabled,
                                child: Column(
                                  children: [
                                    _InputCard(
                                      fieldKey: const ValueKey('login_email'),
                                      hint: 'Email',
                                      icon: 'assets/email_icon.png',
                                      controller: _loginEmailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: _validateLoginEmail,
                                    ),
                                    const SizedBox(height: 12),
                                    _InputCard(
                                      fieldKey: const ValueKey(
                                        'login_password',
                                      ),
                                      hint: 'Password',
                                      icon: 'assets/password_icon.png',
                                      controller: _loginPassCtrl,
                                      obscureText: _loginObscure,
                                      onToggleObscure: () => setState(
                                        () => _loginObscure = !_loginObscure,
                                      ),
                                      validator: _validateLoginPassword,
                                    ),
                                    const SizedBox(height: 7),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () {},
                                          child: const Text(
                                            'Forgot password',
                                            style: TextStyle(
                                              fontFamily: 'ClashGrotesk',
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      width: 160,
                                      height: 40,
                                      child: BlocConsumer<AuthBloc, AuthState>(
                                        listener: (context, state) {
                                          if (state.loginStatus ==
                                              LoginStatus.success) {
                                            final target = state.isAdmin
                                                ? AdminDashboardScreen()
                                                : state.isSupervisor
                                                    ? const JourneyPlanMapScreen()
                                                    : const AppShell();

                                            // persist session
                                            final box = GetStorage();
                                            if (state.isSupervisor) {
                                              box.write('supervisor_loggedIn', true);
                                              box.remove('loggedIn');
                                            } else {
                                              box.write('loggedIn', true);
                                              box.remove('supervisor_loggedIn');
                                            }

                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(builder: (_) => target),
                                              (route) => false,
                                            );
                                          } else if (state.loginStatus ==
                                              LoginStatus.failure) {
                                            showAppToast(
                                              context,
                                              "Invalid Credentials!",
                                              type: ToastType.error,
                                            );
                                          }
                                        },
                                        builder: (context, state) {
                                          final loading =
                                              state.loginStatus ==
                                                  LoginStatus.loading ||
                                              _loginLoading;
                                          return _PrimaryGradientButton(
                                            text: loading
                                                ? 'PLEASE WAIT...'
                                                : 'LOGIN',
                                            onPressed: loading
                                                ? null
                                                : _submitLogin,
                                            loading: loading,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _FooterSwitch(
                                      prompt: "Don’t have an account? ",
                                      action: "Create an account",
                                      onTap: () => setState(() {
                                        if (_scrollCtrl.hasClients) {
                                          _scrollCtrl.jumpTo(0);
                                        }
                                        tab = 1;
                                        _scrollY = 0;
                                      }),
                                    ),
                                  ],
                                ),
                              ),

                            // ------------- SIGNUP -------------
                            if (tab == 1)
                              Form(
                                key: _signupFormKey,
                                autovalidateMode: AutovalidateMode.disabled,
                                child: Column(
                                  children: [
                                    _InputCard(
                                      fieldKey: const ValueKey('signup_name'),
                                      hint: 'Name',
                                      icon: 'assets/name_icon.png',
                                      controller: _nameCtrl,
                                      validator: _validateName,
                                    ),
                                    const SizedBox(height: 12),

                                    _InputCard(
                                      fieldKey: const ValueKey('signup_email'),
                                      hint: 'Email',
                                      icon: 'assets/email_icon.png',
                                      controller: _signupEmailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: _validateSignupEmail,
                                    ),
                                    const SizedBox(height: 12),

                                    _CnicField(
                                      controller: _cnicCtrl,
                                      validator: _cnic,
                                    ),
                                    const SizedBox(height: 12),

                                    // ✅ Location dropdown (from /locations collection)
                                    Container(
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.06),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            height: 32,
                                            width: 32,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF2F3F5),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.location_on_rounded,
                                              size: 18,
                                              color: Color(0xFF1B1B1B),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: StreamBuilder<List<FbLocation>>(
                                              stream: FbLocationRepo.watchLocations(),
                                              builder: (context, snap) {
                                                final list = snap.data ?? const <FbLocation>[];

                                                return DropdownButtonFormField<String>(
                                                  value: _signupLocationId,
                                                  isExpanded: true,
                                                  alignment: Alignment.centerLeft,
                                                  style: const TextStyle(
                                                    fontFamily: 'ClashGrotesk',
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black,
                                                    letterSpacing: 0.3,
                                                  ),
                                                  decoration: const InputDecoration(
                                                    border: InputBorder.none,
                                                    isCollapsed: true,
                                                    contentPadding: EdgeInsets.only(top: 15),
                                                    hintText: 'Select Location',
                                                    hintStyle: TextStyle(
                                                      fontFamily: 'ClashGrotesk',
                                                      color: Colors.black54,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                  icon: const Padding(
                                                    padding: EdgeInsets.only(top: 14.0),
                                                    child: Icon(Icons.expand_more_rounded, size: 29),
                                                  ),
                                                  borderRadius: BorderRadius.circular(14),
                                                  dropdownColor: Colors.white,
                                                  menuMaxHeight: 320,
                                                  items: list
                                                      .map(
                                                        (l) => DropdownMenuItem<String>(
                                                          value: l.id,
                                                          alignment: Alignment.centerLeft,
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(vertical: 3),
                                                            child: Text(
                                                              l.name,
                                                              style: const TextStyle(
                                                                fontFamily: 'ClashGrotesk',
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w600,
                                                                letterSpacing: 0.3,
                                                                color: Colors.black,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: _signupLoading
                                                      ? null
                                                      : (v) => setState(() => _signupLocationId = v),
                                                  validator: (v) => (v == null || v.isEmpty) ? 'Please select' : null,
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    _InputCard(
                                      fieldKey: const ValueKey('signup_password'),
                                      hint: 'Password',
                                      icon: 'assets/password_icon.png',
                                      controller: _signupPassCtrl,
                                      obscureText: _signupObscure,
                                      onToggleObscure: () => setState(
                                        () => _signupObscure = !_signupObscure,
                                      ),
                                      validator: _validateSignupPassword,
                                    ),
                                    const SizedBox(height: 12),

                                    _InputCard(
                                      fieldKey: const ValueKey('signup_confirm_password'),
                                      hint: 'Confirm Password',
                                      icon: 'assets/password_icon.png',
                                      controller: _signupConfirmPassCtrl,
                                      obscureText: _signupConfirmObscure,
                                      onToggleObscure: () => setState(
                                        () => _signupConfirmObscure = !_signupConfirmObscure,
                                      ),
                                      validator: (v) {
                                        final x = (v ?? '').trim();
                                        if (x.isEmpty) return 'Required';
                                        if (x != _signupPassCtrl.text.trim()) return 'Passwords do not match';
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 20),

                                    SizedBox(
                                      width: 160,
                                      height: 40,
                                      child: _PrimaryGradientButton(
                                        text: _signupLoading
                                            ? 'PLEASE WAIT...'
                                            : 'SIGNUP',
                                        onPressed: _signupLoading
                                            ? null
                                            : _submitSignup,
                                        loading: _signupLoading,
                                      ),
                                    ),
                                    const SizedBox(height: 18),

                                    _FooterSwitch(
                                      prompt: "Already have an account? ",
                                      action: "Login",
                                      onTap: () => setState(() {
                                        if (_scrollCtrl.hasClients) {
                                          _scrollCtrl.jumpTo(0);
                                        }
                                        tab = 0;
                                        _scrollY = 0;
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Device ID pill - top right
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => _copyDeviceId(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.68),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.30),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.smartphone_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _deviceId,
                        style: const TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 11,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // logo (unchanged)
          Positioned(
            top: logoTop,
            left: 60,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Image.asset(
                  "assets/logo_ams.png",
                  height: 270,
                  width: 270,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------- UI bits you already had ----------------- */

class _AuthToggle extends StatelessWidget {
  const _AuthToggle({required this.activeIndex, required this.onChanged});
  final int activeIndex;
  final ValueChanged<int> onChanged;

  static const _grad = LinearGradient(
    colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              height: 44,
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                gradient: activeIndex == 0 ? _grad : null,
                borderRadius: BorderRadius.circular(22),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onChanged(0),
                child: Center(
                  child: Text(
                    'Login',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: activeIndex == 0
                          ? Colors.white
                          : const Color(0xFF0AA2FF),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedContainer(
              height: 44,
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                gradient: activeIndex == 1 ? _grad : null,
                borderRadius: BorderRadius.circular(22),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onChanged(1),
                child: Center(
                  child: Text(
                    'SignUp',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: activeIndex == 1
                          ? Colors.white
                          : const Color(0xFF0AA2FF),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.hint,
    required this.icon,
    this.controller,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.onToggleObscure,
    this.fieldKey,
  });

  final String hint;
  final String icon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Image.asset(
            icon,
            height: 17,
            width: 17,
            color: const Color(0xFF1B1B1B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              key: fieldKey,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
              controller: controller,
              keyboardType: keyboardType,
              validator: validator,
              obscureText: obscureText,
              decoration: const InputDecoration(
                hintText: '',
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  color: Colors.black54,
                  fontSize: 16,
                ),
              ).copyWith(hintText: hint),
            ),
          ),
          if (onToggleObscure != null)
            IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: const Color(0xFF1B1B1B),
              ),
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _FooterSwitch extends StatelessWidget {
  const _FooterSwitch({
    required this.prompt,
    required this.action,
    required this.onTap,
  });
  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: const TextStyle(
            fontFamily: 'ClashGrotesk',
            fontSize: 14.5,
            color: Color(0xFF1B1B1B),
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5,
              color: Color(0xFF1E9BFF),
              decoration: TextDecoration.underline,
              decorationThickness: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/* ----------------- Special Fields ----------------- */

class _CnicField extends StatelessWidget {
  const _CnicField({required this.controller, required this.validator});
  final TextEditingController controller;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Image.asset(
            'assets/name_icon.png',
            height: 17,
            width: 17,
            color: const Color(0xFF1B1B1B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              key: const ValueKey('signup_cnic'),
              controller: controller,
              textAlign: TextAlign.start,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
                _CnicInputFormatter(),
              ],
              validator: validator,
              decoration: const InputDecoration(
                hintText: 'Employee CNIC',
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Text(
              '4xxxx-xxxxxxx-x',
              style: TextStyle(
                color: Color(0xFF3B97A6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PkMobileField extends StatelessWidget {
  const _PkMobileField({
    required this.hint,
    required this.controller,
    required this.validator,
  });
  final String hint;
  final TextEditingController controller;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Image.asset(
            'assets/name_icon.png',
            height: 17,
            width: 17,
            color: const Color(0xFF1B1B1B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
              controller: controller,
              validator: validator,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  color: Colors.black54,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Text(
              '92XXXXXXXXXX',
              style: TextStyle(
                color: Color(0xFF3B97A6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------- Formatters ----------------- */

class _CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 13; i++) {
      buf.write(digits[i]);
      if (i == 4 || i == 11) buf.write('-');
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  static const _grad = LinearGradient(
    colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;

    return Opacity(
      opacity: disabled ? 0.8 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: _grad,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F53FD).withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: disabled ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
