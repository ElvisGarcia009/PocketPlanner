import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global RouteObserver (si lo necesitas para recargar datos)
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

/// Modelo para cada ítem dentro de la sección
class ItemData {
  String name;
  double amount;
  IconData? iconData;

  ItemData({required this.name, this.amount = 0.0, this.iconData});

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'iconData': iconData?.codePoint,
  };

  factory ItemData.fromJson(Map<String, dynamic> json) => ItemData(
    name: json['name'],
    amount: (json['amount'] as num).toDouble(),
    iconData:
        json['iconData'] != null
            ? IconData(json['iconData'], fontFamily: 'MaterialIcons')
            : null,
  );
}

/// Modelo para cada sección
class SectionData {
  String title;
  bool isEditingTitle;
  List<ItemData> items;

  SectionData({
    required this.title,
    this.isEditingTitle = false,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory SectionData.fromJson(Map<String, dynamic> json) {
    List<dynamic> itemsJson = json['items'];
    List<ItemData> items = itemsJson.map((e) => ItemData.fromJson(e)).toList();
    return SectionData(title: json['title'], items: items);
  }
}

// Widgets auxiliares (EditableTitle, CategoryTextField, BlueTextField, AmountEditor)

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
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
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
    final theme = FlutterFlowTheme.of(context);
    return TextField(
      autofocus: true,
      focusNode: _focusNode,
      controller: _controller,
      textAlign: TextAlign.center,
      style: theme.typography.bodyMedium.override(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
      ),
      onSubmitted: (value) {
        widget.onSubmitted(value.trim().isEmpty ? _oldText : value.trim());
      },
    );
  }
}

class _CategoryTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _CategoryTextField({
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return TextField(
      controller: controller,
      enabled: false,
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: theme.typography.bodySmall.override(
          color: theme.secondaryText,
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.secondaryText),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _BlueTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String prefixText;

  const _BlueTextField({
    required this.controller,
    required this.labelText,
    required this.prefixText,
  });

  @override
  State<_BlueTextField> createState() => _BlueTextFieldState();
}

class _BlueTextFieldState extends State<_BlueTextField> {
  final NumberFormat _formatter = NumberFormat('#,##0.##');
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.text = _formatNumber(double.tryParse(_controller.text) ?? 0.0);
  }

  String _formatNumber(double value) => '\$${_formatter.format(value)}';

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixText: widget.prefixText,
        labelStyle: theme.typography.bodySmall.override(
          color: theme.secondaryText,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.secondaryText),
          borderRadius: BorderRadius.circular(4),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.secondaryText.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: theme.secondaryText),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      onChanged: (val) {
        String raw = val.replaceAll('\$', '').replaceAll(',', '');
        if (raw.contains('.')) {
          final dotIndex = raw.indexOf('.');
          final decimals = raw.length - dotIndex - 1;
          if (decimals > 2) raw = raw.substring(0, dotIndex + 3);
          if (raw == ".") raw = "0.";
        }
        double value = double.tryParse(raw) ?? 0.0;
        String newString = _formatNumber(value);
        if (raw.endsWith('.') || RegExp(r'^[0-9]*\.[0-9]$').hasMatch(raw)) {
          final parts = raw.split('.');
          final intPart = double.tryParse(parts[0]) ?? 0.0;
          final formattedInt = _formatter.format(intPart).split('.')[0];
          final partialDecimal = parts.length > 1 ? '.' + parts[1] : '';
          newString = '\$$formattedInt$partialDecimal';
        }
        if (_controller.text != newString) {
          _controller.value = TextEditingValue(
            text: newString,
            selection: TextSelection.collapsed(offset: newString.length),
          );
        }
      },
    );
  }
}

