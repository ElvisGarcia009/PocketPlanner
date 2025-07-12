import 'dart:io';

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
    return _db!;
  }

  bool dbIsFor(String uid) => _db != null && _currentUid == uid;

  static const _dbVersion = 12;

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
        await _DropSQLiteDatabase(db);
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

    //  budgetPeriod_tb
    await db.execute('''
    INSERT INTO budgetPeriod_tb (id_budgetPeriod, name) VALUES
      (1,'Mensual'),
      (2,'Quincenal')
    ''');

    // budget_tb  (solamente una fila, se puede quedar igual)
    await db.execute('''
    INSERT INTO budget_tb (id_budget, name, id_budgetPeriod)
    VALUES (1,'Mi presupuesto',2);
    ''');

    // card_tb
    await db.execute('''
    INSERT INTO card_tb (id_card, title, id_budget, date_crea, date_mod) VALUES
      (1,'Ingresos',1,datetime('now'),NULL),
      (2,'Gastos',  1,datetime('now'),NULL),
      (3,'Ahorros', 1,datetime('now'),NULL);
    ''');

    // movement_tb
    await db.execute('''
    INSERT INTO movement_tb (id_movement, name) VALUES
      (1,'Gastos'),
      (2,'Ingresos'),
      (3,'Ahorros');
    ''');

    //  category_tb
    await db.execute('''
   INSERT INTO category_tb (id_category, name, icon_name, id_movement) VALUES
  /* ──────────────── id_movement = 1  (GASTOS) ──────────────── */
  (1 , 'Consumos'                , 'fastfood'              , 1),
  (2 , 'Entretenimiento'         , 'movie'                 , 1),
  (3 , 'Gimnasio'                , 'fitness_center'        , 1),
  (4 , 'Deportes'                , 'sports_soccer'         , 1),
  (5 , 'Servicios de streaming'  , 'live_tv'               , 1),
  (6 , 'Suscripciones'           , 'subscriptions'         , 1),
  (7 , 'Ropa'                    , 'shopping_bag'          , 1),
  (8 , 'Compras del hogar'       , 'home_repair_service'   , 1),
  (9 , 'Cuidado personal'        , 'spa'                   , 1),
  (10, 'Salud'                   , 'health_and_safety'     , 1),
  (11, 'Seguro'                  , 'security'              , 1),
  (12, 'Impuestos'               , 'request_quote'         , 1),
  (13, 'Alquiler'                , 'home'                  , 1),
  (14, 'Servicios públicos'      , 'bolt'                  , 1),
  (15, 'Internet'                , 'wifi'                  , 1),
  (16, 'Teléfono móvil'          , 'phone_android'         , 1),
  (17, 'Transporte'              , 'directions_bus'        , 1),
  (18, 'Gasolina'                , 'local_gas_station'     , 1),
  (19, 'Peaje'                   , 'paid'                  , 1),
  (20, 'Estacionamiento'         , 'local_parking'         , 1),
  (21, 'Mantenimiento vehicular' , 'car_repair'            , 1),
  (22, 'Regalos'                 , 'card_giftcard'         , 1),
  (23, 'Mascotas'                , 'pets'                  , 1),
  (24, 'Gastos Estudiantiles'    , 'school'                , 1),
  (25, 'Préstamo'                , 'account_balance'       , 1),
  (26, 'Tarjeta crédito'         , 'credit_card'           , 1),
  (27, 'Otros'                   , 'category'              , 1),
  (28, 'Ingresos'                , 'attach_money'          , 2),
  (29, 'Salario'                 , 'payments'              , 2),
  (30, 'Bono'                    , 'star'                  , 2),
  (31, 'Freelance'               , 'work'                  , 2),
  (32, 'Reembolsos'              , 'undo'                  , 2),
  (33, 'Regalos recibidos'       , 'card_giftcard'         , 2),
  (34, 'Inversión'               , 'show_chart'            , 2),
  (35, 'Dividendos'              , 'trending_up'           , 2),
  (36, 'Intereses'               , 'show_chart'            , 2),
  (37, 'Venta de acciones'       , 'stacked_line_chart'    , 2),
  (38, 'Ingresos de renta'       , 'apartment'             , 2),
  (39, 'Venta de artículos'      , 'sell'                  , 2),
  (40, 'Ventas en línea'         , 'shopping_cart'         , 2),
  (41, 'Pensión'                 , 'elderly'               , 2),
  (42, 'Ahorros'                 , 'savings'               , 3),
  (43, 'Ahorros de emergencia'   , 'medical_services'      , 3),
  (44, 'Fondo emergencia extra'  , 'priority_high'         , 3),
  (45, 'Vacaciones'              , 'beach_access'          , 3),
  (46, 'Fondo viajes'            , 'flight'                , 3),
  (47, 'Nuevo auto'              , 'directions_car'        , 3),
  (48, 'Inicial de casa'         , 'house'                 , 3),
  (49, 'Proyecto'                , 'build'                 , 3),
  (50, 'Fondo médico'            , 'medical_services'      , 3),
  (51, 'Fondo de retiro'         , 'account_balance_wallet', 3),
  (52, 'Ahorro educación'        , 'school'                , 3),
  (53, 'Boda'                    , 'favorite'              , 3),
  (54, 'Inversión'               , 'trending_up'           , 3);
    ''');

    //  frequency_tb
    await db.execute('''
    INSERT INTO frequency_tb (id_frequency, name) VALUES
    (1,'Solo por hoy'),
    (2,'Todos los días'),
    (3,'Dias laborables'),
    (4,'Cada semana'),
    (5,'Cada mes');
    ''');

    // itemType_tb
    await db.execute('''
    INSERT INTO itemType_tb (id, name) VALUES
      (1,'Monto fijo'),
      (2,'Monto variable');
    ''');

    // item_tb
    await db.execute('''
    INSERT INTO item_tb (id_item, id_category, id_card, amount, date_crea, id_itemType)
    VALUES (1,28,1,0,datetime('now'),1),
           (2,1,2,0,datetime('now'),2),
           (3,42,3,0,datetime('now'),2);
    ''');

    await db.execute('''
    INSERT INTO merchant_map_tb (merchant, id_category) VALUES
      ('UBER',                          17),
      ('UBER RIDES',                   17),
      ('UBER TRIP',                    17),
      ('CORREDOR',                     17),
      ('IN DRIVE',                     17),
      ('DIDI',                         17),
      ('APOLO TAXI',                   17),
      ('CARIBE TOURS',                17),
      ('METRO BUS',                   17),
      ('MCDONALDS',                    1),
      ('BURGER KING',                 1),
      ('PIZZA HUT',                   1),
      ('DOMINOS',                     1),
      ('KFC',                         1),
      ('WENDYS',                      1),
      ('POLLO VICTORINA',             1),
      ('LA SIRENA',                   1),
      ('JUMBO',                       1),
      ('SUPERPOLA',                   1),
      ('SUPERMERCADO NACIONAL',       1),
      ('NETFLIX',                     5),
      ('SPOTIFY',                     5),
      ('APPLE ITUNES',                5),
      ('GOOGLE PLAY',                 5),
      ('PLAYSTATION NETWORK',         5),
      ('CLARO',                      16),
      ('ALTICE',                     16),
      ('VIVA',                       16),
      ('EDESUR',                     14),
      ('EDEESTE',                    14),
      ('EDENORTE',                   14),
      ('CEPM',                       14),
      ('CAASD',                      15),
      ('INAPA',                      15),
      ('FARMACIA CAROL',             10),
      ('FARMACIA MEDCAR',            10),
      ('HUMANO',                     10),
      ('MAPFRE',                     10),
      ('ZARA',                        7),
      ('ADIDAS',                      7),
      ('NIKE',                        7),
      ('SEGUROS RESERVAS',          11),
      ('SEGUROS UNIVERSAL',         11);
    ''');
  }

  /// Borra todas las tablas locales del usuario actual (¡no usar en producción!)
  Future<void> DropSQLiteDatabase() async {
    if (_db == null) {
      throw Exception('No hay base de datos abierta.');
    }
    await _DropSQLiteDatabase(_db!);
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

  Future<List<Map<String, Object?>>> query(
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

  Future<void> _DropSQLiteDatabase(Database db) async {
    if (_currentUid == null) {
      throw Exception('No hay un usuario actual.');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, _fileNameFor(_currentUid!));

    if (_db != null) {
      await _db!.close();
      _db = null;
      _currentUid = null;
    }

    final dbFile = File(path);
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
  }

  String _fileNameFor(String uid) => 'db_$uid.db';

  /*  CONSULTA PARA CREAR LAS TABLAS  */

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
  "date" DATE,
  "id_budget" INTEGER
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

// Clases de modelo para SQLite

class BudgetSql {
  final int? idBudget;
  final String name;
  final int idPeriod;
  final DateTime dateCrea;

  BudgetSql({
    this.idBudget,
    required this.name,
    required this.idPeriod,
    DateTime? dateCrea,
  }) : dateCrea = dateCrea ?? DateTime.now();

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

class PeriodSql {
  final int idPeriod;
  final String name;

  PeriodSql({required this.idPeriod, required this.name});

  Map<String, dynamic> toMap() => {'id_period': idPeriod, 'name': name};

  factory PeriodSql.fromMap(Map<String, Object?> m) => PeriodSql(
    idPeriod: m['id_budgetPeriod'] as int,
    name: m['name'] as String,
  );
}
