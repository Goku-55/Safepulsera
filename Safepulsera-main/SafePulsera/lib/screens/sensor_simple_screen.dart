import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_data_provider.dart';

class SensorSimpleScreen extends StatelessWidget {
  const SensorSimpleScreen({Key? key}) : super(key: key);

  Future<void> _clearHistory(BuildContext context) async {
    final provider = Provider.of<SensorDataProvider>(context, listen: false);
    try {
      await provider.clearHistory();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historial borrado correctamente')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al borrar historial: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensores'),
        backgroundColor: const Color(0xFF1A1F29),
      ),
      backgroundColor: const Color(0xFF0A0E17),
      body: Consumer<SensorDataProvider>(
        builder: (context, provider, _) {
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text('Error: ${provider.error}'),
                ],
              ),
            );
          }

          if (provider.currentData == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00F5D4)),
                  SizedBox(height: 16),
                  Text('Conectando con sensores...', style: TextStyle(color: Colors.white)),
                ],
              ),
            );
          }

          final sensorData = provider.currentData!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: provider.isOnline ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.radio_button_checked, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        provider.isOnline ? 'EN LÍNEA' : 'FUERA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _DataCard(
                      icon: Icons.favorite,
                      label: 'Ritmo Cardíaco',
                      value: sensorData.hr.toStringAsFixed(1),
                      unit: 'BPM',
                      color: Colors.red,
                    ),
                    _DataCard(
                      icon: Icons.cloud,
                      label: 'Oxigenación',
                      value: sensorData.spo2.toString(),
                      unit: '%',
                      color: Colors.blue,
                    ),
                    _DataCard(
                      icon: Icons.thermostat,
                      label: 'Temperatura',
                      value: sensorData.temperatura.toStringAsFixed(1),
                      unit: '°C',
                      color: Colors.orange,
                    ),
                    _DataCard(
                      icon: Icons.electric_bolt,
                      label: 'Estrés (GSR)',
                      value: sensorData.gsr.toString(),
                      unit: '',
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _clearHistory(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Limpiar Historial'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _DataCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1F29),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: unit,
                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
