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
}
