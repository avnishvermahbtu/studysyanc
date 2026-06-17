import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studysync/features/navigation/main_navigation_screen.dart';
import 'package:studysync/features/routine/screens/routine_model.dart';
import 'package:studysync/features/routine/screens/routine_screen.dart';
import 'package:studysync/login_page.dart';
import 'package:studysync/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Explicitly enable offline support & local caching for Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Firebase App',
      home: FirebaseAuth.instance.currentUser == null
          ? const LoginPage()
          : const MainNavigationScreen(),
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