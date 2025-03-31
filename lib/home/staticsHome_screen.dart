import 'dart:convert';
//import 'package:auto_size_text/auto_size_text.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

// ---------------------------------------------------------------------------
// MODELOS (TransactionData, ItemData, SectionData)
// ---------------------------------------------------------------------------
class TransactionData {
  String type; // 'Gasto', 'Ingreso', 'Ahorro'
  String displayAmount; // Monto formateado
  double rawAmount; // Monto numérico real
  String category; // Categoría elegida
  DateTime date; // Fecha
  String frequency; // Frecuencia

  TransactionData({
    required this.type,
    required this.displayAmount,
    required this.rawAmount,
    required this.category,
    required this.date,
    required this.frequency,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'displayAmount': displayAmount,
      'rawAmount': rawAmount,
      'category': category,
      'date': date.toIso8601String(),
      'frequency': frequency,
    };
  }

  factory TransactionData.fromJson(Map<String, dynamic> json) {
    return TransactionData(
      type: json['type'],
      displayAmount: json['displayAmount'],
      rawAmount: (json['rawAmount'] as num).toDouble(),
      category: json['category'],
      date: DateTime.parse(json['date']),
      frequency: json['frequency'],
    );
  }
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
  // Totales de transacciones Gasto y Ahorro
  double _totalExpense = 0.0;
  double _totalSaving = 0.0;
  // Balance actual = ingresos - (gastos + ahorros)
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData(); // Cargar transacciones y presupuesto
  }

  // Recalcula los totales
  void _recalculateTotals() {
    _totalExpense = 0;
    _totalSaving = 0;

    for (var tx in _transactions) {
      if (tx.type == 'Gasto') {
        _totalExpense += tx.rawAmount;
      } else if (tx.type == 'Ahorro') {
        _totalSaving += tx.rawAmount;
      }
    }
    _currentBalance = _incomeCardTotal - _totalExpense - _totalSaving;
  }

  // Guardar datos en SharedPreferences
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    var txJson = _transactions.map((tx) => tx.toJson()).toList();
    await prefs.setString('transactions', jsonEncode(txJson));
    await prefs.setDouble('income_card_total', _incomeCardTotal);
  }

  // Cargar transacciones y "Ingresos" del presupuesto
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Cargar transacciones
    String? txData = prefs.getString('transactions');
    if (txData != null) {
      List<dynamic> jsonList = jsonDecode(txData);
      List<TransactionData> loadedTx =
          jsonList.map((item) => TransactionData.fromJson(item)).toList();
      setState(() {
        _transactions.clear();
        _transactions.addAll(loadedTx);
      });
    }

    // Cargar presupuesto para encontrar "Ingresos"
    String? budgetData = prefs.getString('budget_data');
    if (budgetData != null) {
      List<dynamic> jsonData = jsonDecode(budgetData);
      List<SectionData> loadedSections =
          jsonData.map((sec) => SectionData.fromJson(sec)).toList();

      double incomeSum = 0.0;
      for (var section in loadedSections) {
        if (section.title == 'Ingresos') {
          for (var item in section.items) {
            incomeSum += item.amount;
          }
        }
      }
      setState(() {
        _incomeCardTotal = incomeSum;
      });
    } else {
      setState(() {
        _incomeCardTotal = 0.0;
      });
    }
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
                                      getTitlesWidget: (value, meta) {
                                        return _buildBarLabelWithValue(
                                          value.toInt(),
                                        );
                                      },
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
                        // Add your AI extraction logic here
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        ),
                        fixedSize: const Size(
                        120,
                        140,
                        ), // Customize width and height
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        const Icon(Icons.assistant, color: Colors.white, size: 30,),
                        const SizedBox(
                          height: 8,
                        ), // Add spacing between icon and text
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

  Widget _buildBarLabelWithValue(int index) {
    double totalGasto = 0.0;
    double totalAhorro = 0.0;
    double totalIngreso = 0.0;

    for (var tx in _transactions) {
      switch (tx.type) {
        case 'Gasto':
          totalGasto += tx.rawAmount;
          break;
        case 'Ahorro':
          totalAhorro += tx.rawAmount;
          break;
        case 'Ingreso':
          totalIngreso += tx.rawAmount;
          break;
      }
    }

    String amount = '';

    final formatter = NumberFormat('#,##0.##');
    switch (index) {
      case 0:
      amount = '\$${formatter.format(totalGasto)}';
      break;
      case 1:
      amount = '\$${formatter.format(totalAhorro)}';
      break;
      case 2:
      amount = '\$${formatter.format(totalIngreso)}';
      break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          amount,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Construye las secciones del PieChart basadas en los montos
  // ---------------------------------------------------------------------------
  List<PieChartSectionData> _buildPieChartSections() {
    if (_incomeCardTotal == 0 && _totalExpense == 0 && _totalSaving == 0) {
      // Si no hay ingresos, pinta todo de gris
      return [
        PieChartSectionData(
          color: Colors.grey,
          value: 100,
          showTitle: false,
          radius: 25,
        ),
      ];
    }

    double greenPercent = (_currentBalance / _incomeCardTotal) * 100;
    double redPercent = (_totalExpense / _incomeCardTotal) * 100;
    double bluePercent = (_totalSaving / _incomeCardTotal) * 100;

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
    double greenPercent =
        _incomeCardTotal == 0 ? 0 : (_currentBalance / _incomeCardTotal) * 100;
    double redPercent =
        _incomeCardTotal == 0 ? 0 : (_totalExpense / _incomeCardTotal) * 100;
    double bluePercent =
        _incomeCardTotal == 0 ? 0 : (_totalSaving / _incomeCardTotal) * 100;

    final legendData = <Map<String, dynamic>>[];

    if (redPercent > 0) {
      legendData.add({
        'type': 'Gasto',
        'color': Colors.red,
        'percent': redPercent,
      });
    }
    if (bluePercent > 0) {
      legendData.add({
        'type': 'Ahorro',
        'color': Colors.blue,
        'percent': bluePercent,
      });
    }

    if (_incomeCardTotal != 0) {
      legendData.add({
      'type': 'Ingreso',
      'color': Colors.green,
      'percent': greenPercent,
      });
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          legendData.map((item) {
            final color = item['color'] as Color;
            final typeName = item['type'].toString();
            final percent = item['percent'] as double;

            return Container(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 50, 0),
              margin: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$typeName (${percent.toStringAsFixed(1)}%)',
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
  // Construye los grupos del gráfico de barras (Gasto, Ahorro, Ingreso)
  // ---------------------------------------------------------------------------
  List<BarChartGroupData> _buildBarChartGroups() {
    double totalGasto = 0.0;
    double totalAhorro = 0.0;
    double totalIngreso = 0.0;

    
    for (var tx in _transactions) {
    switch (tx.type) {
      case 'Gasto':
        totalGasto += tx.rawAmount;
        break;
      case 'Ahorro':
        totalAhorro += tx.rawAmount;
        break;
      case 'Ingreso':
        totalIngreso += tx.rawAmount;
        break;
      }
    }

    if ( totalIngreso <= 0 && totalGasto <= 0 && totalAhorro <= 0)
    {
      totalIngreso = 2000;
      totalAhorro = 1300;
      totalGasto = 1100;
    }
    

    return [
      BarChartGroupData(
        x: 0,
        barRods: [
          BarChartRodData(
            toY: totalGasto,
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
            toY: totalAhorro,
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
            toY: totalIngreso,
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

          if (tx.type == 'Gasto') {
            iconColor = Colors.red;
            iconData = Icons.money_off_rounded;
          } else if (tx.type == 'Ingreso') {
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
    if (tx.type == 'Gasto') {
      color = Colors.red;
    } else if (tx.type == 'Ingreso') {
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
    String transactionType = 'Gasto'; // 'Gasto', 'Ingreso', 'Ahorro'
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
                            label: 'Gasto',
                            selected: transactionType == 'Gasto',
                            onTap:
                                () => setBottomState(
                                  () => transactionType = 'Gasto',
                                ),
                          ),
                          _buildTypeButton(
                            label: 'Ingreso',
                            selected: transactionType == 'Ingreso',
                            onTap:
                                () => setBottomState(
                                  () => transactionType = 'Ingreso',
                                ),
                          ),
                          _buildTypeButton(
                            label: 'Ahorro',
                            selected: transactionType == 'Ahorro',
                            onTap:
                                () => setBottomState(
                                  () => transactionType = 'Ahorro',
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                            onPressed: () {
                              final raw = montoController.text
                                  .replaceAll(',', '')
                                  .replaceAll('\$', '');
                              final number = double.tryParse(raw) ?? 0.0;
                              final cat = categoryController.text.trim();
                              if (number > 0.0 && cat.isNotEmpty) {
                                final display = montoController.text;
                                // Si es Ingreso, se suma a _incomeCardTotal
                                if (transactionType == 'Ingreso') {
                                  setState(() => _incomeCardTotal += number);
                                }
                                setState(() {
                                  _transactions.add(
                                    TransactionData(
                                      type: transactionType,
                                      displayAmount: display,
                                      rawAmount: number,
                                      category: cat,
                                      date: selectedDate,
                                      frequency: selectedFrequency,
                                    ),
                                  );
                                });
                                _saveData();
                              }
                              Navigator.of(ctx).pop();
                            },
                            child: const Text(
                              'Aceptar',
                              style: TextStyle(color: Colors.white),
                            ),
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
    final categories = _getCategoriesForType(type);
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

  // Retorna las categorías según el tipo
  List<Map<String, dynamic>> _getCategoriesForType(String type) {
    if (type == 'Gasto') {
      return [
        {'name': 'Transporte', 'icon': Icons.directions_bus},
        {'name': 'Entretenimiento', 'icon': Icons.movie},
        {'name': 'Gastos Estudiantiles', 'icon': Icons.school},
        {'name': 'Préstamo', 'icon': Icons.account_balance},
        {'name': 'Comida', 'icon': Icons.fastfood},
        {'name': 'Trjta. crédito', 'icon': Icons.credit_card},
      ];
    } else if (type == 'Ingreso') {
      return [
        {'name': 'Ingresos', 'icon': Icons.monetization_on},
        {'name': 'Salario', 'icon': Icons.payments},
        {'name': 'Inversión', 'icon': Icons.show_chart},
        {'name': 'Otros', 'icon': Icons.add_business},
      ];
    } else {
      // Ahorro
      return [
        {'name': 'Ahorros de emergencia', 'icon': Icons.security},
        {'name': 'Ahorros', 'icon': Icons.savings},
        {'name': 'Vacaciones', 'icon': Icons.card_travel},
        {'name': 'Proyecto', 'icon': Icons.build},
        {'name': 'Otros', 'icon': Icons.add},
      ];
    }
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
// Botón para seleccionar "Gasto", "Ingreso" o "Ahorro"
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
