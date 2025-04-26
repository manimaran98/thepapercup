import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:thepapercup/Views/home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OpenShiftScreen extends StatefulWidget {
  final Function(double) onShiftOpened;
  final String? userId;

  const OpenShiftScreen({
    super.key,
    required this.onShiftOpened,
    this.userId,
  });

  @override
  State<OpenShiftScreen> createState() => _OpenShiftScreenState();
}

class _OpenShiftScreenState extends State<OpenShiftScreen> {
  final TextEditingController _drawerController = TextEditingController();
  bool _isLoading = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkExistingShift();
  }

  Future<void> _checkExistingShift() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot currentDoc = await FirebaseFirestore.instance
          .collection('shifts')
          .doc('current')
          .get();

      if (currentDoc.exists) {
        Map<String, dynamic> data = currentDoc.data() as Map<String, dynamic>;
        if (data['isOpen'] == true) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(selectedIndex: 1),
              ),
            );
            Fluttertoast.showToast(
              msg: 'A shift is already open',
              backgroundColor: Colors.orange,
            );
          }
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error checking shift status: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _generateShiftId() {
    final now = DateTime.now();
    final DateFormat formatter = DateFormat('ddMMyyyy_HH:mm');
    return formatter.format(now);
  }

  Future<void> _openShift(double drawerAmount) async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      DocumentSnapshot currentDoc = await FirebaseFirestore.instance
          .collection('shifts')
          .doc('current')
          .get();

      if (currentDoc.exists) {
        Map<String, dynamic> data = currentDoc.data() as Map<String, dynamic>;
        if (data['isOpen'] == true) {
          Fluttertoast.showToast(
            msg: 'A shift is already open',
            backgroundColor: Colors.orange,
          );
          return;
        }
      }

      final DateTime now = DateTime.now();
      final String shiftId = _generateShiftId();
      final DateFormat dateFormatter = DateFormat('ddMMyyyy');
      final DateFormat timeFormatter = DateFormat('HH:mm');

      await FirebaseFirestore.instance.collection('shifts').doc(shiftId).set({
        'isOpen': true,
        'startTime': timeFormatter.format(now),
        'date': dateFormatter.format(now),
        'endTime': null,
        'userId': widget.userId ?? '',
        'drawerAmount': drawerAmount,
        'sales': 0.00,
        'endDrawerAmount': 0.00,
        'expectedDrawerAmount': drawerAmount,
      });

      await FirebaseFirestore.instance.collection('shifts').doc('current').set({
        'currentShiftId': shiftId,
        'isOpen': true,
        'drawerAmount': drawerAmount,
        'userId': widget.userId ?? '',
      });

      widget.onShiftOpened(drawerAmount);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(selectedIndex: 1),
          ),
        );
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: 'Error opening shift: $error',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Shift'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isProcessing
              ? null
              : () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomeScreen(selectedIndex: 1),
                    ),
                  );
                },
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _drawerController,
                    keyboardType: TextInputType.number,
                    enabled: !_isProcessing,
                    decoration: const InputDecoration(
                      labelText: 'Starting Drawer Amount',
                      hintText: 'Enter the starting amount in the drawer',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(122, 81, 204, 1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isProcessing
                        ? null
                        : () {
                            if (_drawerController.text.isEmpty) {
                              Fluttertoast.showToast(
                                msg: 'Please enter a drawer amount',
                                backgroundColor: Colors.red,
                              );
                              return;
                            }

                            try {
                              final double amount =
                                  double.parse(_drawerController.text);
                              _openShift(amount);
                            } catch (e) {
                              Fluttertoast.showToast(
                                msg: 'Please enter a valid amount',
                                backgroundColor: Colors.red,
                              );
                            }
                          },
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Open Shift',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
