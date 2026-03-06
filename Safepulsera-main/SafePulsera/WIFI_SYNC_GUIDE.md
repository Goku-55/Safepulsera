# 📡 WiFi Smart Configuration - Guía de Sincronización

## 🎯 ¿Qué es esto?

Sistema de configuración WiFi remota que permite:
- ✅ Seleccionar redes WiFi desde la app Flutter
- ✅ Almacenar credenciales en Firebase
- ✅ ESP32 carga automáticamente en el próximo reinicio
- ✅ **SIN reprogramación necesaria**

---

## 🔄 Flujo de Sincronización

```
┌─────────────────────────────┐
│  App Flutter               │
│  (WiFi Settings Screen)    │
└────────────┬────────────────┘
             │
             ├─ Escanea redes disponibles
             ├─ Usuario selecciona red
             ├─ Ingresa contraseña (si es necesaria)
             │
             ▼
┌─────────────────────────────┐
│  Firebase Realtime DB      │
│  /wifi_config              │
│  ├─ ssid: "INFINITUM0279"  │
│  ├─ password: "6Bi42k..."  │
│  └─ timestamp: "2026-..." │
└────────────┬────────────────┘
             │
             ├─ Datos guardados en tiempo real
             │
             ▼
┌─────────────────────────────┐
│  ESP32 Microcontroller     │
│  (En el próximo reinicio)  │
│  ├─ Lee /wifi_config       │
│  ├─ Obtiene ssid/password  │
│  └─ Se conecta automáticamente
└─────────────────────────────┘
```

---

## 📱 Uso en Flutter App

### 1. **Abrir Configuración de WiFi**
   - Ve a **Ajustes → Configurar WiFi ESP32**
   - Se abrirá la pantalla `WiFiSettingsScreen`

### 2. **Escanear Redes**
   ```
   [Escanear Redes Disponibles] ← Presiona este botón
   ```
   - Espera 2 segundos a que se carguen las redes
   - Se mostrarán todas las redes WiFi disponibles

### 3. **Seleccionar Red**
   ```
   📶 Redes Disponibles
   ├─ 🔐 INFINITUM0279 (Segura, -50 dBm)
   ├─ 🔐 MyNetwork (Segura, -65 dBm)
   ├─ 🔓 Guest_WiFi (Abierta, -75 dBm)
   ```
   - Toca una red para seleccionarla
   - Se marcará con un círculo azul

### 4. **Ingresar Contraseña**
   ```
   🔐 Contraseña (si es requerida)
   [_______________________]
   ```
   - Si la red es **abierta**: deja vacío
   - Si es **segura**: escribe la contraseña

### 5. **Conectar**
   ```
   [Conectar a INFINITUM0279]
   ```
   - Se guardará en Firebase automáticamente
   - Verás un mensaje de confirmación verde

---

## 🛰️ Sincronización con Firebase

### Datos guardados (`/wifi_config`)
```json
{
  "ssid": "INFINITUM0279",
  "password": "6Bi42kmmEB",
  "timestamp": "2026-02-13T12:00:00.000"
}
```

### Verificar en Firebase Console
1. Ve a **Realtime Database**
2. Expande **`wifi_config`**
3. Deberías ver:
   ```
   wifi_config
   ├─ ssid: "INFINITUM0279"
   ├─ password: "6Bi42kmmEB"
   └─ timestamp: "2026..."
   ```

---

## 🔌 Configuración en ESP32

### Código relevante en `arduino_esp32_wifi_config.ino`

```cpp
// Cargar WiFi desde Firebase
loadWiFiConfigFromFirebase();

// La función lee /wifi_config
void loadWiFiConfigFromFirebase() {
  if (Firebase.RTDB.getJSON(&fbdo, "/wifi_config")) {
    // Lee ssid y password
    // Se conecta automáticamente
  }
}
```

### Qué sucede al reiniciar ESP32:
1. **El ESP32 enciende**
2. **Lee Firebase → obtiene /wifi_config**
3. **Extrae ssid y password**
4. **Se conecta a la red automáticamente**
5. **Serial Monitor muestra:**
   ```
   ✅ WiFi conectado
   IP: 192.168.x.x
   ✅ Firebase listo para enviar
   ```

---

## ✨ Indicadores de Estado

### En la App Flutter

| Indicador | Significado |
|-----------|-----------|
| 🟢 Verde | Red conectada exitosamente |
| 🟠 Naranja | Red con señal débil |
| 🔴 Rojo | Falla de conexión |
| 🔓 Cerradura abierta | Red WiFi sin contraseña |
| 🔐 Cerradura cerrada | Red WiFi con contraseña |

### En la OLED del ESP32
```
HR: 72 BPM
SpO2: 98 %
Temp: 36.5 C
GSR: 2048
─────────────
WiFi: ON   FB: OK
```

---

## 🔧 Solución de Problemas

### "❌ WiFi desconectado"
- Verifica que las credenciales sean correctas en Firebase
- Reinicia el ESP32
- Verifica que el WiFi del router esté activo

### "⚠️ Firebase en modo degradado"
- Comprueba tu conexión a internet
- Verifica la API Key en el código
- Hay WiFi conectado pero Firebase tardó en conectar (normal)

### "No se escanean las redes"
- Comprueba permisos en el teléfono
- Reinicia la app Flutter
- Presiona nuevamente "Escanear Redes Disponibles"

### Datos no se sincronizan
- Verifica que tengas internet en el teléfono
- Abre Firebase Console y recarga
- Los datos deben aparecer en `/wifi_config`

---

## 📊 Monitoreo en Tiempo Real

### Ver logs en Arduino IDE
```
Tools → Serial Monitor (115200 baud)
```

```
📡 Cargando configuración WiFi desde Firebase...
✅ WiFi encontrado: INFINITUM0279
📡 Conectando a: INFINITUM0279
✅ WiFi conectado
IP: 192.168.0.10
✅ Firebase listo para enviar
```

### Ver datos en Firebase Console
```
Realtime Database → Datos
└─ sensores
   ├─ datos_actuales ← Se actualiza cada 1 segundo
   └─ historico ← Se guarda cada 10 segundos
```

---

## 🎓 Información Técnica

### Componentes del Sistema

| Componente | Función |
|-----------|---------|
| `WiFiProvider` | Gestiona estado WiFi en la app |
| `WiFiSettingsScreen` | UI para escanear y conectar |
| `firebase_database` | Almacena configuración |
| `wi_scan` | Escanea redes disponibles |
| `Arduino Code` | Lee config y conecta automáticamente |
| `OLED Display` | Muestra estado WiFi |

### Sincronización Automática
- ✅ Se sincroniza instantáneamente a Firebase
- ✅ ESP32 lo recibe en el próximo reinicio
- ✅ No interfiere con monitoreo de sensores

---

## 🚀 Ventajas del Sistema

| Ventaja | Beneficio |
|---------|-----------|
| **Sin reprogramación** | Cambiar WiFi sin USB |
| **Almacenado en Firebase** | Múltiples ESP32 pueden compartir config |
| **Sincronización automática** | Los cambios son inmediatos |
| **Interfaz intuitiva** | Fácil de usar para cualquiera |
| **Feedback visual** | Sabes exactamente qué está pasando |
| **Historial** | Firebase guarda timestamp de cada cambio |

---

## 📞 Soporte

Si tienes problemas:
1. Verifica Firebase Console
2. Revisa Serial Monitor del ESP32
3. Comprueba permisos de la app Flutter
4. Reinicia ambos dispositivos

¡Listo! Ahora tienes sincronización WiFi perfecta 🎉
