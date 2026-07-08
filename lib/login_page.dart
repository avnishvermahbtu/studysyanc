import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysync/features/navigation/main_navigation_screen.dart';
import 'package:studysync/signup_page.dart';
import 'package:studysync/features/focus/controller/focus_controller.dart';
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
  String? _passwordError;

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

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController(text: emailController.text.trim());
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isResetLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xff0f172a),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.white10),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xff6366f1).withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: Color(0xff6366f1),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Reset Password",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Enter your registered email address, and we will send you a secure link to reset your password.",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: resetEmailController,
                      enabled: !isResetLoading,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Please enter your email";
                        }
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return "Please enter a valid email address";
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: "Email Address",
                        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54, size: 20),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.white10),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.white10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xff6366f1)),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.redAccent),
                        ),
                        errorStyle: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!isResetLoading) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (formKey.currentState?.validate() ?? false) {
                        final email = resetEmailController.text.trim();
                        setStateDialog(() {
                          isResetLoading = true;
                        });

                        try {
                          await _auth.sendPasswordResetEmail(email: email);
                          if (mounted) {
                            Navigator.pop(dialogContext); // Close reset dialog
                            _showAlert("Success", "Password reset link sent to $email. Please check your inbox.");
                          }
                        } on FirebaseAuthException catch (ex) {
                          if (mounted) {
                            setStateDialog(() {
                              isResetLoading = false;
                            });
                            String errorMessage = "Failed to send reset email.";
                            if (ex.code == 'user-not-found') {
                              errorMessage = "No user found with this email address.";
                            } else if (ex.code == 'invalid-email') {
                              errorMessage = "The email address is invalid.";
                            } else {
                              errorMessage = ex.message ?? ex.code;
                            }
                            _showAlert("Error", errorMessage);
                          }
                        } catch (e) {
                          if (mounted) {
                            setStateDialog(() {
                              isResetLoading = false;
                            });
                            _showAlert("Error", "Something went wrong. Please try again later.");
                          }
                        }
                      }
                    },
                    child: const Text(
                      "Send Link",
                      style: TextStyle(color: Color(0xff6366f1), fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Color(0xff6366f1),
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
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

    if (password.length < 8) {
      setState(() {
        _passwordError = "Password must be at least 8 characters";
      });
      return;
    } else {
      setState(() {
        _passwordError = null;
      });
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
        await FocusController().clearAndReload();
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
        await FocusController().clearAndReload();
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

  Widget _buildGlassCard({required Widget child, double blur = 6.0, double opacity = 0.03, Color borderColor = Colors.white10}) {
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
                              onChanged: (val) {
                                if (_passwordError != null && val.trim().length >= 8) {
                                  setState(() {
                                    _passwordError = null;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                labelText: "Password",
                                labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                errorText: _passwordError,
                                errorStyle: const TextStyle(color: Colors.redAccent),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white38, size: 20),
                                  onPressed: () => setState(() => hidePassword = !hidePassword),
                                ),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.white10)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xff6366f1))),
                                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
                                focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  _showForgotPasswordDialog();
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: Color(0xff6366f1),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

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

  Widget _buildSocialButton({
    required IconData icon,
    required String text,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white10, width: 1.2),
        borderRadius: BorderRadius.circular(30),
      ),
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
