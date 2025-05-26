import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:thepapercup/Views/Login/login_screen.dart';
import 'package:thepapercup/Views/home_screen.dart';
import 'package:thepapercup/modal/user_model.dart';

class checkUser extends StatefulWidget {
  const checkUser({Key? key}) : super(key: key);

  @override
  State<checkUser> createState() => _checkUserState();
}

class _checkUserState extends State<checkUser> {
  String role = 'user';
  String name = 'user';
  List data = [];
  int index = 0;
  User? user = FirebaseAuth.instance.currentUser;
  UserModel loggedInUser = UserModel();

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  onSelectNotification(String? payload) async {
    //Navigator.push(context,//MaterialPageRoute(builder: (context) => viewAppoinmentDetails(bookingDetails: payload.toString(),)));
  }

  void _checkRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    final DocumentSnapshot snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .get();

    setState(() {
      role = snap['role'];
      name = snap['fullname'];
    });

    if (role != 'User') {
      navigateNext(const LoginScreen());
      Fluttertoast.showToast(msg: "Unauthorised Access");
    } else if (role == 'User') {
      navigateNext(HomeScreen(
        selectedIndex: 0,
      ));
      Fluttertoast.showToast(msg: "Welcome " + name);
    }
  }

  void navigateNext(Widget route) {
    Timer(const Duration(milliseconds: 500), () {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => route));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          color: Colors.white,
          child: const Center(
            child: CircularProgressIndicator(),
          )),
    );
  }
}
