

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'order_storage.dart';
import 'dart:typed_data';


// lib/Data/daily_report_pdf.dart
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'order_storage.dart'; // adjust path if needed
// lib/Data/daily_report_pdf.dart
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'order_storage.dart'; // adjust path if needed

class DailyReportPdfService {
  Future<Uint8List> generateDailyReportPdf(DateTime day) async {
    final sheet = OrdersStorage().dailySheetFor(day);
    final pdf = pw.Document();

    // No data for this day
    if (sheet == null || sheet.rows.isEmpty) {
      pdf.addPage(
        pw.Page(
          build: (_) => pw.Center(
            child: pw.Text('No sales recorded for this day.'),
          ),
        ),
      );
      final raw = await pdf.save();
      return Uint8List.fromList(raw);
    }

    final prettyDate = _prettyDay(sheet.day);

    // ---------- Table header ----------
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFEFF2F8),
        ),
        children: [
          _cell('#', bold: true),
          _cell('Product', bold: true),
          _cell('Brand', bold: true),
          _cellRight('Qty', bold: true),
        ],
      ),
    ];

    // ---------- Table body ----------
    int i = 1;
    for (final r in sheet.rows) {
      rows.add(
        pw.TableRow(
          children: [
            _cell('$i'),
            _cell(r.name),
            _cell(r.brand),
            _cellRight('${r.qty}'),
          ],
        ),
      );
      i++;
    }

    // ---------- Page layout ----------
    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFDCE7FF),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'Daily Sales Report',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    prettyDate,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${sheet.totalLines} SKUs • '
                    '${sheet.totalQty} Qty • '
                    '${sheet.totalOrders} orders',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColor.fromInt(0xFFE5E7EB),
              width: .6,
            ),
            defaultVerticalAlignment:
                pw.TableCellVerticalAlignment.middle,
            children: rows,
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFEFF1FF),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'Total Qty: ${sheet.totalQty}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Text(
            'Auto Generated Report',
            style: pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );

    final raw = await pdf.save();
    return Uint8List.fromList(raw);
  }

  String _prettyDay(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}, ${d.year}';
  }
}

// ---------- PDF cell helpers ----------

pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight:
              bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

pw.Widget _cellRight(String text, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight:
                bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );

