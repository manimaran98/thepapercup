import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:thepapercup/Views/Sales/open_shift.dart';
import 'package:thepapercup/modal/item_modal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:thepapercup/modal/shift_modal.dart';
import 'package:intl/intl.dart';

class SalesScreen extends StatefulWidget {
  final String userId; // Add userId as a parameter
  const SalesScreen({super.key, required this.userId});

  @override
  _SalesScreen createState() => _SalesScreen();
}

class _SalesScreen extends State<SalesScreen> {
  List<ItemModel> itemsForSale = [];
  Map<String, ItemModel> cart = {};
  bool isShiftOpen = false;
  DateTime now = DateTime.now();
  DateFormat dateFormat = DateFormat('dd-MM-yyyy');
  DateFormat timeFormat = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    checkShiftStatus();
    createSampleItems();
  }

  Future<void> checkShiftStatus() async {
    try {
      DocumentSnapshot shiftSnapshot = await FirebaseFirestore.instance
          .collection('shifts')
          .doc('current')
          .get();

      if (shiftSnapshot.exists && shiftSnapshot.data() != null) {
        var shiftData = shiftSnapshot.data() as Map<String, dynamic>;
        setState(() {
          isShiftOpen = shiftData['isOpen'] ?? false;
        });
        if (isShiftOpen) {
          await loadItemsForSale();
        }
      } else {
        // Shift does not exist, so create a closed shift
        await createClosedShift();
        // Handle case for no shift data
      }
    } catch (e) {
      // Show a toast message for the error
      Fluttertoast.showToast(
        msg: 'Error checking shift status: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> createClosedShift() async {
    // Create a closed shift in the database
    final DateTime now = DateTime.now();
    final ShiftModel closedShift = ShiftModel(
      id: 'current',
      name: 'Closed Shift',
      isOpen: false,
      startTime: timeFormat.format(now),
      endTime: timeFormat.format(now),
      userId: widget.userId,
      date: dateFormat.format(now),
      drawerAmount: 0.00,
      sales: 0.00, // Use the userId passed as a parameter
    );

    await FirebaseFirestore.instance
        .collection('shifts')
        .doc('current')
        .set(closedShift.toMap());
  }

  Future<void> loadItemsForSale() async {
    try {
      QuerySnapshot itemsSnapshot =
          await FirebaseFirestore.instance.collection('itemsForSale').get();

      List<ItemModel> loadedItems = itemsSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // If the document doesn't have an ID field, use the document ID
        if (!data.containsKey('id')) {
          // Update the document with its ID if it's missing
          doc.reference.update({'id': doc.id});
        }
        data['id'] = doc.id; // Always use the document ID
        return ItemModel.fromMap(data);
      }).toList();

      if (mounted) {
        setState(() {
          itemsForSale = loadedItems;
        });
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Error loading items: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> createSampleItems() async {
    try {
      // Check if items already exist
      QuerySnapshot itemsSnapshot =
          await FirebaseFirestore.instance.collection('itemsForSale').get();

      if (itemsSnapshot.docs.isEmpty) {
        // Create sample items
        List<Map<String, dynamic>> sampleItems = [
          {
            'name': 'Coffee',
            'price': 2.50,
            'category': 'Beverages',
            'quantity': 0,
          },
          {
            'name': 'Tea',
            'price': 2.00,
            'category': 'Beverages',
            'quantity': 0,
          },
          {
            'name': 'Cake',
            'price': 3.50,
            'category': 'Food',
            'quantity': 0,
          },
          {
            'name': 'Sandwich',
            'price': 4.00,
            'category': 'Food',
            'quantity': 0,
          },
          {
            'name': 'Water',
            'price': 1.00,
            'category': 'Beverages',
            'quantity': 0,
          },
          {
            'name': 'Cookie',
            'price': 1.50,
            'category': 'Food',
            'quantity': 0,
          },
        ];

        // Add items to Firestore with their IDs
        for (var item in sampleItems) {
          DocumentReference docRef = await FirebaseFirestore.instance
              .collection('itemsForSale')
              .add(item);

          // Update the document with its ID
          await docRef.update({'id': docRef.id});
        }

        // Reload items after adding
        await loadItemsForSale();
      } else {
        // If items exist, just load them
        await loadItemsForSale();
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error creating sample items: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
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

      // Calculate totals
      double subtotal = calculateTotal();
      double tax = subtotal * 0.1; // 10% tax
      double total = subtotal + tax;

      // Create sale document
      await FirebaseFirestore.instance.collection('sales').doc(saleId).set({
        'saleId': saleId,
        'date': now,
        'items': saleItems,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'shiftId': 'current', // Link to current shift
      });

      // Update current shift sales total
      DocumentReference shiftRef =
          FirebaseFirestore.instance.collection('shifts').doc('current');
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

      // Show success message
      Fluttertoast.showToast(
        msg: 'Sale completed successfully',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      // Show error message
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
              // Order summary
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
              // Subtotal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:'),
                  Text('\$${calculateTotal().toStringAsFixed(2)}'),
                ],
              ),
              // Tax
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tax (10%):'),
                  Text('\$${(calculateTotal() * 0.1).toStringAsFixed(2)}'),
                ],
              ),
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
                    '\$${(calculateTotal() * 1.1).toStringAsFixed(2)}',
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

  @override
  Widget build(BuildContext context) {
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
      body: isShiftOpen
          ? Row(
              children: [
                // Left side - Items Grid (70% width)
                Expanded(
                  flex: 7,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                    ),
                    itemCount: itemsForSale.length,
                    itemBuilder: (context, index) {
                      final item = itemsForSale[index];
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
                                Container(
                                  height: 2,
                                  color: Colors.red[200],
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
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
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
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
                        ),
                      );
                    },
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
                                          onPressed: () => removeFromCart(item),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
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
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Shift is currently closed',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: null, // Will be set in state
                    child: Text(
                      'Open Shift',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
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
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Close Shift'),
            content: const Text('Are you sure you want to close the shift?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Confirm'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await closeShift();
                },
              ),
            ],
          );
        },
      );
    }
  }

  void handleOpenShift() {
    // Navigate to the OpenShiftScreen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OpenShiftScreen(
          onShiftOpened: (double drawerAmount) async {
            // After shift is opened, update the state
            setState(() {
              isShiftOpen = true;
            });
            await loadItemsForSale();
          },
        ),
      ),
    );
  }

  Future<void> closeShift() async {
    try {
      // Calculate total sales from cart
      double totalSales = 0.0;
      cart.forEach((key, item) {
        if (item.price != null && item.quantity != null) {
          totalSales += item.price! * item.quantity!;
        }
      });

      // Get the current shift data
      DocumentSnapshot shiftSnapshot = await FirebaseFirestore.instance
          .collection('shifts')
          .doc('current')
          .get();

      if (shiftSnapshot.exists) {
        var shiftData = shiftSnapshot.data() as Map<String, dynamic>;
        double initialDrawerAmount = shiftData['drawerAmount'] ?? 0.0;

        // Update the shift document with end time and total sales
        await FirebaseFirestore.instance
            .collection('shifts')
            .doc('current')
            .update({
          'isOpen': false,
          'endTime': DateTime.now(),
          'sales': totalSales,
          'totalAmount': initialDrawerAmount + totalSales,
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
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error closing shift: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }
}
