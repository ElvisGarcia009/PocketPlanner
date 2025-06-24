// lib/budgetAI/budget_ai_service.dart
//
// Servicio central para ajustar presupuestos con IA
//
// AÑADE en pubspec.yaml (ya las tienes):
//   tflite_flutter: ^0.9.0         # ejecución del modelo
//   shared_preferences: ^2.2.2     # almacenamiento local
//
// AÑADE en pubspec.yaml -> assets:
//   - assets/models/budget_adjuster.tflite
//
// -----------------------------------------------------------

/*

import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
//import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:Pocket_Planner/home/remainingHome_screen.dart';
import 'package:Pocket_Planner/functions/active_budget.dart';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';

/// Resultado interpretado del modelo.
///
/// Ejemplo:
/// ```json
/// {
///   "Ingresos": {
///     "Salario": 22000.0
///   },
///   "Gastos": {
///     "Transporte": 3900.0,
///     "Comida": 3100.0
///   },
///   "Ahorros": {
///     "Ahorros": 4000.0
///   }
/// }
/// ```
typedef BudgetJson = Map<String, Map<String, double>>;

class BudgetAIService {
  BudgetAIService._internal();

  static final BudgetAIService instance = BudgetAIService._internal();

  /// Ajusta el presupuesto activo y devuelve el JSON con las propuestas.
  ///
  /// * Carga los datos de SQLite.
  /// * Invoca el modelo.
  /// * Almacena la respuesta en `SharedPreferences` bajo la clave
  ///   `ai_adjustment_<idBudget>`.
  Future<BudgetJson> adjustCurrentBudget(BuildContext context) async {
    // 1️⃣  Id de presupuesto activo
    final int? idBudget =
        Provider.of<ActiveBudget>(context, listen: false).idBudget;
    if (idBudget == null) {
      throw StateError('No hay presupuesto activo');
    }

    // 2️⃣  Reúne datos -> listas de entrada
    final dao = BudgetDao();
    final sections =
        await dao.fetchSections(idBudget: idBudget);              // plan
    final txs =
        await dao.fetchTransactions(idBudget: idBudget);          // real

    final _ModelIO io = _prepareModelInput(sections, txs);

    // 3️⃣  Infiere con el modelo
    final List<double> rawOutput = await _runModel(io);

    // 4️⃣  Convierte salida a JSON legible
    final BudgetJson json = _parseOutput(
      sections,
      rawOutput,
    );

    // 5️⃣  Guarda en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ai_adjustment_$idBudget',
      jsonEncode(json),
    );

    return json;
  }

  // ───────────────────────────────────────────────────────────────────
  // MODEL IO helpers
  // ───────────────────────────────────────────────────────────────────

  /// Convierte las estructuras de tu BD a tensores de entrada.
  _ModelIO _prepareModelInput(
    List<SectionData> plan,
    List<TransactionData> txs,
  ) {
    // --- Ejemplo sencillo de codificación: -------------------------
    // Para cada ítem:
    //   [budgetPlan , realSpent]
    // Se concatenan todos en un Float32List.
    // ----------------------------------------------------------------
    final List<double> buffer = [];

    for (final sec in plan) {
      for (final item in sec.items) {
        // Plan
        buffer.add(item.amount);

        // Gasto real buscado entre transacciones
        final spent = txs
            .where((t) =>
                t.category == item.name &&
                t.type.toLowerCase() ==
                    sec.title.toLowerCase()) // "Gastos"/"Ingresos"/...
            .fold<double>(0, (s, t) => s + t.rawAmount);

        buffer.add(spent);
      }
    }

    // Dimensión [1, N] – modelo debe saber esto.
    final input = Float32List.fromList(buffer);

    // Salida esperada misma longitud (plan ajustado)
    return _ModelIO(input: input, outputSize: buffer.length ~/ 2);
  }

// ─────────────────────────────────────────────────────────────
// Sustituye TODO el método _runModel() por este
// ─────────────────────────────────────────────────────────────
Future<List<double>> _runModel(_ModelIO io) async {
  // 1. Cargar intérprete
  final interpreter = await Interpreter.fromAsset(
    'models/budget_adjuster.tflite',
    options: InterpreterOptions()..threads = 2,
  );

  // 2. Reservar tensores
  interpreter.allocateTensors();

  // 3. Copiar entrada
  //    El modelo fue entrenado con shape [1, N]; por eso
  //    creamos un Float32List y lo envolvemos en un List-de-List.
  final inputTensor = [io.input];                 // ==>  List<Object>

  // 4. Crear buffer de salida (N/2 valores)
  final outputBuffer = Float32List(io.outputSize);
  final outputs = <int, Object>{0: [outputBuffer]}; // shape [1, N/2]

  // 5. Inferencia
  interpreter.runForMultipleInputs(inputTensor, outputs);

  // 6. Extraer y convertir a List<double>
  final Float32List raw = (outputs[0] as List).first as Float32List;
  return raw.toList(growable: false);
}


  /// Mapea la salida a un JSON con misma estructura que los *cards*.
  BudgetJson _parseOutput(List<SectionData> plan, List<double> out) {
    final BudgetJson result = {};

    int idx = 0;
    for (final sec in plan) {
      final Map<String, double> items = {};
      for (final item in sec.items) {
        items[item.name] = out[idx++];
      }
      result[sec.title] = items;
    }
    return result;
  }
}

// Helper privado para pasar entrada + tamaño de salida
class _ModelIO {
  final Float32List input;
  final int outputSize;
  _ModelIO({required this.input, required this.outputSize});
}


/*

COMO PEDIRLO EN CUALQUIER PARTE DEL PROGRAMA

void _onPedirAjusteIA(BuildContext context) async {
  try {
    final json = await BudgetAIService.instance.adjustCurrentBudget(context);
    debugPrint('✅ IA devolvió: $json');
    // Muestra diálogo de confirmación al usuario, etc.
  } catch (e) {
    debugPrint('⛔️ Error pidiendo ajuste IA: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error IA: $e')),
    );
  }
}


*/

*/
