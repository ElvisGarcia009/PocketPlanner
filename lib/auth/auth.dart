import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      return 'Credenciales incorrectas, intente nuevamente';
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
