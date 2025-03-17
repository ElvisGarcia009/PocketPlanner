import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Modelo simple para transacciones, con un "type" en lugar de isExpense
// type puede ser 'Gasto', 'Ingreso' o 'Ahorro'.
// ---------------------------------------------------------------------------
class TransactionData {
  String type;         // 'Gasto' | 'Ingreso' | 'Ahorro'
  double amount;
  String category;
  DateTime date;
  String frequency;

  TransactionData({
    required this.type,        
    required this.amount,
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
  // Lista de transacciones
  final List<TransactionData> _transactions = [];

  // Balance actual (suma de ingresos - gastos - ahorros)
  double _currentBalance = 0.0;

  // Totales para Ingreso, Gasto, Ahorro (para el chart)
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _totalSaving = 0.0;

  @override
  Widget build(BuildContext context) {
    // Recalcular pie chart y balance antes de dibujar
    _recalculateTotals();

    return Scaffold(
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

                    // Sección balance + leyenda
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
    );
  }

  // ---------------------------------------------------------------------------
  // Recalcula valores para el chart y el balance actual
  // ---------------------------------------------------------------------------
  void _recalculateTotals() {
    _totalIncome = 0;
    _totalExpense = 0;
    _totalSaving = 0;

    for (var tx in _transactions) {
      switch (tx.type) {
        case 'Ingreso':
          _totalIncome += tx.amount;
          break;
        case 'Gasto':
          _totalExpense += tx.amount;
          break;
        case 'Ahorro':
          _totalSaving += tx.amount;
          break;
      }
    }

    // Balance actual = Ingresos - Gastos - Ahorros
    _currentBalance = _totalIncome - _totalExpense - _totalSaving;
  }

  // ---------------------------------------------------------------------------
  // Sección que contiene el PieChart (a la izquierda) y la leyenda (a la derecha)
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
                    '${_currentBalance.toStringAsFixed(2)}\$',
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

        // Leyenda a la derecha
        _buildLegend(total),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Construye la leyenda del chart: circulo + nombre + porcentaje
  // ---------------------------------------------------------------------------
  Widget _buildLegend(double total) {
    if (total == 0) {
      // No hay transacciones => chart gris => sin leyenda
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

    final List<Map<String, dynamic>> legendData = [];

    // Calculamos % de cada tipo (si > 0)
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

    // Construimos la leyenda
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
              // Círculo de color
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Nombre + porcentaje
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
  // Construye la lista de secciones del PieChart
  // ---------------------------------------------------------------------------
  List<PieChartSectionData> _buildPieChartSections(double total) {
    if (total == 0) {
      // Gráfico gris completo
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

    // Gasto -> Rojo
    if (expPercent > 0) {
      sections.add(PieChartSectionData(
        color: Colors.red.withOpacity(0.7),
        value: expPercent,
        showTitle: false,
        radius: 25,
      ));
    }

    // Ahorro -> Azul
    if (savPercent > 0) {
      sections.add(PieChartSectionData(
        color: Colors.blue.withOpacity(0.7),
        value: savPercent,
        showTitle: false,
        radius: 25,
      ));
    }

    // Ingreso -> Verde
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
  // Lista de transacciones
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

    // Mostramos las últimas 20 transacciones
    final recentTx = _transactions.take(20).toList();

    return Column(
      children: recentTx.map((tx) {
        // Determina color de la transacción
        Color color;
        if (tx.type == 'Gasto') {
          color = Colors.red;
        } else if (tx.type == 'Ingreso') {
          color = Colors.green;
        } else {
          color = Colors.blue; // Ahorro
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
              // Título + fecha
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
              Text(
                '${tx.amount.toStringAsFixed(2)}\$',
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
  // Mostrar TODAS las transacciones
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

  Widget _buildTransactionTile(TransactionData tx) {
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
            '${tx.amount.toStringAsFixed(2)}\$',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Muestra la hoja de transacción (Gasto, Ingreso, Ahorro)
  // ---------------------------------------------------------------------------
  void _showAddTransactionSheet() {
    String transactionType = 'Gasto'; // 'Gasto' | 'Ingreso' | 'Ahorro'
    final montoController = TextEditingController();
    final categoryController = TextEditingController(text: 'Otros');
    DateTime selectedDate = DateTime.now();
    String selectedFrequency = 'Solo por hoy';

    final frequencies = [
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
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setBottomState) {
            final mediaQuery = MediaQuery.of(ctx);
            final height = mediaQuery.size.height * 0.65;

            return Container(
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
                  bottom: mediaQuery.viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const Text(
                        'Transacción',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Botones Gasto, Ingreso, Ahorro
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

                      // Monto
                      TextField(
                        controller: montoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Monto \$',
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
                              dropdownColor: Colors.white, // Fondo blanco
                              value: selectedFrequency,
                              isExpanded: true,
                              items: frequencies.map((freq) {
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

                      // Botones
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                            ),
                            onPressed: () {
                              final amount = double.tryParse(montoController.text.trim()) ?? 0.0;
                              final category = categoryController.text.trim();
                              if (amount > 0.0 && category.isNotEmpty) {
                                setState(() {
                                  _transactions.add(
                                    TransactionData(
                                      type: transactionType, 
                                      amount: amount,
                                      category: category,
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
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Función que retorna las categorías según el tipo de transacción
  // ---------------------------------------------------------------------------
  List<Map<String, dynamic>> _getCategoriesForType(String type) {
    if (type == 'Gasto') {
      // Categorías para Gasto
      return [
        {'name': 'Transporte', 'icon': Icons.directions_bus},
        {'name': 'Entretenimiento', 'icon': Icons.movie},
        {'name': 'Gastos Estudiantiles', 'icon': Icons.school},
        {'name': 'Préstamo', 'icon': Icons.account_balance},
        {'name': 'Comida', 'icon': Icons.fastfood},
        {'name': 'Trjta. crédito', 'icon': Icons.credit_card},
      ];
    } else if (type == 'Ingreso') {
      // Categorías para Ingreso
      return [
        {'name': 'Ingresos', 'icon': Icons.monetization_on},
        {'name': 'Salario', 'icon': Icons.payments},
        {'name': 'Inversión', 'icon': Icons.show_chart},
        {'name': 'Otros', 'icon': Icons.add_business},
      ];
    } else {
      // type == 'Ahorro'
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
  // Ventana emergente "centrada" para elegir categorías 
  // segun el "type" (Gasto, Ingreso, Ahorro)
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

  // ---------------------------------------------------------------------------
  // Muestra DatePicker con tema en que todo el texto sea negro
  // excepto los botones Cancel y OK en azul. Quita "Select date".
  // ---------------------------------------------------------------------------
  Future<DateTime?> _showBlueDatePicker(BuildContext ctx, DateTime initialDate) {
    final ThemeData datePickerTheme = Theme.of(ctx).copyWith(
      // Solo "Cancel" y "OK" en azul; el resto en negro
      colorScheme: const ColorScheme.light(
        primary: Colors.white,    // Encabezado blanco
        onPrimary: Colors.black,  // Texto en encabezado en negro
        onSurface: Colors.black,  // Texto de días en negro
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
}
