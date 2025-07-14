import 'dart:async';
import 'dart:math' as math;
import 'package:pocketplanner/auth/auth.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:pocketplanner/database/sqlite_management.dart';
import 'package:pocketplanner/services/actual_currency.dart';
import 'package:pocketplanner/services/budget_monitor.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pocketplanner/services/active_budget.dart';
import 'package:pocketplanner/services/date_range.dart';

// MODELOS

class _ReviewTx {
  TransactionData tx;
  final String merchant; // texto tal cual llegó (“UBER RIDES”, etc.)
  _ReviewTx({required this.tx, required this.merchant});
}

class TransactionData2 {
  final int? id;
  final DateTime date;
  final int categoryId;
  final int frequencyId;
  final double amount;
  final int movementId; // 1 = Gastos, 2 = Ingresos, 3 = Ahorros
  final int budgetId;

  const TransactionData2({
    this.id,
    required this.date,
    required this.categoryId,
    required this.frequencyId,
    required this.amount,
    required this.movementId,
    required this.budgetId,
  });

  // Mapeadores SQLite <-> Modelo
  factory TransactionData2.fromMap(Map<String, Object?> row) {
    return TransactionData2(
      id: row['id_transaction'] as int?,
      date: DateTime.parse(row['date'] as String),
      categoryId: row['id_category'] as int,
      frequencyId: row['id_frequency'] as int,
      amount: (row['amount'] as num).toDouble(),
      movementId: row['id_movement'] as int,
      budgetId: row['id_budget'] as int,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id_transaction': id,
    'date': date.toIso8601String(),
    'id_category': categoryId,
    'id_frequency': frequencyId,
    'amount': amount,
    'id_movement': movementId,
    'id_budget': budgetId,
  };

  // Helpers útiles para la UI
  String get type {
    switch (movementId) {
      case 1:
        return 'Gastos';
      case 2:
        return 'Ingresos';
      case 3:
        return 'Ahorros';
      default:
        return 'Otro';
    }
  }

  /// Formateo estándar con símbolo de $ y separadores.
  String get displayAmount =>
      NumberFormat.currency(symbol: '\$').format(amount);

  /// Clona cambiando solo los campos dados.
  TransactionData2 copyWith({
    int? id,
    DateTime? date,
    int? categoryId,
    int? frequencyId,
    double? amount,
    int? movementId,
    int? budgetId,
  }) => TransactionData2(
    id: id ?? this.id,
    date: date ?? this.date,
    categoryId: categoryId ?? this.categoryId,
    frequencyId: frequencyId ?? this.frequencyId,
    amount: amount ?? this.amount,
    movementId: movementId ?? this.movementId,
    budgetId: budgetId ?? this.budgetId,
  );
}

class TransactionData {
  int? idTransaction;

  String type;
  String displayAmount;
  double rawAmount;
  String category;
  DateTime date;
  String frequency;

  TransactionData({
    this.idTransaction,
    required this.type,
    required this.displayAmount,
    required this.rawAmount,
    required this.category,
    required this.date,
    required this.frequency,
  });

  // copyWith para clonado seguro
  TransactionData copyWith({
    int? idTransaction,
    String? type,
    String? displayAmount,
    double? rawAmount,
    String? category,
    DateTime? date,
    String? frequency,
  }) => TransactionData(
    idTransaction: idTransaction ?? this.idTransaction,
    type: type ?? this.type,
    displayAmount: displayAmount ?? this.displayAmount,
    rawAmount: rawAmount ?? this.rawAmount,
    category: category ?? this.category,
    date: date ?? this.date,
    frequency: frequency ?? this.frequency,
  );

  // (de)serialización
  Map<String, dynamic> toJson() => {
    'idTransaction': idTransaction,
    'type': type,
    'displayAmount': displayAmount,
    'rawAmount': rawAmount,
    'category': category,
    'date': date.toIso8601String(),
    'frequency': frequency,
  };

  factory TransactionData.fromJson(Map<String, dynamic> json) =>
      TransactionData(
        idTransaction: json['idTransaction'] as int?,
        type: json['type'] as String,
        displayAmount: json['displayAmount'] as String,
        rawAmount: (json['rawAmount'] as num).toDouble(),
        category: json['category'] as String,
        date: DateTime.parse(json['date'] as String),
        frequency: json['frequency'] as String,
      );
}

class ItemData {
  String name;
  double amount;
  IconData? iconData;

  ItemData({required this.name, this.amount = 0.0, this.iconData});

  Map<String, dynamic> toJson() {
    return {'name': name, 'amount': amount, 'iconData': iconData?.codePoint};
  }

  factory ItemData.fromJson(Map<String, dynamic> json) {
    return ItemData(
      name: json['name'],
      amount: (json['amount'] as num).toDouble(),
      iconData:
          json['iconData'] != null
              ? IconData(json['iconData'], fontFamily: 'MaterialIcons')
              : null,
    );
  }
}

class SectionData {
  String title;
  bool isEditingTitle;
  List<ItemData> items;

