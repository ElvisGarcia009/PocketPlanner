import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';
import 'package:pocketplanner/services/active_budget.dart';
import 'package:pocketplanner/services/date_range.dart';
import 'package:provider/provider.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Verifica si el email tiene un formato válido
  static bool isValidEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  /// Inicia sesión con email y contraseña.
  static Future<String?> loginWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      //  Bloquea la entrada si el correo NÃO está verificado
      if (!cred.user!.emailVerified) {
        await _auth.signOut(); // fuerza cierre de sesión
        return 'Tu correo aún no ha sido verificado. Revisa tu bandeja de entrada o spam.';
      }

      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': true,
        });
      }

      return null; // éxito
    } on FirebaseAuthException catch (e) {
      print("ERRORRRRRR  " + e.code);
      return firebaseErrorMessages[e.code] ??
          'Ocurrió un error al iniciar sesión. Intenta nuevamente.';
    } catch (_) {
      return 'Error desconocido al iniciar sesión.';
    }
  }

  static Future<String?> sendPasswordReset(String email) async {
    if (!isValidEmail(email)) {
      return 'Debes ingresar un correo electrónico válido';
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // todo OK
    } on FirebaseAuthException catch (e) {
      return firebaseErrorMessages[e.code] ??
          'No se pudo enviar el enlace. Intenta nuevamente.';
    } catch (_) {
      return 'Error inesperado al enviar el enlace.';
    }
  }

  // Errores principales
  static Map<String, String> firebaseErrorMessages = {
    'invalid-email': 'El correo electrónico no es válido.',
    'user-disabled': 'Esta cuenta ha sido deshabilitada.',
    'user-not-found': 'No se encontró una cuenta con este correo.',
    'wrong-password': 'La contraseña es incorrecta.',
    'invalid-credential': 'Credenciales incorrectas o usuario no encontrado',
    'channel-error': 'Por favor llena todos los campos',
    'email-already-in-use': 'Este correo ya está registrado en otra cuenta.',
    'weak-password': 'La contraseña debe tener al menos 6 caracteres.',
    'operation-not-allowed': 'Esta operación no está permitida.',
    'too-many-requests': 'Demasiados intentos. Intenta más tarde.',
  };

  /// Inicia sesión con Google.
  static Future<String?> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // El usuario canceló el flujo de Google
        return 'Cancelado por el usuario';
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Inicia sesión en Firebase con las credenciales de Google
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Verifica en Firestore si el usuario ya existe
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final docSnapshot = await userDocRef.get();

        if (!docSnapshot.exists) {
          // No existe, así que lo insertamos en la colección 'users'
          await userDocRef.set({
            'uid': user.uid,
            'email': user.email,
            'displayName': user.displayName,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return null; // Éxito total
    } catch (_) {
      return 'No se ha podido ingresar sesión con Google...';
    }
  }

  /// Registra (Sign Up) un usuario con email y contraseña.
  static Future<String?> signUp(String email, String password) async {
    if (!isValidEmail(email)) {
      return 'Debes ingresar un correo electrónico válido';
    }

    try {
      // 1. Crea el usuario
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await user.sendEmailVerification();
        await _auth.signOut();
      }

      return null; // todo OK
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'Este email ya está registrado en otra cuenta';
      } else if (e.code == 'weak-password') {
        return 'La contraseña debe tener al menos 6 caracteres';
      } else {
        return 'Error al registrarse: ${e.message}';
      }
    } catch (e) {
      return 'Error al registrarse: $e';
    }
  }
}

Future<bool> _checkInternet() async {
  try {
    final result = await InternetAddress.lookup('ejemplo.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
}

final _googleSignIn = GoogleSignIn(
  scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
  serverClientId:
      '20828963238-m8l6rcvp4aj274j49q7bqubv5uklmtau.apps.googleusercontent.com',
);

/// Autentica al usuario y envia el token a nuestra api para obtiene las transacciones del banco seleccionado.
Future<List<Map<String, dynamic>>?> authenticateUserAndFetchTransactions(
  BuildContext context,
) async {
  
  //Chequeamos si hay internet
  final connected = await _checkInternet();
  if (!connected) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Debes tener conexión a internet')),
    );
    return null;
  }

  // 1) ––– Banco –––
  final bank = await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _BankPickerDialog(theme: FlutterFlowTheme.of(context)),
  );
  if (bank == null) return null; // usuario canceló

  try {
    // 2) ––– Google Sign-In –––

    final account = await _googleSignIn.signIn();
    if (account == null) return null; // usuario canceló
    final token = (await account.authentication).accessToken;
    if (token == null) return null; // algo falló

    // 3) ––– periodo activo –––
    final bid = context.read<ActiveBudget>().idBudget;
    if (bid == null) throw 'No hay periodo activo';
    final range = await periodRangeForBudget(bid);
    if (range == PeriodRange.empty) throw 'No hay periodo activo';

    final after = DateFormat('yyyy/MM/dd').format(range.start);
    final before = DateFormat('yyyy/MM/dd').format(range.end);

    // 4) Mostrar un spinner de carga mientras se ejecuta
    bool dialogShown = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        dialogShown = true;
        return const Center(child: CircularProgressIndicator());
      },
    );

    // 5) ––– llamada HTTPS –––
    final uri = Uri.parse(
      'https://pocketplanner-backend-0seo.onrender.com/transactions'
      '?bank=$bank&after=$after&before=$before',
    );

    print('banco: ' + bank + " after: " + after + " before: " + before);

    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (dialogShown)
      Navigator.of(context, rootNavigator: true).pop(); // cierra spinner

    if (res.statusCode != 200) throw 'Error HTTP ${res.statusCode}';
    final body = json.decode(res.body) as Map<String, dynamic>;

    print(body);
    return List<Map<String, dynamic>>.from(body['transactions'] ?? []);
  } catch (e) {
    // si el spinner sigue visible lo cerramos:
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error importando: $e')));
    return null;
  }
}

//Dialogo para seleccionar el banco
class _BankPickerDialog extends StatelessWidget {
  const _BankPickerDialog({required this.theme});
  final FlutterFlowThemeData theme;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'Selecciona el banco',
      style: theme.typography.titleLarge,
      textAlign: TextAlign.center,
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bankTile(
          context,
          'Banco Popular',
          'assets/images/popular_logo.jpg',
          'popular',
        ),
        const SizedBox(height: 10),
        _bankTile(
          context,
          'Banco Banreservas',
          'assets/images/banreservas_logo.png',
          'banreservas',
        ),
      ],
    ),
    actions: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              textStyle: theme.typography.bodyMedium,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    ],
  );

  Widget _bankTile(BuildContext ctx, String txt, String img, String val) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListTile(
          leading: Image.asset(img, width: 40),
          title: Text(
            txt,
            style: theme.typography.bodyLarge.copyWith(color: Colors.black),
          ),
          onTap: () => Navigator.pop(ctx, val),
        ),
      );
}
