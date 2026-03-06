import 'package:flutter/material.dart';
import '../services/firebase_sensor_service.dart';

class RealtimeSensorDisplay extends StatefulWidget {
  const RealtimeSensorDisplay({Key? key}) : super(key: key);

  @override
  State<RealtimeSensorDisplay> createState() => _RealtimeSensorDisplayState();
}

class _RealtimeSensorDisplayState extends State<RealtimeSensorDisplay> {
  late FirebaseSensorService _sensorService;

  @override
  void initState() {
    super.initState();
    _sensorService = FirebaseSensorService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeAllergy - Monitoreo en Tiempo Real'),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<SensorData?>(
        stream: _sensorService.getSensorDataStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Conectando con ESP32...'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('No hay datos disponibles'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final sensorData = snapshot.data!;
          final isOnline = sensorData.status == 'active';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Status Card
                  Card(
                    color: isOnline ? Colors.green : Colors.red,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isOnline ? Icons.check_circle : Icons.error,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOnline ? 'Dispositivo EN LÍNEA' : 'Dispositivo FUERA DE LÍNEA',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sensor Cards Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _SensorCard(
                        icon: Icons.favorite,
                        label: 'Ritmo Cardíaco',
                        value: sensorData.hr.toStringAsFixed(1),
                        unit: 'BPM',
                        color: Colors.red,
                        minValue: 60,
                        maxValue: 100,
                        currentValue: sensorData.hr,
                      ),
                      _SensorCard(
                        icon: Icons.cloud,
                        label: 'SpO₂',
                        value: sensorData.spo2.toString(),
                        unit: '%',
                        color: Colors.blue,
                        minValue: 95,
                        maxValue: 100,
                        currentValue: sensorData.spo2.toDouble(),
                      ),
                      _SensorCard(
                        icon: Icons.thermostat,
                        label: 'Temperatura',
                        value: sensorData.temperatura.toStringAsFixed(1),
                        unit: '°C',
                        color: Colors.orange,
                        minValue: 36,
                        maxValue: 37.5,
                        currentValue: sensorData.temperatura,
                      ),
                      _SensorCard(
                        icon: Icons.electric_bolt,
                        label: 'GSR',
                        value: '${sensorData.gsr}',
                        unit: 'Ω',
                        color: Colors.purple,
                        minValue: 0,
                        maxValue: 1000,
                        currentValue: sensorData.gsr.toDouble(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Device Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Información del Dispositivo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _InfoRow('ID Dispositivo', sensorData.deviceId),
                          _InfoRow(
                            'Última Sincronización',
                            _formatTimestamp(sensorData.timestamp),
                          ),
                          _InfoRow('Estado', sensorData.status),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Statistics Section
                  _StatisticsSection(sensorService: _sensorService),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(double timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    return '${date.hour}:${date.minute}:${date.second}';
  }
}

class _SensorCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final double minValue;
  final double maxValue;
  final double currentValue;

  const _SensorCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.minValue,
    required this.maxValue,
    required this.currentValue,
  });

  bool _isAbnormal() {
    return currentValue < minValue || currentValue > maxValue;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isAbnormal() ? Colors.red : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _isAbnormal() ? Colors.red : Colors.black,
                      ),
                    ),
                    TextSpan(
                      text: ' ${unit}Unit',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_isAbnormal())
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.warning, size: 16, color: Colors.red),
                    SizedBox(width: 4),
                    Text(
                      'Anormal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StatisticsSection extends StatelessWidget {
  final FirebaseSensorService sensorService;

  const _StatisticsSection({required this.sensorService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: sensorService.getStatistics(limit: 60),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Cargando estadísticas...'));
        }

        final stats = snapshot.data!;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estadísticas (Últimos 60 datos)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _StatRow('HR Promedio', '${(stats['hr']['avg'] as double).toStringAsFixed(1)} BPM'),
                _StatRow('SpO₂ Promedio', '${(stats['spo2']['avg'] as double).toStringAsFixed(1)}%'),
                _StatRow('Temp Promedio', '${(stats['temperatura']['avg'] as double).toStringAsFixed(1)}°C'),
                _StatRow('Total mediciones', '${stats['count']} registros'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
