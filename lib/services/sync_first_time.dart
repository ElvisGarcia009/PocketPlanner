import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import '../database/sqlite_management.dart';

class FirstTimeSync {
  FirstTimeSync._();
  static final instance = FirstTimeSync._();

  /// entry-point público
  Future<void> syncFromFirebaseIfNeeded() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // no sesión

    final prefs = await SharedPreferences.getInstance();
    final key = 'isSynced_$uid';
    //await prefs.remove('isSynced_$uid');
    if (prefs.getBool(key) == true) return;

    await _downloadAndInsert(uid);
    await prefs.setBool(key, true); // marcar OK
  }

  /// descarga TODO el árbol budgets → sections/items/tx
  Future<List<String>> _downloadAndInsert(String uid) async {
    final fs = FirebaseFirestore.instance;
    final db = SqliteManager.instance.db;
    final errors = <String>[];

    T? _get<T>(DocumentSnapshot<Map<String, dynamic>> doc, String key) =>
        doc.data()?['$key'] as T?;

    debugPrint('[Sync] → Consultando budgets de $uid');

    late QuerySnapshot<Map<String, dynamic>> budgetsSnap;
    try {
      budgetsSnap =
          await fs.collection('users').doc(uid).collection('budgets').get();
      debugPrint('[Sync]   Budgets encontrados: ${budgetsSnap.size}');
    } catch (e, st) {
      debugPrint('[Sync][FATAL] No se pudo leer Firestore: $e');
      errors.add('Leer Firestore → $e');
      return errors; // aborta
    }

    try {
      await db.transaction((txn) async {
        for (final bud in budgetsSnap.docs) {
          try {
            final idBudget =
                int.tryParse(bud.id) ??
                (throw 'id_budget no numérico: ${bud.id}');
            final data = bud.data();

            // -------- 1️⃣ budget_tb ----------
            await txn.insert('budget_tb', {
              'id_budget': idBudget,
              'name': data['name'] ?? 'Budget $idBudget',
              'id_budgetPeriod': data['period'] ?? 2,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);

            // -------- 2️⃣ sections ----------
            final secSnap = await bud.reference.collection('sections').get();
            for (final sec in secSnap.docs) {
              final idCard =
                  int.tryParse(sec.id) ??
                  (throw 'id_card no numérico: ${sec.id}');
              await txn.insert('card_tb', {
                'id_card': idCard,
                'id_budget': idBudget,
                'title': sec['title'] ?? 'Sección $idCard',
                'date_crea': DateTime.now().toIso8601String(),
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }

            // -------- 3️⃣ items --------------
            final itemSnap = await bud.reference.collection('items').get();
            for (final it in itemSnap.docs) {
              try {
                final idItem =
                    int.tryParse(it.id) ??
                    (throw 'id_item no numérico: ${it.id}');
                await txn.insert('item_tb', {
                  'id_item': idItem,
                  'id_card': it['idCard'],
                  'id_category': it['idCategory'],
                  'amount': (it['amount'] as num).toDouble(),
                  'id_itemType': it['idItemType'] ?? 2,
                  'date_crea': DateTime.now().toIso8601String(),
                }, conflictAlgorithm: ConflictAlgorithm.ignore);
              } catch (e, st) {
                debugPrint('[Sync][item] $e\n$st');
                errors.add('item ${it.id} → $e');
              }
            }

            // -------- 4️⃣ transactions -------
            final txSnap = await bud.reference.collection('transactions').get();
            for (final tx in txSnap.docs) {
              try {
                final idTx =
                    int.tryParse(tx.id) ??
                    (throw 'id_transaction no numérico: ${tx.id}');
                await txn.insert('transaction_tb', {
                  'id_transaction': idTx,
                  'id_budget': idBudget,
                  'id_category': tx['category'],
                  'amount': (tx['rawAmount'] as num).toDouble(),
                  'id_frequency': tx['frequency'],
                  'id_movement': tx['type'],
                  'date': _tsToIso(_get(tx, 'date')),
                }, conflictAlgorithm: ConflictAlgorithm.ignore);
              } catch (e, st) {
                debugPrint('[Sync][tx] $e\n$st');
                errors.add('tx ${tx.id} → $e');
              }
            }
          } catch (e, st) {
            debugPrint('[Sync][budget] $e\n$st');
            errors.add('budget ${bud.id} → $e');
          }
        }
      });
    } catch (e, st) {
      debugPrint('[Sync][SQL] Error en la transacción: $e\n$st');
      errors.add('SQLite transaction → $e');
    }

    if (errors.isEmpty) {
      debugPrint('[Sync] ✔️ Descarga + inserción completada sin errores');
    } else {
      debugPrint('[Sync] ⚠️  Finalizado con ${errors.length} errores');
    }
    return errors;
  }

  String? _tsToIso(dynamic v) =>
      v is Timestamp ? v.toDate().toIso8601String() : null;
}
