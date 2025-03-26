import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Modelo para transacciones (type = 'Gasto', 'Ingreso', 'Ahorro')
// ---------------------------------------------------------------------------
class TransactionData {
  String type;           // 'Gasto', 'Ingreso', 'Ahorro'
  String displayAmount;  // Monto formateado
  double rawAmount;      // Monto numérico real
  String category;       // Categoría elegida
  DateTime date;         // Fecha
  String frequency;      // Frecuencia

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

// ---------------------------------------------------------------------------
// Modelo para cada ítem del presupuesto (se duplican aquí para cargar el income)
// ---------------------------------------------------------------------------
class ItemData {
  String name;
  double amount;
  IconData? iconData; // Se guarda el icono seleccionado

  ItemData({
    required this.name,
    this.amount = 0.0,
    this.iconData,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'iconData': iconData?.codePoint,
    };
  }

  factory ItemData.fromJson(Map<String, dynamic> json) {
    return ItemData(
      name: json['name'],
      amount: (json['amount'] as num).toDouble(),
      iconData: json['iconData'] != null
          ? IconData(json['iconData'], fontFamily: 'MaterialIcons')
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Modelo para la sección del presupuesto
// ---------------------------------------------------------------------------
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
    List<ItemData> items = itemsJson.map((item) => ItemData.fromJson(item)).toList();
    return SectionData(
      title: json['title'],
      items: items,
    );
  }
}

class StaticsHomeScreen extends StatefulWidget {
  const StaticsHomeScreen({Key? key}) : super(key: key);

  @override
  State<StaticsHomeScreen> createState() => _StaticsHomeScreenState();
}

class _StaticsHomeScreenState extends State<StaticsHomeScreen> {
  // Lista de transacciones guardadas
  final List<TransactionData> _transactions = [];

  // Valor base (total del card "Ingresos" obtenido del presupuesto)
  double _incomeCardTotal = 0.0;
  // Totales de transacciones de gasto y ahorro
  double _totalExpense = 0.0;
  double _totalSaving = 0.0;
  // Balance actual = _incomeCardTotal - (gastos + ahorros)
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData(); // Carga transacciones y el ingreso desde presupuesto
  }

  // Recalcula totales basados en las transacciones y el ingreso base
  void _recalculateTotals() {
    _totalExpense = 0;
    _totalSaving = 0;

    for (var tx in _transactions) {
      if (tx.type == 'Gasto') {
        _totalExpense += tx.rawAmount;
      } else if (tx.type == 'Ahorro') {
        _totalSaving += tx.rawAmount;
      }
      // Las transacciones de 'Ingreso' en este screen se usan solo para actualizar el registro de transacciones
    }
    _currentBalance = _incomeCardTotal - _totalExpense - _totalSaving;
  }

  // Guarda transacciones y _incomeCardTotal en SharedPreferences
  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> txJson =
        _transactions.map((tx) => tx.toJson()).toList();
    await prefs.setString('transactions', jsonEncode(txJson));
    await prefs.setDouble('income_card_total', _incomeCardTotal);
  }

  // Carga tanto las transacciones como el valor del card "Ingresos" desde SharedPreferences  
  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Cargar transacciones
    String? txData = prefs.getString('transactions');
    if (txData != null) {
      List<dynamic> jsonList = jsonDecode(txData);
      List<TransactionData> loadedTx = jsonList
          .map((jsonItem) => TransactionData.fromJson(jsonItem))
          .toList();
      setState(() {
        _transactions.clear();
        _transactions.addAll(loadedTx);
      });
    }

