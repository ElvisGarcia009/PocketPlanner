import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../flutterflow_components/flutterflowtheme.dart'; // Importa tu archivo de temas

/// Modelo para transacciones (tipo: 'Gasto', 'Ingreso', 'Ahorro')
class TransactionData {
  String type;
  double rawAmount;
  String category;

  TransactionData({
    required this.type,
    required this.rawAmount,
    required this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'rawAmount': rawAmount,
      'category': category,
    };
  }

  factory TransactionData.fromJson(Map<String, dynamic> json) {
    return TransactionData(
      type: json['type'],
      rawAmount: (json['rawAmount'] as num).toDouble(),
      category: json['category'],
    );
  }
}

/// Modelo ItemData
class ItemData {
  String name;
  double amount;
  IconData? iconData;

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

/// Modelo SectionData
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
    return SectionData(
      title: json['title'],
      items: items,
    );
  }
}

class RemainingHomeScreen extends StatefulWidget {
  const RemainingHomeScreen({Key? key}) : super(key: key);

  @override
  State<RemainingHomeScreen> createState() => _RemainingHomeScreenState();
}

class _RemainingHomeScreenState extends State<RemainingHomeScreen> {
  final List<SectionData> _sections = [];
  final List<TransactionData> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    // Cargar presupuesto
    String? budgetData = prefs.getString('budget_data');
    if (budgetData != null) {
      List<dynamic> jsonData = jsonDecode(budgetData);
      List<SectionData> loadedSections =
          jsonData.map((s) => SectionData.fromJson(s)).toList();

      // Cargar transacciones
      String? txData = prefs.getString('transactions');
      if (txData != null) {
        List<dynamic> jsonTx = jsonDecode(txData);
        _transactions.clear();
        _transactions.addAll(
          jsonTx.map((t) => TransactionData.fromJson(t)).toList(),
        );
      }

      // Calcular los montos restantes por ítem
      List<SectionData> computedSections =
          loadedSections.map((section) => _computeRemaining(section)).toList();
      setState(() {
        _sections.clear();
        _sections.addAll(computedSections);
      });
    }
  }

  SectionData _computeRemaining(SectionData section) {
    List<ItemData> computedItems = [];

    for (var item in section.items) {
      double newAmount = item.amount;

      if (section.title == "Ingresos") {
        double sumIngreso = 0.0, sumGasto = 0.0, sumAhorro = 0.0;
        for (var tx in _transactions) {
          if (tx.category == item.name) {
            if (tx.type == "Ingreso") sumIngreso += tx.rawAmount;
            if (tx.type == "Gasto") sumGasto += tx.rawAmount;
            if (tx.type == "Ahorro") sumAhorro += tx.rawAmount;
          }
        }
        newAmount = item.amount + sumIngreso - sumGasto - sumAhorro;
      } else if (section.title == "Gastos") {
        double sumGasto = 0.0;
        for (var tx in _transactions) {
          if (tx.category == item.name && tx.type == "Gasto") {
            sumGasto += tx.rawAmount;
          }
        }
        newAmount = item.amount - sumGasto;
      } else if (section.title == "Ahorros") {
        double sumAhorro = 0.0;
        for (var tx in _transactions) {
          if (tx.category == item.name && tx.type == "Ahorro") {
            sumAhorro += tx.rawAmount;
          }
        }
        // Podrías interpretar Ahorros distinto, depende de tu lógica.
        // Aquí se lee el total de "Ahorros" sumado, a decisión tuya:
        newAmount = sumAhorro;
      }

      computedItems.add(
        ItemData(
          name: item.name,
          amount: newAmount,
          iconData: item.iconData,
        ),
      );
    }

    return SectionData(
      title: section.title,
      items: computedItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < _sections.length; i++) ...[
              _buildSectionCard(_sections[i]),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(SectionData section) {
    final theme = FlutterFlowTheme.of(context);

    return Card(
      color: theme.secondaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Text(
                section.title,
                style: theme.typography.titleMedium.override(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: theme.secondaryText, thickness: 1),
            const SizedBox(height: 12),
            for (int i = 0; i < section.items.length; i++) ...[
              _buildItem(section.items[i]),
              if (i < section.items.length - 1) ...[
                const SizedBox(height: 12),
                Divider(color: theme.secondaryText, thickness: 1),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItem(ItemData item) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white), // Ejemplo de color de acento
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color.fromARGB(56, 117, 117, 117),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${item.amount < 0 ? '-' : ''}\$${NumberFormat('#,##0.##').format(item.amount.abs())}",
            style: theme.typography.bodyMedium.override(
              fontSize: 14,
              color: item.amount < 0 ? Colors.red : theme.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}
