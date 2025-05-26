import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:thepapercup/modal/category_model.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all categories
  Stream<List<CategoryModel>> getCategories() {
    return _firestore
        .collection('categories')
        .where('isDeleted',
            isEqualTo: false) // Filter out soft-deleted categories
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Add a new category
  Future<void> addCategory(CategoryModel category) async {
    await _firestore.collection('categories').add(category.toMap());
  }

  // Update an existing category
  Future<void> updateCategory(CategoryModel category) async {
    await _firestore
        .collection('categories')
        .doc(category.id)
        .update(category.toMap());
  }

  // Delete a category (soft delete)
  Future<void> deleteCategory(String categoryId) async {
    // Check if category is assigned to any items
    final itemsSnapshot = await _firestore
        .collection('itemsForSale')
        .where('category',
            isEqualTo: categoryId) // Assuming category is stored as ID
        .limit(1) // We only need to know if at least one item exists
        .get();

    if (itemsSnapshot.docs.isNotEmpty) {
      // Category is assigned to items, prevent deletion
      throw Exception(
          'Cannot delete category: It is assigned to inventory items.');
    }

    // Perform soft delete
    await _firestore.collection('categories').doc(categoryId).update({
      'isDeleted': true,
      'deletedAt':
          FieldValue.serverTimestamp(), // Optional: record deletion time
    });
  }
}
