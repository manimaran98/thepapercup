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

  void handleMenuAction(String value) {
    if (value == 'End Shift') {
      // Implement end shift logic
      // Calculate and show the summary of sales
    }
  }

  void handleOpenShift() {
    // Navigate to the OpenShiftScreen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OpenShiftScreen(
          onShiftOpened: (double drawerAmount) {
            // Implement the logic to handle shift opening if needed
          },
          // Pass any required parameters to the OpenShiftScreen
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
      body: Column(
        children: [
          if (!isShiftOpen) // Display "Open Shift" button if shift is closed
            ElevatedButton(
              onPressed: handleOpenShift,
              child: const Text('Open Shift'),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: itemsForSale.length,
              itemBuilder: (context, index) {
                final item = itemsForSale[index];
                return ListTile(
                  title: Text((item.name).toString()),
                  subtitle:
                      Text('Price: ${item.price?.toStringAsFixed(2) ?? "N/A"}'),
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
      ),

      // Add a floating action button for checkout
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Implement checkout logic here
        },
        child: const Icon(Icons.shopping_cart),
      ),
    );
  }
}
