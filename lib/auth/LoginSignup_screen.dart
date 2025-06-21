import 'dart:async';
import 'package:flutter/material.dart';
import 'package:Pocket_Planner/flutterflow_components/flutterflowtheme.dart';
import 'package:Pocket_Planner/auth/auth.dart';
import 'package:Pocket_Planner/home/home_screen.dart';
import 'package:Pocket_Planner/flutterflow_components/flutterflow_tabbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Pocket_Planner/database/sqlite_management.dart';

/// Este widget reproduce la UI de FlutterFlow (tabbar con Login y SignUp)
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
    body: Container(
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
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
            Container(
              height: 590.5,
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
                padding: const EdgeInsetsDirectional.fromSTEB(10, 20, 10, 0),
                child: Column(
                  children: [
                    Align(
                      alignment: const Alignment(0, 0),
                      child: FlutterFlowButtonTabBar(
                        useToggleButtonStyle: true,
                        labelStyle: theme.typography.titleMedium.override(
                          fontFamily: 'Montserrat',
                          letterSpacing: 0.0,
                        ),
                        unselectedLabelStyle: theme.typography.titleMedium.override(
                          fontFamily: 'Montserrat',
                          letterSpacing: 0.0,
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.black,
                        backgroundColor: theme.primary,
                        unselectedBackgroundColor: const Color(0xFFA2A2A2),
                        borderWidth: 2,
                        borderRadius: 40,
                        elevation: 0,
                        buttonMargin: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
                        tabs: const [
                          Tab(text: 'Iniciar sesión'),
                          Tab(text: 'Registrarse'),
                        ],
                        controller: _tabBarController,
                        onTap: (i) async {},
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabBarController,
                        children: [
                          Align(
                            alignment: const AlignmentDirectional(0, 0),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Estás de vuelta!',
                                    textAlign: TextAlign.center,
                                    style: theme.typography.displaySmall.override(
                                      fontFamily: 'Montserrat',
                                      color: Colors.black,
                                      letterSpacing: 0.0,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(0, 12, 0, 24),
                                    child: Text(
                                      'Ingresa tus credenciales',
                                      textAlign: TextAlign.center,
                                      style: theme.typography.labelLarge.override(
                                        fontFamily: 'Montserrat',
                                        letterSpacing: 0.0,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
                                    child: Container(
                                      width: double.infinity,
                                      child: TextFormField(
                                        controller: _emailAddressTextController,
                                        autofocus: true,
                                        autofillHints: const [AutofillHints.email],
                                        obscureText: false,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          labelStyle: theme.typography.labelLarge.override(
                                            fontFamily: 'Manrope',
                                            letterSpacing: 0.0,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: const BorderSide(
                                              color: Color(0xFFF0F5F9),
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: theme.primary,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFF9F9F9),
                                        ),
                                        style: theme.typography.bodyLarge.override(
                                          fontFamily: 'Montserrat',
                                          color: Colors.black,
                                          letterSpacing: 0.0,
                                        ),
                                        keyboardType: TextInputType.emailAddress,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: TextFormField(
                                        controller: _passwordTextController,
                                        autofocus: true,
                                        obscureText: true,
                                        decoration: InputDecoration(
                                          labelText: 'Contraseña',
                                          labelStyle: theme.typography.labelLarge.override(
                                            fontFamily: 'Manrope',
                                            letterSpacing: 0.0,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: const BorderSide(
                                              color: Color(0xFFF0F5F9),
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: theme.primary,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        style: theme.typography.bodyLarge.override(
                                          fontFamily: 'Montserrat',
                                          color: Colors.black,
                                          letterSpacing: 0.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
                                    child: ElevatedButton(
                                      onPressed: _handleEmailLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'Ingresar',
                                        style: theme.typography.titleSmall.override(
                                          fontFamily: 'Montserrat',
                                          color: Colors.white,
                                          letterSpacing: 0.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
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
                                          Image.asset(
                                            'assets/images/google_logo.png', // Asegúrate de que este archivo exista
                                            height: 24,
                                          ),
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
                                ],
                              ),
                            ),
                          ),
                          Align(
                            alignment: const AlignmentDirectional(0, 0),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Crea tu cuenta de Pocket Planner',
                                    textAlign: TextAlign.center,
                                    style: theme.typography.displaySmall.override(
                                      fontFamily: 'Montserrat',
                                      color: Colors.black,
                                      fontSize: 26,
                                      letterSpacing: 0.0,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(0, 12, 0, 24),
                                    child: Text(
                                      'Empecemos registrando tus datos',
                                      textAlign: TextAlign.center,
                                      style: theme.typography.labelLarge.override(
                                        fontFamily: 'Montserrat',
                                        fontSize: 15.8,
                                        letterSpacing: 0.0,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
                                    child: Container(
                                      width: double.infinity,
                                      child: TextFormField(
                                        controller: _suEmailTextController,
                                        autofocus: true,
                                        autofillHints: const [AutofillHints.email],
                                        obscureText: false,
                                        decoration: InputDecoration(
                                          labelText: 'Email',
                                          labelStyle: theme.typography.labelLarge.override(
                                            fontFamily: 'Manrope',
                                            letterSpacing: 0.0,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: const BorderSide(
                                              color: Color(0xFFF0F5F9),
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: theme.primary,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFF9F9F9),
                                        ),
                                        style: theme.typography.bodyLarge.override(
                                          fontFamily: 'Montserrat',
                                          color: Colors.black,
                                          letterSpacing: 0.0,
                                        ),
                                        keyboardType: TextInputType.emailAddress,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
                                    child: Container(
                                      width: double.infinity,
                                      child: TextFormField(
                                        controller: _suPassTextController,
                                        autofocus: true,
                                        obscureText: true,
                                        decoration: InputDecoration(
                                          labelText: 'Contraseña',
                                          labelStyle: theme.typography.labelLarge.override(
                                            fontFamily: 'Manrope',
                                            letterSpacing: 0.0,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: const BorderSide(
                                              color: Color(0xFFF0F5F9),
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: theme.primary,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        style: theme.typography.bodyLarge.override(
                                          fontFamily: 'Montserrat',
                                          color: Colors.black,
                                          letterSpacing: 0.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
                                    child: Container(
                                      width: double.infinity,
                                      child: TextFormField(
                                        controller: _suConfirmpassTextController,
                                        autofocus: true,
                                        obscureText: true,
                                        decoration: InputDecoration(
                                          labelText: 'Confirmar contraseña',
                                          labelStyle: theme.typography.labelLarge.override(
                                            fontFamily: 'Manrope',
                                            letterSpacing: 0.0,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: const BorderSide(
                                              color: Color(0xFFF0F5F9),
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: theme.primary,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        style: theme.typography.bodyLarge.override(
                                          fontFamily: 'Montserrat',
                                          color: Colors.black,
                                          letterSpacing: 0.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
                                    child: ElevatedButton(
                                      onPressed: _handleSignUp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'Registrarse',
                                        style: theme.typography.titleSmall.override(
                                          fontFamily: 'Montserrat',
                                          color: Colors.white,
                                          letterSpacing: 0.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
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
        MaterialPageRoute(builder: (_) => const HomeScreen()),
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
      MaterialPageRoute(builder: (_) => const HomeScreen()),
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
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _showError(error);
    }
  }

  void _showError(String msg) {
    setState(() => _errorMessage = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _hideError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
      _errorAnimCtrl.reverse();
    }
  }

}


