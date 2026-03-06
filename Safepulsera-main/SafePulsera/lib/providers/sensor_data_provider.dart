import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/firebase_sensor_service.dart';

class SensorDataProvider extends ChangeNotifier {
  final FirebaseSensorService _sensorService = FirebaseSensorService();
  
  SensorData? _currentData;
  List<SensorData> _historicalData = [];
  bool _isOnline = false;
  String? _error;

  SensorData? get currentData => _currentData;
  List<SensorData> get historicalData => _historicalData;
  bool get isOnline => _isOnline;
  String? get error => _error;

  SensorDataProvider() {
    _initializeStreams();
  }

  void _initializeStreams() {
    // Escuchar datos actuales
    _sensorService.getSensorDataStream().listen(
      (data) {
        _currentData = data;
        _isOnline = data != null && data.status == 'active';
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );

    // Escuchar histórico
    _sensorService.getHistoricalDataStream().listen(
      (data) {
        _historicalData = data;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error en histórico: $error');
      },
    );
  }

  Future<Map<String, dynamic>> getStatistics({int limit = 60}) async {
    return await _sensorService.getStatistics(limit: limit);
  }

  Future<void> clearHistory() async {
    await _sensorService.historicoRef.remove();
    notifyListeners();
  }

  Future<SensorData?> getCurrentData() async {
    return await _sensorService.getCurrentSensorData();
  }

  bool isDataAbnormal(SensorData data) {
    final hrAbnormal = data.hr < 60 || data.hr > 100;
    final spo2Abnormal = data.spo2 < 95;
    final tempAbnormal = data.temperatura < 36 || data.temperatura > 37.5;
    
    return hrAbnormal || spo2Abnormal || tempAbnormal;
  }

  @override
  void dispose() {
    _sensorService.dispose();
    super.dispose();
  }
}
