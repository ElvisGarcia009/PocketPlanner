// lib/auth/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../database/sqlite_management.dart';
import '../home/home_screen.dart';
import '../services/active_budget.dart';
import '../services/periods.dart';
import '../services/sync_first_time.dart';
import '../auth/LoginSignup_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const AuthFlowScreen();

    return FutureBuilder<void>(
      future: _bootstrapApp(context, user.uid),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const HomeScreen(); // todo cargado
      },
    );
  }

  /* ────────────────────────────────────────────────────────── 
   1) Abre/crea SQLite del usuario
   2) Sincroniza Firebase → SQLite solo la 1ra vez
   3) Inicializa provider ActiveBudget
   4) Ejecuta inserciones automáticas (AutoRecurringService)
   ────────────────────────────────────────────────────────── */
  Future<void> _bootstrapApp(BuildContext ctx, String uid) async {
    await SqliteManager.instance.initDbForUser(uid);

    await FirstTimeSync.instance.syncFromFirebaseIfNeeded(ctx);

    await Provider.of<ActiveBudget>(
      ctx,
      listen: false,
    ).initFromSqlite(SqliteManager.instance.db);

    final inserted = await AutoRecurringService().run(ctx);
    if (inserted > 0 && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            'Se insertaron $inserted transacciones automáticas 🧾',
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
      );
    }
  }
}
