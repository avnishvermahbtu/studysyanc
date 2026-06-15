import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';

class SignupPage extends StatefulWidget {
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {

  bool hidePassword = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  FutureOr<UserCredential?> Function(UserCredential value)? get value => null;

    // Logic
  signUp()async{
    if(emailController.text.isEmpty && passwordController.text.isEmpty){
      showDialog(context: context, builder: (context)=>AlertDialog(
        title: Text("Alert!"),
        content: Text("Enter Required Fields"),
        actions: [
          TextButton(onPressed: (){
            Navigator.pop(context);
          }, child: Text("OK"))
        ],
      ));
    }
    else{
      UserCredential? usercredential;
      try{
        usercredential=await _auth.createUserWithEmailAndPassword(email: emailController.text.toString(), password: passwordController.text.toString());
        showDialog(context: context, builder: (context)=>AlertDialog(
          title: Text("Success"),
          content: Text("Signup Successful"),
          actions: [
            TextButton(onPressed: (){
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>LoginPage()));
            }, child: Text("OK"))
          ],
        ));

      }
      on FirebaseAuthException catch(ex){
        return showDialog(context: context, builder: (context)=>AlertDialog(
          title: Text("Alert!"),
          content: Text(ex.code.toString()),
          actions: [
            TextButton(onPressed: (){
              Navigator.pop(context);
            }, child:Text("OK") )
          ],
        ));
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
                  /// Icon
                  const Icon(Icons.person_add_alt_1,
                      size: 80, color: Colors.white),
                  const SizedBox(height: 20),

                   /// Create Account
                  const Text(
                    "Create Account",
                    style: TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),

                  /// Name
                  TextField(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.person),
                      hintText: "Full Name",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

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
                  const SizedBox(height: 20),

                  /// Sign Up Button
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
                            signUp();

                        });
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account?",
                          style: TextStyle(color: Colors.white)),
                      TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>LoginPage()));
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white
                          ),
                          child: const Text("Login",style: TextStyle(
                            fontWeight: FontWeight.bold
                          ),))
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}