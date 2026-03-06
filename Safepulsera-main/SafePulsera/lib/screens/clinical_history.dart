import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClinicalHistoryScreen extends StatefulWidget {
  const ClinicalHistoryScreen({super.key});

  @override
  State<ClinicalHistoryScreen> createState() => _ClinicalHistoryScreenState();
}

class _ClinicalHistoryScreenState extends State<ClinicalHistoryScreen> {
  // Colores oficiales según tu diseño futurista
  final Color primaryTurquoise = const Color(0xFF00F5D4);
  final Color cardColor = const Color(0xFF1A1F2E);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17), // Fondo oscuro
      appBar: AppBar(
        title: const Text("Monitor SafeAllergy"),
        backgroundColor: primaryTurquoise,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text("Inicie sesión para ver sensores", style: TextStyle(color: Colors.white)))
          : StreamBuilder<DocumentSnapshot>(
              // Paso 7.2: Conexión con Firestore para los sensores
              stream: FirebaseFirestore.instance.collection('sensores').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryTurquoise));
                }

                // Datos integrados de tu "Propuesta sensores.pdf"
                Map<String, dynamic> datos = snapshot.data?.data() as Map<String, dynamic>? ?? {
                  'ppm': '--',      // Sensor MAX30102
                  'oxigeno': '--',  // Sensor MAX30102
                  'temp': '--',     // Sensor MLX90614
                  'gsr': '--',      // Sensor de Piel CJMCU-6701
                };

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // Indicador visual de estado
                      Icon(Icons.favorite, size: 80, color: primaryTurquoise),
                      const SizedBox(height: 20),
                      const Text(
                        "LECTURA ACTUAL DE LA BANDA",
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 30),

                      // Ritmo Cardíaco - MAX30102
                      _buildDataTile(
                        label: "Ritmo Cardíaco",
                        value: "${datos['ppm']} BPM",
                        icon: Icons.monitor_heart,
                        color: Colors.redAccent,
                        subtitle: "Detección de taquicardia",
                      ),
                      const SizedBox(height: 15),

                      // Oxigenación - MAX30102
                      _buildDataTile(
                        label: "Saturación Oxígeno",
                        value: "${datos['oxigeno']} %",
                        icon: Icons.water_drop,
                        color: Colors.blueAccent,
                        subtitle: "Monitoreo de disnea",
                      ),
                      const SizedBox(height: 15),

                      // Temperatura - MLX90614
                      _buildDataTile(
                        label: "Temp. Corporal",
                        value: "${datos['temp']} °C",
                        icon: Icons.thermostat,
                        color: Colors.orangeAccent,
                        subtitle: "Sensor Infrarrojo",
                      ),
                      const SizedBox(height: 15),

                      // Sensor de Piel (GSR) - CJMCU-6701
                      _buildDataTile(
                        label: "Estrés (GSR)",
                        value: "${datos['gsr']} µS",
                        icon: Icons.bolt,
                        color: Colors.purpleAccent,
                        subtitle: "Actividad Galvánica",
                      ),
                      
                      const SizedBox(height: 40),
                      const Divider(color: Colors.white10),
                      
                      // Usuario actual
                      ListTile(
                        leading: const Icon(Icons.person, color: Colors.white54),
                        title: const Text("Paciente", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        subtitle: Text(user.email ?? "Sin correo", style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDataTile({required String label, required String value, required IconData icon, required Color color, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor, 
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 15),
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
              Text(
                value,
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 43),
              child: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
          )
        ],
      ),
    );
  }
}