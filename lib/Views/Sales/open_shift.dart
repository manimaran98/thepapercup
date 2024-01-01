import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:thepapercup/Views/home_screen.dart';

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

  void _navigateBackToSalesScreen() {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => HomeScreen(
                  selectedIndex: 1,
                ))); // Navigate back to the previous screen (SalesScreen)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Shift'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBackToSalesScreen, // Call the navigation function
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
                  widget.onShiftOpened(drawerAmount);
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
