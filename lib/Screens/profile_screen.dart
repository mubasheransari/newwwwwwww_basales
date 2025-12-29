import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_amst_flutter/Bloc/auth_bloc.dart';
import 'package:new_amst_flutter/Data/token_store.dart';
import 'package:new_amst_flutter/Screens/auth_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _bg = Color(0xFFF6F7FB);
  static const _title = Color(0xFF111111);
  static const _sub = Color(0xFF7D8790);
  static const _divider = Color(0xFFE9ECF2);

  static const _gradHeader = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const _chipGrad = LinearGradient(
    colors: [Color(0xFF73D1FF), Color(0xFF6A7CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  String _formatTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .toLowerCase()
        .split(' ')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size.width / 390.0;

    final code = context.select((AuthBloc b) => b.state.userCode) ?? '--';
    final empName = _formatTitleCase(
      context.select((AuthBloc b) => b.state.userName) ?? 'User',
    );
    // Optional fields are not available in Firebase version (keep blanks)
    final empFName = '';
    final desName = '';
    final desCode = '';
    final depName = '';
    final phone = '';
    final phone2 = '';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 24 * s),
          children: [
            // ===== Title =====
            SizedBox(
              height: 44 * s,
              child: Center(
                child: Text(
                  'Profile',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 24 * s,
                    fontWeight: FontWeight.w700,
                    color: _title,
                  ),
                ),
              ),
            ),
            SizedBox(height: 14 * s),

            // ===== Gradient Header Card (no avatar, no edit) =====
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16 * s),
              decoration: BoxDecoration(
                gradient: _gradHeader,
                borderRadius: BorderRadius.circular(18 * s),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7F53FD).withOpacity(0.22),
                    blurRadius: 18 * s,
                    offset: Offset(0, 10 * s),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    empName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 22 * s,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 6 * s),

                  // Designation + department
                  if (desName.isNotEmpty)
                    Text(
                      desCode.isNotEmpty ? '$desName  •  $desCode' : desName,
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 14.5 * s,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ),
                  if (depName.isNotEmpty) SizedBox(height: 2 * s),
                  if (depName.isNotEmpty)
                    Text(
                      depName.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 13.5 * s,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.90),
                      ),
                    ),

                  SizedBox(height: 14 * s),

                  Wrap(
                    spacing: 10 * s,
                    runSpacing: 8 * s,
                    children: [
                      _pill(
                        s: s,
                        icon: Icons.badge_rounded,
                        label: 'Employee Code',
                        value: code,
                      ),
                      if (empFName.isNotEmpty)
                        _pill(
                          s: s,
                          icon: Icons.person_outline_rounded,
                          label: 'Father Name',
                          value: empFName,
                        ),
                      if (phone.isNotEmpty)
                        _pill(
                          s: s,
                          icon: Icons.phone_rounded,
                          label: 'Phone',
                          value: phone,
                        ),
                      if (phone2.isNotEmpty)
                        _pill(
                          s: s,
                          icon: Icons.phone_android_rounded,
                          label: 'Alternate',
                          value: phone2,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 18 * s),
            _dividerLine(s),

            // ===== Menu rows =====
            // InkWell(
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => LeaveTypeDebugPage(),
            //       ),
            //     );
            //   },
            //   child: _menuRow(
            //     s: s,
            //     icon: Icons.receipt_long_outlined,
            //     label: 'Recent Report',
            //   ),
            // ),
            // _dividerLine(s),
            // _menuRow(
            //   s: s,
            //   icon: Icons.add_location_alt_outlined,
            //   label: 'Location',
            // ),
            _dividerLine(s),

            // Logout row (gradient icon)
            InkWell(
              onTap: () async {
                // Firebase logout
                await FirebaseAuth.instance.signOut();
                await TokenStore().clear();
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              },
              child: _menuRow(s: s, label: 'Log out', gradientIcon: true),
            ),
            _dividerLine(s),
          ],
        ),
      ),
    );
  }

  // ===== Helpers =====

  static Widget _dividerLine(double s) => Container(height: 1, color: _divider);

  static Widget _menuRow({
    required double s,
    String label = '',
    IconData? icon,
    bool gradientIcon = false,
  }) {
    final leftIcon = gradientIcon
        ? Container(
            width: 24 * s,
            height: 24 * s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: _chipGrad,
            ),
            child: Icon(
              Icons.logout_rounded,
              size: 14 * s,
              color: Colors.white,
            ),
          )
        : Icon(icon, size: 22 * s, color: _title);

    return SizedBox(
      height: 58 * s,
      child: Row(
        children: [
          leftIcon,
          SizedBox(width: 14 * s),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 16 * s,
                fontWeight: FontWeight.w600,
                color: _title,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 22 * s,
            color: Colors.black.withOpacity(.75),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required double s,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.40), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14 * s, color: Colors.white),
          SizedBox(width: 6 * s),
          Text(
            '$label: ',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 14.5 * s,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 11.5 * s,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

