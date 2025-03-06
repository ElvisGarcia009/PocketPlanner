import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Verifica si el email tiene un formato válido
  static bool isValidEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  /// Inicia sesión con email y contraseña.
  /// Retorna `null` si todo OK.
  /// Retorna un `String` con el error si falla.
  static Future<String?> loginWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Indica éxito
    } catch (_) {
      // Podrías hacer más granular los errores, pero
      // si quieres un mensaje genérico, retornas esto:
      return 'Credenciales incorrectas, intente nuevamente';
    }
  }

  /// Inicia sesión con Google.
  /// Retorna `null` si todo OK,
  /// o un `String` con el error en caso de fallo.
  static Future<String?> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // El usuario canceló el flujo
        return 'Cancelado por el usuario';
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      return null; // Éxito
    } catch (_) {
      return 'Credenciales incorrectas, intente nuevamente';
    }
  }

  /// Registra (Sign Up) un usuario con email y password.
  /// Retorna `null` si todo OK.
  /// Retorna un `String` con la descripción del error si algo falla.
  static Future<String?> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return null; // Éxito
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
