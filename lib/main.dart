import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thepapercup/Views/loginScreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]).then((_) {
    runApp(MyApp()); // Replace with your app name
  });
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
