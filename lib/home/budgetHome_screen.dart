import 'package:flutter/material.dart';
import 'planHome_screen.dart';
import 'remainingHome_screen.dart';
import '../flutterflow_components/flutterflowtheme.dart';



class BudgetHomeScreen extends StatelessWidget {
  const BudgetHomeScreen({super.key});

  // Top section que reemplaza el título actual
  Widget _buildTopSection() {
    return Container(
      color: const Color.fromARGB(0, 25, 118, 210), // Se mantiene transparente para que se vea el color del AppBar
      padding: const EdgeInsets.only(top: 30, bottom: 30, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              // Configuración
            },
          ),
          InkWell(
            onTap: () {},
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Mi Presupuesto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final theme = FlutterFlowTheme.of(context);

    return DefaultTabController(
      length: 2,
      initialIndex: 0, // Inicia en "Plan"
      child: Scaffold(
        appBar: AppBar(
            flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
              colors: [Color.fromARGB(255, 19, 36, 135), Color.fromARGB(255, 28, 55, 112)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              ),
            ),
            ),
          title: _buildTopSection(),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: theme.alternate, // Fondo blanco para la parte de los botones
              child: TabBar(
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(width: 2.0, color: const Color.fromARGB(255, 255, 255, 255)),
                ),
                indicatorSize: TabBarIndicatorSize.tab, // El indicador ocupa todo el tab
                labelColor: Colors.white,
                unselectedLabelColor: const Color.fromARGB(149, 97, 97, 97),
                labelStyle: theme.typography.bodyMedium.override(fontSize: 18),
                tabs: const [
                  Tab(text: "Plan"),
                  Tab(text: "Restante"),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            PlanHomeScreen(),       // Pantalla editable (Plan)
            RemainingHomeScreen(),  // Pantalla solo lectura (Restante)
          ],
        ),
      ),
    );
  }
}
