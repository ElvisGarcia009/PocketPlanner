import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:Pocket_Planner/services/dateRange.dart';   // <- ajusta el path si es otro
import '../flutterflow_components/flutterflowtheme.dart';
import 'package:Pocket_Planner/database/sqlite_management.dart';
import 'package:Pocket_Planner/services/active_budget.dart';
import 'package:sqflite/sqflite.dart';

/// ──────────────────────────────────────────────────────────
///  MODELOS DE PRESENTACIÓN
/// ──────────────────────────────────────────────────────────

class TransactionData {
  String type;          // 'Gasto' | 'Ingreso' | 'Ahorro'
  double rawAmount;     // 1234.5
  String category;      // nombre de la categoría

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
  IconData? iconData;

  ItemData({
    required this.name,
    this.amount = 0.0,
    this.iconData,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'iconData': iconData?.codePoint,
      };

  factory ItemData.fromJson(Map<String, dynamic> json) => ItemData(
        name: json['name'],
        amount: (json['amount'] as num).toDouble(),
        iconData: json['iconData'] != null
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
        items: (json['items'] as List)
            .map((e) => ItemData.fromJson(e))
            .toList(),
      );
}

/// ──────────────────────────────────────────────────────────
///  WIDGET – Pantalla "Restante"
/// ──────────────────────────────────────────────────────────

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
    final int? bid = context.read<ActiveBudget>().idBudget;
    if (bid == null) return; // No hay presupuesto aún

    // Leer desde SQLite filtrado por presupuesto
    final sectionsFromDb     = await _dao.fetchSections(idBudget: bid);
    final transactionsFromDb = await _dao.fetchTransactions(idBudget: bid);

    // Calcular saldos restantes
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

  /* ─────────── Calcula el saldo restante para cada ítem ─────────── */
  SectionData _computeRemaining(
    SectionData section,
    List<TransactionData> txs,
  ) {
    final List<ItemData> computedItems = [];

    for (final item in section.items) {
      double newAmount = item.amount;

      if (section.title == 'Ingresos') {
        double inc = 0, exp = 0, sav = 0;
        for (final tx in txs) {
          if (tx.category != item.name) continue;
          switch (tx.type) {
            case 'Ingreso':
              inc += tx.rawAmount;
              break;
            case 'Gasto':
              exp += tx.rawAmount;
              break;
            case 'Ahorro':
              sav += tx.rawAmount;
              break;
          }
        }
        newAmount = item.amount + inc - exp - sav;
      } else if (section.title == 'Gastos') {
        double exp = txs
            .where((tx) => tx.type == 'Gasto' && tx.category == item.name)
            .fold(0, (s, tx) => s + tx.rawAmount);
        newAmount = item.amount - exp;
      } else if (section.title == 'Ahorros') {
        double sav = txs
            .where((tx) => tx.type == 'Ahorro' && tx.category == item.name)
            .fold(0, (s, tx) => s + tx.rawAmount);
        newAmount = sav;
      }

      computedItems.add(
        ItemData(
          name: item.name,
          amount: newAmount,
          iconData: item.iconData,
        ),
      );
    }
    return SectionData(title: section.title, items: computedItems);
  }

  /* ─────────── UI ─────────── */

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
                style: theme.typography.titleMedium
                    .override(fontWeight: FontWeight.bold),
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
            ]
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
            border: Border.all(color: Colors.white),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.iconData ?? Icons.category,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            item.name,
            style: theme.typography.bodyMedium
                .override(fontSize: 16, fontWeight: FontWeight.w500),
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

/// 🎯  Mapea el nombre textual del icono a su IconData.
/// Añade aquí todos los nombres que utilices en `category_tb.icon_name`.
const Map<String, IconData> _materialIconByName = {
  'directions_bus'   : Icons.directions_bus,
  'movie'            : Icons.movie,
  'school'           : Icons.school,
  'paid'             : Icons.paid,
  'restaurant'       : Icons.restaurant,
  'credit_card'      : Icons.credit_card,
  'devices_other'    : Icons.devices_other,
  'attach_money'     : Icons.attach_money,
  'point_of_sale'    : Icons.point_of_sale,
  'savings'          : Icons.savings,
  'local_airport'    : Icons.local_airport,
  'build_circle'     : Icons.build_circle,
  'pending_actions'  : Icons.pending_actions,
  'fastfood'         : Icons.fastfood,
  'show_chart'       : Icons.show_chart,
  'medical_services' : Icons.medical_services,
  'account_balance'  : Icons.account_balance,
  'payments'         : Icons.payments,
  'beach_access'     : Icons.beach_access,
  'build'            : Icons.build,

};


/// ──────────────────────────────────────────────────────────
///  DAO – Acceso a la BD local
/// ──────────────────────────────────────────────────────────
class BudgetDao {
  final Database _db = SqliteManager.instance.db;

  /*───────────────────────────── Sections ─────────────────────────────*/
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

      // Solo si existe ítem en la fila
      if (r['cat_name'] != null) {
        final iconName = r['icon_name'] as String?;           // puede ser null
        tmp[cardId]!.items.add(
          ItemData(
            name     : r['cat_name'] as String,
            amount   : (r['amount'] as num).toDouble(),
            iconData : _materialIconByName[iconName] ?? Icons.category,
          ),
        );
      }
    }
    return tmp.values.toList();
  }

/*────────────────────────── Transactions ───────────────────────────*/
Future<List<TransactionData>> fetchTransactions({
  required int idBudget,
  }) async {

    /* ➋ Trae solo las transacciones que caen dentro del
          periodo (mensual o quincenal) activo.                 */
    final rows = await selectTransactionsInPeriod(
      budgetId  : idBudget,
      extraWhere: null,          // ← sin filtros adicionales
      extraArgs : const [],
    );

    /* ➌ Mapea id_movement → texto para la UI */
    String _map(int id) => switch (id) {
          1 => 'Gasto',
          2 => 'Ingreso',
          3 => 'Ahorro',
          _ => 'Otro',
        };

    /* ➍ Convierte los registros en tu modelo de presentación */
    return rows.map(
      (r) => TransactionData(
        type      : _map(r['id_movement'] as int),
        rawAmount : (r['amount'] as num).toDouble(),
        category  : r['category_name'] as String,
      ),
    ).toList();
  }

}

