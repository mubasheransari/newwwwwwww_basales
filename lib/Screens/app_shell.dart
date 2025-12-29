import 'package:flutter/material.dart';
import 'package:new_amst_flutter/Screens/home_screen.dart';
import 'package:new_amst_flutter/Screens/profile_screen.dart' show ProfilePage;
import 'package:new_amst_flutter/Screens/tabbar_screen_history.dart';
import '../Widgets/bottom_bar.dart';



class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _visibleTabs = <BottomTab>[
    BottomTab.home,
    BottomTab.reports,
    BottomTab.profile,
  ];

  BottomTab _tab = BottomTab.home;

  final Map<BottomTab, GlobalKey<NavigatorState>> _navKeys = {
    BottomTab.home: GlobalKey<NavigatorState>(),
    BottomTab.reports: GlobalKey<NavigatorState>(),
    BottomTab.profile: GlobalKey<NavigatorState>(),
  };

  int get _stackIndex {
    final i = _visibleTabs.indexOf(_tab);
    return i >= 0 ? i : 0; // coerce map/about to home
  }

  @override
  void initState() {
    super.initState();
    if (!_visibleTabs.contains(_tab)) _tab = BottomTab.home;
  }

  Future<bool> _onWillPop() async {
    final nav = _navKeys[_visibleTabs[_stackIndex]]!.currentState!;
    if (nav.canPop()) {
      nav.pop();
      return false;
    }
    if (_tab != BottomTab.home) {
      setState(() => _tab = BottomTab.home);
      return false;
    }
    return true;
  }

  void _setTab(BottomTab t) =>
      setState(() => _tab = _visibleTabs.contains(t) ? t : BottomTab.home);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: IndexedStack(
          index: _stackIndex,
          children: [
            _TabNavigator(navKey: _navKeys[BottomTab.home]!,    initial: const HomeScreen()),
            _TabNavigator(navKey: _navKeys[BottomTab.reports]!, initial: HistoryTabsScreen()), //AttendanceHistoryScreen()),//ReportHistoryScreen()),
            _TabNavigator(navKey: _navKeys[BottomTab.profile]!, initial: const ProfilePage()),
          ],
        ),
        bottomNavigationBar: BottomBar(
          active: _visibleTabs[_stackIndex],
          onChanged: _setTab,
        ),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.navKey, required this.initial});
  final GlobalKey<NavigatorState> navKey;
  final Widget initial;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey, // important: attach the key to Navigator
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (_) => initial, settings: settings),
    );
  }
}

