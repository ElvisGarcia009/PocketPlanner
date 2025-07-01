// lib/ui/review_screen.dart
import 'package:Pocket_Planner/BudgetAI/budget_engine.dart';
import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Revisión del presupuesto')),
      body: Column(
        children: [
          Expanded(child: _buildTable()),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _saving
                ? const CircularProgressIndicator()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: _onAccept,
                        child: const Text('Aceptar ajustes'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return ListView.separated(
      itemCount: widget.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final it = widget.items[i];
        final diff = it.newPlan - it.oldPlan;
        return ListTile(
          title: Text('Item ${it.idItem}  •  Cat ${it.idCat}'),
          subtitle: Text('Plan anterior: \$${it.oldPlan.toStringAsFixed(2)}\n'
              'Gastado:        \$${it.spent.toStringAsFixed(2)}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('\$${it.newPlan.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                diff >= 0 ? '+${diff.toStringAsFixed(2)}' : diff.toStringAsFixed(2),
                style: TextStyle(
                    color: diff >= 0 ? Colors.green : Colors.red,
                    fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onAccept() async {
    setState(() => _saving = true);
    await BudgetEngine.instance.persist(widget.items);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context)
        ..pop()                           // cierra ReviewScreen
        ..pop();                          // cierra spinner de la pantalla previa
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presupuesto actualizado')),
      );
    }
  }
}
