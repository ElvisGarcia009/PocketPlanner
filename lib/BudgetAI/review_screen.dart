import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  // tabla con edicion rápida
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
          title: Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
            ), // 8 px de espacio inferior
            child: Text(
              '${it.catName}',
              style: theme.typography.titleLarge.override(
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          subtitle: Text(
            'Plan anterior: $_currency${_fmt(it.oldPlan)}\n'
            'Gastado:          $_currency${_fmt(it.spent)}',
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
                  '$_currency${_fmt(it.newPlan)}',
                  style: theme.typography.bodyMedium.override(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                  ),
                ),
                // diff
                Text(
                  diff == 0
                      ? '0.00'
                      : (diff > 0 ? '+${_fmt(diff)}' : '-${_fmt(diff.abs())}'),
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
    final formatter = NumberFormat('#,##0.##');
    final ctrl = TextEditingController(text: _fmt(it.newPlan));
    final _currency = context.read<ActualCurrency>().cached;
    final theme = FlutterFlowTheme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              'Editar propuesta',
              style: theme.typography.titleLarge,
              textAlign: TextAlign.center,
            ),
            content: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monto',
                prefix: Text(_currency),
                labelStyle: theme.typography.bodySmall.override(
                  color: theme.secondaryText,
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              style: theme.typography.bodyLarge,
              onChanged: (val) {
                String raw = val.replaceAll(',', '');
                if (raw.contains('.')) {
                  final dotIndex = raw.indexOf('.');
                  final decimals = raw.length - dotIndex - 1;
                  if (decimals > 2) raw = raw.substring(0, dotIndex + 3);
                  if (raw == '.') raw = '0.';
                }

                double number = double.tryParse(raw) ?? 0.0;

                if (raw.endsWith('.') || RegExp(r'^\d+\.\d?$').hasMatch(raw)) {
                  final parts = raw.split('.');
                  final intPart = double.tryParse(parts[0]) ?? 0.0;
                  final formattedInt = formatter.format(intPart).split('.')[0];
                  final partialDecimal = parts.length > 1 ? '.' + parts[1] : '';
                  final newString = '$formattedInt$partialDecimal';
                  ctrl.value = TextEditingValue(
                    text: newString,
                    selection: TextSelection.collapsed(
                      offset: newString.length,
                    ),
                  );
                } else {
                  final formatted = formatter.format(number);
                  ctrl.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                }
              },
            ),

            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  textStyle: theme.typography.bodyMedium,
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
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
                double.tryParse(
                  ctrl.text.replaceAll(',', '').replaceAll(_currency, ''),
                ) ??
                it.newPlan,
      );
    }
  }

  // FEEDBACK DEL USUARIO
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

  String _fmt(double v) => NumberFormat('#,##0.00', 'en_US').format(v);
}
