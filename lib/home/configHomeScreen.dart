import 'package:Pocket_Planner/database/sqlite_management.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:Pocket_Planner/flutterflow_components/flutterflowtheme.dart';
import 'package:Pocket_Planner/flutterflow_components/flutterflow_buttons.dart';
import 'package:Pocket_Planner/auth/LoginSignup_screen.dart';

class ConfigHomeScreen extends StatefulWidget {
  const ConfigHomeScreen({super.key});

  @override
  State<ConfigHomeScreen> createState() => _ConfigHomeScreenState();
}

class _ConfigHomeScreenState extends State<ConfigHomeScreen> {
  bool mouseRegionHovered1 = false;
  bool mouseRegionHovered2 = false;
  bool mouseRegionHovered3 = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF14181B),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: AlignmentDirectional(0, 0),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 100, 0, 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/PocketPlanner-LOGO.png',
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 0, 8),
                child: Text(
                  'Opciones de cuenta',
                  style: theme.typography.labelMedium.override(
                    fontFamily: 'Montserrat',
                    color: const Color(0xFFF3F3F3),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.0,
                  ),
                ),
              ),
              _buildOption(icon: Icons.account_circle_outlined, text: 'Mi cuenta'),
              const Divider(thickness: 1, color: Color(0xFFE0E3E7)),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 0, 8),
                child: Text(
                  'Servicios de PocketPlanner',
                  style: theme.typography.labelMedium.override(
                    fontFamily: 'Montserrat',
                    color: const Color(0xFFF3F3F3),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.0,
                  ),
                ),
              ),
              _buildHoverableOption(Icons.mail_outline, 'Sincroniza tu correo electrónico', () {
                setState(() => mouseRegionHovered1 = true);
              }, () {
                setState(() => mouseRegionHovered1 = false);
              }),
              _buildHoverableOption(Icons.cloud_queue, 'Guarda tus datos en la nube', () {
                setState(() => mouseRegionHovered2 = true);
              }, () {
                setState(() => mouseRegionHovered2 = false);
              }),
              const Divider(thickness: 1, color: Color(0xFFE0E3E7)),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 0, 8),
                child: Text(
                  'Soporte',
                  style: theme.typography.labelMedium.override(
                    fontFamily: 'Montserrat',
                    color: const Color(0xFFF3F3F3),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.0,
                  ),
                ),
              ),
              _buildHoverableOption(Icons.help_outline_rounded, 'Centro de ayuda', () {
                setState(() => mouseRegionHovered3 = true);
              }, () {
                setState(() => mouseRegionHovered3 = false);
              }),
              Align(
                alignment: const AlignmentDirectional(0, 1),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 50, 24, 0),
                  child: FFButtonWidget(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      await SqliteManager.instance.close();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => AuthFlowScreen()),
                      );
                    },
                    text: 'Cerrar sesión',
                    options: FFButtonOptions(
                      width: 200,
                      height: 50,
                      color: theme.secondary,
                      textStyle: theme.typography.bodyLarge.override(
                        fontFamily: 'Montserrat',
                        color: const Color.fromARGB(255, 255, 255, 255),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.0,
                      ),
                      //borderSide: const BorderSide(color: Color(0xFFE0E3E7), width: 1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({required IconData icon, required String text}) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
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
                  letterSpacing: 0.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoverableOption(IconData icon, String text, VoidCallback onEnter, VoidCallback onExit) {
    final theme = FlutterFlowTheme.of(context);
    return MouseRegion(
      opaque: false,
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onEnter(),
      onExit: (_) => onExit(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
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
                        letterSpacing: 0.0,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}