  SectionData({
    required this.title,
    this.isEditingTitle = false,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory SectionData.fromJson(Map<String, dynamic> json) {
    var itemsJson = json['items'] as List;
    List<ItemData> items =
        itemsJson.map((item) => ItemData.fromJson(item)).toList();
    return SectionData(title: json['title'], items: items);
  }
}

/// Firma de la función que construye cada tile visual de la transacción
typedef TxTileBuilder = Widget Function(TransactionData tx);

/// Lista reutilizable para el bottom-sheet “Ver más”.
///  – Recibe el mapa ya agrupado y la función que pinta cada tile.
///  – Se encarga de borrar elementos sin cerrar el bottom-sheet.
/// Lista reutilizable para el bottom-sheet “Ver más” ― mantiene el estilo viejo
/// y permite borrar transacciones sin cerrar el diálogo.
class _TxList extends StatefulWidget {
  const _TxList({
    required this.grouped,
    required this.tileBuilder,
    required this.onDelete,
  });

  final Map<int, Map<int, Map<String, List<TransactionData>>>> grouped;
  final TxTileBuilder tileBuilder;
  final Future<void> Function(TransactionData) onDelete;

  @override
  State<_TxList> createState() => _TxListState();
}

class _TxListState extends State<_TxList> {
  late Map<int, Map<int, Map<String, List<TransactionData>>>> _data;

  @override
  void initState() {
    super.initState();
    _data = _clone(widget.grouped);
  }

  Map<int, Map<int, Map<String, List<TransactionData>>>> _clone(
    Map<int, Map<int, Map<String, List<TransactionData>>>> src,
  ) {
    return {
      for (final y in src.keys)
        y: {
          for (final m in src[y]!.keys)
            m: {
              for (final t in src[y]![m]!.keys)
                t: List<TransactionData>.from(src[y]![m]![t]!),
            },
        },
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final currency = context.read<ActualCurrency>().cached;

    const monthNames = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    if (_data.isEmpty) {
      return Center(
        child: Text('No hay transacciones', style: theme.typography.bodyMedium),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final year in _data.keys) ...[
          _yearDivider(theme, year.toString()),
          for (final month in _data[year]!.keys) ...[
            _monthHeader(theme, monthNames[month]),
            for (final type in ['Ingresos', 'Ahorros', 'Gastos']) ...[
              if (_data[year]![month]![type]!.isNotEmpty) ...[
                _typeHeader(theme, type),
                ..._data[year]![month]![type]!.map(
                  (tx) => Dismissible(
                    key: ValueKey('bs-${tx.idTransaction}'),
                    direction: DismissDirection.startToEnd,
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      final res = await showDialog<bool>(
                        context: context,
                        builder:
                            (c) => AlertDialog(
                              title: Text(
                                '¿Borrar transacción?',
                                style: theme.typography.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                              content: Text(
                                'Esta acción no se puede deshacer',
                                style: theme.typography.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                              actions: [
                                TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    textStyle: theme.typography.bodyMedium,
                                  ),
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    textStyle: theme.typography.bodyMedium,
                                  ),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Borrar'),
                                ),
                              ],
                            ),
                      );
                      return res ?? false;
                    },
                    onDismissed: (_) async {
                      await widget.onDelete(tx); // BD + estado global
                      setState(
                        () => _data[year]![month]![type]!.remove(tx),
                      ); // UI
                      // Limpia estructuras vacías
                      if (_data[year]![month] != null) {
                        _data[year]![month]!.removeWhere((_, l) => l.isEmpty);
                      }
                      if (_data[year]![month]!.isEmpty)
                        _data[year]!.remove(month);
                      if (_data[year]!.isEmpty) _data.remove(year);
                    },
                    child: widget.tileBuilder(tx),
                  ),
                ),
                // ─── Resumen por tipo ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 12, right: 10),
                  child: Text(
                    '$type de ${monthNames[month]}, $year: '
                    '${NumberFormat.currency(symbol: currency, decimalDigits: 2).format(_data[year]![month]![type]!.fold<double>(0, (s, tx) => s + tx.rawAmount))}',
                    style: theme.typography.bodySmall.override(
                      color: theme.primaryText,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
                const FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Divider(thickness: 1, color: Colors.white),
                ),
              ],
            ],
          ],
        ],
      ],
    );
  }

  /* ──────────── helpers de estilo ──────────── */

  Widget _yearDivider(FlutterFlowThemeData th, String txt) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        const Expanded(child: Divider(thickness: 1, color: Colors.white)),
        const SizedBox(width: 12),
        Text(
          txt,
          style: th.typography.titleMedium.override(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(thickness: 1, color: Colors.white)),
      ],
    ),
  );

