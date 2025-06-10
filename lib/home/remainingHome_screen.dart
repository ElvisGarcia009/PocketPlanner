import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../flutterflow_components/flutterflowtheme.dart'; 
import 'package:Pocket_Planner/database/sqlite_management.dart';
import 'package:sqflite/sqflite.dart';

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
  final BudgetDao _dao = BudgetDao();             
  final List<SectionData> _sections = [];
  final List<TransactionData> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
  // ── leer todo desde SQLite ──
  final sectionsFromDb     = await _dao.fetchSections();
  final transactionsFromDb = await _dao.fetchTransactions();

  // ── calcular saldos restantes ──
  final computed = sectionsFromDb
      .map((sec) => _computeRemaining(sec, transactionsFromDb))
      .toList();

  setState(() {
    _sections
      ..clear()
      ..addAll(computed);
    _transactions
      ..clear()
      ..addAll(transactionsFromDb);
  });
}


 

/// Re-calcula el saldo restante de cada ítem de una sección
SectionData _computeRemaining(
  SectionData section,
  List<TransactionData> txs,      // ←  ahora recibe las transacciones
) {
  final List<ItemData> computedItems = [];

  for (final item in section.items) {
    double newAmount = item.amount;

    /* ───────── Ingresos ───────── */
    if (section.title == 'Ingresos') {
      double sumIngreso = 0, sumGasto = 0, sumAhorro = 0;

      for (final tx in txs) {
        if (tx.category != item.name) continue;

        switch (tx.type) {
          case 'Ingreso': sumIngreso += tx.rawAmount; break;
          case 'Gasto'  : sumGasto   += tx.rawAmount; break;
          case 'Ahorro' : sumAhorro  += tx.rawAmount; break;
        }
      }
      newAmount = item.amount + sumIngreso - sumGasto - sumAhorro;
    }

    /* ───────── Gastos ───────── */
    else if (section.title == 'Gastos') {
      double sumGasto = 0;
      for (final tx in txs) {
        if (tx.type == 'Gasto' && tx.category == item.name) {
          sumGasto += tx.rawAmount;
        }
      }
      newAmount = item.amount - sumGasto;
    }

    /* ───────── Ahorros ───────── */
    else if (section.title == 'Ahorros') {
      double sumAhorro = 0;
      for (final tx in txs) {
        if (tx.type == 'Ahorro' && tx.category == item.name) {
          sumAhorro += tx.rawAmount;
        }
      }
      // aquí decidimos que el valor mostrado es lo ahorrado efectivamente
      newAmount = sumAhorro;
    }

    /* ───────── cualquier otra sección ───────── */
    computedItems.add(
      ItemData(
        name:     item.name,
        amount:   newAmount,
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

/* ───────── BudgetDao ───────── */
class BudgetDao {
  final Database _db = SqliteManager.instance.db;

  Future<List<SectionData>> fetchSections() async {
    const sql = '''
      SELECT ca.id_card, ca.title,
             it.amount,
             cat.name        AS cat_name,
             cat.icon_code
      FROM   card_tb ca
      LEFT JOIN item_tb it   ON it.id_card = ca.id_card
      LEFT JOIN category_tb cat ON cat.id_category = it.id_category
      ORDER BY ca.id_card;
    ''';

    final rows = await _db.rawQuery(sql);

    // agrupar por tarjeta
    final Map<int, SectionData> tmp = {};
    for (final r in rows) {
      final cardId = r['id_card'] as int;
      tmp.putIfAbsent(
        cardId,
        () => SectionData(title: r['title'] as String, items: []),
      );

      if (r['cat_name'] != null) {
        tmp[cardId]!.items.add(
          ItemData(
            name:   r['cat_name'] as String,
            amount: (r['amount'] as num).toDouble(),
            iconData: IconData(
              r['icon_code'] as int,
              fontFamily: 'MaterialIcons',
            ),
          ),
        );
      }
    }
    return tmp.values.toList();
  }

  Future<List<TransactionData>> fetchTransactions() async {
    const sql = '''
      SELECT t.amount,
             t.id_movement,
             cat.name AS cat_name
      FROM   transaction_tb t
      JOIN   category_tb   cat ON cat.id_category = t.id_category;
    ''';

    final rows = await _db.rawQuery(sql);

    String _mapType(int id) => switch (id) { 
      1 => 'Gasto', 2 => 'Ingreso', 3 => 'Ahorro', _ => 'Otro' };

    return rows.map((r) => TransactionData(
      type:      _mapType(r['id_movement'] as int),
      rawAmount: (r['amount'] as num).toDouble(),
      category:  r['cat_name'] as String,
    )).toList();
  }
}

