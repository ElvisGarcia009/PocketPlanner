import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:Pocket_Planner/home/home_screen.dart';
import 'LoginSignup_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Ya hay sesión activa
      return const HomeScreen();
    } else {
      // No hay sesión
      return const AuthFlowScreen();
    }
  }
}