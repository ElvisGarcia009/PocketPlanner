// lib/screens/chatbot_home_screen.dart
import 'dart:convert';
import 'dart:ui';
import 'package:Pocket_Planner/database/sqlite_management.dart';
import 'package:Pocket_Planner/flutterflow_components/flutterflowtheme.dart';
import 'package:Pocket_Planner/functions/active_budget.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

/* ──────────────────────────────────────────────────────────
   MODELO + DAO + API
─────────────────────────────────────────────────────────── */

class ChatMessage {
  int?    idMsg;
  String  text;
  DateTime date;
  bool    isUser;
  bool    isPending;

  ChatMessage({
    this.idMsg,
    required this.text,
    required this.date,
    required this.isUser,
    this.isPending = false,
  });

  factory ChatMessage.fromRow(Map<String, Object?> r) => ChatMessage(
        idMsg   : r['id_msg']   as int,
        text    : r['message']  as String,
        date    : DateTime.parse(r['date'] as String),
        isUser  : (r['from'] as int) == 1,
      );
}

class ChatbotDao {
  final _db = SqliteManager.instance.db;

  Future<int> insert({
    required String text,
    required int from,               // 1=usuario | 2=bot
    DateTime? date,
  }) async =>
      await _db.insert(
        'chatbot_tb',
        {
          'message': text,
          'from'   : from,
          'date'   : (date ?? DateTime.now()).toIso8601String(),
        },
      );

  Future<void> updateText(int idMsg, String msg) async =>
      _db.update('chatbot_tb', {'message': msg},
          where: 'id_msg = ?', whereArgs: [idMsg]);

  Future<List<Map<String, Object?>>> fetchAll() async =>
      _db.query('chatbot_tb', orderBy: 'date ASC');
}

class ChatbotApi {
  static const _url =
      'https://pocketplanner-backend-ayj7.onrender.com/message';

  static Future<String> ask(List<Map<String, String>> memory) async {
    final res = await http.post(
      Uri.parse(_url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'messages': memory}),
    ).timeout(const Duration(seconds: 20));

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['reply'] ?? 'Lo siento, no entendí 😔';
    }
    throw Exception('Error ${res.statusCode}');
  }
}


/* ──────────────────────────────────────────────────────────
   PANTALLA
─────────────────────────────────────────────────────────── */

class ChatbotHomeScreen extends StatefulWidget {
  const ChatbotHomeScreen({Key? key}) : super(key: key);

  @override
  State<ChatbotHomeScreen> createState() => _ChatbotHomeScreenState();
}

class _ChatbotHomeScreenState extends State<ChatbotHomeScreen> {
  final _txtCtrl   = TextEditingController();
  final _focusNode = FocusNode();
  final _scroll    = ScrollController();

  final _dao       = ChatbotDao();
  List<ChatMessage> _messages = [];
  

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  

/* ───── carga inicial ─────────────────────────────────── */

  Future<void> _loadMessages() async {
    final rows = await _dao.fetchAll();
    setState(() => _messages = rows.map(ChatMessage.fromRow).toList());

    if (_messages.isEmpty) {
      final init = ChatMessage(
        text : 'Hola! Soy Leticia AI, tu asesora financiera personal. Dime ¿Que quieres saber?',
        date : DateTime.now(),
        isUser: false,
      );
      init.idMsg = await _dao.insert(text: init.text, from: 2, date: init.date);
      setState(() => _messages.add(init));
    }
  }




/* ───── envío ─────────────────────────────────────────── */

  void _handleSendMessage() async {
    final txt = _txtCtrl.text.trim();
    if (txt.isEmpty) return;

    // 1. usuario
    final user = ChatMessage(text: txt, date: DateTime.now(), isUser: true);
    user.idMsg = await _dao.insert(text: txt, from: 1, date: user.date);
    setState(() => _messages.add(user));

    // 2. placeholder bot
    final bot = ChatMessage(
      text : '...',
      date : DateTime.now(),
      isUser: false,
      isPending: true,
    );
    bot.idMsg = await _dao.insert(text: bot.text, from: 2, date: bot.date);
    setState(() => _messages.add(bot));

    _txtCtrl.clear();
    _focusNode.unfocus();
    _scrollToBottom();

    // 3. llamada a la API
    try {
      // 1. Genera el prompt con toda la info
    final prompt = await ContextBuilder.build(context, txt);

// Tomar últimos 6 mensajes del historial (sin pending)
final memory = _messages
    .where((m) => !m.isPending)
    .toList()
    .reversed
    .take(6)
    .toList()
    .reversed
    .map((m) => {
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.text,
        })
    .toList();

// Añadir el nuevo mensaje del usuario
memory.add({'role': 'user', 'content': prompt});

// Enviar a la API
final reply = await ChatbotApi.ask(memory);

    
  bot
  ..text      = reply
  ..isPending = false;
  await _dao.updateText(bot.idMsg!, reply);
  } catch (_) {
  bot
  ..text      = 'Lo siento, ocurrió un error 😞'
  ..isPending = false;
  await _dao.updateText(bot.idMsg!, bot.text);
  }

  if (mounted) {
  setState(() {});
  _scrollToBottom();
  }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

/* ───── UI ─────────────────────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/chat-wallpaper.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(child: _buildMessagesList(theme)),
            _buildBottomBar(theme),
          ],
        ),
      ),
    );
  }

/* header */

Widget _buildHeader(FlutterFlowThemeData theme) => Material(
      color: Colors.transparent,
      elevation: 1,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
            width: double.infinity,               // ⬅️ ocupa todo el ancho
            color: theme.primaryBackground,
            padding: const EdgeInsets.only(top: 35, bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Leticia AI', style: theme.typography.bodyMedium),
                Text(
                  'Habla con tu asesora financiera personal',
                  style: theme.typography.bodySmall.override(
                    color: theme.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );


/* lista */

  Widget _buildMessagesList(FlutterFlowThemeData theme) => ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: 10),
        reverse: true,
        itemCount: _messages.length,
        itemBuilder: (_, i) {
          final msg = _messages[_messages.length - 1 - i];
          return msg.isUser
              ? _userBubble(msg, theme)
              : _botBubble(msg, theme);
        },
      );

/* bottom bar */

  Widget _buildBottomBar(FlutterFlowThemeData theme) => Material(
        elevation: 1,
        color: theme.primaryBackground.withOpacity(.9),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 8, 8, 15),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _txtCtrl,
                  focusNode: _focusNode,
                  style: theme.typography.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Escribe tus preguntas…',
                    hintStyle:
                        theme.typography.bodySmall.override(color: Colors.grey),
                    filled: true,
                    fillColor: theme.secondaryBackground,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send_outlined,
                    color: theme.primaryText, size: 30),
                onPressed: _handleSendMessage,
              ),
            ],
          ),
        ),
      );