class AmountEditor extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onValueChanged;

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
  late FocusNode _focusNode;
  final NumberFormat _formatter = NumberFormat('#,##0.##');
  double _currentValue = 0.0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _focusNode = FocusNode();
    _controller = TextEditingController(
      text:
          _currentValue == 0.0
              ? "\$0"
              : "\$${_formatter.format(_currentValue)}",
    );
  }

  @override
  void didUpdateWidget(covariant AmountEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _currentValue = widget.initialValue;
      _controller.text =
          _currentValue == 0.0
              ? "\$0"
              : "\$${_formatter.format(_currentValue)}";
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatNumber(double value) => _formatter.format(value);

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return TextField(
      focusNode: _focusNode,
      controller: _controller,
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(border: InputBorder.none),
      style: theme.typography.bodyMedium,
      onTap: () {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      },
      onChanged: (val) {
        String raw = val.replaceAll('\$', '').replaceAll(',', '');
        if (raw.contains('.')) {
          final dotIndex = raw.indexOf('.');
          final decimals = raw.length - dotIndex - 1;
          if (decimals > 2) raw = raw.substring(0, dotIndex + 3);
          if (raw == ".") raw = "0.";
        }
        _currentValue = double.tryParse(raw) ?? 0.0;
        String newString = '\$${_formatNumber(_currentValue)}';
        if (raw.endsWith('.') || RegExp(r'^[0-9]*\.[0-9]$').hasMatch(raw)) {
          final parts = raw.split('.');
          final intPart = double.tryParse(parts[0]) ?? 0.0;
          final formattedInt = _formatter.format(intPart).split('.')[0];
          final partialDecimal = parts.length > 1 ? '.' + parts[1] : '';
          newString = '\$$formattedInt$partialDecimal';
        }
        if (_controller.text != newString) {
          _controller.value = TextEditingValue(
            text: newString,
            selection: TextSelection.collapsed(offset: newString.length),
          );
        }
        widget.onValueChanged(_currentValue);
      },
    );
  }
}

/// Pantalla Plan (editable)
class PlanHomeScreen extends StatefulWidget {
  const PlanHomeScreen({Key? key}) : super(key: key);

  @override
  State<PlanHomeScreen> createState() => _PlanHomeScreenState();
}

