//import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class SqliteManager {
  SqliteManager._private();
  static final SqliteManager instance = SqliteManager._private();

  Database? _db;
  String? _currentUid;

  /// Acceso al objeto Database. Lanza si no se ha inicializado.
  Database get db {
    if (_db == null) {
      throw Exception('Database not initialized. Call initDbForUser(uid) after login.');
    }
    print('DB uID: ${this._currentUid}');    

    return _db!;
  }

  bool dbIsFor(String uid) => _db != null && _currentUid == uid;

  static const _dbVersion = 8;

  Future<void> initDbForUser(String uid) async {
    // Si el mismo usuario ya está inicializado, no hacemos nada.
    if (_db != null && _currentUid == uid) return;

    // Si había una BD previa abierta, la cerramos.
    if (_db != null) {
      await _db!.close();
    }

    _currentUid = uid;

    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, _fileNameFor(uid));
    

    _db = await openDatabase(
    path,
    version: _dbVersion,
    onCreate: (db, v) async => await createTables(db),
    onUpgrade: (db, oldV, newV) async {
      await _dropAllTables(db);
      await createTables(db);
      await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _currentUid = null;
  }


  Future<void> createTables(Database db) async {
    // Crear tablas
    await db.execute(_sqlCreateMovement);
    await db.execute(_sqlCreateFrequency);
    await db.execute(_sqlCreateBudgetPeriod);
    await db.execute(_sqlCreateBudget);
    await db.execute(_sqlCreateCategory);
    await db.execute(_sqlCreatePriority);
    await db.execute(_sqlCreateItemType);
    await db.execute(_sqlCreateCard);
    await db.execute(_sqlCreateTransaction);
    await db.execute(_sqlCreateItem);
    await db.execute(_sqlCreateDetails);
    await db.execute(_sqlCreateChatbot);

    // Datos por defecto

    // 1️⃣  budgetPeriod_tb
    await db.execute('''
    INSERT INTO budgetPeriod_tb (id_budgetPeriod, name) VALUES
      (1,'Mensual'),
      (2,'Quincenal'),
      (3,'Bisemanal'),
      (4,'Semanal'),
      (5,'Anual');
    ''');

    // 2️⃣  budget_tb  (solamente una fila, se puede quedar igual)
    await db.execute('''
    INSERT INTO budget_tb (id_budget, name, id_budgetPeriod, date_crea, date_mod)
    VALUES (1,'Mi presupuesto',2,datetime('now'),NULL);
    ''');

    // 3️⃣  card_tb
    await db.execute('''
    INSERT INTO card_tb (id_card, title, id_budget, date_crea, date_mod) VALUES
      (1,'Ingresos',1,datetime('now'),NULL),
      (2,'Gastos',  1,datetime('now'),NULL),
      (3,'Ahorros', 1,datetime('now'),NULL);
    ''');

    // 4️⃣  movement_tb
    await db.execute('''
    INSERT INTO movement_tb (id_movement, name) VALUES
      (1,'Gastos'),
      (2,'Ingresos'),
      (3,'Ahorros');
    ''');

    // 5️⃣  category_tb
    await db.execute('''
INSERT INTO category_tb (id_category, name, icon_name, id_movement) VALUES
  -- ── GASTOS ─────────────────────────────────────────────────────────
  (1 , 'Transporte'          , 'directions_bus'  , 1),
  (2 , 'Entretenimiento'     , 'movie'           , 1),
  (3 , 'Gastos Estudiantiles', 'school'          , 1),
  (4 , 'Préstamo'            , 'account_balance' , 1),
  (5 , 'Comida'              , 'fastfood'        , 1),
  (6 , 'Tarjeta crédito'     , 'credit_card'     , 1),
  (7 , 'Otros'               , 'category'        , 1),
  (8 , 'Ingresos'            , 'attach_money'    , 2),
  (9 , 'Salario'             , 'payments'        , 2),
  (10, 'Inversión'           , 'show_chart'      , 2),
  (11, 'Otros'               , 'category'        , 2),
  (12, 'Ahorros de emergencia', 'medical_services', 3),
  (13, 'Ahorros'             , 'savings'         , 3),
  (14, 'Vacaciones'          , 'beach_access'    , 3),
  (15, 'Proyecto'            , 'build'           , 3),
  (16, 'Otros'               , 'category'        , 3);
    ''');

    // 6️⃣  frequency_tb
    await db.execute('''
    INSERT INTO frequency_tb (id_frequency, name) VALUES
    (1,'Solo por hoy'),
    (2,'Todos los días'),
    (3,'Dias laborables'),
    (4,'Cada semana'),
    (5,'Cada 2 semanas'),
    (6,'Cada 3 semanas'),
    (7,'Cada 4 semanas'),
    (8,'Cada mes'),
    (9,'Cada 2 meses'),
    (10,'Cada 3 meses'),
    (11,'Cada 4 meses'),
    (12,'Cada primer dia del mes'),
    (13,'Cada ultimo día del mes'),
    (14,'Cada medio año'),
    (15,'Cada año');
    ''');

    // 7️⃣  itemType_tb
    await db.execute('''
    INSERT INTO itemType_tb (id, name) VALUES
      (1,'Monto fijo'),
      (2,'Monto variable');
    ''');

    // 8️⃣  priority_tb
    await db.execute('''
    INSERT INTO priority_tb (id_priority, name, weight) VALUES
      (1,'Alta' ,3),
      (2,'Media',2),
      (3,'Baja' ,1);
    ''');

    // 9️⃣  item_tb 
    await db.execute('''
    INSERT INTO item_tb (id_item, id_category, id_card, amount, date_crea, id_priority, id_itemType)
    VALUES (1,9,1,0,datetime('now'),1,1),
           (2,1,2,0,datetime('now'),1,1),
           (3,13,3,0,datetime('now'),1,1);
    ''');

  }


  Future<int> insert(String table, Map<String, Object?> values) =>
      db.insert(table, values);

  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      db.query(table, where: where, whereArgs: whereArgs);

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required String where,
    required List<Object?> whereArgs,
  }) =>
      db.update(table, values, where: where, whereArgs: whereArgs);

  Future<int> delete(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) =>
      db.delete(table, where: where, whereArgs: whereArgs);


 Future<void> _dropAllTables(Database db) async {
  const tables = [
    'transaction_tb',
    'item_tb',
    'card_tb',
    'budget_tb',
    'budgetPeriod_tb',
    'category_tb',
    'movement_tb',
    'frequency_tb',
    'priority_tb',
    'itemType_tb',
    'details_tb',
    'chatbot_tb'
  ];
  for (final t in tables) {
    await db.execute('DROP TABLE IF EXISTS $t');
  }
}

  String _fileNameFor(String uid) => 'db_$uid.db';

  // ---------------------------------------------------------------------------
  // SQL PARA CREAR TABLAS
  // ---------------------------------------------------------------------------

  static const _sqlCreateCategory = '''
CREATE TABLE IF NOT EXISTS "category_tb" (
  "id_category" INTEGER NOT NULL UNIQUE,
  "name" VARCHAR NOT NULL,
  "icon_name" TEXT NOT NULL,          
  "id_movement" INTEGER NOT NULL,
  PRIMARY KEY("id_category"),
  FOREIGN KEY ("id_movement") REFERENCES "movement_tb"("id_movement")
    ON UPDATE NO ACTION ON DELETE NO ACTION
);
''';

  static const _sqlCreateMovement = '''
CREATE TABLE IF NOT EXISTS "movement_tb" (
  "id_movement" INTEGER NOT NULL UNIQUE,
  "name" VARCHAR NOT NULL,
  PRIMARY KEY("id_movement")
);
''';

  static const _sqlCreateFrequency = '''
CREATE TABLE IF NOT EXISTS "frequency_tb" (
  "id_frequency" INTEGER NOT NULL UNIQUE,
  "name" VARCHAR NOT NULL,
  PRIMARY KEY("id_frequency")
);
''';

  static const _sqlCreateBudgetPeriod = '''
CREATE TABLE IF NOT EXISTS "budgetPeriod_tb" (
  "id_budgetPeriod" INTEGER NOT NULL UNIQUE,
  "name" VARCHAR NOT NULL,
  PRIMARY KEY("id_budgetPeriod")
);
''';

  static const _sqlCreateBudget = '''
CREATE TABLE IF NOT EXISTS "budget_tb" (
  "id_budget" INTEGER NOT NULL UNIQUE,
  "name" VARCHAR NOT NULL,
  "id_budgetPeriod" INTEGER NOT NULL,
  "date_crea" DATETIME NOT NULL,
  "date_mod" DATETIME,
  PRIMARY KEY("id_budget"),
  FOREIGN KEY ("id_budgetPeriod") REFERENCES "budgetPeriod_tb"("id_budgetPeriod")
    ON UPDATE NO ACTION ON DELETE NO ACTION
);
''';

  static const _sqlCreatePriority = '''
CREATE TABLE IF NOT EXISTS "priority_tb" (
  "id_priority" INTEGER NOT NULL UNIQUE,
  "name" VARCHAR NOT NULL,
  "weight" INTEGER NOT NULL,
  PRIMARY KEY("id_priority")
);
''';

  static const _sqlCreateItemType = '''
CREATE TABLE IF NOT EXISTS "itemType_tb" (
  "id" INTEGER NOT NULL UNIQUE,
  "name" VARCHAR NOT NULL,
  PRIMARY KEY("id")
);
''';

  static const _sqlCreateCard = '''
CREATE TABLE IF NOT EXISTS "card_tb" (
  "id_card" INTEGER NOT NULL UNIQUE,
  "title" VARCHAR NOT NULL,
  "id_budget" INTEGER NOT NULL,
  "date_crea" DATETIME NOT NULL,
  "date_mod" DATETIME,
  PRIMARY KEY("id_card"),
  FOREIGN KEY ("id_budget") REFERENCES "budget_tb"("id_budget")
    ON UPDATE NO ACTION ON DELETE NO ACTION
);
''';

  static const _sqlCreateTransaction = '''
CREATE TABLE IF NOT EXISTS "transaction_tb" (
  "id_transaction" INTEGER PRIMARY KEY AUTOINCREMENT,
  "date" DATETIME NOT NULL,
  "id_category" INTEGER NOT NULL,
  "id_frequency" INTEGER NOT NULL,
  "amount" REAL NOT NULL,
  "id_movement" INTEGER NOT NULL,
  "id_budget" INTEGER NOT NULL,
  FOREIGN KEY ("id_category") REFERENCES "category_tb"("id_category")
    ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY ("id_frequency") REFERENCES "frequency_tb"("id_frequency")
    ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY ("id_movement") REFERENCES "movement_tb"("id_movement")
    ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY ("id_budget") REFERENCES "budget_tb"("id_budget")
    ON UPDATE NO ACTION ON DELETE NO ACTION
);
''';

  static const _sqlCreateItem = '''
CREATE TABLE IF NOT EXISTS "item_tb" (
  "id_item" INTEGER NOT NULL UNIQUE,
  "id_category" INTEGER NOT NULL,
  "id_card" INTEGER NOT NULL,
  "amount" REAL NOT NULL,
  "date_crea" DATETIME NOT NULL,
  "id_priority" INTEGER NOT NULL,
  "id_itemType" INTEGER NOT NULL,
  PRIMARY KEY("id_item"),
  FOREIGN KEY ("id_category") REFERENCES "category_tb"("id_category")
    ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY ("id_card") REFERENCES "card_tb"("id_card")
    ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY ("id_priority") REFERENCES "priority_tb"("id_priority")
    ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY ("id_itemType") REFERENCES "itemType_tb"("id")
    ON UPDATE NO ACTION ON DELETE NO ACTION
);
''';

  static const _sqlCreateDetails = '''
CREATE TABLE IF NOT EXISTS "details_tb" (
  "userID" TEXT NOT NULL,
  "last_sync" DATETIME NOT NULL,
  PRIMARY KEY("userID")
);
''';

  static const _sqlCreateChatbot = '''
CREATE TABLE IF NOT EXISTS "chatbot_tb" (
  "id_msg" INTEGER PRIMARY KEY AUTOINCREMENT,
  "message" TEXT,
  "from" INTEGER,
  "date" DATE
);
''';
}

