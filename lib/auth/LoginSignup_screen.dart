import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pocketplanner/auth/authGate.dart';
import 'package:pocketplanner/flutterflow_components/flutterflowtheme.dart';
import 'package:pocketplanner/auth/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pocketplanner/database/sqlite_management.dart';

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({super.key});

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen>
    with TickerProviderStateMixin {
  final _emailAddressTextController = TextEditingController();
  final _passwordTextController = TextEditingController();
  final _suEmailTextController = TextEditingController();
  final _suPassTextController = TextEditingController();
  final _suConfirmpassTextController = TextEditingController();
  late TabController _tabBarController;
  String? _errorMessage;
  late AnimationController _errorAnimCtrl;

  @override
  void initState() {
    super.initState();
    _tabBarController = TabController(length: 2, vsync: this);
    _errorAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _tabBarController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _emailAddressTextController.dispose();
    _errorAnimCtrl.dispose();
    super.dispose();
    _suEmailTextController.dispose();
    _suPassTextController.dispose();
    _suConfirmpassTextController.dispose();
    _tabBarController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset:
          true, // Para evitar que el teclado cubra los campos de entrada
      body: GestureDetector(
        onTap:
            () =>
                FocusScope.of(
                  context,
                ).unfocus(), // Oculta el teclado al tocar fuera de los campos de texto
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Color.fromARGB(255, 0, 36, 112)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(15, 70, 15, 0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Hola',
                          style: theme.typography.displaySmall.override(
                            fontFamily: 'Baumans',
                            color: const Color.fromARGB(255, 183, 255, 0),
                            fontSize: 50,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.0,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Bienvenido a Pocket Planner!',
                          style: theme.typography.displaySmall.override(
                            fontFamily: 'Montserrat',
                            color: Colors.white,
                            fontSize: 18,
                            letterSpacing: 0.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 4,
                          color: Color(0x33000000),
                          offset: Offset(0, 2),
                        ),
                      ],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        10,
                        20,
                        10,
                        0,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: TabBarView(
                              controller: _tabBarController,
                              children: [
                                _buildLoginTab(context),
                                _buildSignupTab(context),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //Dialogo del LogIn
  Widget _buildLoginTab(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 32, top: 10, right: 32, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Estás de vuelta!',
            textAlign: TextAlign.center,
            style: theme.typography.displaySmall.override(
              fontFamily: 'Montserrat',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ingresa tus credenciales',
            textAlign: TextAlign.center,
            style: theme.typography.labelLarge.override(
              fontFamily: 'Montserrat',
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailAddressTextController,
            autofillHints: const [AutofillHints.email],
            decoration: _inputDecoration('Email', context),
            style: _inputStyle(context),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordTextController,
            obscureText: true,
            decoration: _inputDecoration('Contraseña', context),
            style: _inputStyle(context),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handleEmailLogin,
            style: _elevatedButtonStyle(context),
            child: Text('Ingresar', style: _buttonTextStyle(context)),
          ),
          const SizedBox(height: 40),
          Text(
            'O ingresa con',
            style: theme.typography.labelLarge.override(
              fontFamily: 'Montserrat',
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _handleGoogleLogin,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDADADA), width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/google_logo.png', height: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Iniciar sesión con Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Enlace a REGISTRO
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _tabBarController.animateTo(1),
            child: Text(
              '¿Aún no tienes una cuenta?\n ¡Regístrate aquí!',
              style: theme.typography.bodyLarge.override(color: theme.primary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  //Dialogo del SignUp
  Widget _buildSignupTab(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 32, top: 10, right: 32, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Crea tu cuenta de Pocket Planner',
            textAlign: TextAlign.center,
            style: theme.typography.displaySmall.override(
              fontFamily: 'Montserrat',
              color: Colors.black,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Empecemos registrando tus datos',
            textAlign: TextAlign.center,
            style: theme.typography.labelLarge.override(
              fontFamily: 'Montserrat',
              fontSize: 15.8,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _suEmailTextController,
            autofillHints: const [AutofillHints.email],
            decoration: _inputDecoration('Email', context),
            style: _inputStyle(context),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _suPassTextController,
            obscureText: true,
            decoration: _inputDecoration('Contraseña', context),
            style: _inputStyle(context),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _suConfirmpassTextController,
            obscureText: true,
            decoration: _inputDecoration('Confirmar contraseña', context),
            style: _inputStyle(context),
          ),
          const SizedBox(height: 26),
          ElevatedButton(
            onPressed: _handleSignUp,
            style: _elevatedButtonStyle(context),
            child: Text('Registrarse', style: _buttonTextStyle(context)),
          ),

          // 🔗  Enlace a LOGIN
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _tabBarController.animateTo(0),
            child: Text(
              '¿Ya tienes una cuenta? ¡Inicia sesión!',
              style: theme.typography.bodyLarge.override(color: theme.primary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /*  AQUI VAN LOS HELPERS DE DICHOS DIALOGOS  */

  InputDecoration _inputDecoration(String label, BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: theme.typography.labelLarge.override(fontFamily: 'Manrope'),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFF0F5F9), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: theme.primary, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: const Color(0xFFF9F9F9),
    );
  }

  TextStyle _inputStyle(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return theme.typography.bodyLarge.override(
      fontFamily: 'Montserrat',
      color: Colors.black,
    );
  }

  ButtonStyle _elevatedButtonStyle(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ElevatedButton.styleFrom(
      backgroundColor: theme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  TextStyle _buttonTextStyle(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return theme.typography.titleSmall.override(
      fontFamily: 'Montserrat',
      color: Colors.white,
    );
  }

  Future<void> _handleGoogleLogin() async {
    _hideError();
    final error = await AuthService.loginWithGoogle();
    if (error == null) {
      // Sesion exitosa e inicializacion de sqlite
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await SqliteManager.instance.initDbForUser(uid);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    } else {
      // Error
      _showError(error);
    }
  }

  Future<void> _handleEmailLogin() async {
    final email = _emailAddressTextController.text.trim();
    final pass = _passwordTextController.text.trim();

    final error = await AuthService.loginWithEmail(email, pass);
    if (error == null) {
      // Sesion exitosa e inicializacion de sqlite
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await SqliteManager.instance.initDbForUser(uid);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    } else {
      _showError(error);
    }
  }

  Future<void> _handleSignUp() async {
    final email = _suEmailTextController.text.trim();
    final pass = _suPassTextController.text.trim();
    final conf = _suConfirmpassTextController.text.trim();

    if (pass != conf) {
      _showError('Las contraseñas no coinciden');
      return;
    }

    final error = await AuthService.signUp(email, pass);
    if (error == null) {
      // Sesion exitosa e inicializacion de sqlite
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await SqliteManager.instance.initDbForUser(uid);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    } else {
      _showError(error);
    }
  }

  void _showError(String msg) {
    setState(() => _errorMessage = msg);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _hideError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
      _errorAnimCtrl.reverse();
    }
  }
}
