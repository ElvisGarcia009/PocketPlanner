import 'package:flutter/foundation.dart';
import 'package:pocketplanner/BudgetAI/budget_engine.dart';
import 'package:pocketplanner/BudgetAI/review_screen.dart';
import 'package:pocketplanner/database/sqlite_management.dart';
import 'package:pocketplanner/services/active_budget.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pocketplanner/services/actual_currency.dart';

class CardSql {
  final int? idCard;
  final String title;
  final int idBudget;

  const CardSql({this.idCard, required this.title, required this.idBudget});

  Map<String, Object?> toMap() => {
    if (idCard != null) 'id_card': idCard,
    'title': title,
    'id_budget': idBudget,
    'date_crea': DateTime.now().toIso8601String(),
  };
}

class ItemData {
  int? idItem;
  int? idCategory;
  String name;
  double amount;
  IconData? iconData;
  int typeId;

  ItemData({
    required this.name,
    required this.amount,
    required this.typeId,
    this.idItem,
    this.idCategory,
    this.iconData,
  });
}

class ItemSql {
  final int? idItem;
  final int idCategory;
  final int idCard;
  final double amount;
  final int itemType;

  const ItemSql({
    this.idItem,
    required this.idCategory,
    required this.idCard,
    required this.amount,
    required this.itemType,
  });

  Map<String, Object?> toMap() => {
    if (idItem != null) 'id_item': idItem,
    'id_category': idCategory,
    'id_card': idCard,
    'amount': amount,
    'id_itemType': itemType,
    'date_crea': DateTime.now().toIso8601String(),
  };
}

/// Modelo para cada sección
class SectionData {
  int? idCard;
  String title;
  bool isEditingTitle;
  List<ItemData> items;

  SectionData({
    this.idCard,
    required this.title,
    this.isEditingTitle = false,
    required this.items,
  });
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
      decoration: const InputDecoration(border: InputBorder.none),
      onSubmitted: (value) {
        widget.onSubmitted(value.trim().isEmpty ? _oldText : value.trim());
      },
    );
  }
}

