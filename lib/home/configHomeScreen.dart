import 'package:google_sign_in/google_sign_in.dart';
import 'package:pocketplanner/database/sqlite_management.dart';
import 'package:pocketplanner/services/active_budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';
import 'package:pocketplanner/flutterflow_components/flutterflow_buttons.dart';
import 'package:pocketplanner/auth/LoginSignup_screen.dart';
import 'package:pocketplanner/services/actual_currency.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ConfigHomeScreen extends StatefulWidget {
  const ConfigHomeScreen({super.key});

  @override
  State<ConfigHomeScreen> createState() => _ConfigHomeScreenState();
}

class _ConfigHomeScreenState extends State<ConfigHomeScreen>
    with SingleTickerProviderStateMixin {
  final Database _db = SqliteManager.instance.db;

  // Animación del logo
  late final AnimationController _logoController;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final AssetImage _logoImg;
  bool _logoReady = false;

  @override
  void initState() {
    super.initState();

    _logoImg = const AssetImage('assets/images/PocketPlanner-LOGO.png');
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );
    _fade = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);

    // Precarga de la imagen: cuando termina disparamos la animación
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(_logoImg, context).then((_) {
        if (mounted) {
          setState(() => _logoReady = true);
          _logoController.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  // CRUD para detalles del usuario
  Future<Map<String, dynamic>?> _readDetails(String uid) async {
    final rows = await _db.query(
      'details_tb',
      where: 'userID = ?',
      whereArgs: [uid],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Inserta o actualiza los detalles del usuario.
  Future<void> _upsertDetails({
    required String uid,
    required String username,
    required String currency,
    required int? idBudget,
  }) async {
    await _db.insert('details_tb', {
      'userID': uid,
      'user_name': username,
      'currency': currency,
      'id_budget': idBudget,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _deleteDetails(String uid) async {
    await _db.delete('details_tb', where: 'userID = ?', whereArgs: [uid]);
  }

  // UI Principal
  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final GoogleSignIn _googleSignIn = GoogleSignIn();

    return Scaffold(
      backgroundColor: const Color(0xFF14181B),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 100),

              // Logo con animación de entrada
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child:
                      (_logoReady)
                          ? FadeTransition(
                            opacity: _fade,
                            child: ScaleTransition(
                              scale: _scale,
                              child: Image(
                                image: _logoImg,
                                width: 200,
                                height: 200,
                              ),
                            ),
                          )
                          // mientras se precarga mostramos un icono cargando
                          : const SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                ),
              ),

              const SizedBox(height: 10),
              _label('Opciones de cuenta'),

              _buildOption(
                icon: Icons.account_circle_outlined,
                text: 'Mi cuenta',
                onTap: _showAccountDialog,
              ),

              const Divider(thickness: 1, color: Color(0xFFE0E3E7)),
              _label('Servicios de PocketPlanner'),

              _buildOption(
                icon: Icons.cloud_queue,
                text: 'Guarda tus datos en la nube',
                onTap: _startSyncWithConfirmation,
              ),

              const Divider(thickness: 1, color: Color(0xFFE0E3E7)),
              _label('Soporte'),

              _buildOption(
                icon: Icons.help_outline_rounded,
                text: 'Centro de ayuda',
                onTap: () {
                  _openHelpCenter();
                },
              ),

              const SizedBox(height: 50),

              Center(
                child: FFButtonWidget(
                  onPressed: () async {
                    try {
                      await _googleSignIn.signOut();
                    } catch (_) {
                      await _googleSignIn.disconnect();
                    }
                    await FirebaseAuth.instance.signOut();
                    await SqliteManager.instance.close();
                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const AuthFlowScreen(),
                        ),
                      );
                    }
                  },
                  text: 'Cerrar sesión',
                  options: FFButtonOptions(
                    width: 200,
                    height: 50,
                    color: theme.secondary,
                    textStyle: theme.typography.bodyLarge.override(
                      fontFamily: 'Montserrat',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /*      HELPS       */

  Padding _label(String title) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 0, 8),
      child: Text(
        title,
        style: theme.typography.labelMedium.override(
          fontFamily: 'Montserrat',
          color: const Color(0xFFF3F3F3),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 8),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 0, 0),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 0, 0),
                child: Text(
                  text,
                  style: theme.typography.bodyMedium.override(
                    fontFamily: 'Montserrat',
                    color: const Color(0xFFF3F3F3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialogo de cuenta

  Future<void> _showAccountDialog() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final existing = await _readDetails(uid);

    // controladores / valores iniciales
    final nameCtrl = TextEditingController(
      text: existing?['user_name'] as String? ?? '',
    );
    String currency = existing?['currency'] as String? ?? 'RD\$';

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = FlutterFlowTheme.of(ctx);

        return AlertDialog(
          backgroundColor: theme.primaryBackground,
          title: Text(
            'Detalles',
            textAlign: TextAlign.center,
            style: theme.typography.titleLarge,
          ),
          // formulario
          content: StatefulBuilder(
            builder: (ctx, setStateSB) {
              final theme = FlutterFlowTheme.of(ctx);

              InputDecoration _dec(String label) => InputDecoration(
                labelText: label,
                labelStyle: theme.typography.bodySmall.override(
                  color: theme.secondaryText,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.secondaryText),
                  borderRadius: BorderRadius.circular(4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.primary),
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre de usuario
                  TextField(
                    controller: nameCtrl,
                    decoration: _dec('Nombre de usuario'),
                    style: theme.typography.bodyMedium,
                  ),
                  const SizedBox(height: 12),

                  // Moneda
                  DropdownButtonFormField<String>(
                    value: currency,
                    decoration: _dec('Moneda'),
                    style: theme.typography.bodyMedium,
                    items: const [
                      DropdownMenuItem(value: 'RD\$', child: Text('RD\$')),
                      DropdownMenuItem(value: 'US\$', child: Text('US\$')),
                    ],
                    onChanged: (v) => setStateSB(() => currency = v ?? 'RD\$'),
                  ),
                ],
              );
            },
          ),
          // botones en una sola fila
          actionsPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 12,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Cancelar
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: theme.typography.bodySmall.override(
                      color: theme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Borrar cuenta
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed:
                      () => _handleDeleteAccount(dialogCtx: ctx, uid: uid),
                  child: Text(
                    'Borrar cuenta',
                    style: theme.typography.bodySmall.override(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Guardar
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed:
                      () => _handleSaveProfile(
                        dialogCtx: ctx,
                        uid: uid,
                        nameCtrl: nameCtrl,
                        currency: currency,
                        onDone: () {
                          ActualCurrency().change(
                            currency,
                          ); // Se actualiza el currency en toda la app
                          setState(() {});
                        },
                      ),
                  child: Text(
                    'Guardar',
                    style: theme.typography.bodySmall.override(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Sincronización con Firebase
  Future<void> _startSyncWithConfirmation() async {
    final theme = FlutterFlowTheme.of(context);

    final bool? goAhead = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(
              'Confirmar',
              textAlign: TextAlign.center,
              style: theme.typography.headlineMedium,
            ),
            content: const Text(
              'Se sincronizarán tus datos con la nube\n¿Quieres continuar?',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(
                  'Cancelar',
                  style: theme.typography.bodyMedium.override(
                    color: theme.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(
                  'Continuar',
                  style: theme.typography.bodyMedium.override(
                    color: Colors.white,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
    );

    if (goAhead == true) {
      await _syncAllDataToFirebase();
    }
  }

  Future<bool> _syncAllDataToFirebase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final int? bid = context.read<ActiveBudget>().idBudget;

    if (uid == null || bid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay sesión o presupuesto activo.')),
        );
      }
      return false;
    }

    final fs = FirebaseFirestore.instance;
    final userDoc = fs.collection('users').doc(uid);
    final budgetDoc = userDoc.collection('budgets').doc(bid.toString());

    final sectionColl = budgetDoc.collection('sections');
    final itemColl = budgetDoc.collection('items');

    final remoteSections =
        (await sectionColl.get()).docs.map((d) => d.id).toSet();
    final remoteItems = (await itemColl.get()).docs.map((d) => d.id).toSet();

    final localCards = await _db.query(
      'card_tb',
      where: 'id_budget = ?',
      whereArgs: [bid],
    );
    final localItems = await _db.rawQuery(
      'SELECT * FROM item_tb WHERE id_card IN '
      '(SELECT id_card FROM card_tb WHERE id_budget = ?)',
      [bid],
    );

    WriteBatch batch = fs.batch();
    int op = 0;

    void _commitIfFull() async {
      if (op > 400) {
        await batch.commit();
        batch = fs.batch();
        op = 0;
      }
    }

    for (final row in localCards) {
      final id = row['id_card'].toString();
      if (remoteSections.contains(id)) continue; // ya existe
      batch.set(sectionColl.doc(id), {
        'title': row['title'],
        'idCard': row['id_card'],
        'createdAt': FieldValue.serverTimestamp(),
      });
      op++;
      _commitIfFull();
    }

    for (final row in localItems) {
      final id = row['id_item'].toString();
      if (remoteItems.contains(id)) continue;
      batch.set(itemColl.doc(id), {
        'idCard': row['id_card'],
        'idCategory': row['id_category'],
        'amount': row['amount'],
        'idItemType': row['id_itemType'],
        'createdAt': FieldValue.serverTimestamp(),
      });
      op++;
      _commitIfFull();
    }

    final txColl = budgetDoc.collection('transactions');

    final remoteTxIds = (await txColl.get()).docs.map((d) => d.id).toSet();

    final localTx = await _db.query(
      'transaction_tb',
      where: 'id_budget = ?',
      whereArgs: [bid],
    );

    for (final row in localTx) {
      final id = row['id_transaction'].toString();
      if (remoteTxIds.contains(id)) continue;

      batch.set(txColl.doc(id), {
        'idCategory': row['id_category'],
        'idFrequency': row['id_frequency'],
        'amount': row['amount'],
        'idMovement': row['id_movement'],
        'date': row['date'],
        'createdAt': FieldValue.serverTimestamp(),
      });
      op++;
      _commitIfFull();
    }

    if (op > 0) await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('¡Sincronización exitosa!')));
    }
    return true;
  }

  // Maneja el guardado del perfil
  Future<void> _handleSaveProfile({
    required BuildContext dialogCtx,
    required String uid,
    required TextEditingController nameCtrl,
    required String currency,
    required VoidCallback onDone,
  }) async {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    final int? idBudget = context.read<ActiveBudget>().idBudget;

    await _upsertDetails(
      uid: uid,
      username: nameCtrl.text.trim(),
      currency: currency,
      idBudget: idBudget,
    );

    if (idBudget != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('budgets')
          .doc(idBudget.toString())
          .collection('details')
          .doc('profile')
          .set({
            'user_name': nameCtrl.text.trim(),
            'currency': currency,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }

    if (mounted) {
      Navigator.pop(dialogCtx);
      onDone(); //
    }
  }

  // Borrar cuenta (datos locales y Firestore)
  Future<void> _handleDeleteAccount({
    required BuildContext dialogCtx,
    required String uid,
  }) async {
    // 1. Pregunta final de confirmación
    final bool? confirm = await showDialog<bool>(
      context: dialogCtx,
      builder:
          (c) => AlertDialog(
            title: const Text('Confirmar'),
            content: const Text(
              '¿Seguro que deseas borrar tu cuenta y todos los datos?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Sí, borrar'),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    // 2. Borra fila de details_tb
    await _deleteDetails(uid);

    // 3. Cierra / resetea la base SQLite local
    await SqliteManager.instance.close();

    // 4. Limpia Firestore (/users/{uid}) — ignora errores si no existe
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    } catch (_) {}

    // 5. Elimina cuenta de FirebaseAuth
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (_) {
      // Si el token está “viejo” quizá necesite re-autenticación;
      // puedes manejarlo aparte si lo deseas
    }

    // 6. Llévalo de vuelta a la pantalla de login
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthFlowScreen()),
        (_) => false,
      );
    }
  }

  // Abre el centro de ayuda en el navegador
  Future<void> _openHelpCenter() async {
    const url =
        'https://docs.google.com/forms/d/e/1FAIpQLScfRd15HNGGW1aDmV1BudXRy92eivrwf9jCor5oOCPLmPk7Xg/viewform?usp=dialog';

    final ok = await launchUrlString(
      url,
      mode: LaunchMode.externalApplication, // -> usa el navegador por defecto
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el navegador.')),
      );
    }
  }
}
