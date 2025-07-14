import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketplanner/BudgetAI/optimization.dart';
import 'package:pocketplanner/database/sqlite_management.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({Key? key}) : super(key: key);

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Future<List<ItemUi>> _futureRecs;
  List<ItemUi>? _items;

  @override
  void initState() {
    super.initState();
    _showIntroIfNeeded();
    _futureRecs = _runPipeline();
  }

  Future<void> _showIntroIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('review_screen_intro') ?? false;
              final theme = FlutterFlowTheme.of(context);

    if (!shown) {
      // Espera a que build() haya renderizado
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Center(child: const Text('Instrucciones')),
            content: const Text(
              'Aquí verás tus items con:\n'
              '- Presupuesto actual\n'
              '- Total gastado\n'
              '- Predicción de IA\n\n'
              'Puedes deslizar a la derecha para eliminar sugerencias no deseadas, '
              'o tocar "Aceptar cambios" para guardar las recomendaciones.\n\n'
              'Para uso óptimo, debes tener tus items con presupuestos'
              'y transacciones de dichos items para analizar tus patrones.\n\n'
              ''
              'OJO: La IA NO toca tus items con monto fijo, solo los variables.',
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
      await prefs.setBool('review_screen_intro', true);
    }
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }

  Future<List<ItemUi>> _runPipeline() async {
    final connected = await _checkInternet();
    if (!connected) {
      throw Exception('Debes tener conexión a internet.');
    }
    // 1) Total de ingresos desde la tarjeta "Ingresos"
    final db = SqliteManager.instance.db;
    final rows = await db.rawQuery(
      'SELECT SUM(amount) AS total '
      'FROM item_tb JOIN card_tb USING(id_card) '
      'WHERE card_tb.title = ?',
      ['Ingresos'],
    );
    final income = (rows.first['total'] as num?)?.toDouble() ?? 0.0;

    // 2) Llama al optimizador
    final recs = await Optimization.instance.recalculate(income, context);
    _items = recs;
    return recs;
  }

  Future<void> _onAccept() async {
    if (_items == null) return;
    await persist(_items!, context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Presupuestos guardados correctamente')),
    );
    Navigator.of(context).pop(true);
  }

  void _onCancel() {
    Navigator.of(context).pop(false);
  }

  String _fmt(double v) {
    final f = NumberFormat.simpleCurrency(
      locale: Localizations.localeOf(context).toString(),
    );
    return f.format(v);
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presupuesto sugerido'),
        centerTitle: true,
        titleTextStyle: theme.textTheme.titleLarge,
      ),
      body: FutureBuilder<List<ItemUi>>(
        future: _futureRecs,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final msg = snap.error.toString();
            return Center(
              child: Text(
                msg.contains('Debes tener conexión')
                  ? msg
                  : 'Error: $msg',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            );
          }
          final recos = _items ?? [];
          if (recos.isEmpty) {
            return const Center(child: Text('No hay datos disponibles para ajustar.'));
          }
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: recos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = recos[i];
                    final diff = r.newPlan - r.oldPlan;
                    final diffColor = diff > 0
                      ? Colors.green
                      : (diff < 0 ? Colors.red : Colors.grey);
                    final diffSign = diff > 0 ? '+' : (diff < 0 ? '-' : '');
                    return Dismissible(
                      key: ValueKey(r.idCat),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        color: Colors.redAccent,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => setState(() => recos.removeAt(i)),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.catName, style: theme.textTheme.titleLarge),
                              const SizedBox(height: 12),
                              _infoRow('Presupuesto actual', _fmt(r.oldPlan)),
                              _infoRow('Total gastado', _fmt(r.spent)),
                              _infoRow('Predicción IA', _fmt(r.aiPlan)),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Nuevo presupuesto',
                                      style: theme.textTheme.titleMedium),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(_fmt(r.newPlan),
                                          style: theme.textTheme.headlineSmall),
                                      Text(
                                        diff == 0
                                            ? 'Sin cambio'
                                            : '$diffSign${_fmt(diff.abs())}',
                                        style: theme.textTheme
                                            .bodySmall
                                            ?.copyWith(color: diffColor),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _onCancel,
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _onAccept,
                      child: const Text('Aceptar cambios'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
