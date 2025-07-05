import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pocketplanner/services/date_range.dart'; // <- ajusta el path si es otro
import '../flutterflow_components/flutterflowtheme.dart';
import 'package:pocketplanner/database/sqlite_management.dart';
import 'package:pocketplanner/services/active_budget.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pocketplanner/services/actual_currency.dart';

/// ──────────────────────────────────────────────────────────
///  MODELOS DE PRESENTACIÓN
/// ──────────────────────────────────────────────────────────

class TransactionData {
  String type; // 'Gasto' | 'Ingreso' | 'Ahorro'
  double rawAmount; // 1234.5
  String category; // nombre de la categoría

  TransactionData({
    required this.type,
    required this.rawAmount,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'rawAmount': rawAmount,
    'category': category,
  };

  factory TransactionData.fromJson(Map<String, dynamic> json) =>
      TransactionData(
        type: json['type'],
        rawAmount: (json['rawAmount'] as num).toDouble(),
        category: json['category'],
      );
}

class ItemData {
  String name;
  double amount;
  double? goal;
  IconData? iconData;

  ItemData({required this.name, this.amount = 0.0, this.goal, this.iconData});

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    if (goal != null) 'goal': goal,
    'iconData': iconData?.codePoint,
  };

  factory ItemData.fromJson(Map<String, dynamic> json) => ItemData(
    name: json['name'],
    amount: (json['amount'] as num).toDouble(),
    goal: json['goal'] != null ? (json['goal'] as num).toDouble() : null,
    iconData:
        json['iconData'] != null
            ? IconData(json['iconData'], fontFamily: 'MaterialIcons')
            : null,
  );
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

  Map<String, dynamic> toJson() => {
    'title': title,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory SectionData.fromJson(Map<String, dynamic> json) => SectionData(
    title: json['title'],
    items: (json['items'] as List).map((e) => ItemData.fromJson(e)).toList(),
  );
}

/// ──────────────────────────────────────────────────────────
///  WIDGET – Pantalla "Restante"
/// ──────────────────────────────────────────────────────────

class IndicatorsHomeScreen extends StatefulWidget {
  const IndicatorsHomeScreen({Key? key}) : super(key: key);

  @override
  State<IndicatorsHomeScreen> createState() => _IndicatorsHomeScreenState();
}

class _IndicatorsHomeScreenState extends State<IndicatorsHomeScreen> {
  final BudgetDao _dao = BudgetDao();

  final List<SectionData> _sections = [];
  final List<TransactionData> _transactions = [];
  String get _currency => context.watch<ActualCurrency>().cached;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final int? bid = context.read<ActiveBudget>().idBudget;
    if (bid == null) return; // No hay presupuesto aún

    // Leer desde SQLite filtrado por presupuesto
    final sectionsFromDb = await _dao.fetchSections(idBudget: bid);
    final transactionsFromDb = await _dao.fetchTransactions(idBudget: bid);

    // Calcular saldos restantes
    final computed =
        sectionsFromDb
            .map((sec) => _computeIndicators(sec, transactionsFromDb))
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

  /* 
   Calcula los indicadores para cada tarjeta
   – Ingresos  -> 1 solo ítem  «Balance Total»
   – Gastos    -> restante por categoría   (plan – gastado)
   – Ahorros   -> progreso “$ahorrado de $meta”
   – Otras tarjetas personalizadas se devuelven sin cambios
  */

