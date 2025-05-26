import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptModel {
  final String id;
  final List<Map<String, dynamic>> items;
  final double total;
  final String paymentMethod;
  final DateTime timestamp;
  final double? change;
  final String? customerEmail;
  final bool isPrinted;
  final bool isEmailed;

  ReceiptModel({
    required this.id,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.timestamp,
    this.change,
    this.customerEmail,
    this.isPrinted = false,
    this.isEmailed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'items': items,
      'total': total,
      'paymentMethod': paymentMethod,
      'timestamp': timestamp,
      'change': change,
      'customerEmail': customerEmail,
      'isPrinted': isPrinted,
      'isEmailed': isEmailed,
    };
  }

  factory ReceiptModel.fromMap(Map<String, dynamic> map) {
    return ReceiptModel(
      id: map['id'] ?? '',
      items: List<Map<String, dynamic>>.from(map['items'] ?? []),
      total: (map['total'] ?? 0.0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      change: map['change']?.toDouble(),
      customerEmail: map['customerEmail'],
      isPrinted: map['isPrinted'] ?? false,
      isEmailed: map['isEmailed'] ?? false,
    );
  }
}
