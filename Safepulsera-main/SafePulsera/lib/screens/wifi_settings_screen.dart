import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wifi_provider.dart';

class WiFiSettingsScreen extends StatefulWidget {
  const WiFiSettingsScreen({Key? key}) : super(key: key);

  @override
  State<WiFiSettingsScreen> createState() => _WiFiSettingsScreenState();
}

class _WiFiSettingsScreenState extends State<WiFiSettingsScreen> {
  String? selectedNetwork;
  String passwordInput = '';
  final passwordController = TextEditingController();

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar WiFi', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.grey.shade900,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey.shade900,
      body: Consumer<WiFiProvider>(
        builder: (context, wifiProvider, child) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- ENCABEZADO ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade700, Colors.teal.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withAlpha(80),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.wifi, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Red WiFi Actual',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                wifiProvider.connectedNetwork ?? 'No conectado',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: wifiProvider.connectedNetwork != null
                                      ? Colors.white
                                      : Colors.redAccent.shade100,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- ESTADO DE CONEXIÓN DEL ESP32 ---
                  if (wifiProvider.esp32ConnectionStatus != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: wifiProvider.esp32ConnectionStatus == 'connected'
                            ? Colors.teal.shade900
                            : wifiProvider.esp32ConnectionStatus == 'connecting'
                                ? Colors.blueGrey.shade800
                                : Colors.red.shade900,
                        border: Border.all(
                          color: wifiProvider.esp32ConnectionStatus == 'connected'
                              ? Colors.teal.shade500
                              : wifiProvider.esp32ConnectionStatus == 'connecting'
                                  ? Colors.blueGrey.shade500
                                  : Colors.red.shade600,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: wifiProvider.esp32ConnectionStatus == 'connected'
                                  ? Colors.teal.shade700
                                  : wifiProvider.esp32ConnectionStatus == 'connecting'
                                      ? Colors.blueGrey.shade700
                                      : Colors.red.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              wifiProvider.esp32ConnectionStatus == 'connected'
                                  ? Icons.check_circle
                                  : wifiProvider.esp32ConnectionStatus == 'connecting'
                                      ? Icons.sync
                                      : Icons.error,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  wifiProvider.esp32ConnectionStatus == 'connected'
                                      ? 'ESP32 Conectado'
                                      : wifiProvider.esp32ConnectionStatus == 'connecting'
                                          ? 'ESP32 Conectando...'
                                          : 'ESP32 Error de Conexión',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                if (wifiProvider.esp32LastError != null && 
                                    wifiProvider.esp32ConnectionStatus == 'failed')
                                  Text(
                                    wifiProvider.esp32LastError!,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // --- MENSAJES ---
                  if (wifiProvider.successMessage != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade900,
                        border: Border.all(color: Colors.teal.shade600, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.teal.shade300),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              wifiProvider.successMessage!,
                              style: TextStyle(color: Colors.teal.shade200),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (wifiProvider.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900,
                        border: Border.all(color: Colors.red.shade600, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade300),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              wifiProvider.errorMessage!,
                              style: TextStyle(color: Colors.red.shade200),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // --- UBICACIÓN ACTUAL ---
                  if (wifiProvider.locationText != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade600, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.teal.shade400, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Tu ubicación actual',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal.shade300,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            wifiProvider.locationText ?? 'Obteniendo ubicación...',
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              color: Colors.white70,
                            ),
                          ),
                          if (wifiProvider.locationMapUrl != null) ...[
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () {
                                // Aquí puedes abrir Google Maps si lo deseas
                              },
                              child: Text(
                                'Ver en Google Maps',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal.shade300,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // --- BOTÓN ESCANEAR ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: wifiProvider.isScanning
                          ? null
                          : () => wifiProvider.scanNetworks(),
                      icon: wifiProvider.isScanning
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.wifi_find),
                      label: Text(
                        wifiProvider.isScanning
                            ? 'Escaneando...'
                            : 'Escanear Redes',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- LISTA DE REDES ---
                  if (wifiProvider.availableNetworks.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.wifi, color: Colors.teal.shade400, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Redes Disponibles',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade300,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: wifiProvider.availableNetworks.length,
                      itemBuilder: (context, index) {
                        final network = wifiProvider.availableNetworks[index];
                        final isSelected = selectedNetwork == network.ssid;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? Colors.teal.shade400
                                  : Colors.grey.shade600,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: isSelected ? Colors.teal.shade900.withAlpha(100) : Colors.grey.shade800,
                          ),
                          child: ListTile(
                            onTap: () {
                              setState(() {
                                selectedNetwork = network.ssid;
                                passwordController.clear();
                              });
                            },
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: network.isSecure
                                    ? Colors.teal.shade800
                                    : Colors.green.shade800,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                network.isSecure ? Icons.lock : Icons.lock_open,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              network.ssid,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected ? Colors.teal.shade300 : Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Icon(
                                  Icons.signal_cellular_alt,
                                  size: 14,
                                  color: _getSignalColor(network.level),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${network.level} dBm',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: network.isSecure
                                        ? Colors.teal.shade900
                                        : Colors.green.shade900,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    network.isSecure ? 'Segura' : 'Abierta',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: network.isSecure
                                          ? Colors.teal.shade200
                                          : Colors.green.shade200,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle,
                                    color: Colors.teal.shade400, size: 26)
                                : null,
                          ),
                        );
                      },
                    ),
                  ],

                  // --- CAMPO CONTRASEÑA ---
                  if (selectedNetwork != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(Icons.password, color: Colors.teal.shade400, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Contraseña',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal.shade300,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Ingresa la contraseña',
                        prefixIcon: const Icon(Icons.password),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        passwordInput = value;
                      },
                    ),
                    const SizedBox(height: 20),

                    // --- BOTÓN CONECTAR ---
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: wifiProvider.isSaving
                            ? null
                            : () async {
                                if (selectedNetwork != null) {
                                  // Buscar la red seleccionada para obtener su estado de seguridad
                                  final network = wifiProvider.availableNetworks.firstWhere(
                                    (n) => n.ssid == selectedNetwork,
                                    orElse: () => WiFiNetwork(ssid: selectedNetwork!, level: -100, isSecure: true),
                                  );
                                  
                                  final success =
                                      await wifiProvider.connectToNetwork(
                                    selectedNetwork!,
                                    password: passwordInput,
                                    isSecure: network.isSecure,
                                  );

                                  if (success && mounted) {
                                    // Limpiar formulario
                                    setState(() {
                                      selectedNetwork = null;
                                      passwordController.clear();
                                      passwordInput = '';
                                    });
                                  }
                                }
                              },
                        icon: wifiProvider.isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          wifiProvider.isSaving
                              ? 'Guardando...'
                              : 'Conectar a $selectedNetwork',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // --- INFO IMPORTANTE ---
                  if (wifiProvider.availableNetworks.isEmpty &&
                      !wifiProvider.isScanning) ...[
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        border: Border.all(color: Colors.teal.shade700, width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.teal.shade400),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Presiona "Escanear Redes" para buscar WiFi disponibles',
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getSignalColor(int level) {
    if (level > -50) return Colors.green;
    if (level > -70) return Colors.orange;
    return Colors.red;
  }
}
