import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:thepapercup/modal/item_model.dart';
import 'package:thepapercup/services/image_service.dart';
import 'package:thepapercup/services/category_service.dart';
import 'package:thepapercup/modal/category_model.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  _InventoryScreen createState() => _InventoryScreen();
}

class _InventoryScreen extends State<InventoryScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final ImageService _imageService = ImageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<ItemModel> items = [];
  String? _selectedCategory;
  String? _selectedImageUrl;
  bool _isLoading = true;

  List<CategoryModel> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _quantityController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      // Listen to real-time updates for itemsForSale
      _firestore.collection('itemsForSale').snapshots().listen((snapshot) {
        if (!mounted) return; // Check if the widget is still mounted
        List<ItemModel> loadedItems = snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return ItemModel.fromMap(data, doc.id); // Use the fromMap constructor
        }).toList();

        setState(() {
          items = loadedItems; // Update the items list
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error loading items: $e');
      Fluttertoast.showToast(
        msg: 'Error loading items: $e',
        backgroundColor: Colors.red,
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      CategoryService().getCategories().listen((categories) {
        if (mounted) {
          setState(() {
            _categories = categories;
          });
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
      // Optionally show a toast or other error feedback
    }
  }

  void _showAddItemDialog() {
    _nameController.clear();
    _priceController.clear();
    _costController.clear();
    _quantityController.clear();
    _imageUrlController.clear();
    _selectedCategory = null;
    _selectedImageUrl = null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        String? imageUrl =
                            await _imageService.pickAndUploadImage();
                        if (imageUrl != null) {
                          setState(() {
                            _selectedImageUrl = imageUrl;
                          });
                        }
                      },
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _selectedImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _selectedImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                        Icons.image_not_supported);
                                  },
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 50),
                                  Text('Tap to add image'),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                        prefixText: 'RM ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cost',
                        border: OutlineInputBorder(),
                        prefixText: 'RM ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category),
                      ),
                      value: _selectedCategory,
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Add'),
                  onPressed: () async {
                    if (_nameController.text.isEmpty ||
                        _priceController.text.isEmpty ||
                        _costController.text.isEmpty ||
                        _quantityController.text.isEmpty ||
                        _selectedCategory == null) {
                      Fluttertoast.showToast(
                        msg: 'Please fill all fields',
                        backgroundColor: Colors.red,
                      );
                      return;
                    }

                    try {
                      double price = double.parse(_priceController.text);
                      double cost = double.parse(_costController.text);
                      int quantity = int.parse(_quantityController.text);

                      final newItem = ItemModel(
                        id: '',
                        name: _nameController.text,
                        price: price,
                        cost: cost,
                        quantity: quantity,
                        category: _selectedCategory!,
                        imageUrl: _selectedImageUrl,
                      );

                      await FirebaseFirestore.instance
                          .collection('itemsForSale')
                          .add(newItem.toMap());

                      if (mounted) {
                        Navigator.of(context).pop();
                        Fluttertoast.showToast(
                          msg: 'Item added successfully',
                          backgroundColor: Colors.green,
                        );
                      }
                    } catch (e) {
                      Fluttertoast.showToast(
                        msg: 'Error adding item: $e',
                        backgroundColor: Colors.red,
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditItemDialog(ItemModel item) {
    _nameController.text = item.name ?? '';
    _priceController.text = item.price?.toString() ?? '';
    _costController.text = item.cost?.toString() ?? '';
    _quantityController.text = item.quantity?.toString() ?? '';
    _imageUrlController.text = item.imageUrl ?? '';
    _selectedCategory = item.category;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        String? imageUrl =
                            await _imageService.pickAndUploadImage();
                        if (imageUrl != null) {
                          // Delete old image if exists
                          if (_selectedImageUrl != null) {
                            await _imageService.deleteImage(_selectedImageUrl!);
                          }
                          setState(() {
                            _selectedImageUrl = imageUrl;
                          });
                        }
                      },
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _selectedImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _selectedImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                        Icons.image_not_supported);
                                  },
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 50),
                                  Text('Tap to add image'),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                        prefixText: 'RM ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cost',
                        border: OutlineInputBorder(),
                        prefixText: 'RM ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category),
                      ),
                      value: _selectedCategory,
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    if (_nameController.text.isEmpty ||
                        _priceController.text.isEmpty ||
                        _costController.text.isEmpty ||
                        _quantityController.text.isEmpty ||
                        _selectedCategory == null) {
                      Fluttertoast.showToast(
                        msg: 'Please fill all fields',
                        backgroundColor: Colors.red,
                      );
                      return;
                    }

                    try {
                      double price = double.parse(_priceController.text);
                      double cost = double.parse(_costController.text);
                      int quantity = int.parse(_quantityController.text);

                      await FirebaseFirestore.instance
                          .collection('itemsForSale')
                          .doc(item.id)
                          .update({
                        'name': _nameController.text,
                        'price': price,
                        'cost': cost,
                        'quantity': quantity,
                        'category': _selectedCategory,
                        'imageUrl': _imageUrlController.text.isNotEmpty
                            ? _imageUrlController.text
                            : null,
                      });

                      Navigator.of(context).pop();
                      Fluttertoast.showToast(
                        msg: 'Item updated successfully',
                        backgroundColor: Colors.green,
                      );
                    } catch (e) {
                      Fluttertoast.showToast(
                        msg: 'Error updating item: $e',
                        backgroundColor: Colors.red,
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddItemDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('itemsForSale')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inventory,
                    size: 60,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No items in inventory',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showAddItemDialog,
                    child: const Text('Add Item'),
                  ),
                ],
              ),
            );
          }

          List<ItemModel> items = snapshot.data!.docs.map((doc) {
            return ItemModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildItemCard(item);
            },
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(ItemModel item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this item?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                Navigator.of(context).pop(true);
                try {
                  // Delete image if exists
                  if (item.imageUrl != null) {
                    await _imageService.deleteImage(item.imageUrl!);
                  }

                  // Delete item document
                  await FirebaseFirestore.instance
                      .collection('itemsForSale')
                      .doc(item.id)
                      .delete();

                  Fluttertoast.showToast(
                    msg: 'Item deleted successfully',
                    backgroundColor: Colors.green,
                  );
                } catch (e) {
                  Fluttertoast.showToast(
                    msg: 'Error deleting item: $e',
                    backgroundColor: Colors.red,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemCard(ItemModel item) {
    // Find the category name using the item's category ID
    String categoryName = 'Uncategorized'; // Default category name

    if (item.category != null &&
        item.category!.isNotEmpty &&
        _categories.isNotEmpty) {
      try {
        final foundCategory = _categories.firstWhere(
          (category) => category.id == item.category,
          orElse: () => CategoryModel(
              id: '', name: 'Uncategorized'), // Provide a default category
        );
        categoryName = foundCategory.name;
      } catch (e) {
        // Catch potential errors during firstWhere if orElse somehow fails (shouldn't happen but for safety)
        print('Error finding category for item ${item.name}: $e');
        categoryName = 'Unknown Category'; // Another fallback
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: 8.0, vertical: 4.0), // Adjusted margin
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          // Use a Row for the main layout
          crossAxisAlignment:
              CrossAxisAlignment.start, // Align items to the top
          children: [
            // Item Image (Optional)
            Container(
              // Use a Container to give the image a fixed size
              width: 80, // Fixed width for the image container
              height: 80, // Fixed height for the image container
              margin: const EdgeInsets.only(
                  right: 12.0), // Add some space to the right of the image
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                color: Colors.grey[200], // Placeholder background color
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.image_not_supported,
                              size: 50,
                              color:
                                  Colors.grey); // Adjusted icon size and color
                        },
                      )
                    : const Center(
                        // Centered placeholder icon
                        child: Icon(Icons.image_not_supported,
                            size: 40,
                            color: Colors.grey), // Adjusted icon size and color
                      ),
              ),
            ),
            // Item Details
            Expanded(
              // Use Expanded to make the text details take the available space
              child: Column(
                // Stack text details vertically
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Align text to the left
                children: [
                  Text(
                    item.name ?? '',
                    style: const TextStyle(
                        fontSize: 16.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Category: $categoryName', // Display category name
                    style: const TextStyle(
                        fontSize: 13.0,
                        color: Colors
                            .blueGrey), // Adjusted font size and color for category
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Price: RM${item.price?.toStringAsFixed(2) ?? "0.00"}',
                    style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500), // Adjusted font style
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Cost: RM${item.cost?.toStringAsFixed(2) ?? "0.00"}',
                    style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500), // Adjusted font style
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Quantity: ${item.quantity ?? 0}',
                    style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500), // Adjusted font style
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              // Use a Column for the action buttons
              mainAxisSize:
                  MainAxisSize.min, // Make the column take minimum space
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center buttons vertically
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20), // Adjusted icon size
                  padding: EdgeInsets.zero, // Remove padding
                  constraints: const BoxConstraints(), // Remove constraints
                  onPressed: () => _showEditItemDialog(item),
                ),
                const SizedBox(height: 8.0), // Space between buttons
                IconButton(
                  icon: const Icon(Icons.delete,
                      size: 20,
                      color: Colors.red), // Adjusted icon size and color
                  padding: EdgeInsets.zero, // Remove padding
                  constraints: const BoxConstraints(), // Remove constraints
                  onPressed: () => _showDeleteConfirmation(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