    // Cargar el presupuesto para obtener el total de "Ingresos"
    String? budgetData = prefs.getString('budget_data');
    if (budgetData != null) {
      List<dynamic> jsonData = jsonDecode(budgetData);
      List<SectionData> loadedSections = jsonData
          .map((sectionJson) => SectionData.fromJson(sectionJson))
          .toList();
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
      // Si no hay presupuesto, se deja en 0
      setState(() {
        _incomeCardTotal = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cada reconstrucción recalcula los totales
    _recalculateTotals();

    final localTheme = Theme.of(context).copyWith(
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color.fromARGB(255, 110, 170, 255),
        selectionColor: Color.fromARGB(128, 110, 170, 255),
        selectionHandleColor: Color.fromARGB(255, 90, 130, 200),
      ),
    );

    return Theme(
      data: localTheme,
      child: Scaffold(
        body: Container(
          color: Colors.grey[200],
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      // Sección: PieChart + leyenda (SIEMPRE se muestra la gráfica)
                      _buildBalanceAndLegendSection(),
                      const SizedBox(height: 32),
                      _buildRecentTransactionsTitle(),
                      const SizedBox(height: 16),
                      _buildTransactionsList(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: Colors.blue,
          onPressed: _showAddTransactionSheet,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sección que muestra PieChart y leyenda a la derecha
  // Ahora se muestra siempre la gráfica (si _incomeCardTotal es 0, se muestra una sección gris)
  // ---------------------------------------------------------------------------
  Widget _buildBalanceAndLegendSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // PieChart de 200x200
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: _buildPieChartSections(),
                  centerSpaceRadius: 60,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'BALANCE ACTUAL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${_currentBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _buildLegend(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Construye la leyenda del PieChart (si _incomeCardTotal es 0, se muestra la leyenda con 0%)
  // ---------------------------------------------------------------------------
  Widget _buildLegend() {
    double greenPercent = _incomeCardTotal == 0 ? 0 : (_currentBalance / _incomeCardTotal) * 100;
    double redPercent = _incomeCardTotal == 0 ? 0 : (_totalExpense / _incomeCardTotal) * 100;
    double bluePercent = _incomeCardTotal == 0 ? 0 : (_totalSaving / _incomeCardTotal) * 100;

    final legendData = <Map<String, dynamic>>[];

    if (redPercent > 0) {
      legendData.add({'type': 'Gasto', 'color': Colors.red, 'percent': redPercent});
    }
    if (bluePercent > 0) {
      legendData.add({'type': 'Ahorro', 'color': Colors.blue, 'percent': bluePercent});
    }
    // Siempre se muestra el restante (verde), incluso si es 0%
    legendData.add({'type': 'Ingreso', 'color': Colors.green, 'percent': greenPercent});

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: legendData.map((item) {
        final color = item['color'] as Color;
        final typeName = item['type'].toString();
        final percent = item['percent'] as double;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
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
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Construye las secciones del PieChart basándose en _incomeCardTotal.
  // Si es 0, se muestra una sección gris que ocupa el 100%.
  // ---------------------------------------------------------------------------
  List<PieChartSectionData> _buildPieChartSections() {
    if (_incomeCardTotal == 0) {
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
      sections.add(PieChartSectionData(
        color: Colors.red.withOpacity(0.7),
        value: redPercent,
        showTitle: false,
        radius: 25,
      ));
    }
    if (bluePercent > 0) {
      sections.add(PieChartSectionData(
        color: Colors.blue.withOpacity(0.7),
        value: bluePercent,
        showTitle: false,
        radius: 25,
      ));
    }
    if (greenPercent > 0) {
      sections.add(PieChartSectionData(
        color: Colors.green.withOpacity(0.7),
        value: greenPercent,
        showTitle: false,
        radius: 25,
      ));
    }
    return sections;
  }

  // ---------------------------------------------------------------------------
  // Título "Transacciones recientes" y botón "Ver más"
  // ---------------------------------------------------------------------------
  Widget _buildRecentTransactionsTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Transacciones recientes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        InkWell(
          onTap: _showAllTransactions,
          child: const Text(
            'Ver más',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blueAccent,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Lista de transacciones recientes (se muestra displayAmount tal cual)
  // ---------------------------------------------------------------------------
  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 180),
          child: Text(
            'Presiona el botón + para agregar transacciones!',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final recentTx = _transactions.take(20).toList();

    return Column(
      children: recentTx.map((tx) {
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
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    if (tx.frequency != 'Solo por hoy')
                      Text(
                        'Frecuencia: ${tx.frequency}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              Text(
                tx.displayAmount,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Muestra un bottom sheet con TODAS las transacciones
  // ---------------------------------------------------------------------------
  void _showAllTransactions() {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay transacciones')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Todas las transacciones',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    for (var tx in _transactions) ...[
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

  // ---------------------------------------------------------------------------
  // Tile para cada transacción en la vista "Ver más"
  // ---------------------------------------------------------------------------
  Widget _buildTransactionTile(TransactionData tx) {
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
        color: Colors.white,
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(dateStr, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                if (tx.frequency != 'Solo por hoy')
                  Text(
                    'Frecuencia: ${tx.frequency}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Text(
            tx.displayAmount,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Muestra la hoja para agregar una nueva transacción
  // Se maneja el formateo manual de montos y se actualiza SharedPreferences.
  // Si la transacción es de tipo "Ingreso" se suma al card "Ingresos".
  // ---------------------------------------------------------------------------
  void _showAddTransactionSheet() {
    String transactionType = 'Gasto'; // 'Gasto' | 'Ingreso' | 'Ahorro'
    final categoryController = TextEditingController(text: 'Otros');
    DateTime selectedDate = DateTime.now();
    String selectedFrequency = 'Solo por hoy';

    final TextEditingController montoController = TextEditingController(text: '0');
    final NumberFormat formatter = NumberFormat('#,##0.##');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setBottomState) {
          final mq = MediaQuery.of(ctx);
          final height = mq.size.height * 0.65;

          final localTheme = Theme.of(ctx).copyWith(
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Color.fromARGB(255, 110, 170, 255),
              selectionColor: Color.fromARGB(128, 110, 170, 255),
              selectionHandleColor: Color.fromARGB(255, 90, 130, 200),
            ),
          );

          return Theme(
            data: localTheme,
            child: Container(
              height: height,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
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
                      const Text(
                        'Transacción',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Botones para seleccionar tipo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTypeButton(
                            label: 'Gasto',
                            selected: transactionType == 'Gasto',
                            onTap: () => setBottomState(() => transactionType = 'Gasto'),
                          ),
                          _buildTypeButton(
                            label: 'Ingreso',
                            selected: transactionType == 'Ingreso',
                            onTap: () => setBottomState(() => transactionType = 'Ingreso'),
                          ),
                          _buildTypeButton(
                            label: 'Ahorro',
                            selected: transactionType == 'Ahorro',
                            onTap: () => setBottomState(() => transactionType = 'Ahorro'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Campo Monto
                      TextField(
                        controller: montoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.left,
                        decoration: InputDecoration(
                          labelText: 'Monto',
                          labelStyle: const TextStyle(color: Colors.black),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onChanged: (val) {
                          String raw = val.replaceAll(',', '').replaceAll('\$', '');
                          if (raw.contains('.')) {
                            final dotIndex = raw.indexOf('.');
                            final decimals = raw.length - dotIndex - 1;
                            if (decimals > 2) {
                              raw = raw.substring(0, dotIndex + 3);
                            }
                            if (raw == ".") {
                              raw = "0.";
                            }
                          }
                          double number = double.tryParse(raw) ?? 0.0;
                          if (raw.endsWith('.') || raw.matchesDecimalWithOneDigitEnd()) {
                            final parts = raw.split('.');
                            final intPart = double.tryParse(parts[0]) ?? 0.0;
                            final formattedInt = formatter.format(intPart).split('.')[0];
                            final partialDecimal = parts.length > 1 ? '.' + parts[1] : '';
                            final newString = '\$$formattedInt$partialDecimal';
                            montoController.value = TextEditingValue(
                              text: newString,
                              selection: TextSelection.collapsed(offset: newString.length),
                            );
                          } else {
                            final formatted = formatter.format(number);
                            final newString = '\$$formatted';
                            montoController.value = TextEditingValue(
                              text: newString,
                              selection: TextSelection.collapsed(offset: newString.length),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      // Categoría
                      InkWell(
                        onTap: () async {
                          final chosenCat = await _showCategoryDialog(transactionType);
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
                            labelStyle: const TextStyle(color: Colors.black),
                            disabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Fecha
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Fecha: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final picked = await _showBlueDatePicker(ctx, selectedDate);
                              if (picked != null) {
                                setBottomState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Frecuencia
                      Row(
                        children: [
                          const Text('Frecuencia: '),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String>(
                              dropdownColor: Colors.white,
                              value: selectedFrequency,
                              isExpanded: true,
                              items: [
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
                                  setBottomState(() {
                                    selectedFrequency = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Botones Cancelar y Aceptar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
                            onPressed: () {
                              final raw = montoController.text.replaceAll(',', '').replaceAll('\$', '');
                              final number = double.tryParse(raw) ?? 0.0;
                              final cat = categoryController.text.trim();

                              if (number > 0.0 && cat.isNotEmpty) {
                                final display = montoController.text;
                                // Si es de tipo "Ingreso", se actualiza el card de ingresos;
                                // de lo contrario, se agrega la transacción
                                if (transactionType == 'Ingreso') {
                                  setState(() {
                                    _incomeCardTotal += number;
                                  });
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
                            child: const Text("Aceptar", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Obtiene las categorías según el tipo (Gasto, Ingreso, Ahorro)
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Ventana emergente para elegir categoría según el tipo
  // ---------------------------------------------------------------------------
  Future<String?> _showCategoryDialog(String transactionType) async {
    final categories = _getCategoriesForType(transactionType);
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Seleccionar Categoría',
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: 300,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 24,
              children: categories.map((cat) {
                return GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(cat['name'].toString()),
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
                          style: const TextStyle(fontSize: 12),
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
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancelar'),
            )
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Muestra un DatePicker con tema personalizado
// ---------------------------------------------------------------------------
Future<DateTime?> _showBlueDatePicker(BuildContext ctx, DateTime initialDate) {
  final ThemeData datePickerTheme = Theme.of(ctx).copyWith(
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
// Botón para seleccionar el tipo (Gasto, Ingreso, Ahorro)
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
        color: selected ? Colors.blue : Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
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
// Extensión para validar un decimal parcial (ej: "99.9", "0.5", "123.4")
// ---------------------------------------------------------------------------
extension _StringDecimalExt on String {
  bool matchesDecimalWithOneDigitEnd() {
    final noCommas = replaceAll(',', '');
    return RegExp(r'^[0-9]*\.[0-9]$').hasMatch(noCommas);
  }
}
