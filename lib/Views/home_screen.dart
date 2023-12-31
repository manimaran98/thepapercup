import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thepapercup/modal/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .get()
        .then((value) {
      loggedInUser = UserModel.fromMap(value.data());
      fullname = "${loggedInUser.firstName}";
      userId = "${loggedInUser.uid}";
      setState(() {});
    });
    _setLandscapeOrientation();
  }

  final formKey = GlobalKey<FormState>();
  String? errorMessage;

  @override
  void dispose() {
    _resetOrientation();
    super.dispose();
  }

  void _setLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  void _resetOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  final _formKey = GlobalKey<FormState>(); // Add this line

  User? user = FirebaseAuth.instance.currentUser;
  UserModel loggedInUser = UserModel();

  int _selectedIndex = 0;
  String fullname = "Loading...";
  String userId = "";

  void _onItemTapped(int index) {
    setState(() {
      if (index == 0) {
        _selectedIndex = index;
      }

      if (index == 1) {
        //Navigator.push(context,MaterialPageRoute(builder: (context) => const appoinment_booking()));

        _selectedIndex = index;
      }

      if (index == 2) {
        //Navigator.push(context,MaterialPageRoute(builder: (context) => const health_screening()));
        _selectedIndex = index;
      }

      if (index == 3) {
        //Navigator.push(context,MaterialPageRoute(builder: (context) => const account_screen()));
        _selectedIndex = index;
      }
    });
  }

  @override
  void didChangeDependencies() {
    precacheImage(const AssetImage('assets/homebg.jpg'), context);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(122, 81, 204, 1),
      resizeToAvoidBottomInset: true,
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(26.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                    height: 160,
                    child: Image.asset(
                      "assets/logo.png",
                      fit: BoxFit.contain,
                    )),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  // ignore: prefer_const_literals_to_create_immutables
                  children: <Widget>[
                    Text(
                      'POS',
                      style: TextStyle(
                        color: Colors.white, // White color
                        fontSize: 60, // Larger font size
                        fontWeight: FontWeight.bold, // Bold font weight
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        //currentIndex: 0,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: Colors.black),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month, color: Colors.black),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box, color: Colors.black),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined, color: Colors.black),
            label: 'Account',
          )
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        onTap: _onItemTapped,
      ),
    );
  }
}