  Widget _monthHeader(FlutterFlowThemeData th, String txt) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 2),
    child: Text(
      txt,
      style: th.typography.bodyMedium.override(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: th.primaryText,
      ),
    ),
  );

  Widget _typeHeader(FlutterFlowThemeData th, String txt) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Text(
      txt,
      textAlign: TextAlign.center,
      style: th.typography.bodyMedium.override(
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

// PANTALLA PRINCIPAL, usando FlutterFlowTheme y ajustando posicionamiento

class StatisticsHomeScreen extends StatefulWidget {
  const StatisticsHomeScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsHomeScreen> createState() => _StatisticsHomeScreenState();
}

class _StatisticsHomeScreenState extends State<StatisticsHomeScreen> {
  // Lista de transacciones guardadas
  final List<TransactionData> _transactions = [];

  // Valor base (total del card de Ingresos)
  double _incomeCardTotal = 0.0;

  // Totales de transacciones Gastos y Ahorros
  double _totalExpense = 0.0;
  double _totalSaving = 0.0;

  // Balance actual = Ingresos - (Gastos + Ahorros)
  double _currentBalance = 0.0;

  bool _importing = false;

  String get _currency => context.read<ActualCurrency>().cached;
  @override
  void initState() {
    super.initState();
    _ensureDbAndLoad();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _ensureDbAndLoad() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Espera a que la BD abra (pero solo si aún no está la misma)
    if (SqliteManager.instance.dbIsFor(uid) == false) {
      await SqliteManager.instance.initDbForUser(uid);
    }

    await _loadData();
  }

  // Recalcula los totales
  void _recalculateTotals() {
    _totalExpense = 0;
    _totalSaving = 0;

    for (var tx in _transactions) {
      if (tx.type == 'Gastos') {
        _totalExpense += tx.rawAmount;
      } else if (tx.type == 'Ahorros') {
        _totalSaving += tx.rawAmount;
      }
    }
    _currentBalance = _incomeCardTotal - _totalExpense - _totalSaving;
  }

  Future<TransactionData2> _toPersistedModel(
    TransactionData uiTx,
    DatabaseExecutor exec,
    int idBudget,
  ) async {
    final movementId = switch (uiTx.type) {
      'Gastos' => 1,
      'Ingresos' => 2,
      'Ahorros' => 3,
      _ => 1,
    };

    final catId =
        Sqflite.firstIntValue(
          await exec.rawQuery(
            'SELECT id_category FROM category_tb '
            'WHERE name = ? AND id_movement = ? LIMIT 1',
            [uiTx.category, movementId],
          ),
        )!;
    final freqId =
        Sqflite.firstIntValue(
          await exec.rawQuery(
            'SELECT id_frequency FROM frequency_tb WHERE name = ? LIMIT 1',
            [uiTx.frequency],
          ),
        )!;

    return TransactionData2(
      id: uiTx.idTransaction,
      date: uiTx.date,
      categoryId: catId,
      frequencyId: freqId,
      amount: uiTx.rawAmount,
      movementId: movementId,
      budgetId: idBudget,
    );
  }

  Future<int> _insertTx(TransactionData2 tx, DatabaseExecutor exec) async =>
      await exec.insert(
        'transaction_tb',
        tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> _saveData() async {
    final db = SqliteManager.instance.db;
    final int? bid = Provider.of<ActiveBudget>(context, listen: false).idBudget;

    if (bid == null) return;

    final range = await periodRangeForBudget(bid);

    await db.transaction((txn) async {
      for (var i = 0; i < _transactions.length; i++) {
        final uiTx = _transactions[i];
        if (uiTx.idTransaction != null) continue;

        final persisted = await _toPersistedModel(uiTx, txn, bid);
        final newId = await _insertTx(persisted, txn);

        _transactions[i] = uiTx.copyWith(idTransaction: newId);

        if (uiTx.date.isBefore(range.end) && uiTx.date.isAfter(range.start))
          BudgetMonitor().onTransactionAdded(context, persisted.categoryId);
      }
    });

    _syncTransactionsWithFirebase(context, bid);
  }

  Future<void> _syncTransactionsWithFirebase(
    BuildContext ctx,
    int idBudget,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final txColl = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('budgets')
        .doc(idBudget.toString())
        .collection('transactions');

    final existingIds = (await txColl.get()).docs.map((d) => d.id).toSet();

    for (final uiTx in _transactions) {
      final id = uiTx.idTransaction?.toString();
      if (id == null || existingIds.contains(id)) continue;

      await txColl.doc(id).set({
        'type': uiTx.type,
        'rawAmount': uiTx.rawAmount,
        'category': uiTx.category,
        'date': uiTx.date.toIso8601String(),
        'frequency': uiTx.frequency,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  //  Cargar datos
  Future<void> _loadData() async {
    final db = SqliteManager.instance.db;

    /* Id del presupuesto activo */
    final int? idBudget =
        Provider.of<ActiveBudget>(context, listen: false).idBudget;
    if (idBudget == null) return; // sin presupuesto

    /* Salario base (card “Ingresos”, item “Salario”) */
    final salRow = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(it.amount), 0) AS total_ingresos
      FROM   card_tb      AS ca
      JOIN   item_tb      AS it   ON it.id_card     = ca.id_card
      JOIN   category_tb  AS cat  ON cat.id_category = it.id_category
      WHERE  ca.id_budget = ?          
        AND  ca.title     = 'Ingresos' 
  ''',
      [idBudget],
    );

    final double baseSalary =
        salRow.isNotEmpty
            ? (salRow.first['total_ingresos'] as num).toDouble()
            : 0.0;

    /* Transacciones para ese presupuesto — AHORA usando el helper */
    final rows = await selectTransactionsInPeriod(
      budgetId: idBudget,
      extraWhere: null,
      extraArgs: [], // filtros extra opcionales
    );

    final symbol = context.read<ActualCurrency>().cached;

    /*  Mapear a modelo de presentación */
    final txList =
        rows.map((row) {
          final tx2 = TransactionData2.fromMap(row);
          return TransactionData(
            idTransaction: row['id_transaction'] as int,
            type: row['movement_name'] as String,
            displayAmount: NumberFormat.currency(
              symbol: symbol,
              decimalDigits: 2,
            ).format(tx2.amount),
            rawAmount: tx2.amount,
            category: row['category_name'] as String,
            date: tx2.date,
            frequency: row['frequency_name'] as String,
          );
        }).toList();

    /* Sumas para balance */
    final ingresos = txList
        .where((tx) => tx.type == 'Ingresos')
        .fold<double>(0.0, (s, tx) => s + tx.rawAmount);

    final gastos = txList
        .where((tx) => tx.type == 'Gastos')
        .fold<double>(0.0, (s, tx) => s + tx.rawAmount);

    final ahorros = txList
        .where((tx) => tx.type == 'Ahorros')
        .fold<double>(0.0, (s, tx) => s + tx.rawAmount);

    /*  Refrescar estado UI */
    setState(() {
      _transactions
        ..clear()
        ..addAll(txList);

      //  🔑  INGRESOS BASE + INGRESOS DE TRANSACCIONES
      _incomeCardTotal = baseSalary + ingresos;

      _totalExpense = gastos;
      _totalSaving = ahorros;

      // Recalcula balance inmediatamente
      _recalculateTotals();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Recalcular cada vez que se reconstruye
    _recalculateTotals();
    final currency = context.watch<ActualCurrency>().cached;

    // Accede al tema de FlutterFlow
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // CONTENEDOR DEL GRÁFICO PIE CHART
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 60, 0, 0),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(57, 30, 30, 30),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 4,
                          color: Color(0x33000000),
                          offset: Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        /* ──────────── Pie + Balance ──────────── */
                        Expanded(
                          flex: 4,
                          child: LayoutBuilder(
                            builder:
                                (ctx, cts) => Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Center(
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: PieChart(
                                          PieChartData(
                                            sections: _buildPieChartSections(),
                                            centerSpaceRadius:
                                                cts.maxWidth * .30,
                                            sectionsSpace: 0,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Balance TOTAL
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'BALANCE TOTAL',
                                          style: theme.typography.bodyMedium
                                              .override(
                                                fontFamily: 'Montserrat',
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth:
                                                120, // ❶  límite duro en píxeles
                                          ),
                                          child: FittedBox(
                                            // ❷  encoge el texto si no cabe
                                            fit:
                                                BoxFit
                                                    .scaleDown, //     (opcional, evita el overflow)
                                            child: Text(
                                              '$currency${_currentBalance.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},')}',
                                              overflow:
                                                  TextOverflow
                                                      .ellipsis, // por si supera el alto
                                              style: theme.typography.bodyMedium
                                                  .override(
                                                    fontFamily: 'Montserrat',
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                          ),
                        ),

                        // Leyenda del piechart
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: _buildLegend(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // CONTENEDOR DEL GRÁFICO DE BARRAS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          0,
                          10,
                          0,
                          20,
                        ),
                        child: Container(
                          width: 250,
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(57, 30, 30, 30),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 4,
                                color: Color(0x33000000),
                                offset: Offset(0, 2),
                              ),
                            ],
                            borderRadius: const BorderRadius.all(
                              Radius.circular(40),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceEvenly,
                                barTouchData: BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: _buildBarLabelWithValue,
                                      reservedSize: 22,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  drawHorizontalLine: true,
                                  drawVerticalLine: false,
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: _buildBarChartGroups(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        0,
                        10,
                        0,
                        20,
                      ),
                      child: ElevatedButton(
                        onPressed:
                            _importing
                                ? null
                                : () async {
                                  setState(() => _importing = true);

                                  final jsonList =
                                      await authenticateUserAndFetchTransactions(
                                        context,
                                      );

                                  setState(() => _importing = false);

                                  if (!mounted) return;

                                  // La petición falló o se canceló
                                  if (jsonList == null) return;

                                  // La petición fue exitosa pero no hay transacciones
                                  if (jsonList.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No hay transacciones por registrar.',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  // Hay transacciones -> seguir con el flujo normal
                                  await _reviewImported(jsonList);
                                },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          fixedSize: const Size(120, 140),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color.fromARGB(255, 213, 253, 14),
                                Color.fromARGB(255, 217, 255, 81),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.mail,
                                  color: Colors.black,
                                  size: 30,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Extrae tus\ntransacciones\ndel correo!',
                                  textAlign: TextAlign.center,
                                  style: theme.typography.bodyMedium.override(
                                    color: const Color.fromARGB(
                                      255,
                                      45,
                                      45,
                                      45,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ROW: "Transacciones del mes" + "Ver más"
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(15, 0, 15, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transacciones del periodo',
                        style: theme.typography.titleMedium.override(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          color: theme.info,
                          fontSize: 16,
                        ),
                      ),
                      InkWell(
                        onTap: _showAllTransactions,
                        child: Text(
                          'Ver más',
                          style: theme.typography.bodySmall.override(
                            fontFamily: 'Montserrat',
                            color: const Color(0xFC2797FF),
                            decoration: TextDecoration.underline,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // LISTA DE TRANSACCIONES
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 10, 0),
                  child: _buildRecentTransactionsList(),
                ),
              ],
            ),
          ),

          // BOTÓN FLOTANTE
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton(
                onPressed: _showAddTransactionSheet,
                backgroundColor: Colors.blue,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarLabelWithValue(double value, TitleMeta meta) {
    // 1. Totales
    double gastos = 0, ahorros = 0, ingresos = 0;
    for (final tx in _transactions) {
      switch (tx.type) {
        case 'Gastos':
          gastos += tx.rawAmount;
          break;
        case 'Ahorros':
          ahorros += tx.rawAmount;
          break;
        case 'Ingresos':
          ingresos += tx.rawAmount;
          break;
      }
    }

    // 2. Selección según barra
    final f = NumberFormat('#,##0.##');
    String amount;
    switch (value.toInt()) {
      case 0:
        amount = '\$${f.format(gastos)}';
        break;
      case 1:
        amount = '\$${f.format(ahorros)}';
        break;
      case 2:
        amount = '\$${f.format(ingresos)}';
        break;
      default:
        amount = '';
    }

    // 3. Devolver envuelto
    return SideTitleWidget(
      meta: meta,
      space: 4,
      child: Text(
        amount,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // Construye las secciones del PieChart basadas en los montos

  List<PieChartSectionData> _buildPieChartSections() {
    if (_incomeCardTotal == 0 && _totalExpense == 0 && _totalSaving == 0) {
      // Si no hay Ingresos, pinta todo de gris
      return [
        PieChartSectionData(
          color: Colors.grey,
          value: 100,
          showTitle: false,
          radius: 25,
        ),
      ];
    }

    double greenPercent = 0.0;
    double redPercent = 0.0;
    double bluePercent = 0.0;

    if (_incomeCardTotal == 0) {
      greenPercent = _currentBalance;
      redPercent = _totalExpense;
      bluePercent = _totalSaving;
    } else {
      greenPercent = (_currentBalance / _incomeCardTotal) * 100;
      redPercent = (_totalExpense / _incomeCardTotal) * 100;
      bluePercent = (_totalSaving / _incomeCardTotal) * 100;
    }

    final sections = <PieChartSectionData>[];

    if (redPercent > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color.fromARGB(255, 241, 34, 34),
          value: redPercent,
          showTitle: false,
          radius: 25,
        ),
      );
    }
    if (bluePercent > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color.fromARGB(255, 0, 134, 244),
          value: bluePercent,
          showTitle: false,
          radius: 25,
        ),
      );
    }
    if (greenPercent > 0) {
      sections.add(
        PieChartSectionData(
          color: const Color.fromARGB(255, 42, 189, 47),
          value: greenPercent,
          showTitle: false,
          radius: 25,
        ),
      );
    }
    return sections;
  }

  // Leyenda con porcentajes (usamos el theme como parámetro para estilos)

  Widget _buildLegend() {
    final theme = FlutterFlowTheme.of(context);

    /* ───────── TOTALES ───────── */
    double gastos = 0, ahorros = 0;
    for (final tx in _transactions) {
      if (tx.type == 'Gastos') gastos += tx.rawAmount;
      if (tx.type == 'Ahorros') ahorros += tx.rawAmount;
    }

    // Ingresos = tarjeta “Ingresos” + transacciones de ingreso
    final double ingresos = _incomeCardTotal;

    /* ────── Cuando no hay datos ────── */
    if (ingresos == 0 && gastos == 0 && ahorros == 0) {
      return Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No hay datos\n disponibles',
              overflow: TextOverflow.ellipsis,
              style: theme.typography.bodySmall.override(
                fontFamily: 'Montserrat',
                color: theme.primaryText,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    }

    final double disponible = math.max(ingresos - gastos - ahorros, 0);

    final legendData = <Map<String, dynamic>>[
      if (gastos > 0)
        {
          'type': 'Gastos',
          'color': const Color.fromARGB(255, 241, 34, 34),
          'value': gastos,
        },
      if (ahorros > 0)
        {
          'type': 'Ahorros',
          'color': const Color.fromARGB(255, 0, 134, 244),
          'value': ahorros,
        },
      if (disponible > 0)
        {
          // “Ingresos” representa lo que **queda** luego de gastos + ahorros
          'type': 'Ingresos',
          'color': const Color.fromARGB(255, 42, 189, 47),
          'value': disponible,
        },
    ];

    final double totalBase = ingresos == 0 ? 1 : ingresos; // evita ÷0

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          legendData.map((item) {
            final color = item['color'] as Color;
            final type = item['type'] as String;
            final value = item['value'] as double;
            final percent = (value / totalBase) * 100;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  /* bolita de color */
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color.withOpacity(.8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  /* texto */
                  Expanded(
                    child: AutoSizeText(
                      '$type (${percent.toStringAsFixed(1)} %)',
                      style: theme.typography.bodySmall.override(
                        fontFamily: 'Montserrat',
                        color: theme.primaryText,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      minFontSize: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  // Construye los grupos del gráfico de barras (Gastos, Ahorros, Ingresos)

  List<BarChartGroupData> _buildBarChartGroups() {
    double totalGastos = 0.0;
    double totalAhorros = 0.0;
    double totalIngresos = 0.0;

    for (var tx in _transactions) {
      switch (tx.type) {
        case 'Gastos':
          totalGastos += tx.rawAmount;
          break;
        case 'Ahorros':
          totalAhorros += tx.rawAmount;
          break;
        case 'Ingresos':
          totalIngresos += tx.rawAmount;
          break;
      }
    }

    if (totalIngresos <= 0 && totalGastos <= 0 && totalAhorros <= 0) {
      totalIngresos = 2000;
      totalAhorros = 1300;
      totalGastos = 1100;
    }

    return [
      BarChartGroupData(
        x: 0,
        barRods: [
          BarChartRodData(
            toY: totalGastos,
            width: 18,
            color: Color.fromARGB(255, 241, 34, 34),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
        ],
      ),
      BarChartGroupData(
        x: 1,
        barRods: [
          BarChartRodData(
            toY: totalAhorros,
            width: 18,
            color: Color.fromARGB(255, 0, 134, 244),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
        ],
      ),
      BarChartGroupData(
        x: 2,
        barRods: [
          BarChartRodData(
            toY: totalIngresos,
            width: 18,
            color: const Color.fromARGB(255, 42, 189, 47),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
        ],
      ),
    ];
  }

  // Lista de transacciones con el estilo FlutterFlow

  Widget _buildRecentTransactionsList() {
    final theme = FlutterFlowTheme.of(context);

    if (_transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 110),
          child: Text(
            'Presiona el botón + para agregar transacciones!',
            style: theme.typography.bodyMedium.override(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final recentTx = _transactions.toList();

    return SizedBox(
      height: 300,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: recentTx.length,
        itemBuilder: (context, index) {
          final tx = recentTx[index];

          Color iconColor;
          IconData iconData;

          if (tx.type == 'Gastos') {
            iconColor = Color.fromARGB(255, 241, 34, 34);
            iconData = Icons.money_off_rounded;
          } else if (tx.type == 'Ingresos') {
            iconColor = Color.fromARGB(255, 42, 189, 47);
            iconData = Icons.attach_money;
          } else {
            iconColor = Color.fromARGB(255, 0, 134, 244);
            iconData = Icons.savings;
          }

          final dateStr = DateFormat('dd/MM/yyyy').format(tx.date);

          return Dismissible(
            key: ValueKey(tx.idTransaction ?? index), // identificador único
            direction:
                DismissDirection.startToEnd, // deslizar de derecha -> izq.
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) async {
              // diálogo de confirmación opcional
              return await showDialog<bool>(
                    context: context,
                    builder:
                        (c) => AlertDialog(
                          title: Text(
                            '¿Borrar transacción?',
                            style: theme.typography.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          content: Text(
                            'Esta acción no se puede deshacer.',
                            style: theme.typography.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          actions: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue, // fondo
                                foregroundColor:
                                    Colors.white, // texto / iconos ⇒ ¡blanco!
                                textStyle: theme.typography.bodyMedium,
                              ),
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red, // fondo
                                foregroundColor:
                                    Colors.white, // texto / iconos ⇒ ¡blanco!
                                textStyle: theme.typography.bodyMedium,
                              ),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Si, Borrar'),
                            ),
                          ],
                        ),
                  ) ??
                  false;
            },
            onDismissed: (_) => _deleteTransaction(tx),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 10, 5),
              child: Card(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                color: theme.secondaryBackground,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          10,
                          12,
                          0,
                          0,
                        ),
                        child: Icon(iconData, color: iconColor, size: 24),
                      ),
                    ),
                    Align(
                      alignment: const AlignmentDirectional(-0.58, 0),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          0,
                          5,
                          0,
                          5,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category
                            Text(
                              tx.category,
                              style: theme.typography.bodyMedium.override(
                                fontFamily: 'Montserrat',
                                color: theme.primaryText,
                              ),
                            ),
                            // Date
                            Text(
                              dateStr,
                              style: theme.typography.bodySmall.override(
                                fontFamily: 'Montserrat',
                                color: theme.secondaryText,
                              ),
                            ),
                            if (tx.frequency != 'Solo por hoy')
                              Text(
                                tx.frequency,
                                style: theme.typography.bodySmall.override(
                                  fontFamily: 'Montserrat',
                                  color: theme.secondaryText,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: const AlignmentDirectional(1, 0),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          0,
                          15,
                          18,
                          0,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 120, // ❶ tope de anchura
                          ),
                          child: FittedBox(
                            // ❷ adapta (reduce) el texto si no cabe
                            fit: BoxFit.scaleDown,
                            child: Text(
                              tx.displayAmount,
                              textAlign: TextAlign.center,
                              style: theme.typography.bodyMedium.override(
                                fontFamily: 'Montserrat',
                                color: iconColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow:
                                  TextOverflow
                                      .ellipsis, // (extra) oculta si excede el alto
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _normalizeMerchant(String raw) {
    final noDiacritics = raw
        .toUpperCase()
        .replaceAll(RegExp(r'[ÁÀÂÄ]'), 'A')
        .replaceAll(RegExp(r'[ÉÈÊË]'), 'E')
        .replaceAll(RegExp(r'[ÍÌÎÏ]'), 'I')
        .replaceAll(RegExp(r'[ÓÒÔÖ]'), 'O')
        .replaceAll(RegExp(r'[ÚÙÛÜ]'), 'U')
        .replaceAll(RegExp(r'Ñ'), 'N');

    return noDiacritics
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), '') // quita símbolos
        .replaceAll(RegExp(r'\s+'), ' ') // espacios dobles
        .trim();
  }

  /// Devuelve el id_category previamente mapeado, o null
  Future<int?> _mappedCategoryId(DatabaseExecutor txn, String merchant) async {
    final norm = _normalizeMerchant(merchant);

    final rows = await txn.rawQuery(
      '''
    SELECT id_category
    FROM   merchant_map_tb
    WHERE  ? LIKE '%' || merchant || '%'     
       OR  merchant LIKE '%' || ? || '%'     
    ORDER  BY LENGTH(merchant) DESC          
    LIMIT  1
  ''',
      [norm, norm],
    );

    return rows.isEmpty ? null : rows.first['id_category'] as int;
  }

  /// Guarda o actualiza el mapeo (merchant → id_category)
  Future<void> _upsertMerchantMapping(
    DatabaseExecutor txn,
    String merchant,
    int idCategory,
  ) async {
    final norm = _normalizeMerchant(merchant);
    await txn.insert(
      'merchant_map_tb',
      {'merchant': norm, 'id_category': idCategory},
      conflictAlgorithm: ConflictAlgorithm.replace, // UPSERT
    );
  }

  Future<void> _reviewImported(List<Map<String, dynamic>> raw) async {
  if (raw.isEmpty) return;

  final db = SqliteManager.instance.db;
  final List<_ReviewTx> items = [];

  for (final m in raw) {
    final merchant = (m['comercio'] ?? '').toString();
    final amt = double.parse(m['amount']) / 100.0;
    final date = _parseDate(m['date'] as String);

    String catName = 'Otros';
    final mappedId = await _mappedCategoryId(db, merchant);
    if (mappedId != null) {
      final row = await db.query(
        'category_tb',
        columns: ['name'],
        where: 'id_category = ?',
        whereArgs: [mappedId],
        limit: 1,
      );
      if (row.isNotEmpty) catName = row.first['name'] as String;
    }

    items.add(_ReviewTx(
      merchant: merchant,
      tx: TransactionData(
        idTransaction: null,
        type: 'Gastos',
        displayAmount: _displayFmt(amt),
        rawAmount: amt,
        category: catName,
        date: date,
        frequency: 'Solo por hoy',
      ),
    ));
  }

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final theme = FlutterFlowTheme.of(ctx);
      final size = MediaQuery.of(ctx).size;
      final dlgW = size.width * 0.95;
      final dlgH = size.height * 0.85;

      bool isSimilarMerchant(String a, String b) {
        final norm = (String s) =>
            s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final na = norm(a), nb = norm(b);
        return na.contains(nb) || nb.contains(na);
      }

      return StatefulBuilder(
        builder: (ctx, setSB) => AlertDialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: theme.primaryBackground,
          title: Text(
            'Revisar las transacciones',
            style: theme.typography.titleLarge,
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: dlgW,
            height: dlgH,
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (c, i) {
                final itm = items[i];
                final tx = itm.tx;
                final catCtrl = TextEditingController(text: tx.category);

                return Dismissible(
                  key: ValueKey(itm.hashCode),
                  direction: DismissDirection.startToEnd,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 24),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => setSB(() => items.removeAt(i)),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${itm.merchant}  •  ${tx.displayAmount}',
                            style: theme.typography.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatWithOptionalTime(tx.date),
                            style: theme.typography.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final cat = await _showCategoryDialog('Gastos');
                              if (cat != null) {
                                setSB(() {
                                  // Propaga a todos los merchants "similares"
                                  for (var entry in items) {
                                    if (isSimilarMerchant(entry.merchant, itm.merchant)) {
                                      entry.tx = entry.tx.copyWith(category: cat);
                                    }
                                  }
                                });
                              }
                            },
                            child: TextField(
                              controller: catCtrl,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: 'Categoría',
                                labelStyle: theme.typography.bodySmall
                                    .override(color: theme.secondaryText),
                                disabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                textStyle: theme.typography.bodyMedium,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle: theme.typography.bodyMedium,
              ),
              onPressed: items.isEmpty
                  ? null
                  : () async {
                      setState(() {
                        _transactions.addAll(items.map((e) => e.tx));
                        _transactions.sort((a, b) => b.date.compareTo(a.date));
                      });

                      await db.transaction((txn) async {
                        for (final it in items) {
                          final row = await txn.query(
                            'category_tb',
                            columns: ['id_category'],
                            where: 'name = ?',
                            whereArgs: [it.tx.category],
                            limit: 1,
                          );
                          if (row.isNotEmpty) {
                            final idCat = row.first['id_category'] as int;
                            await _upsertMerchantMapping(txn, it.merchant, idCat);
                          }
                        }
                      });

                      await _saveData();
                      if (mounted) Navigator.pop(ctx);
                    },
              child: const Text('Guardar todo'),
            ),
          ],
        ),
      );
    },
  );
}


  /// Devuelve `true` si la cadena tiene hora al final (hh:mm).
  bool _hasTime(String s) => RegExp(r'\b\d{1,2}:\d{2}$').hasMatch(s.trim());

  /// Parsea la fecha con o sin hora según lo detectado.
  DateTime _parseDate(String s) {
    final fmt = DateFormat(_hasTime(s) ? 'dd/MM/yy HH:mm' : 'dd/MM/yyyy');
    return fmt.parseStrict(s);
  }

  /// Formatea para mostrar: con hora si la traía, sin hora en caso contrario.
  String formatWithOptionalTime(DateTime dt) {
    final hasTime = dt.hour != 0 || dt.minute != 0 || dt.second != 0;
    final fmt = DateFormat(hasTime ? 'dd/MM/yy  HH:mm' : 'dd/MM/yyyy');
    return fmt.format(dt);
  }

  Future<void> _deleteTransaction(TransactionData tx) async {
    // 1) quitarla de la lista y refrescar UI/gráficas
    setState(() {
      _transactions.remove(tx);
      _recalculateTotals();
    });

    // 2) borrar de SQLite
    if (tx.idTransaction != null) {
      await SqliteManager.instance.db.delete(
        'transaction_tb',
        where: 'id_transaction = ?',
        whereArgs: [tx.idTransaction],
      );
    }

    // 3) borrar de Firestore (si existe)
    final user = FirebaseAuth.instance.currentUser;
    final bid = context.read<ActiveBudget>().idBudget;
    if (user != null && bid != null && tx.idTransaction != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('budgets')
          .doc(bid.toString())
          .collection('transactions')
          .doc(tx.idTransaction.toString())
          .delete();
    }

    // 4) aviso breve
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transacción eliminada')));
    }
  }

  // VER MÁS -> mostrar todas las transacciones en un bottom sheet

  void _showAllTransactions() async {
    final theme = FlutterFlowTheme.of(context);
    final grouped = await _groupedTxByType();
    if (grouped.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No hay transacciones')));
      return;
    }

    // ❶  Mostramos el bottom-sheet y esperamos a que se cierre
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.primaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder:
              (_, __) => _TxList(
                grouped: grouped,
                tileBuilder: _buildTransactionTile, // ← le pasamos tu builder
                onDelete: _deleteTransaction, // ← callback a la BD
              ),
        );
      },
    );

    // ❷  Cuando el usuario cierre manualmente → refrescamos la pantalla padre
    if (mounted) await _loadData();
  }

  // Agrupa transacciones por año y mes, ordenadas por fecha descendente
  Future<Map<int, Map<int, Map<String, List<TransactionData>>>>>
  _groupedTxByType() async {
    final db = SqliteManager.instance.db;
    final _currency = context.read<ActualCurrency>().cached;
    final int? bid = context.read<ActiveBudget>().idBudget;
    if (bid == null) return {};

    final rows = await db.rawQuery(
      '''
    SELECT t.*, m.name AS movement_name, c.name AS category_name,
           f.name AS frequency_name
    FROM   transaction_tb t
    JOIN   movement_tb   m USING(id_movement)
    JOIN   category_tb   c USING(id_category)
    JOIN   frequency_tb  f USING(id_frequency)
    WHERE  t.id_budget = ?
    ORDER  BY t.date DESC
    ''',
      [bid],
    );

    /* ── Mapear a modelo de presentación ─────────────────────────── */
    final list =
        rows.map((r) {
          final tx2 = TransactionData2.fromMap(r);
          return TransactionData(
            idTransaction: tx2.id,
            type: r['movement_name'] as String, // Ingresos, …
            displayAmount: NumberFormat.currency(
              symbol: _currency,
              decimalDigits: 2,
            ).format(tx2.amount),
            rawAmount: tx2.amount,
            category: r['category_name'] as String,
            date: tx2.date,
            frequency: r['frequency_name'] as String,
          );
        }).toList();

    /* ── Agrupar: año → mes → tipo ───────────────────────────────── */
    final Map<int, Map<int, Map<String, List<TransactionData>>>> g = {};
    for (final tx in list) {
      g.putIfAbsent(tx.date.year, () => {});
      g[tx.date.year]!.putIfAbsent(tx.date.month, () => {});
      g[tx.date.year]![tx.date.month]!.putIfAbsent(tx.type, () => []).add(tx);
    }

    /* ── Ordenar: año ↓ , mes ↓ , fechas ↓ ───────────────────────── */
    final orderedYears = g.keys.toList()..sort((b, a) => a.compareTo(b));
    final Map<int, Map<int, Map<String, List<TransactionData>>>> ordered = {};
    for (final y in orderedYears) {
      final months = g[y]!.keys.toList()..sort((b, a) => a.compareTo(b));
      ordered[y] = {};
      for (final m in months) {
        // dentro del mes ya vienen en fecha DESC
        ordered[y]![m] = {
          'Ingresos': g[y]![m]!['Ingresos'] ?? [],
          'Ahorros': g[y]![m]!['Ahorros'] ?? [],
          'Gastos': g[y]![m]!['Gastos'] ?? [],
        };
      }
    }
    return ordered;
  }

  // Item para cada transacción en "Ver más"
  Widget _buildTransactionTile(TransactionData tx) {
    final theme = FlutterFlowTheme.of(context);

    Color color;
    if (tx.type == 'Gastos') {
      color = Colors.red;
    } else if (tx.type == 'Ingresos') {
      color = Colors.green;
    } else {
      color = Colors.blue;
    }
    final dateStr = DateFormat('dd/MM/yyyy').format(tx.date);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.category,
                  style: theme.typography.bodyMedium.override(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  dateStr,
                  style: theme.typography.bodySmall.override(
                    color: Colors.grey,
                  ),
                ),
                if (tx.frequency != 'Solo por hoy')
                  Text(
                    'Frecuencia: ${tx.frequency}',
                    style: theme.typography.bodySmall.override(
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            tx.displayAmount,
            style: theme.typography.bodyMedium.override(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // BOTÓN + => Agregar Nueva Transacción
  void _showAddTransactionSheet() async {
    final _currency = context.read<ActualCurrency>().cached;
    final frequencyOptions = await _getFrequencyNames();
    if (frequencyOptions.isEmpty) return;

    DateTime selectedDate = DateTime.now();
    final dateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(selectedDate),
    );

    String transactionType = 'Gastos'; // 'Gastos', 'Ingresos', 'Ahorros'
    final categoryController = TextEditingController(text: 'Otros');
    String selectedFrequency = 'Solo por hoy';

    final montoController = TextEditingController(text: '0');
    final formatter = NumberFormat('#,##0.##');

    final theme = FlutterFlowTheme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setBottomState) {
            final mq = MediaQuery.of(ctx);
            final height = mq.size.height * 0.65;

            return GestureDetector(
              behavior: HitTestBehavior.opaque, // capta taps en zonas vacías
              onTap: () => FocusScope.of(ctx).unfocus(), // cierra teclado
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(ctx).primaryBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(50),
                    topRight: Radius.circular(50),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 24,
                    bottom: mq.viewInsets.bottom + 24,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // ────────── Título ──────────
                        Text(
                          'Registrar transacción',
                          style: FlutterFlowTheme.of(
                            ctx,
                          ).typography.titleLarge.override(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ────────── Botones tipo ──────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTypeButton(
                              label: 'Gastos',
                              selected: transactionType == 'Gastos',
                              onTap:
                                  () => setBottomState(() {
                                    transactionType = 'Gastos';
                                    categoryController.clear();
                                  }),
                            ),
                            _buildTypeButton(
                              label: 'Ingresos',
                              selected: transactionType == 'Ingresos',
                              onTap:
                                  () => setBottomState(() {
                                    transactionType = 'Ingresos';
                                    categoryController.clear();
                                  }),
                            ),
                            _buildTypeButton(
                              label: 'Ahorros',
                              selected: transactionType == 'Ahorros',
                              onTap:
                                  () => setBottomState(() {
                                    transactionType = 'Ahorros';
                                    categoryController.clear();
                                  }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ────────── Categoría (solo lectura) ──────────
                        InkWell(
                          onTap: () async {
                            final chosenCat = await _showCategoryDialog(
                              transactionType,
                            );
                            if (chosenCat != null) {
                              setBottomState(
                                () => categoryController.text = chosenCat,
                              );
                            }
                          },
                          child: TextField(
                            controller: categoryController,
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: 'Categoría',
                              labelStyle: FlutterFlowTheme.of(
                                ctx,
                              ).typography.bodySmall.override(
                                color: FlutterFlowTheme.of(ctx).secondaryText,
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Colors.grey,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ────────── Campo Monto ──────────
                        TextField(
                          controller: montoController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Monto',
                            prefix: Text(_currency),
                            labelStyle: FlutterFlowTheme.of(
                              ctx,
                            ).typography.bodySmall.override(
                              color: FlutterFlowTheme.of(ctx).secondaryText,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          onChanged: (val) {
                            String raw = val.replaceAll(',', '');
                            if (raw.contains('.')) {
                              final dot = raw.indexOf('.');
                              final dec = raw.length - dot - 1;
                              if (dec > 2) raw = raw.substring(0, dot + 3);
                              if (raw == '.') raw = '0.';
                            }
                            double number = double.tryParse(raw) ?? 0.0;

                            if (raw.endsWith('.') ||
                                raw.matchesDecimalWithOneDigitEnd()) {
                              final parts = raw.split('.');
                              final intPart = double.tryParse(parts[0]) ?? 0.0;
                              final formattedInt =
                                  formatter.format(intPart).split('.')[0];
                              final partialDec =
                                  parts.length > 1 ? '.${parts[1]}' : '';
                              final newStr = '$formattedInt$partialDec';
                              montoController.value = TextEditingValue(
                                text: newStr,
                                selection: TextSelection.collapsed(
                                  offset: newStr.length,
                                ),
                              );
                            } else {
                              final formatted = formatter.format(number);
                              montoController.value = TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(
                                  offset: formatted.length,
                                ),
                              );
                            }
                          },
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: Colors.grey, thickness: 1),
                        ),

                        // ────────── Frecuencia ──────────
                        Row(
                          children: [
                            Text(
                              'Frecuencia: ',
                              style:
                                  FlutterFlowTheme.of(ctx).typography.bodyLarge,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton2<String>(
                                value: selectedFrequency,
                                isExpanded: true,
                                dropdownStyleData: const DropdownStyleData(
                                  maxHeight: 250,
                                  padding: EdgeInsets.symmetric(vertical: 1),
                                ),
                                items:
                                    frequencyOptions
                                        .map(
                                          (f) => DropdownMenuItem(
                                            value: f,
                                            child: Text(
                                              f,
                                              style: theme.typography.bodyLarge,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setBottomState(
                                      () => selectedFrequency = val,
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: Colors.grey, thickness: 1),
                        ),

                        // ────────── Fecha ──────────
                        TextField(
                          style: theme.typography.bodyLarge,
                          controller: dateCtrl,
                          readOnly: true,
                          onTap: () async {
                            final picked = await _selectDate(
                              context,
                              selectedDate,
                            );
                            if (picked != null) {
                              setBottomState(() {
                                selectedDate = picked;
                                dateCtrl.text = DateFormat(
                                  'yyyy-MM-dd',
                                ).format(picked);
                              });
                            }
                          },
                          decoration: const InputDecoration(
                            filled: true,
                            prefixIcon: Icon(Icons.calendar_today),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ────────── Botones ──────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(
                                'Cancelar',
                                style: theme.typography.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                              onPressed: () async {
                                final raw = montoController.text
                                    .replaceAll(',', '')
                                    .replaceAll('\$', '');
                                final number = double.tryParse(raw) ?? 0.0;
                                final cat = categoryController.text.trim();

                                // ─── VALIDACIÓN ──────────────────────────────────────────────
                                if (cat.isEmpty || number <= 0) {
                                  if (ctx.mounted) Navigator.of(ctx).pop();

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Debes llenar la categoría y el monto!',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                if (number > 0.0 && cat.isNotEmpty) {
                                  if (transactionType == 'Ingresos') {
                                    setState(() => _incomeCardTotal += number);
                                  }

                                  setState(() {
                                    _transactions.add(
                                      TransactionData(
                                        idTransaction: null,
                                        type: transactionType,
                                        displayAmount: _displayFmt(number),
                                        rawAmount: number,
                                        category: cat,
                                        date: selectedDate,
                                        frequency: selectedFrequency,
                                      ),
                                    );
                                    _transactions.sort(
                                      (a, b) => b.date.compareTo(
                                        a.date,
                                      ), // ← orden descendente por fecha
                                    );
                                  });

                                  try {
                                    await _saveData(); //  ←  ESPERAR
                                  } catch (e, st) {
                                    debugPrint('⛔️ Error en _saveData(): $e');
                                    debugPrintStack(stackTrace: st);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Error guardando: $e'),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                }
                                if (context.mounted) Navigator.of(ctx).pop();
                              },
                              child: Text(
                                'Aceptar',
                                style: theme.typography.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _displayFmt(double v) =>
      NumberFormat.currency(symbol: _currency, decimalDigits: 2).format(v);

  // DIALOGO CATEGORÍAS

  Future<String?> _showCategoryDialog(String type) async {
    final theme = FlutterFlowTheme.of(context);
    final categories = await _getCategoriesForType(type);
    final mediaWidth = MediaQuery.of(context).size.width;
    final movementId = _movementIdForType(type);

    final headerGradient =
        movementId == 1
            ? [Colors.red.shade700, Colors.red.shade400]
            : movementId == 2
            ? [Colors.green.shade700, Colors.green.shade400]
            : [Color(0xFF132487), Color(0xFF1C3770)];

    final avatarBgColor =
        movementId == 1
            ? Colors.red.withOpacity(0.2)
            : movementId == 2
            ? Colors.green.withOpacity(0.2)
            : theme.accent1;

    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => AlertDialog(
            // forma + borde redondeado
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            backgroundColor: theme.primaryBackground,

            // cabecera degradada
            titlePadding: EdgeInsets.zero,
            title: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Text(
                'Seleccionar Categoría',
                textAlign: TextAlign.center,
                style: theme.typography.titleLarge.override(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            content: SizedBox(
              width: mediaWidth.clamp(0, 430) * 0.75,
              height: 550,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 16),
                itemCount: (categories.length / 3).ceil(),
                itemBuilder: (ctx, rowIx) {
                  final start = rowIx * 3;
                  final end = (start + 3).clamp(0, categories.length);
                  final rowCats = categories.sublist(start, end);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /* FILA DE TARJETAS  */
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment:
                            CrossAxisAlignment.start, // evita brincos
                        children:
                            rowCats.map((cat) {
                              final name = cat['name'] as String;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.of(ctx).pop(name),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: avatarBgColor,
                                        child: Icon(
                                          cat['icon'] as IconData,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      AutoSizeText(
                                        name,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: theme.primaryText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        minFontSize: 8,
                                        overflow: TextOverflow.ellipsis,
                                        stepGranularity: 1,
                                        wrapWords: false,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                      ),

                      /* DIVIDER (menos en la última fila)  */
                      if (rowIx < (categories.length / 3).ceil() - 1) ...[
                        const SizedBox(height: 12),
                        Divider(color: theme.secondaryText, thickness: 1),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
    );
  }

  //   Utilidad: de tipo -> id_movement
  int _movementIdForType(String type) {
    switch (type) {
      case 'Gastos':
        return 1;
      case 'Ingresos':
        return 2;
      case 'Ahorros':
        return 3;
      default:
        return 0;
    }
  }

  // Lee categorías + icon_name desde SQLite
  Future<List<Map<String, dynamic>>> _getCategoriesForType(String type) async {
    final db = SqliteManager.instance.db;
    final idMove = _movementIdForType(type);

    // Si idMove == 0 traemos TODAS (backup)
    final rows = await db.rawQuery(
      idMove == 0
          ? 'SELECT name, icon_name FROM category_tb'
          : 'SELECT name, icon_name FROM category_tb WHERE id_movement = ?',
      idMove == 0 ? [] : [idMove],
    );

    return rows.map((r) {
      final iconName = r['icon_name'] as String;
      return {
        'name': r['name'] as String,
        'icon': _materialIconByName[iconName] ?? Icons.category,
      };
    }).toList();
  }

  static const Map<String, IconData> _materialIconByName = {
    'directions_bus': Icons.directions_bus,
    'movie': Icons.movie,
    'school': Icons.school,
    'account_balance': Icons.account_balance,
    'fastfood': Icons.fastfood,
    'credit_card': Icons.credit_card,
    'category': Icons.category,
    'bolt': Icons.bolt,
    'wifi': Icons.wifi,
    'health_and_safety': Icons.health_and_safety,
    'shopping_bag': Icons.shopping_bag,
    'card_giftcard': Icons.card_giftcard,
    'pets': Icons.pets,
    'home_repair_service': Icons.home_repair_service,
    'home': Icons.home,
    'spa': Icons.spa,
    'security': Icons.security,
    'request_quote': Icons.request_quote,
    'subscriptions': Icons.subscriptions,
    'sports_soccer': Icons.sports_soccer,
    'local_gas_station': Icons.local_gas_station,
    'paid': Icons.paid,
    'local_parking': Icons.local_parking,
    'car_repair': Icons.car_repair,
    'live_tv': Icons.live_tv,
    'fitness_center': Icons.fitness_center,
    'phone_android': Icons.phone_android,
    'attach_money': Icons.attach_money,
    'payments': Icons.payments,
    'show_chart': Icons.show_chart,
    'star': Icons.star,
    'work': Icons.work,
    'trending_up': Icons.trending_up,
    'undo': Icons.undo,
    'apartment': Icons.apartment,
    'sell': Icons.sell,
    'stacked_line_chart': Icons.stacked_line_chart,
    'elderly': Icons.elderly,
    'shopping_cart': Icons.shopping_cart,
    'medical_services': Icons.medical_services,
    'savings': Icons.savings,
    'beach_access': Icons.beach_access,
    'build': Icons.build,
    'account_balance_wallet': Icons.account_balance_wallet,
    'favorite': Icons.favorite,
    'directions_car': Icons.directions_car,
    'house': Icons.house,
    'flight': Icons.flight,
    'priority_high': Icons.priority_high,
  };
}

Future<DateTime?> _selectDate(BuildContext ctx, DateTime initialDate) {
  return showDatePicker(
    context: ctx,
    initialDate: initialDate,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    helpText: '',
    cancelText: 'Cancelar',
    confirmText: 'OK',
  );
}

// Botón para seleccionar "Gastos", "Ingresos" o "Ahorros"

Widget _buildTypeButton({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color:
            selected
                ? {
                      'Gastos': Colors.red,
                      'Ingresos': Colors.green,
                      'Ahorros': Colors.blue,
                    }[label] ??
                    Colors.blue
                : const Color(0xFF959595),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

// Extensión para manejar decimales parciales (ej: 99.9, 0.5, etc.)

extension _StringDecimalExt on String {
  bool matchesDecimalWithOneDigitEnd() {
    final noCommas = replaceAll(',', '');
    return RegExp(r'^[0-9]*\.[0-9]$').hasMatch(noCommas);
  }
}

Future<List<String>> _getFrequencyNames() async {
  final db = SqliteManager.instance.db;
  final rows = await db.query('frequency_tb', orderBy: 'id_frequency');
  return rows.map((r) => r['name'] as String).toList();
}