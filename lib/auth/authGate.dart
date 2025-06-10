import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:Pocket_Planner/home/home_screen.dart';
import 'LoginSignup_screen.dart';
import 'package:Pocket_Planner/database/sqlite_management.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ── No hay sesión ­→ flujo de autenticación ───────────────────
    if (user == null) return const AuthFlowScreen();

    // ── Hay sesión ­→ inicializar SQLite y esperar ────────────────
    return FutureBuilder<void>(
      future: SqliteManager.instance.initDbForUser(user.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done) {
          return const HomeScreen();                // BD lista
        } else if (snap.hasError) {
          // Maneja el error como prefieras
          return Scaffold(
            body: Center(
              child: Text('Error inicializando BD:\n${snap.error}'),
            ),
          );
        } else {
          // Cargando
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}
