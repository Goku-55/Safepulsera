import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

class SensorData {
  final double hr;
  final int spo2;
  final double temperatura;
  final int gsr;
  final double timestamp;
  final String deviceId;
  final String status;

  SensorData({
    required this.hr,
    required this.spo2,
    required this.temperatura,
    required this.gsr,
    required this.timestamp,
    required this.deviceId,
    required this.status,
  });

  factory SensorData.fromJson(Map<dynamic, dynamic> json) {
    return SensorData(
      hr: (json['hr'] ?? 0).toDouble(),
      spo2: (json['spo2'] ?? 0).toInt(),
      temperatura: (json['temperatura'] ?? 0).toDouble(),
      gsr: (json['gsr'] ?? 0).toInt(),
      timestamp: (json['timestamp'] ?? 0).toDouble(),
      deviceId: json['device_id'] ?? 'unknown',
      status: json['status'] ?? 'inactive',
    );
  }

  Map<String, dynamic> toJson() => {
    'hr': hr,
    'spo2': spo2,
    'temperatura': temperatura,
    'gsr': gsr,
    'timestamp': timestamp,
    'device_id': deviceId,
    'status': status,
  };

  @override
  String toString() {
    return 'HR: $hr BPM | SpO2: $spo2% | Temp: $temperatura°C | GSR: $gsr';
  }
}

class FirebaseSensorService {
  static final FirebaseSensorService _instance = FirebaseSensorService._internal();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  late DatabaseReference _sensorRef;
  late DatabaseReference _historicoRef;

  factory FirebaseSensorService() {
    return _instance;
  }

  FirebaseSensorService._internal() {
    _sensorRef = _database.ref('/sensores/datos_actuales');
    _historicoRef = _database.ref('/sensores/historico');
  }

  DatabaseReference get historicoRef => _historicoRef;

  /// Stream en tiempo real de los datos actuales del sensor
  Stream<SensorData?> getSensorDataStream() {
    return _sensorRef.onValue.map((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        try {
          return SensorData.fromJson(
            Map<dynamic, dynamic>.from(event.snapshot.value as Map),
          );
        } catch (e) {
          debugPrint('Error parseando datos del sensor: $e');
          return null;
        }
      }
      return null;
    });
  }

  /// Obtener datos actuales una sola vez
  Future<SensorData?> getCurrentSensorData() async {
    try {
      final snapshot = await _sensorRef.get();
      if (snapshot.value != null && snapshot.value is Map) {
        return SensorData.fromJson(
          Map<dynamic, dynamic>.from(snapshot.value as Map),
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo datos actuales: $e');
      return null;
    }
  }

  /// Stream del histórico de datos
  Stream<List<SensorData>> getHistoricalDataStream({DateTime? startDate}) {
    return _historicoRef.onValue.map((event) {
      if (event.snapshot.value == null || event.snapshot.value is! Map) return [];
      
      try {
        final Map<dynamic, dynamic> data = 
          Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        
        return data.entries
            .where((e) => e.value is Map)
            .map((e) => SensorData.fromJson(Map<dynamic, dynamic>.from(e.value)))
            .toList()
            .reversed
            .toList();
      } catch (e) {
        debugPrint('Error en histórico stream: $e');
        return [];
      }
    });
  }

  /// Obtener datos históricos pagados
  Future<List<SensorData>> getPaginatedHistory({
    int limit = 100,
    double? startTimestamp,
  }) async {
    try {
      final query = _historicoRef.orderByChild('timestamp');
      
      final snapshot = await query.limitToLast(limit).get();
      
      if (snapshot.value == null || snapshot.value is! Map) return [];
      
      final Map<dynamic, dynamic> data = 
        Map<dynamic, dynamic>.from(snapshot.value as Map);
      
      return data.entries
          .where((e) => e.value is Map)
          .map((e) => SensorData.fromJson(Map<dynamic, dynamic>.from(e.value)))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo histórico paginado: $e');
      return [];
    }
  }

  /// Verificar estado de conexión del ESP32
  Stream<bool> getDeviceStatusStream() {
    return _sensorRef.child('status').onValue.map((event) {
      return event.snapshot.value == 'active';
    });
  }

  /// Obtener estadísticas de últimas N mediciones
  Future<Map<String, dynamic>> getStatistics({int limit = 60}) async {
    try {
      final data = await getPaginatedHistory(limit: limit);
      if (data.isEmpty) return {};

      final hrs = data.map((d) => d.hr).toList();
      final spo2s = data.map((d) => d.spo2).toList();
      final temps = data.map((d) => d.temperatura).toList();
      final gsrs = data.map((d) => d.gsr).toList();

      return {
        'hr': {
          'avg': hrs.isNotEmpty ? hrs.reduce((a, b) => a + b) / hrs.length : 0,
          'max': hrs.isNotEmpty ? hrs.reduce((a, b) => a > b ? a : b) : 0,
          'min': hrs.isNotEmpty ? hrs.reduce((a, b) => a < b ? a : b) : 0,
        },
        'spo2': {
          'avg': spo2s.isNotEmpty ? spo2s.reduce((a, b) => a + b) / spo2s.length : 0,
          'max': spo2s.isNotEmpty ? spo2s.reduce((a, b) => a > b ? a : b) : 0,
          'min': spo2s.isNotEmpty ? spo2s.reduce((a, b) => a < b ? a : b) : 0,
        },
        'temperatura': {
          'avg': temps.isNotEmpty ? temps.reduce((a, b) => a + b) / temps.length : 0,
          'max': temps.isNotEmpty ? temps.reduce((a, b) => a > b ? a : b) : 0,
          'min': temps.isNotEmpty ? temps.reduce((a, b) => a < b ? a : b) : 0,
        },
        'gsr': {
          'avg': gsrs.isNotEmpty ? gsrs.reduce((a, b) => a + b) / gsrs.length : 0,
          'max': gsrs.isNotEmpty ? gsrs.reduce((a, b) => a > b ? a : b) : 0,
          'min': gsrs.isNotEmpty ? gsrs.reduce((a, b) => a < b ? a : b) : 0,
        },
        'count': data.length,
      };
    } catch (e) {
      debugPrint('Error calculando estadísticas: $e');
      return {};
    }
  }

  /// Limpiar referencias
  void dispose() {
    _sensorRef.onDisconnect();
  }
}
