import 'package:flutter/material.dart';
import 'package:thepapercup/Views/loginScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensure that Firebase is initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Initialize Firebase
  runApp(const MyApp()); // Replace with your app name
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

// This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'The Paper Cup',
      theme: ThemeData(
        primaryColor: Colors.blue,
      ),
      home: const loginScreen(),
    );
  }
}
