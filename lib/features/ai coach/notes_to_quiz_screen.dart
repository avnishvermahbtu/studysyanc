import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NotesToQuizScreen extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(title: Text("Notes To Quiz"),),
     body: Center(child: Text("Quiz Screen")),
   );
  }
}