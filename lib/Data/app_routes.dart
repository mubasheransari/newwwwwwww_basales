// // app_routes.dart
// import 'package:flutter/material.dart';
// import 'package:new_amst_flutter/Screens/home_screen.dart';
// import 'package:new_amst_flutter/Screens/report_history_screen.dart';



// class AppRoutes {
//   static const home    = '/';
//   static const reports = '/reports';
//   static const map     = '/map';
//   static const about   = '/about';
//   static const profile = '/profile';

//   static Route<dynamic> onGenerateRoute(RouteSettings settings) {
//     switch (settings.name) {
//       case reports:
//         return _page(const ReportHistoryScreen());
//       case map:
//         return _page(const ReportHistoryScreen());
//       case profile:
//         return _page(const ReportHistoryScreen());
//       case home:
//       default:
//         return _page(const InspectionHomePixelPerfect());
//     }
//   }

//   static MaterialPageRoute _page(Widget child) =>
//       MaterialPageRoute(builder: (_) => child, settings: RouteSettings(name: child.runtimeType.toString()));
// }
