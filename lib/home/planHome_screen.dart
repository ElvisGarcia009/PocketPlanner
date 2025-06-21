import 'package:Pocket_Planner/database/sqlite_management.dart';
import 'package:Pocket_Planner/functions/active_budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:Pocket_Planner/flutterflow_components/flutterflowtheme.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

/// Modelo para cada ítem dentro de la sección

class ItemSql {
  final int? idItem;
  final int idCategory;
  final int idCard;
  final double amount;

  const ItemSql({
    this.idItem,
    required this.idCategory,
    required this.idCard,
    required this.amount,
  });

  factory ItemSql.fromRow(Map<String, Object?> r) => ItemSql(
        idItem:     r['id_item']      as int?,
        idCategory: r['id_category']  as int,
        idCard:     r['id_card']      as int,
        amount:     (r['amount'] as num).toDouble(),
      );

  Map<String, Object?> toMap() => {
        if (idItem != null) 'id_item': idItem,
        'id_category': idCategory,
        'id_card': idCard,
        'amount': amount,
        'date_crea': DateTime.now().toIso8601String(),
        'id_priority': 1,
        'id_itemType': 1,
      };
}

class CardSql {
  final int? idCard;
  final String title;
  final int idBudget;                      // ← NUEVO

  const CardSql({
    this.idCard,
    required this.title,
    required this.idBudget,
  });

  Map<String, Object?> toMap() => {
        if (idCard != null) 'id_card' : idCard,
        'title'     : title,
        'id_budget' : idBudget,            // ← ya no es “1”
        'date_crea' : DateTime.now().toIso8601String(),
      };
}



class ItemData {
  int? idItem;                
  int? idCategory; 
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
  int? idCard; 
  String title;
  bool isEditingTitle;
  List<ItemData> items;

