import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DataCleanup {
  static Future<void> clearSalesAndInventory(BuildContext context,
      {Function? onCleanupComplete}) async {
    try {
      // Delete all items from inventory
      final inventorySnapshot =
          await FirebaseFirestore.instance.collection('itemsForSale').get();

      for (var doc in inventorySnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete all items from sales
      final salesSnapshot =
          await FirebaseFirestore.instance.collection('sales').get();

      for (var doc in salesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All sales and inventory items have been cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Call the refresh callback if provided
      if (onCleanupComplete != null) {
        onCleanupComplete();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
