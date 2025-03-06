import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pocketplanner/auth/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return WillPopScope(
      onWillPop: () async => false, // Deshabilita el retroceso del dispositivo
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // Oculta el botón de volver en el AppBar
          title: const Text('Home'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '¡Bienvenido!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Muestra el displayName si existe
              if (user != null && user.email != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Correo: ${user.email}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              const SizedBox(height: 40),
              // Botón de Cerrar Sesión
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  // En lugar de mostrar otra pantalla, regresa directamente al Login
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
