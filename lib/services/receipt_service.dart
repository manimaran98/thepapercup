import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:thepapercup/modal/receipt_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart';

class ReceiptService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save receipt to Firestore
  Future<void> saveReceipt(ReceiptModel receipt) async {
    await _firestore
        .collection('receipts')
        .doc(receipt.id)
        .set(receipt.toMap());
  }

  // Get all receipts
  Stream<List<ReceiptModel>> getReceipts() {
    return _firestore
        .collection('receipts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReceiptModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Get receipts by date range
  Stream<List<ReceiptModel>> getReceiptsByDateRange(
      DateTime startDate, DateTime endDate) {
    return _firestore
        .collection('receipts')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThan: Timestamp.fromDate(endDate))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReceiptModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Generate PDF receipt
  Future<File> generateReceiptPDF(ReceiptModel receipt) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(symbol: 'RM');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'The Paper Cup',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Coffee & More',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      '123 Coffee Street, City',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Phone: (123) 456-7890',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1),

              // Receipt Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Receipt #: ${receipt.id}'),
                  pw.Text(dateFormat.format(receipt.timestamp)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('Payment Method: ${receipt.paymentMethod}'),
              pw.SizedBox(height: 16),

              // Items
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Item',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Qty',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Price',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Total',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // Items
                  ...receipt.items.map((item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(item['name']),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(item['quantity'].toString()),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child:
                                pw.Text(currencyFormat.format(item['price'])),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child:
                                pw.Text(currencyFormat.format(item['total'])),
                          ),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 16),

              // Totals
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Subtotal:',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(currencyFormat.format(receipt.total)),
                      ],
                    ),
                    if (receipt.change != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Change:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(currencyFormat.format(receipt.change!)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your purchase!',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Please come again',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/receipt_${receipt.id}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // Print receipt
  Future<void> printReceipt(ReceiptModel receipt) async {
    final file = await generateReceiptPDF(receipt);
    await Share.shareXFiles([XFile(file.path)], text: 'Receipt');

    // Update printed status
    await _firestore.collection('receipts').doc(receipt.id).update({
      'isPrinted': true,
    });
  }

  // Email receipt
  Future<void> emailReceipt(ReceiptModel receipt, String email) async {
    final file = await generateReceiptPDF(receipt);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Your receipt from The Paper Cup',
      subject: 'Receipt #${receipt.id} from The Paper Cup',
    );

    // Update emailed status
    await _firestore.collection('receipts').doc(receipt.id).update({
      'isEmailed': true,
      'customerEmail': email,
    });
  }

  // Generate reports
  Future<Map<String, dynamic>> generateDailyReport(DateTime date) async {
    final startDate = DateTime(date.year, date.month, date.day);
    final endDate = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('receipts')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThan: Timestamp.fromDate(endDate))
        .get();

    final receipts =
        snapshot.docs.map((doc) => ReceiptModel.fromMap(doc.data())).toList();

    return {
      'date': date,
      'totalSales': receipts.fold(0.0, (sum, receipt) => sum + receipt.total),
      'totalOrders': receipts.length,
      'averageOrder': receipts.isEmpty
          ? 0.0
          : receipts.fold(0.0, (sum, receipt) => sum + receipt.total) /
              receipts.length,
      'paymentMethods': _aggregatePaymentMethods(receipts),
      'items': _aggregateItems(receipts),
    };
  }

  Future<Map<String, dynamic>> generateMonthlyReport(DateTime date) async {
    final startDate = DateTime(date.year, date.month, 1);
    final endDate = DateTime(date.year, date.month + 1, 0, 23, 59, 59);

    final snapshot = await _firestore
        .collection('receipts')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThan: Timestamp.fromDate(endDate))
        .get();

    final receipts =
        snapshot.docs.map((doc) => ReceiptModel.fromMap(doc.data())).toList();

    // Group by day
    Map<DateTime, List<ReceiptModel>> dailyReceipts = {};
    for (var receipt in receipts) {
      final day = DateTime(receipt.timestamp.year, receipt.timestamp.month,
          receipt.timestamp.day);
      dailyReceipts[day] = [...(dailyReceipts[day] ?? []), receipt];
    }

    // Calculate daily totals
    Map<DateTime, double> dailyTotals = {};
    for (var entry in dailyReceipts.entries) {
      dailyTotals[entry.key] =
          entry.value.fold(0.0, (sum, receipt) => sum + receipt.total);
    }

    return {
      'month': date,
      'totalSales': receipts.fold(0.0, (sum, receipt) => sum + receipt.total),
      'totalOrders': receipts.length,
      'averageOrder': receipts.isEmpty
          ? 0.0
          : receipts.fold(0.0, (sum, receipt) => sum + receipt.total) /
              receipts.length,
      'dailyTotals': dailyTotals,
      'paymentMethods': _aggregatePaymentMethods(receipts),
      'items': _aggregateItems(receipts),
    };
  }

  Future<Map<String, dynamic>> generateYearlyReport(DateTime date) async {
    final startDate = DateTime(date.year, 1, 1);
    final endDate = DateTime(date.year, 12, 31, 23, 59, 59);

    final snapshot = await _firestore
        .collection('receipts')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThan: Timestamp.fromDate(endDate))
        .get();

    final receipts =
        snapshot.docs.map((doc) => ReceiptModel.fromMap(doc.data())).toList();

    // Group by month
    Map<int, List<ReceiptModel>> monthlyReceipts = {};
    for (var receipt in receipts) {
      final month = receipt.timestamp.month;
      monthlyReceipts[month] = [...(monthlyReceipts[month] ?? []), receipt];
    }

    // Calculate monthly totals
    Map<int, double> monthlyTotals = {};
    for (var entry in monthlyReceipts.entries) {
      monthlyTotals[entry.key] =
          entry.value.fold(0.0, (sum, receipt) => sum + receipt.total);
    }

    return {
      'year': date.year,
      'totalSales': receipts.fold(0.0, (sum, receipt) => sum + receipt.total),
      'totalOrders': receipts.length,
      'averageOrder': receipts.isEmpty
          ? 0.0
          : receipts.fold(0.0, (sum, receipt) => sum + receipt.total) /
              receipts.length,
      'monthlyTotals': monthlyTotals,
      'paymentMethods': _aggregatePaymentMethods(receipts),
      'items': _aggregateItems(receipts),
    };
  }

  Map<String, double> _aggregatePaymentMethods(List<ReceiptModel> receipts) {
    Map<String, double> paymentMethods = {};
    for (var receipt in receipts) {
      paymentMethods[receipt.paymentMethod] =
          (paymentMethods[receipt.paymentMethod] ?? 0) + receipt.total;
    }
    return paymentMethods;
  }

  Map<String, Map<String, dynamic>> _aggregateItems(
      List<ReceiptModel> receipts) {
    Map<String, Map<String, dynamic>> items = {};
    for (var receipt in receipts) {
      for (var item in receipt.items) {
        final name = item['name'] as String;
        final quantity = item['quantity'] as int;
        final total = item['total'] as double;

        if (!items.containsKey(name)) {
          items[name] = {
            'quantity': 0,
            'total': 0.0,
          };
        }

        items[name]!['quantity'] = (items[name]!['quantity'] as int) + quantity;
        items[name]!['total'] = (items[name]!['total'] as double) + total;
      }
    }
    return items;
  }

  // Generate PDF report
  Future<File> generateReportPDF(
      Map<String, dynamic> report, String reportType) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(symbol: 'RM');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'The Paper Cup',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Sales Report',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Report Type: $reportType',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Summary',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Sales:'),
                        pw.Text(currencyFormat.format(report['totalSales'])),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Orders:'),
                        pw.Text(report['totalOrders'].toString()),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Average Order:'),
                        pw.Text(currencyFormat.format(report['averageOrder'])),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Payment Methods
              pw.Text('Payment Methods',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Method',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Amount',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...report['paymentMethods']
                      .entries
                      .map((entry) => pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(entry.key),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child:
                                    pw.Text(currencyFormat.format(entry.value)),
                              ),
                            ],
                          )),
                ],
              ),
              pw.SizedBox(height: 20),

              // Time-based Data
              if (reportType == 'Monthly Report' &&
                  report['dailyTotals'] != null) ...[
                pw.Text('Daily Sales',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Date',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Amount',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...report['dailyTotals'].entries.map((entry) => pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(dateFormat.format(entry.key)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child:
                                  pw.Text(currencyFormat.format(entry.value)),
                            ),
                          ],
                        )),
                  ],
                ),
              ] else if (reportType == 'Yearly Report' &&
                  report['monthlyTotals'] != null) ...[
                pw.Text('Monthly Sales',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Month',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Amount',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...report['monthlyTotals']
                        .entries
                        .map((entry) => pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(DateFormat('MMMM')
                                      .format(DateTime(2024, entry.key))),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                      currencyFormat.format(entry.value)),
                                ),
                              ],
                            )),
                  ],
                ),
              ],
              pw.SizedBox(height: 20),

              // Top Items
              pw.Text('Top Selling Items',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Item',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Quantity',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('Total',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...report['items'].entries.map((entry) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(entry.key),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(entry.value['quantity'].toString()),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                                currencyFormat.format(entry.value['total'])),
                          ),
                        ],
                      )),
                ],
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File(
        '${output.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // Share report
  Future<void> shareReport(
      Map<String, dynamic> report, String reportType) async {
    final file = await generateReportPDF(report, reportType);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: '$reportType - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
    );
  }
}