  SectionData _computeIndicators(
    SectionData section,
    List<TransactionData> txs,
  ) {
    /*  ----------  INGRESOS  ---------- */
    if (section.title == 'Ingresos') {
      final plannedIncome = section.items.fold<double>(
        0,
        (s, it) => s + it.amount,
      ); //  plan

      final otherIncomes = txs
          .where((tx) => tx.type == 'Ingreso')
          .fold<double>(0, (s, tx) => s + tx.rawAmount); //  Ingresos

      final totalExpenses = txs
          .where((tx) => tx.type == 'Gasto')
          .fold<double>(0, (s, tx) => s + tx.rawAmount); //  Gastos

      final totalSavings = txs
          .where((tx) => tx.type == 'Ahorro')
          .fold<double>(0, (s, tx) => s + tx.rawAmount); //  Ahorros

      final balance = (plannedIncome + otherIncomes) - (totalExpenses + totalSavings);

      return SectionData(
        title: section.title,
        items: [
          ItemData(
            name: 'Balance Total',
            amount: balance,
            iconData: Icons.payments,
          ),
        ],
      );
    }

    /* ----------  GASTOS  ---------- */
    if (section.title == 'Gastos') {
      final items =
          section.items.map((item) {
            final spent = txs
                .where((tx) => tx.type == 'Gasto' && tx.category == item.name)
                .fold<double>(0, (s, tx) => s + tx.rawAmount);

            return ItemData(
              name: item.name,
              amount: item.amount - spent, // restante
              iconData: item.iconData,
            );
          }).toList();

      return SectionData(title: section.title, items: items);
    }

    /* ----------  AHORROS  ---------- */
    if (section.title == 'Ahorros') {
      final items =
          section.items.map((item) {
            final saved = txs
                .where((tx) => tx.type == 'Ahorro' && tx.category == item.name)
                .fold<double>(0, (s, tx) => s + tx.rawAmount);

            return ItemData(
              name: item.name,
              amount: saved, // progreso
              goal: item.amount, // meta
              iconData: item.iconData,
            );
          }).toList();

      return SectionData(title: section.title, items: items);
    }

    /* ----------  OTROS  ---------- */
    return section; // tarjetas personalizadas sin calculo especial
  }

  //Interfaz

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    if (_sections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final sec in _sections) ...[
              _buildSectionCard(sec),
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
            Divider(color: theme.secondaryText),
            const SizedBox(height: 12),
            for (int i = 0; i < section.items.length; i++) ...[
              _buildItem(section.items[i]),
              if (i < section.items.length - 1) ...[
                const SizedBox(height: 12),
                Divider(color: theme.secondaryText),
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

    /* ---------- etiqueta a mostrar ---------- */
    String display;
    Color displayColor = theme.primaryText;

    // Ahorros: $progreso de $meta
    if (item.goal != null) {
      display =
          '$_currency${NumberFormat('#,##0.##').format(item.amount)} '
          'de $_currency${NumberFormat('#,##0.##').format(item.goal)}';
    }
    // Balance Total (puede ser negativo)
    else if (item.name == 'Balance Total') {
      display = '$_currency${NumberFormat('#,##0.##').format(item.amount)}';
      if (item.amount < 0) displayColor = Colors.red;
    }
    else {
      display = '$_currency${NumberFormat('#,##0.##').format(item.amount)}';
      if (item.amount < 0) displayColor = Colors.red;
    }

    return Row(
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color.fromARGB(56, 117, 117, 117),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            display,
            style: theme.typography.bodyMedium.override(
              fontSize: 14,
              color: displayColor,
            ),
          ),
        ),
      ],
    );
  }
}

