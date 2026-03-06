import 'package:flutter/material.dart';
// IMPORTANTE: Asegúrate de importar home_screen.dart
import 'home_screen.dart'; 
import 'emergency_contacts_screen.dart';
import 'settings_screen.dart';
import 'registro_medico_screen.dart';
import 'sensor_simple_screen.dart';
import 'monitoring_tab_screen.dart';

class NavegacionBase extends StatefulWidget {
  const NavegacionBase({super.key});

  @override
  State<NavegacionBase> createState() => _NavegacionBaseState();
}

class _NavegacionBaseState extends State<NavegacionBase> {
  int _selectedIndex = 0;

  // --- SOLUCIÓN: CAMBIAMOS EL ORDEN DE LAS PÁGINAS ---
  final List<Widget> _paginas = [
    const HomeScreen(),                // Índice 0: AHORA ES LA IMAGEN 1 (DASHBOARD)
    const RegistroMedicoScreen(),      // Índice 1: Registro (Peso, Alergias)
    const SensorSimpleScreen(),       // Índice 2: Monitor de Sensores
    const MonitoringTabScreen(),       // Índice 3: Monitoreo en Tiempo Real
    const EmergencyContactsScreen(),    // Índice 4: Contactos
    const SettingsScreen(),             // Índice 5: Ajustes
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _paginas[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0A0E17),
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF00F5D4), 
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed, 
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view), // Cambiado a Grid para "Hoy"
            label: 'Hoy'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_ind), 
            label: 'Registro'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            label: 'Sensores'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart),
            label: 'Monitoreo'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contact_phone), 
            label: 'Contactos'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings), 
            label: 'Ajustes'
          ),
        ],
      ),
    );
  }
}