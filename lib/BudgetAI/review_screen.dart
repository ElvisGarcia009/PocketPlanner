import 'package:flutter/material.dart';
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';
import 'package:pocketplanner/services/actual_currency.dart';
import 'package:provider/provider.dart';
import '../BudgetAI/budget_engine.dart';

class ReviewScreen extends StatefulWidget {
  final List<ItemUi> items;
  const ReviewScreen({super.key, required this.items});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Revisión del presupuesto',
          style: theme.typography.titleLarge,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(child: _buildTable()),
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                _saving
                    ? const CircularProgressIndicator()
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: _onCancel, //  feedback
                          child: Text(
                            'Cancelar',
                            style: theme.typography.bodyLarge.override(
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          onPressed: _onAccept,
                          child: Text(
                            'Aceptar ajustes',
                            style: theme.typography.bodyLarge.override(
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  // ───────────────── tabla con edición rápida ────────────────
  Widget _buildTable() {
    final theme = FlutterFlowTheme.of(context);
    final _currency = context.read<ActualCurrency>().cached;


    return ListView.separated(
      itemCount: widget.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final it = widget.items[i];
        final diff = it.newPlan - it.oldPlan;
        return ListTile(
          title: Text(
            '${it.catName}',
            style: theme.typography.titleLarge.override(
              fontFamily: 'Montserrat',
            ),
          ),
          subtitle: Text(
            'Plan anterior: $_currency${it.oldPlan.toStringAsFixed(2)}\n'
            'Gastado:          $_currency${it.spent.toStringAsFixed(2)}',
            style: theme.typography.bodyMedium.override(
              fontFamily: 'Montserrat',
            ),
          ),
          trailing: GestureDetector(
            onTap: () => _editAmount(it),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_currency${it.newPlan.toStringAsFixed(2)}',
                  style: theme.typography.bodyMedium.override(
                    fontFamily: 'Montserrat',
                  ),
                ),
                Text(
                  diff >= 0
                      ? '+${diff.toStringAsFixed(2)}'
                      : diff.toStringAsFixed(2),
                  style: TextStyle(
                    color: diff >= 0 ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editAmount(ItemUi it) async {
    final ctrl = TextEditingController(text: it.newPlan.toStringAsFixed(2));
    final _currency = context.read<ActualCurrency>().cached;
    final theme = FlutterFlowTheme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              'Editar monto',
              style: theme.typography.titleLarge,
              textAlign: TextAlign.center,
            ),
            content: TextField(
              style: theme.typography.bodyLarge,
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(prefixText: _currency),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // fondo
                  foregroundColor: Colors.white, // texto / iconos ⇒ ¡blanco!
                  textStyle: theme.typography.bodyMedium,
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // fondo
                  foregroundColor: Colors.white, // texto / iconos ⇒ ¡blanco!
                  textStyle: theme.typography.bodyMedium,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
    if (ok ?? false) {
      setState(
        () =>
            it.newPlan =
                double.tryParse(ctrl.text.replaceAll(',', '.')) ?? it.newPlan,
      );
    }
  }

  // ────────────────────────── FEEDBACK ─────────────────────────
  Future<void> _onAccept() async {
    setState(() => _saving = true);
    await BudgetEngine.instance.persist(widget.items, context);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true); //  TRUE = hubo cambios
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Presupuesto actualizado')));
    }
  }

  Future<void> _onCancel() async {
    await BudgetEngine.instance.persist(widget.items, context);
    if (mounted) Navigator.pop(context, false); // FALSE = sin cambios
  }
}
