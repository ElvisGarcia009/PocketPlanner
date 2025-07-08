import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';

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
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Éxito
    } catch (_) {
      // Retorno genérico de error
      return 'Credenciales incorrectas, intente nuevamente';
    }
  }

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
    try {
      // Crea el usuario en Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Obtén el usuario creado
      final user = userCredential.user;
      if (user != null) {
        // Guarda en Firestore, usando el UID como ID del documento
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Si todo fue exitoso, retornamos null (sin errores)
      return null;
    } on FirebaseAuthException catch (e) {
      // Manejo de errores específicos de Firebase
      if (e.code == 'email-already-in-use') {
        return 'Este email ya está registrado en otra cuenta';
      } else if (e.code == 'weak-password') {
        return 'La contraseña debe tener al menos 6 caracteres';
      } else {
        return 'Error al registrarse: ${e.message}';
      }
    } catch (e) {
      // Cualquier otro error
      return 'Error al registrarse: $e';
    }
  }
}

//Para la funcion extraer transacciones del correo de Google
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
);

/// Autentica al usuario y envia el token a nuestra api y obtiene las transacciones del banco seleccionado.
Future<List<Map<String, dynamic>>?> authenticateUserAndFetchTransactions(
  BuildContext context,
) async {
  final theme = FlutterFlowTheme.of(context);

  // Seleccion del banco
  final bank = await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _BankPickerDialog(theme: theme),
  );
  if (bank == null) return null;

  //OAuth con Google
  final account = await _googleSignIn.signIn();
  final access = await account?.authentication;
  final token = access?.accessToken;
  if (token == null) return null;

  // Mostrar un spinner mientras se obtienen las transacciones
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final uri = Uri.parse(
      'https://pocketplanner-backend-0seo.onrender.com/transactions?bank=$bank',
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    Navigator.of(context, rootNavigator: true).pop(); // cierra spinner
    if (res.statusCode != 200) throw Exception('Error ${res.statusCode}');

    final Map<String, dynamic> body = json.decode(res.body);
    return List<Map<String, dynamic>>.from(body['transactions'] ?? []);
  } catch (e) {
    Navigator.of(context, rootNavigator: true).pop();
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