// lib/models/budget_sql.dart
class BudgetSql {
  final int?     idBudget;
  final String   name;
  final int      idPeriod;
  final DateTime dateCrea;          // ← ya no opcional

  BudgetSql({
    this.idBudget,
    required this.name,
    required this.idPeriod,
    DateTime? dateCrea,
  }) : dateCrea = dateCrea ?? DateTime.now();  // ← default en Dart

  Map<String, dynamic> toMap() => {
        if (idBudget != null) 'id_budget'       : idBudget,
        'name'                                  : name,
        'id_budgetPeriod'                       : idPeriod,
        'date_crea'                             : dateCrea.toIso8601String(),
      };

  factory BudgetSql.fromMap(Map<String, Object?> m) => BudgetSql(
        idBudget : m['id_budget']        as int?,
        name     : m['name']             as String,
        idPeriod : m['id_budgetPeriod']  as int,
        dateCrea : DateTime.parse(m['date_crea'] as String),
      );
}

// lib/models/period_sql.dart
class PeriodSql {
  final int idPeriod;  // PK
  final String name;   // 'Quincenal', 'Mensual', …

  PeriodSql({required this.idPeriod, required this.name});

  Map<String, dynamic> toMap() => {
        'id_period': idPeriod,
        'name'     : name,
      };

  factory PeriodSql.fromMap(Map<String, Object?> m) => PeriodSql(
        idPeriod: m['id_budgetPeriod'] as int,
        name    : m['name']      as String,
      );
}
