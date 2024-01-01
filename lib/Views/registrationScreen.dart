import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:thepapercup/Views/home_screen.dart';
import 'package:thepapercup/modal/user_model.dart';

class registrationScreen extends StatefulWidget {
  const registrationScreen({super.key});

  @override
  State<registrationScreen> createState() => _registrationScreenState();
}

class _registrationScreenState extends State<registrationScreen> {
  final auth = FirebaseAuth.instance;

  // string for displaying the error Message
  String? errorMessage;

  // form key
  final formKey = GlobalKey<FormState>();

  //editingController
  final firstNameEditingController = TextEditingController();
  final mobileEditingController = TextEditingController();
  final emailEditingController = TextEditingController();
  final passwordEditingController = TextEditingController();
  final confirmPasswordEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //name field
    final fullNameField = TextFormField(
      autofocus: false,
      controller: firstNameEditingController,
      keyboardType: TextInputType.text,
      validator: (value) {
        RegExp regex = RegExp(r'^.{3,}$');
        if (value!.isEmpty) {
          return ("First Name is Required for Registration");
        }

        if (!regex.hasMatch(value)) {
          return ("Please Enter Valid Name Min. 3 Characters");
        }
      },
      onSaved: (value) {
        firstNameEditingController.text = value!;
      },
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.account_box_outlined,
            color: Colors.white), // Icon color
        contentPadding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
        hintText: 'First Name',
        hintStyle: const TextStyle(color: Colors.white), // Hint text color
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Colors.white), // Border color when field is enabled
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Colors.white), // Border color when field is focused
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      style: const TextStyle(color: Colors.white), // Input text color
    );

    //Mobile field
    final mobileField = TextFormField(
      autofocus: false,
      controller: mobileEditingController,
      keyboardType: TextInputType.text,
      validator: (value) {
        // ignore: valid_regexps
        RegExp regex = RegExp('^.{10,}');
        if (value!.isEmpty) {
          return ("Mobile is Required for Registration");
        }

        if (!regex.hasMatch(value)) {
          return ("Please Enter Valid Mobile Number");
        }

        return null;
      },
      onSaved: (value) {
        mobileEditingController.text = value!;
      },
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.account_box_outlined,
            color: Colors.white), // Icon color
        contentPadding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
        hintText: 'Mobile Number',
        hintStyle: const TextStyle(color: Colors.white), // Hint text color
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Colors.white), // Border color when field is enabled
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Colors.white), // Border color when field is focused
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      style: const TextStyle(color: Colors.white), // Input text color
    );

    //email field
    final emailField = TextFormField(
      autofocus: false,
      controller: emailEditingController,
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value!.isEmpty) {
          return ("Please Enter Your Email Address");
        }

        if (!RegExp("^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+.[a-z]").hasMatch(value)) {
          return ("Please Enter a valid Email");
        }

        return null;
      },
      onSaved: (value) {
        emailEditingController.text = value!;
      },
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.mail, color: Colors.white), // Icon color
        contentPadding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
        hintText: 'Email',
        hintStyle: const TextStyle(color: Colors.white), // Hint text color
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Colors.white), // Border color when field is enabled
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Colors.white), // Border color when field is focused
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      style: const TextStyle(color: Colors.white), // Input text color
    );

    //Password field
    final passwordField = TextFormField(
      autofocus: false,
      controller: passwordEditingController,
      obscureText: true,
      validator: (value) {
        RegExp regex = RegExp(r'^.{6,}$');
        if (value!.isEmpty) {
          return ("Password is Required for Login");
        }

        if (!regex.hasMatch(value)) {
          return ("Please Enter Valid Password Min. 6 Characters");
        }
      },
      onSaved: (value) {
        passwordEditingController.text = value!;
      },
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        prefixIcon:
            const Icon(Icons.vpn_key, color: Colors.white), // Icon color
        contentPadding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
        hintText: 'Password',
        hintStyle: const TextStyle(color: Colors.white), // Hint text color
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Colors.white), // Border color when field is enabled
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Colors.white), // Border color when field is focused
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      style: const TextStyle(color: Colors.white), // Input text color
    );

    //Confirm Password field
    final confirmPasswordField = TextFormField(
      autofocus: false,
      controller: confirmPasswordEditingController,
      obscureText: true,
      validator: (value) {
        if (confirmPasswordEditingController.text !=
            passwordEditingController.text) {
          return "Password did not match.";
        }
      },
      onSaved: (value) {
        confirmPasswordEditingController.text = value!;
      },
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        prefixIcon:
            const Icon(Icons.vpn_key, color: Colors.white), // Icon color
        contentPadding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
        hintText: 'Confirm Password',
        hintStyle: const TextStyle(color: Colors.white), // Hint text color
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Colors.white), // Border color when field is enabled
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
              color: Colors.white), // Border color when field is focused
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      style: const TextStyle(color: Colors.white), // Input text color
    );

    final registerButton = Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(30),
      color: Colors.white,
      child: MaterialButton(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
        minWidth: MediaQuery.of(context).size.width,
        onPressed: () {
          signUp(emailEditingController.text, passwordEditingController.text);
        },
        child: const Text(
          "SignUp",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 20,
              color: Color.fromRGBO(122, 81, 204, 1),
              fontWeight: FontWeight.bold),
        ),
      ),
    );

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
              child: Form(
                key: formKey,
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
                    const SizedBox(height: 15),
                    fullNameField,
                    const SizedBox(height: 15),
                    mobileField,
                    const SizedBox(height: 15),
                    emailField,
                    const SizedBox(height: 15),
                    passwordField,
                    const SizedBox(height: 15),
                    confirmPasswordField,
                    const SizedBox(height: 15),
                    registerButton,
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  void signUp(String email, String password) async {
    if (formKey.currentState!.validate()) {
      try {
        await auth.createUserWithEmailAndPassword(
            email: email, password: password);
        postDetailsToFirestore();
      } on FirebaseAuthException catch (error) {
        // Error handling with FirebaseAuthException
        switch (error.code) {
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
      } catch (e) {
        // Generic error handling if the exception is not a FirebaseAuthException
        Fluttertoast.showToast(msg: e.toString());
        print(e);
      }
    }
  }

  postDetailsToFirestore() async {
    // calling our firestore
    // calling our user model
    // sedning these values

    FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
    User? user = auth.currentUser;

    UserModel userModel = UserModel();

    // writing all the values
    userModel.email = user!.email;
    userModel.uid = user.uid;
    userModel.fullName = firstNameEditingController.text;
    userModel.mobile = mobileEditingController.text;
    userModel.birthDate = '';
    userModel.gender = '';
    userModel.role = 'User';

    await firebaseFirestore
        .collection("users")
        .doc(user.uid)
        .set(userModel.toMap());
    Fluttertoast.showToast(msg: "Account created successfully :) ");

    // ignore: use_build_context_synchronously
    Navigator.pushAndRemoveUntil(
        (context),
        MaterialPageRoute(
            builder: (context) => HomeScreen(
                  selectedIndex: 0,
                )),
        (route) => false);
  }
}
