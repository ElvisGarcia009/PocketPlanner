import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:pocketplanner/database/sqlite_management.dart';
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';
import 'package:pocketplanner/services/active_budget.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// MODELO + DAO + API

class ChatMessage {
  int? idMsg;
  String text;
  DateTime date;
  bool isUser;
  bool isPending;

  ChatMessage({
    this.idMsg,
    required this.text,
    required this.date,
    required this.isUser,
    this.isPending = false,
  });

  factory ChatMessage.fromRow(Map<String, Object?> r) => ChatMessage(
    idMsg: r['id_msg'] as int,
    text: r['message'] as String,
    date: DateTime.parse(r['date'] as String),
    isUser: (r['from'] as int) == 1,
  );
}

class ChatbotDao {
  final _db = SqliteManager.instance.db;

  Future<int> insert({
    required String text,
    required int from, // 1 = usuario | 2 = bot
    DateTime? date,
    required int idBudget,
  }) async => await _db.insert('chatbot_tb', {
    'message': text,
    'from': from,
    'date': (date ?? DateTime.now()).toIso8601String(),
    'id_budget': idBudget,
  });

  Future<void> updateText(int idMsg, String msg) async => _db.update(
    'chatbot_tb',
    {'message': msg},
    where: 'id_msg = ?',
    whereArgs: [idMsg],
  );

  /* ← filtra por presupuesto y ordena ASC */
  Future<List<Map<String, Object?>>> fetchAll(int idBudget) async => _db.query(
    'chatbot_tb',
    where: 'id_budget = ?',
    whereArgs: [idBudget],
    orderBy: 'date ASC',
  );

  Future<List<Map<String, Object?>>> fetchPaginated({
    required int idBudget,
    required int limit,
    required int offset,
  }) async => _db.query(
    'chatbot_tb',
    where: 'id_budget = ?',
    whereArgs: [idBudget],
    orderBy: 'date DESC', // Importante: orden descendente
    limit: limit,
    offset: offset,
  );
}

class ChatbotApi {
  static const _url =
      'https://pocketplanner-backend-0seo.onrender.com/message'; // Nuestro endpoint de la API para el chatbot

  static Future<String> ask(List<Map<String, String>> memory) async {
    final res = await http
        .post(
          Uri.parse(_url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'messages': memory}),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['reply'] ??
          'Lo siento! No me encuentro de servicio ahora mismo, intenta en unos minutos.';
    }
    throw Exception('Error ${res.statusCode}');
  }
}

class ChatbotHomeScreen extends StatefulWidget {
  const ChatbotHomeScreen({Key? key}) : super(key: key);

  @override
  State<ChatbotHomeScreen> createState() => _ChatbotHomeScreenState();
}

class _ChatbotHomeScreenState extends State<ChatbotHomeScreen> {
  final _txtCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scroll = ScrollController();

  final _dao = ChatbotDao();
  List<ChatMessage> _messages = [];

  int _page = 0;
  final int _pageSize = 10;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;

  late final int _bid;

  @override
  void initState() {
    super.initState();
    _bid = context.read<ActiveBudget>().idBudget!; // Presupuesto activo
    _loadMessages();
  }

  // Cargar mensajes del chat desde la base de datos
  Future<void> _loadMessages() async {
    final rows = await _dao.fetchPaginated(
      idBudget: _bid,
      limit: _pageSize,
      offset: _page * _pageSize,
    );

    final newMessages = rows.map(ChatMessage.fromRow).toList();

    setState(() {
      if (newMessages.isEmpty) {
        _hasMoreMessages = false;
      } else {
        // Mantenemos el orden cronológico (más antiguos primero)
        _messages.insertAll(0, newMessages.reversed.toList());
        _page++;
      }

      if (_messages.isEmpty) {
        _addInitialBotMessage();
      }
    });
  }

  void _addInitialBotMessage() async {
    final init = ChatMessage(
      text:
          'Hola! Soy Leticia AI, tu asesora financiera personal. Dime ¿Que quieres saber?',
      date: DateTime.now(),
      isUser: false,
    );

    init.idMsg = await _dao.insert(
      text: init.text,
      from: 2,
      date: init.date,
      idBudget: _bid,
    );

    setState(() => _messages.add(init));
  }

