import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:thepapercup/Views/Sales/open_shift.dart';
import 'package:thepapercup/modal/item_modal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:thepapercup/modal/shift_modal.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Load both shift status and items in parallel
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Load both shift status and items in parallel
      await Future.wait([
        checkShiftStatus(),
        loadItemsForSale(),
      ]);
    } catch (e) {
      print('Error initializing data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFirstLoad = false;
        });
      }
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

  Future<void> loadItemsForSale() async {
    try {
      QuerySnapshot itemsSnapshot =
          await FirebaseFirestore.instance.collection('itemsForSale').get();

      if (!mounted) return;

      List<ItemModel> loadedItems = itemsSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('id')) {
          doc.reference.update({'id': doc.id});
        }
        data['id'] = doc.id;
        return ItemModel.fromMap(data);
      }).toList();

      setState(() {
        itemsForSale = loadedItems;
      });
    } catch (e) {
      print('Error loading items: $e');
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
    });

    // Update current reference
    await FirebaseFirestore.instance.collection('shifts').doc('current').set({
      'currentShiftId': shiftId,
      'isOpen': false,
      'drawerAmount': 0.00,
    });

    if (mounted) {
      setState(() {
        isShiftOpen = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isFirstLoad) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(Color.fromRGBO(122, 81, 204, 1)),
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
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8.0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                      ),
                      itemCount: itemsForSale.length,
                      itemBuilder: (context, index) =>
                          _buildGridItem(itemsForSale[index]),
                    ),
                  ),
                  // Right side - Cart (30% width)
                  Container(
                    width: MediaQuery.of(context).size.width * 0.3,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
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
                          padding: const EdgeInsets.all(16.0),
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
                                'Current Order',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${cart.length} items',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Cart Items
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: cart.length,
                            itemBuilder: (context, index) {
                              final item = cart.values.elementAt(index);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8.0),
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
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '\$${item.price?.toStringAsFixed(2) ?? "0.00"}',
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
                                                Icons.remove_circle_outline),
                                            iconSize: 20,
                                            onPressed: () =>
                                                removeFromCart(item),
                                          ),
                                          Text(
                                            '${item.quantity}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.add_circle_outline),
                                            iconSize: 20,
                                            onPressed: () => addToCart(item),
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
                        // Cart Footer with Total and Checkout
                        Container(
                          padding: const EdgeInsets.all(16.0),
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
                                    'Sub Total',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '\$${calculateTotal().toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      cart.isEmpty ? null : showCheckoutDialog,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text(
                                    'Proceed to Checkout',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
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
      print('Debug - Invalid item ID: ${item.toMap()}'); // Add debug print
      Fluttertoast.showToast(
        msg: 'Error: Invalid item ID',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add ${item.name ?? "Item"}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Price: \$${item.price?.toStringAsFixed(2) ?? "0.00"}'),
              const SizedBox(height: 8),
              if (cart.containsKey(item.id))
                Text(
                  'Current quantity in cart: ${cart[item.id]!.quantity ?? 0}',
                  style: const TextStyle(fontSize: 14),
                ),
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
              child: const Text('Add'),
              onPressed: () {
                setState(() {
                  if (cart.containsKey(item.id)) {
                    cart[item.id]!.quantity =
                        (cart[item.id]!.quantity ?? 0) + 1;
                  } else {
                    cart[item.id!] = ItemModel(
                      id: item.id,
                      name: item.name,
                      price: item.price,
                      category: item.category,
                      quantity: 1,
                    );
                  }
                });
                Navigator.of(context).pop();
                Fluttertoast.showToast(
                  msg: 'Item added to cart',
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                );
              },
            ),
          ],
        );
      },
    );
  }

  void removeFromCart(ItemModel item) {
    setState(() {
      if (cart.containsKey(item.id)) {
        if (cart[item.id]!.quantity! > 1) {
          cart[item.id]!.quantity = cart[item.id]!.quantity! - 1;
        } else {
          cart.remove(item.id);
        }
      }
    });
  }

  Future<void> processSale() async {
    try {
      final DateTime now = DateTime.now();
      final String saleId = DateTime.now().millisecondsSinceEpoch.toString();

      // Get current shift ID
      DocumentSnapshot currentDoc = await FirebaseFirestore.instance
          .collection('shifts')
          .doc('current')
          .get();

      String currentShiftId =
          (currentDoc.data() as Map<String, dynamic>)['currentShiftId'];

      // Create sale items list
      List<Map<String, dynamic>> saleItems = cart.values
          .map((item) => {
                'itemId': item.id,
                'name': item.name,
                'price': item.price,
                'quantity': item.quantity,
                'total': item.price! * item.quantity!,
              })
          .toList();

      // Calculate total
      double total = calculateTotal();

      // Create sale document
      await FirebaseFirestore.instance.collection('sales').doc(saleId).set({
        'saleId': saleId,
        'date': now,
        'items': saleItems,
        'total': total,
        'shiftId': currentShiftId,
      });

      // Update current shift sales total
      DocumentReference shiftRef =
          FirebaseFirestore.instance.collection('shifts').doc(currentShiftId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot shiftDoc = await transaction.get(shiftRef);
        if (shiftDoc.exists) {
          double currentSales =
              (shiftDoc.data() as Map<String, dynamic>)['sales'] ?? 0.0;
          transaction.update(shiftRef, {
            'sales': currentSales + total,
          });
        }
      });

      // Clear cart after successful sale
      setState(() {
        cart.clear();
      });

      Fluttertoast.showToast(
        msg: 'Sale completed successfully',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error processing sale: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void showCheckoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Checkout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Items list
              ...cart.values.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${item.name} x${item.quantity}'),
                        Text(
                            '\$${(item.price! * item.quantity!).toStringAsFixed(2)}'),
                      ],
                    ),
                  )),
              const Divider(),
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${calculateTotal().toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await processSale();
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        );
      },
    );
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
                            'Initial Drawer Amount: \$${initialDrawer.toStringAsFixed(2)}'),
                        Text('Total Sales: \$${sales.toStringAsFixed(2)}'),
                        Text(
                            'Expected Drawer Amount: \$${expectedAmount.toStringAsFixed(2)}',
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
              Text('Expected: \$${expectedAmount.toStringAsFixed(2)}'),
              Text('Current: \$${currentAmount.toStringAsFixed(2)}'),
              Text(
                  'Difference: \$${(expectedAmount - currentAmount).toStringAsFixed(2)}',
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

  Widget _buildGridItem(ItemModel item) {
    return Card(
      elevation: 2,
      color: Colors.white,
      child: InkWell(
        onTap: () => addToCart(item),
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
                      '\$${item.price?.toStringAsFixed(2) ?? "0.00"}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
