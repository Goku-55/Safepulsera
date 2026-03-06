# 🚀 Integración de Monitoreo en Tiempo Real - Guía de Actualización

## ✅ Cambios Realizados Automáticamente

### 1. **main.dart Actualizado**
✅ Importado `provider` package
✅ Importado `SensorDataProvider`
✅ Envuelto la app con `MultiProvider`
✅ Configurado para estar disponible globalmente

### 2. **pubspec.yaml Actualizado**
✅ Agregado `provider: ^6.0.0`

### 3. **Archivos Creados**
✅ `lib/services/firebase_sensor_service.dart` - Servicio de sensores
✅ `lib/providers/sensor_data_provider.dart` - Provider de estado
✅ `lib/screens/realtime_sensor_screen.dart` - Pantalla de monitoreo completo
✅ `lib/screens/monitoring_tab_screen.dart` - Tab para navegación inferior

---

## 📋 Pasos para Integración Completa

### Paso 1: Instalar Dependencias
```bash
flutter pub get
```

### Paso 2: Agregar tab en navegación_base.dart

En el archivo `lib/screens/navegacion_base.dart`, agregar esta importación:
```dart
import 'monitoring_tab_screen.dart';
```

Y en el `BottomNavigationBar`, agregar este item:
```dart
BottomNavigationBarItem(
  icon: const Icon(Icons.monitor_heart),
  label: 'Monitoreo',
),
```

### Paso 3: Actualizar body de navegación_base.dart

En la lista de pantallas del `_pages`:
```dart
pages = [
  // ... pantallas existentes ...
  const MonitoringTabScreen(),  // ← AGREGAR ESTO
];
```

### Paso 4: Usar datos en cualquier pantalla

**Opción A: Con Provider (recomendado)**
```dart
final provider = context.read<SensorDataProvider>();
final currentData = provider.currentData;
final isOnline = provider.isOnline;
```

**Opción B: Con Consumer para rebuild automático**
```dart
Consumer<SensorDataProvider>(
  builder: (context, provider, _) {
    return Text('HR: ${provider.currentData?.hr} BPM');
  },
)
```

**Opción C: Con Stream directo**
```dart
StreamBuilder<SensorData?>(
  stream: FirebaseSensorService().getSensorDataStream(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return Text('Temp: ${snapshot.data?.temperatura}°C');
    }
    return const CircularProgressIndicator();
  },
)
```

---

## 🔧 Ejemplo: Agregar widget de ritmo cardíaco en home

En cualquier pantalla o widget:

```dart
import 'package:provider/provider.dart';
import '../providers/sensor_data_provider.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SensorDataProvider>(
      builder: (context, sensorProvider, _) {
        if (sensorProvider.currentData == null) {
          return const CircularProgressIndicator();
        }
        
        final hr = sensorProvider.currentData!.hr;
        return ListTile(
          title: const Text('Ritmo Cardíaco'),
          subtitle: Text('$hr BPM'),
          trailing: Icon(
            Icons.favorite,
            color: hr > 100 ? Colors.red : Colors.red.shade200,
          ),
        );
      },
    );
  }
}
```

---

## 📊 Estructura de Datos Disponibles

### `SensorData` 
```dart
class SensorData {
  final double hr;              // Ritmo cardíaco en BPM
  final int spo2;               // Saturación de oxígeno %
  final double temperatura;     // Temperatura en °C
  final int gsr;                // Respuesta galvánica de la piel Ω
  final double timestamp;       // Timestamp en ms
  final String deviceId;        // ID del dispositivo
  final String status;          // "active" o "inactive"
}
```

### `SensorDataProvider`
```dart
// Propiedades
SensorData? currentData          // Datos actuales
List<SensorData> historicalData  // Histórico completo
bool isOnline                    // Si dispositivo está online
String? error                    // Último error

// Métodos
getStatistics(limit)             // Obtener promedio/max/min
isDataAbnormal(data)             // Detectar valores anormales
```

---

## 🎨 Ejemplos de Uso Avanzado

### 1. Mostrar alerta si HR es anormal
```dart
Consumer<SensorDataProvider>(
  builder: (context, provider, _) {
    final data = provider.currentData;
    if (data != null && provider.isDataAbnormal(data)) {
      return Container(
        color: Colors.red.shade100,
        padding: EdgeInsets.all(16),
        child: Text('⚠️ Ritmo cardíaco: ${data.hr} BPM'),
      );
    }
    return SizedBox.shrink();
  },
)
```

### 2. Gráfico de histórico (con fl_chart)
```dart
Consumer<SensorDataProvider>(
  builder: (context, provider, _) {
    final data = provider.historicalData;
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) =>
              FlSpot(e.key.toDouble(), e.value.hr)
            ).toList(),
          ),
        ],
      ),
    );
  },
)
```

### 3. Sincronización con notificaciones
```dart
Future<void> _checkSensorAlerts() async {
  final provider = Provider.of<SensorDataProvider>(context, listen: false);
  
  if (provider.currentData != null && provider.isDataAbnormal(provider.currentData!)) {
    await NotificationService.showNotification(
      title: 'Alerta de Salud',
      body: 'HR: ${provider.currentData!.hr} BPM - Valor anormal',
    );
  }
}
```

---

## 🐛 Troubleshooting

### Pantalla muestra "Conectando con sensores..."
- Verificar que ESP32 esté enviando datos
- Verificar conexión a WiFi
- Revisar Firebase en consola

### Error "SensorDataProvider not found"
- Asegurar que el `ChangeNotifierProvider` está en `main.dart`
- Verificar que importa `SensorDataProvider` correctamente

### Datos lentos o atrasados
- Revisar conexión WiFi / Latencia
- Revisar ancho de banda disponible en Firebase

---

## 📱 Próximos Pasos Sugeridos

1. ✅ Integrar tab de monitoreo en navegación
2. ✅ Agregar widget de ritmo cardíaco a home
3. ✅ Implementar alertas en notificaciones
4. ✅ Agregar gráficos históricos
5. ✅ Exportar datos a CSV
6. ✅ Implementar limpieza automática de datos antiguos

---

## 🎯 Comandos Útiles

```bash
# Verificar que todo compila
flutter analyze

# Ejecutar en modo debug
flutter run

# Recompilar después de cambios
flutter pub get && flutter clean && flutter pub get
```

---

## ✨ Estado Actual

| Feature | Status |
|---------|--------|
| Arduino sincronización | ✅ Completado |
| Provider en main.dart | ✅ Completado |
| Servicio Firebase | ✅ Completado |
| Pantalla monitoreo | ✅ Completado |
| Tab en navegación | ⏳ Pendiente (ver Paso 2) |
| Alertas de salud | ⏳ Pendiente |
| Gráficos | ⏳ Pendiente |

