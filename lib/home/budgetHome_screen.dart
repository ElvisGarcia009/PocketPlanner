import 'package:flutter/material.dart';
import 'planHome_screen.dart';
import 'remainingHome_screen.dart';

// Global RouteObserver para recargar datos
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class BudgetHomeScreen extends StatelessWidget {
  const BudgetHomeScreen({Key? key}) : super(key: key);

  // Top section que reemplaza el título actual
  Widget _buildTopSection() {
    return Container(
      color: const Color.fromARGB(0, 25, 118, 210), // Se mantiene transparente para que se vea el color del AppBar
      padding: const EdgeInsets.only(top: 30, bottom: 16, left: 16, right: 16),
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
    return DefaultTabController(
      length: 2,
      initialIndex: 0, // Inicia en "Plan"
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: _buildTopSection(),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: Colors.white, // Fondo blanco para la parte de los botones
              child: TabBar(
                indicator: BoxDecoration(
                  //borderRadius: BorderRadius.circular(50),
                  color: Colors.blue[900],
                ),
                indicatorSize: TabBarIndicatorSize.tab, // El indicador ocupa todo el tab
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black,
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
