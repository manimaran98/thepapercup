import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    _setLandscapeOrientation();
  }

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

  // Add these lines
  String _email = '';
  String _password = '';

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
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      // Sets minimum size of the button
                      minimumSize:
                          Size(150, 50), // Width and Height respectively
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
                ],
              ),
            ),
          ),
        ));
  }
}
