import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../notification_service.dart'; 

// 1. MODELO DE DATOS
class WeatherData {
  final String city;
  final double temperature;
  final double humidity;
  final String description;
  final int aqi;
  final double pm25;
  final double pm10;
  final List<double> hourlyPm25;
  final DateTime timestamp;

  WeatherData({
    required this.city, 
    required this.temperature, 
    required this.humidity,
    required this.description, 
    required this.aqi, 
    required this.pm25, 
    required this.pm10,
    required this.hourlyPm25,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WeatherData.fromJson(Map<String, dynamic> w, Map<String, dynamic> a, String city) {
    final curW = w['current'] ?? {};
    final curA = a['current'] ?? {};
    final hourlyA = a['hourly'] ?? {};
    
    double p25 = (curA['pm2_5'] as num? ?? 0.0).toDouble();
    double p10 = (curA['pm10'] as num? ?? 0.0).toDouble(); // Extraer PM10
    
    List<double> hourlyList = (hourlyA['pm2_5'] as List? ?? [])
        .take(24)
        .map((e) => (e as num).toDouble())
        .toList();

    return WeatherData(
      city: city,
      temperature: (curW['temperature_2m'] as num? ?? 0.0).toDouble(),
      humidity: (curW['relative_humidity_2m'] as num? ?? 0.0).toDouble(),
      description: _translateWeatherCode(curW['weather_code'] ?? 0),
      pm25: p25,
      pm10: p10,
      hourlyPm25: hourlyList,
      aqi: p25 <= 12 ? 1 : p25 <= 35 ? 2 : p25 <= 55 ? 3 : p25 <= 150 ? 4 : 5,
    );
  }

  static String _translateWeatherCode(int code) {
    if (code == 0) return 'Despejado';
    if (code >= 1 && code <= 3) return 'Parcialmente Nublado';
    if (code >= 51 && code <= 65) return 'Lluvia';
    if (code >= 95) return 'Tormenta';
    return 'Nublado';
  }

  String getAQILabel() {
    if (aqi <= 1) return "Excelente";
    if (aqi <= 2) return "Bueno";
    if (aqi <= 3) return "Moderado";
    if (aqi <= 4) return "Insalubre";
    return "Peligroso";
  }

  // NUEVO: Convertir a JSON para guardar en Firestore
  Map<String, dynamic> toJson() => {
    'ciudad': city,
    'temperatura': temperature,
    'humedad': humidity,
    'descripcion': description,
    'aqi': aqi,
    'pm25': pm25,
    'pm10': pm10,
    'timestamp': Timestamp.fromDate(timestamp),
  };
}

// 2. EL SERVICIO (Lógica de descarga y GPS)
class WeatherService {
  static const String weatherBaseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String aqiBaseUrl = 'https://air-quality-api.open-meteo.com/v1/air-quality';

  static Future<WeatherData> getWeatherData() async {
    final prefs = await SharedPreferences.getInstance();
    int intentos = 0;
    const maxIntentos = 3;

    while (intentos < maxIntentos) {
      try {
        intentos++;
        debugPrint('Intento $intentos/$maxIntentos de obtener datos climáticos...');

        // Validar permisos GPS
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          throw Exception('Permisos GPS no disponibles');
        }

        // Obtener coordenadas
        Position pos = await _determinePosition();
        
        // URLs con PM2.5 y PM10
        final wUrl = '$weatherBaseUrl?latitude=${pos.latitude}&longitude=${pos.longitude}&current=temperature_2m,relative_humidity_2m,weather_code&timezone=auto';
        final aUrl = '$aqiBaseUrl?latitude=${pos.latitude}&longitude=${pos.longitude}&current=pm2_5,pm10&hourly=pm2_5&timezone=auto';

        final responses = await Future.wait([
          http.get(Uri.parse(wUrl)).timeout(const Duration(seconds: 10)),
          http.get(Uri.parse(aUrl)).timeout(const Duration(seconds: 10)),
          _getCity(pos.latitude, pos.longitude),
        ]);

        // NUEVA: Validar respuesta HTTP
        final wResponse = responses[0] as http.Response;
        final aResponse = responses[1] as http.Response;

        if (wResponse.statusCode != 200 || aResponse.statusCode != 200) {
          throw Exception('API error: ${wResponse.statusCode}, ${aResponse.statusCode}');
        }

        final wJson = json.decode(wResponse.body);
        final aJson = json.decode(aResponse.body);
        final city = responses[2] as String;

        final data = WeatherData.fromJson(wJson, aJson, city);

        // Guardar en caché
        await prefs.setString('weather_cache', json.encode({'w': wJson, 'a': aJson, 'c': city}));

        // NUEVA: Guardar en Firestore
        await _guardarClimaHistorial(data);

        // Alerta si calidad crítica
        if (data.aqi >= 4) {
          await NotificationService.showNotification(
            id: 999,
            title: "Calidad de Aire Crítica",
            body: "PM2.5 en $city: ${data.pm25.round()} µg/m³. Evita salir.",
          );
        }

        debugPrint('Datos climáticos obtenidos exitosamente');
        return data;
      } catch (e) {
        debugPrint('Intento $intentos falló: $e');
        if (intentos < maxIntentos) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    // Si fallaron todos, usar caché
    String? cached = prefs.getString('weather_cache');
    if (cached != null) {
      final d = json.decode(cached);
      debugPrint('Usando datos en caché (sin conexión)');
      return WeatherData.fromJson(d['w'], d['a'], "${d['c']} (Sin conexión)");
    }
    
    throw Exception("No hay conexión y sin datos en caché.");
  }

  // NUEVO: Guardar datos de clima en Firestore
  static Future<void> _guardarClimaHistorial(WeatherData data) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('clima_historial')
          .add(data.toJson());

      debugPrint('Datos climáticos guardados en Firestore');
    } catch (e) {
      debugPrint('Error guardando clima: $e');
    }
  }

  // MÉTODO GPS MEJORADO
  static Future<Position> _determinePosition() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('GPS desactivado. Actívalo en configuración.');

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) throw Exception('Permiso de ubicación denegado');
    }
    
    if (perm == LocationPermission.deniedForever) {
      throw Exception('Los permisos de ubicación están bloqueados. Actívalos en Ajustes.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      throw Exception('No se pudo obtener ubicación: $e');
    }
  }

  static Future<String> _getCity(double lat, double lon) async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(lat, lon);
      if (p.isNotEmpty) {
        return p[0].locality ?? p[0].administrativeArea ?? "Ubicación";
      }
      return "Ubicación desconocida";
    } catch (_) { 
      return "Ubicación Actual"; 
    }
  }
}