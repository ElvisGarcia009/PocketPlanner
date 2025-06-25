// budget_home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'planHome_screen.dart';
import 'remainingHome_screen.dart';
import '../flutterflow_components/flutterflowtheme.dart';
import '../database/sqlite_management.dart';
import '../services/active_budget.dart';

class BudgetHomeScreen extends StatefulWidget {
  const BudgetHomeScreen({super.key});

  @override
  State<BudgetHomeScreen> createState() => _BudgetHomeScreenState();
}

class _BudgetHomeScreenState extends State<BudgetHomeScreen> {
  final Database _db = SqliteManager.instance.db;

  List<BudgetSql> _budgets = [];
  BudgetSql?     _current;      // ← presupuesto activo en pantalla

  // ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    final maps = await _db.query('budget_tb', orderBy: 'id_budget');
    _budgets = maps.map(BudgetSql.fromMap).toList();

    // Si no hubiera ninguno, creamos el primero
    if (_budgets.isEmpty) {
      final int id = await _db.insert(
        'budget_tb',
        BudgetSql(name: 'Mi primer presupuesto', idPeriod: 1).toMap(),
      );
      _budgets = [
        BudgetSql(idBudget: id, name: 'Mi primer presupuesto', idPeriod: 1)
      ];
    }

    // Tomamos el presupuesto activo guardado en provider (o el 1.º)
    final prov = Provider.of<ActiveBudget>(context, listen: false);
    _current = _budgets.firstWhere(
      (b) => b.idBudget == prov.idBudget,
      orElse: () => _budgets.first,
    );
    prov.change(
      idBudgetNew : _current!.idBudget!,   // int
      nameNew     : _current!.name,        // String
      idPeriodNew : _current!.idPeriod,    // int
    );
     // sincroniza provider ↔ estado local
    setState(() {});
  }

  // ────────────────────────────────────────────────────────────────
  //  TOP-SECTION  ( título + selector + ⚙︎ )
  // ────────────────────────────────────────────────────────────────
  Widget _buildTopSection() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          /*  ⚙︎ CONFIGURAR  */
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _current == null ? null : _openEditDialog,
          ),

          /*  ▼ SELECTOR DE PRESUPUESTOS  */
          InkWell(
            onTap: _openBudgetSelector,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _current?.name ?? '...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
          ),

          const SizedBox(width: 32), // para balancear
        ],
      );

  // ────────────────────────────────────────────────────────────────
  //  SELECTOR DE PRESUPUESTO
  // ────────────────────────────────────────────────────────────────
  void _openBudgetSelector() => showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._budgets.map(
                (b) => ListTile(
                  leading: Icon(
                    b.idBudget == _current?.idBudget
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(b.name),
                  onTap: () {
                    Navigator.pop(context);
                    _setCurrent(b);
                  },
                ),
              ),
              const Divider(color: Colors.white),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Agregar presupuesto'),
                onTap: () {
                  Navigator.pop(context);
                  _openAddDialog();
                },
              ),
            ],
          ),
        ),
      );

