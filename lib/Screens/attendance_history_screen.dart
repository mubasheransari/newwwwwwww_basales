import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

/// Same filters as ReportHistoryScreen
enum _Filter { all, today, last7, thisMonth }

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final GetStorage _box = GetStorage();
  static const String _storageKey = 'attendance_logs';

  _Filter _filter = _Filter.all;

  List<AttendanceRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _loadAttendance();

    // 🔄 Live reload when MarkAttendanceView writes 'attendance_logs'
    _box.listenKey(_storageKey, (_) {
      if (!mounted) return;
      _loadAttendance();
    });
  }

  Future<void> _loadAttendance() async {
    final raw = _box.read(_storageKey);
    final List<AttendanceRecord> items = [];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            items.add(AttendanceRecord.fromMap(
              Map<String, dynamic>.from(item),
            ));
          } catch (_) {
            // ignore bad rows
          }
        }
      }
    }

    // Sort: newest on top
    items.sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;
    setState(() {
      _records = items;
      _loading = false;
    });
  }

  List<AttendanceRecord> get _filtered {
    final now = DateTime.now();
    switch (_filter) {
      case _Filter.all:
        return _records;
      case _Filter.today:
        return _records.where((e) {
          return e.date.year == now.year &&
              e.date.month == now.month &&
              e.date.day == now.day;
        }).toList();
      case _Filter.last7:
        final from = now.subtract(const Duration(days: 7));
        return _records.where((e) => e.date.isAfter(from)).toList();
      case _Filter.thisMonth:
        return _records
            .where(
              (e) => e.date.year == now.year && e.date.month == now.month,
            )
            .toList();
    }
  }

  String _prettyDate(AttendanceRecord r) {
    // Example: "Mon, 13-Nov-2025"
    final df = DateFormat('EEE, dd-MMM-yyyy');
    return df.format(r.date);
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;
    final padBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAttendance,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16 * s,
              8 * s,
              16 * s,
              140 * s + padBottom,
            ),
            children: [
              // ----- Header -----
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.center,
              //   children: [
              //     Padding(
              //       padding: const EdgeInsets.only(left: 30.0),
              //       child: Text(
              //         'Attendance History',
              //         textAlign: TextAlign.center,
              //         style: TextStyle(
              //           fontFamily: 'ClashGrotesk',
              //           fontSize: 20 * s,
              //           fontWeight: FontWeight.w900,
              //           color: const Color(0xFF0F172A),
              //         ),
              //       ),
              //     ),
              //     const SizedBox(width: 48),
              //   ],
              // ),
              // SizedBox(height: 10 * s),

              _FiltersBar(
                s: s,
                active: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
              SizedBox(height: 16 * s),

              if (_loading)
                Padding(
                  padding: EdgeInsets.only(top: 40 * s),
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (_filtered.isEmpty)
                   Padding(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).size.height *0.25),
                  child: const Center(child: Text('No attendance reports available yet!',style: TextStyle(      fontFamily: 'ClashGrotesk',fontWeight: FontWeight.bold),)),
                )
                // Padding(
                //   padding: EdgeInsets.only(top: 40 * s),
                //   child: const Center(child: Text('No attendance records yet')),
                // )
              else
                ..._filtered.map(
                  (r) => Padding(
                    padding: EdgeInsets.only(bottom: 12 * s),
                    child: _AttendanceCard(
                      s: s,
                      title: _prettyDate(r),
                      day: r.day,
                      inTime: r.inTime,
                      outTime: r.outTime,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple model for one attendance row
class AttendanceRecord {
  final DateTime date; // Parsed from yyyy-MM-dd
  final String displayDate; // dd-MMM-yyyy
  final String day; // e.g. Monday
  final String inTime; // "09:15:10"
  final String outTime; // "18:10:05" or ""

  AttendanceRecord({
    required this.date,
    required this.displayDate,
    required this.day,
    required this.inTime,
    required this.outTime,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> json) {
    // 'date' in storage: "yyyy-MM-dd"
    final dateStr = (json['date'] ?? '').toString();
    final DisplayDate = (json['displayDate'] ?? '').toString();
    final day = (json['day'] ?? '').toString();
    final inTime = (json['in'] ?? '').toString();
    final outTime = (json['out'] ?? '').toString();

    // Fallback: if parse fails, use today (so it doesn't crash)
    DateTime parsed;
    try {
      parsed = DateTime.parse(dateStr);
    } catch (_) {
      parsed = DateTime.now();
    }

    return AttendanceRecord(
      date: parsed,
      displayDate: DisplayDate,
      day: day,
      inTime: inTime,
      outTime: outTime,
    );
  }
}

/* ---------------- Filters Bar (same style as ReportHistoryScreen) ---------------- */

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.s,
    required this.active,
    required this.onChanged,
  });

  final double s;
  final _Filter active;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(_Filter f, String label) {
      final isActive = f == active;
      return GestureDetector(
        onTap: () => onChanged(f),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                  )
                : null,
            color: isActive ? null : const Color(0xFFEFF2F8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w800,
              color: isActive ? Colors.white : const Color(0xFF111827),
              fontSize: 13 * s,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(8 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * s),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          chip(_Filter.all, 'All'),
          chip(_Filter.today, 'Today'),
          chip(_Filter.last7, 'Last 7 Days'),
          chip(_Filter.thisMonth, 'This Month'),
        ],
      ),
    );
  }
}

/* ---------------- Attendance Card UI ---------------- */

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.s,
    required this.title,
    required this.day,
    required this.inTime,
    required this.outTime,
  });

  final double s;
  final String title;
  final String day;
  final String inTime;
  final String outTime;

  @override
  Widget build(BuildContext context) {
    final hasOut = outTime.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * s),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // left gradient spine
          Container(
            width: 9 * s,
            height: 110 * s,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              gradient: LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12 * s, 10 * s, 12 * s, 10 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date + day
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      fontSize: 16 * s,
                    ),
                  ),
                  SizedBox(height: 4 * s),
                  Row(
                    children: [
                      Icon(
                        Icons.event_note_rounded,
                        size: 16 * s,
                        color: const Color(0xFF6B7280),
                      ),
                      SizedBox(width: 6 * s),
                      Text(
                        day,
                        style: TextStyle(
                          color: const Color(0xFF6B7280),
                          fontSize: 12.5 * s,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8 * s),
                  // IN / OUT times
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _InOutPill(
                        s: s,
                        label: 'IN',
                        time: inTime.isEmpty ? '--:--' : inTime,
                        color: const Color(0xFF22C55E),
                      ),
                      _InOutPill(
                        s: s,
                        label: 'OUT',
                        time: hasOut ? outTime : '--:--',
                        color: hasOut
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF9CA3AF),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InOutPill extends StatelessWidget {
  const _InOutPill({
    required this.s,
    required this.label,
    required this.time,
    required this.color,
  });

  final double s;
  final String label;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * s,
        vertical: 6 * s,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18 * s,
            height: 18 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          SizedBox(width: 8 * s),
          Text(
            '$label: $time',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              fontSize: 12 * s,
            ),
          ),
        ],
      ),
    );
  }
}
