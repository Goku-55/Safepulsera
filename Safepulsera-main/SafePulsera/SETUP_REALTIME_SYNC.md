# SafeAllergy - Sincronización en Tiempo Real ESP32 ↔ Flutter

## ✅ Cambios Implementados

### Arduino ESP32 (arduino_esp32_wifi_config.ino)
- ✅ **Envío cada 1 segundo** en lugar de 5 segundos
- ✅ **Verificación optimizada de Firebase** antes de enviar
- ✅ **JSON en una sola transacción** para mejor eficiencia
- ✅ **Sistema de reintentos** automático (máx 2 intentos)
- ✅ **Histórico automático** cada 10 segundos
- ✅ **Logs reducidos** para evitar spam en serial

**Rutas en Firebase:**
```
/sensores/datos_actuales         ← Datos en TIEMPO REAL
/sensores/historico/{timestamp}  ← Histórico de todas las mediciones
```

---

## 📱 Flutter App - Nuevos Servicios

### 1. **FirebaseSensorService** (`lib/services/firebase_sensor_service.dart`)
Servicio singleton que maneja toda la comunicación con Firebase:

```dart
// Obtener stream en tiempo real
Stream<SensorData?> getSensorDataStream()

// Datos actuales de una vez
Future<SensorData?> getCurrentSensorData()

// Stream del histórico
Stream<List<SensorData>> getHistoricalDataStream()

// Obtener estadísticas
Future<Map<String, dynamic>> getStatistics(limit: 60)

// Verificar si dispositivo está online
Stream<bool> getDeviceStatusStream()
```

### 2. **RealtimeSensorScreen** (`lib/screens/realtime_sensor_screen.dart`)
Widget que muestra en tiempo real:
- ❤️ Ritmo Cardíaco
- 🫁 SpO₂ (Saturación de Oxígeno)
- 🌡️ Temperatura
- ⚡ GSR (Galvanic Skin Response)
- 📊 Estadísticas automáticas
- 🟢 Estado del dispositivo

### 3. **SensorDataProvider** (`lib/providers/sensor_data_provider.dart`)
State management con Provider:
- Gestiona el estado de los datos
- Detecta valores anormales
- Sincroniza histórico
- Manejo de errores

---

## 🚀 Instalación y Uso

### Paso 1: Actualizar pubspec.yaml
```yaml
dependencies:
  firebase_database: ^10.0.0
  cloud_firestore: ^4.13.0
  provider: ^6.0.0
```

### Paso 2: Instalar dependencias
```bash
flutter pub get
```

### Paso 3: Importar en main.dart
```dart
import 'package:provider/provider.dart';
import 'providers/sensor_data_provider.dart';
import 'screens/realtime_sensor_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeAllergy',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ChangeNotifierProvider(
        create: (_) => SensorDataProvider(),
        child: const RealtimeSensorScreen(),
      ),
    );
  }
}
```

### Paso 4: Usar en otros widgets
```dart
// Con Provider
final provider = context.read<SensorDataProvider>();
final currentData = provider.currentData;
final isAbnormal = provider.isDataAbnormal(currentData);

// Stream directo
StreamBuilder<SensorData?>(
  stream: FirebaseSensorService().getSensorDataStream(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();
    return Text('HR: ${snapshot.data?.hr} BPM');
  },
)
```

---

## 📊 Estructura de Datos en Firebase

### Datos Actuales (en tiempo real)
```json
{
  "/sensores/datos_actuales": {
    "hr": 72.5,
    "spo2": 98,
    "temperatura": 36.8,
    "gsr": 250,
    "timestamp": 1707817200000,
    "device_id": "ESP32_SAFEALLERGY",
    "status": "active"
  }
}
```

### Histórico
```json
{
  "/sensores/historico": {
    "1707817200000": {
      "hr": 72.5,
      "spo2": 98,
      "temperatura": 36.8,
      "gsr": 250,
      "timestamp": 1707817200000
    },
    "1707817210000": { ... }
  }
}
```

---

## ⚡ Velocidad de Sincronización

| Métrica | Anterior | Actual |
|---------|----------|--------|
| Lectura sensores | 1 segundo | ✅ 1 segundo |
| Envío a Firebase | 5 segundos | ✅ **1 segundo** |
| Recepción en app | Variable | ✅ **Tiempo Real** |
| Histórico | Cada 5s | ✅ Cada 10s |

---

## 🔍 Detección de Valores Anormales

### Rangos Normales
- **HR**: 60-100 BPM
- **SpO₂**: ≥ 95 %
- **Temperatura**: 36.0-37.5 °C
- **GSR**: 0-1000 Ω

Si algún valor está fuera de rango:
- 🔴 Borde rojo en la tarjeta
- ⚠️ Símbolo de advertencia
- 📢 Potencial alerta (ver notification_service.dart)

---

## 📝 Logs en Serial del ESP32

```
✅ Sincronizado #5
✅ Sincronizado #10   ← Cada 5 envíos exitosos
✅ Histórico guardado ← Cada 10 envíos
```

---

## 🐛 Troubleshooting

### "No hay datos disponibles"
1. Verificar WiFi conectada en ESP32
2. Verificar API_KEY en Arduino es válida
3. Verificar Firebase RTDB habilitada en consola

### Datos lentos / con delay
1. Revisar conexión WiFi (5GHz → 2.4GHz)
2. Reducir distancia entre ESP32 y router
3. Verificar carga de Firebase (usar estadísticas)

### Errores de sincronización
Check serial monitor del ESP32:
```
❌ Firebase no está listo
❌ No se pudo enviar...
```

---

## 🎯 Próximas Mejoras Sugeridas

- [ ] Agregar notificaciones de alerta (push)
- [ ] Gráficos históricos con charts
- [ ] Exportar datos a CSV
- [ ] Autenticación multi-usuario
- [ ] Modo offline con sincronización posterior
- [ ] Predicción de alergias basada en datos

---

## 📝 Notas

- El ESP32 intenta reconectar automáticamente si WiFi cae
- Firebase usa reintentos automáticos en caso de fallo
- El histórico se mantiene indefinidamente en Firebase
- Las alertas deben implementarse en notification_service.dart

