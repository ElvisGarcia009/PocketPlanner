import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Modelo para transacciones (type = 'Gasto', 'Ingreso', 'Ahorro')
// Guardamos:
//
//  - displayAmount: el monto con formato y comas tal como lo ingresó el usuario (p. ej. "$1,234.5")
//  - rawAmount: valor numérico real (p. ej. 1234.5)
// ---------------------------------------------------------------------------
class TransactionData {
  String type;           // 'Gasto', 'Ingreso', 'Ahorro'
  String displayAmount;  // Monto "visualmente formateado"
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
}

class StaticsHomeScreen extends StatefulWidget {
  const StaticsHomeScreen({Key? key}) : super(key: key);

  @override
  State<StaticsHomeScreen> createState() => _StaticsHomeScreenState();
}

class _StaticsHomeScreenState extends State<StaticsHomeScreen> {
  // Lista de transacciones y balance
  final List<TransactionData> _transactions = [];
  double _currentBalance = 0.0;

  // Totales para el Pie Chart
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _totalSaving = 0.0;

  @override
  Widget build(BuildContext context) {
    // Recalcular montos cada vez que se reconstruye el widget
    _recalculateTotals();

    // Tema local para el cursor / selección en azul tenue
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

                      // Sección: PieChart + leyenda
                      _buildBalanceAndLegendSection(),
                      const SizedBox(height: 32),

                      // Título "Transacciones recientes" + "Ver más"
                      _buildRecentTransactionsTitle(),
                      const SizedBox(height: 16),

                      // Lista transacciones
                      _buildTransactionsList(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Botón flotante para agregar una transacción
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
  // Recalcula totales de Ingreso, Gasto, Ahorro y el balance actual
  // ---------------------------------------------------------------------------
  void _recalculateTotals() {
    _totalIncome = 0;
    _totalExpense = 0;
    _totalSaving = 0;

    for (var tx in _transactions) {
      switch (tx.type) {
        case 'Ingreso':
          _totalIncome += tx.rawAmount;
          break;
        case 'Gasto':
          _totalExpense += tx.rawAmount;
          break;
        case 'Ahorro':
          _totalSaving += tx.rawAmount;
          break;
      }
    }
    // Balance = Ingresos - Gastos - Ahorros
    _currentBalance = _totalIncome - _totalExpense - _totalSaving;
  }

  // ---------------------------------------------------------------------------
  // Sección con PieChart y leyenda a la derecha
  // ---------------------------------------------------------------------------
  Widget _buildBalanceAndLegendSection() {
    final total = _totalIncome + _totalExpense + _totalSaving;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Gráfico
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: _buildPieChartSections(total),
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

        // Leyenda
        _buildLegend(total),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Construye la leyenda del PieChart
  // ---------------------------------------------------------------------------
  Widget _buildLegend(double total) {
    if (total == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'Sin transacciones',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }

    final legendData = <Map<String, dynamic>>[];

    if (_totalExpense > 0) {
      final p = (_totalExpense / total) * 100;
      legendData.add({'type': 'Gasto', 'color': Colors.red, 'percent': p});
    }
    if (_totalSaving > 0) {
      final p = (_totalSaving / total) * 100;
      legendData.add({'type': 'Ahorro', 'color': Colors.blue, 'percent': p});
    }
    if (_totalIncome > 0) {
      final p = (_totalIncome / total) * 100;
      legendData.add({'type': 'Ingreso', 'color': Colors.green, 'percent': p});
    }

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
  // Construye las secciones del PieChart
  // ---------------------------------------------------------------------------
  List<PieChartSectionData> _buildPieChartSections(double total) {
    if (total == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey,
          value: 100,
          showTitle: false,
          radius: 25,
        ),
      ];
    }

    final incPercent = _totalIncome / total * 100;
    final expPercent = _totalExpense / total * 100;
    final savPercent = _totalSaving / total * 100;

    final sections = <PieChartSectionData>[];

    if (expPercent > 0) {
      sections.add(PieChartSectionData(
        color: Colors.red.withOpacity(0.7),
        value: expPercent,
        showTitle: false,
        radius: 25,
      ));
    }
    if (savPercent > 0) {
      sections.add(PieChartSectionData(
        color: Colors.blue.withOpacity(0.7),
        value: savPercent,
        showTitle: false,
        radius: 25,
      ));
    }
    if (incPercent > 0) {
      sections.add(PieChartSectionData(
        color: Colors.green.withOpacity(0.7),
        value: incPercent,
        showTitle: false,
        radius: 25,
      ));
    }
    return sections;
  }

  // ---------------------------------------------------------------------------
  // "Transacciones recientes" + botón "Ver más"
  // ---------------------------------------------------------------------------
  Widget _buildRecentTransactionsTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Transacciones recientes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
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
  // Lista transacciones recientes (mostramos "displayAmount" en vez de parsear)
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
        // Determina color
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
              // Cuadro de color
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),

              // Categoría + fecha
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    if (tx.frequency != 'Solo por hoy')
                      Text(
                        'Frecuencia: ${tx.frequency}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),

              // Monto (lo mostramos tal cual el usuario lo ingresó en "displayAmount")
              Text(
                tx.displayAmount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Mostramos TODAS las transacciones en un bottom sheet
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
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
  // Tile para cada transacción al mostrar "todas"
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
          // Monto "displayAmount"
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
  // con manejo de separador de miles, 2 decimales, etc. en el campo "Monto"
  // ---------------------------------------------------------------------------
  void _showAddTransactionSheet() {
    String transactionType = 'Gasto'; // 'Gasto' | 'Ingreso' | 'Ahorro'
    final categoryController = TextEditingController(text: 'Otros');
    DateTime selectedDate = DateTime.now();
    String selectedFrequency = 'Solo por hoy';

    // Controlador para "monto" con el approach de formateo manual
    final TextEditingController montoController = TextEditingController(text: '0');
    final NumberFormat formatter = NumberFormat('#,##0.##');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setBottomState) {
            final mq = MediaQuery.of(ctx);
            final height = mq.size.height * 0.65;

            // Tema local
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
                  borderRadius: BorderRadius.only(
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
                        const Text(
                          'Transacción',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // Botones Gasto/Ingreso/Ahorro
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
                            //prefixText: "\$", // Un único "$" fijo
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
                            // 1) Quitar comas y $
                            String raw = val.replaceAll(',', '').replaceAll('\$', '');
                            // 2) limitar 2 decimales
                            if (raw.contains('.')) {
                              final dotIndex = raw.indexOf('.');
                              final decimals = raw.length - dotIndex - 1;
                              if (decimals > 2) {
                                raw = raw.substring(0, dotIndex + 3);
                              }
                              // si usuario deja solo "."
                              if (raw == ".") {
                                raw = "0.";
                              }
                            }
                            double number = double.tryParse(raw) ?? 0.0;

                            // 3) Manejo parcial si termina en "." o ".<1digit>"
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
                              // Caso normal
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

                        // Botones Finales
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
                                // parse amount
                                final raw = montoController.text
                                    .replaceAll(',', '')
                                    .replaceAll('\$', '');
                                final number = double.tryParse(raw) ?? 0.0;
                                final cat = categoryController.text.trim();

                                if (number > 0.0 && cat.isNotEmpty) {
                                  // Creamos displayAmount con el texto actual
                                  final display = montoController.text;

                                  setState(() {
                                    _transactions.add(
                                      TransactionData(
                                        type: transactionType,
                                        displayAmount: display, // p.e. "$1,234.5"
                                        rawAmount: number,
                                        category: cat,
                                        date: selectedDate,
                                        frequency: selectedFrequency,
                                      ),
                                    );
                                  });
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
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Función para obtener las categorías según el tipo (Gasto, Ingreso, Ahorro)
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
      // 'Ahorro'
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
  // Ventana emergente para elegir categoría según el type
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
// Muestra DatePicker con tema en que todo el texto sea negro
// excepto los botones Cancel y OK en azul. Quita "Select date".
// ---------------------------------------------------------------------------
Future<DateTime?> _showBlueDatePicker(BuildContext ctx, DateTime initialDate) {
  final ThemeData datePickerTheme = Theme.of(ctx).copyWith(
    // Solo "Cancel" y "OK" en azul; el resto en negro
    colorScheme: const ColorScheme.light(
      primary: Colors.white,   // Encabezado blanco
      onPrimary: Colors.black, // Texto encabezado en negro
      onSurface: Colors.black, // Texto de días en negro
    ),
    dialogBackgroundColor: Colors.white,
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue, // Botones "Cancel" y "OK" en azul
      ),
    ),
  );

  return showDatePicker(
    context: ctx,
    initialDate: initialDate,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    helpText: '',        // Quita "Select date"
    cancelText: 'Cancel',
    confirmText: 'OK',
    builder: (context, child) {
      return Theme(data: datePickerTheme, child: child!);
    },
  );
}

// ---------------------------------------------------------------------------
// Botón tipo "Gasto | Ingreso | Ahorro"
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
// Extensión para verificar si el string termina con un decimal parcial .x
// ---------------------------------------------------------------------------
extension _StringDecimalExt on String {
  bool matchesDecimalWithOneDigitEnd() {
    // ejemplo: "99.9", "0.5", "123.4"
    final noCommas = replaceAll(',', '');
    return RegExp(r'^[0-9]*\.[0-9]$').hasMatch(noCommas);
  }
}
