import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart'; // Para formatear con comas y decimales

/// Modelo para cada ítem dentro de la sección
class ItemData {
  String name;
  double amount;
  IconData? iconData; // Almacena el icono seleccionado

  ItemData({
    required this.name,
    this.amount = 0.0,
    this.iconData,
  });
}

/// Modelo para cada sección (Ingresos, Ahorros, Gastos, o personalizada)
class SectionData {
  String title;
  bool isEditingTitle;
  List<ItemData> items;

  SectionData({
    required this.title,
    this.isEditingTitle = false,
    required this.items,
  });
}

class BudgetHomeScreen extends StatefulWidget {
  const BudgetHomeScreen({Key? key}) : super(key: key);

  @override
  State<BudgetHomeScreen> createState() => _BudgetHomeScreenState();
}

class _BudgetHomeScreenState extends State<BudgetHomeScreen> {
  // Secciones por defecto
  final List<SectionData> _sections = [
    SectionData(
      title: 'Ingresos',
      items: [ItemData(name: 'Salario', amount: 0.0, iconData: Icons.payments)],
    ),
    SectionData(
      title: 'Ahorros',
      items: [ItemData(name: 'Ahorros', amount: 0.0, iconData: Icons.savings)],
    ),
    SectionData(
      title: 'Gastos',
      items: [ItemData(name: 'Transporte', amount: 0.0, iconData: Icons.directions_bus)],
    ),
  ];

