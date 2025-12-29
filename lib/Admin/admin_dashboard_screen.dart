import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:new_amst_flutter/Admin/location_management_tab.dart';
import 'package:new_amst_flutter/Admin/supervisor_management_tab.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'journey_plans_tab.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:new_amst_flutter/Admin/location_management_tab.dart';
import 'package:new_amst_flutter/Admin/supervisor_management_tab.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ✅ IMPORTANT: this file contains JourneyPlansManagementTab
import 'journey_plans_tab.dart';

int _createdAtMillis(Map<String, dynamic> data) {
  final v = data['createdAt'];
  if (v is Timestamp) return v.millisecondsSinceEpoch;
  if (v is DateTime) return v.millisecondsSinceEpoch;
  if (v is int) return v;
  if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch ?? 0;
  return 0;
}

/// ✅ Safe time formatter
String _fmtTime(dynamic createdAt) {
  if (createdAt is Timestamp) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate());
  }
  if (createdAt is String) {
    final dt = DateTime.tryParse(createdAt);
    if (dt != null) return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }
  return '--';
}

/// ✅ Extract items list from many possible firestore keys (NO hardcoding values)
List<Map<String, dynamic>> _extractOrderItems(Map<String, dynamic> data) {
  final raw = data['items'] ?? data['lines'] ?? data['products'] ?? [];
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const [];
}

