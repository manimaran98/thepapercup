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
    QuerySnapshot itemsSnapshot =
        await FirebaseFirestore.instance.collection('itemsForSale').get();

    List<ItemModel> loadedItems =
        itemsSnapshot.docs.map((doc) => ItemModel.fromMap(doc.data())).toList();

    setState(() {
      itemsForSale = loadedItems;
    });
  }

  void addToCart(ItemModel item) {
    // Implement add to cart logic
    if (item.id != null) {
      setState(() {
        if (cart.containsKey(item.id!)) {
          cart[item.id!]!.quantity = (cart[item.id!]!.quantity ?? 0) + 1;
        } else {
          cart[item.id!] = item;
          cart[item.id!]!.quantity = 1;
        }
      });
    }
  }

  void removeFromCart(ItemModel item) {
    // Implement remove from cart logic
    if (item.id != null && cart.containsKey(item.id!)) {
      setState(() {
        cart[item.id!]!.quantity = (cart[item.id!]!.quantity ?? 0) - 1;
        if (cart[item.id!]!.quantity! <= 0) {
          cart.remove(item.id!);
        }
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales"),
        actions: <Widget>[
          if (isShiftOpen) // Only show the End Shift option when shift is open
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
      body: Center(
        child: isShiftOpen
            ? Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: itemsForSale.length,
                      itemBuilder: (context, index) {
                        final item = itemsForSale[index];
                        return ListTile(
                          title: Text((item.name).toString()),
                          subtitle: Text(
                              'Price: ${item.price?.toStringAsFixed(2) ?? "N/A"}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              if (item.price != null) {
                                addToCart(item);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Shift is currently closed',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: handleOpenShift,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                    child: const Text(
                      'Open Shift',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: isShiftOpen
          ? FloatingActionButton(
              onPressed: () {
                // Implement checkout logic here
              },
              child: const Icon(Icons.shopping_cart),
            )
          : null,
    );
  }
}
