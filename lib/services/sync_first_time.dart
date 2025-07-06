// lib/services/sync_first_time.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import '../database/sqlite_management.dart';

class FirstTimeSync {
  FirstTimeSync._();
  static final instance = FirstTimeSync._();

  // ──────────────────────────────────────────────
  /// El método público: lo llamas desde AuthGate
  // ──────────────────────────────────────────────
  Future<void> syncFromFirebaseIfNeeded(BuildContext ctx) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final doneKey = 'isSynced_$uid';
    if (prefs.getBool(doneKey) == true) return;

    final errs = await _downloadAndInsert(uid);
    if (errs.isEmpty) {
      // marcar como hecho
      await prefs.setBool(doneKey, true);
    } 
  }

  // ──────────────────────────────────────────────
  /// Descarga budgets → sections/items/transactions
  // ──────────────────────────────────────────────
  Future<List<String>> _downloadAndInsert(String uid) async {
    final fs = FirebaseFirestore.instance;
    final db = SqliteManager.instance.db;
    final errors = <String>[];

    late QuerySnapshot<Map<String, dynamic>> budgetsSnap;
    try {
      budgetsSnap =
          await fs.collection('users').doc(uid).collection('budgets').get();
    } catch (e) {
      errors.add('Firestore: $e');
      return errors;
    }

    try {
      await db.transaction((txn) async {
        for (final bud in budgetsSnap.docs) {
          try {
            final idBudget = int.tryParse(bud.id) ?? -1;
            final data = bud.data();

            // 1️⃣ budget_tb
            await _upsert(txn, 'budget_tb', 'id_budget', {
              'id_budget': idBudget,
              'name': data['name'] ?? 'Budget $idBudget',
              'id_budgetPeriod': data['period'] ?? 2,
            });

            // 2️⃣ sections → card_tb
            final secSnap = await bud.reference.collection('sections').get();
            for (final sec in secSnap.docs) {
              final idCard = int.tryParse(sec.id) ?? -1;
              await _upsert(txn, 'card_tb', 'id_card', {
                'id_card': idCard,
                'id_budget': idBudget,
                'title': sec['title'] ?? 'Sección $idCard',
                'date_crea': DateTime.now().toIso8601String(),
              });
            }

            // 3️⃣ items → item_tb
            final itemSnap = await bud.reference.collection('items').get();
            for (final it in itemSnap.docs) {
              try {
                final idItem = int.tryParse(it.id) ?? -1;
                final idCat = it['idCategory'] as int;
                await _ensureCategory(
                  txn,
                  idCat,
                  it['name'] ?? 'Cat $idCat',
                );

                await _upsert(txn, 'item_tb', 'id_item', {
                  'id_item': idItem,
                  'id_card': it['idCard'],
                  'id_category': idCat,
                  'amount': (it['amount'] as num).toDouble(),
                  'id_itemType': it['idItemType'] ?? 2,
                  'date_crea': DateTime.now().toIso8601String(),
                });
              } catch (e) {
                errors.add('item ${it.id}: $e');
              }
            }

            // 4️⃣ transactions → transaction_tb
            final txSnap = await bud.reference.collection('transactions').get();
            for (final tx in txSnap.docs) {
              try {
                final idTx = int.tryParse(tx.id) ?? -1;

                final idCat = await _idForCategory(
                  txn,
                  tx['category'] as String,
                );
                final idFreq = await _idForFrequency(
                  txn,
                  tx['frequency'] as String,
                );
                final idMov = await _idForMovement(
                  txn,
                  tx['type'] as String,
                );

                await _upsert(txn, 'transaction_tb', 'id_transaction', {
                  'id_transaction': idTx,
                  'id_budget': idBudget,
                  'id_category': idCat,
                  'amount': (tx['rawAmount'] as num).toDouble(),
                  'id_frequency': idFreq,
                  'id_movement': idMov,
                  'date': _tsToIso(tx['createdAt']),
                });
              } catch (e) {
                errors.add('tx ${tx.id}: $e');
              }
            }
          } catch (e) {
            errors.add('budget ${bud.id}: $e');
          }
        }
      });
    } catch (e) {
      errors.add('SQLite transacción: $e');
    }

    return errors;
  }

  // ─── utils ────────────────────────────────────────────────────────────
  String? _tsToIso(dynamic v) =>
      v is Timestamp ? v.toDate().toIso8601String() : null;

  Future<void> _upsert(
    DatabaseExecutor txn,
    String table,
    String pk,
    Map<String, Object?> values,
  ) async {
    final updated = await txn.update(
      table,
      values,
      where: '$pk = ?',
      whereArgs: [values[pk]],
    );
    if (updated == 0) {
      await txn.insert(table, values);
    }
  }

  Future<void> _ensureCategory(
    DatabaseExecutor txn,
    int idCat,
    String name,
  ) async {
    final r = await txn.query(
      'category_tb',
      where: 'id_category = ?',
      whereArgs: [idCat],
      limit: 1,
    );
    if (r.isEmpty) {
      await txn.insert('category_tb', {
        'id_category': idCat,
        'name': name,
      });
    }
  }

  Future<int> _idForCategory(DatabaseExecutor txn, String name) =>
      _idForGeneric(txn,
          table: 'category_tb',
          idCol: 'id_category',
          nameCol: 'name',
          nameVal: name);

  Future<int> _idForFrequency(DatabaseExecutor txn, String name) =>
      _idForGeneric(txn,
          table: 'frequency_tb',
          idCol: 'id_frequency',
          nameCol: 'name',
          nameVal: name);

  Future<int> _idForMovement(DatabaseExecutor txn, String name) =>
      _idForGeneric(txn,
          table: 'movement_tb',
          idCol: 'id_movement',
          nameCol: 'name',
          nameVal: name);

  Future<int> _idForGeneric(
    DatabaseExecutor txn, {
    required String table,
    required String idCol,
    required String nameCol,
    required String nameVal,
    Map<String, Object?> extraCols = const {},
  }) async {
    final rows = await txn.query(
      table,
      columns: [idCol],
      where: '$nameCol = ?',
      whereArgs: [nameVal],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first[idCol] as int;

    return await txn.insert(table, {nameCol: nameVal, ...extraCols});
  }
}
