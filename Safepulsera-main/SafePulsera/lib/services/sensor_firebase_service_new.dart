import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class SensorFirebaseService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Stream para Ritmo Cardíaco
  static Stream<int> getHeartRateStream() {
    return _database
        .ref('sensores/hr/valor')
        .onValue
        .map((event) {
          try {
            final value = (event.snapshot.value as num?)?.toInt() ?? 0;
            debugPrint('❤️ HR: $value BPM');
            return value;
          } catch (e) {
            debugPrint('❌ Error leyendo HR: $e');
            return 0;
          }
        });
  }

  // Stream para SpO2
  static Stream<int> getSpO2Stream() {
    return _database
        .ref('sensores/spo2/valor')
        .onValue
        .map((event) {
          try {
            final value = (event.snapshot.value as num?)?.toInt() ?? 0;
            debugPrint('🫁 SpO2: $value%');
            return value;
          } catch (e) {
            debugPrint('❌ Error leyendo SpO2: $e');
            return 0;
          }
        });
  }

  // Stream para Temperatura
  static Stream<double> getTemperatureStream() {
    return _database
        .ref('sensores/temperatura/valor')
        .onValue
        .map((event) {
          try {
            final value = (event.snapshot.value as num?)?.toDouble() ?? 0.0;
            debugPrint('🌡️ Temperatura: ${value.toStringAsFixed(1)}°C');
            return value;
          } catch (e) {
            debugPrint('❌ Error leyendo Temperatura: $e');
            return 0.0;
          }
        });
  }

  // Stream para GSR
  static Stream<int> getGSRStream() {
    return _database
        .ref('sensores/gsr/valor')
        .onValue
        .map((event) {
          try {
            final value = (event.snapshot.value as num?)?.toInt() ?? 0;
            debugPrint('⚡ GSR: $value');
            return value;
          } catch (e) {
            debugPrint('❌ Error leyendo GSR: $e');
            return 0;
          }
        });
  }

  // Stream solo para GSR (compatibilidad)
  static Stream<int> getSensorDataStream() {
    return getGSRStream();
  }
}
