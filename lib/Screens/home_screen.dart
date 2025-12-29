import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_amst_flutter/Bloc/auth_bloc.dart';
import 'package:new_amst_flutter/Screens/apply_leave_screen.dart';
import 'package:new_amst_flutter/Screens/mark_attendance.dart'
    show MarkAttendanceView;
import 'package:new_amst_flutter/Screens/products.dart';
import 'package:new_amst_flutter/Screens/sales_overview.dart';
import 'package:new_amst_flutter/Widgets/gradient_text.dart';

String formatTitleCase(String text) {
  if (text.isEmpty) return text;
  return text
      .toLowerCase()
      .split(' ')
      .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
      .join(' ');
}

const kBg = Color(0xFFF6F7FA);
const kTxtDim = Color(0xFF6A6F7B);
const kTxtDark = Color(0xFF1F2937);
const kSearchBg = Color(0xFFF0F2F5);
const kIconMuted = Color(0xFF9CA3AF);
const kBikeText = Color(0xFF444B59);

const kGradBluePurple = LinearGradient(
  colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

const kCardCarGrad = LinearGradient(
  colors: [Color(0xFF1CC8FF), Color(0xFF6B63FF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _bg = Color(0xFFF6F7FA);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const baseW = 393.0;
    final s = size.width / baseW;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 100 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(s: s),
                  SizedBox(height: 8 * s),
                  const SalesChartSection(),

                  SizedBox(height: 8 * s),

                  SizedBox(height: 15 * s),
                  MarkAttendanceWidget(s: s),
                  SizedBox(height: 30 * s),
                  SalesWidget(s: s),
                  SizedBox(height: 25 * s),
                  ApplyLeaveWidget(s: s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    final rawName = context.select((AuthBloc b) => b.state.userName) ?? 'User';
    final name = formatTitleCase(rawName);

    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 14 * s,
                color: const Color(0xFF6A6F7B),
                height: 1.2,
              ),
              children: [
                TextSpan(
                  text: 'Good morning,\n',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 18 * s,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: 0.1 * s,
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GradientText(
                    name,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 25 * s,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      letterSpacing: 0.1 * s,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MarkAttendanceWidget extends StatelessWidget {
  const MarkAttendanceWidget({super.key, required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 219 * s,
      width: MediaQuery.of(context).size.width * 0.90,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1CC8FF), Color(0xFF6B63FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9 * s),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B63FF).withOpacity(0.25),
            blurRadius: 20 * s,
            offset: Offset(0, 10 * s),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -29 * s,
            top: 18 * s,
            child: SizedBox(
              width: 205 * s,
              height: 210 * s,
              child: Image.asset(
                'assets/new_attendance_icon-removebg-preview.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mark\nAttendance',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    color: Colors.white,
                    fontSize: 29 * s,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 6 * s),
                Text(
                  'Make sure GPS is on and\nyou’re at the job site.',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 16.5 * s,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 34),
                InkWell(
                  onTap: () {
                    final authBloc = context.read<AuthBloc>();

                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => BlocProvider<AuthBloc>.value(
                          value: authBloc,
                          child: MarkAttendanceView(
                            code: context.read<AuthBloc>().state.userCode ?? '--',
                          ),
                        ),
                      ),
                    );
                  },
                  child: _ChipButtonGradient(
                    s: s,
                    icon: 'assets/attendance_icons.png',
                    label: 'Mark Attendance',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ApplyLeaveWidget extends StatelessWidget {
  const ApplyLeaveWidget({required this.s, super.key});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 219 * s,
      width: MediaQuery.of(context).size.width * 0.90,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9 * s),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F53FD).withOpacity(0.25),
            blurRadius: 20 * s,
            offset: Offset(0, 10 * s),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -29 * s,
            top: 18 * s,
            child: SizedBox(
              width: 225 * s,
              height: 215 * s,
              child: Image.asset(
                'assets/leave_apply_card.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(16 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apply\nLeave',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    color: Colors.white,
                    fontSize: 29 * s,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 6 * s),
                Text(
                  'Choose type, dates and\nadd a short reason.',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 16.5 * s,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 34 * s),
                InkWell(
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => const ApplyLeaveScreenNew(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                  child: _ChipButtonGradient(
                    s: s,
                    icon: 'assets/attendance_icons.png',
                    label: 'Apply Leave',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SalesWidget extends StatelessWidget {
  const SalesWidget({super.key, required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 219 * s,
      width: MediaQuery.of(context).size.width * 0.90,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9 * s),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F53FD).withOpacity(0.25),
            blurRadius: 20 * s,
            offset: Offset(0, 10 * s),
          ),
        ],
      ),

      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -29 * s,
            top: 18 * s,
            child: SizedBox(
              width: 205 * s,
              height: 210 * s,
              child: Image.asset(
                'assets/new_sales-removebg-preview.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientText(
                  'Daily\nSales',
                  gradient: const LinearGradient(
                    colors: [Colors.white, Colors.white],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 29 * s,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 6 * s),
                Text(
                  'Enter daily sales and\n track your sales.',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    color: Colors.white,
                    fontSize: 16.5 * s,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocalTeaCatalogSkuOnly(),
                      ),
                    );
                  },
                  child: _ChipButtonGradient(
                    s: s,
                    label: 'Enter your Sales',
                    icon: 'assets/sales_button_icon.png',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipButtonGradient extends StatelessWidget {
  const _ChipButtonGradient({
    required this.s,
    required this.label,
    required this.icon,
  });
  final double s;
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40 * s,
      padding: EdgeInsets.symmetric(horizontal: 12 * s),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
        ),
        borderRadius: BorderRadius.circular(5 * s),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F53FD).withOpacity(0.25),
            blurRadius: 12 * s,
            offset: Offset(0, 6 * s),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            icon,
            height: 22 * s,
            width: 22 * s,
          ),

          SizedBox(width: 8 * s),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              color: Colors.white,
              fontSize: 16 * s,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
