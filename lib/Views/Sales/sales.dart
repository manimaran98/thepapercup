import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:thepapercup/Views/Sales/open_shift.dart';
import 'package:thepapercup/modal/item_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:thepapercup/modal/shift_modal.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thepapercup/services/sales_service.dart';
import 'package:thepapercup/modal/sales_model.dart';
import 'package:thepapercup/modal/receipt_model.dart';
import 'package:thepapercup/services/receipt_service.dart';
import 'package:thepapercup/services/category_service.dart';
import 'package:thepapercup/modal/category_model.dart';

class SalesScreen extends StatefulWidget {
  final String userId;
  const SalesScreen({super.key, required this.userId});

  @override
  _SalesScreen createState() => _SalesScreen();
}

class _SalesScreen extends State<SalesScreen>
    with AutomaticKeepAliveClientMixin {
  List<ItemModel> itemsForSale = [];
  Map<String, ItemModel> cart = {};
  bool isShiftOpen = false;
  bool _isLoading = true;
  bool _isInitialized = false;
  DateTime now = DateTime.now();
  DateFormat dateFormat = DateFormat('dd-MM-yyyy');
  DateFormat timeFormat = DateFormat('HH:mm');
  bool _isFirstLoad = true;
  String? _selectedCategory;
  bool isProcessing = false;
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _qrAmountController = TextEditingController();

  List<CategoryModel> _categories = [];

  List<String> get categoriesDisplayList {
    return ['All', ..._categories.map((c) => c.name)];
  }

  List<ItemModel> get filteredItems {
    if (_selectedCategory == null || _selectedCategory == 'All') {
      return itemsForSale;
    }
    return itemsForSale
        .where((item) => item.categoryName == _selectedCategory)
        .toList();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _loadCategories();
      await loadItemsForSale();
      await checkShiftStatus();
    } catch (e) {
      print('Error initializing data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFirstLoad = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categoriesSnapshot =
          await FirebaseFirestore.instance.collection('categories').get();
      final loadedCategories = categoriesSnapshot.docs.map((doc) {
        return CategoryModel.fromMap(doc.data(), doc.id);
      }).toList();

      if (mounted) {
        setState(() {
          _categories = loadedCategories;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      Fluttertoast.showToast(
        msg: 'Error loading categories: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> checkShiftStatus() async {
    try {
      DocumentSnapshot currentShiftDoc = await FirebaseFirestore.instance
          .collection('shifts')
          .doc('current')
          .get();

      if (!mounted) return;

      if (currentShiftDoc.exists && currentShiftDoc.data() != null) {
        var currentData = currentShiftDoc.data() as Map<String, dynamic>;
        setState(() {
          isShiftOpen = currentData['isOpen'] ?? false;
        });
      } else {
        await createClosedShift();
      }
    } catch (e) {
      print('Error checking shift status: $e');
    }
  }

  Future<void> createClosedShift() async {
    final DateTime now = DateTime.now();
    final DateFormat dateFormatter = DateFormat('ddMMyyyy');
    final DateFormat timeFormatter = DateFormat('HH:mm');
    final String shiftId =
        '${dateFormatter.format(now)}_${timeFormatter.format(now)}';

    // Create a closed shift document
    await FirebaseFirestore.instance.collection('shifts').doc(shiftId).set({
      'isOpen': false,
      'startTime': timeFormatter.format(now),
      'date': dateFormatter.format(now),
      'endTime': timeFormatter.format(now),
      'userId': widget.userId,
      'drawerAmount': 0.00,
      'sales': 0.00,
      'endDrawerAmount': 0.00,
      'expectedDrawerAmount': 0.00,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Update current reference
    await FirebaseFirestore.instance.collection('shifts').doc('current').set({
      'currentShiftId': shiftId,
      'isOpen': false,
      'drawerAmount': 0.00,
      'sales': 0.00,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      setState(() {
        isShiftOpen = false;
      });
    }
  }

  Future<void> loadItemsForSale() async {
    try {
      QuerySnapshot itemsSnapshot =
          await FirebaseFirestore.instance.collection('itemsForSale').get();

      if (!mounted) return;

      List<ItemModel> loadedItems = itemsSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        final item = ItemModel.fromMap(data, doc.id);

        final category = _categories.firstWhere(
          (cat) => cat.id == item.categoryId,
          orElse: () => CategoryModel(id: '', name: 'Uncategorized'),
        );

        item.categoryName = category.name;

        return item;
      }).toList();

      setState(() {
        itemsForSale = loadedItems;
      });
    } catch (e) {
      print('Error loading items: $e');
      Fluttertoast.showToast(
        msg: 'Error loading items: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (isProcessing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing payment...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales"),
        actions: <Widget>[
          if (isShiftOpen)
            PopupMenuButton<String>(
              onSelected: handleMenuAction,
              itemBuilder: (BuildContext context) {
                return {'End Shift'}.map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isShiftOpen
            ? Row(
                key: const ValueKey('sales_view'),
                children: [
                  // Left side - Items Grid (70% width)
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        // Category Filter
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: categoriesDisplayList.length,
                            itemBuilder: (context, index) {
                              final category = categoriesDisplayList[index];
                              final isSelected = _selectedCategory == category;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: FilterChip(
                                  label: Text(category),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedCategory =
                                          selected ? category : 'All';
                                      print(
                                          'Selected category: $_selectedCategory');
                                    });
                                  },
                                  backgroundColor: Colors.grey[200],
                                  selectedColor: Colors.blue[100],
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.blue[900]
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Items Grid
                        Expanded(
                          child: itemsForSale.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No items available',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.all(8.0),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.8,
                                    crossAxisSpacing: 8.0,
                                    mainAxisSpacing: 8.0,
                                  ),
                                  itemCount: filteredItems.length,
                                  itemBuilder: (context, index) =>
                                      _buildGridItem(filteredItems[index]),
                                ),
                        ),
                      ],
                    ),
                  ),
                  // Right side - Cart (30% width)
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border(
                          left: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Cart Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Cart',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${cart.length} items',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Cart Items
                          Expanded(
                            child: cart.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Cart is empty',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(8.0),
                                    itemCount: cart.length,
                                    itemBuilder: (context, index) {
                                      final item = cart.values.elementAt(index);
                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8.0),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            children: [
                                              // Item Details
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.name ?? '',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      'RM${item.price?.toStringAsFixed(2) ?? "0.00"}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Quantity Controls
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.remove),
                                                    onPressed: () =>
                                                        removeFromCart(item),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8.0),
                                                    child: Text(
                                                      '${item.quantity}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.add),
                                                    onPressed: () {
                                                      final originalItem =
                                                          itemsForSale
                                                              .firstWhere((i) =>
                                                                  i.id ==
                                                                  item.id);
                                                      addToCart(originalItem);
                                                    },
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          // Cart Footer
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                  offset: const Offset(0, -1),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'RM${calculateTotal().toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        cart.isEmpty ? null : _handleCheckout,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                    ),
                                    child: const Text(
                                      'Checkout',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                key: const ValueKey('closed_view'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Shift is currently closed',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: handleOpenShift,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(122, 81, 204, 1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                      child: const Text(
                        'Open Shift',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void addToCart(ItemModel item) {
    if (item.id == null || item.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Invalid item ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if item is out of stock
    if (item.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item is out of stock'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      if (cart.containsKey(item.id)) {
        // Get the current quantity in cart
        int currentCartQuantity = cart[item.id]!.quantity;

        // Check if adding one more would exceed available stock
        if (currentCartQuantity >= item.quantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Cannot add more than available stock (${item.quantity})'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Update quantity of existing item
        cart[item.id] = ItemModel(
          id: item.id,
          name: item.name,
          price: item.price,
          cost: item.cost,
          quantity: currentCartQuantity + 1,
          categoryId: item.categoryId,
          categoryName: item.categoryName,
          imageUrl: item.imageUrl,
        );
      } else {
        // Add new item to cart
        cart[item.id!] = ItemModel(
          id: item.id,
          name: item.name,
          price: item.price,
          cost: item.cost,
          quantity: 1,
          categoryId: item.categoryId,
          categoryName: item.categoryName,
          imageUrl: item.imageUrl,
        );
      }
    });
  }

  void removeFromCart(ItemModel item) {
    if (item.id == null || item.id!.isEmpty) return;

    setState(() {
      if (cart.containsKey(item.id)) {
        if (cart[item.id]!.quantity > 1) {
          // Decrement quantity
          cart[item.id] = ItemModel(
            id: item.id,
            name: item.name,
            price: item.price,
            cost: item.cost,
            quantity: cart[item.id]!.quantity - 1,
            categoryId: item.categoryId,
            categoryName: item.categoryName,
            imageUrl: item.imageUrl,
          );
        } else {
          // Remove item from cart
          cart.remove(item.id);
        }
      }
    });
  }

  Future<void> _handleCheckout() async {
    if (cart.isEmpty) return;

    setState(() => isProcessing = true);

    try {
      // Show payment method selection dialog
      String? selectedPaymentMethod = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Select Payment Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.money),
                title: const Text('Cash'),
                onTap: () => Navigator.pop(context, 'Cash'),
              ),
              ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text('Card'),
                onTap: () => Navigator.pop(context, 'Card'),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('QR'),
                onTap: () => Navigator.pop(context, 'QR'),
              ),
            ],
          ),
        ),
      );

      if (selectedPaymentMethod == null) {
        setState(() => isProcessing = false);
        return;
      }

      await _processPayment(selectedPaymentMethod);
    } catch (e) {
      print('Error processing payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isProcessing = false);
    }
  }

  Future<void> _processPayment(String method) async {
    if (cart.isEmpty) return;

    setState(() => isProcessing = true);

    try {
      double total = cart.values
          .fold(0, (sum, item) => sum + (item.price * item.quantity));

      if (method == 'Cash') {
        // Show cash payment dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Cash Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total Amount: RM${total.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                TextField(
                  controller: _cashAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount Received',
                    prefixText: 'RM ',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => isProcessing = false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  double received =
                      double.tryParse(_cashAmountController.text) ?? 0;
                  if (received < total) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Amount received is less than total'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  double change = received - total;
                  Navigator.pop(context);
                  _completeSale(method, total, change: change);
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      } else if (method == 'QR') {
        // Show QR payment dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('QR Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total Amount: RM${total.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                const Text(
                    'Please complete the payment using your preferred QR payment app'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => isProcessing = false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _completeSale(method, total);
                },
                child: const Text('Complete Payment'),
              ),
            ],
          ),
        );
      } else {
        // Direct payment (Card)
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Card Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total Amount: RM${total.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                const Text(
                    'Please complete the payment using the card machine'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => isProcessing = false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _completeSale(method, total);
                },
                child: const Text('Complete Payment'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error processing payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isProcessing = false);
    }
  }

  Future<void> _completeSale(String method, double total,
      {double? change}) async {
    try {
      // Get current shift ID
      DocumentSnapshot currentDoc = await FirebaseFirestore.instance
          .collection('shifts')
          .doc('current')
          .get();

      if (!currentDoc.exists) {
        throw Exception('No active shift found');
      }

      String currentShiftId =
          (currentDoc.data() as Map<String, dynamic>)['currentShiftId'];

      print('Current Shift ID: $currentShiftId'); // Debug log

      // Get current shift data
      DocumentSnapshot shiftDoc = await FirebaseFirestore.instance
          .collection('shifts')
          .doc(currentShiftId)
          .get();

      if (!shiftDoc.exists) {
        throw Exception('Shift document not found');
      }

      double currentSales =
          (shiftDoc.data() as Map<String, dynamic>)['sales'] ?? 0.0;
      print('Current Sales: $currentSales'); // Debug log
      print('New Sale Amount: $total'); // Debug log

      // Create sale document
      final saleRef = FirebaseFirestore.instance.collection('sales').doc();
      final sale = {
        'items': cart.values
            .map((item) => {
                  'id': item.id,
                  'name': item.name,
                  'quantity': item.quantity,
                  'price': item.price,
                  'total': item.price * item.quantity,
                })
            .toList(),
        'total': total,
        'paymentMethod': method,
        'timestamp': FieldValue.serverTimestamp(),
        'change': change,
        'shiftId': currentShiftId,
      };

      // Update inventory
      final batch = FirebaseFirestore.instance.batch();

      // Add sale document
      batch.set(saleRef, sale);

      // Update shift's sales total
      batch.update(
        FirebaseFirestore.instance.collection('shifts').doc(currentShiftId),
        {
          'sales': FieldValue.increment(total),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      );

      // Update inventory quantities
      for (var item in cart.values) {
        final itemRef =
            FirebaseFirestore.instance.collection('itemsForSale').doc(item.id);

        batch.update(itemRef, {
          'quantity': FieldValue.increment(-item.quantity),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Commit the batch
      await batch.commit();

      // Verify the update
      DocumentSnapshot updatedShiftDoc = await FirebaseFirestore.instance
          .collection('shifts')
          .doc(currentShiftId)
          .get();

      double updatedSales =
          (updatedShiftDoc.data() as Map<String, dynamic>)['sales'] ?? 0.0;
      print('Updated Sales: $updatedSales'); // Debug log

      // Create receipt
      final receipt = ReceiptModel(
        id: saleRef.id,
        items: sale['items'] as List<Map<String, dynamic>>,
        total: total,
        paymentMethod: method,
        timestamp: DateTime.now(),
        change: change,
        isPrinted: false,
        isEmailed: false,
      );

      // Save receipt
      final receiptService = ReceiptService();
      await receiptService.saveReceipt(receipt);

      // Show success message and receipt
      if (!mounted) return;

      // Show receipt dialog with options
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Sale Complete'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Receipt',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...cart.values.map((item) => Text(
                      '${item.name} x${item.quantity} - RM${(item.price! * item.quantity!).toStringAsFixed(2)}',
                    )),
                const Divider(),
                Text('Total: RM${total.toStringAsFixed(2)}'),
                Text('Payment Method: $method'),
                if (change != null)
                  Text('Change: RM${change.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Text('Date: ${DateTime.now().toString()}'),
                Text('Receipt #: ${saleRef.id}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() {
                  cart.clear();
                  isProcessing = false;
                });
                await loadItemsForSale();
              },
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await receiptService.printReceipt(receipt);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error printing receipt: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Print'),
            ),
            TextButton(
              onPressed: () async {
                final emailController = TextEditingController();
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Email Receipt'),
                    content: TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Email',
                        hintText: 'Enter customer email address',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter an email address'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context);
                          try {
                            await receiptService.emailReceipt(receipt, email);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error emailing receipt: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Email'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error completing sale: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing sale: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isProcessing = false);
    }
  }

  double calculateTotal() {
    double total = 0.0;
    cart.forEach((key, item) {
      if (item.price != null && item.quantity != null) {
        total += item.price! * item.quantity!;
      }
    });
    return total;
  }

  void handleMenuAction(String value) {
    if (value == 'End Shift') {
      _showEndShiftDialog();
    }
  }

  Widget _buildGridItem(ItemModel item) {
    bool isOutOfStock = item.quantity <= 0;
    bool isLowStock = item.quantity <= 5 && item.quantity > 0;

    print('Building grid item: ${item.name}, Category: ${item.categoryName}');

    return Card(
      elevation: 2,
      color: Colors.white,
      child: Stack(
        children: [
          InkWell(
            onTap: isOutOfStock ? null : () => addToCart(item),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image_not_supported);
                          },
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 2,
                          color: Colors.red[200],
                          margin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        Text(
                          item.name ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Container(
                          height: 2,
                          color: Colors.red[200],
                          margin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        Text(
                          'RM${item.price?.toStringAsFixed(2) ?? "0.00"}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isLowStock)
                          Text(
                            'Low Stock: ${item.quantity} left',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (!isOutOfStock && !isLowStock)
                          Text(
                            'In Stock: ${item.quantity}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOutOfStock)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'OUT OF STOCK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void handleOpenShift() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OpenShiftScreen(
          onShiftOpened: (double drawerAmount) async {
            setState(() {
              isShiftOpen = true;
            });
          },
          userId: widget.userId,
        ),
      ),
    );
  }

  void _showEndShiftDialog() {
    final TextEditingController drawerController = TextEditingController();
    double expectedAmount = 0.0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Close Shift'),
              content: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('shifts')
                    .doc('current')
                    .get()
                    .then((currentDoc) async {
                  String currentShiftId = (currentDoc.data()
                      as Map<String, dynamic>)['currentShiftId'];
                  return FirebaseFirestore.instance
                      .collection('shifts')
                      .doc(currentShiftId)
                      .get();
                }),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  if (snapshot.hasData) {
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    double initialDrawer = data['drawerAmount'] ?? 0.0;
                    double sales = data['sales'] ?? 0.0;
                    expectedAmount = initialDrawer + sales;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            'Initial Drawer Amount: RM${initialDrawer.toStringAsFixed(2)}'),
                        Text('Total Sales: RM${sales.toStringAsFixed(2)}'),
                        Text(
                            'Expected Drawer Amount: RM${expectedAmount.toStringAsFixed(2)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: drawerController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Current Drawer Amount',
                            hintText: 'Enter the current amount in drawer',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                        ),
                      ],
                    );
                  }

                  return const Text('Error loading shift data');
                },
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Close Shift'),
                  onPressed: () {
                    if (drawerController.text.isEmpty) {
                      Fluttertoast.showToast(
                        msg: 'Please enter the current drawer amount',
                        backgroundColor: Colors.red,
                      );
                      return;
                    }

                    try {
                      double currentAmount =
                          double.parse(drawerController.text);
                      if (currentAmount < expectedAmount) {
                        _showDrawerDiscrepancyDialog(
                            currentAmount, expectedAmount, () {
                          Navigator.of(context).pop();
                          closeShift(currentAmount);
                        });
                      } else {
                        Navigator.of(context).pop();
                        closeShift(currentAmount);
                      }
                    } catch (e) {
                      Fluttertoast.showToast(
                        msg: 'Please enter a valid amount',
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

  void _showDrawerDiscrepancyDialog(
      double currentAmount, double expectedAmount, Function onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Warning: Drawer Discrepancy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The drawer amount is less than expected:'),
              const SizedBox(height: 10),
              Text('Expected: RM${expectedAmount.toStringAsFixed(2)}'),
              Text('Current: RM${currentAmount.toStringAsFixed(2)}'),
              Text(
                  'Difference: RM${(expectedAmount - currentAmount).toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Are you sure you want to close the shift?'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> closeShift(double endDrawerAmount) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current shift ID
      DocumentSnapshot currentDoc = await FirebaseFirestore.instance
          .collection('shifts')
          .doc('current')
          .get();

      String currentShiftId =
          (currentDoc.data() as Map<String, dynamic>)['currentShiftId'];

      // Get shift data
      DocumentSnapshot shiftSnapshot = await FirebaseFirestore.instance
          .collection('shifts')
          .doc(currentShiftId)
          .get();

      if (shiftSnapshot.exists) {
        var shiftData = shiftSnapshot.data() as Map<String, dynamic>;
        double initialDrawerAmount = shiftData['drawerAmount'] ?? 0.0;
        double sales = shiftData['sales'] ?? 0.0;
        double expectedAmount = initialDrawerAmount + sales;

        // Update the shift document with end time and final amounts
        await FirebaseFirestore.instance
            .collection('shifts')
            .doc(currentShiftId)
            .update({
          'isOpen': false,
          'endTime': DateFormat('HH:mm').format(DateTime.now()),
          'endDrawerAmount': endDrawerAmount,
          'expectedDrawerAmount': expectedAmount,
          'discrepancy': endDrawerAmount - expectedAmount,
        });

        // Update current reference
        await FirebaseFirestore.instance
            .collection('shifts')
            .doc('current')
            .update({
          'isOpen': false,
        });

        // Clear the cart
        setState(() {
          cart.clear();
          isShiftOpen = false;
        });

        Fluttertoast.showToast(
          msg: 'Shift closed successfully',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error closing shift: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _cashAmountController.dispose();
    _qrAmountController.dispose();
    super.dispose();
  }
}
