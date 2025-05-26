import 'package:cloud_firestore/cloud_firestore.dart';

class SalesModel {
  final String id;
  final DateTime timestamp;
  final List<SalesItem> items;
  final double total;
  final String paymentMethod;
  final String userId;

  SalesModel({
    required this.id,
    required this.timestamp,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.userId,
  });

  factory SalesModel.fromMap(Map<String, dynamic> map, String docId) {
    return SalesModel(
      id: docId,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      items: (map['items'] as List<dynamic>)
          .map((item) => SalesItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      total: (map['total'] as num).toDouble(),
      paymentMethod: map['paymentMethod'] as String,
      userId: map['userId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'paymentMethod': paymentMethod,
      'userId': userId,
    };
  }
}

class SalesItem {
  final String name;
  final int quantity;
  final double price;
  final double cost;
  final String category;

  SalesItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.cost,
    required this.category,
  });

  factory SalesItem.fromMap(Map<String, dynamic> map) {
    return SalesItem(
      name: map['name'] as String,
      quantity: map['quantity'] as int,
      price: (map['price'] as num).toDouble(),
      cost: (map['cost'] as num).toDouble(),
      category: map['category'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'cost': cost,
      'category': category,
    };
  }
}
