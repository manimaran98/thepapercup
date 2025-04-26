import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:thepapercup/modal/item_modal.dart';
import 'package:thepapercup/services/image_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  _InventoryScreen createState() => _InventoryScreen();
}

class _InventoryScreen extends State<InventoryScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final ImageService _imageService = ImageService();
  String? _selectedCategory;
  String? _selectedImageUrl;
  bool _isLoading = false;

  List<String> categories = [
    'Hot Coffee',
    'Cold Coffee',
    'Tea',
    'Snacks',
    'Others'
  ];

  @override
  void initState() {
    super.initState();
  }

  void _showAddItemDialog() {
    _nameController.clear();
    _priceController.clear();
    _quantityController.clear();
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
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
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
                      int quantity = int.parse(_quantityController.text);

                      ItemModel newItem = ItemModel(
                        name: _nameController.text,
                        price: price,
                        quantity: quantity,
                        category: _selectedCategory,
                        imageUrl: _selectedImageUrl,
                      );

                      await FirebaseFirestore.instance
                          .collection('itemsForSale')
                          .add(newItem.toMap());

                      Navigator.of(context).pop();
                      Fluttertoast.showToast(
                        msg: 'Item added successfully',
                        backgroundColor: Colors.green,
                      );
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
    _quantityController.text = item.quantity?.toString() ?? '';
    _selectedCategory =
        categories.contains(item.category) ? item.category : categories.last;
    _selectedImageUrl = item.imageUrl;

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
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        }
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
                      int quantity = int.parse(_quantityController.text);

                      await FirebaseFirestore.instance
                          .collection('itemsForSale')
                          .doc(item.id)
                          .update({
                        'name': _nameController.text,
                        'price': price,
                        'quantity': quantity,
                        'category': _selectedCategory,
                        'imageUrl': _selectedImageUrl,
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
          // Show loading spinner while waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Show error message if something went wrong
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

          // Show message if no items exist
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

          // Convert the documents to ItemModel objects
          List<ItemModel> items = snapshot.data!.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; // Add the document ID to the data
            return ItemModel.fromMap(data);
          }).toList();

          // Show the list of items
          return ListView.builder(
            itemCount: items.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            item.imageUrl!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image_not_supported),
                              );
                            },
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.inventory),
                        ),
                  title: Text(
                    item.name ?? 'No name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Price: \$${item.price?.toStringAsFixed(2) ?? '0.00'}'),
                      Text('Quantity: ${item.quantity ?? 0}'),
                      Text('Category: ${item.category ?? 'Uncategorized'}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditItemDialog(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        color: Colors.red,
                        onPressed: () => _showDeleteConfirmation(item),
                      ),
                    ],
                  ),
                ),
              );
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
}
