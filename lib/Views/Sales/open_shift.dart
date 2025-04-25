import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:thepapercup/Views/home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OpenShiftScreen extends StatefulWidget {
  final Function(double) onShiftOpened;

  const OpenShiftScreen({super.key, required this.onShiftOpened});

  @override
  State<OpenShiftScreen> createState() => _OpenShiftScreenState();
}

class _OpenShiftScreenState extends State<OpenShiftScreen> {
  final TextEditingController _drawerController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  void _navigateBackToSalesScreen(double drawerAmount) async {
    // Add data to Firebase when opening the shift
    final DateTime now = DateTime.now();
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      // Update the current shift document
      await firestore.collection('shifts').doc('current').set({
        'name': 'Open Shift',
        'isOpen': true,
        'startTime': now,
        'endTime': null,
        'userId': '', // Replace with the actual user ID if needed
        'drawerAmount': drawerAmount,
        'sales': 0.00,
        // Add other necessary fields
      });

      // Navigate back to the SalesScreen
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    } catch (error) {
      Fluttertoast.showToast(
        msg: 'Error opening shift: $error',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Shift'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back to the SalesScreen without opening the shift
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  selectedIndex: 1,
                ),
              ),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextFormField(
              controller: _drawerController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Drawer Amount',
                hintText: 'Enter the initial drawer amount',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Confirm'),
              onPressed: () {
                final double? drawerAmount =
                    double.tryParse(_drawerController.text);
                if (drawerAmount != null) {
                  // Call the function to open the shift and pass drawerAmount
                  widget.onShiftOpened(drawerAmount);
                  // Navigate back to SalesScreen with the new shift open
                  _navigateBackToSalesScreen(drawerAmount);
                } else {
                  Fluttertoast.showToast(
                    msg: 'Please Enter Valid Number',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
