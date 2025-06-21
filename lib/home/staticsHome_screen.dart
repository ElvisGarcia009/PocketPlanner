import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:Pocket_Planner/flutterflow_components/flutterflowtheme.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:Pocket_Planner/database/sqlite_management.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Pocket_Planner/functions/active_budget.dart';


// ---------------------------------------------------------------------------
// MODELOS (TransactionData, ItemData, SectionData)
// ---------------------------------------------------------------------------

class TransactionData2 {
  // ── Campos persistidos ─────────────────────────────────────────────
  final int? id;                // id_transaction (puede ser null antes de insertar)
  final DateTime date;
  final int categoryId;
  final int frequencyId;
  final double amount;
  final int movementId;         // 1 = Gastos, 2 = Ingresos, 3 = Ahorros
  final int budgetId;

  // ── Constructor ───────────────────────────────────────────────────
  const TransactionData2({
    this.id,
    required this.date,
    required this.categoryId,
    required this.frequencyId,
    required this.amount,
    required this.movementId,
    required this.budgetId,
  });

  // ── Mapeadores SQLite ↔️ Modelo ────────────────────────────────────
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

  // ── Helpers útiles para la UI ─────────────────────────────────────
  /// 'Gastos', 'Ingresos' o 'Ahorros'
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
  }) =>
      TransactionData2(
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
  // ── NUEVO ─────────────────────────────────────────────
  int? idTransaction;           // id en la tabla; null antes del INSERT

  String type;                  // 'Gastos', 'Ingresos', 'Ahorros'
  String displayAmount;         // Monto formateado
  double rawAmount;             // Monto numérico (sin formato)
  String category;              // Nombre de la categoría
  DateTime date;                // Fecha
  String frequency;             // Nombre de la frecuencia

  TransactionData({
    this.idTransaction,         // ← opcional
    required this.type,
    required this.displayAmount,
    required this.rawAmount,
    required this.category,
    required this.date,
    required this.frequency,
  });

  // ── copyWith para clonado seguro ─────────────────────
  TransactionData copyWith({
    int? idTransaction,
    String? type,
    String? displayAmount,
    double? rawAmount,
    String? category,
    DateTime? date,
    String? frequency,
  }) =>
      TransactionData(
        idTransaction: idTransaction ?? this.idTransaction,
        type: type ?? this.type,
        displayAmount: displayAmount ?? this.displayAmount,
        rawAmount: rawAmount ?? this.rawAmount,
        category: category ?? this.category,
        date: date ?? this.date,
        frequency: frequency ?? this.frequency,
      );

  // ── (de)serialización ────────────────────────────────
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
  IconData? iconData; // Se guarda el icono seleccionado

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

// ---------------------------------------------------------------------------
// PANTALLA PRINCIPAL, usando FlutterFlowTheme y ajustando posicionamiento
// ---------------------------------------------------------------------------
class StaticsHomeScreen extends StatefulWidget {
  const StaticsHomeScreen({Key? key}) : super(key: key);

  @override
  State<StaticsHomeScreen> createState() => _StaticsHomeScreenState();
}

class _StaticsHomeScreenState extends State<StaticsHomeScreen> {
  // Lista de transacciones guardadas
  final List<TransactionData> _transactions = [];

  // Valor base (total del card de Ingresos)
  double _incomeCardTotal = 0.0;
  // Totales de transacciones Gastos y Ahorros
  double _totalExpense = 0.0;
  double _totalSaving = 0.0;
  // Balance actual = Ingresos - (Gastos + Ahorros)
  double _currentBalance = 0.0;

 @override
void initState() {
  super.initState();
  _ensureDbAndLoad();
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
    int idBudget,                //  ← nuevo parámetro
) async {

  final movementId = switch (uiTx.type) {
    'Gastos'   => 1,
    'Ingresos' => 2,
    'Ahorros'  => 3,
    _          => 1,
  };

  final catId = Sqflite.firstIntValue(await exec.rawQuery(
  'SELECT id_category FROM category_tb '
  'WHERE name = ? AND id_movement = ? LIMIT 1',[uiTx.category, movementId]))!;
  final freqId = Sqflite.firstIntValue(await exec.rawQuery(
      'SELECT id_frequency FROM frequency_tb WHERE name = ? LIMIT 1',
      [uiTx.frequency]))!;

  return TransactionData2(
    id: uiTx.idTransaction,
    date: uiTx.date,
    categoryId: catId,
    frequencyId: freqId,
    amount: uiTx.rawAmount,
    movementId: movementId,
    budgetId: idBudget,      // o el presupuesto actual
  );
}

Future<int> _insertTx(TransactionData2 tx, DatabaseExecutor exec) async =>
    await exec.insert(
      'transaction_tb',
      tx.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );



Future<void> _saveData() async {
  final db  = SqliteManager.instance.db;
  final int? bid =
      Provider.of<ActiveBudget>(context, listen: false).idBudget;

  if (bid == null) return;                        // sin presupuesto activo

  await db.transaction((txn) async {
    for (var i = 0; i < _transactions.length; i++) {
      final uiTx = _transactions[i];
      if (uiTx.idTransaction != null) continue;

      final persisted = await _toPersistedModel(uiTx, txn, bid); // ← bid
      final newId     = await _insertTx(persisted, txn);
      _transactions[i] = uiTx.copyWith(idTransaction: newId);
    }
  });

  await _syncTransactionsWithFirebase(context, bid);              // ← bid
}


Future<void> _syncTransactionsWithFirebase(
    BuildContext ctx,
    int idBudget,                             // ← nuevo parámetro
) async {

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final txColl = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('budgets')                  //  ← ruta nueva
      .doc(idBudget.toString())
      .collection('transactions');

  final existingIds =
      (await txColl.get()).docs.map((d) => d.id).toSet();

  for (final uiTx in _transactions) {
    final id = uiTx.idTransaction?.toString();
    if (id == null || existingIds.contains(id)) continue;

    await txColl.doc(id).set({
      'type'       : uiTx.type,
      'rawAmount'  : uiTx.rawAmount,
      'category'   : uiTx.category,
      'date'       : uiTx.date.toIso8601String(),
      'frequency'  : uiTx.frequency,
      'createdAt'  : FieldValue.serverTimestamp(),
    });
  }
}






Future<void> _loadData() async {
  final db = SqliteManager.instance.db;

  // 1) id del presupuesto activo
  final int? idBudget =
      Provider.of<ActiveBudget>(context, listen: false).idBudget;

  // 2) Query filtrada por ese presupuesto
  const sql = '''
  SELECT
      t.id_transaction              AS id_transaction,
      t.date                        AS date,
      t.id_category                 AS id_category,
      t.id_frequency                AS id_frequency,
      t.amount                      AS amount,
      t.id_movement                 AS id_movement,
      t.id_budget                   AS id_budget,
      c.name                        AS category_name,
      c.icon_code                   AS category_icon,
      f.name                        AS frequency_name,
      m.name                        AS movement_name,     -- 'Gastos', 'Ingresos', 'Ahorros'
      b.name                        AS budget_name,
      bp.name                       AS budget_period_name
  FROM  transaction_tb      AS t
  JOIN  category_tb          AS c  ON c.id_category      = t.id_category
  JOIN  frequency_tb         AS f  ON f.id_frequency     = t.id_frequency
  JOIN  movement_tb          AS m  ON m.id_movement      = t.id_movement
  JOIN  budget_tb            AS b  ON b.id_budget        = t.id_budget
  JOIN  budgetPeriod_tb      AS bp ON bp.id_budgetPeriod = b.id_budgetPeriod
  WHERE t.id_budget = ?                 -- ← filtro
  ORDER BY t.date DESC;
  ''';

  // 3) Ejecutar con el parámetro
  final rows = await db.rawQuery(sql, [idBudget]);
  debugPrint('🔎  SELECT devolvió ${rows.length} filas para budget $idBudget');

  // ── Paso intermedio: fila -> TransactionData2 -> TransactionData ─────────────
  final txList = rows.map((row) {
    final tx = TransactionData2.fromMap(row);           // persistido

    return TransactionData(                             // presentación
      idTransaction: row['id_transaction'] as int,
      type:          row['movement_name']  as String,   // 'Gastos', 'Ingresos', 'Ahorros'
      displayAmount: tx.displayAmount,
      rawAmount:     tx.amount,
      category:      row['category_name']  as String,
      date:          tx.date,
      frequency:     row['frequency_name'] as String,
    );
  }).toList();

  // ── Calcular total de Ingresos para el balance ──────────────────────────────
  final incomeSum = txList
      .where((tx) => tx.type == 'Ingresos')
      .fold<double>(0.0, (sum, tx) => sum + tx.rawAmount);

  // ── Refrescar el estado de la UI ────────────────────────────────────────────
  setState(() {
    _transactions
      ..clear()
      ..addAll(txList);
    _incomeCardTotal = incomeSum;
  });
}


  @override
  Widget build(BuildContext context) {
    // Recalcular cada vez que se reconstruye
    _recalculateTotals();

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
                // CONTENEDOR DEL GRÁFICO
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 40, 10, 0),
                  child: Container(
                    width: double.infinity,
                    height: 235.8,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(57, 30, 30, 30),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 4,
                          color: Color(0x33000000),
                          offset: Offset(0, 2),
                        ),
                      ],
                      borderRadius: const BorderRadius.all(Radius.circular(40)),
                    ),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.center,
                            child: Transform.translate(
                            offset: _incomeCardTotal <= 0 && _totalExpense <= 0 && _totalSaving <= 0
                              ? const Offset(0, 0)
                              : const Offset(-60, 0),
                            child: PieChart(
                              PieChartData(
                              sections: _buildPieChartSections(),
                              centerSpaceRadius: 70,
                              sectionsSpace: 0,
                              ),
                            ),
                            ),
                          ),
                        Align(
                          alignment: _incomeCardTotal <= 0 && _totalExpense <= 0 && _totalSaving <= 0
                              ? const Alignment(0, 0)
                              : const Alignment(-0.42, 0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'BALANCE TOTAL',
                                style: theme.typography.bodyMedium.override(
                                  fontFamily: 'Montserrat',
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${_currentBalance.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (match) => '${match[1]},')}',
                                style: theme.typography.bodyMedium.override(
                                  fontFamily: 'Montserrat',
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: const AlignmentDirectional(1.38, 0),
                          child: _buildLegend(),
                        ),
                      ],
                    ),
                  ),
                ),

                // CONTENEDOR DEL GRÁFICO DE BARRAS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          5,
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
                                      getTitlesWidget: _buildBarLabelWithValue,   // ① le pasaremos (value, meta)
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
                      padding: const EdgeInsetsDirectional.fromSTEB(0, 18, 15, 20),
                      child: ElevatedButton(
                      onPressed: () {
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        ),
                        fixedSize: const Size(
                        120,
                        140,
                        ), 
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        const Icon(Icons.assistant, color: Colors.white, size: 30,),
                        const SizedBox(
                          height: 8,
                        ), 
                        const Text(
                          "Extrae tu \ntransacción\ncon IA",
                          style: TextStyle(color: Colors.white, fontFamily: 'Montserrat', fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        ],
                      ),
                      ),
                    ),
                  ],
                ),

                // ROW: "Transacciones del mes" + "Ver más"
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(15, 20, 15, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transacciones del mes',
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
  // ── 1. Totales ────────────────────────────
  double gastos = 0, ahorros = 0, ingresos = 0;
  for (final tx in _transactions) {
    switch (tx.type) {
      case 'Gastos':   gastos   += tx.rawAmount; break;
      case 'Ahorros':  ahorros  += tx.rawAmount; break;
      case 'Ingresos': ingresos += tx.rawAmount; break;
    }
  }

  // ── 2. Selección según barra ──────────────
  final f = NumberFormat('#,##0.##');
  String amount;
  switch (value.toInt()) {
    case 0: amount = '\$${f.format(gastos)}';   break;
    case 1: amount = '\$${f.format(ahorros)}';  break;
    case 2: amount = '\$${f.format(ingresos)}'; break;
    default: amount = '';
  }

  // ── 3. Devolver envuelto ──────────────────
  return SideTitleWidget(
    axisSide: meta.axisSide,    // ¡imprescindible!
    space: 4,                   // distancia al eje
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


  // ---------------------------------------------------------------------------
  // Construye las secciones del PieChart basadas en los montos
  // ---------------------------------------------------------------------------
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

    if (_incomeCardTotal == 0)
    {
      greenPercent = _currentBalance;
      redPercent = _totalExpense;
      bluePercent = _totalSaving;
    }
    else
    {
      greenPercent = (_currentBalance / _incomeCardTotal) * 100;
      redPercent = (_totalExpense / _incomeCardTotal) * 100;
      bluePercent = (_totalSaving / _incomeCardTotal) * 100;
    }
    

    final sections = <PieChartSectionData>[];

    if (redPercent > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.red.withOpacity(0.7),
          value: redPercent,
          showTitle: false,
          radius: 25,
        ),
      );
    }
    if (bluePercent > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.blue.withOpacity(0.7),
          value: bluePercent,
          showTitle: false,
          radius: 25,
        ),
      );
    }
    if (greenPercent > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.green.withOpacity(0.7),
          value: greenPercent,
          showTitle: false,
          radius: 25,
        ),
      );
    }
    return sections;
  }

  // ---------------------------------------------------------------------------
  // Leyenda con porcentajes (usamos el theme como parámetro para estilos)
  // ---------------------------------------------------------------------------
  Widget _buildLegend() {
  final theme = FlutterFlowTheme.of(context);

  // 1️⃣  Totales por tipo
  double gastos   = 0, ahorros = 0, ingresos = 0;
  for (final tx in _transactions) {
    switch (tx.type) {
      case 'Gastos'   : gastos   += tx.rawAmount; break;
      case 'Ahorros'  : ahorros  += tx.rawAmount; break;
      case 'Ingresos' : ingresos += tx.rawAmount; break;
    }
  }

  // 2️⃣  Lista de entradas que realmente existan
  final legendData = <Map<String, dynamic>>[
    if (gastos   > 0) {'type': 'Gastos'  , 'color': Colors.red  , 'value': gastos  },
    if (ahorros  > 0) {'type': 'Ahorros' , 'color': Colors.blue , 'value': ahorros },
    if (ingresos > 0) {'type': 'Ingresos', 'color': Colors.green, 'value': ingresos},
  ];

  final f = NumberFormat('#,##0.##');             // formateador común
  final totalGeneral = gastos + ahorros + ingresos;

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: legendData.map((item) {
      final color = item['color'] as Color;
      final type  = item['type']  as String;
      final value = item['value'] as double;
      final percent =
          totalGeneral == 0 ? 0 : (value / totalGeneral) * 100;

      return Container(
        padding: const EdgeInsetsDirectional.only(end: 50),
        margin : const EdgeInsets.only(bottom: 6),
        child  : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // bolita de color
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            // texto con total y porcentaje
            Text(
              // Muestra sólo el total
              // '$type \$${f.format(value)}',
              // o total + porcentaje, descomenta si lo quieres:
              '$type (${percent.toStringAsFixed(1)}%)',
              style: theme.typography.bodySmall.override(
                fontFamily: 'Montserrat',
                color: theme.primaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );
}


  // ---------------------------------------------------------------------------
  // Construye los grupos del gráfico de barras (Gastos, Ahorros, Ingresos)
  // ---------------------------------------------------------------------------
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

    if ( totalIngresos <= 0 && totalGastos <= 0 && totalAhorros <= 0)
    {
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
            color: Colors.red,
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
            color: Colors.blue,
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
            color: Colors.green,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
        ],
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Lista de transacciones con el estilo FlutterFlow
  // ---------------------------------------------------------------------------
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
    final recentTx = _transactions.reversed.take(10).toList();

    return SizedBox(
      height: 300, // Limit the height of the list
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: recentTx.length,
        itemBuilder: (context, index) {
          final tx = recentTx[index];

          Color iconColor;
          IconData iconData;

          if (tx.type == 'Gastos') {
            iconColor = Colors.red;
            iconData = Icons.money_off_rounded;
          } else if (tx.type == 'Ingresos') {
            iconColor = Colors.green;
            iconData = Icons.attach_money;
          } else {
            iconColor = Colors.blue;
            iconData = Icons.savings;
          }

          final dateStr = DateFormat('dd/MM/yyyy').format(tx.date);

          return Padding(
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
                      padding: const EdgeInsetsDirectional.fromSTEB(0, 5, 0, 5),
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
                      child: Text(
                        tx.displayAmount,
                        textAlign: TextAlign.center,
                        style: theme.typography.bodyMedium.override(
                          fontFamily: 'Montserrat',
                          color: iconColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VER MÁS -> mostrar todas las transacciones en un bottom sheet
  // ---------------------------------------------------------------------------
  void _showAllTransactions() {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No hay transacciones')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      builder: (context) {
        final theme = FlutterFlowTheme.of(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return Container(
              color: theme.primaryBackground,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Todas las transacciones',
                      style: FlutterFlowTheme.of(ctx).typography.titleMedium
                          .override(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    for (var tx in _transactions.reversed) ...[
                      _buildTransactionTile(tx),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

  // ---------------------------------------------------------------------------
  // BOTÓN + => Agregar Nueva Transacción (mismo formulario y lógica)
  // ---------------------------------------------------------------------------
  void _showAddTransactionSheet() {
    String transactionType = 'Gastos'; // 'Gastos', 'Ingresos', 'Ahorros'
    final categoryController = TextEditingController(text: 'Otros');
    DateTime selectedDate = DateTime.now();
    String selectedFrequency = 'Solo por hoy';

    final montoController = TextEditingController(text: '0');
    final formatter = NumberFormat('#,##0.##');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setBottomState) {
            final mq = MediaQuery.of(ctx);
            final height = mq.size.height * 0.65;

            return Container(
              height: height,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(ctx).primaryBackground,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTypeButton(
                            label: 'Gastos',
                            selected: transactionType == 'Gastos',
                            onTap:
                                () => setBottomState(
                                  () => transactionType = 'Gastos',
                                ),
                          ),
                          _buildTypeButton(
                            label: 'Ingresos',
                            selected: transactionType == 'Ingresos',
                            onTap:
                                () => setBottomState(
                                  () => transactionType = 'Ingresos',
                                ),
                          ),
                          _buildTypeButton(
                            label: 'Ahorros',
                            selected: transactionType == 'Ahorros',
                            onTap:
                                () => setBottomState(
                                  () => transactionType = 'Ahorros',
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Campo Monto
                      TextField(
                        controller: montoController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Monto',
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
                          String raw = val
                              .replaceAll(',', '')
                              .replaceAll('\$', '');
                          if (raw.contains('.')) {
                            final dotIndex = raw.indexOf('.');
                            final decimals = raw.length - dotIndex - 1;
                            if (decimals > 2) {
                              raw = raw.substring(0, dotIndex + 3);
                            }
                            if (raw == '.') {
                              raw = '0.';
                            }
                          }
                          double number = double.tryParse(raw) ?? 0.0;

                          if (raw.endsWith('.') ||
                              raw.matchesDecimalWithOneDigitEnd()) {
                            final parts = raw.split('.');
                            final intPart = double.tryParse(parts[0]) ?? 0.0;
                            final formattedInt =
                                formatter.format(intPart).split('.')[0];
                            final partialDecimal =
                                parts.length > 1 ? '.' + parts[1] : '';
                            final newString = '\$$formattedInt$partialDecimal';
                            montoController.value = TextEditingValue(
                              text: newString,
                              selection: TextSelection.collapsed(
                                offset: newString.length,
                              ),
                            );
                          } else {
                            final formatted = formatter.format(number);
                            final newString = '\$$formatted';
                            montoController.value = TextEditingValue(
                              text: newString,
                              selection: TextSelection.collapsed(
                                offset: newString.length,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Categoría
                      InkWell(
                        onTap: () async {
                          final chosenCat = await _showCategoryDialog(
                            transactionType,
                          );
                          if (chosenCat != null) {
                            setBottomState(() {
                              categoryController.text = chosenCat;
                            });
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
                              borderSide: const BorderSide(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Colors.grey, thickness: 1),
                      ),

                      // Fecha
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              text: 'Fecha: ',
                              style:
                                  FlutterFlowTheme.of(
                                    ctx,
                                  ).typography.bodyMedium,
                              children: [
                                TextSpan(
                                  text: DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(selectedDate),
                                  style: FlutterFlowTheme.of(
                                    ctx,
                                  ).typography.bodyMedium.override(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final picked = await _showDatePicker(
                                ctx,
                                selectedDate,
                              );
                              if (picked != null) {
                                setBottomState(() => selectedDate = picked);
                              }
                            },
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Colors.grey, thickness: 1),
                      ),

                      // Frecuencia
                      Row(
                        children: [
                          Text(
                            'Frecuencia: ',
                            style:
                                FlutterFlowTheme.of(ctx).typography.bodyMedium,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton2<String>(
                              value: selectedFrequency,
                              isExpanded: true,
                              items:
                                  [
                                    'Solo por hoy',
                                    'Todos los días',
                                    'Dias laborables',
                                    'Cada semana',
                                    'Cada 2 semanas',
                                    'Cada 3 semanas',
                                    'Cada 4 semanas',
                                    'Cada mes',
                                    'Cada 2 meses',
                                    'Cada 3 meses',
                                    'Cada 4 meses',
                                    'Cada primer dia del mes',
                                    'Cada ultimo día del mes',
                                    'Cada medio año',
                                    'Cada año',
                                  ].map((freq) {
                                    return DropdownMenuItem(
                                      value: freq,
                                      child: Text(freq),
                                    );
                                  }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setBottomState(() => selectedFrequency = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Botones
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            onPressed: () async {                 //  ←  async
                              final raw = montoController.text.replaceAll(',', '').replaceAll('\$', '');
                              final number = double.tryParse(raw) ?? 0.0;
                              final cat = categoryController.text.trim();

                              if (number > 0.0 && cat.isNotEmpty) {
                                if (transactionType == 'Ingresos') {
                                  setState(() => _incomeCardTotal += number);
                                }

                                setState(() {
                                  _transactions.add(
                                    TransactionData(
                                      idTransaction: null,
                                      type: transactionType,
                                      displayAmount: montoController.text,
                                      rawAmount: number,
                                      category: cat,
                                      date: selectedDate,
                                      frequency: selectedFrequency,
                                    ),
                                  );
                                });

                                try {
                                  await _saveData();              //  ←  ESPERAR
                                } catch (e, st) {
                                  debugPrint('⛔️ Error en _saveData(): $e');
                                  debugPrintStack(stackTrace: st);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error guardando: $e')),
                                    );
                                  }
                                  return;                         // no cierres el modal si falló
                                }
                              }
                              if (context.mounted) Navigator.of(ctx).pop();
                            },
                            child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      
    );

  }

  // ---------------------------------------------------------------------------
  // DIALOGO CATEGORÍAS
  // ---------------------------------------------------------------------------
  Future<String?> _showCategoryDialog(String type) async {
    final categories = await _getCategoriesForType(type);
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final theme = FlutterFlowTheme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.primaryBackground,
          title: Text(
            'Seleccionar Categoría',
            textAlign: TextAlign.center,
            style: theme.typography.titleSmall,
          ),
          content: SizedBox(
            width: 300,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 24,
              children:
                  categories.map((cat) {
                    return GestureDetector(
                      onTap:
                          () => Navigator.of(ctx).pop(cat['name'].toString()),
                      child: SizedBox(
                        width: 90,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.blue[50],
                              child: Icon(
                                cat['icon'] as IconData,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat['name'].toString(),
                              textAlign: TextAlign.center,
                              style: theme.typography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: theme.primary),
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  // 1️⃣  Utilidad: de tipo → id_movement
  int _movementIdForType(String type) {
    switch (type) {
      case 'Gastos'  : return 1;
      case 'Ingresos': return 2;
      case 'Ahorros' : return 3;
      default        : return 0;   // por si añades más tipos
    }
  }

  /// 2️⃣  Lee categorías + icon_code desde SQLite
  Future<List<Map<String, dynamic>>> _getCategoriesForType(String type) async {
    final db = SqliteManager.instance.db;
    final idMove = _movementIdForType(type);

    // si idMove==0 devolvemos TODAS (nunca debería ocurrir aquí, pero es útil)
    final rows = await db.rawQuery(
      idMove == 0
        ? 'SELECT name, icon_code FROM category_tb'
        : 'SELECT name, icon_code FROM category_tb WHERE id_movement = ?',
      idMove == 0 ? [] : [idMove],
    );

    // Convertimos icon_code → IconData
    return rows.map((r) => {
        'name': r['name'] as String,
        'icon': IconData(r['icon_code'] as int, fontFamily: 'MaterialIcons'),
      }).toList();
  }
}

// ---------------------------------------------------------------------------
// DatePicker con tema "azul"
// ---------------------------------------------------------------------------
Future<DateTime?> _showDatePicker(BuildContext ctx, DateTime initialDate) {
  final datePickerTheme = Theme.of(ctx).copyWith(
    colorScheme: const ColorScheme.light(
      primary: Colors.white,
      onPrimary: Colors.black,
      onSurface: Colors.black,
    ),
    dialogBackgroundColor: Colors.white,
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.blue),
    ),
  );
  return showDatePicker(
    context: ctx,
    initialDate: initialDate,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    helpText: '',
    cancelText: 'Cancel',
    confirmText: 'OK',
    builder: (context, child) {
      return Theme(data: datePickerTheme, child: child!);
    },
  );
}

// ---------------------------------------------------------------------------
// Botón para seleccionar "Gastos", "Ingresos" o "Ahorros"
// ---------------------------------------------------------------------------
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
            selected ? Colors.blue : const Color.fromARGB(255, 149, 149, 149),
        //border: Border.all(color: Colors.grey),
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

// ---------------------------------------------------------------------------
// Extensión para manejar decimales parciales (ej: 99.9, 0.5, etc.)
// ---------------------------------------------------------------------------
extension _StringDecimalExt on String {
  bool matchesDecimalWithOneDigitEnd() {
    final noCommas = replaceAll(',', '');
    return RegExp(r'^[0-9]*\.[0-9]$').hasMatch(noCommas);
  }
}


