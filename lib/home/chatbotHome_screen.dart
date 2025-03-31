import 'dart:convert';
import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importa tu tema
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';

/// Modelo de mensaje con toJson/fromJson para guardar en SharedPreferences
class ChatMessage {
  final String text;
  final String time; 
  final bool isUser;

  ChatMessage({
    required this.text,
    required this.time,
    required this.isUser,
  });

  /// Para serializar
  Map<String, dynamic> toJson() => {
    'text': text,
    'time': time,
    'isUser': isUser,
  };

  /// Para deserializar
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String,
      time: json['time'] as String,
      isUser: json['isUser'] as bool,
    );
  }
}

class ChatbotHomeScreen extends StatefulWidget {
  const ChatbotHomeScreen({Key? key}) : super(key: key);

  @override
  State<ChatbotHomeScreen> createState() => _ChatbotHomeScreenState();
}

class _ChatbotHomeScreenState extends State<ChatbotHomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Controlador para hacer scroll y desplazarnos al final
  final ScrollController _scrollController = ScrollController();

  /// Lista de mensajes (se cargará de SharedPreferences)
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  /// Cargar mensajes guardados de SharedPreferences
  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('chatMessages');
    if (savedData != null) {
      final List<dynamic> jsonList = json.decode(savedData);
      final loadedMessages = jsonList.map((e) => ChatMessage.fromJson(e)).toList();
      setState(() {
        _messages = loadedMessages;
      });
    }

    // Si no había nada, agregamos el mensaje inicial de la AI (si deseas)
    if (_messages.isEmpty) {
      setState(() {
        _messages = [
          ChatMessage(
            text: 'Tus finanzas no van muy bien de acuerdo al plan, ¿Quieres que te muestre los detalles?',
            time: '3:57 PM',
            isUser: false,
          ),
        ];
      });
    }
  }

  /// Guardar mensajes en SharedPreferences
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _messages.map((msg) => msg.toJson()).toList();
    await prefs.setString('chatMessages', json.encode(jsonList));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.cover,
            image: Image.asset('assets/images/chat-wallpaper.jpg').image,
          ),
        ),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          child: Stack(
            children: [
              // Listado de mensajes con scroll (de abajo arriba)
              Positioned.fill(
                child: Column(
                  children: [
                    // Encabezado fijo
                    _buildHeader(),
                    // Lista de mensajes en la parte restante
                    Expanded(
                      child: _buildMessagesList(),
                    ),
                    // Barra inferior con TextField y botón
                    _buildBottomBar(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el encabezado con BackdropFilter
  Widget _buildHeader() {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: Colors.transparent,
      elevation: 1,
      child: Container(
        color: theme.primaryBackground,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 35, 0, 2),
              child: Row(
                children: [
                  InkWell(
                    onTap: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Hi there!'),
                          content: const Text('Change the action to navigate to back'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Ok'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const SizedBox(width: 50, height: 50),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Leticia AI',
                          style: theme.typography.bodyMedium,
                        ),
                        Text(
                          'Habla con tu asesora financiera personal',
                          style: theme.typography.bodyMedium.override(
                            fontFamily: 'Manrope',
                            color: theme.secondaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Hi there!'),
                          content: const Text('Change the action to navigate to back'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Ok'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const SizedBox(width: 50, height: 50),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Construye la lista de mensajes
  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      reverse: true, // para que el último mensaje quede en la parte inferior
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        // Como estamos en reverse: el item 0 es el último mensaje
        final msg = _messages[_messages.length - 1 - index];
        return msg.isUser
            ? _buildUserBubble(msg.text, msg.time)
            : _buildAiBubble(msg.text, msg.time);
      },
    );
  }

  /// Construye la barra inferior con el campo de texto y botón de enviar
  Widget _buildBottomBar() {
    final theme = FlutterFlowTheme.of(context);
    return Align(
      alignment: AlignmentDirectional(0, 1),
      child: Material(
        color: Colors.transparent,
        elevation: 1,
        child: Container(
          color: theme.primaryBackground,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 5, 0, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsetsDirectional.fromSTEB(15, 10, 0, 15),
                        child: TextFormField(
                          controller: _textController,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: 'Escribe tus preguntas...',
                            hintStyle: theme.typography.bodySmall.override(
                              fontFamily: 'Manrope',
                              color: const Color(0x81878787),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.secondaryBackground,
                          ),
                          style: theme.typography.bodyMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.send_outlined,
                        color: theme.primaryText,
                        size: 30,
                      ),
                      onPressed: _handleSendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lógica para enviar el mensaje
  void _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final timeString = DateFormat('h:mm a').format(DateTime.now());
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        time: timeString,
        isUser: true,
      ));
    });

    _textController.clear();
    _focusNode.unfocus();

    // Guardar inmediatamente el mensaje
    await _saveMessages();

    // Esperamos un frame y hacemos scroll al final
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Burbuja del usuario
  Widget _buildUserBubble(String text, String time) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 10, 15, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.7,
            ),
            decoration: BoxDecoration(
              color: theme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // AutoSizeText para texto largo
                  AutoSizeText(
                    text,
                    style: theme.typography.bodyMedium.override(
                      fontFamily: 'Manrope',
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 20,
                    minFontSize: 12,
                    overflow: TextOverflow.clip,
                    wrapWords: true,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: theme.typography.bodySmall.override(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Burbuja de la AI
  Widget _buildAiBubble(String text, String time) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 10, 15, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(13, 0, 7, 0),
            child: Container(
              width: 40,
              height: 40,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Image.asset('assets/images/chat-bot.png'),
            ),
          ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.7,
            ),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AutoSizeText(
                    text,
                    style: theme.typography.bodyMedium.override(
                      fontFamily: 'Manrope',
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 20,
                    minFontSize: 12,
                    overflow: TextOverflow.clip,
                    wrapWords: true,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: theme.typography.bodySmall.override(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