Future<void> _openAddDialog() async {
  final nameCtrl = TextEditingController();
  int? periodId = 1;

  // ── 1) Periodos disponibles ─────────────────────────────────────────
  final periods = (await _db.query('budgetPeriod_tb'))
      .map(PeriodSql.fromMap)
      .toList();

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Nuevo presupuesto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Periodo'),
            value: periodId,
            items: periods
                .map((p) =>
                    DropdownMenuItem(value: p.idPeriod, child: Text(p.name)))
                .toList(),
            onChanged: (val) => periodId = val,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          child: const Text('Guardar'),
          onPressed: () async {
            /* ──────────────────────────────────────────────────────────
             *  Validaciones rápidas
             * ─────────────────────────────────────────────────────── */
            final trimmedName = nameCtrl.text.trim();
            if (trimmedName.isEmpty || periodId == null) return;

            /* ──────────────────────────────────────────────────────────
             *  2) INSERTS dentro de una transacción
             * ─────────────────────────────────────────────────────── */
            late int budgetId;
            late List<int> cardIds;

            await _db.transaction((txn) async {
              // 2-a) presupuesto ------------------------------------
              budgetId = await txn.insert(
                'budget_tb',
                BudgetSql(
                        name: trimmedName,
                        idPeriod: periodId!,
                        dateCrea: DateTime.now())
                    .toMap(),
              );

              // 2-b) tarjetas ---------------------------------------
              const cardTitles = ['Ingresos', 'Gastos', 'Ahorros'];
              cardIds = [];
              for (final t in cardTitles) {
                final cid = await txn.insert('card_tb', {
                  'title': t,
                  'id_budget': budgetId,
                  'date_crea': DateTime.now().toIso8601String(),
                });
                cardIds.add(cid);
              }

              // 2-c) ítems “cero” -----------------------------------
              /*  Categorías:
                    Ingresos  → id_category = 9
                    Gastos    → id_category = 1
                    Ahorros   → id_category = 13
               */
              const catIds = [9, 1, 13];
              for (var i = 0; i < 3; i++) {
                await txn.insert('item_tb', {
                  'id_category': catIds[i],
                  'id_card': cardIds[i],
                  'amount': 0,
                  'date_crea': DateTime.now().toIso8601String(),
                  'id_priority': 1,
                  'id_itemType': 1,
                });
              }
            });

            /* ────────────────────────────────────────────────────────
             *  3)  Actualizar estado local y provider
             * ───────────────────────────────────────────────────── */
            final newBudget =
                BudgetSql(idBudget: budgetId, name: trimmedName, idPeriod: periodId!);
            _budgets.add(newBudget);
            _setCurrent(newBudget);                            // ← método propio
            if (!mounted) return;
            Provider.of<ActiveBudget>(context, listen: false)
                .change(idBudgetNew: budgetId,
                        nameNew: trimmedName,
                        idPeriodNew: periodId!);

            /* ────────────────────────────────────────────────────────
             *  4)  Sincronizar con Firestore
             * ───────────────────────────────────────────────────── */
            await _syncSectionsItemsFirebaseForBudget(budgetId, cardIds);

            Navigator.pop(context); // cerrar diálogo
          },
        ),
      ],
    ),
  );
}

/* ════════════════════════════════════════════════════════════════════
 *  Sube a Firestore las secciones & ítems del presupuesto indicado
 * ═════════════════════════════════════════════════════════════════ */
Future<void> _syncSectionsItemsFirebaseForBudget(
    int budgetId, List<int> cardIds) async {

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final fs        = FirebaseFirestore.instance;
  final budgetRef = fs
      .collection('users')
      .doc(user.uid)
      .collection('budgets')
      .doc(budgetId.toString());

  final secColl = budgetRef.collection('sections');
  final itmColl = budgetRef.collection('items');

  WriteBatch batch = fs.batch();

  // Secciones (tarjetas)
  const titles = ['Ingresos', 'Gastos', 'Ahorros'];
  for (var i = 0; i < 3; i++) {
    batch.set(
      secColl.doc(cardIds[i].toString()),
      {'title': titles[i]},
    );
  }

  // Ítems
  const catIds = [9, 1, 13];
  for (var i = 0; i < 3; i++) {
    batch.set(
      itmColl.doc(), // id generado por Firestore
      {
        'idCard'    : cardIds[i],
        'idCategory': catIds[i],
        'name'      : titles[i],
        'amount'    : 0,
      },
    );
  }

  await batch.commit();
}


  // ────────────────────────────────────────────────────────────────
  //  DIALOGO  –  EDITAR / ELIMINAR  PRESUPUESTO
  // ────────────────────────────────────────────────────────────────
