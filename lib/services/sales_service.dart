import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modal/sales_model.dart';

class SalesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new sale
  Future<String> createSale({
    required List<SalesItem> items,
    required double total,
    required String paymentMethod,
  }) async {
    try {
      final sale = SalesModel(
        id: '', // Will be set by Firestore
        timestamp: DateTime.now(),
        items: items,
        total: total,
        paymentMethod: paymentMethod,
        userId: _auth.currentUser!.uid,
      );

      final docRef = await _firestore.collection('sales').add(sale.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating sale: $e');
      rethrow;
    }
  }

  // Get sales for a specific date range
  Future<List<SalesModel>> getSalesByDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('sales')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) =>
              SalesModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error getting sales: $e');
      rethrow;
    }
  }

  // Get sales by category
  Future<Map<String, double>> getSalesByCategory(
      DateTime startDate, DateTime endDate) async {
    try {
      final QuerySnapshot salesSnapshot = await _firestore
          .collection('sales')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .get();

      Map<String, double> categorySales = {};

      for (var doc in salesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>;

        for (var item in items) {
          final itemData = item as Map<String, dynamic>;
          final category = itemData['category'] as String? ?? 'Uncategorized';
          final quantity = (itemData['quantity'] as num).toInt();
          final price = (itemData['price'] as num).toDouble();

          categorySales[category] =
              (categorySales[category] ?? 0) + (quantity * price);
        }
      }

      return categorySales;
    } catch (e) {
      print('Error getting sales by category: $e');
      return {};
    }
  }

  // Get sales by payment method
  Future<Map<String, double>> getSalesByPaymentMethod(
      DateTime startDate, DateTime endDate) async {
    try {
      final QuerySnapshot salesSnapshot = await _firestore
          .collection('sales')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .get();

      Map<String, double> paymentSales = {};

      for (var doc in salesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final paymentMethod = data['paymentMethod'] as String? ?? 'Unknown';
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;

        paymentSales[paymentMethod] =
            (paymentSales[paymentMethod] ?? 0) + total;
      }

      return paymentSales;
    } catch (e) {
      print('Error getting sales by payment method: $e');
      return {};
    }
  }

  // Get profit analysis
  Future<Map<String, double>> getProfitAnalysis(
      DateTime startDate, DateTime endDate) async {
    try {
      final QuerySnapshot salesSnapshot = await _firestore
          .collection('sales')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .get();

      double revenue = 0.0;
      double cost = 0.0;

      for (var doc in salesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>;

        for (var item in items) {
          final itemData = item as Map<String, dynamic>;
          final quantity = (itemData['quantity'] as num).toInt();
          final price = (itemData['price'] as num).toDouble();
          final itemCost = (itemData['cost'] as num?)?.toDouble() ?? 0.0;

          revenue += quantity * price;
          cost += quantity * itemCost;
        }
      }

      final profit = revenue - cost;
      final margin = revenue > 0 ? (profit / revenue) * 100 : 0.0;

      return {
        'revenue': revenue.toDouble(),
        'cost': cost.toDouble(),
        'profit': profit.toDouble(),
        'margin': margin.toDouble(),
      };
    } catch (e) {
      print('Error getting profit analysis: $e');
      return {
        'revenue': 0.0,
        'cost': 0.0,
        'profit': 0.0,
        'margin': 0.0,
      };
    }
  }

  // Get top selling items
  Future<Map<String, double>> getTopSellingItems(
      DateTime startDate, DateTime endDate) async {
    try {
      final QuerySnapshot salesSnapshot = await _firestore
          .collection('sales')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .get();

      Map<String, double> itemSales = {};

      for (var doc in salesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>;

        for (var item in items) {
          final itemData = item as Map<String, dynamic>;
          final name = itemData['name'] as String;
          final quantity = (itemData['quantity'] as num).toInt();
          final price = (itemData['price'] as num).toDouble();

          itemSales[name] = (itemSales[name] ?? 0) + (quantity * price);
        }
      }

      return itemSales;
    } catch (e) {
      print('Error getting top selling items: $e');
      return {};
    }
  }

  Future<Map<String, int>> getSalesQuantityByCategory(
      DateTime startDate, DateTime endDate) async {
    try {
      final QuerySnapshot salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .get();

      Map<String, int> categoryQuantities = {};

      for (var doc in salesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>;

        for (var item in items) {
          final category = item['category'] as String? ?? 'Uncategorized';
          final quantity = item['quantity'] as int? ?? 0;

          categoryQuantities[category] =
              (categoryQuantities[category] ?? 0) + quantity;
        }
      }

      return categoryQuantities;
    } catch (e) {
      print('Error getting sales quantity by category: $e');
      return {};
    }
  }

  Future<Map<String, int>> getSalesQuantityByPaymentMethod(
      DateTime startDate, DateTime endDate) async {
    try {
      final QuerySnapshot salesSnapshot = await FirebaseFirestore.instance
          .collection('sales')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .get();

      Map<String, int> paymentQuantities = {};

      for (var doc in salesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final paymentMethod = data['paymentMethod'] as String? ?? 'Unknown';
        final items = data['items'] as List<dynamic>;

        int totalQuantity = 0;
        for (var item in items) {
          totalQuantity += item['quantity'] as int? ?? 0;
        }

        paymentQuantities[paymentMethod] =
            (paymentQuantities[paymentMethod] ?? 0) + totalQuantity;
      }

      return paymentQuantities;
    } catch (e) {
      print('Error getting sales quantity by payment method: $e');
      return {};
    }
  }
}
