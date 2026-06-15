import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:studysync/features/navigation/main_navigation_screen.dart';
import 'package:studysync/signup_page.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  bool hidePassword = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  login() async {
    // 1️⃣ Check if fields are empty
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (_) =>
            AlertDialog(
              title: Text("Alert!"),
              content: Text("Please enter email and password"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("OK"),
                )
              ],
            ),
      );
    }
    else {
      try {
        UserCredential? usercredential;
        // 2️⃣ Firebase login
        usercredential = await _auth.signInWithEmailAndPassword(
          email: emailController.text.toString(),
          password: passwordController.text.toString(),
        );
        // 3️⃣ Navigate to Main Screen if login successful
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainNavigationScreen()),
        );
      } on FirebaseAuthException catch (ex) {
        showDialog(
          context: context,
          builder: (_) =>
              AlertDialog(
                title: Text("Error"),
                content: Text(ex.code.toString()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("OK"),
                  )
                ],
              ),
        );
      }
    }
  }
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff667eea), Color(0xff764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        /// Icon Lock
                        const Icon(Icons.lock_outline,
                            size: 80, color: Colors.white),
                        const SizedBox(height: 20),
                        /// Welcome back
                        const Text(
                          "Welcome Back",
                          style: TextStyle(
                              fontSize: 28,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 40),
                        /// Email
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.email),
                            hintText: "Email",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        /// Password
                        TextField(
                          controller: passwordController,
                          obscureText: hidePassword,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.lock),
                            hintText: "Password",
                            suffixIcon: IconButton(
                              icon: Icon(hidePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () {
                                setState(() {
                                  hidePassword = !hidePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        /// Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                login();
                              });
                            },
                            child: const Text(
                              "Login",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text("OR",
                            style: TextStyle(color: Colors.white)),
                        const SizedBox(height: 20),
                        /// Google Login
                        socialButton(
                            icon: Icons.g_mobiledata,
                            text: "Continue with Google"),
                        const SizedBox(height: 10),
                        /// Facebook Login
                        socialButton(
                            icon: Icons.facebook,
                            text: "Continue with Facebook"),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have account?",
                                style: TextStyle(color: Colors.white)),
                            /// SignUp TextButton
                            TextButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(
                                      builder: (context) => SignupPage()));
                                },
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.white
                                ),
                                child: const Text("Sign Up",
                                  style: TextStyle(fontWeight: FontWeight.bold,
                                  ),))
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              )

        ),
      );
    }

    Widget socialButton({required IconData icon, required String text}) {
      return Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Text(text),
          ],
        ),
      );
    }
  }