/// ✅ Extract qty safely
int _qtyOf(Map<String, dynamic> item) {
  final v = item['qty'] ?? item['quantity'] ?? item['q'] ?? 0;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// ✅ Extract product name safely
String _nameOf(Map<String, dynamic> item) {
  final v = item['name'] ?? item['title'] ?? item['productName'] ?? '';
  return (v ?? '').toString();
}

/// ✅ Extract SKU safely
String _skuOf(Map<String, dynamic> item) {
  final v = item['sku'] ??
      item['skuNo'] ??
      item['number'] ??
      item['code'] ??
      item['skuNumber'] ??
      '';
  return (v ?? '').toString();
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _index = 0;

  final _items = const [
    _AdminNavItem('Locations', Icons.location_on_outlined),
    _AdminNavItem('Supervisors', Icons.supervisor_account_outlined),
    _AdminNavItem('Attendance', Icons.access_time),
    _AdminNavItem('Sales', Icons.shopping_cart_outlined),
    _AdminNavItem('Journey Plans', Icons.map_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final title = _items[_index].label;

    Widget body;
    switch (_index) {
      case 0:
        body = const LocationManagementTab();
        break;
      case 1:
        body = const SupervisorManagementTab();
        break;
      case 2:
        body = const AttendanceTabBlink();
        break;
      case 3:
        body = const SalesTabBlink();
        break;
      case 4:
        // ✅ FIX: JourneyPlansTab doesn't exist, your class is JourneyPlansManagementTab
        body = const JourneyPlansManagementTab();
        break;
      default:
        body = const LocationManagementTab();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.admin_panel_settings),
                title: Text('Admin Panel'),
                subtitle: Text('Manage locations, supervisors, attendance & sales'),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final it = _items[i];
                    final selected = i == _index;
                    return ListTile(
                      leading: Icon(it.icon),
                      title: Text(it.label),
                      selected: selected,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _index = i);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: body,
    );
  }
}

class _AdminNavItem {
  final String label;
  final IconData icon;
  const _AdminNavItem(this.label, this.icon);
}

// ============================ ATTENDANCE TAB (BLINK) =============================

class AttendanceTabBlink extends StatefulWidget {
  const AttendanceTabBlink({super.key});

  @override
  State<AttendanceTabBlink> createState() => _AttendanceTabBlinkState();
}

class _AttendanceTabBlinkState extends State<AttendanceTabBlink> {
  final Set<String> _known = {};
  final Set<String> _blink = {};

  void _detectNew(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final currentIds = docs.map((d) => d.id).toSet();

    if (_known.isEmpty) {
      _known.addAll(currentIds);
      return;
    }

    final newOnes = currentIds.difference(_known);
    if (newOnes.isNotEmpty) {
      _blink.addAll(newOnes);
      _known.addAll(newOnes);

      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() => _blink.removeAll(newOnes));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance.collection('users').snapshots();

    final attendanceStream =
        FirebaseFirestore.instance.collectionGroup('attendance').limit(300).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: usersStream,
      builder: (context, usersSnap) {
        final Map<String, String> uidToName = {};
        if (usersSnap.hasData) {
          for (final d in usersSnap.data!.docs) {
            final name = (d.data()['name'] ?? '').toString();
            if (name.isNotEmpty) uidToName[d.id] = name;
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: attendanceStream,
          builder: (context, snap) {
            if (snap.hasError) return _ErrorBox(message: snap.error.toString());
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

            final docs = [...snap.data!.docs];
            docs.sort(
              (a, b) => _createdAtMillis(b.data()).compareTo(_createdAtMillis(a.data())),
            );

            _detectNew(docs);

            if (docs.isEmpty) {
              return const Center(child: Text('No attendance records found.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final d = docs[i];
                final data = d.data();

                final uid = d.reference.parent.parent?.id ?? 'unknown';
                final userName = uidToName[uid] ?? uid;

                final action = (data['action'] ?? '').toString();
                final dist = (data['distanceMeters'] as num?)?.toDouble();
                final within = (data['withinAllowed'] as bool?) ?? false;
                final lat = (data['lat'] as num?)?.toDouble();
                final lng = (data['lng'] as num?)?.toDouble();

                final timeStr = _fmtTime(data['createdAt']);
                final shouldBlink = _blink.contains(d.id);

                return _BlinkCard(
                  blink: shouldBlink,
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      title: Text(
                        '$userName • $action',
                        style: const TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Time: $timeStr\n'
                          'Distance: ${dist?.toStringAsFixed(1) ?? '--'} m (${within ? 'Allowed' : 'Blocked'})\n'
                          'Lat/Lng: ${lat?.toStringAsFixed(6) ?? '--'}, ${lng?.toStringAsFixed(6) ?? '--'}',
                          style: const TextStyle(
                            fontFamily: 'ClashGrotesk',
                            color: Colors.black87,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ============================ SALES TAB (BLINK) =============================

class SalesTabBlink extends StatefulWidget {
  const SalesTabBlink({super.key});

  @override
  State<SalesTabBlink> createState() => _SalesTabBlinkState();
}

class _SalesTabBlinkState extends State<SalesTabBlink> {
  final Set<String> _known = {};
  final Set<String> _blink = {};

  void _detectNew(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final currentIds = docs.map((d) => d.id).toSet();

    if (_known.isEmpty) {
      _known.addAll(currentIds);
      return;
    }

    final newOnes = currentIds.difference(_known);
    if (newOnes.isNotEmpty) {
      _blink.addAll(newOnes);
      _known.addAll(newOnes);

      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() => _blink.removeAll(newOnes));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance.collection('users').snapshots();
    final salesStream =
        FirebaseFirestore.instance.collectionGroup('sales').limit(300).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: usersStream,
      builder: (context, usersSnap) {
        final Map<String, String> uidToName = {};
        if (usersSnap.hasData) {
          for (final d in usersSnap.data!.docs) {
            final name = (d.data()['name'] ?? '').toString();
            if (name.isNotEmpty) uidToName[d.id] = name;
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: salesStream,
          builder: (context, snap) {
            if (snap.hasError) return _ErrorBox(message: snap.error.toString());
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

            final docs = [...snap.data!.docs];
            docs.sort(
              (a, b) => _createdAtMillis(b.data()).compareTo(_createdAtMillis(a.data())),
            );

            _detectNew(docs);

            if (docs.isEmpty) {
              return const Center(child: Text('No sales records found.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final d = docs[i];
                final data = d.data();

                final uid = d.reference.parent.parent?.id ?? 'unknown';
                final userName = uidToName[uid] ?? uid;

                final timeStr = _fmtTime(data['createdAt']);
                final total = (data['total'] ?? data['grandTotal'] ?? data['amount']);

                final items = _extractOrderItems(data);
                final skuCount = items.length;
                final totalQty = items.fold<int>(0, (sum, it) => sum + _qtyOf(it));

                final shouldBlink = _blink.contains(d.id);

                return _BlinkCard(
                  blink: shouldBlink,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        title: Text(
                          '$userName • Sale',
                          style: const TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Time: $timeStr\n'
                            'SKUs: $skuCount  •  Qty: $totalQty\n'
                            'Total: ${total ?? '--'}',
                            style: const TextStyle(
                              fontFamily: 'ClashGrotesk',
                              color: Colors.black87,
                              height: 1.25,
                            ),
                          ),
                        ),
                        children: items.isEmpty
                            ? const [
                                Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'No items found in this order.',
                                    style: TextStyle(
                                      fontFamily: 'ClashGrotesk',
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              ]
                            : items.map((item) {
                                final name = _nameOf(item);
                                final sku = _skuOf(item);
                                final qty = _qtyOf(item);

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.shopping_bag_outlined,
                                          size: 16, color: Color(0xFF0AA2FF)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${name.isNotEmpty ? name : '—'}'
                                          '${sku.isNotEmpty ? " ($sku)" : ""}\n'
                                          'Qty: $qty',
                                          style: const TextStyle(
                                            fontFamily: 'ClashGrotesk',
                                            fontSize: 13,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ================================ UI =================================

class _BlinkCard extends StatelessWidget {
  final bool blink;
  final Widget child;
  const _BlinkCard({required this.blink, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: blink ? const Color(0xFFE8F7FF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: blink
              ? const Color(0xFF0AA2FF).withOpacity(0.35)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Error:\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'ClashGrotesk'),
        ),
      ),
    );
  }
}


// int _createdAtMillis(Map<String, dynamic> data) {
//   final v = data['createdAt'];
//   if (v is Timestamp) return v.millisecondsSinceEpoch;
//   if (v is DateTime) return v.millisecondsSinceEpoch;
//   if (v is int) return v;
//   if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch ?? 0;
//   return 0;
// }

// /// ✅ Safe time formatter
// String _fmtTime(dynamic createdAt) {
//   if (createdAt is Timestamp) {
//     return DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate());
//   }
//   if (createdAt is String) {
//     final dt = DateTime.tryParse(createdAt);
//     if (dt != null) return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
//   }
//   return '--';
// }

// /// ✅ Extract items list from many possible firestore keys (NO hardcoding values)
// List<Map<String, dynamic>> _extractOrderItems(Map<String, dynamic> data) {
//   final raw = data['items'] ?? data['lines'] ?? data['products'] ?? [];
//   if (raw is List) {
//     return raw
//         .whereType<Map>()
//         .map((e) => Map<String, dynamic>.from(e))
//         .toList();
//   }
//   return const [];
// }

// /// ✅ Extract qty safely
// int _qtyOf(Map<String, dynamic> item) {
//   final v = item['qty'] ?? item['quantity'] ?? item['q'] ?? 0;
//   if (v is int) return v;
//   if (v is double) return v.round();
//   if (v is num) return v.toInt();
//   if (v is String) return int.tryParse(v) ?? 0;
//   return 0;
// }

// /// ✅ Extract product name safely
// String _nameOf(Map<String, dynamic> item) {
//   final v = item['name'] ?? item['title'] ?? item['productName'] ?? '';
//   return (v ?? '').toString();
// }

// /// ✅ Extract SKU safely
// String _skuOf(Map<String, dynamic> item) {
//   final v = item['sku'] ??
//       item['skuNo'] ??
//       item['number'] ??
//       item['code'] ??
//       item['skuNumber'] ??
//       '';
//   return (v ?? '').toString();
// }


// class AdminDashboardScreen extends StatefulWidget {
//   const AdminDashboardScreen({super.key});

//   @override
//   State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
// }

// class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
//   int _index = 0;

//   final _items = const [
//     _AdminNavItem('Locations', Icons.location_on_outlined),
//     _AdminNavItem('Supervisors', Icons.supervisor_account_outlined),
//     _AdminNavItem('Attendance', Icons.access_time),
//     _AdminNavItem('Sales', Icons.shopping_cart_outlined),
//     _AdminNavItem('Journey Plans', Icons.map_outlined),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     final title = _items[_index].label;

//     Widget body;
//     switch (_index) {
//       case 0:
//         body = const LocationManagementTab();
//         break;
//       case 1:
//         body = const SupervisorManagementTab();
//         break;
//       case 2:
//         body = const AttendanceTabBlink();
//         break;
//       case 3:
//         body = const SalesTabBlink();
//         break;
//       case 4:
//         body = const JourneyPlansTab();
//         break;
//       default:
//         body = const LocationManagementTab();
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(title),
//         backgroundColor: const Color(0xFF0F172A),
//         foregroundColor: Colors.white,
//       ),
//       drawer: Drawer(
//         child: SafeArea(
//           child: Column(
//             children: [
//               const ListTile(
//                 leading: Icon(Icons.admin_panel_settings),
//                 title: Text('Admin Panel'),
//                 subtitle: Text('Manage locations, supervisors, attendance & sales'),
//               ),
//               const Divider(height: 1),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: _items.length,
//                   itemBuilder: (context, i) {
//                     final it = _items[i];
//                     final selected = i == _index;
//                     return ListTile(
//                       leading: Icon(it.icon),
//                       title: Text(it.label),
//                       selected: selected,
//                       onTap: () {
//                         Navigator.pop(context);
//                         setState(() => _index = i);
//                       },
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       body: body,
//     );
//   }
// }

// class _AdminNavItem {
//   final String label;
//   final IconData icon;
//   const _AdminNavItem(this.label, this.icon);
// }



// class AttendanceTabBlink extends StatefulWidget {
//   const AttendanceTabBlink({super.key});

//   @override
//   State<AttendanceTabBlink> createState() => _AttendanceTabBlinkState();
// }

// class _AttendanceTabBlinkState extends State<AttendanceTabBlink> {
//   final Set<String> _known = {}; // doc ids seen before
//   final Set<String> _blink = {}; // doc ids that should blink once

//   void _detectNew(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
//     final currentIds = docs.map((d) => d.id).toSet();

//     // First load: mark all known (no blink)
//     if (_known.isEmpty) {
//       _known.addAll(currentIds);
//       return;
//     }

//     // Any new doc id -> blink once
//     final newOnes = currentIds.difference(_known);
//     if (newOnes.isNotEmpty) {
//       _blink.addAll(newOnes);
//       _known.addAll(newOnes);

//       // remove blink after 800ms (blink once)
//       Future.delayed(const Duration(milliseconds: 800), () {
//         if (!mounted) return;
//         setState(() => _blink.removeAll(newOnes));
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final usersStream = FirebaseFirestore.instance.collection('users').snapshots();

//     final attendanceStream = FirebaseFirestore.instance
//         .collectionGroup('attendance')
//         .limit(300)
//         .snapshots();

//     return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//       stream: usersStream,
//       builder: (context, usersSnap) {
//         final Map<String, String> uidToName = {};
//         if (usersSnap.hasData) {
//           for (final d in usersSnap.data!.docs) {
//             final name = (d.data()['name'] ?? '').toString();
//             if (name.isNotEmpty) uidToName[d.id] = name;
//           }
//         }

//         return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//           stream: attendanceStream,
//           builder: (context, snap) {
//             if (snap.hasError) return _ErrorBox(message: snap.error.toString());
//             if (!snap.hasData) {
//               return const Center(child: CircularProgressIndicator());
//             }

//             final docs = [...snap.data!.docs];
//             docs.sort((a, b) =>
//                 _createdAtMillis(b.data()).compareTo(_createdAtMillis(a.data())));

//             _detectNew(docs);

//             if (docs.isEmpty) {
//               return const Center(child: Text('No attendance records found.'));
//             }

//             return ListView.separated(
//               padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
//               itemCount: docs.length,
//               separatorBuilder: (_, __) => const SizedBox(height: 10),
//               itemBuilder: (context, i) {
//                 final d = docs[i];
//                 final data = d.data();

//                 final uid = d.reference.parent.parent?.id ?? 'unknown';
//                 final userName = uidToName[uid] ?? uid;

//                 final action = (data['action'] ?? '').toString();
//                 final dist = (data['distanceMeters'] as num?)?.toDouble();
//                 final within = (data['withinAllowed'] as bool?) ?? false;
//                 final lat = (data['lat'] as num?)?.toDouble();
//                 final lng = (data['lng'] as num?)?.toDouble();

//                 final timeStr = _fmtTime(data['createdAt']);

//                 final shouldBlink = _blink.contains(d.id);

//                 return _BlinkCard(
//                   blink: shouldBlink,
//                   child: Material(
//                     type: MaterialType.transparency, // ✅ Fix ListTile Material error
//                     child: ListTile(
//                       title: Text(
//                         '$userName • $action',
//                         style: const TextStyle(
//                           fontFamily: 'ClashGrotesk',
//                           fontWeight: FontWeight.w800,
//                           color: Color(0xFF1B1B1B),
//                         ),
//                       ),
//                       subtitle: Padding(
//                         padding: const EdgeInsets.only(top: 6),
//                         child: Text(
//                           'Time: $timeStr\n'
//                           'Distance: ${dist?.toStringAsFixed(1) ?? '--'} m (${within ? 'Allowed' : 'Blocked'})\n'
//                           'Lat/Lng: ${lat?.toStringAsFixed(6) ?? '--'}, ${lng?.toStringAsFixed(6) ?? '--'}',
//                           style: const TextStyle(
//                             fontFamily: 'ClashGrotesk',
//                             color: Colors.black87,
//                             height: 1.25,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }
// }

// // ============================ SALES TAB (BLINK) =============================

// class SalesTabBlink extends StatefulWidget {
//   const SalesTabBlink({super.key});

//   @override
//   State<SalesTabBlink> createState() => _SalesTabBlinkState();
// }

// class _SalesTabBlinkState extends State<SalesTabBlink> {
//   final Set<String> _known = {};
//   final Set<String> _blink = {};

//   void _detectNew(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
//     final currentIds = docs.map((d) => d.id).toSet();

//     if (_known.isEmpty) {
//       _known.addAll(currentIds);
//       return;
//     }

//     final newOnes = currentIds.difference(_known);
//     if (newOnes.isNotEmpty) {
//       _blink.addAll(newOnes);
//       _known.addAll(newOnes);

//       Future.delayed(const Duration(milliseconds: 800), () {
//         if (!mounted) return;
//         setState(() => _blink.removeAll(newOnes));
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final usersStream = FirebaseFirestore.instance.collection('users').snapshots();

//     final salesStream =
//         FirebaseFirestore.instance.collectionGroup('sales').limit(300).snapshots();

//     return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//       stream: usersStream,
//       builder: (context, usersSnap) {
//         final Map<String, String> uidToName = {};
//         if (usersSnap.hasData) {
//           for (final d in usersSnap.data!.docs) {
//             final name = (d.data()['name'] ?? '').toString();
//             if (name.isNotEmpty) uidToName[d.id] = name;
//           }
//         }

//         return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//           stream: salesStream,
//           builder: (context, snap) {
//             if (snap.hasError) return _ErrorBox(message: snap.error.toString());
//             if (!snap.hasData) {
//               return const Center(child: CircularProgressIndicator());
//             }

//             final docs = [...snap.data!.docs];
//             docs.sort((a, b) =>
//                 _createdAtMillis(b.data()).compareTo(_createdAtMillis(a.data())));

//             _detectNew(docs);

//             if (docs.isEmpty) {
//               return const Center(child: Text('No sales records found.'));
//             }

//             return ListView.separated(
//               padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
//               itemCount: docs.length,
//               separatorBuilder: (_, __) => const SizedBox(height: 10),
//               itemBuilder: (context, i) {
//                 final d = docs[i];
//                 final data = d.data();

//                 final uid = d.reference.parent.parent?.id ?? 'unknown';
//                 final userName = uidToName[uid] ?? uid;

//                 final timeStr = _fmtTime(data['createdAt']);
//                 final total = (data['total'] ?? data['grandTotal'] ?? data['amount']);

//                 // ✅ Order items list from firestore (items/lines/products)
//                 final items = _extractOrderItems(data);

//                 // ✅ SKU count and total quantity
//                 final skuCount = items.length;
//                 final totalQty = items.fold<int>(0, (sum, it) => sum + _qtyOf(it));

//                 final shouldBlink = _blink.contains(d.id);

//                 return _BlinkCard(
//                   blink: shouldBlink,
//                   child: Material(
//                     type: MaterialType.transparency, // ✅ Fix ExpansionTile Material error
//                     child: Theme(
//                       data: Theme.of(context).copyWith(
//                         dividerColor: Colors.transparent,
//                         splashColor: Colors.transparent,
//                         highlightColor: Colors.transparent,
//                       ),
//                       child: ExpansionTile(
//                         tilePadding: const EdgeInsets.symmetric(horizontal: 16),
//                         childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),

//                         title: Text(
//                           '$userName • Sale',
//                           style: const TextStyle(
//                             fontFamily: 'ClashGrotesk',
//                             fontWeight: FontWeight.w800,
//                             color: Color(0xFF1B1B1B),
//                           ),
//                         ),

//                         subtitle: Padding(
//                           padding: const EdgeInsets.only(top: 6),
//                           child: Text(
//                             'Time: $timeStr\n'
//                             'SKUs: $skuCount  •  Qty: $totalQty\n'
//                             'Total: ${total ?? '--'}',
//                             style: const TextStyle(
//                               fontFamily: 'ClashGrotesk',
//                               color: Colors.black87,
//                               height: 1.25,
//                             ),
//                           ),
//                         ),

//                         children: items.isEmpty
//                             ? [
//                                 const Padding(
//                                   padding: EdgeInsets.only(top: 8),
//                                   child: Text(
//                                     'No items found in this order.',
//                                     style: TextStyle(
//                                       fontFamily: 'ClashGrotesk',
//                                       fontSize: 13,
//                                     ),
//                                   ),
//                                 )
//                               ]
//                             : items.map((item) {
//                                 final name = _nameOf(item);
//                                 final sku = _skuOf(item);
//                                 final qty = _qtyOf(item);

//                                 return Padding(
//                                   padding: const EdgeInsets.only(top: 8),
//                                   child: Row(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       const Icon(
//                                         Icons.shopping_bag_outlined,
//                                         size: 16,
//                                         color: Color(0xFF0AA2FF),
//                                       ),
//                                       const SizedBox(width: 8),
//                                       Expanded(
//                                         child: Text(
//                                           '${name.isNotEmpty ? name : '—'}'
//                                           '${sku.isNotEmpty ? " ($sku)" : ""}\n'
//                                           'Qty: $qty',
//                                           style: const TextStyle(
//                                             fontFamily: 'ClashGrotesk',
//                                             fontSize: 13,
//                                             height: 1.3,
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               }).toList(),
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }
// }

// // ================================ UI =================================

// class _BlinkCard extends StatelessWidget {
//   final bool blink;
//   final Widget child;
//   const _BlinkCard({required this.blink, required this.child});

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 300),
//       padding: EdgeInsets.zero,
//       decoration: BoxDecoration(
//         color: blink ? const Color(0xFFE8F7FF) : Colors.white,
//         borderRadius: BorderRadius.circular(18),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.06),
//             blurRadius: 12,
//             offset: const Offset(0, 6),
//           ),
//         ],
//         border: Border.all(
//           color: blink ? const Color(0xFF0AA2FF).withOpacity(0.35) : Colors.transparent,
//           width: 1,
//         ),
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(18),
//         child: child,
//       ),
//     );
//   }
// }

// class _GradientIconButton extends StatelessWidget {
//   final String tooltip;
//   final IconData icon;
//   final VoidCallback onPressed;

//   const _GradientIconButton({
//     required this.tooltip,
//     required this.icon,
//     required this.onPressed,
//   });

//   static const _grad = LinearGradient(
//     colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   @override
//   Widget build(BuildContext context) {
//     return Tooltip(
//       message: tooltip,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(14),
//         onTap: onPressed,
//         child: Ink(
//           width: 40,
//           height: 40,
//           decoration: BoxDecoration(
//             gradient: _grad,
//             borderRadius: BorderRadius.circular(14),
//             boxShadow: [
//               BoxShadow(
//                 color: const Color(0xFF7F53FD).withOpacity(0.20),
//                 blurRadius: 14,
//                 offset: const Offset(0, 6),
//               ),
//             ],
//           ),
//           child: Icon(icon, color: Colors.white, size: 20),
//         ),
//       ),
//     );
//   }
// }

// class _ErrorBox extends StatelessWidget {
//   final String message;
//   const _ErrorBox({required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Text(
//           'Error:\n$message',
//           textAlign: TextAlign.center,
//           style: const TextStyle(fontFamily: 'ClashGrotesk'),
//         ),
//       ),
//     );
//   }
// }


/*

int _createdAtMillis(Map<String, dynamic> data) {
  final v = data['createdAt'];
  if (v is Timestamp) return v.millisecondsSinceEpoch;
  if (v is DateTime) return v.millisecondsSinceEpoch;
  if (v is int) return v;
  if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch ?? 0;
  return 0;
}

class AdminDashboardScreen extends StatefulWidget {
   AdminDashboardScreen();

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final Set<String> _known = {};
  final Set<String> _blink = {};

  void _detectNew(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final ids = docs.map((d) => d.id).toSet();

    if (_known.isEmpty) {
      _known.addAll(ids);
      return;
    }

    final newOnes = ids.difference(_known);
    if (newOnes.isNotEmpty) {
      _blink.addAll(newOnes);
      _known.addAll(newOnes);

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _blink.removeAll(newOnes));
      });
    }
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data) {
    final raw = data['items'] ?? data['products'] ?? data['lines'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance.collection('users').snapshots();
    final salesStream =
        FirebaseFirestore.instance.collectionGroup('sales').limit(300).snapshots();

    return StreamBuilder(
      stream: usersStream,
      builder: (_, usersSnap) {
        final names = <String, String>{};
        if (usersSnap.hasData) {
          for (final d in usersSnap.data!.docs) {
            final n = (d['name'] ?? '').toString();
            if (n.isNotEmpty) names[d.id] = n;
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: salesStream,
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = [...snap.data!.docs]
              ..sort((a, b) =>
                  _createdAtMillis(b.data()).compareTo(_createdAtMillis(a.data())));

            _detectNew(docs);

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final d = docs[i];
                final data = d.data();
                final uid = d.reference.parent.parent?.id ?? '';
                final user = names[uid] ?? uid;
                final items = _items(data);

                final blink = _blink.contains(d.id);
                final total = _num(data['total'] ?? data['grandTotal']);

                return _BlinkCard(
                  blink: blink,
                  child: ExpansionTile(
                    title: Text(
                      '$user • Order',
                      style: const TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      'Items: ${items.length}  |  Total: ${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontFamily: 'ClashGrotesk'),
                    ),
                    children: items.map((it) {
                      final name = it['name'] ?? it['title'] ?? 'Item';
                      final sku = it['sku'] ?? '--';
                      final qty = _num(it['qty'] ?? it['quantity']);
                      final price = _num(it['price'] ?? it['unitPrice']);
                      final line = qty * price;

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontFamily: 'ClashGrotesk',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'SKU: $sku\nQty: $qty\nPrice: $price\nLine: ${line.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontFamily: 'ClashGrotesk',
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}


class _BlinkCard extends StatelessWidget {
  final bool blink;
  final Widget child;
  const _BlinkCard({required this.blink, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // keeps your design
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: blink ? const Color(0xFFE8F7FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: blink
                ? const Color(0xFF0AA2FF).withOpacity(0.35)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Material(
          // ✅ THIS is what ListTile / ExpansionTile needs
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}

*/
// class AdminDashboardScreen extends StatelessWidget {
//   const AdminDashboardScreen({super.key});

//   static const _bg = Color(0xFFF2F3F5);
//   static const _grad = LinearGradient(
//     colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 3,
//       child: Scaffold(
//         backgroundColor: _bg,
//         appBar: AppBar(
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           title: const Text(
//             'Admin Dashboard',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 20,
//               fontWeight: FontWeight.w900,
//               color: Color(0xFF1B1B1B),
//             ),
//           ),
//           actions: [
//             Padding(
//               padding: const EdgeInsets.only(right: 12),
//               child: _GradientIconButton(
//                 tooltip: 'Logout',
//                 icon: Icons.logout,
//                 onPressed: () async {
//                   await FirebaseAuth.instance.signOut();
//                   if (!context.mounted) return;
//                   Navigator.of(context).popUntil((r) => r.isFirst);
//                 },
//               ),
//             ),
//           ],
//           bottom: PreferredSize(
//             preferredSize: const Size.fromHeight(56),
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
//               child: Container(
//                 height: 44,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(28),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.08),
//                       blurRadius: 16,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: TabBar(
//                   indicatorSize: TabBarIndicatorSize.tab,
//                   dividerColor: Colors.transparent,
//                   indicator: BoxDecoration(
//                     gradient: _grad,
//                     borderRadius: BorderRadius.circular(22),
//                   ),
//                   labelStyle: const TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 16,
//                     fontWeight: FontWeight.w900,
//                   ),
//                   unselectedLabelStyle: const TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontSize: 16,
//                     fontWeight: FontWeight.w900,
//                   ),
//                   labelColor: Colors.white,
//                   unselectedLabelColor: const Color(0xFF0AA2FF),
//                   tabs: const [
//                     Tab(text: 'Attendance'),
//                     Tab(text: 'Sales'),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//         body: const TabBarView(
//           children: [
//             AttendanceTabBlink(),
//             SalesTabBlink(),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class AttendanceTabBlink extends StatefulWidget {
//   const AttendanceTabBlink({super.key});

//   @override
//   State<AttendanceTabBlink> createState() => _AttendanceTabBlinkState();
// }

// class _AttendanceTabBlinkState extends State<AttendanceTabBlink> {
//   final Set<String> _known = {}; // doc ids seen before
//   final Set<String> _blink = {}; // doc ids that should blink once

//   void _detectNew(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
//     final currentIds = docs.map((d) => d.id).toSet();

//     // First load: mark all known (no blink)
//     if (_known.isEmpty) {
//       _known.addAll(currentIds);
//       return;
//     }

//     // Any new doc id -> blink once
//     final newOnes = currentIds.difference(_known);
//     if (newOnes.isNotEmpty) {
//       _blink.addAll(newOnes);
//       _known.addAll(newOnes);

//       // remove blink after 800ms (blink once)
//       Future.delayed(const Duration(milliseconds: 800), () {
//         if (!mounted) return;
//         setState(() => _blink.removeAll(newOnes));
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final usersStream = FirebaseFirestore.instance.collection('users').snapshots();

//     final attendanceStream = FirebaseFirestore.instance
//         .collectionGroup('attendance')
//         .limit(300)
//         .snapshots();

//     return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//       stream: usersStream,
//       builder: (context, usersSnap) {
//         final Map<String, String> uidToName = {};
//         if (usersSnap.hasData) {
//           for (final d in usersSnap.data!.docs) {
//             final name = (d.data()['name'] ?? '').toString();
//             if (name.isNotEmpty) uidToName[d.id] = name;
//           }
//         }

//         return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//           stream: attendanceStream,
//           builder: (context, snap) {
//             if (snap.hasError) return _ErrorBox(message: snap.error.toString());
//             if (!snap.hasData) return const Center(child: CircularProgressIndicator());

//             final docs = [...snap.data!.docs];
//             docs.sort((a, b) =>
//                 _createdAtMillis(b.data()).compareTo(_createdAtMillis(a.data())));

//             _detectNew(docs);

//             if (docs.isEmpty) {
//               return const Center(child: Text('No attendance records found.'));
//             }

//             return ListView.separated(
//               padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
//               itemCount: docs.length,
//               separatorBuilder: (_, __) => const SizedBox(height: 10),
//               itemBuilder: (context, i) {
//                 final d = docs[i];
//                 final data = d.data();

//                 final uid = d.reference.parent.parent?.id ?? 'unknown';
//                 final userName = uidToName[uid] ?? uid;

//                 final action = (data['action'] ?? '').toString();
//                 final dist = (data['distanceMeters'] as num?)?.toDouble();
//                 final within = (data['withinAllowed'] as bool?) ?? false;
//                 final lat = (data['lat'] as num?)?.toDouble();
//                 final lng = (data['lng'] as num?)?.toDouble();

//                 final ts = data['createdAt'];
//                 String timeStr = '--';
//                 if (ts is Timestamp) {
//                   timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
//                 } else if (ts is String) {
//                   final dt = DateTime.tryParse(ts);
//                   if (dt != null) timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
//                 }

//                 final shouldBlink = _blink.contains(d.id);

//                 return _BlinkCard(
//                   blink: shouldBlink,
//                   child: ListTile(
//                     title: Text(
//                       '$userName • $action',
//                       style: const TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontWeight: FontWeight.w800,
//                         color: Color(0xFF1B1B1B),
//                       ),
//                     ),
//                     subtitle: Padding(
//                       padding: const EdgeInsets.only(top: 6),
//                       child: Text(
//                         'Time: $timeStr\n'
//                         'Distance: ${dist?.toStringAsFixed(1) ?? '--'} m (${within ? 'Allowed' : 'Blocked'})\n'
//                         'Lat/Lng: ${lat?.toStringAsFixed(6) ?? '--'}, ${lng?.toStringAsFixed(6) ?? '--'}',
//                         style: const TextStyle(
//                           fontFamily: 'ClashGrotesk',
//                           color: Colors.black87,
//                           height: 1.25,
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }
// }

// class SalesTabBlink extends StatefulWidget {
//   const SalesTabBlink({super.key});

//   @override
//   State<SalesTabBlink> createState() => _SalesTabBlinkState();
// }

// class _SalesTabBlinkState extends State<SalesTabBlink> {
//   final Set<String> _known = {};
//   final Set<String> _blink = {};

//   void _detectNew(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
//     final currentIds = docs.map((d) => d.id).toSet();

//     if (_known.isEmpty) {
//       _known.addAll(currentIds);
//       return;
//     }

//     final newOnes = currentIds.difference(_known);
//     if (newOnes.isNotEmpty) {
//       _blink.addAll(newOnes);
//       _known.addAll(newOnes);

//       Future.delayed(const Duration(milliseconds: 800), () {
//         if (!mounted) return;
//         setState(() => _blink.removeAll(newOnes));
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final usersStream = FirebaseFirestore.instance.collection('users').snapshots();

//     final salesStream =
//         FirebaseFirestore.instance.collectionGroup('sales').limit(300).snapshots();

//     return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//       stream: usersStream,
//       builder: (context, usersSnap) {
//         final Map<String, String> uidToName = {};
//         if (usersSnap.hasData) {
//           for (final d in usersSnap.data!.docs) {
//             final name = (d.data()['name'] ?? '').toString();
//             if (name.isNotEmpty) uidToName[d.id] = name;
//           }
//         }

//         return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//           stream: salesStream,
//           builder: (context, snap) {
//             if (snap.hasError) return _ErrorBox(message: snap.error.toString());
//             if (!snap.hasData) return const Center(child: CircularProgressIndicator());

//             final docs = [...snap.data!.docs];
//             docs.sort((a, b) =>
//                 _createdAtMillis(b.data()).compareTo(_createdAtMillis(a.data())));

//             _detectNew(docs);

//             if (docs.isEmpty) return const Center(child: Text('No sales records found.'));

//             return ListView.separated(
//               padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
//               itemCount: docs.length,
//               separatorBuilder: (_, __) => const SizedBox(height: 10),
//               itemBuilder: (context, i) {
//                 final d = docs[i];
//                 final data = d.data();

//                 final uid = d.reference.parent.parent?.id ?? 'unknown';
//                 final userName = uidToName[uid] ?? uid;

//                 final ts = data['createdAt'];
//                 String timeStr = '--';
//                 if (ts is Timestamp) {
//                   timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate());
//                 } else if (ts is String) {
//                   final dt = DateTime.tryParse(ts);
//                   if (dt != null) timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
//                 }

//                 final total = (data['total'] ?? data['grandTotal'] ?? data['amount']);
//                 final items = data['items'] ?? data['lines'] ?? data['products'];
//                 final title =
//                     (data['title'] ?? data['customerName'] ?? 'Sale').toString();

//                 String itemsSummary = '';
//                 if (items is List) {
//                   itemsSummary = 'Items: ${items.length}';
//                 } else if (items != null) {
//                   itemsSummary = 'Items: 1';
//                 }

//                 final shouldBlink = _blink.contains(d.id);

//                 return _BlinkCard(
//                   blink: shouldBlink,
//                   child: ListTile(
//                     title: Text(
//                       '$userName • $title',
//                       style: const TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontWeight: FontWeight.w800,
//                         color: Color(0xFF1B1B1B),
//                       ),
//                     ),
//                     subtitle: Padding(
//                       padding: const EdgeInsets.only(top: 6),
//                       child: Text(
//                         'Time: $timeStr\n'
//                         'Total: ${total ?? '--'}\n'
//                         '$itemsSummary',
//                         style: const TextStyle(
//                           fontFamily: 'ClashGrotesk',
//                           color: Colors.black87,
//                           height: 1.25,
//                         ),
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }
// }

// class _BlinkCard extends StatelessWidget {
//   final bool blink;
//   final Widget child;
//   const _BlinkCard({required this.blink, required this.child});

//   @override
//   Widget build(BuildContext context) {
//     // blink once = quick highlight
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 300),
//       padding: EdgeInsets.zero,
//       decoration: BoxDecoration(
//         color: blink ? const Color(0xFFE8F7FF) : Colors.white,
//         borderRadius: BorderRadius.circular(18),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.06),
//             blurRadius: 12,
//             offset: const Offset(0, 6),
//           ),
//         ],
//         border: Border.all(
//           color: blink ? const Color(0xFF0AA2FF).withOpacity(0.35) : Colors.transparent,
//           width: 1,
//         ),
//       ),
//       child: child,
//     );
//   }
// }

// class _GradientIconButton extends StatelessWidget {
//   final String tooltip;
//   final IconData icon;
//   final VoidCallback onPressed;

//   const _GradientIconButton({
//     required this.tooltip,
//     required this.icon,
//     required this.onPressed,
//   });

//   static const _grad = LinearGradient(
//     colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   @override
//   Widget build(BuildContext context) {
//     return Tooltip(
//       message: tooltip,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(14),
//         onTap: onPressed,
//         child: Ink(
//           width: 40,
//           height: 40,
//           decoration: BoxDecoration(
//             gradient: _grad,
//             borderRadius: BorderRadius.circular(14),
//             boxShadow: [
//               BoxShadow(
//                 color: const Color(0xFF7F53FD).withOpacity(0.20),
//                 blurRadius: 14,
//                 offset: const Offset(0, 6),
//               ),
//             ],
//           ),
//           child: Icon(icon, color: Colors.white, size: 20),
//         ),
//       ),
//     );
//   }
// }

// class _ErrorBox extends StatelessWidget {
//   final String message;
//   const _ErrorBox({required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Text(
//           'Error:\n$message',
//           textAlign: TextAlign.center,
//           style: const TextStyle(fontFamily: 'ClashGrotesk'),
//         ),
//       ),
//     );
//   }
// }

