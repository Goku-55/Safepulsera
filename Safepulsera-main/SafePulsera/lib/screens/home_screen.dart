import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/weather_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<WeatherData> weatherFuture;
  final Color neonColor = const Color(0xFF00F5D4);

  @override
  void initState() {
    super.initState();
    weatherFuture = WeatherService.getWeatherData();
  }

  void _refreshWeather() {
    setState(() {
      weatherFuture = WeatherService.getWeatherData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: _buildAppBar(),
      body: FutureBuilder<WeatherData>(
        future: weatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: neonColor));
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final weather = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refreshWeather(),
            color: neonColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLocationHeader(weather.city),
                  const SizedBox(height: 20),
                  
                  // Fila de Temperatura y Humedad
                  Row(
                    children: [
                      _buildTechCard("Temperatura", "${weather.temperature.round()}°C", Icons.thermostat, Colors.orange),
                      const SizedBox(width: 15),
                      _buildTechCard("Humedad", "${weather.humidity.round()}%", Icons.water_drop, Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // NUEVA FILA: PM2.5 y PM10 con información
                  Row(
                    children: [
                      _buildInfoCard("PM2.5", "${weather.pm25.round()} µg/m³", Icons.cloud, Colors.yellow,
                        "Partículas finas en el aire\nMenores de 2.5 micras\nPueden llegar a los pulmones"),
                      const SizedBox(width: 15),
                      _buildInfoCard("PM10", "${weather.pm10.round()} µg/m³", Icons.air, Colors.red,
                        "Partículas gruesas\nMenores de 10 micras\nAfectan vías respiratorias"),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tarjeta Principal de AQI
                  _buildAQICard(weather),
                  const SizedBox(height: 20),

                  // Gráfico de Tendencia (Nueva integración)
                  _buildTrendSection(weather),
                  const SizedBox(height: 25),

                  // Detalles y Recomendaciones
                  const Text("RECOMENDACIÓN MÉDICA", style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  _buildAdviceBox(weather),
                  
                  const SizedBox(height: 25),
                  const Text("DETALLES ATMOSFÉRICOS", style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  _buildDetailsTable(weather),

                  const SizedBox(height: 25),
                  const Text("HISTORIAL DE ALERTAS", style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  _buildAlertHistory(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- COMPONENTES DE LA INTERFAZ ---

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SafeAllergy Band", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: neonColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text("Estado: Protegido", style: TextStyle(color: neonColor, fontSize: 12)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white54), onPressed: _refreshWeather),
      ],
    );
  }

  Widget _buildLocationHeader(String city) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("ENTORNO ACTUAL", style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.2)),
        Row(
          children: [
            Icon(Icons.location_on, color: neonColor, size: 14),
            const SizedBox(width: 4),
            Text(city, style: TextStyle(color: neonColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendSection(WeatherData weather) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F29),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TENDENCIA PM2.5 (24H)", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: LineChart(_getChartData(weather)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceBox(WeatherData weather) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neonColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: neonColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety, color: neonColor),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              _generateAdvice(weather.aqi),
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE APOYO ---

  LineChartData _getChartData(WeatherData weather) {
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1A1F29),
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem("${s.y} µg", TextStyle(color: neonColor, fontWeight: FontWeight.bold))).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: weather.hourlyPm25.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
          isCurved: true,
          barWidth: 3,
          color: neonColor,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: neonColor.withValues(alpha: 0.05)),
        ),
      ],
    );
  }

  String _generateAdvice(int aqi) {
    if (aqi <= 1) return "Calidad de aire óptima. Puedes realizar actividades intensas al aire libre.";
    if (aqi <= 2) return "Calidad aceptable. Si eres muy sensible, podrías notar molestias leves.";
    if (aqi <= 3) return "Nivel moderado. Se recomienda reducir el tiempo de ejercicio vigoroso en exterior.";
    return "¡Alerta! Calidad de aire insalubre. Evita salir y mantén las ventanas cerradas.";
  }

  // (Tus otros métodos _buildTechCard, _buildAQICard, _buildPollutantRow se mantienen igual pero usando .withValues(alpha: ...))
  
  // Widget de Error mejorado
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.redAccent, size: 60),
          const SizedBox(height: 15),
          Text('Error de conexión\n$error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _refreshWeather, child: const Text("Reintentar")),
        ],
      ),
    );
  }

  // ... (Siguen tus métodos de soporte anteriores con la sintaxis withValues)
  
  Widget _buildTechCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F29), 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // NUEVO: Tarjeta con información emergente
  Widget _buildInfoCard(String title, String value, IconData icon, Color color, String info) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _showInfoDialog(title, info),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F29), 
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Icon(Icons.info_outline, color: neonColor, size: 16),
                ],
              ),
              const SizedBox(height: 15),
              Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // NUEVO: Diálogo de información
  void _showInfoDialog(String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Icon(Icons.info, color: neonColor),
          ],
        ),
        content: Text(
          description,
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Entendido", style: TextStyle(color: neonColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAQICard(WeatherData weather) {
    Color aqiColor = weather.aqi <= 1 ? Colors.greenAccent : weather.aqi <= 2 ? Colors.yellowAccent : weather.aqi <= 3 ? Colors.orangeAccent : Colors.redAccent;
    return GestureDetector(
      onTap: () => _showInfoDialog(
        "¿Qué es AQI?",
        "AQI (Air Quality Index) es un índice de 1 a 5 que mide la calidad del aire:\n\n1️⃣ Excelente - Verde\n2️⃣ Bueno - Amarillo\n3️⃣ Moderado - Naranja\n4️⃣ Insalubre - Rojo\n5️⃣ Peligroso - Rojo oscuro\n\nSe calcula según PM2.5, PM10 y otros contaminantes.",
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F29),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: neonColor.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("CALIDAD DEL AIRE (AQI)", style: TextStyle(color: Colors.white54, fontSize: 11)),
                Row(
                  children: [
                    Text("${weather.aqi}/5", style: TextStyle(color: aqiColor, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Icon(Icons.info_outline, color: neonColor, size: 16),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(weather.getAQILabel(), style: TextStyle(color: aqiColor, fontSize: 32, fontWeight: FontWeight.bold)),
            const Text("Presiona para saber más", style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTable(WeatherData weather) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF1A1F29), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          _buildDetailRow("Partículas PM2.5", "${weather.pm25.toStringAsFixed(1)} µg/m³"),
          const Divider(color: Colors.white10),
          _buildDetailRow("Partículas PM10", "${weather.pm10.toStringAsFixed(1)} µg/m³"),
          const Divider(color: Colors.white10),
          _buildDetailRow("Condición", weather.description),
          const Divider(color: Colors.white10),
          _buildDetailRow("Actualizado", "${weather.timestamp.hour}:${weather.timestamp.minute.toString().padLeft(2, '0')}"),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }

  // NUEVO: Historial de alertas críticas
  Widget _buildAlertHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('clima_historial')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('❌ Error cargando historial: ${snapshot.error}');
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFF1A1F29), borderRadius: BorderRadius.circular(15)),
            child: const Text("Error cargando historial", style: TextStyle(color: Colors.red)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFF1A1F29), borderRadius: BorderRadius.circular(15)),
            child: const Center(
              child: Text("Sin alertas registradas", style: TextStyle(color: Colors.white38, fontSize: 13)),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: const Color(0xFF1A1F29), borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = (data['timestamp'] as Timestamp).toDate();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${data['ciudad']} - AQI ${data['aqi']}/5", 
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text("PM2.5: ${data['pm25'].round()} µg/m³", 
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    Text("${ts.day}/${ts.month}", style: const TextStyle(color: Colors.red, fontSize: 11)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}