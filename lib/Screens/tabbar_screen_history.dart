import 'package:flutter/material.dart';
import 'package:new_amst_flutter/Screens/report_history_screen.dart';
import 'attendance_history_screen.dart';

const _kBg = Color(0xFFF6F7FA);

class HistoryTabsScreen extends StatelessWidget {
  const HistoryTabsScreen({super.key});

  static const _grad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _kBg,
          centerTitle: true,
          title: Text(
            'History',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 22 * s,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          automaticallyImplyLeading: true,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(56 * s),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16 * s, 0, 16 * s, 10 * s),
              child: Container(
                height: 46 * s,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: TabBar(
                  padding: const EdgeInsets.all(3),

                  // 🚫 remove black underline / divider
                  dividerColor: Colors
                      .transparent, // <-- this kills the bottom black line
                  indicatorColor: Colors.transparent,
                  indicatorWeight: 0,

                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: _grad,
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF111827),
                  labelStyle: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 13.5 * s,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 13.5 * s,
                    fontWeight: FontWeight.w700,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'Sales History'),
                    Tab(text: 'Attendance History'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          physics: BouncingScrollPhysics(),
          children: [
            ReportHistoryScreen(),
            AttendanceHistoryScreen(),
          ],
        ),
      ),
    );
  }
}
