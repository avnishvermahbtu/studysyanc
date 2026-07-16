import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studysync/features/navigation/main_navigation_screen.dart';
import 'package:studysync/features/routine/screens/routine_model.dart';
import 'package:studysync/features/routine/screens/routine_screen.dart';
import 'package:studysync/login_page.dart';
import 'package:studysync/firebase_options.dart';
import 'package:studysync/features/group_study/screens/auto_join_screen.dart';
import 'package:studysync/core/theme/theme_manager.dart';
import 'package:studysync/core/services/notification_service.dart';
import 'package:studysync/core/services/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize theme manager configuration
  await ThemeManager.init();

  // Initialize subscription and daily limits tracker
  await SubscriptionService().init();

  // Explicitly enable offline support & local caching for Firestore
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint("Failed to set Firestore settings: $e");
  }

  runApp(MyApp());

  // Initialize notifications in the background after first frame to prevent black startup screen
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService().init();
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeManager.isLightNotifier,
      builder: (context, isLight, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Firebase App',
          themeMode: ThemeMode.dark,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xfff1f5f9),
            primaryColor: const Color(0xff6366f1),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xff020617),
            primaryColor: const Color(0xff6366f1),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
          ),
          home: FirebaseAuth.instance.currentUser == null
              ? const LoginPage()
              : const MainNavigationScreen(),
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');
        if (uri.path.startsWith('/join')) {
          String? roomCode;
          if (uri.pathSegments.length > 1) {
            roomCode = uri.pathSegments[1];
          } else {
            roomCode = uri.queryParameters['code'];
          }
          if (roomCode != null && roomCode.isNotEmpty) {
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => AutoJoinScreen(roomCode: roomCode!),
            );
          }
        }
        return null;
      },
    );
  },
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