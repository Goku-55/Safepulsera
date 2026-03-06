import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class WiFiConfigScreen extends StatefulWidget {
  const WiFiConfigScreen({super.key});

  @override
  State<WiFiConfigScreen> createState() => _WiFiConfigScreenState();
}

class _WiFiConfigScreenState extends State<WiFiConfigScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  String _status = "Listo para configurar";
  bool _isLoading = false;
  bool _showPassword = false;
  String? _savedSSID;
  String? _savedPassword;

  @override
  void initState() {
    super.initState();
    _loadSavedWiFiConfig();
  }

  void _loadSavedWiFiConfig() async {
    try {
      final snapshot = await _database.ref('wifi_config').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _savedSSID = data['ssid'] ?? '';
          _savedPassword = data['password'] ?? '';
          _ssidController.text = _savedSSID ?? '';
          _passwordController.text = _savedPassword ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error cargando config: $e');
    }
  }

  void _saveWiFiConfig() async {
    if (_ssidController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _status = "❌ Completa SSID y contraseña");
      return;
    }

    setState(() {
      _isLoading = true;
      _status = "⏳ Guardando configuración...";
    });

    try {
      // Guardar en Firebase
      await _database.ref('wifi_config').set({
        'ssid': _ssidController.text,
        'password': _passwordController.text,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      setState(() {
        _status = "✅ Configuración guardada";
        _savedSSID = _ssidController.text;
        _savedPassword = _passwordController.text;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ WiFi configurado. El ESP32 se reconectará pronto.'),
          backgroundColor: Colors.green,
        ),
      );

      // Limpiar después de 2 segundos
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = "❌ Error: $e";
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F29),
        title: const Text("⚙️ Configuración WiFi (ESP32)"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== Información =====
              Card(
                color: const Color(0xFF1A1F29),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "📡 Información",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyan,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Aquí puedes configurar el WiFi del ESP32-CAM. Una vez guardado, el dispositivo se reconectará automáticamente a la nueva red.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0E17),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange, width: 1),
                        ),
                        child: const Text(
                          "⚠️ El ESP32 debe estar conectado. La configuración se envía por Firebase.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ===== Estado Actual =====
              if (_savedSSID != null && _savedSSID!.isNotEmpty)
                Card(
                  color: const Color(0xFF1A2A1A),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "📶 WiFi Actual en ESP32",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              "Red: ",
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _savedSSID ?? "---",
                                style: const TextStyle(
                                  color: Colors.cyan,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              "Pass: ",
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _showPassword
                                    ? (_savedPassword ?? "---")
                                    : ("*" * (_savedPassword?.length ?? 0)),
                                style: const TextStyle(
                                  color: Colors.cyan,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() => _showPassword = !_showPassword);
                              },
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // ===== Formulario =====
              const Text(
                "🔧 Nueva Configuración",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // SSID Input
              TextField(
                controller: _ssidController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Nombre de la red WiFi (SSID)",
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(
                    Icons.router,
                    color: Colors.cyan,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Colors.cyan,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Colors.cyan,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A1F29),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Password Input
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Contraseña WiFi",
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(
                    Icons.lock,
                    color: Colors.orange,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Colors.orange,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Colors.orange,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A1F29),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ===== Estado =====
              Card(
                color: const Color(0xFF1A1F29),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white70),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status,
                          style: TextStyle(
                            color: _status.contains("✅")
                                ? Colors.green
                                : _status.contains("❌")
                                    ? Colors.red
                                    : _status.contains("⏳")
                                        ? Colors.orange
                                        : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ===== Botones =====
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              _ssidController.clear();
                              _passwordController.clear();
                              setState(() => _status = "Listo para configurar");
                            },
                      icon: const Icon(Icons.clear),
                      label: const Text("Limpiar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        disabledBackgroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveWiFiConfig,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(_isLoading ? "Guardando..." : "Guardar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        disabledBackgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ===== Instrucciones =====
              Card(
                color: const Color(0xFF1A1F29),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "📋 Instrucciones",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyan,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        "1. Pon el SSID de tu WiFi\n"
                        "2. Pon la contraseña correcta\n"
                        "3. Hace click en 'Guardar'\n"
                        "4. El ESP32 se reconectará en ~10 segundos\n"
                        "5. Verifica en el Serial Monitor del Arduino",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
