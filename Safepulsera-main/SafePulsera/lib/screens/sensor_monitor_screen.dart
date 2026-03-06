import 'package:flutter/material.dart';
import '../services/sensor_firebase_service.dart';

class SensorMonitorScreen extends StatefulWidget {
  const SensorMonitorScreen({super.key});

  @override
  State<SensorMonitorScreen> createState() => _SensorMonitorScreenState();
}

class _SensorMonitorScreenState extends State<SensorMonitorScreen> {
  int _hr = 0;
  int _spo2 = 0;
  double _temperature = 0.0;
  int _gsr = 0;
  String _status = "Conectando...";
  final List<String> _logs = [];

  void _clearLogs() {
    setState(() => _logs.clear());
  }

  String _getStressLevel(int gsr) {
    if (gsr < 500) return "😌 Relajado";
    if (gsr < 1000) return "😐 Normal";
    if (gsr < 1500) return "😟 Algo estresado";
    return "😰 Muy estresado";
  }

  String _getHealthStatus(int hr, int spo2, double temp) {
    List<String> warnings = [];
    
    if (hr > 120 || hr < 50) warnings.add("❤️ FC anormal");
    if (spo2 < 95 && spo2 > 0) warnings.add("🫁 SpO2 bajo");
    if (temp > 38 || temp < 35) warnings.add("🌡️ Temp anormal");
    
    if (warnings.isEmpty) return "✅ Normal";
    return warnings.join(" | ");
  }

  void _updateLogs() {
    _logs.add(
      "${DateTime.now().toLocal().toString().split('.')[0]} - HR: $_hr | SpO2: $_spo2% | Temp: ${_temperature.toStringAsFixed(1)}°C | GSR: $_gsr"
    );
    if (_logs.length > 50) _logs.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F29),
        title: const Text("🏥 Monitor de Salud"),
        elevation: 0,
      ),
      body: StreamBuilder<int>(
        stream: SensorFirebaseService.getHeartRateStream(),
        builder: (context, hrSnapshot) {
          if (hrSnapshot.hasData) {
            _hr = hrSnapshot.data ?? 0;
            _status = "✅ Conectado (WiFi)";
          }

          return StreamBuilder<int>(
            stream: SensorFirebaseService.getSpO2Stream(),
            builder: (context, spo2Snapshot) {
              if (spo2Snapshot.hasData) {
                _spo2 = spo2Snapshot.data ?? 0;
              }

              return StreamBuilder<double>(
                stream: SensorFirebaseService.getTemperatureStream(),
                builder: (context, tempSnapshot) {
                  if (tempSnapshot.hasData) {
                    _temperature = tempSnapshot.data ?? 0.0;
                  }

                  return StreamBuilder<int>(
                    stream: SensorFirebaseService.getGSRStream(),
                    builder: (context, gsrSnapshot) {
                      if (gsrSnapshot.hasData) {
                        _gsr = gsrSnapshot.data ?? 0;
                        _updateLogs();
                      }

                      return SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // ===== Estado de Conexión =====
                              Card(
                                color: const Color(0xFF1A1F29),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Estado:",
                                        style: TextStyle(fontSize: 14, color: Colors.white70),
                                      ),
                                      Text(
                                        _status,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ===== Tarjeta de Salud General =====
                              Card(
                                color: const Color(0xFF1A1F29),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    _getHealthStatus(_hr, _spo2, _temperature),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ===== Grid de 4 Sensores =====
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                children: [
                                  // Ritmo Cardíaco
                                  _buildSensorCard(
                                    title: "❤️ Ritmo Cardíaco",
                                    value: "$_hr",
                                    unit: "BPM",
                                    color: Colors.red,
                                    bgColor: const Color(0xFF2A1A1A),
                                  ),
                                  // SpO2
                                  _buildSensorCard(
                                    title: "🫁 Oxigenación",
                                    value: "$_spo2",
                                    unit: "%",
                                    color: Colors.blue,
                                    bgColor: const Color(0xFF1A1F2A),
                                  ),
                                  // Temperatura
                                  _buildSensorCard(
                                    title: "🌡️ Temperatura",
                                    value: _temperature.toStringAsFixed(1),
                                    unit: "°C",
                                    color: Colors.orange,
                                    bgColor: const Color(0xFF2A1F1A),
                                  ),
                                  // GSR (Estrés)
                                  _buildSensorCard(
                                    title: "⚡ Estrés (GSR)",
                                    value: "$_gsr",
                                    unit: "",
                                    color: Colors.cyan,
                                    bgColor: const Color(0xFF1A2A2A),
                                    subtitle: _getStressLevel(_gsr),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // ===== Botón de Limpiar Logs =====
                              ElevatedButton.icon(
                                onPressed: _clearLogs,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text("Limpiar Historial"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ===== Histórico de Datos =====
                              Card(
                                color: const Color(0xFF1A1F29),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Histórico (${_logs.length})",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0A0E17),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: _logs.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  "📡 Esperando datos del ESP32...",
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(color: Colors.white54),
                                                ),
                                              )
                                            : ListView.builder(
                                                reverse: true,
                                                itemCount: _logs.length,
                                                itemBuilder: (context, index) {
                                                  final log = _logs[_logs.length - 1 - index];
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                      horizontal: 8,
                                                    ),
                                                    child: Text(
                                                      log,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontFamily: 'Courier',
                                                        color: Color(0xFF00F5D4),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSensorCard({
    required String title,
    required String value,
    required String unit,
    required Color color,
    required Color bgColor,
    String? subtitle,
  }) {
    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.7),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
