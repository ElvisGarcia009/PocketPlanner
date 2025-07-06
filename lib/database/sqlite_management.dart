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
      throw Exception(
        'Database not initialized. Call initDbForUser(uid) after login.',
      );
    }
    print('DB uID: ${this._currentUid}');

    return _db!;
  }

  bool dbIsFor(String uid) => _db != null && _currentUid == uid;

  static const _dbVersion = 10;

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
    await db.execute(_sqlCreateItemType);
    await db.execute(_sqlCreateCard);
    await db.execute(_sqlCreateTransaction);
    await db.execute(_sqlCreateItem);
    await db.execute(_sqlCreateDetails);
    await db.execute(_sqlCreateChatbot);
    await db.execute(_sqlCreateAI_feedback);
    await db.execute(_sqlCreateMerchant_map_tb);

    // Datos por defecto

    // 1️⃣  budgetPeriod_tb
    await db.execute('''
    INSERT INTO budgetPeriod_tb (id_budgetPeriod, name) VALUES
      (1,'Mensual'),
      (2,'Quincenal')
    ''');

    // 2️⃣  budget_tb  (solamente una fila, se puede quedar igual)
    await db.execute('''
    INSERT INTO budget_tb (id_budget, name, id_budgetPeriod)
    VALUES (1,'Mi presupuesto',2);
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
  (12, 'Ahorros de emergencia', 'medical_services', 3),
  (13, 'Ahorros'             , 'savings'         , 3),
  (14, 'Vacaciones'          , 'beach_access'    , 3),
  (15, 'Proyecto'            , 'build'           , 3),
  (17, 'Servicios públicos' , 'bolt'                 , 1),
  (18, 'Electricidad'       , 'electric_bolt'        , 1),
  (19, 'Agua'               , 'water_drop'           , 1),
  (20, 'Internet'           , 'wifi'                 , 1),
  (21, 'Salud'              , 'health_and_safety'    , 1),
  (22, 'Ropa'               , 'shopping_bag'         , 1),
  (23, 'Regalos'            , 'card_giftcard'        , 1),
  (24, 'Mascotas'           , 'pets'                 , 1),
  (25, 'Mantenimiento hogar', 'home_repair_service'  , 1),
  (26, 'Cuidado personal'   , 'spa'                  , 1),
  (27, 'Seguro'             , 'security'             , 1),
  (28, 'Educación'          , 'menu_book'            , 1),
  (29, 'Impuestos'          , 'request_quote'        , 1),
  (30, 'Suscripciones'      , 'subscriptions'        , 1),
  (31, 'Deportes'           , 'sports_soccer'        , 1),
  (32, 'Bono'               , 'star'                 , 2),
  (33, 'Freelance'          , 'work'                 , 2),
  (34, 'Dividendos'         , 'trending_up'          , 2),
  (35, 'Reembolsos'         , 'undo'                 , 2),
  (36, 'Regalos recibidos'  , 'card_giftcard'        , 2),
  (37, 'Ingresos de renta'  , 'apartment'            , 2),
  (38, 'Venta de artículos' , 'sell'                 , 2),
  (39, 'Intereses'          , 'show_chart'           , 2),
  (40, 'Pensión'            , 'elderly'              , 2),
  (41, 'Venta de acciones'  , 'stacked_line_chart'   , 2),
  (42, 'Fondo de retiro'          , 'account_balance_wallet', 3),
  (43, 'Ahorro educación'         , 'school'                , 3),
  (44, 'Boda'                     , 'favorite'              , 3),
  (45, 'Nuevo auto'               , 'directions_car'        , 3),
  (46, 'Fondo infantil'           , 'child_friendly'        , 3),
  (47, 'Inicial de casa'          , 'house'                 , 3),
  (48, 'Fondo médico'             , 'medical_services'      , 3),
  (49, 'Fondo viajes'             , 'flight'                , 3),
  (50, 'Fondo emergencia extra'   , 'priority_high'         , 3),
  (51, 'Inversión largo plazo'    , 'trending_up'           , 3),
  (52, 'Fondo tecnología'         , 'devices_other'         , 3);
    ''');

    // 6️⃣  frequency_tb
    await db.execute('''
    INSERT INTO frequency_tb (id_frequency, name) VALUES
    (1,'Solo por hoy'),
    (2,'Todos los días'),
    (3,'Dias laborables'),
    (4,'Cada semana'),
    (5,'Cada mes')
    ''');

    // 7️⃣  itemType_tb
    await db.execute('''
    INSERT INTO itemType_tb (id, name) VALUES
      (1,'Monto fijo'),
      (2,'Monto variable');
    ''');

    // 9️⃣  item_tb
    await db.execute('''
    INSERT INTO item_tb (id_item, id_category, id_card, amount, date_crea, id_itemType)
    VALUES (1,9,1,0,datetime('now'),1),
           (2,1,2,0,datetime('now'),2),
           (3,13,3,0,datetime('now'),2);
    ''');

    await db.execute('''
    INSERT INTO merchant_map_tb (merchant, id_category) VALUES
      ('UBER',                          1),
      ('UBER RIDES',                    1),
      ('UBER TRIP',                     1),
      ('CORREDOR',                       1),
      ('IN DRIVE',                      1),
      ('DIDI',                          1),
      ('APOLO TAXI',                    1),
      ('CARIBE TOURS',                  1),
      ('METRO BUS',                     1),
      ('MCDONALDS',                     5),
      ('BURGER KING',                   5),
      ('PIZZA HUT',                     5),
      ('DOMINOS',                       5),
      ('KFC',                           5),
      ('WENDYS',                        5),
      ('POLLO VICTORINA',               5),
      ('LA SIRENA',                     5),
      ('JUMBO',                         5),
      ('SUPERPOLA',                     5),
      ('SUPERMERCADO NACIONAL',         5),
      ('NETFLIX',                      30),
      ('SPOTIFY',                      30),
      ('APPLE ITUNES',                 30),
      ('GOOGLE PLAY',                  30),
      ('PLAYSTATION NETWORK',          30),
      ('CLARO',                        20),
      ('ALTICE',                       20),
      ('VIVA',                         20),
      ('EDESUR',                       18),
      ('EDEESTE',                      18),
      ('EDENORTE',                     18),
      ('CEPM',                         18),
      ('CAASD',                        19),
      ('INAPA',                        19),
      ('FARMACIA CAROL',               21),
      ('FARMACIA MEDCAR',              21),
      ('HUMANO',                       21),   
      ('MAPFRE',                       21),
      ('ZARA',                         22),
      ('ADIDAS',                       22),
      ('NIKE',                         22),
      ('SEGUROS RESERVAS',             27),
      ('SEGUROS UNIVERSAL',            27);
    ''');
  }

  Future<List<Map<String, Object?>>> fetchItemsWithSpent(
    int lookbackDays,
  ) async {
    const itemsQ = '''
    SELECT it.id_item, it.id_card, it.id_category,
           it.amount, it.id_itemType,
           ct.name AS category_name
    FROM item_tb it
    JOIN category_tb ct USING(id_category)''';

    const spentQ = '''
    SELECT id_category, SUM(amount) AS spent
    FROM transaction_tb
    WHERE date(date) >= date('now', ?)
    GROUP BY id_category''';

    final items = await db.rawQuery(itemsQ);
    final spentRs = await db.rawQuery(spentQ, ['-${lookbackDays} day']);

    final spent = {
      for (final r in spentRs)
        r['id_category'] as int: (r['spent'] as num).toDouble(),
    };

    return items
        .map((r) => {...r, 'spent': spent[r['id_category']] ?? 0.0})
        .toList();
  }

  Future<int> insert(String table, Map<String, Object?> values) =>
      db.insert(table, values);

  Future<List<Map<String, Object?>>>   query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) => db.query(table, where: where, whereArgs: whereArgs);

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required String where,
    required List<Object?> whereArgs,
  }) => db.update(table, values, where: where, whereArgs: whereArgs);

  Future<int> delete(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) => db.delete(table, where: where, whereArgs: whereArgs);

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
      'itemType_tb',
      'details_tb',
      'chatbot_tb',
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
  PRIMARY KEY("id_budget"),
  FOREIGN KEY ("id_budgetPeriod") REFERENCES "budgetPeriod_tb"("id_budgetPeriod")
    ON UPDATE NO ACTION ON DELETE NO ACTION
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
  "id_itemType" INTEGER NOT NULL,
  PRIMARY KEY("id_item"),
  FOREIGN KEY ("id_category") REFERENCES "category_tb"("id_category")
    ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY ("id_card") REFERENCES "card_tb"("id_card")
    ON UPDATE NO ACTION ON DELETE NO ACTION,
  FOREIGN KEY ("id_itemType") REFERENCES "itemType_tb"("id")
    ON UPDATE NO ACTION ON DELETE NO ACTION
);
''';

  static const _sqlCreateDetails = '''
