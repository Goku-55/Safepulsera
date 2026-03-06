import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'wifi_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _cerrarSesion() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cerrar sesión: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _agregarCuenta() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0E17),
        title: const Text('Agregar Cuenta', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Deseas crear una nueva cuenta? Se abrirá la pantalla de registro.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/register');
            },
            child: const Text('Ir a Registro', style: TextStyle(color: Color(0xFF00F5D4))),
          ),
        ],
      ),
    );
  }

  void _cambiarCuenta() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0E17),
        title: const Text('Cambiar Cuenta', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Para cambiar de cuenta, primero debes cerrar sesión y luego iniciar con otra cuenta.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cerrarSesion();
            },
            child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          const Text(
            'Gestión de Cuenta',
            style: TextStyle(
              color: Color(0xFF00F5D4),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildOptionCard(
            icon: Icons.person_add,
            title: 'Agregar Cuenta',
            subtitle: 'Añadir una nueva cuenta de usuario',
            onTap: _agregarCuenta,
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            icon: Icons.person_pin,
            title: 'Cambiar Cuenta',
            subtitle: 'Cambiar a otra cuenta registrada',
            onTap: _cambiarCuenta,
          ),
          const SizedBox(height: 12),
          _buildOptionCard(
            icon: Icons.logout,
            title: 'Cerrar Sesión',
            subtitle: 'Cerrar sesión y volver a login',
            onTap: _cerrarSesion,
            isDestructive: true,
          ),
          const SizedBox(height: 40),
          const Divider(color: Colors.white10),
          const SizedBox(height: 20),
          const Text(
            'Dispositivos',
            style: TextStyle(
              color: Color(0xFF00F5D4),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildOptionCard(
            icon: Icons.router,
            title: 'Configurar WiFi ESP32',
            subtitle: 'Conectar ESP32 a tu red WiFi',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WiFiSettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 40),
          const Divider(color: Colors.white10),
          const SizedBox(height: 20),
          const Text(
            'Información',
            style: TextStyle(
              color: Color(0xFF00F5D4),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoField('Email', FirebaseAuth.instance.currentUser?.email ?? 'No disponible'),
          const SizedBox(height: 12),
          _buildInfoField('UID', FirebaseAuth.instance.currentUser?.uid ?? 'No disponible'),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDestructive ? Colors.red.withValues(alpha: 0.5) : const Color(0xFF00F5D4).withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red : const Color(0xFF00F5D4),
          size: 28,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.red : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isDestructive ? Colors.red : const Color(0xFF00F5D4),
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF00F5D4).withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}