  // Manejar el envío de mensajes
  void _handleSendMessage() async {
    final txt = _txtCtrl.text.trim();
    if (txt.isEmpty) return;

    // 1. usuario
    final user = ChatMessage(text: txt, date: DateTime.now(), isUser: true);
    user.idMsg = await _dao.insert(
      text: txt,
      from: 1,
      date: user.date,
      idBudget: _bid,
    );
    setState(() => _messages.add(user));

    // 2. placeholder bot
    final bot = ChatMessage(
      text: '...',
      date: DateTime.now(),
      isUser: false,
      isPending: true,
    );
    bot.idMsg = await _dao.insert(
      text: bot.text,
      from: 2,
      date: bot.date,
      idBudget: _bid,
    );
    setState(() => _messages.add(bot));

    _txtCtrl.clear();
    _focusNode.unfocus();
    _scrollToBottom();

    // 3. llamada a la API
    try {
      // Genera el prompt con toda la info del usuario
      final prompt = await ContextBuilder.build(context, txt);

      // Toma los ultimos 6 mensajes del historial (darle memoria al chatbot, no recuerda lo que le dices)
      final memory =
          _messages
              .where((m) => !m.isPending)
              .toList()
              .reversed
              .take(6)
              .toList()
              .reversed
              .map(
                (m) => {
                  'role': m.isUser ? 'user' : 'assistant',
                  'content': m.text,
                },
              )
              .toList();

      // Añadir el mensaje del usuario
      memory.add({'role': 'user', 'content': prompt});

      // Enviar a la API
      final reply = await ChatbotApi.ask(memory);

      bot
        ..text = reply
        ..isPending = false;
      await _dao.updateText(bot.idMsg!, reply);

      setState(() {});
      _scrollToBottom();
    } catch (_) {
      bot
        ..text = 'Lo siento, ocurrió un error 😞'
        ..isPending = false;
      await _dao.updateText(bot.idMsg!, bot.text);
    }

    if (_page > 0) {
      _page = 0;
      _hasMoreMessages = true;
      await _reloadAllMessages();
    }
  }

  Future<void> _reloadAllMessages() async {
    setState(() => _messages.clear());
    await _loadMessages();
    _scrollToBottom();
  }

