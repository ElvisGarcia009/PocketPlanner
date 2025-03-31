import 'package:flutter/material.dart';
import 'package:pocketplanner/home/budgetHome_screen.dart'; // Importa la pantalla real de Presupuesto
import 'package:pocketplanner/home/staticsHome_screen.dart'; // Importa la pantalla real de Estadísticas
import 'package:pocketplanner/home/chatbotHome_screen.dart';
import 'package:pocketplanner/home/configHomeScreen.dart';

// Pantalla de Estadísticas (usando el widget real)
class HomeContentWidget extends StatelessWidget {
  const HomeContentWidget({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const StaticsHomeScreen(), 
    );
  }
}

class BudgetHomeWidget extends StatelessWidget {
  const BudgetHomeWidget({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const BudgetHomeScreen(), 
    );
  }
}

// Pantalla de Asesoría 
class AsesoriaPlaceholder extends StatelessWidget {
  const AsesoriaPlaceholder({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asesoría'),
      ),
      body: Container(
        alignment: Alignment.center,
        child: const Text('Pantalla de Asesoría'),
      ),
    );
  }
}

// Pantalla de Configuración
class ConfigPlaceholder extends StatelessWidget {
  const ConfigPlaceholder({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: Container(
        alignment: Alignment.center,
        child: const Text('Pantalla de Configuración'),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Lista de páginas con Scaffold
  final List<Widget> _pages = [
    const HomeContentWidget(),
    const BudgetHomeWidget(),
    const ChatbotHomeScreen(),
    const ConfigHomeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AnimatedSwitcher con tamaño forzado
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color.fromARGB(255, 255, 255, 255), // Cambia el color del icono seleccionado a azul
        unselectedItemColor: const Color.fromARGB(196, 131, 131, 131),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.query_stats_outlined),
            label: 'Estadísticas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Presupuesto',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assistant_outlined),
            label: 'Asesoría',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_sharp),
            label: 'Configuración',
          ),
        ],
      ),
    );
  }
}