class _PlanHomeScreenState extends State<PlanHomeScreen> with RouteAware {
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
      items: [
        ItemData(
          name: 'Transporte',
          amount: 0.0,
          iconData: Icons.directions_bus,
        ),
      ],
    ),
  ];

  final GlobalKey _globalKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // CAMBIO AQUÍ: verificación de route
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _loadData();
  }

  // CAMBIO AQUÍ: verificación de route
  @override
  void dispose() {
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('budget_data');
    if (data != null) {
      List<dynamic> jsonData = jsonDecode(data);
      List<SectionData> loadedSections =
          jsonData.map((s) => SectionData.fromJson(s)).toList();
      setState(() {
        _sections.clear();
        _sections.addAll(loadedSections);
      });
    }
  }

  Future<void> _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> jsonData =
        _sections.map((s) => s.toJson()).toList();
    await prefs.setString('budget_data', jsonEncode(jsonData));
  }

  void _handleGlobalTap() {
    bool changed = false;
    for (var section in _sections) {
      if (section.isEditingTitle) {
        section.isEditingTitle = false;
        changed = true;
      }
    }
    if (changed) {
      setState(() {});
      _saveData();
    }
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: _handleGlobalTap,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        body: Column(
          children: [
            Expanded(
              child: Container(
                key: _globalKey,
                color: theme.primaryBackground,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
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

  Widget _buildSectionCard(int sectionIndex) {
    final theme = FlutterFlowTheme.of(context);
    final section = _sections[sectionIndex];
    return Card(
      color: theme.secondaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSectionTitle(sectionIndex),
            const SizedBox(height: 12),
            Divider(color: theme.secondaryText, thickness: 1),
            const SizedBox(height: 12),
            for (int i = 0; i < section.items.length; i++) ...[
              _buildItem(sectionIndex, i),
              if (i < section.items.length - 1) ...[
                const SizedBox(height: 12),
                Divider(color: theme.secondaryText, thickness: 1),
                const SizedBox(height: 12),
              ],
            ],
            const SizedBox(height: 12),
            Divider(color: theme.secondaryText, thickness: 1),
            const SizedBox(height: 12),
            InkWell(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    GestureDetector(
                    onTap: () {
                      setState(() {
                      _sections.removeAt(sectionIndex);
                      });
                      _saveData();
                    },
                    child: Text(
                      ' - Eliminar tarjeta',
                      style: theme.typography.bodyMedium.override(
                      fontSize: 14,
                      color: const Color.fromARGB(255, 244, 67, 54),
                      ),
                    ),
                    ),
                  GestureDetector(
                  onTap: () => _showAddItemDialog(sectionIndex),
                  child: Text(
                    'Agregar +',
                    style: theme.typography.bodyMedium.override(
                    fontSize: 14,
                    color: const Color.fromARGB(255, 33, 149, 243),
                    ),
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

  Widget _buildSectionTitle(int sectionIndex) {
    final theme = FlutterFlowTheme.of(context);
    final section = _sections[sectionIndex];
    if (!section.isEditingTitle) {
      return GestureDetector(
        onTap: () {
          setState(() {
            section.isEditingTitle = true;
          });
        },
        child: Center(
          child: Text(
            section.title,
            style: theme.typography.titleMedium.override(
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
          _saveData();
        },
        onCancel: () {
          setState(() => section.isEditingTitle = false);
          _saveData();
        },
      );
    }
  }

  Widget _buildItem(int sectionIndex, int itemIndex) {
    final theme = FlutterFlowTheme.of(context);
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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.iconData ?? Icons.category,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              style: theme.typography.bodyMedium.override(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            ),
            Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(56, 117, 117, 117), // Add background color here
              borderRadius: BorderRadius.circular(20), // Add border radius here
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 3, left: 3),
              child: Flexible(
              child: IntrinsicWidth(
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Center( // Center the text
                child: AmountEditor(
                key: ValueKey(item.amount),
                initialValue: item.amount,
                onValueChanged: (newVal) {
                  item.amount = newVal;
                  _saveData();
                },
                ),
              ),
              ),
              ),
              ),
            ),
            ),
        ],
      ),
    );
  }

  void _showAddItemDialog(int sectionIndex) {
    final theme = FlutterFlowTheme.of(context);
    final nameController = TextEditingController();
    final amountController = TextEditingController(text: "0");
    IconData? pickedIcon;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.primaryBackground,
          title: Text("Agregar ítem", style: theme.typography.titleLarge, textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final result = await _showCategoryDialog(
                    _sections[sectionIndex].title,
                  );
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
              _BlueTextField(
                controller: amountController,
                labelText: "Monto",
                prefixText: "",
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Cancelar",
                style: theme.typography.bodyMedium.override(
                  color: Colors.white,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
              onPressed: () {
                final name = nameController.text.trim();
                final raw = amountController.text
                    .replaceAll(',', '')
                    .replaceAll('\$', '');
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
                  _saveData();
                }
                Navigator.of(context).pop();
              },
              child: Text(
                "Aceptar",
                style: theme.typography.bodyMedium.override(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteItem(int sectionIndex, int itemIndex) async {
    final item = _sections[sectionIndex].items[itemIndex];
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = FlutterFlowTheme.of(context);
        return AlertDialog(
          backgroundColor: theme.primaryBackground,
          title: const Text('Confirmar'),
          content: Text(
            '¿Estás seguro que quieres borrar la categoría "${item.name}"?',
            style: theme.typography.bodyMedium,
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: theme.primary),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: theme.primary),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, borrar'),
            ),
          ],
        );
      },
    );
    if (result == true) {
      setState(() {
        _sections[sectionIndex].items.removeAt(itemIndex);
      });
      _saveData();
    }
  }

  Widget _buildCreateNewSectionButton(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      //width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
        onPressed: () {
          // Add functionality for "Ajustar presupuesto con IA" here
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primary,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          'Ajustar presupuesto con IA',
          style: theme.typography.bodyMedium.override(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
          ),
          ElevatedButton(
        onPressed: () {
          setState(() {
            _sections.add(
          SectionData(
            title: 'Nueva Sección',
            items: [ItemData(name: 'Categoría', amount: 0.0)],
          ),
            );
          });
          _saveData();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primary,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          'Crear tarjeta',
          style: theme.typography.bodyMedium.override(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showCategoryDialog(String sectionTitle) async {
    final theme = FlutterFlowTheme.of(context);
    final categories = _getCategoriesForSection(sectionTitle);
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.primaryBackground,
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
              children:
                  categories.map((cat) {
                    return GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(cat),
                      child: SizedBox(
                        width: 90,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: theme.accent1,
                              child: Icon(
                                cat['icon'] as IconData,
                                color: theme.primary,
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
      // Sección Personalizada
      return [
        {'name': 'Ingresos', 'icon': Icons.monetization_on},
        {'name': 'Salario', 'icon': Icons.payments},
        {'name': 'Inversión', 'icon': Icons.show_chart},
        {'name': 'Ahorros de emergencia', 'icon': Icons.security},
        {'name': 'Ahorros', 'icon': Icons.savings},
        {'name': 'Vacaciones', 'icon': Icons.card_travel},
        {'name': 'Proyecto', 'icon': Icons.build},
        {'name': 'Transporte', 'icon': Icons.directions_bus},
        {'name': 'Entretenimiento', 'icon': Icons.movie},
        {'name': 'Gastos Estudiantiles', 'icon': Icons.school},
        {'name': 'Préstamo', 'icon': Icons.account_balance},
        {'name': 'Comida', 'icon': Icons.fastfood},
        {'name': 'Trjta. crédito', 'icon': Icons.credit_card},
        {'name': 'Otros', 'icon': Icons.add},
      ];
    }
  }
}
