import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_data_provider.dart';
import 'realtime_sensor_screen.dart';

class HomeScreenWithRealtime extends StatefulWidget {
  const HomeScreenWithRealtime({Key? key}) : super(key: key);

  @override
  State<HomeScreenWithRealtime> createState() => _HomeScreenWithRealtimeState();
}

class _HomeScreenWithRealtimeState extends State<HomeScreenWithRealtime> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeAllergy - Monitoreo'),
        elevation: 0,
      ),
      body: Consumer<SensorDataProvider>(
        builder: (context, provider, _) {
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${provider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (provider.currentData == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Esperando datos del ESP32...'),
                ],
              ),
            );
          }

          final sensorData = provider.currentData!;
          final isAbnormal = provider.isDataAbnormal(sensorData);

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: provider.isOnline ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.radio_button_checked,
                            color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          provider.isOnline ? 'Dispositivo EN LÍNEA' : 'Dispositivo FUERA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isAbnormal)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Valores Anormales Detectados',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                Text(
                                  'Verifica los valores en el monitoreo completo',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
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
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _QuickDataCard(
                        icon: Icons.favorite,
                        label: 'HR',
                        value: sensorData.hr.toStringAsFixed(1),
                        unit: 'BPM',
                        color: Colors.red,
                      ),
                      _QuickDataCard(
                        icon: Icons.cloud,
                        label: 'SpO₂',
                        value: sensorData.spo2.toString(),
                        unit: '%',
                        color: Colors.blue,
                      ),
                      _QuickDataCard(
                        icon: Icons.thermostat,
                        label: 'Temp',
                        value: sensorData.temperatura.toStringAsFixed(1),
                        unit: '°C',
                        color: Colors.orange,
                      ),
                      _QuickDataCard(
                        icon: Icons.electric_bolt,
                        label: 'GSR',
                        value: sensorData.gsr.toString(),
                        unit: 'Ω',
                        color: Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RealtimeSensorDisplay(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.monitor_heart),
                      label: const Text('Monitoreo Completo'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickDataCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _QuickDataCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
