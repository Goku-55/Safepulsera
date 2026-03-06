import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sensor_data_provider.dart';
// import 'realtime_sensor_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class MonitoringTabScreen extends StatelessWidget {
  const MonitoringTabScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorDataProvider>(
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
        final isAbnormal = provider.isDataAbnormal(sensorData);
        final historical = provider.historicalData;

        return SingleChildScrollView(
          child: Padding(
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
                if (isAbnormal)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Valores anormales detectados',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isAbnormal) const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _DataCard(
                      icon: Icons.favorite,
                      label: 'HR',
                      value: sensorData.hr.toStringAsFixed(1),
                      unit: 'BPM',
                      color: Colors.red,
                    ),
                    _DataCard(
                      icon: Icons.cloud,
                      label: 'SpO₂',
                      value: sensorData.spo2.toString(),
                      unit: '%',
                      color: Colors.blue,
                    ),
                    _DataCard(
                      icon: Icons.thermostat,
                      label: 'Temp',
                      value: sensorData.temperatura.toStringAsFixed(1),
                      unit: '°C',
                      color: Colors.orange,
                    ),
                    _DataCard(
                      icon: Icons.electric_bolt,
                      label: 'GSR',
                      value: sensorData.gsr.toString(),
                      unit: 'Ω',
                      color: Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Estadísticas
                FutureBuilder<Map<String, dynamic>>(
                  future: provider.getStatistics(limit: 60),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final stats = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estadísticas últimas 60 mediciones', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        _StatsRow('HR', stats['hr']),
                        _StatsRow('SpO₂', stats['spo2']),
                        _StatsRow('Temp', stats['temperatura']),
                        _StatsRow('GSR', stats['gsr']),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Historial
                const Text('Historial', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F29),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: historical.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay datos históricos', style: TextStyle(color: Colors.white38)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: historical.length,
                        itemBuilder: (context, index) {
                          final d = historical[index];
                          return ListTile(
                            leading: const Icon(Icons.history, color: Colors.teal),
                            title: Text('HR: ${d.hr.toStringAsFixed(1)} | SpO₂: ${d.spo2}% | Temp: ${d.temperatura.toStringAsFixed(1)}°C | GSR: ${d.gsr}', style: const TextStyle(color: Colors.white)),
                            subtitle: Text('Fecha: ${DateTime.fromMillisecondsSinceEpoch((d.timestamp * 1000).toInt())}', style: const TextStyle(color: Colors.white38)),
                          );
                        },
                      ),
                ),
                const SizedBox(height: 24),
                // Gráfica visual
                if (historical.isNotEmpty)
                  Container(
                    height: 220,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F29),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: historical.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.hr)).toList(),
                            isCurved: true,
                            color: Colors.red,
                            barWidth: 2,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                          ),
                          LineChartBarData(
                            spots: historical.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.spo2.toDouble())).toList(),
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 2,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                          ),
                          LineChartBarData(
                            spots: historical.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.temperatura)).toList(),
                            isCurved: true,
                            color: Colors.orange,
                            barWidth: 2,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                          ),
                          LineChartBarData(
                            spots: historical.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.gsr.toDouble())).toList(),
                            isCurved: true,
                            color: Colors.teal,
                            barWidth: 2,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (historical.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: const [
                        _LegendDot(color: Colors.red, label: 'HR'),
                        _LegendDot(color: Colors.blue, label: 'SpO₂'),
                        _LegendDot(color: Colors.orange, label: 'Temp'),
                        _LegendDot(color: Colors.teal, label: 'GSR'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
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

class _StatsRow extends StatelessWidget {
  final String label;
  final Map? stats;
  const _StatsRow(this.label, this.stats);

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const SizedBox();
    return Row(
      children: [
        Text('$label:', style: const TextStyle(color: Colors.white)),
        const SizedBox(width: 8),
        Text('Promedio: ${stats?['avg']?.toStringAsFixed(1) ?? '-'}', style: const TextStyle(color: Colors.white70)),
        const SizedBox(width: 8),
        Text('Máx: ${stats?['max']?.toStringAsFixed(1) ?? '-'}', style: const TextStyle(color: Colors.white70)),
        const SizedBox(width: 8),
        Text('Mín: ${stats?['min']?.toStringAsFixed(1) ?? '-'}', style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