  // Para detectar taps fuera de los TextFields
  final GlobalKey _globalKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleGlobalTap,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        body: Column(
          children: [
            // Sección superior azul
            _buildTopSection(),

            // Sección inferior
            Expanded(
              child: Container(
                key: _globalKey,
                color: Colors.grey[200],
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _sections.length; i++) ...[
                        _buildSectionCard(i),
                        const SizedBox(height: 16),
                      ],
                      _buildCreateNewSectionButton(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cierra edición de títulos si hace tap fuera
  // ---------------------------------------------------------------------------
  void _handleGlobalTap() {
    bool changed = false;
    for (var section in _sections) {
      if (section.isEditingTitle) {
        section.isEditingTitle = false;
        changed = true;
      }
    }
    if (changed) setState(() {});
    FocusScope.of(context).unfocus();
  }

  // ---------------------------------------------------------------------------
  // Sección superior azul (Botón config + nombre de presupuesto)
  // ---------------------------------------------------------------------------
  Widget _buildTopSection() {
    return Container(
      color: Colors.blue[700],
      padding: const EdgeInsets.only(top: 30, bottom: 16, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              // Lógica de configuración
            },
          ),

          InkWell(
            onTap: () {},
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Mi Presupuesto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
          ),

          const SizedBox(width: 32),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card de cada sección
  // ---------------------------------------------------------------------------
  Widget _buildSectionCard(int sectionIndex) {
    final section = _sections[sectionIndex];
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSectionTitle(sectionIndex),
            const SizedBox(height: 12),
            const Divider(color: Colors.grey, thickness: 1),
            const SizedBox(height: 12),

            for (int i = 0; i < section.items.length; i++) ...[
              _buildItem(sectionIndex, i),
              if (i < section.items.length - 1) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.grey, thickness: 1),
                const SizedBox(height: 12),
              ],
            ],

            const SizedBox(height: 12),
            const Divider(color: Colors.grey, thickness: 1),
            const SizedBox(height: 12),

            // Botón para agregar ítem
            InkWell(
              onTap: () => _showAddItemDialog(sectionIndex),
              child: Row(
                children: const [
                  Icon(Icons.add, size: 20, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Text(
                    'Agregar',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Título editable
  // ---------------------------------------------------------------------------
  Widget _buildSectionTitle(int sectionIndex) {
    final section = _sections[sectionIndex];

    if (!section.isEditingTitle) {
      return GestureDetector(
        onTap: () {
          setState(() => section.isEditingTitle = true);
        },
        child: Center(
          child: Text(
            section.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else {
      return _EditableTitle(
        initialText: section.title,
        onSubmitted: (newValue) {
          setState(() {
            section.title = newValue;
            section.isEditingTitle = false;
          });
        },
        onCancel: () {
          setState(() => section.isEditingTitle = false);
        },
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Ítem con slide para borrar y AmountEditor (con ancho adaptativo máx 120)
  // ---------------------------------------------------------------------------
  Widget _buildItem(int sectionIndex, int itemIndex) {
    final item = _sections[sectionIndex].items[itemIndex];

    return Slidable(
      key: ValueKey('${sectionIndex}_$itemIndex'),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) => _confirmDeleteItem(sectionIndex, itemIndex),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícono de la categoría
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.iconData ?? Icons.category,
              color: Colors.blueAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Nombre
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Monto con ancho adaptativo hasta 120
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Flexible(
              child: IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: AmountEditor(
                    initialValue: item.amount,
                    onValueChanged: (newVal) {
                      setState(() {
                        item.amount = newVal;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Diálogo para agregar ítem
  // ---------------------------------------------------------------------------
  void _showAddItemDialog(int sectionIndex) {
    final nameController = TextEditingController();
    // Dejamos "0" en vez de "$0", ya que la UI ya presenta un "$" en prefixText
    final amountController = TextEditingController(text: "0");
    IconData? pickedIcon;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[100],
          title: const Text("Agregar ítem"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final result = await _showCategoryDialog(_sections[sectionIndex].title);
                  if (result != null) {
                    nameController.text = result['name'];
                    pickedIcon = result['icon'] as IconData?;
                  }
                },
                child: _CategoryTextField(
                  controller: nameController,
                  hint: "Categoría",
                ),
              ),
              const SizedBox(height: 12),

              // Monto
              _BlueTextField(
                controller: amountController,
                labelText: "Monto",
                // Retiramos el prefijo "$ " porque el usuario no quiere duplicar el símbolo
                // Sin embargo, si deseas dejarlo visual, ponlo así: prefixText: "$ " 
                prefixText: "", 
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
              onPressed: () {
                final name = nameController.text.trim();
                final raw = amountController.text.replaceAll(',', '').replaceAll('\$', '');
                final amount = double.tryParse(raw) ?? 0.0;

                if (name.isNotEmpty) {
                  setState(() {
                    _sections[sectionIndex].items.add(
                      ItemData(
                        name: name,
                        amount: amount,
                        iconData: pickedIcon,
                      ),
                    );
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text("Aceptar", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Diálogo confirmación borrar
  // ---------------------------------------------------------------------------
  void _confirmDeleteItem(int sectionIndex, int itemIndex) async {
    final item = _sections[sectionIndex].items[itemIndex];
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('¿Estás seguro que quieres borrar la categoría "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, borrar'),
          ),
        ],
      ),
    );
    if (result == true) {
      setState(() {
        _sections[sectionIndex].items.removeAt(itemIndex);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Botón para crear una nueva sección
  // ---------------------------------------------------------------------------
  Widget _buildCreateNewSectionButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _sections.add(
              SectionData(
                title: 'Nueva Sección',
                items: [ItemData(name: 'Categoría', amount: 0.0)],
              ),
            );
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Crear una nueva sección',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AlertDialog con categorías => { 'name', 'icon' } o null
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _showCategoryDialog(String sectionTitle) async {
    final categories = _getCategoriesForSection(sectionTitle);

    return showDialog<Map<String, dynamic>>(
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
                  onTap: () => Navigator.of(ctx).pop(cat),
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
  // Retorna las categorías según la sección
  // ---------------------------------------------------------------------------
  List<Map<String, dynamic>> _getCategoriesForSection(String sectionTitle) {
    if (sectionTitle == 'Ingresos') {
      return [
        {'name': 'Ingresos', 'icon': Icons.monetization_on},
        {'name': 'Salario', 'icon': Icons.payments},
        {'name': 'Inversión', 'icon': Icons.show_chart},
        {'name': 'Otros', 'icon': Icons.add},
      ];
    } else if (sectionTitle == 'Ahorros') {
      return [
        {'name': 'Ahorros de emergencia', 'icon': Icons.security},
        {'name': 'Ahorros', 'icon': Icons.savings},
        {'name': 'Vacaciones', 'icon': Icons.card_travel},
        {'name': 'Proyecto', 'icon': Icons.build},
        {'name': 'Otros', 'icon': Icons.add},
      ];
    } else if (sectionTitle == 'Gastos') {
      return [
        {'name': 'Transporte', 'icon': Icons.directions_bus},
        {'name': 'Entretenimiento', 'icon': Icons.movie},
        {'name': 'Gastos Estudiantiles', 'icon': Icons.school},
        {'name': 'Préstamo', 'icon': Icons.account_balance},
        {'name': 'Comida', 'icon': Icons.fastfood},
        {'name': 'Trjta. crédito', 'icon': Icons.credit_card},
      ];
    } else {
      // Sección personalizada => todas
      return [
        // Ingresos
        {'name': 'Ingresos', 'icon': Icons.monetization_on},
        {'name': 'Salario', 'icon': Icons.payments},
        {'name': 'Inversión', 'icon': Icons.show_chart},
        // Ahorros
        {'name': 'Ahorros de emergencia', 'icon': Icons.security},
        {'name': 'Ahorros', 'icon': Icons.savings},
        {'name': 'Vacaciones', 'icon': Icons.card_travel},
        {'name': 'Proyecto', 'icon': Icons.build},
        // Gastos
        {'name': 'Transporte', 'icon': Icons.directions_bus},
        {'name': 'Entretenimiento', 'icon': Icons.movie},
        {'name': 'Gastos Estudiantiles', 'icon': Icons.school},
        {'name': 'Préstamo', 'icon': Icons.account_balance},
        {'name': 'Comida', 'icon': Icons.fastfood},
        {'name': 'Trjta. crédito', 'icon': Icons.credit_card},
        // Extra "Otros"
        {'name': 'Otros', 'icon': Icons.add},
      ];
    }
  }
}

// ---------------------------------------------------------------------------
// Editor de Monto (AmountEditor): Permite . manual, 2 decimales, comas, y "$".
// (Se mantiene para los ítems existentes)
// ---------------------------------------------------------------------------
class AmountEditor extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onValueChanged;

  const AmountEditor({
    super.key,
    required this.initialValue,
    required this.onValueChanged,
  });

  @override
  State<AmountEditor> createState() => _AmountEditorState();
}

class _AmountEditorState extends State<AmountEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  final NumberFormat _formatter = NumberFormat('#,##0.##');
  double _currentValue = 0.0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _focusNode = FocusNode();

    // Si es 0 => "$0", si no => "$ + formateo"
    if (_currentValue == 0.0) {
      _controller = TextEditingController(text: "\$0");
    } else {
      final formatted = _formatter.format(_currentValue);
      _controller = TextEditingController(text: "\$$formatted");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Formatea un double a string con comas y sin .00 auto
  String _formatNumber(double value) {
    return _formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final localTheme = Theme.of(context).copyWith(
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color.fromARGB(255, 110, 170, 255),
        selectionColor: Color.fromARGB(128, 110, 170, 255),
        selectionHandleColor: Color.fromARGB(255, 90, 130, 200),
      ),
    );

    return Theme(
      data: localTheme,
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 213, 213, 213),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: TextField(
          focusNode: _focusNode,
          controller: _controller,
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
          ),
          onTap: () {
            // Seleccionar todo el texto al hacer tap
            _controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controller.text.length,
            );
          },
          onChanged: (val) {
            // Quitamos "$" y comas
            String raw = val.replaceAll('\$', '').replaceAll(',', '');
            // Manejo de decimales
            if (raw.contains('.')) {
              final dotIndex = raw.indexOf('.');
              final decimals = raw.length - dotIndex - 1;
              // Si excede 2 decimales, cortamos
              if (decimals > 2) {
                raw = raw.substring(0, dotIndex + 3);
              }
              // Si usuario deja solo ".", convertimos a "0."
              if (raw == ".") {
                raw = "0.";
              }
            }

            double number = double.tryParse(raw) ?? 0.0;
            setState(() => _currentValue = number);

            // Lógica parcial si termina en "." o ".<1digit>"
            if (raw.endsWith('.') || raw.matchesDecimalWithOneDigitEnd()) {
              final parts = raw.split('.');
              final intPart = double.tryParse(parts[0]) ?? 0.0;
              final formattedInt = _formatter.format(intPart).split('.')[0];
              final partialDecimal = parts.length > 1 ? '.' + parts[1] : '';
              final newString = '\$$formattedInt$partialDecimal';
              _controller.value = TextEditingValue(
                text: newString,
                selection: TextSelection.collapsed(offset: newString.length),
              );
            } else {
              // normal
              final formatted = _formatNumber(_currentValue);
              final newString = '\$$formatted';
              _controller.value = TextEditingValue(
                text: newString,
                selection: TextSelection.collapsed(offset: newString.length),
              );
            }
            widget.onValueChanged(_currentValue);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EditableTitle: maneja la edición de título con un focusNode
// Cancela edición si pierde el foco
// ---------------------------------------------------------------------------
class _EditableTitle extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCancel;

  const _EditableTitle({
    Key? key,
    required this.initialText,
    required this.onSubmitted,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<_EditableTitle> createState() => _EditableTitleState();
}

class _EditableTitleState extends State<_EditableTitle> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late String _oldText;

  @override
  void initState() {
    super.initState();
    _oldText = widget.initialText;
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();

    // Seleccionar todo el texto cuando gana foco
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        });
      } else {
        widget.onCancel();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localTheme = Theme.of(context).copyWith(
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color.fromARGB(255, 110, 170, 255),
        selectionColor: Color.fromARGB(128, 110, 170, 255),
        selectionHandleColor: Color.fromARGB(255, 90, 130, 200),
      ),
    );

    return Theme(
      data: localTheme,
      child: TextField(
        autofocus: true,
        focusNode: _focusNode,
        controller: _controller,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Editar título',
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(0),
          ),
        ),
        onSubmitted: (value) {
          widget.onSubmitted(value.trim().isEmpty ? _oldText : value.trim());
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Campo de texto para la categoría en el dialog
// ---------------------------------------------------------------------------
class _CategoryTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;

  const _CategoryTextField({
    Key? key,
    required this.controller,
    required this.hint,
  }) : super(key: key);

  @override
  State<_CategoryTextField> createState() => _CategoryTextFieldState();
}

class _CategoryTextFieldState extends State<_CategoryTextField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      enabled: false,
      decoration: InputDecoration(
        labelText: widget.hint,
        disabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Campo de texto "azul" para el monto cuando se agrega un item
// Comas, 2 decimales, sin .00 auto, y antepone "$" SÓLO en la lógica de formateo
// NOT en prefixText, y textAlign a la IZQUIERDA
// ---------------------------------------------------------------------------
class _BlueTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String prefixText;

  const _BlueTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    required this.prefixText,
  }) : super(key: key);

  @override
  State<_BlueTextField> createState() => _BlueTextFieldState();
}

class _BlueTextFieldState extends State<_BlueTextField> {
  late FocusNode _focusNode;
  final NumberFormat _formatter = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Se mantiene en "0" si era "0.0"
    if (widget.controller.text == "0.0") {
      widget.controller.text = "0";
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localTheme = Theme.of(context).copyWith(
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color.fromARGB(255, 110, 170, 255),
        selectionColor: Color.fromARGB(128, 110, 170, 255),
        selectionHandleColor: Color.fromARGB(255, 90, 130, 200),
      ),
    );

    return Theme(
      data: localTheme,
      child: TextField(
        focusNode: _focusNode,
        controller: widget.controller,
        textAlign: TextAlign.left, // <--- Alineado a la IZQUIERDA
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.labelText,
          // Se quita el prefijo "$ " para evitar duplicar el símbolo.
          prefixText: "\$",
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
        onTap: () {
          // Seleccionar todo al hacer tap
          widget.controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: widget.controller.text.length,
          );
        },
        onChanged: (val) {
          // 1) Quitar comas y '$'
          String raw = val.replaceAll(',', '').replaceAll('\$', '');
          // 2) Limitar a 2 decimales
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

          // 3) Manejo parcial si termina en "." o ".<1digit>"
          if (raw.endsWith('.') || raw.matchesDecimalWithOneDigitEnd()) {
            final parts = raw.split('.');
            final intPart = double.tryParse(parts[0]) ?? 0.0;
            final formattedInt = _formatter.format(intPart).split('.')[0];
            final partialDecimal = parts.length > 1 ? '.' + parts[1] : '';
            final newString = '$formattedInt$partialDecimal';  // Sin "$"
            widget.controller.value = TextEditingValue(
              text: newString,
              selection: TextSelection.collapsed(offset: newString.length),
            );
          } else {
            // normal
            final formatted = _formatter.format(number);
            final newString = formatted;  // Sin "$"
            widget.controller.value = TextEditingValue(
              text: newString,
              selection: TextSelection.collapsed(offset: newString.length),
            );
          }
        },
      ),
    );
  }
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
