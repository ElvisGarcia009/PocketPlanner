import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import 'planHome_screen.dart';
import 'IndicatorsHome_screen.dart';
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
  BudgetSql? _current; // <- presupuesto activo en pantalla

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    final maps = await _db.query('budget_tb', orderBy: 'id_budget');
    _budgets = maps.map(BudgetSql.fromMap).toList();

    // Si no hubiera ningun presupuesto, creamos el primero
    if (_budgets.isEmpty) {
      final int id = await _db.insert(
        'budget_tb',
        BudgetSql(name: 'Mi primer presupuesto', idPeriod: 1).toMap(),
      );
      _budgets = [
        BudgetSql(idBudget: id, name: 'Mi primer presupuesto', idPeriod: 2),
      ];
    }

    // Tomamos el presupuesto activo guardado en provider
    final prov = Provider.of<ActiveBudget>(context, listen: false);
    _current = _budgets.firstWhere(
      (b) => b.idBudget == prov.idBudget,
      orElse: () => _budgets.first,
    );
    prov.change(
      idBudgetNew: _current!.idBudget!,
      nameNew: _current!.name,
      idPeriodNew: _current!.idPeriod,
    );
    setState(() {});
  }

  // Top Section (titulo y selector de presupuesto)

  Widget _buildTopSection(FlutterFlowThemeData theme) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,

    children: [
      // const SizedBox(width: 30),
      // Selector
      InkWell(
        onTap: _openBudgetSelector,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
              _current?.name ?? '...',
              style: theme.typography.titleLarge.override(),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),

      // Botón de configuración
      IconButton(
        icon: const Icon(Icons.settings, color: Colors.white),
        onPressed: _current == null ? null : _openEditDialog,
      ),
    ],
  );

  // Funcion del selector de presupuestos

  void _openBudgetSelector() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      final theme = FlutterFlowTheme.of(context); // ← Aquí se declara

      return SafeArea(
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
                title: Text(b.name, style: theme.typography.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _setCurrent(b);
                },
              ),
            ),
            const Divider(color: Colors.white),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(
                'Agregar presupuesto',
                style: theme.typography.bodyLarge,
              ),
              onTap: () {
                Navigator.pop(context);
                _openAddDialog();
              },
            ),
          ],
        ),
      );
    },
  );

  Future<void> _openAddDialog() async {
    final nameCtrl = TextEditingController();
    int? periodId = 1;

    // Obtener periodos disponibles
    final periods =
        (await _db.query('budgetPeriod_tb')).map(PeriodSql.fromMap).toList();

    final theme = FlutterFlowTheme.of(context);

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              'Nuevo presupuesto',
              style: theme.typography.titleLarge,
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: theme.typography.bodyMedium,
                  textAlign: TextAlign.left,
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
                  items:
                      periods
                          .map(
                            (p) => DropdownMenuItem<int>(
                              value: p.idPeriod,
                              child: Text(
                                p.name,
                                style: theme.typography.bodyMedium,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => periodId = v ?? periodId,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  textStyle: theme.typography.bodyMedium,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final trimmedName = nameCtrl.text.trim();
                  if (trimmedName.isEmpty || periodId == null) return;

                  late int budgetId;
                  late List<int> cardIds;

                  await _db.transaction((txn) async {
                    // a) Insertar nuevo presupuesto
                    budgetId = await txn.insert(
                      'budget_tb',
                      BudgetSql(
                        name: trimmedName,
                        idPeriod: periodId!,
                        dateCrea: DateTime.now(),
                      ).toMap(),
                    );

                    // b) Crear tarjetas base
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

                    // c) Crear ítems base en cada tarjeta
                    const catIds = [9, 1, 13]; // IDs de categorías iniciales
                    for (var i = 0; i < 3; i++) {
                      await txn.insert('item_tb', {
                        'id_category': catIds[i],
                        'id_card': cardIds[i],
                        'amount': 0,
                        'date_crea': DateTime.now().toIso8601String(),
                        'id_itemType': 1,
                      });
                    }
                  });

                  // Agregar nuevo presupuesto a la lista
                  final newBudget = BudgetSql(
                    idBudget: budgetId,
                    name: trimmedName,
                    idPeriod: periodId!,
                  );

                  _budgets.add(newBudget);
                  _setCurrent(newBudget);

                  if (!mounted) return;

                  Provider.of<ActiveBudget>(context, listen: false).change(
                    idBudgetNew: budgetId,
                    nameNew: trimmedName,
                    idPeriodNew: periodId!,
                  );

                  // Sincronizar con Firebase
                  _syncSectionsItemsFirebaseForBudget(
                    budgetId,
                    trimmedName,
                    periodId!,
                    cardIds,
                  );
                  Navigator.pop(context); // Cerrar el diálogo
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: theme.typography.bodyMedium,
                ),
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }

  // Sube a firebase las secciones e ítems del presupuesto recién creado
  Future<void> _syncSectionsItemsFirebaseForBudget(
    int budgetId,
    String budgetName, // ⬅️ NUEVOS PARÁMETROS
    int periodId, // ⬅️
    List<int> cardIds,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fs = FirebaseFirestore.instance;
    final budgetRef = fs
        .collection('users')
        .doc(user.uid)
        .collection('budgets')
        .doc(budgetId.toString());

    final secColl = budgetRef.collection('sections');
    final itmColl = budgetRef.collection('items');

    final batch = fs.batch();

    /* 1⃣  Doc raíz del presupuesto ----------------------------------- */
    batch.set(budgetRef, {
      'name': budgetName,
      'id_budgetPeriod': periodId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    /* 2⃣  Secciones base --------------------------------------------- */
    const titles = ['Ingresos', 'Gastos', 'Ahorros'];
    for (var i = 0; i < 3; i++) {
      batch.set(secColl.doc(cardIds[i].toString()), {'title': titles[i]});
    }

    /* 3⃣  Ítems base -------------------------------------------------- */
    const catIds = [9, 1, 13];
    for (var i = 0; i < 3; i++) {
      batch.set(itmColl.doc(), {
        'idCard': cardIds[i],
        'idCategory': catIds[i],
        'name': titles[i],
        'amount': 0,
      });
    }

    await batch.commit();
  }

  // Dialogo de edición del presupuesto

  Future<void> _openEditDialog() async {
    if (_current == null) return;

    final nameCtrl = TextEditingController(text: _current!.name);
    int periodId = _current!.idPeriod;

    final periods =
        (await _db.query('budgetperiod_tb')).map(PeriodSql.fromMap).toList();

    final theme = FlutterFlowTheme.of(context);

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: theme.primaryBackground,
            title: Text(
              'Editar presupuesto',
              style: theme.typography.titleLarge,
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: theme.typography.bodyMedium,
                  textAlign: TextAlign.left,
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
                  items:
                      periods
                          .map(
                            (p) => DropdownMenuItem<int>(
                              value: p.idPeriod,
                              child: Text(
                                p.name,
                                style: theme.typography.bodyMedium,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => periodId = v ?? periodId,
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: theme.typography.bodyMedium.override(
                        color: theme.primary,
                      ),
                    ),
                  ),

                  // Eliminar
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder:
                            (_) => AlertDialog(
                              backgroundColor: theme.primaryBackground,
                              title: Text(
                                'Eliminar presupuesto',
                                style: theme.typography.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                              content: Text(
                                'Si elimina este presupuesto, se borrará su plan y transacciones. ¿Desea continuar?',
                                style: theme.typography.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                              actions: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: theme.primaryText,
                                        textStyle: theme.typography.bodyMedium,
                                      ),
                                      onPressed:
                                          () => Navigator.pop(context, false),
                                      child: Text(
                                        'No, cancelar',
                                        style: theme.typography.bodyMedium
                                            .override(color: theme.primary),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        textStyle: theme.typography.bodyMedium,
                                      ),
                                      onPressed:
                                          () => Navigator.pop(context, true),
                                      child: Text(
                                        'Sí, borrar todo',
                                        style: theme.typography.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      );

                      if (confirm == true) {
                        final bid = _current!.idBudget!;

                        // ✅ VALIDAR SI HAY MÁS DE UN PRESUPUESTO
                        final countRows = await _db.query('budget_tb');
                        if (countRows.length <= 1) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No puedes quedarte sin presupuestos',
                                ),
                              ),
                            );
                          }
                          return;
                        }

                        // ✅ CONTINÚA CON ELIMINACIÓN SI HAY MÁS DE UNO
                        await _db.transaction((txn) async {
                          final cardRows = await txn.query(
                            'card_tb',
                            columns: ['id_card'],
                            where: 'id_budget = ?',
                            whereArgs: [bid],
                          );
                          final cardIds =
                              cardRows.map((r) => r['id_card'] as int).toList();

                          if (cardIds.isNotEmpty) {
                            await txn.delete(
                              'item_tb',
                              where:
                                  'id_card IN (${List.filled(cardIds.length, '?').join(',')})',
                              whereArgs: cardIds,
                            );
                          }

                          await txn.delete(
                            'transaction_tb',
                            where: 'id_budget = ?',
                            whereArgs: [bid],
                          );

                          await txn.delete(
                            'card_tb',
                            where: 'id_budget = ?',
                            whereArgs: [bid],
                          );

                          await txn.delete(
                            'budget_tb',
                            where: 'id_budget = ?',
                            whereArgs: [bid],
                          );
                        });

                        _deleteBudgetFromFirebase(bid);

                        await _loadBudgets();
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: Text(
                      'Eliminar',
                      style: theme.typography.bodyMedium.override(
                        color: theme.primaryText,
                      ),
                    ),
                  ),

                  const SizedBox(width: 2),

                  TextButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
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

                      _syncBudgetHeaderFirebase(
                        _current!.idBudget!,
                        nameCtrl.text.trim(),
                        periodId,
                      );
                      await _loadBudgets();
                      if (mounted) Navigator.pop(context);
                    },
                    child: Text(
                      'Guardar',
                      style: theme.typography.bodyMedium.override(
                        color: theme.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  /*        HELPERS       */
  void _setCurrent(BudgetSql b) {
    setState(() => _current = b);
    Provider.of<ActiveBudget>(context, listen: false).change(
      idBudgetNew: b.idBudget!,
      nameNew: b.name,
      idPeriodNew: b.idPeriod,
    );
  }

  //BUILD PRINCIPAL
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
          title: _buildTopSection(theme),
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
                tabs: const [Tab(text: 'Plan'), Tab(text: 'Indicadores')],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            PlanHomeScreen(key: ValueKey(_current!.idBudget)),
            IndicatorsHomeScreen(key: ValueKey(_current!.idBudget)),
          ],
        ),
      ),
    );
  }
}

