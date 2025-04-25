import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:thepapercup/Views/Sales/sales.dart';
import 'package:thepapercup/modal/user_model.dart';

// ignore: must_be_immutable
class HomeScreen extends StatefulWidget {
  int selectedIndex;
  HomeScreen({super.key, required this.selectedIndex});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    getdata();
  }

  void getdata() async {
    FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .get()
        .then((value) {
      loggedInUser = UserModel.fromMap(value.data());
      fullname = "${loggedInUser.fullName}";
      userId = "${loggedInUser.uid}";
      // After fetching user data, set up the widget options
      _setupWidgetOptions();
    });
  }

  final formKey = GlobalKey<FormState>();
  String? errorMessage;
  // Define your screen widgets here
  List<Widget> _widgetOptions = [];

  void _setupWidgetOptions() {
    setState(() {
      // Now you can use userId to initialize _widgetOptions
      _widgetOptions = [
        const Text('Home Screen Placeholder'),
        SalesScreen(userId: userId), // Pass userId to SalesScreen
        const Text('Inventory Screen Placeholder'),
        const Text('Catering Screen Placeholder'),
        const Text('Account Screen Placeholder'),
      ];
    });
  }

  //final _formKey = GlobalKey<FormState>(); // Add this line

  User? user = FirebaseAuth.instance.currentUser;
  UserModel loggedInUser = UserModel();

  String fullname = "Loading...";
  String userId = "";
  void _onItemTapped(int index) {
    setState(() {
      widget.selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The build method checks if _widgetOptions is empty and shows a loader until data is loaded
    if (_widgetOptions.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color.fromRGBO(122, 81, 204, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(122, 81, 204, 1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: _widgetOptions
            .elementAt(widget.selectedIndex), // Display the selected screen
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: Color.fromRGBO(122, 81, 204, 1)),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business, color: Color.fromRGBO(122, 81, 204, 1)),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box, color: Color.fromRGBO(122, 81, 204, 1)),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined,
                color: Color.fromRGBO(122, 81, 204, 1)),
            label: 'Account',
          )
        ],
        currentIndex: widget.selectedIndex,
        selectedItemColor: const Color.fromRGBO(122, 81, 204, 1),
        onTap: _onItemTapped,
      ),
    );
  }
}