CREATE TABLE IF NOT EXISTS "details_tb" (
	"userID" TEXT NOT NULL,
	"user_name" VARCHAR,
	"currency" VARCHAR,
  "id_budget" INTEGER,
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

  static const _sqlCreateAI_feedback = '''
CREATE TABLE IF NOT EXISTS ai_feedback_tb (
  id_category  INTEGER NOT NULL UNIQUE,        
  accepted     INTEGER NOT NULL DEFAULT 0,     
  edited       INTEGER NOT NULL DEFAULT 0,     
  rejected     INTEGER NOT NULL DEFAULT 0,    
  streak       INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id_category),
  FOREIGN KEY (id_category) REFERENCES category_tb(id_category)
      ON UPDATE NO ACTION
      ON DELETE CASCADE
);
''';

  static const _sqlCreateMerchant_map_tb = '''
CREATE TABLE IF NOT EXISTS merchant_map_tb (
  merchant   TEXT PRIMARY KEY,   -- nombre “normalizado” del comercio
  id_category INTEGER NOT NULL   -- FK a category_tb
);
''';
}

// lib/models/budget_sql.dart
class BudgetSql {
  final int? idBudget;
  final String name;
  final int idPeriod;
  final DateTime dateCrea; // ← ya no opcional

  BudgetSql({
    this.idBudget,
    required this.name,
    required this.idPeriod,
    DateTime? dateCrea,
  }) : dateCrea = dateCrea ?? DateTime.now(); // ← default en Dart

  Map<String, dynamic> toMap() => {
    if (idBudget != null) 'id_budget': idBudget,
    'name': name,
    'id_budgetPeriod': idPeriod,
  };

  factory BudgetSql.fromMap(Map<String, Object?> m) => BudgetSql(
    idBudget: m['id_budget'] as int?,
    name: m['name'] as String,
    idPeriod: m['id_budgetPeriod'] as int,
  );
}

// lib/models/period_sql.dart
class PeriodSql {
  final int idPeriod; // PK
  final String name; // 'Quincenal', 'Mensual', …

  PeriodSql({required this.idPeriod, required this.name});

  Map<String, dynamic> toMap() => {'id_period': idPeriod, 'name': name};

  factory PeriodSql.fromMap(Map<String, Object?> m) => PeriodSql(
    idPeriod: m['id_budgetPeriod'] as int,
    name: m['name'] as String,
  );
}
