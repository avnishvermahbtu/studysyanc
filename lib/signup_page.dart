import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysync/login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool hidePassword = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showAlert(String title, String message, {bool popToLogin = false}) {
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
                color: title == "Success" ? const Color(0xff10b981) : const Color(0xffef4444),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (popToLogin) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                }
              },
              child: const Text("OK", style: TextStyle(color: Color(0xff10b981), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> signUp() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showAlert("Alert!", "Please enter required fields (Email & Password)");
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xff10b981))),
      );

      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        Navigator.pop(context); // Dismiss loading loader
        // Update user display name if custom name is input
        if (name.isNotEmpty && _auth.currentUser != null) {
          await _auth.currentUser!.updateDisplayName(name);
          await _auth.currentUser!.reload();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('student_name', name);
        }
        // Direct transition back to login page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } on FirebaseAuthException catch (ex) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading loader
        _showAlert("Alert!", ex.message ?? ex.code);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showAlert("Error", "Something went wrong during signup. Please try again.");
      }
    }
  }

  // Glassmorphic Card Container
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
            left: -50,
            child: CircleAvatar(
              radius: 160,
              backgroundColor: const Color(0xff10b981).withOpacity(0.1),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -50,
            child: CircleAvatar(
              radius: 160,
              backgroundColor: const Color(0xff6366f1).withOpacity(0.06),
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
                    // Header logo description
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xff10b981).withOpacity(0.12),
                            boxShadow: [
                              BoxShadow(color: const Color(0xff10b981).withOpacity(0.25), blurRadius: 15, spreadRadius: 1)
                            ],
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xff10b981), size: 36),
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
                              "CREATE ACADEMIC ACCESS",
                              style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Inputs Card
                    _buildGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Create Account",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Sign up to unlock personalized AI features",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            const SizedBox(height: 35),

                            // Name input
                            TextField(
                              controller: nameController,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                labelText: "Full Name (Optional)",
                                labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white54, size: 20),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xff10b981))),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Email input
                            TextField(
                              controller: emailController,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: "Email Address",
                                labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54, size: 20),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xff10b981))),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Password input
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
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xff10b981))),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Sign Up action button
                            Container(
                              height: 55,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xff10b981).withOpacity(0.25),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff10b981),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  signUp();
                                },
                                child: const Text(
                                  "SIGN UP",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Redirect login bottom line
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?", style: TextStyle(color: Colors.white38, fontSize: 13)),
                        TextButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                          },
                          child: const Text(
                            "Login",
                            style: TextStyle(color: Color(0xff10b981), fontWeight: FontWeight.bold, fontSize: 13),
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
}