  SectionData({
    this.idCard,                            // ← NUEVO parámetro
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

  // ── Tarjetas cuyo título no debe poder editarse ni eliminarse ─────────
static const Set<String> _fixedTitles = {'Ingresos', 'Gastos', 'Ahorros'};

bool _isFixed(SectionData s) => _fixedTitles.contains(s.title);


  final GlobalKey _globalKey = GlobalKey();

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


 Future<void> _loadData() async {
  final db        = SqliteManager.instance.db;
  final int? bid  = Provider.of<ActiveBudget>(context, listen: false).idBudget;

  if (bid == null) return;                // aún no se ha fijado presupuesto

  const sql = '''
    SELECT ca.id_card, ca.title,
           it.id_item, it.amount,
           cat.name      AS cat_name,
           cat.icon_code
    FROM   card_tb ca
    LEFT JOIN item_tb    it   ON it.id_card = ca.id_card
    LEFT JOIN category_tb cat ON cat.id_category = it.id_category
    WHERE  ca.id_budget = ?                       
    ORDER BY ca.id_card;
  ''';

  final rows = await db.rawQuery(sql, [bid]);

  // 2) Agrupar por tarjeta
  final Map<int, SectionData> tmp = {};
  for (final row in rows) {
    final idCard = row['id_card'] as int;
    tmp.putIfAbsent(
      idCard,
      () => SectionData(idCard : idCard, title: row['title'] as String, items: []),
    );

    // si la tarjeta aún no tiene ítems, row['id_item'] será null
    if (row['id_item'] != null) {
      tmp[idCard]!.items.add(
        ItemData(
          name: row['cat_name'] as String,
          amount: (row['amount'] as num).toDouble(),
          iconData: IconData(
            row['icon_code'] as int,
            fontFamily: 'MaterialIcons',
          ),
        ),
      );
    }
  }

  setState(() {
    _sections
      ..clear()
      ..addAll(tmp.values);
  });
}


Future<void> saveIncremental() async {
  final db   = SqliteManager.instance.db;
  final int? bid = Provider.of<ActiveBudget>(context, listen: false).idBudget;
  if (bid == null) return;

  await db.transaction((txn) async {
    /* ───────── 1) Snapshot SOLO del presupuesto activo ───────── */
    final oldCards = await txn.query(
      'card_tb',
      where: 'id_budget = ?',
      whereArgs: [bid],
    );

    // obtén los id_card que pertenecen a este presupuesto
    final cardIdsThisBudget =
        oldCards.map((c) => c['id_card'] as int).toList(growable: false);

    final oldItems = cardIdsThisBudget.isEmpty
        ? <Map<String, Object?>>[]
        : await txn.query(
            'item_tb',
            where:
                'id_card IN (${List.filled(cardIdsThisBudget.length, '?').join(',')})',
            whereArgs: cardIdsThisBudget,
          );

    final oldCardIds = oldCards.map((c) => c['id_card'] as int).toSet();
    final oldItemIds = oldItems.map((i) => i['id_item'] as int).toSet();

    /* ───────── 2) Recorre las secciones mostradas en pantalla ─── */
    for (final sec in _sections) {
      // 2-a) tarjeta (UPSERT)
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
        oldCardIds.remove(sec.idCard);                // ya procesada
      }

      // 2-b) ítems (UPSERT)
      for (final it in sec.items) {
        it.idCategory ??= await _getCategoryId(txn, it.name);
        if (it.idCategory == null) continue;

        if (it.idItem == null) {
          it.idItem = await txn.insert(
            'item_tb',
            ItemSql(
              idCard: sec.idCard!,
              idCategory: it.idCategory!,
              amount: it.amount,
            ).toMap(),
          );
        } else {
          await txn.update(
            'item_tb',
            {'amount': it.amount},
            where: 'id_item = ?',
            whereArgs: [it.idItem],
          );
          oldItemIds.remove(it.idItem);               // ya procesado
        }
      }
    }

    /* ───────── 3) Borra lo que sobró en ESTE presupuesto ─────── */
    if (oldCardIds.isNotEmpty) {
      await txn.delete(
        'card_tb',
        where: 'id_card IN (${List.filled(oldCardIds.length, '?').join(',')})',
        whereArgs: oldCardIds.toList(),
      );
    }
    if (oldItemIds.isNotEmpty) {
      await txn.delete(
        'item_tb',
        where: 'id_item IN (${List.filled(oldItemIds.length, '?').join(',')})',
        whereArgs: oldItemIds.toList(),
      );
    }
  });

  // 4) Sincroniza con Firestore (sigue igual)
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
  return await dbExec.insert(
    'category_tb',
    {'name': name},
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );
}



Future<void> _syncWithFirebaseIncremental(BuildContext context) async {
  /* ───────────── 0. Seguridad ───────────── */
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;                              // sesión expirada

  final int? bid = Provider.of<ActiveBudget>(context, listen: false).idBudget;
  if (bid == null) return;                               // aún sin presupuesto

  /* ───────────── 1. Referencias ─────────── */
  final fs        = FirebaseFirestore.instance;
  final userDoc   = fs.collection('users').doc(user.uid);
  final budgetDoc = userDoc.collection('budgets').doc(bid.toString());

  final secColl = budgetDoc.collection('sections');
  final itmColl = budgetDoc.collection('items');

  /* ───────────── 2. Snapshot remoto ─────── */
  final remoteSectionIds = (await secColl.get()).docs.map((d) => d.id).toSet();
  final remoteItemIds    = (await itmColl.get()).docs.map((d) => d.id).toSet();

  /* ───────────── 3. Lote incremental ────── */
  WriteBatch batch = fs.batch();
  int opCount = 0;

  Future<void> _commitIfNeeded() async {
    if (opCount >= 400) {
      await batch.commit();
      batch = fs.batch();
      opCount = 0;
    }
  }

  /* 3-a) UPSERT de sections & items */
  for (final sec in _sections) {
    final secId = sec.idCard!.toString();

    batch.set(
      secColl.doc(secId),
      { 'title': sec.title },
      SetOptions(merge: true),
    ); opCount++; await _commitIfNeeded();
    remoteSectionIds.remove(secId);

    for (final it in sec.items) {
      final itId = it.idItem!.toString();
      batch.set(
        itmColl.doc(itId),
        {
          'idCard'    : sec.idCard,
          'idCategory': it.idCategory,
          'name'      : it.name,
          'amount'    : it.amount,
        },
        SetOptions(merge: true),
      ); opCount++; await _commitIfNeeded();
      remoteItemIds.remove(itId);
    }
  }

  /* ───────────── 4. Eliminaciones remoto ─── */
  for (final orphanSec in remoteSectionIds) {
    batch.delete(secColl.doc(orphanSec)); opCount++; await _commitIfNeeded();
  }
  for (final orphanItem in remoteItemIds) {
    batch.delete(itmColl.doc(orphanItem)); opCount++; await _commitIfNeeded();
  }

  /* ───────────── 5. Commit final ─────────── */
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_isFixed(section))               // ← NUEVA CONDICIÓN
                  GestureDetector(
                    onTap: () {
                      setState(() => _sections.removeAt(sectionIndex));
                      saveIncremental();
                    },
                    child: Text(
                      ' - Eliminar tarjeta',
                      style: theme.typography.bodyMedium.override(
                        fontSize: 14,
                        color: const Color.fromARGB(255, 244, 67, 54),
                      ),
                    ),
                  ),
                GestureDetector(                      // (Agregar +) queda igual
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

  // ①  Si es una tarjeta “fija”, sólo la mostramos
  if (_isFixed(section)) {
    return Center(
      child: Text(
        section.title,
        style: theme.typography.titleMedium
            .override(fontWeight: FontWeight.bold),
      ),
    );
  }

  // ②  Resto igual (editable)
  if (!section.isEditingTitle) {
    return GestureDetector(
      onTap: () => setState(() => section.isEditingTitle = true),
      child: Center(
        child: Text(
          section.title,
          style: theme.typography.titleMedium
              .override(fontWeight: FontWeight.bold),
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
        saveIncremental();
      },
      onCancel: () {
        setState(() => section.isEditingTitle = false);
        saveIncremental();
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
                  saveIncremental();
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
                  saveIncremental();
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
      saveIncremental();
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
            title: 'Nueva Tarjeta',
             items: [
              ItemData(
                name: 'Entretenimiento',
                amount: 0.0,
                // ⬇⬇⬇ antes: iconData: Icons.movie,
                iconData: IconData(58383, fontFamily: 'MaterialIcons'),
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

  // 3️⃣  Diálogo para escoger categoría
Future<Map<String, dynamic>?> _showCategoryDialog(
    String sectionTitle) async {
  final theme = FlutterFlowTheme.of(context);
  final categories = await _getCategoriesForSection(sectionTitle);

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: theme.primaryBackground,
      title: const Text('Seleccionar Categoría',
          textAlign: TextAlign.center),
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
                      backgroundColor: theme.accent1,
                      child: Icon(cat['icon'] as IconData,
                          color: theme.primary, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(cat['name'] as String,
                        textAlign: TextAlign.center,
                        style: theme.typography.bodySmall),
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
    ),
  );
}


  // 1️⃣  Utilidad: de nombre de sección → id_movement de la BD
int _movementIdForSection(String title) {
  switch (title) {
    case 'Gastos':
      return 1;
    case 'Ingresos':
      return 2;
    case 'Ahorros':
      return 3;
    default:                // tarjetas personalizadas → trae todo
      return 0;
  }
}

/// 2️⃣  Lee categorías + icon_code desde SQLite
Future<List<Map<String, dynamic>>> _getCategoriesForSection(
    String sectionTitle) async {
  final db = SqliteManager.instance.db;

  final movementId = _movementIdForSection(sectionTitle);

  final rows = await db.rawQuery(
    movementId == 0
        ? 'SELECT name, icon_code FROM category_tb'
        : 'SELECT name, icon_code FROM category_tb WHERE id_movement = ?',
    movementId == 0 ? [] : [movementId],
  );

  return rows
      .map((r) => {
            'name': r['name'] as String,
            'icon': IconData(r['icon_code'] as int,
                fontFamily: 'MaterialIcons'),
          })
      .toList();
}

}
