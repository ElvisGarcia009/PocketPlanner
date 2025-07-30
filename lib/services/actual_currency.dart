import 'package:flutter/foundation.dart';

import '../database/sqlite_management.dart';

class ActualCurrency extends ChangeNotifier {
  ActualCurrency._();
  static final ActualCurrency _inst = ActualCurrency._();
  factory ActualCurrency() => _inst;

  String _symbol = 'RD\$'; // valor seguro por defecto
  bool _loaded = false; // 1-solo fetch

  // lee una vez y deja en caché
  Future<void> _loadIfNeeded() async {
    if (_loaded) return;
    final db = SqliteManager.instance.db;
    final rows = await db.query('details_tb', columns: ['currency'], limit: 1);
    final code = rows.isNotEmpty ? rows.first['currency'] as String : 'RD\$';
    _symbol = code.toUpperCase().contains('US') ? 'US\$' : 'RD\$';
    _loaded = true;
  }

  // Símbolo en uso («RD$» o «US$»).
  // Si aún no está cargado, lo hace y después notifica.
  Future<String> symbol() async {
    await _loadIfNeeded();
    return _symbol;
  }

  String get cached => _symbol;

  // cambia la moneda
  Future<void> change(String newSymbol) async {
    final s = newSymbol.toUpperCase().contains('US') ? 'US\$' : 'RD\$';
    if (s == _symbol) return; // nada que hacer

    final db = SqliteManager.instance.db;
    await db.update('details_tb', {'currency': s}); // sobreescribe fila única

    _symbol = s;
    notifyListeners(); // dispara rebuild
  }
}
