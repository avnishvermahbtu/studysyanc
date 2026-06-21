import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysync/features/navigation/main_navigation_screen.dart';
import 'package:studysync/signup_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:studysync/features/group_study/screens/auto_join_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool hidePassword = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff0f172a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10),
          ),
          title: Row(
            children: [
              Icon(
                title == "Success" ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                color: title == "Success" ? const Color(0xff10b981) : const Color(0xff6366f1),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Color(0xff6366f1), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showAlert("Alert!", "Please enter email and password");
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xff6366f1))),
      );

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Force reload to get latest user details
      await userCredential.user?.reload();
      final updatedUser = _auth.currentUser;
      if (updatedUser != null && updatedUser.displayName != null && updatedUser.displayName!.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('student_name', updatedUser.displayName!);
      }

      if (mounted) {
        Navigator.pop(context); // Dismiss loading loader
        final pendingCode = PendingJoinService.pendingRoomCode;
        if (pendingCode != null && pendingCode.isNotEmpty) {
          PendingJoinService.pendingRoomCode = null; // Clear it
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => AutoJoinScreen(roomCode: pendingCode)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (ex) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading loader
        _showAlert("Error", ex.message ?? ex.code);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showAlert("Error", "Something went wrong. Please check your credentials.");
      }
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xff6366f1))),
      );

      UserCredential userCredential;

      if (kIsWeb) {
        // Web Google Sign-In via Firebase Auth Popup
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile Google Sign-In via google_sign_in package
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          if (mounted) Navigator.pop(context);
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final User? user = userCredential.user;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final String displayName = user.displayName ?? "Student";
        await prefs.setString('student_name', displayName);

        final userDoc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
            "uid": user.uid,
            "name": displayName,
            "email": user.email ?? "",
            "xp": 0,
            "level": 1,
            "streak": 0,
            "cumulativeXp": 0,
            "lastUpdated": FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        Navigator.pop(context); // Dismiss loader
        final pendingCode = PendingJoinService.pendingRoomCode;
        if (pendingCode != null && pendingCode.isNotEmpty) {
          PendingJoinService.pendingRoomCode = null; // Clear it
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => AutoJoinScreen(roomCode: pendingCode)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loader
        _showAlert("Error", "Google Sign-In failed: $e");
      }
    }
  }

  // Premium Glassmorphic Card Container
  Widget _buildGlassCard({required Widget child, double blur = 20, double opacity = 0.03, Color borderColor = Colors.white10}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            border: Border.all(color: borderColor, width: 1.2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020617),
      body: Stack(
        children: [
          // Cyberpunk Background Glows
          Positioned(
            top: -100,
            right: -50,
            child: CircleAvatar(
              radius: 160,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.12),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: CircleAvatar(
              radius: 160,
              backgroundColor: const Color(0xffa855f7).withOpacity(0.08),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Logo details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xff6366f1).withOpacity(0.15),
                            boxShadow: [
                              BoxShadow(color: const Color(0xff6366f1).withOpacity(0.3), blurRadius: 15, spreadRadius: 1)
                            ],
                          ),
                          child: const Icon(Icons.bolt_rounded, color: Color(0xff6366f1), size: 36),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "STUDYSYNC",
                              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            Text(
                              "AI STUDY ASSISTANT",
                              style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Forms card
                    _buildGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Welcome Back",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Log in to continue your focus routine",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            const SizedBox(height: 35),

                            // Email Address Field
                            TextField(
                              controller: emailController,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: "Email Address",
                                labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54, size: 20),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xff6366f1))),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Password Field
                            TextField(
                              controller: passwordController,
                              obscureText: hidePassword,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                labelText: "Password",
                                labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white38, size: 20),
                                  onPressed: () => setState(() => hidePassword = !hidePassword),
                                ),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xff6366f1))),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Login Action button
                            Container(
                              height: 55,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xff6366f1).withOpacity(0.35),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff6366f1),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  login();
                                },
                                child: const Text(
                                  "LOGIN",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Social login header
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white10, endIndent: 10)),
                        Text("OR CONTINUE WITH", style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        Expanded(child: Divider(color: Colors.white10, indent: 10)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Social grid buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildSocialButton(
                            icon: Icons.g_mobiledata_rounded,
                            text: "Google",
                            iconColor: const Color(0xffef4444),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              signInWithGoogle();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSocialButton(
                            icon: Icons.facebook_outlined,
                            text: "Facebook",
                            iconColor: const Color(0xff3b5998),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              // Facebook login not configured
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 35),

                    // Register bottom line
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?", style: TextStyle(color: Colors.white38, fontSize: 13)),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(context, MaterialPageRoute(builder: (context) => SignupPage()));
                          },
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(color: Color(0xff6366f1), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Social link widget
  Widget _buildSocialButton({
    required IconData icon,
    required String text,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return _buildGlassCard(
      opacity: 0.04,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