class _CategoryTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _CategoryTextField({required this.controller, required this.hint});

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

  String _formatNumber(double value) => _formatter.format(value);

  @override
  void didUpdateWidget(covariant _BlueTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // si cambió la divisa, re-formateamos el valor actual
    if (widget.prefixText != oldWidget.prefixText) {
      final raw = _stripCurrency(_controller.text);
      final value = double.tryParse(raw) ?? 0.0;
      _controller.text = _formatNumber(value);
    }
  }

  /// Quita separadores y el símbolo recibido en 'prefixText'.
  String _stripCurrency(String raw) {
    final escaped = RegExp.escape(widget.prefixText);
    return raw.replaceAll(RegExp('[,\\s$escaped]'), '');
  }

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
        String raw = val.replaceAll(',', '');
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
          newString = '${widget.prefixText}$formattedInt$partialDecimal';
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
  final String currencySymbol;

  const AmountEditor({
    Key? key,
    required this.initialValue,
    required this.onValueChanged,
    required this.currencySymbol,
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
              ? "${widget.currencySymbol}0"
              : "${widget.currencySymbol}${_formatter.format(_currentValue)}",
    );
  }

  @override
  void didUpdateWidget(covariant AmountEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue ||
        widget.currencySymbol != oldWidget.currencySymbol) {
      _currentValue = widget.initialValue;
      _controller.text =
          _currentValue == 0.0
              ? "${widget.currencySymbol}0"
              : "${widget.currencySymbol}${_formatter.format(_currentValue)}";
      ;
    }
  }

  String _stripCurrency(String raw) {
    final escaped = RegExp.escape(widget.currencySymbol);
    return raw.replaceAll(RegExp('[,\\s$escaped]'), '');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatNumber(double v) => _formatter.format(v);

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
        String raw = _stripCurrency(val);
        if (raw.contains('.')) {
          final dotIndex = raw.indexOf('.');
          final decimals = raw.length - dotIndex - 1;
          if (decimals > 2) raw = raw.substring(0, dotIndex + 3);
          if (raw == ".") raw = "0.";
        }
        _currentValue = double.tryParse(raw) ?? 0.0;
        String newString =
            '${widget.currencySymbol}${_formatNumber(_currentValue)}';
        if (raw.endsWith('.') || RegExp(r'^[0-9]*\.[0-9]$').hasMatch(raw)) {
          final parts = raw.split('.');
          final intPart = double.tryParse(parts[0]) ?? 0.0;
          final formattedInt = _formatter.format(intPart).split('.')[0];
          final partialDecimal = parts.length > 1 ? '.' + parts[1] : '';
          newString = '${widget.currencySymbol}$formattedInt$partialDecimal';
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
      items: [
        ItemData(
          name: 'Salario',
          amount: 0.0,
          iconData: Icons.payments,
          typeId: 1,
        ),
      ],
    ),
    SectionData(
      title: 'Ahorros',
      items: [
        ItemData(
          name: 'Ahorros',
          amount: 0.0,
          iconData: Icons.savings,
          typeId: 2,
        ),
      ],
    ),
    SectionData(
      title: 'Gastos',
      items: [
        ItemData(
          name: 'Transporte',
          amount: 0.0,
          iconData: Icons.directions_bus,
          typeId: 2,
        ),
      ],
    ),
  ];

  // Tarjetas cuyo título no debe poder editarse ni eliminarse
  static const Set<String> _fixedTitles = {'Ingresos', 'Gastos', 'Ahorros'};

  bool _isFixed(SectionData s) => _fixedTitles.contains(s.title);

  final GlobalKey _globalKey = GlobalKey();

  /// Devuelve el símbolo de divisa ya normalizado ("RD$" o "US$"").
  String get _currency => context.watch<ActualCurrency>().cached;

  // ————————————————————————————————————————————————————————————————

  @override
  void initState() {
    super.initState();
    _ensureDbAndLoad();
  }

  Future<void> _ensureDbAndLoad() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (!SqliteManager.instance.dbIsFor(uid)) {
      await SqliteManager.instance.initDbForUser(uid);
    }
    await _loadData();
  }

  static const Map<String, IconData> _materialIconByName = {
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
    'star': Icons.star,
    'work': Icons.work,
    'trending_up': Icons.trending_up,
    'undo': Icons.undo,
    'apartment': Icons.apartment,
    'sell': Icons.sell,
    'stacked_line_chart': Icons.stacked_line_chart,
    'account_balance_wallet': Icons.account_balance_wallet,
    'elderly': Icons.elderly,
    'directions_car': Icons.directions_car,
    'child_friendly': Icons.child_friendly,
    'house': Icons.house,
    'priority_high': Icons.priority_high,
    'flight': Icons.flight,
  };

  // Carga tarjetas e ítems del presupuesto activo
  Future<void> _loadData() async {
    final db = SqliteManager.instance.db;
    final int? bid = Provider.of<ActiveBudget>(context, listen: false).idBudget;

    if (bid == null) return; // sin presupuesto

    const sql = '''
    SELECT ca.id_card,
           ca.title,
           it.id_item,
           it.amount,
           it.id_itemType,                -- ★
           cat.name       AS cat_name,
           cat.icon_name  AS icon_name
    FROM   card_tb         ca
    LEFT JOIN item_tb      it   ON it.id_card      = ca.id_card
    LEFT JOIN category_tb  cat  ON cat.id_category = it.id_category
    WHERE  ca.id_budget = ?
    ORDER  BY ca.id_card;
  ''';

    final rows = await db.rawQuery(sql, [bid]);

    // Agrupar por tarjeta
    final Map<int, SectionData> tmp = {};
    for (final row in rows) {
      final int idCard = row['id_card'] as int;

      tmp.putIfAbsent(
        idCard,
        () => SectionData(
          idCard: idCard,
          title: row['title'] as String,
          items: [],
        ),
      );

      if (row['id_item'] != null) {
        final iconName = row['icon_name'] as String?;
        tmp[idCard]!.items.add(
          ItemData(
            idItem: row['id_item'] as int,
            name: row['cat_name'] as String,
            amount: (row['amount'] as num).toDouble(),
            typeId: row['id_itemType'] as int? ?? 2, // ★
            iconData: _materialIconByName[iconName] ?? Icons.category,
          ),
        );
      }
    }

    // Refresca UI
    if (rows.isEmpty) return; // <- mantén las secciones por defecto

    setState(() {
      _sections
        ..clear()
        ..addAll(tmp.values);
    });
  }

  // Guarda los cambios en la BD
  Future<void> saveIncremental() async {
    final db = SqliteManager.instance.db;
    final active = context.read<ActiveBudget>();
    final bid = active.idBudget;
    final bName = active.name ?? 'Mi presupuesto';
    final bPeriod = active.idPeriod ?? 2;

    if (bid == null) return;

    await db.transaction((txn) async {
      await txn.insert('budget_tb', {
        'id_budget': bid,
        'name': bName,
        'id_budgetPeriod': bPeriod,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final oldCards = await txn.query(
        'card_tb',
        where: 'id_budget = ?',
        whereArgs: [bid],
      );

      final cardIdsThisBudget = oldCards
          .map((c) => c['id_card'] as int)
          .toList(growable: false);

      final oldItems =
          cardIdsThisBudget.isEmpty
              ? <Map<String, Object?>>[]
              : await txn.query(
                'item_tb',
                where:
                    'id_card IN (${List.filled(cardIdsThisBudget.length, '?').join(',')})',
                whereArgs: cardIdsThisBudget,
              );

      final oldCardIds = oldCards.map((c) => c['id_card'] as int).toSet();
      final oldItemIds = oldItems.map((i) => i['id_item'] as int).toSet();

      for (final sec in _sections) {
        if (sec.idCard == null) {
          sec.idCard = await txn.insert(
            'card_tb',
            CardSql(title: sec.title, idBudget: bid).toMap(),
          );
        } else {
          await txn.update(
            'card_tb',
            {'title': sec.title},
            where: 'id_card = ?',
            whereArgs: [sec.idCard],
          );
          oldCardIds.remove(sec.idCard); // ya procesada
        }

        for (final it in sec.items) {
          it.idCategory ??= await _getCategoryId(txn, it.name);
          if (it.idCategory == null) continue;

          if (it.idItem == null) {
            it.idItem = await txn.insert(
              'item_tb',
              ItemSql(
                idCategory: it.idCategory!,
                idCard: sec.idCard!,
                amount: it.amount,
                itemType: it.typeId,
              ).toMap(),
            );
          } else {
            await txn.update(
              'item_tb',
              {
                'amount': it.amount,
                'id_itemType': it.typeId,
                'id_category': it.idCategory,
              },
              where: 'id_item = ?',
              whereArgs: [it.idItem],
            );
            oldItemIds.remove(it.idItem);
          }
        }
      }

      if (oldCardIds.isNotEmpty) {
        await txn.delete(
          'card_tb',
          where:
              'id_card IN (${List.filled(oldCardIds.length, '?').join(',')})',
          whereArgs: oldCardIds.toList(),
        );
      }
      if (oldItemIds.isNotEmpty) {
        await txn.delete(
          'item_tb',
          where:
              'id_item IN (${List.filled(oldItemIds.length, '?').join(',')})',
          whereArgs: oldItemIds.toList(),
        );
      }
    });

    //Sincroniza con Firestore
    _syncWithFirebaseIncremental(context);
  }

  Future<int> _getCategoryId(DatabaseExecutor dbExec, String name) async {
    // 1) ¿Ya existe?
    final List<Map<String, Object?>> rows = await dbExec.query(
      'category_tb',
      columns: ['id_category'],
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      // Existe → devolvemos su id_category
      return rows.first['id_category'] as int;
    }

    // 2) No existe → insertamos
    return await dbExec.insert('category_tb', {
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _syncWithFirebaseIncremental(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // sesión expirada

    final active = context.read<ActiveBudget>();
    final bid = active.idBudget;
    final bName = active.name ?? 'Mi presupuesto';
    final bPeriod = active.idPeriod ?? 2;

    if (bid == null) return; // aún sin presupuesto

    final fs = FirebaseFirestore.instance;
    final userDoc = fs.collection('users').doc(user.uid);
    final budgetDoc = userDoc.collection('budgets').doc(bid.toString());

    final secColl = budgetDoc.collection('sections');
    final itmColl = budgetDoc.collection('items');

    final remoteSectionIds =
        (await secColl.get()).docs.map((d) => d.id).toSet();
    final remoteItemIds = (await itmColl.get()).docs.map((d) => d.id).toSet();

    WriteBatch batch = fs.batch();
    int opCount = 0;

    Future<void> _commitIfNeeded() async {
      if (opCount >= 400) {
        await batch.commit();
        batch = fs.batch();
        opCount = 0;
      }
    }

    batch.set(budgetDoc, {
      'name': bName,
      'id_budgetPeriod': bPeriod,
    }, SetOptions(merge: true));

    /* 3-a) UPSERT de sections & items */
    for (final sec in _sections) {
      final secId = sec.idCard!.toString();

      batch.set(secColl.doc(secId), {
        'title': sec.title,
      }, SetOptions(merge: true));
      opCount++;
      await _commitIfNeeded();
      remoteSectionIds.remove(secId);

      for (final it in sec.items) {
        final itId = it.idItem!.toString();
        batch.set(itmColl.doc(itId), {
          'idCard': sec.idCard,
          'idCategory': it.idCategory,
          'name': it.name,
          'amount': it.amount,
          'idItemType': it.typeId,
        }, SetOptions(merge: true));
        opCount++;
        await _commitIfNeeded();
        remoteItemIds.remove(itId);
      }
    }

    for (final orphanSec in remoteSectionIds) {
      batch.delete(secColl.doc(orphanSec));
      opCount++;
      await _commitIfNeeded();
    }
    for (final orphanItem in remoteItemIds) {
      batch.delete(itmColl.doc(orphanItem));
      opCount++;
      await _commitIfNeeded();
    }

    if (opCount > 0) await batch.commit();
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
      saveIncremental();
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
                children: [
                  if (!_isFixed(section))
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: Text(
                                  'Confirmar eliminación',
                                  style: theme.typography.titleLarge,
                                  textAlign: TextAlign.center,
                                ),
                                content: Text(
                                  '¿Estás seguro de que deseas\n eliminar esta tarjeta?',
                                  style: theme.typography.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                actions: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      textStyle: theme.typography.bodySmall,
                                    ),
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: Text('No'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      textStyle: theme.typography.bodySmall,
                                    ),
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    child: const Text('Sí, borrar'),
                                  ),
                                ],
                              ),
                        );

                        if (confirm == true) {
                          setState(() => _sections.removeAt(sectionIndex));
                          saveIncremental();
                        }
                      },
                      child: Text(
                        ' - Eliminar tarjeta',
                        style: theme.typography.bodyMedium.override(
                          fontSize: 14,
                          color: const Color.fromARGB(255, 244, 67, 54),
                        ),
                      ),
                    ),
                  const Spacer(),
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

    bool _isDuplicate(String candidate) {
      return _sections.any(
        (s) => s.title.toLowerCase() == candidate.toLowerCase() && s != section,
      );
    }

    // Tarjetas fijas
    if (_isFixed(section)) {
      return Center(
        child: Text(
          section.title,
          style: theme.typography.titleMedium.override(
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Si no estamos editando, mostramos el título como antes
    if (!section.isEditingTitle) {
      return GestureDetector(
        onTap: () => setState(() => section.isEditingTitle = true),
        child: Center(
          child: Text(
            section.title,
            style: theme.typography.titleMedium.override(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // EditableTitle con validación de duplicados
    return _EditableTitle(
      initialText: section.title,
      onSubmitted: (newValue) {
        // si el nombre ya existe en otra tarjeta...
        if (_isDuplicate(newValue)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Esta tarjeta ya existe'),
              backgroundColor: Colors.redAccent,
            ),
          );
          // NO cerramos el editor ni cambiamos nada
          return;
        }
        // en otro caso, aplicamos el cambio
        setState(() {
          section.title = newValue;
          section.isEditingTitle = false;
        });
        saveIncremental();
      },
      onCancel: () {
        setState(() => section.isEditingTitle = false);
        saveIncremental();
      },
    );
  }

  Widget _buildItem(int sectionIndex, int itemIndex) {
    final theme = FlutterFlowTheme.of(context);
    final item = _sections[sectionIndex].items[itemIndex];

    return Slidable(
      key: ValueKey('${sectionIndex}_$itemIndex'),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.40,
        children: [
          SlidableAction(
            onPressed: (ctx) => _confirmDeleteItem(sectionIndex, itemIndex),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
          ),
        ],
      ),

      child: GestureDetector(
        onTap: () => _showAddItemDialog(sectionIndex, existingIndex: itemIndex),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              // ↧ tendrá exactamente el ancho de su contenido,
              //    pero sin exceder 120 px por si el número es muy largo
              constraints: const BoxConstraints(maxWidth: 140),
              decoration: BoxDecoration(
                color: const Color.fromARGB(56, 117, 117, 117),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IntrinsicWidth(
                // ⬅️ ajusta al ancho del texto
                child: AmountEditor(
                  key: ValueKey(item.amount),
                  initialValue: item.amount,
                  onValueChanged: (v) {
                    item.amount = v;
                    saveIncremental();
                  },
                  currencySymbol: _currency,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog(int sectionIndex, {int? existingIndex}) {
    final theme = FlutterFlowTheme.of(context);

    final isEditing = existingIndex != null;
    final ItemData? ex =
        isEditing ? _sections[sectionIndex].items[existingIndex] : null;

    final nameCtrl = TextEditingController(text: ex?.name ?? '');
    final amtCtrl = TextEditingController(text: (ex?.amount ?? 0).toString());
    IconData? pickedIcon = ex?.iconData;
    int typeId = ex?.typeId ?? 2;

    //   CATEGORIAS EXCLUIDAS
    final Set<String> excludeNames =
        _sections.expand((s) => s.items).map((it) => it.name).toSet();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setStateSB) => AlertDialog(
                  backgroundColor: theme.primaryBackground,
                  title: Text(
                    'Agregar item',
                    textAlign: TextAlign.center,
                    style: theme.typography.titleLarge,
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      //  categoría
                      InkWell(
                        onTap: () async {
                          _sections[sectionIndex].items
                              .map((it) => it.name)
                              .toSet();

                          final res = await _showCategoryDialog(
                            _sections[sectionIndex].title,
                            excludeNames: excludeNames,
                          );
                          if (res != null) {
                            nameCtrl.text = res['name'];
                            pickedIcon = res['icon'] as IconData?;
                          }
                        },
                        child: _CategoryTextField(
                          controller: nameCtrl,
                          hint: 'Categoría',
                        ),
                      ),
                      const SizedBox(height: 12),
                      //  monto
                      _BlueTextField(
                        controller: amtCtrl,
                        labelText: 'Monto',
                        prefixText: _currency,
                      ),
                      const SizedBox(height: 12),
                      //  selector tipo
                      Row(
                        children: List.generate(2, (ix) {
                          final bool selected =
                              (ix == 0 && typeId == 1) ||
                              (ix == 1 && typeId == 2);
                          return Expanded(
                            child: GestureDetector(
                              onTap:
                                  () => setStateSB(
                                    () => typeId = ix == 0 ? 1 : 2,
                                  ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve:
                                    Curves
                                        .easeInOut, // animacion de transición suave
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      selected
                                          ? theme.primary
                                          : theme.secondaryBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow:
                                      selected
                                          ? [
                                            BoxShadow(
                                              // sutil glow al pasar
                                              color: theme.primary.withOpacity(
                                                0.35,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                          : null,
                                ),
                                child: Center(
                                  child: Text(
                                    ix == 0 ? 'Monto fijo' : 'Monto variable',
                                    style: theme.typography.bodyMedium.override(
                                      color:
                                          selected
                                              ? Colors.white
                                              : theme.primaryText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.primary,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancelar',
                        style: theme.typography.bodyMedium.override(
                          color: theme.primary,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                      ),
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        final raw = amtCtrl.text.replaceAll(
                          RegExp(r'[,\$]'),
                          '',
                        );
                        final amt = double.tryParse(raw) ?? 0.0;
                        if (name.isEmpty) return;

                        setState(() {
                          if (isEditing) {
                            /* ACTUALIZA */
                            final item =
                                _sections[sectionIndex].items[existingIndex];
                            item
                              ..name = name
                              ..amount = amt
                              ..typeId = typeId
                              ..iconData = pickedIcon
                              ..idCategory = null;
                          } else {
                            /* CREA */
                            _sections[sectionIndex].items.add(
                              ItemData(
                                name: name,
                                amount: amt,
                                typeId: typeId,
                                iconData: pickedIcon,
                              ),
                            );
                          }
                        });

                        saveIncremental(); //  SQLite + Firebase
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        'Aceptar',
                        style: theme.typography.bodyMedium.override(
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
          ),
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
          title: Text(
            'Confirmar eliminación',
            style: theme.typography.titleLarge,
            textAlign: TextAlign.center,
          ),
          content: Text(
            '¿Estás seguro/a que quieres borrar la categoría "${item.name}"?',
            style: theme.typography.bodyMedium,
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle: theme.typography.bodyMedium,
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                textStyle: theme.typography.bodyMedium,
              ),
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
      saveIncremental();
    }
  }

  Widget _buildCreateNewSectionButton(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                _sections.add(
                  SectionData(
                    title: 'Nueva Tarjeta',
                    items: [
                      ItemData(
                        name: 'Entretenimiento',
                        amount: 0.0,
                        iconData: Icons.movie,
                        typeId: 2,
                      ),
                    ],
                  ),
                );
              });
              saveIncremental();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Crear tarjeta personalizable',
              style: theme.typography.bodyMedium.override(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),

          const SizedBox(height: 10),

          _buildAiAdjustBudgetButton(context),
        ],
      ),
    );
  }

  Widget _buildAiAdjustBudgetButton(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return ElevatedButton(
      onPressed: () async {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        try {
          // ── 1) total ingresos ───────────────────────────────
          final ingresosSection = _sections.firstWhere(
            (s) => s.idCard == 1,
            orElse: () => SectionData(title: '', items: []),
          );
          final totalIngresos = ingresosSection.items.fold<double>(
            0.0,
            (sum, it) => sum + it.amount,
          );

          // ── 2) llamada al motor ─────────────────────────────
          final items = await BudgetEngine.instance.recalculate(
            totalIngresos,
            context,
          );

          if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

          // ── 3) pantalla de revisión ─────────────────────────
          final updated = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => ReviewScreen(items: items)),
          );

          if (updated == true && context.mounted) {
            await _loadData();
            setState(() {});
          }
        } catch (e, st) {
          if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

          // Log completo en debug ─────────────────────────────
          if (kDebugMode) {
            print(' BudgetEngine error: $e');
            print(st);
          }

          // Aviso al usuario con la causa real en producción
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Ocurrió un error: $e')));
          }
        }
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color.fromARGB(255, 213, 253, 14),
              Color.fromARGB(255, 217, 255, 81),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          alignment: Alignment.center,
          child: Text(
            'Ajustar presupuesto con IA',
            style: theme.typography.bodyMedium.override(
              color: const Color.fromARGB(255, 45, 45, 45),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showCategoryDialog(
    String sectionTitle, {
    Set<String> excludeNames =
        const {}, // Categorias excluidas para evitar repeticiones
  }) async {
    final theme = FlutterFlowTheme.of(context);
    final categories = await _getCategoriesForSection(
      sectionTitle,
      excludeNames: excludeNames,
    );
    final mediaWidth = MediaQuery.of(context).size.width;
    final movementId = _movementIdForSection(sectionTitle);

    // Define degradados y colores de fondo según movementId
    final List<Color> headerGradient =
        movementId == 1
            ? [Colors.red.shade700, Colors.red.shade400]
            : movementId == 2
            ? [Colors.green.shade700, Colors.green.shade400]
            : movementId == 3
            ? [Color(0xFF132487), Color(0xFF1C3770)]
            : [
              Color.fromARGB(255, 138, 222, 3),
              Color.fromARGB(255, 211, 211, 211),
            ];

    final Color avatarBgColor =
        movementId == 1
            ? Colors.red.withOpacity(0.2)
            : movementId == 2
            ? Colors.green.withOpacity(0.2)
            : movementId == 3
            ? theme.accent1
            : Colors.blueGrey;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            backgroundColor: theme.primaryBackground,

            titlePadding: EdgeInsets.zero,
            title: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Text(
                'Seleccionar Categoría',
                textAlign: TextAlign.center,
                style: theme.typography.titleLarge.override(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            content: SizedBox(
              width: (mediaWidth.clamp(0, 430)) * .75,
              height: 500,
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 15),
                      itemCount: (categories.length / 3).ceil(),
                      itemBuilder: (_, rowIndex) {
                        final start = rowIndex * 3;
                        final end = (start + 3).clamp(0, categories.length);
                        final rowCats = categories.sublist(start, end);

                        return Column(
                          children: [
                            // Filas de máximo 3 categorías
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  rowCats.map((cat) {
                                    return GestureDetector(
                                      onTap:
                                          () => Navigator.of(context).pop(cat),
                                      child: SizedBox(
                                        width: (mediaWidth.clamp(0, 430)) * .20,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: avatarBgColor,
                                              child: Icon(
                                                cat['icon'] as IconData,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            AutoSizeText(
                                              cat['name'] as String,
                                              textAlign: TextAlign.center,
                                              style: theme.typography.bodySmall,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              minFontSize: 8,
                                              stepGranularity: 1,
                                              wrapWords: false,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),

                            // Separando filas con dividers excepto la ultima fila
                            if (rowIndex <
                                (categories.length / 3).ceil() - 1) ...[
                              const SizedBox(height: 12),
                              Divider(color: theme.secondaryText, thickness: 1),
                              const SizedBox(height: 12),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // El titulo se explica solo
  int _movementIdForSection(String title) {
    switch (title) {
      case 'Gastos':
        return 1;
      case 'Ingresos':
        return 2;
      case 'Ahorros':
        return 3;
      default: // tarjetas personalizadas trae todo
        return 0;
    }
  }

  /// Lee categorías : las del movimiento  (Ingresos/Gastos/Ahorros)
  Future<List<Map<String, dynamic>>> _getCategoriesForSection(
    String sectionTitle, {
    Set<String> excludeNames =
        const {}, // Para no repetir las que ya se encuentran en alguna tarjeta
  }) async {
    final db = SqliteManager.instance.db;
    final movementId = _movementIdForSection(sectionTitle);

    final rows = await db.rawQuery(
      movementId == 0
          ? 'SELECT name, icon_name FROM category_tb'
          : 'SELECT name, icon_name FROM category_tb WHERE id_movement = ?',
      movementId == 0 ? [] : [movementId],
    );

    final filtered = rows.where(
      (r) => !excludeNames.contains(r['name'] as String),
    );

    return filtered.map((r) {
      final iconName = r['icon_name'] as String?;
      return {
        'name': r['name'] as String,
        'icon': _materialIconByName[iconName] ?? Icons.category,
      };
    }).toList();
  }
}
