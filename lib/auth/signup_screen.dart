import 'package:flutter/material.dart';
import 'package:pocketplanner/home/home_screen.dart';
import 'package:pocketplanner/auth/auth.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with TickerProviderStateMixin {
  // Controladores de texto
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Variables para guardar mensajes de error
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  // Animations Controllers y sus respectivos offsets (SlideTransitions) para cada error
  late AnimationController _emailErrorAnimCtrl;
  late Animation<Offset> _emailErrorOffset;

  late AnimationController _passwordErrorAnimCtrl;
  late Animation<Offset> _passwordErrorOffset;

  late AnimationController _confirmErrorAnimCtrl;
  late Animation<Offset> _confirmErrorOffset;

  @override
  void initState() {
    super.initState();

    // Duración de la animación
    const duration = Duration(milliseconds: 300);

    // Configuramos cada AnimationController y sus Tween<Offset>
    _emailErrorAnimCtrl = AnimationController(vsync: this, duration: duration);
    _emailErrorOffset = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _emailErrorAnimCtrl, curve: Curves.easeOut));

    _passwordErrorAnimCtrl = AnimationController(vsync: this, duration: duration);
    _passwordErrorOffset = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _passwordErrorAnimCtrl, curve: Curves.easeOut));

    _confirmErrorAnimCtrl = AnimationController(vsync: this, duration: duration);
    _confirmErrorOffset = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _confirmErrorAnimCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _emailErrorAnimCtrl.dispose();
    _passwordErrorAnimCtrl.dispose();
    _confirmErrorAnimCtrl.dispose();
    super.dispose();
  }

  //         METODO PRINCIPAL DE REGISTRO (Sign Up)

  Future<void> _signUp() async {
    // Limpiamos posibles errores previos
    _dismissAllErrors();

    // Validar email localmente
    if (!AuthService.isValidEmail(_emailController.text.trim())) {
      _showEmailError('Formato inválido en el email');
      return;
    }

    // Validar contraseñas iguales
    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      _showConfirmError('Las contraseñas no coinciden');
      return;
    }

    // Validar longitud >= 6
    if (_passwordController.text.trim().length < 6) {
      _showPasswordError('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    // Llamamos a AuthService para crear el usuario
    final error = await AuthService.signUp(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (error == null) {
      // Éxito → Navegamos a HomeScreen
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // Hubo un error, lo mostramos donde corresponda
      // Nota: en auth.dart decidiste un mensaje genérico o uno específico
      //       como "email-already-in-use" => "Este email ya está registrado..."
      // Decidamos a cuál error se refiere
      if (error.contains('ya está registrado')) {
        _showEmailError(error); // "Este email ya está registrado en otra cuenta"
      } else if (error.contains('6 caracteres')) {
        _showPasswordError(error); // "La contraseña debe tener al menos 6 caracteres"
      } else {
        // error genérico
        _showEmailError(error);
      }
    }
  }

  // -----------------------------------------------------------
  //   MOSTRAR / OCULTAR ERRORES (con animaciones)
  // -----------------------------------------------------------
  void _showEmailError(String msg) {
    setState(() {
      _emailError = msg;
      _emailErrorAnimCtrl.forward();
    });
  }

  void _hideEmailError() {
    if (_emailError != null) {
      setState(() => _emailError = null);
      _emailErrorAnimCtrl.reverse();
    }
  }

  void _showPasswordError(String msg) {
    setState(() {
      _passwordError = msg;
      _passwordErrorAnimCtrl.forward();
    });
  }

  void _hidePasswordError() {
    if (_passwordError != null) {
      setState(() => _passwordError = null);
      _passwordErrorAnimCtrl.reverse();
    }
  }

  void _showConfirmError(String msg) {
    setState(() {
      _confirmError = msg;
      _confirmErrorAnimCtrl.forward();
    });
  }

  void _hideConfirmError() {
    if (_confirmError != null) {
      setState(() => _confirmError = null);
      _confirmErrorAnimCtrl.reverse();
    }
  }

  // Cierra todos los errores a la vez
  void _dismissAllErrors() {
    _hideEmailError();
    _hidePasswordError();
    _hideConfirmError();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // Al tocar en cualquier parte, cerramos teclado y errores
        FocusScope.of(context).unfocus();
        _dismissAllErrors();
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
                  Color(0xFF0D0D0D), // Negro/azul oscuro arriba
                  Color(0xFF001F54), // Azul más claro abajo
                ],
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "Hola"
                    Text(
                      'Hola',
                      style: TextStyle(
                        color: const Color(0xFFCCFF00),
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // "Bienvenido a Pocket Planner"
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
                        'SIGN UP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // -----------------------
                    //     EMAIL + ERROR
                    // -----------------------
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          onTap: () {
                            _hidePasswordError();
                            _hideConfirmError();
                          },
                        ),
                        // Animación de error de email
                        AnimatedBuilder(
                          animation: _emailErrorAnimCtrl,
                          builder: (_, __) {
                            if (_emailError == null && _emailErrorAnimCtrl.isDismissed) {
                              return const SizedBox.shrink();
                            }
                            return SlideTransition(
                              position: _emailErrorOffset,
                              child: Opacity(
                                opacity: _emailErrorAnimCtrl.value,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _emailError ?? '',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // -----------------------
                    //   PASSWORD + ERROR
                    // -----------------------
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          onTap: () {
                            _hideEmailError();
                            _hideConfirmError();
                          },
                        ),
                        // Animación de error de password
                        AnimatedBuilder(
                          animation: _passwordErrorAnimCtrl,
                          builder: (_, __) {
                            if (_passwordError == null && _passwordErrorAnimCtrl.isDismissed) {
                              return const SizedBox.shrink();
                            }
                            return SlideTransition(
                              position: _passwordErrorOffset,
                              child: Opacity(
                                opacity: _passwordErrorAnimCtrl.value,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _passwordError ?? '',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // -----------------------
                    //  CONFIRM + ERROR
                    // -----------------------
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Confirmar Contraseña',
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
                          onTap: () {
                            _hideEmailError();
                            _hidePasswordError();
                          },
                        ),
                        // Animación de error de confirm
                        AnimatedBuilder(
                          animation: _confirmErrorAnimCtrl,
                          builder: (_, __) {
                            if (_confirmError == null && _confirmErrorAnimCtrl.isDismissed) {
                              return const SizedBox.shrink();
                            }
                            return SlideTransition(
                              position: _confirmErrorOffset,
                              child: Opacity(
                                opacity: _confirmErrorAnimCtrl.value,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _confirmError ?? '',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          '¿Ya tienes una cuenta? Inicia sesión aquí',
                          style: TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Botón REGISTRARSE
                    Center(
                      child: SizedBox(
                        width: 180,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A84FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          onPressed: _signUp,
                          child: const Text(
                            'REGISTRARSE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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
