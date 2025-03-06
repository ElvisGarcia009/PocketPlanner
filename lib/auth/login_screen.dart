import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pocketplanner/home/home_screen.dart';
import 'package:pocketplanner/auth/signup_screen.dart';
import 'package:pocketplanner/auth/auth.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  
  // Textfields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Manejo de error animado
  String? _errorMessage;
  Timer? _errorTimer;
  late AnimationController _errorAnimCtrl;
  late Animation<Offset> _errorOffset;

  @override
  void initState() {
    super.initState();
    _errorAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _errorOffset = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _errorAnimCtrl,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _errorAnimCtrl.dispose();
    _errorTimer?.cancel();
    super.dispose();
  }

  // Lógica para Login con Email
  Future<void> _handleEmailLogin() async {
    _hideError();
    final error = await AuthService.loginWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (error == null) {
      // Éxito → Ir a HomeScreen
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // Error → mostrar animación
      _showError(error);
    }
  }

  // Lógica para Login con Google
  Future<void> _handleGoogleLogin() async {
    _hideError();
    final error = await AuthService.loginWithGoogle();
    if (error == null) {
      // Éxito
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // Error
      _showError(error);
    }
  }

  // Mostrar y ocultar error
  void _showError(String msg) {
    setState(() => _errorMessage = msg);
    _errorAnimCtrl.forward(from: 0);

    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _hideError();
      }
    });
  }

  void _hideError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
      _errorAnimCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // Cierra teclado y error
        FocusScope.of(context).unfocus();
        _hideError();
      },
      child: Scaffold(
        body: SafeArea(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF0D0D0D),
                  Color(0xFF001F54),
                ],
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola',
                      style: TextStyle(
                        color: const Color(0xFFCCFF00),
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bienvenido a Pocket Planner',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 100),
                    Center(
                      child: const Text(
                        'LOGIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.transparent,
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.9),
                            width: 4,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Contraseña',
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.transparent,
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.9),
                            width: 4,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          '¿No tienes una cuenta? Regístrate aquí',
                          style: TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Boton para iniciar la sesion
                    Center(
                      child: SizedBox(
                        width: 150,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A84FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            _handleEmailLogin(); 
                          },
                          child: const Text(
                            'INGRESAR',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Espacio para el error
                    const SizedBox(height: 10),
                    AnimatedBuilder(
                      animation: _errorAnimCtrl,
                      builder: (_, __) {
                        if (_errorMessage == null &&
                            _errorAnimCtrl.isDismissed) {
                          return const SizedBox.shrink();
                        }
                        return SlideTransition(
                          position: _errorOffset,
                          child: Opacity(
                            opacity: _errorAnimCtrl.value,
                            child: Center(
                              child: Container(
                                width: 600,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red[600],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _errorMessage ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 80),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.white,
                            thickness: 1,
                            endIndent: 10,
                          ),
                        ),
                        Text(
                          'Ingresa con terceros',
                          style: TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.white,
                            thickness: 1,
                            indent: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 55),
                    // Botón de Google
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SocialButton(
                          onTap: _handleGoogleLogin,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/google_logo.png',
                                width: 30,
                                height: 30,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "Inicia sesión con Google",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
}


//  Boton para login con Google (con posibilidad de agregar Facebook y Outlook)
class _SocialButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _SocialButton({Key? key, required this.child, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, 
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }
}
