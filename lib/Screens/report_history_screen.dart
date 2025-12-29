import 'package:flutter/material.dart';
import 'package:new_amst_flutter/Screens/home_screen.dart';
import 'package:new_amst_flutter/Screens/products.dart';
import 'dart:typed_data';
import 'package:get_storage/get_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import 'package:open_filex/open_filex.dart';
import 'package:new_amst_flutter/Data/order_storage.dart';
import '../Data/order_storage.dart';
import '../Data/daily_report_pdf.dart';



// simple theme helpers
const kTxtDark = Color(0xFF0F172A);
const kTxtDim = Color(0xFF6B7280);
const kGradBluePurple = LinearGradient(
  colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

enum _Filter { all, today, last7, thisMonth }
enum _DlgAction { view, download }

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});
  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  // _Filter _filter = _Filter.all;

  // final GetStorage _box = GetStorage();
  // final DailyReportPdfService _pdfService = DailyReportPdfService();

  // List<DailySheet> _sheets = [];
  // bool _loading = true;

    _Filter _filter = _Filter.all;

  final GetStorage _box = GetStorage();
  final DailyReportPdfService _pdfService = DailyReportPdfService();

  List<DailySheet> _sheets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSheets();

    _box.listenKey('local_orders', (_) {
      if (!mounted) return;
      _loadSheets();
    });
  }

  Future<void> _loadSheets() async {
    final list = OrdersStorage().allDailySheets();
    if (!mounted) return;
    setState(() {
      _sheets = list;
      _loading = false;
    });
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DailySheet> get _filtered {
    final now = DateTime.now();
    final today = _dateOnly(now);

    switch (_filter) {
      case _Filter.all:
        return _sheets;

      case _Filter.today:
        return _sheets
            .where((s) => _dateOnly(s.day) == today)
            .toList();

      case _Filter.last7:
        final from = now.subtract(const Duration(days: 7));
        final fromDateOnly = _dateOnly(from);
        return _sheets
            .where((s) =>
                _dateOnly(s.day).isAfter(fromDateOnly.subtract(const Duration(days: 1))))
            .toList();

      case _Filter.thisMonth:
        return _sheets
            .where((s) =>
                s.day.year == now.year && s.day.month == now.month)
            .toList();
    }
  }

  String _prettyDay(DateTime d) {
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${m[d.month - 1]}, ${d.year}';
  }

  String _daySummary(DailySheet sheet) {
    return '${sheet.totalLines} SKUs • ${sheet.totalQty} Qty • ${sheet.totalOrders} orders';
  }

  bool _isDayDownloaded(DailySheet sheet) {
    return sheet.orders.any((o) => o.downloaded);
  }

  Future<void> _viewDailyPdf(DailySheet sheet) async {
    final bytes = await _pdfService.generateDailyReportPdf(sheet.day);
    await Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  Future<void> _downloadDailyPdf(DailySheet sheet) async {
    final Uint8List bytes =
        await _pdfService.generateDailyReportPdf(sheet.day);

    final String baseName =
        'daily_${sheet.day.year}-${sheet.day.month.toString().padLeft(2, '0')}-${sheet.day.day.toString().padLeft(2, '0')}';

    String? savedPath;
    try {
      savedPath = await FileSaver.instance.saveFile(
        name: baseName,
        bytes: bytes,
        ext: 'pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
      return;
    }

    // mark all orders of that day as downloaded
    for (final o in sheet.orders) {
      await OrdersStorage().setDownloaded(o.id, true);
    }
    await _loadSheets();

    if (!mounted) return;
    final path = savedPath ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path.isEmpty ? 'PDF saved' : 'Saved to: $path'),
        action: path.isEmpty
            ? null
            : SnackBarAction(
                label: 'OPEN',
                onPressed: () => OpenFilex.open(path),
              ),
      ),
    );
  }

  Future<_DlgAction?> _showActionDialog(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;

    return showGeneralDialog<_DlgAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 330 * s,
              padding: EdgeInsets.fromLTRB(
                  18 * s, 18 * s, 18 * s, 16 * s),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20 * s),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 18 * s,
                    offset: Offset(0, 10 * s),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * s,
                      vertical: 6 * s,
                    ),
                    decoration: BoxDecoration(
                      gradient: kGradBluePurple,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6 * s),
                        const Text(
                          'Report Options',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14 * s),
                  Text(
                    'What would you like to do?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 18 * s,
                      fontWeight: FontWeight.w800,
                      color: kTxtDark,
                    ),
                  ),
                  SizedBox(height: 10 * s),
                  Text(
                    'You can quickly preview this report on screen or download a PDF copy for your records.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 13.5 * s,
                      height: 1.35,
                      color: kTxtDim,
                    ),
                  ),
                  SizedBox(height: 18 * s),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius:
                                BorderRadius.circular(12 * s),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7F53FD)
                                    .withOpacity(0.22),
                                blurRadius: 14 * s,
                                offset: Offset(0, 6 * s),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.visibility_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'View',
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                horizontal: 8 * s,
                                vertical: 10 * s,
                              ),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12 * s),
                              ),
                            ),
                            onPressed: () =>
                                Navigator.of(context)
                                    .pop(_DlgAction.view),
                          ),
                        ),
                      ),
                      SizedBox(width: 12 * s),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius:
                                BorderRadius.circular(12 * s),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7F53FD)
                                    .withOpacity(0.22),
                                blurRadius: 14 * s,
                                offset: Offset(0, 6 * s),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.download_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Download',
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                horizontal: 8 * s,
                                vertical: 10 * s,
                              ),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12 * s),
                              ),
                            ),
                            onPressed: () =>
                                Navigator.of(context)
                                    .pop(_DlgAction.download),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 390.0;
    final padBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSheets,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                16 * s, 8 * s, 16 * s, 140 * s + padBottom),
            children: [
              _FiltersBar(
                s: s,
                active: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
              SizedBox(height: 16 * s),
              if (_loading)
                Padding(
                  padding: EdgeInsets.only(top: 40 * s),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_filtered.isEmpty)
                Padding(
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).size.height * 0.25),
                  child: const Center(
                    child: Text(
                      'No sales reports available yet!',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                ..._filtered.map((sheet) {
                  final downloaded = _isDayDownloaded(sheet);
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12 * s),
                    child: _ReportCard(
                      s: s,
                      dateText: _prettyDay(sheet.day),
                      vehicleText: _daySummary(sheet),
                      completed: true,
                      downloaded: downloaded,
                      onDownload: () async {
                        final act =
                            await _showActionDialog(context);
                        if (act == _DlgAction.view) {
                          await _viewDailyPdf(sheet);
                        } else if (act ==
                            _DlgAction.download) {
                          await _downloadDailyPdf(sheet);
                        }
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------- Filters Bar ---------------- */

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
          padding: EdgeInsets.symmetric(
              horizontal: 14 * s, vertical: 8 * s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: isActive
                ? const LinearGradient(
                    colors: [
                      Color(0xFF00C6FF),
                      Color(0xFF7F53FD)
                    ],
                  )
                : null,
            color: isActive
                ? null
                : const Color(0xFFEFF2F8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w800,
              color: isActive
                  ? Colors.white
                  : const Color(0xFF111827),
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

/* ---------------- Report Card ---------------- */

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.s,
    required this.dateText,
    required this.vehicleText,
    required this.completed,
    required this.downloaded,
    required this.onDownload,
  });

  final double s;
  final String dateText;
  final String vehicleText;
  final bool completed;
  final bool downloaded;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final canTap = onDownload != null;
    final label =
        downloaded ? 'Download\nAgain' : 'Download\nFull Report';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * s),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9 * s,
            height: 121 * s,
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
              padding: EdgeInsets.fromLTRB(
                  12 * s, 10 * s, 12 * s, 10 * s),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Daily Report',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                            fontSize: 16 * s,
                          ),
                        ),
                      ),
                      _DownloadPill(
                        s: s,
                        enabled: canTap,
                        label: label,
                        onTap: onDownload,
                      ),
                    ],
                  ),
                  SizedBox(height: 6 * s),
                  Row(
                    children: [
                      Icon(
                        Icons.event_note_rounded,
                        size: 16 * s,
                        color: const Color(0xFF6B7280),
                      ),
                      SizedBox(width: 6 * s),
                      Text(
                        dateText,
                        style: TextStyle(
                          color: const Color(0xFF6B7280),
                          fontSize: 12.5 * s,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4 * s),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          vehicleText,
                          style: TextStyle(
                            color: const Color(0xFF6B7280),
                            fontSize: 12.5 * s,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
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

class _DownloadPill extends StatelessWidget {
  const _DownloadPill({
    required this.s,
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final double s;
  final bool enabled;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: EdgeInsets.symmetric(
          horizontal: 10 * s, vertical: 8 * s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * s),
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF6FF), Color(0xFFEFF1FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30 * s,
            height: 30 * s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
              ),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 19,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 8 * s),
          Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
              fontSize: 11.5 * s,
              height: 1.0,
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : .5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: pill,
      ),
    );
  }
}


