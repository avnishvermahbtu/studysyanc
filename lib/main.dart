import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:studysync/features/navigation/main_navigation_screen.dart';
import 'package:studysync/features/routine/screens/routine_model.dart';
import 'package:studysync/features/routine/screens/routine_screen.dart';
import 'package:studysync/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Firebase App',
      home: MainNavigationScreen() ,
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Firebase Connected"),
      ),
      body: Center(
        child: Text(
          "Firebase Successfully Connected 🚀",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}