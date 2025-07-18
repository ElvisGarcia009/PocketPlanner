import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pocketplanner/services/date_range.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../flutterflow_components/flutterflowtheme.dart';
import 'package:pocketplanner/database/sqlite_management.dart';
import 'package:pocketplanner/services/active_budget.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pocketplanner/services/actual_currency.dart';

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

  /// 1 = Gasto, 2 = Ingreso, 3 = Ahorro   (null -> desconocido/personalizado)
  int? movementId;

  ItemData({
    required this.name,
    this.amount = 0.0,
    this.goal,
    this.iconData,
    this.movementId,
  });

  ItemData copyWith({
    String? name,
    double? amount,
    double? goal,
    IconData? iconData,
  }) {
    return ItemData(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      goal: goal ?? this.goal, // ⬅️ Añadido
      iconData: iconData ?? this.iconData,
      movementId: movementId,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    if (goal != null) 'goal': goal,
    'iconData': iconData?.codePoint,
    if (movementId != null) 'movementId': movementId,
  };

  factory ItemData.fromJson(Map<String, dynamic> j) => ItemData(
    name: j['name'],
    amount: (j['amount'] as num).toDouble(),
    goal: j['goal'] != null ? (j['goal'] as num).toDouble() : null,
    iconData:
        j['iconData'] != null
            ? IconData(j['iconData'], fontFamily: 'MaterialIcons')
            : null,
    movementId: j['movementId'] as int?,
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

//  WIDGET – Pantalla "Indicators"

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
    _showIntroIfNeeded();
  }

  Future<void> _loadData() async {
    final int? bid = context.read<ActiveBudget>().idBudget;
    if (bid == null) return;

    final sectionsFromDb = await _dao.fetchSections(idBudget: bid);
    final transactionsFromDb = await _dao.fetchTransactions(idBudget: bid);

    /* 🔹  categorías de GASTO que SÍ están en el planner */
    final plannedGastoCats =
        sectionsFromDb
            .expand((s) => s.items)
            .where((it) => it.movementId == 1) // sólo gasto
            .map((it) => it.name)
            .toSet();

    /* 🔹  gasto NO planificado → “Otros” global  */
    final unknownSpent = transactionsFromDb
        .where(
          (tx) => tx.type == 'Gasto' && !plannedGastoCats.contains(tx.category),
        )
        .fold<double>(0, (s, tx) => s + tx.rawAmount);

    /* 🔹  existe algún ítem “Otros” en el planner? */
    final bool otrosPlanned = plannedGastoCats.contains('Otros');

    final computed =
        sectionsFromDb
            .map(
              (sec) => _computeIndicators(
                sec,
                transactionsFromDb,
                plannedGastoCats,
                unknownSpent,
                otrosPlanned,
              ),
            )
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

  SectionData _computeIndicators(
    SectionData section,
    List<TransactionData> txs,
    Set<String> plannedGastoCats,
    double unknownSpent,
    bool otrosPlanned,
  ) {
    if (section.title == 'Ingresos') {
      final plannedIncome = section.items.fold<double>(
        0,
        (s, it) => s + it.amount,
      );

      final otherIncomes = txs
          .where((tx) => tx.type == 'Ingreso')
          .fold<double>(0, (s, tx) => s + tx.rawAmount);

      final totalExpenses = txs
          .where((tx) => tx.type == 'Gasto')
          .fold<double>(0, (s, tx) => s + tx.rawAmount);

      final totalSavings = txs
          .where((tx) => tx.type == 'Ahorro')
          .fold<double>(0, (s, tx) => s + tx.rawAmount);

      final balance =
          (plannedIncome + otherIncomes) - (totalExpenses + totalSavings);

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

    // GASTOS

    if (section.title == 'Gastos') {
      // TODAS las categorías planificadas de gasto, no solo las del card

      final items =
          section.items.map((item) {
            final spent = txs
                .where((tx) => tx.type == 'Gasto' && tx.category == item.name)
                .fold<double>(0, (s, tx) => s + tx.rawAmount);

            return ItemData(
              name: item.name,
              amount:
                  item.amount -
                  spent - // resta gasto propio
                  (item.name == 'Otros'
                      ? unknownSpent
                      : 0), // y ‟no planificado”
              iconData: item.iconData,
              movementId: 1,
            );
          }).toList();

      // Si NO existe “Otros” presupuestado debemos crearlo aquí
      if (!otrosPlanned && unknownSpent != 0) {
        items.add(
          ItemData(
            name: 'Otros',
            amount: -unknownSpent,
            iconData: Icons.category,
            movementId: 1,
          ),
        );
      }

      return SectionData(title: section.title, items: items);
    }

    // AHORROS
    if (section.title == 'Ahorros') {
      final items =
          section.items.map((item) {
            final saved = txs
                .where((tx) => tx.type == 'Ahorro' && tx.category == item.name)
                .fold<double>(0, (s, tx) => s + tx.rawAmount);

            return ItemData(
              name: item.name,
              amount: saved,
              goal: item.amount,
              iconData: item.iconData,
              movementId: 3,
            );
          }).toList();

      return SectionData(title: section.title, items: items);
    }

    // OTROS
    final items =
        section.items.map((item) {
          switch (item.movementId) {
            case 1: // Gasto
              final spent = txs
                  .where((tx) => tx.type == 'Gasto' && tx.category == item.name)
                  .fold<double>(0, (s, tx) => s + tx.rawAmount);

              final extra = (item.name == 'Otros') ? unknownSpent : 0;

              return item.copyWith(amount: item.amount - spent - extra);

            case 3: // Ahorro
              final saved = txs
                  .where(
                    (tx) => tx.type == 'Ahorro' && tx.category == item.name,
                  )
                  .fold<double>(0, (s, tx) => s + tx.rawAmount);
              return item.copyWith(amount: saved, goal: item.amount);

            default:
              return item;
          }
        }).toList();
    return SectionData(title: section.title, items: items);
  }

  Future<void> _showIntroIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('indicators_home_intro') ?? false;
    final theme = FlutterFlowTheme.of(context);

    if (!shown) {
      // Espera a que build() haya renderizado
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: Center(child: const Text('Indicadores')),
                content: const Text(
                  'Indicadores al lado de tu Plan:\n\n'
                  '• Balance Total: muestra tu saldo final (ingresos − gastos − ahorros).\n\n'
                  '• Gastos: indica cuánto queda en cada categoría; los gastos no planificados aparecen en “Otros”.\n\n'
                  '• Ahorros: refleja cuánto has ahorrado frente a la meta establecida.\n\n'
                  'Mantén tus transacciones y presupuestos actualizados para ver estos indicadores correctamente.',
                ),
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.primaryText,
                      backgroundColor: theme.primary,
                      textStyle: theme.typography.bodyMedium,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
        );
      });
      await prefs.setBool('indicators_home_intro', true);
    }
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

    // El formato de la cantidad depende del tipo de movimiento
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
    } else {
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
  'directions_bus': Icons.directions_bus,
  'movie': Icons.movie,
  'school': Icons.school,
  'account_balance': Icons.account_balance,
  'fastfood': Icons.fastfood,
  'credit_card': Icons.credit_card,
  'category': Icons.category,
  'bolt': Icons.bolt,
  'wifi': Icons.wifi,
  'health_and_safety': Icons.health_and_safety,
  'shopping_bag': Icons.shopping_bag,
  'card_giftcard': Icons.card_giftcard,
  'pets': Icons.pets,
  'home_repair_service': Icons.home_repair_service,
  'home': Icons.home,
  'spa': Icons.spa,
  'security': Icons.security,
  'request_quote': Icons.request_quote,
  'subscriptions': Icons.subscriptions,
  'sports_soccer': Icons.sports_soccer,
  'local_gas_station': Icons.local_gas_station,
  'paid': Icons.paid,
  'local_parking': Icons.local_parking,
  'car_repair': Icons.car_repair,
  'live_tv': Icons.live_tv,
  'fitness_center': Icons.fitness_center,
  'phone_android': Icons.phone_android,
  'attach_money': Icons.attach_money,
  'payments': Icons.payments,
  'show_chart': Icons.show_chart,
  'star': Icons.star,
  'work': Icons.work,
  'trending_up': Icons.trending_up,
  'undo': Icons.undo,
  'apartment': Icons.apartment,
  'sell': Icons.sell,
  'stacked_line_chart': Icons.stacked_line_chart,
  'elderly': Icons.elderly,
  'shopping_cart': Icons.shopping_cart,
  'medical_services': Icons.medical_services,
  'savings': Icons.savings,
  'beach_access': Icons.beach_access,
  'build': Icons.build,
  'account_balance_wallet': Icons.account_balance_wallet,
  'favorite': Icons.favorite,
  'directions_car': Icons.directions_car,
  'house': Icons.house,
  'flight': Icons.flight,
  'priority_high': Icons.priority_high,
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
         cat.name        AS cat_name,
         cat.icon_name   AS icon_name,
         cat.id_movement AS id_move            -- ⬅️
  FROM   card_tb        ca
  LEFT  JOIN item_tb     it  ON it.id_card      = ca.id_card
  LEFT  JOIN category_tb cat ON cat.id_category = it.id_category
  WHERE  ca.id_budget = ?
  ORDER  BY ca.id_card;
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
            movementId: r['id_move'] as int?,
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