  // Animacion de chat
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.minScrollExtent);
      }
    });
  }

  // UI

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

  // Header
  Widget _buildHeader(FlutterFlowThemeData theme) => Material(
    color: Colors.transparent,
    elevation: 1,
    child: ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          width: double.infinity,
          color: theme.primaryBackground,
          padding: const EdgeInsets.only(
            top: 35,
            bottom: 4,
            left: 50,
            right: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Text('Leticia AI', style: theme.typography.bodyLarge),
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
              // Icono de basura pegado a la derecha
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 24),
                color: theme.primaryText,
                tooltip: 'Borrar conversación',
                onPressed: _confirmClearConversation,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _confirmClearConversation() async {
    final theme = FlutterFlowTheme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              'Borrar conversación',
              style: theme.typography.titleLarge,
              textAlign: TextAlign.center,
            ),
            content: Text(
              '¿Estás seguro de que quieres eliminar toda la conversación?',
              style: theme.typography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.primaryText,
                  textStyle: theme.typography.bodyMedium,
                ),
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'No, cancelar',
                  style: theme.typography.bodyMedium.override(
                    color: theme.primary,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  textStyle: theme.typography.bodyMedium,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Si, borrar todo',
                  style: theme.typography.bodyMedium,
                ),
              ),
            ],
          ),
    );

    if (result == true) {
      // 2) Borrar la tabla entera
      await _dao._db.delete('chatbot_tb');
      // 3) Regenerar el mensaje inicial
      final init = ChatMessage(
        text:
            'Hola! Soy Leticia AI, tu asesora financiera personal. Dime ¿Qué quieres saber?',
        date: DateTime.now(),
        isUser: false,
      );
      init.idMsg = await _dao.insert(
        text: init.text,
        from: 2,
        date: init.date,
        idBudget: _bid,
      );
      setState(() {
        _messages = [init];
      });
    }
  }

  // Lista

  Widget _buildMessagesList(FlutterFlowThemeData theme) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (_shouldLoadMore(scrollNotification)) {
          _loadMoreMessages();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: 10),
        reverse: true,
        itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (_, index) {
          if (index >= _messages.length) {
            return _buildLoader();
          }

          final msg = _messages[_messages.length - 1 - index];
          return msg.isUser ? _userBubble(msg, theme) : _botBubble(msg, theme);
        },
      ),
    );
  }

  bool _shouldLoadMore(ScrollNotification scroll) {
    return scroll is ScrollEndNotification &&
        scroll.metrics.pixels == scroll.metrics.minScrollExtent &&
        !_isLoadingMore &&
        _hasMoreMessages;
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() => _isLoadingMore = true);

    try {
      final rows = await _dao.fetchPaginated(
        idBudget: _bid,
        limit: _pageSize,
        offset: _page * _pageSize,
      );

      final newMessages = rows.map(ChatMessage.fromRow).toList();

      setState(() {
        if (newMessages.isEmpty) {
          _hasMoreMessages = false;
        } else {
          _messages.insertAll(0, newMessages.reversed.toList());
          _page++;
        }
      });
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Widget _buildLoader() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Center(child: CircularProgressIndicator()),
  );

  // Bottom Bar

  Widget _buildBottomBar(FlutterFlowThemeData theme) => Material(
    elevation: 1,
    color: theme.primaryBackground.withOpacity(.9),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 8, 15),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _txtCtrl,
              focusNode: _focusNode,
              style: theme.typography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Escribe tus preguntas…',
                hintStyle: theme.typography.bodySmall.override(
                  color: Colors.grey,
                ),
                filled: true,
                fillColor: theme.secondaryBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send_outlined, color: theme.primaryText, size: 30),
            onPressed: _handleSendMessage,
          ),
        ],
      ),
    ),
  );

  // Burbujas de chat

  String _fmt(DateTime d) => DateFormat('h:mm a').format(d);

  Widget _userBubble(ChatMessage m, FlutterFlowThemeData t) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 10, 15, 0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _bubbleContainer(
          color: t.primary,
          text: m.text,
          time: _fmt(m.date),
          txtStyle: t.typography.bodyMedium,
          alignEnd: true,
          pending: false,
        ),
      ],
    ),
  );

  Widget _botBubble(ChatMessage m, FlutterFlowThemeData t) => Padding(
    padding: const EdgeInsets.fromLTRB(13, 10, 50, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
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
      ],
    ),
  );

  Widget _bubbleContainer({
    required Color color,
    required String text,
    required String time,
    required TextStyle txtStyle,
    required bool alignEnd,
    required bool pending,
  }) {
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Texto copiado al portapapeles')),
        );
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .65,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(10),
        child:
            pending
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(),
                )
                : Column(
                  crossAxisAlignment:
                      alignEnd
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.start,
                  children: [
                    MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: txtStyle,
                        h1: txtStyle.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: txtStyle.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: txtStyle.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        strong: txtStyle.copyWith(fontWeight: FontWeight.bold),
                        em: txtStyle.copyWith(fontStyle: FontStyle.italic),
                      ),
                      selectable: false,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: txtStyle.copyWith(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class ContextBuilder {
  static const _msgFaltanDatos = 'El usuario no tiene transacciones';

  static const _noBudget = 'No tienes ningun presupuesto seleccionado.';

  static Future<String> build(BuildContext ctx, String userMsg) async {
    final db = SqliteManager.instance.db;
    final bid = Provider.of<ActiveBudget>(ctx, listen: false).idBudget;
    if (bid == null) return _noBudget;

    // Presupuesto + items
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

    // Totales gastados
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
      db.rawQuery(sqlSpent, [bid]),
    ]);

    final rowsBudget = res[0];
    final rowsSpent = res[1];

    //  si falta cualquiera de los dos bloques, devolvemos el mensaje “faltan datos”
    if (rowsBudget.isEmpty || rowsSpent.isEmpty) return _msgFaltanDatos;

    // 1. Presupuesto
    final budgetName = rowsBudget.first['budget_name'] as String;
    final buf =
        StringBuffer()
          ..write('El usuario tiene un presupuesto $budgetName de ');
    for (final r in rowsBudget) {
      buf.write(
        '${r['budgeted_amount']} en ${r['category_name']} '
        'con ${r['item_type']}, ',
      );
    }

    // 2. Gastos
    buf.write('Sus gastos actuales son ');
    for (final r in rowsSpent) {
      buf.write('${r['total_spent']} en ${r['category_name']}, ');
    }

    // 3. Mensaje del usuario
    buf.write('\n"$userMsg"');
    return buf.toString();
  }
}