Future<void> _openEditDialog() async {
  if (_current == null) return;

  final nameCtrl = TextEditingController(text: _current!.name);
  int periodId   = _current!.idPeriod;

  final periods = (await _db.query('budgetperiod_tb'))
      .map(PeriodSql.fromMap)
      .toList();

  final theme = FlutterFlowTheme.of(context);

  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: theme.primaryBackground,
      title: Text(
        'Editar presupuesto',
        style: theme.typography.titleLarge.override(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            style: theme.typography.bodyMedium,
            decoration: InputDecoration(
              labelText: 'Nombre',
              labelStyle: theme.typography.bodySmall.override(
                color: theme.secondaryText,
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.primary, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.secondaryText),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: periodId,
            decoration: InputDecoration(
              labelText: 'Periodo',
              labelStyle: theme.typography.bodySmall.override(
                color: theme.secondaryText,
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.primary, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.secondaryText),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            style: theme.typography.bodyMedium,
            dropdownColor: theme.secondaryBackground,
            items: periods
                .map((p) => DropdownMenuItem<int>(
                      value: p.idPeriod,
                      child: Text(p.name, style: theme.typography.bodyMedium),
                    ))
                .toList(),
            onChanged: (v) => periodId = v ?? periodId,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        // ───── Cancelar ─────
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: theme.typography.bodyMedium.override(color: theme.primary),
          ),
        ),

                // ───── Eliminar ─────
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: theme.primaryBackground,
                titleTextStyle: theme.typography.titleMedium.override(
                  color: theme.primaryText,       
                  fontWeight: FontWeight.bold,
                ),
                // ← Estilo del cuerpo
                contentTextStyle: theme.typography.bodyMedium.override(
                  color: theme.primaryText,
                ),
                title: const Text('Eliminar presupuesto'),
                content: const Text(
                  '¿Seguro que deseas eliminar este presupuesto?\n',
                ),
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.primaryText,              // texto blanco
                      textStyle: theme.typography.bodyMedium,
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancelar', style: theme.typography.bodyMedium.override(color: theme.primary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,      // fondo
                      foregroundColor: Colors.white,    // texto / iconos ⇒ ¡blanco!
                      textStyle: theme.typography.bodyMedium,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Eliminar'),      // aquí no necesitamos override
                  ),
                ],
              ),

            );

            if (confirm == true) {
              final bid = _current!.idBudget!;
              await _db.transaction((txn) async {
                // 1️⃣  tarjetas del presupuesto
                final cardRows = await txn.query(
                  'card_tb',
                  columns: ['id_card'],
                  where: 'id_budget = ?',
                  whereArgs: [bid],
                );
                final cardIds =
                    cardRows.map((r) => r['id_card'] as int).toList();

                // 2️⃣  ítems de esas tarjetas
                if (cardIds.isNotEmpty) {
                  await txn.delete(
                    'item_tb',
                    where:
                        'id_card IN (${List.filled(cardIds.length, '?').join(',')})',
                    whereArgs: cardIds,
                  );
                }

                // 3️⃣  transacciones
                await txn.delete(
                  'transaction_tb',
                  where: 'id_budget = ?',
                  whereArgs: [bid],
                );

                // 4️⃣  tarjetas
                await txn.delete(
                  'card_tb',
                  where: 'id_budget = ?',
                  whereArgs: [bid],
                );

                // 5️⃣  presupuesto
                await txn.delete(
                  'budget_tb',
                  where: 'id_budget = ?',
                  whereArgs: [bid],
                );
              });

              await _loadBudgets();
              if (mounted) Navigator.pop(context); // cerrar diálogo
            }
          },
          child: Text('Eliminar', style: theme.typography.bodyMedium.override(color: theme.primaryText)),
        ),

        // ───── Guardar ─────
        TextButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          onPressed: () async {
            await _db.update(
              'budget_tb',
              BudgetSql(
                idBudget: _current!.idBudget,
                name: nameCtrl.text.trim(),
                idPeriod: periodId,
              ).toMap(),
              where: 'id_budget = ?',
              whereArgs: [_current!.idBudget],
            );
            await _loadBudgets();
            if (mounted) Navigator.pop(context); // cerrar diálogo
          },
          child: Text(
            'Guardar',
            style: theme.typography.bodyMedium.override(color: theme.primaryText),
          ),
        ),
      ],
    ),
  );
}



  // ────────────────────────────────────────────────────────────────
  //  Helpers
  // ────────────────────────────────────────────────────────────────
  void _setCurrent(BudgetSql b) {
    setState(() => _current = b);
    Provider.of<ActiveBudget>(context, listen: false).change(
      idBudgetNew : b.idBudget!,   // int   (asegúrate de que no es null)
      nameNew     : b.name,        // String
      idPeriodNew : b.idPeriod,    // int
    );  
  }

  // ────────────────────────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    if (_current == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF132487), Color(0xFF1C3770)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          automaticallyImplyLeading: false,
          title: _buildTopSection(),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: theme.alternate,
              child: TabBar(
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(width: 2, color: Colors.white),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF616161),
                labelStyle: theme.typography.bodyMedium.override(fontSize: 18),
                tabs: const [
                  Tab(text: 'Plan'),
                  Tab(text: 'Restante'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            PlanHomeScreen(),
            RemainingHomeScreen(),
          ],
        ),
      ),
    );
  }
}