/// Actualiza sólo los metadatos del presupuesto (nombre-periodo) en Firebase.
Future<void> _syncBudgetHeaderFirebase(
  int idBudget,
  String name,
  int idPeriod,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('budgets')
      .doc(idBudget.toString())
      .set({
        'name': name,
        'id_budgetPeriod': idPeriod,
      }, SetOptions(merge: true));
}

/// Borra el documento del presupuesto y TODAS sus sub-colecciones
/// (sections, items, transactions, …) en Firebase.
Future<void> _deleteBudgetFromFirebase(int idBudget) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final fs = FirebaseFirestore.instance;
  final budDoc = fs
      .collection('users')
      .doc(user.uid)
      .collection('budgets')
      .doc(idBudget.toString());

  /// Helper local: borra *todos* los documentos de una sub-colección
  Future<void> _purgeSubcollection(CollectionReference colRef) async {
    // Traemos en lotes pequeños para no exceder límites de cuota
    const int batchSize = 400; // <= 500 por lote
    while (true) {
      final snap = await colRef.limit(batchSize).get();
      if (snap.docs.isEmpty) break;

      final batch = fs.batch();
      for (final d in snap.docs) batch.delete(d.reference);
      await batch.commit();
    }
  }

  // 1) Borrar sub-colecciones (si las tuvieras)
  await _purgeSubcollection(budDoc.collection('sections'));
  await _purgeSubcollection(budDoc.collection('items'));
  await _purgeSubcollection(budDoc.collection('transactions'));

  // 2) Borrar el documento de presupuesto
  await budDoc.delete();
}