///  Mapea el nombre textual del icono a su IconData.
 const Map<String, IconData> _materialIconByName = {
    // ─────────── originales ───────────
    'directions_bus': Icons.directions_bus,
    'movie': Icons.movie,
    'school': Icons.school,
    'paid': Icons.paid,
    'restaurant': Icons.restaurant,
    'credit_card': Icons.credit_card,
    'devices_other': Icons.devices_other,
    'attach_money': Icons.attach_money,
    'point_of_sale': Icons.point_of_sale,
    'savings': Icons.savings,
    'local_airport': Icons.local_airport,
    'build_circle': Icons.build_circle,
    'pending_actions': Icons.pending_actions,
    'fastfood': Icons.fastfood,
    'show_chart': Icons.show_chart,
    'medical_services': Icons.medical_services,
    'account_balance': Icons.account_balance,
    'payments': Icons.payments,
    'beach_access': Icons.beach_access,
    'build': Icons.build,
    'category': Icons.category,
    // ─────────── gastos (id_movement = 1) ───────────
    'bolt': Icons.bolt,
    'electric_bolt': Icons.electric_bolt,
    'water_drop': Icons.water_drop,
    'wifi': Icons.wifi,
    'health_and_safety': Icons.health_and_safety,
    'shopping_bag': Icons.shopping_bag,
    'card_giftcard': Icons.card_giftcard,
    'pets': Icons.pets,
    'home_repair_service': Icons.home_repair_service,
    'spa': Icons.spa,
    'security': Icons.security,
    'menu_book': Icons.menu_book,
    'request_quote': Icons.request_quote,
    'subscriptions': Icons.subscriptions,
    'sports_soccer': Icons.sports_soccer,
    // ─────────── ingresos (id_movement = 2) ───────────
    'star': Icons.star,
    'work': Icons.work,
    'trending_up': Icons.trending_up,
    'undo': Icons.undo,
    'apartment': Icons.apartment,
    'sell': Icons.sell,
    'stacked_line_chart': Icons.stacked_line_chart,
    'account_balance_wallet': Icons.account_balance_wallet,
    'elderly': Icons.elderly,

    // ─────────── ahorros (id_movement = 3) ───────────
    'directions_car': Icons.directions_car,
    'child_friendly': Icons.child_friendly,
    'house': Icons.house,
    'priority_high': Icons.priority_high,
    'flight': Icons.flight,
  };

///  DAO – Acceso a la BD local

class BudgetDao {
  final Database _db = SqliteManager.instance.db;

  // Secciones
  Future<List<SectionData>> fetchSections({required int idBudget}) async {
    const sql = '''
      SELECT ca.id_card,
             ca.title,
             it.amount,
             cat.name       AS cat_name,
             cat.icon_name  AS icon_name          -- ← nuevo campo
      FROM   card_tb        ca
      LEFT  JOIN item_tb     it  ON it.id_card      = ca.id_card
      LEFT  JOIN category_tb cat ON cat.id_category = it.id_category
      WHERE  ca.id_budget = ?                       -- filtro
      ORDER BY ca.id_card;
    ''';

    final rows = await _db.rawQuery(sql, [idBudget]);

    // Agrupar por tarjeta
    final Map<int, SectionData> tmp = {};
    for (final r in rows) {
      final cardId = r['id_card'] as int;

      tmp.putIfAbsent(
        cardId,
        () => SectionData(title: r['title'] as String, items: []),
      );

      // Solo si existe item en la fila
      if (r['cat_name'] != null) {
        final iconName = r['icon_name'] as String?;
        tmp[cardId]!.items.add(
          ItemData(
            name: r['cat_name'] as String,
            amount: (r['amount'] as num).toDouble(),
            iconData: _materialIconByName[iconName] ?? Icons.category,
          ),
        );
      }
    }
    return tmp.values.toList();
  }

  // Transacciones

  Future<List<TransactionData>> fetchTransactions({
    required int idBudget,
  }) async {
    /*   Trae solo las transacciones que caen dentro del
          periodo (mensual o quincenal) activo.                 */

    final rows = await selectTransactionsInPeriod(
      budgetId: idBudget,
      extraWhere: null, // sin filtros adicionales
      extraArgs: const [],
    );

    String _map(int id) => switch (id) {
      1 => 'Gasto',
      2 => 'Ingreso',
      3 => 'Ahorro',
      _ => 'Otro',
    };

    return rows
        .map(
          (r) => TransactionData(
            type: _map(r['id_movement'] as int),
            rawAmount: (r['amount'] as num).toDouble(),
            category: r['category_name'] as String,
          ),
        )
        .toList();
  }
}
