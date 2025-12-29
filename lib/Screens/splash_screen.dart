import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';
import 'package:new_amst_flutter/Bloc/auth_bloc.dart' show AuthBloc;
import 'package:new_amst_flutter/Screens/auth_screen.dart';
import 'package:new_amst_flutter/Screens/app_shell.dart';
import 'package:new_amst_flutter/Admin/admin_dashboard_screen.dart';
import 'package:new_amst_flutter/Firebase/firebase_services.dart';
import 'package:new_amst_flutter/Widgets/watermarked_widget.dart';
import 'package:new_amst_flutter/Supervisor/home_supervisor_screen.dart';
import 'package:new_amst_flutter/Screens/location_select_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _logoPath = 'assets/ams_logo_underline.png';
  @override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // small delay for splash
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final box = GetStorage();

    // ✅ Firebase session
    final user = FirebaseAuth.instance.currentUser;
    final bool hasSession = user != null;

    // 🔹 Read supervisor flag (might be int/bool/string, so normalize)
    final supervisorLoggedIn = box.read("supervisor_loggedIn")?.toString() ?? "0";
    print("SUPERVISOR $supervisorLoggedIn");

    // 🔹 Get the bloc BEFORE navigation, using the current context
    final authBloc = context.read<AuthBloc>();

    // ✅ Decide target before navigation (builder cannot be async)
    Widget target;
    if (!hasSession && supervisorLoggedIn != "1") {
      target = const AuthScreen();
    } else if (supervisorLoggedIn == "1") {
      target = JourneyPlanMapScreen();
    } else {
      final isAdmin = await FbAdminRepo.isAdmin(user!.uid);
      if (isAdmin) {
        target = AdminDashboardScreen();
      } else {
        final isSupervisor = await FbSupervisorRepo.isSupervisor(user.uid);
        if (isSupervisor) {
          target = JourneyPlanMapScreen();
        } else {

        // Ensure the user has selected a location before using attendance.
        final profile = await FbUserRepo.getOrCreateProfile(user: user!);
        final locationId = profile.locationId;
        final hasValidGeoPoint =
            (profile.allowedLat != 0 || profile.allowedLng != 0);

        target = (locationId == null || !hasValidGeoPoint)
            ? const LocationSelectScreen()
            : const AppShell();
        }

      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: target,
        ),
      ),
    );
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: const [
          // watermark background
          WatermarkTiledSmall(tileScale: 25.0),

          // centered-ish logo
          Positioned(
            top: 350,
            left: 58,
            child: _SplashLogo(),
          ),
        ],
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  static const _logoPath = 'assets/ams_logo_underline.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _logoPath,
      width: 320,
      height: 160,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
