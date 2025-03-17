import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// Modelo para cada ítem dentro de la sección
class ItemData {
  String name;
  double amount;

  ItemData({
    required this.name,
    this.amount = 0.0,
  });
}

/// Modelo para cada sección (Ingresos, Ahorros, Gastos)
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
  // Lista de secciones por defecto
  final List<SectionData> _sections = [
    SectionData(
      title: 'Ingresos',
      items: [ItemData(name: 'Salario', amount: 0.0)],
    ),
    SectionData(
      title: 'Ahorros',
      items: [ItemData(name: 'Ahorros', amount: 0.0)],
    ),
    SectionData(
      title: 'Gastos',
      items: [ItemData(name: 'Transporte', amount: 0.0)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Estructura principal
      body: Column(
        children: [
          // Sección superior azul
          _buildTopSection(),

          // Sección inferior con fondo gris
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Construimos las secciones dinámicamente
                    for (int i = 0; i < _sections.length; i++) ...[
                      _buildSectionCard(i),
                      const SizedBox(height: 16),
                    ],
                    // Botón "Crear una nueva sección"
                    _buildCreateNewSectionButton(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sección superior azul (botón config + nombre de presupuesto)
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
              // Lógica de configuración de usuario
            },
          ),
          InkWell(
            onTap: () {
              // Mostrar lista de presupuestos del usuario
            },
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
  // Construye la Card de cada sección
  // ---------------------------------------------------------------------------
  Widget _buildSectionCard(int sectionIndex) {
    final section = _sections[sectionIndex];
    final titleController = TextEditingController(text: section.title);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Título editable de la sección
            _buildSectionTitle(sectionIndex, titleController),
            const SizedBox(height: 12),
            const Divider(color: Colors.grey, thickness: 1),
            const SizedBox(height: 12),

            // Lista de ítems
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

            // Botón para agregar nuevo ítem (sin subrayado)
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
  // Título editable de la sección
  // ---------------------------------------------------------------------------
  Widget _buildSectionTitle(int sectionIndex, TextEditingController titleController) {
    final section = _sections[sectionIndex];

    if (section.isEditingTitle) {
      // Mantenemos el título centrado, sin subrayado y con borde de foco azul
      return TextField(
        controller: titleController,
        autofocus: true,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold, // Mantiene negrita
          color: Colors.black,
        ),
        cursorColor: Colors.blue, // Cambia el color del cursor a azul
        onSubmitted: (value) {
          setState(() {
            section.title = value;
            section.isEditingTitle = false;
          });
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Editar título',
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(0),
          ),
        ),
      );
    } else {
      // Mostrar el título centrado
      return GestureDetector(
        onTap: () {
          setState(() {
            section.isEditingTitle = true;
          });
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
    }
  }

  // ---------------------------------------------------------------------------
  // Ítem con slide para borrar (slide hacia la derecha) y AmountEditor para editar el monto
  // ---------------------------------------------------------------------------
  Widget _buildItem(int sectionIndex, int itemIndex) {
    final item = _sections[sectionIndex].items[itemIndex];

    return Slidable(
      key: ValueKey('${sectionIndex}_$itemIndex'),
      // Para deslizar hacia la derecha, usamos startActionPane
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) {
              _confirmDeleteItem(sectionIndex, itemIndex);
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete
            ),
        ],
      ),
      child: Row(
        children: [
          // Ícono a la izquierda
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.category, color: Colors.blueAccent, size: 20),
          ),
          const SizedBox(width: 12),

          // Nombre de la categoría
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // AmountEditor en lugar de un simple texto
          SizedBox(
            width: 120,
            child: AmountEditor(
              initialValue: item.amount,
              onValueChanged: (newVal) {
                setState(() {
                  item.amount = newVal;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Diálogo para agregar un nuevo ítem a la sección
  // ---------------------------------------------------------------------------
  void _showAddItemDialog(int sectionIndex) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[100], // Fondo blanco tenue
          title: const Text("Agregar categoría"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo para el nombre
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Nombre de la categoría",
                  labelStyle: const TextStyle(color: Colors.blue),
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
              const SizedBox(height: 12),
              // Campo para el monto con teclado numérico
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Monto",
                  prefixText: "\$ ",
                  labelStyle: const TextStyle(color: Colors.blue),
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
            ],
          ),
          actions: [
            // Botón Cancelar
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancelar", style: TextStyle(color: Colors.white)),
            ),
            // Botón Aceptar
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
              ),
              onPressed: () {
                final name = nameController.text.trim();
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (name.isNotEmpty) {
                  setState(() {
                    _sections[sectionIndex].items.add(ItemData(name: name, amount: amount));
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
  // Diálogo de confirmación para borrar un ítem
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
}

class AmountEditor extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onValueChanged;

  /// [AmountEditor] muestra "RD\$" y permite editar el monto directamente
  /// con teclado numérico y actualización en tiempo real.
  const AmountEditor({
    Key? key,
    required this.initialValue,
    required this.onValueChanged,
  }) : super(key: key);

  @override
  State<AmountEditor> createState() => _AmountEditorState();
}

class _AmountEditorState extends State<AmountEditor> {
  late TextEditingController _controller;
  double _currentValue = 0.0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _controller = TextEditingController(text: _currentValue.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 213, 213, 213),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              textAlign: TextAlign.center,
              onTap: () {
                _controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _controller.text.length,
                );
              },
              onChanged: (val) {
                final newVal = double.tryParse(val) ?? 0.0;
                setState(() {
                  _currentValue = newVal;
                });
                widget.onValueChanged(_currentValue);
              },
            ),
          ),
        ],
      ),
    );
  }
}
