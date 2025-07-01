import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Wrapper mínimo: entrega un ratio (spent/plan) predicho.
class SpendingRatioPredictor {
  SpendingRatioPredictor._(this._interpreter);
  final Interpreter _interpreter;

  static Future<SpendingRatioPredictor> create() async {
    final interp = await Interpreter.fromAsset('budget_base.tflite');
    return SpendingRatioPredictor._(interp);
  }

  /// Devuelve un factor multiplicativo para un [plannedAmount].
  /// e.g. 1.20 ⇒ se espera 20 % de sobre-gasto.
  double predict(double plannedAmount) {
    final input  = Float32List.fromList([plannedAmount]);
    final output = Float32List(1);
    _interpreter.run(input, output);
    return output[0];
  }

  void dispose() => _interpreter.close();
}
