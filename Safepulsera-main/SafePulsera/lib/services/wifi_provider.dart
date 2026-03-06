import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'location_service.dart';
import 'package:geolocator/geolocator.dart';

class WiFiNetwork {
  final String ssid;
  final int level;
  final bool isSecure;

  WiFiNetwork({
    required this.ssid,
    required this.level,
    required this.isSecure,
  });

  @override
  String toString() => 'WiFiNetwork(ssid: $ssid, level: $level, secure: $isSecure)';
}

class WiFiProvider extends ChangeNotifier {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  
  List<WiFiNetwork> availableNetworks = [];
  String? connectedNetwork;
  bool isScanning = false;
  String? errorMessage;
  bool isSaving = false;
  String? successMessage;
  
  // Ubicación actual
  Position? currentLocation;
  String? locationMapUrl;
  String? locationText;
  
  // Estado de conexión del ESP32
  String? esp32ConnectionStatus; // "connected", "failed", "connecting", null
  String? esp32LastError;
  DateTime? esp32LastAttempt;

  WiFiProvider() {
    _loadCurrentWiFi();
    _listenToConnectionStatus();
  }
  
  /// Escuchar estado de conexión del ESP32 en tiempo real
  void _listenToConnectionStatus() {
    _db.ref('/wifi_config/connection_status').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          esp32ConnectionStatus = data['status'] as String?;
          esp32LastError = data['error'] as String?;
          final timestamp = data['timestamp'] as String?;
          if (timestamp != null) {
            esp32LastAttempt = DateTime.tryParse(timestamp);
          }
          
          // Mostrar mensaje según el estado
          if (esp32ConnectionStatus == 'connected') {
            successMessage = '✅ ESP32 conectado exitosamente a $connectedNetwork';
            errorMessage = null;
          } else if (esp32ConnectionStatus == 'failed') {
            errorMessage = '❌ ESP32 no pudo conectarse: ${esp32LastError ?? "Contraseña incorrecta o red no disponible"}';
            successMessage = null;
          } else if (esp32ConnectionStatus == 'connecting') {
            successMessage = '⏳ ESP32 intentando conectar a $connectedNetwork...';
            errorMessage = null;
          }
          
          notifyListeners();
        }
      }
    });
  }

  /// Cargar WiFi actual desde Firebase
  Future<void> _loadCurrentWiFi() async {
    try {
      final snapshot = await _db.ref('/wifi_config/ssid').get();
      if (snapshot.exists) {
        connectedNetwork = snapshot.value as String?;
        notifyListeners();
      }
    } catch (e) {
      // Error silently handled - connection will retry
    }
  }

  /// Solicitar permisos necesarios para escanear WiFi
  Future<bool> _requestLocationPermission() async {
    final PermissionStatus status = await Permission.location.request();
    return status.isGranted;
  }

  /// Escanear redes WiFi reales disponibles
  Future<void> scanNetworks() async {
    isScanning = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Solicitar permisos de ubicación
      final hasPermission = await _requestLocationPermission();
      if (!hasPermission) {
        errorMessage = 'Se necesitan permisos de ubicación para escanear redes WiFi';
        isScanning = false;
        notifyListeners();
        return;
      }

      // Obtener ubicación actual
      currentLocation = await LocationService.getCurrentLocation();
      if (currentLocation != null) {
        locationMapUrl = await LocationService.getLocationMapUrl();
        locationText = '${currentLocation!.latitude.toStringAsFixed(4)}, ${currentLocation!.longitude.toStringAsFixed(4)}';
      }

      // Iniciar escaneo de redes WiFi reales
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan != CanStartScan.yes) {
        errorMessage = 'No se puede escanear WiFi: ${canScan.name}';
        isScanning = false;
        notifyListeners();
        return;
      }
      
      await WiFiScan.instance.startScan();
      
      // Esperar a que el escaneo se complete
      await Future.delayed(const Duration(seconds: 3));
      
      // Obtener resultados del escaneo REAL
      final canGetResults = await WiFiScan.instance.canGetScannedResults();
      if (canGetResults != CanGetScannedResults.yes) {
        errorMessage = 'No se pueden obtener resultados: ${canGetResults.name}';
        isScanning = false;
        notifyListeners();
        return;
      }
      
      final List<WiFiAccessPoint> results = await WiFiScan.instance.getScannedResults();
      
      if (results.isEmpty) {
        errorMessage = 'No se detectaron redes WiFi en tu ubicación';
        isScanning = false;
        notifyListeners();
        return;
      }
      
      // Convertir TODAS las redes detectadas a nuestro modelo WiFiNetwork
      // Incluye redes abiertas, cerradas y ocultas
      List<WiFiNetwork> allNetworks = results
          .map((scan) => WiFiNetwork(
            ssid: scan.ssid.isNotEmpty ? scan.ssid : '[Red Oculta]',
            level: scan.level,
            isSecure: scan.capabilities.toUpperCase().contains('WPA') || 
                     scan.capabilities.toUpperCase().contains('WEP') ||
                     scan.capabilities.toUpperCase().contains('PSK'),
          ))
          .toList();
      
      // Eliminar duplicados por SSID, mantener la señal más fuerte
      final Map<String, WiFiNetwork> uniqueNetworks = {};
      for (var network in allNetworks) {
        if (!uniqueNetworks.containsKey(network.ssid) || 
            uniqueNetworks[network.ssid]!.level < network.level) {
          uniqueNetworks[network.ssid] = network;
        }
      }
      
      availableNetworks = uniqueNetworks.values.toList();
      
      // Ordenar por fuerza de señal (más fuertes primero)
      availableNetworks.sort((a, b) => b.level.compareTo(a.level));
      
      isScanning = false;
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error escaneando redes WiFi: $e';
      availableNetworks = [];
      isScanning = false;
      notifyListeners();
    }
  }

  /// Conectar a una red WiFi y guardar en Firebase
  /// Valida que la contraseña sea correcta para redes seguras
  Future<bool> connectToNetwork(String ssid, {String password = '', bool? isSecure}) async {
    isSaving = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      // Validar que el SSID no esté vacío
      if (ssid.isEmpty) {
        errorMessage = 'El nombre de la red no puede estar vacío';
        isSaving = false;
        notifyListeners();
        return false;
      }

      // Buscar si la red es segura en nuestra lista de redes escaneadas
      final network = availableNetworks.firstWhere(
        (n) => n.ssid == ssid,
        orElse: () => WiFiNetwork(ssid: ssid, level: -100, isSecure: isSecure ?? true),
      );
      
      // Validar contraseña para redes seguras
      if (network.isSecure) {
        if (password.isEmpty) {
          errorMessage = 'Esta red requiere contraseña';
          isSaving = false;
          notifyListeners();
          return false;
        }
        
        // Las contraseñas WPA deben tener mínimo 8 caracteres
        if (password.length < 8) {
          errorMessage = 'La contraseña debe tener al menos 8 caracteres';
          isSaving = false;
          notifyListeners();
          return false;
        }
        
        // Validar que no tenga solo espacios
        if (password.trim().isEmpty) {
          errorMessage = 'La contraseña no puede estar vacía';
          isSaving = false;
          notifyListeners();
          return false;
        }
      }

      // Guardar en Firebase
      await _db.ref('/wifi_config').set({
        'ssid': ssid,
        'password': password,
        'isSecure': network.isSecure,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Actualizar estado local
      connectedNetwork = ssid;
      successMessage = network.isSecure 
          ? 'Credenciales guardadas para $ssid. El ESP32 intentará conectarse.'
          : 'Red abierta $ssid configurada. El ESP32 se conectará automáticamente.';
      isSaving = false;
      notifyListeners();

      // Limpiar mensaje de éxito después de 3 segundos
      await Future.delayed(const Duration(seconds: 3));
      successMessage = null;
      notifyListeners();

      return true;
    } catch (e) {
      errorMessage = 'Error guardando configuración: $e';
      isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Obtener la red actual desde Firebase
  Stream<String?> getConnectedNetworkStream() {
    return _db.ref('/wifi_config/ssid').onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as String?;
      }
      return null;
    });
  }

  /// Limpiar mensajes
  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }
}
