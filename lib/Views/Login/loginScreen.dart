import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:thepapercup/Validation/checkUser.dart';
import 'package:thepapercup/Views/Login/registrationScreen.dart';

// ignore: camel_case_types
class loginScreen extends StatefulWidget {
  const loginScreen({super.key});

  @override
  State<loginScreen> createState() => _loginScreenState();
}

class _loginScreenState extends State<loginScreen> {
  @override
  void initState() {
    super.initState();
  }

  final formKey = GlobalKey<FormState>();
  String? errorMessage;

  final _formKey = GlobalKey<FormState>(); // Add this line

  String _email = '';
  String _password = '';
  //Firebase
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color.fromRGBO(122, 81, 204, 1),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(122, 81, 204, 1),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                      height: 200,
                      child: Image.asset(
                        "assets\\logo.png",
                        fit: BoxFit.contain,
                      )),
                  const Text(
                    'POS',
                    style: TextStyle(
                      color: Colors.white, // White color
                      fontSize: 60, // Larger font size
                      fontWeight: FontWeight.bold, // Bold font weight
                    ),
                  ),
                  const SizedBox(
                    height: 150,
                  ),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(
                        color: Colors.white, // Set label text color to white
                        fontSize: 16, // Set the font size
                        fontWeight: FontWeight.bold, // Make the text bold
                      ),
                      hintText: 'Enter your email', // Placeholder text
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(
                            0.5), // Set hint text color to a slightly transparent white
                        fontSize: 16, // Set the font size
                        fontWeight: FontWeight.bold, // Make the text bold
                      ),
                      enabledBorder: const OutlineInputBorder(
                        // Normal border
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        // Border when TextFormField is selected
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                    onSaved: (value) => _email = value!,
                    style: const TextStyle(
                      color: Colors.white, // Set input text color to white
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(
                        color: Colors.white, // Set label text color to white
                        fontSize: 16, // Set the font size
                        fontWeight: FontWeight.bold, // Make the text bold
                      ),
                      hintText: 'Enter your password', // Placeholder text
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(
                            0.5), // Set hint text color to a slightly transparent white
                        fontSize: 16, // Set the font size
                        fontWeight: FontWeight.bold, // Make the text bold
                      ),
                      enabledBorder: const OutlineInputBorder(
                        // Normal border
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        // Border when TextFormField is selected
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    obscureText: true, // Use this to hide the password input
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                    onSaved: (value) => _password = value!,
                    style: const TextStyle(
                      color: Colors.white, // Set input text color to white
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          // Sets minimum size of the button
                          minimumSize: const Size(
                              150, 50), // Width and Height respectively
                          // Padding inside the button
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 20),
                          // The shape and look of the button
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          // Your onPressed function
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            // Your login logic here
                            signIn(_email, _password);
                          }
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 20, // Increase font size
                            fontWeight: FontWeight.bold, // Bold text
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          // Sets minimum size of the button
                          minimumSize: const Size(
                              150, 50), // Width and Height respectively
                          // Padding inside the button
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 20),
                          // The shape and look of the button
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const registrationScreen()));
                        },
                        child: const Text(
                          'Registration',
                          style: TextStyle(
                            fontSize: 20, // Increase font size
                            fontWeight: FontWeight.bold, // Bold text
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  void signIn(String email, String password) async {
    if (_formKey.currentState!.validate()) {
      try {
        await _auth
            .signInWithEmailAndPassword(email: email, password: password)
            .then((uid) => {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (context) => const checkUser())),
                });
      } on FirebaseAuthException catch (error) {
        switch (error.code) {
          case "permission-denied":
            errorMessage = "You access is denied";
            break;
          case "network-request-failed":
            errorMessage = "You must have an active internet for Login.";
            break;

          case "invalid-email":
            errorMessage = "Your email address appears to be malformed.";

            break;
          case "wrong-password":
            errorMessage = "Your password is wrong.";
            break;
          case "user-not-found":
            errorMessage = "User with this email doesn't exist.";
            break;
          case "user-disabled":
            errorMessage = "User with this email has been disabled.";
            break;
          case "too-many-requests":
            errorMessage = "Too many requests";
            break;
          case "operation-not-allowed":
            errorMessage = "Signing in with Email and Password is not enabled.";
            break;
          default:
            errorMessage = "An undefined Error happened.";
        }
        Fluttertoast.showToast(msg: errorMessage!);
        print(error.code);
      }
    }
  }
}
