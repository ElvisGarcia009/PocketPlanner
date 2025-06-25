import 'package:Pocket_Planner/services/periods.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:Pocket_Planner/home/home_screen.dart';
import 'LoginSignup_screen.dart';
import 'package:Pocket_Planner/database/sqlite_management.dart';
import 'package:Pocket_Planner/services/active_budget.dart';
import 'package:provider/provider.dart'; 

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const AuthFlowScreen();

    return FutureBuilder<void>(
      future: SqliteManager.instance.initDbForUser(user.uid),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // ⬇︎ Creamos y llenamos el provider antes de mostrar la app
        return FutureBuilder<void>(
          future: Provider.of<ActiveBudget>(ctx, listen: false)
              .initFromSqlite(SqliteManager.instance.db).then((_) async {
            final count = await AutoRecurringService().run(ctx);
            if (count > 0 && ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('Se han insertado $count transacciones automáticamente 🧾'),
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              );
            }
          }),
          builder: (ctx, snap2) {
            if (snap2.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return const HomeScreen();      // BD y presupuesto listos
          },
        );
      },
    );
  }
}