/* burbujas */

  String _fmt(DateTime d) => DateFormat('h:mm a').format(d);

  Widget _userBubble(ChatMessage m, FlutterFlowThemeData t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 15, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _bubbleContainer(
            color: t.primary,
            text: m.text,
            time: _fmt(m.date),
            txtStyle: t.typography.bodyMedium,
            alignEnd: true,
            pending: false,
          ),
        ]),
      );

  Widget _botBubble(ChatMessage m, FlutterFlowThemeData t) => Padding(
        padding: const EdgeInsets.fromLTRB(13, 10, 50, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: const AssetImage('assets/images/chat-bot.png'),
            backgroundColor: Colors.transparent,
          ),
          const SizedBox(width: 7),
          _bubbleContainer(
            color: t.secondaryBackground,
            text: m.text,
            time: _fmt(m.date),
            txtStyle: t.typography.bodyMedium,
            alignEnd: false,
            pending: m.isPending,
          ),
        ]),
      );

  Widget _bubbleContainer({
    required Color color,
    required String text,
    required String time,
    required TextStyle txtStyle,
    required bool alignEnd,
    required bool pending,
  }) =>
      Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .65,
        ),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(10),
        child: pending
            ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment:
                    alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  AutoSizeText(text,
                      textAlign: TextAlign.start,
                      //maxLines: 200,
                      minFontSize: 12,
                      style: txtStyle,
                      overflow: TextOverflow.clip),
                  const SizedBox(height: 4),
                  Text(time,
                      style: txtStyle.copyWith(
                          fontSize: 12, color: const Color.fromARGB(255, 255, 255, 255))),
                ],
              ),
      );
}

class ContextBuilder {
  static const _msgFaltanDatos =
      'Primero debes tener transacciones y completar tu presupuesto para poder ayudarte!';

  static Future<String> build(BuildContext ctx, String userMsg) async {
    final db  = SqliteManager.instance.db;
    final bid = Provider.of<ActiveBudget>(ctx, listen: false).idBudget;
    if (bid == null) return _msgFaltanDatos;

    /* — A) Presupuesto + ítems — */
    const sqlBudget = '''
      SELECT b.name        AS budget_name,
             i.amount      AS budgeted_amount,
             cat.name      AS category_name,
             itype.name    AS item_type
      FROM   budget_tb   b
      JOIN   card_tb     c     ON c.id_budget   = b.id_budget
      JOIN   item_tb     i     ON i.id_card     = c.id_card
      JOIN   category_tb cat   ON cat.id_category = i.id_category
      JOIN   itemType_tb itype ON itype.id      = i.id_itemType
      WHERE  b.id_budget = ?
    ''';

    /* — B) Totales gastados — */
    const sqlSpent = '''
      SELECT cat.name AS category_name,
             SUM(t.amount) AS total_spent
      FROM   transaction_tb t
      JOIN   category_tb    cat ON cat.id_category = t.id_category
      WHERE  t.id_budget = ?
      GROUP  BY cat.name
    ''';

    final res = await Future.wait([
      db.rawQuery(sqlBudget, [bid]),
      db.rawQuery(sqlSpent , [bid]),
    ]);

    final rowsBudget = res[0];
    final rowsSpent  = res[1];

    // ⬇️  si falta cualquiera de los dos bloques, devolvemos el mensaje “faltan datos”
    if (rowsBudget.isEmpty || rowsSpent.isEmpty) return _msgFaltanDatos;

    /* — 1. Presupuesto — */
    final budgetName = rowsBudget.first['budget_name'] as String;
    final buf = StringBuffer()
      ..write('El usuario tiene un presupuesto $budgetName de ');
    for (final r in rowsBudget) {
      buf.write('${r['budgeted_amount']} en ${r['category_name']} '
                'con ${r['item_type']}, ');
    }

    /* — 2. Gastos — */
    buf.write('Sus gastos actuales son ');
    for (final r in rowsSpent) {
      buf.write('${r['total_spent']} en ${r['category_name']}, ');
    }

    /* — 3. Mensaje del usuario — */
    buf.write('\n"$userMsg"');
    return buf.toString();
  }
}

