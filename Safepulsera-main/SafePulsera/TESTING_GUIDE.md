# 🧪 Guía Completa de Pruebas - WiFi Sync System

## 📋 Pre-Requisitos

- ✅ Arduino code subido al ESP32
- ✅ Firebase configurado con `/wifi_config` correcta
- ✅ Flutter app compilada
- ✅ Ambos dispositivos conectados a internet

---

## 🔍 Test 1: Verificar Firebase

### Paso 1: Abrir Firebase Console
```
https://console.firebase.google.com/
Proyecto: safeallergy-19bb7
Realtime Database
```

### Paso 2: Buscar `/wifi_config`
Debe ver estructura:
```json
{
  "ssid": "INFINITUM0279",
  "password": "6Bi42kmmEB",
  "timestamp": "2026-..."
}
```

**✅ PASS si:** Existe y tiene datos correctos

---

## 🔍 Test 2: Verificar Arduino/ESP32

### Paso 1: Abrir Arduino IDE
```
Sketch → Monitor Serie (115200 baud)
```

### Paso 2: Buscar estos mensajes
```
✅ OLED inicializada
✅ MAX30102 inicializado
✅ MLX90614 inicializado
✅ GSR inicializado
📡 Conectando a: INFINITUM0279
✅ WiFi conectado
IP: 192.168.0.X
✅ Firebase listo para enviar
📊 LECTURA DE SENSORES
  ❤️ Ritmo Cardíaco: 72 BPM
  🫁 SpO2: 98 %
  🌡️ Temperatura: 36.5 °C
  ⚡ GSR: 2048
✅ Sincronizado #1, #2, #3...
```

### Paso 3: Verificar OLED
En la pantalla debe ver:
```
HR: 72 BPM
SpO2: 98 %
Temp: 36.5 C
GSR: 2048
─────────────
WiFi: ON   FB: OK
```

**✅ PASS si:** Todos los mensajes aparecen y OLED muestra datos

---

## 🔍 Test 3: Verificar App Flutter

### Paso 1: Compilar app
```bash
flutter pub get
flutter run
```

### Paso 2: Verificar que inicia sin errores
- Debe mostrar login o home screen
- No debe haber excepciones en la consola

### Paso 3: Navegar a Settings
```
Menú (hamburguesa) 
  → Ajustes
    → Configurar WiFi ESP32
```

**✅ PASS si:** Se abre la pantalla WiFiSettingsScreen sin errores

---

## 🔍 Test 4: Escanear Redes WiFi

### Paso 1: Presionar "Escanear Redes Disponibles"
```
[Escanear Redes Disponibles] ← TAP
```

### Paso 2: Esperar 2 segundos
Debe mostrar "Escaneando..." con spinner

### Paso 3: Verificar lista de redes
Debe aparecer al menos:
```
📶 Redes Disponibles
├─ 🔐 INFINITUM0279 (-50 dBm | Segura)
├─    MyNetwork (-65 dBm | Segura)
└─ 🔓 Guest_WiFi (-75 dBm | Abierta)
```

**✅ PASS si:** Se muestran al menos 3 redes

---

## 🔍 Test 5: Seleccionar Red

### Paso 1: Pressiona una red (por ejemplo INFINITUM0279)
```
┌─────────────────────────────┐
│ 🔐 INFINITUM0279 ✓         │ ← TAP AQUÍ
│    -50 dBm | Segura        │
└─────────────────────────────┘
```

### Paso 2: Verificar que se marca
La red debe mostrar:
- ✓ Círculo azul a la derecha
- Fondo azul claro
- "Conectar a INFINITUM0279" mostrado

### Paso 3: Campo de contraseña aparece
Debe haber un campo visible:
```
🔐 Contraseña (si es requerida)
[_______________________]
```

**✅ PASS si:** La red se selecciona y aparece campo de contraseña

---

## 🔍 Test 6: Ingresarcontraseña

### Paso 1: Presionar en campo de contraseña
```
🔐 Contraseña (si es requerida)
[_______________________] ← PRESIONAR
```

### Paso 2: Escribir contraseña
```
Escribe: 6Bi42kmmEB
```

### Paso 3: Verificar que se oculta
La contraseña debe mostrarse como:
```
••••••••••••
```

**✅ PASS si:** La contraseña se oculta en el campo

---

## 🔍 Test 7: Guardar en Firebase

### Paso 1: Presionar "Conectar a INFINITUM0279"
```
[Conectar a INFINITUM0279] ← TAP
```

### Paso 2: Esperar respuesta
Debe mostrar:
- Spinner indicando "Guardando..."
- El botón se deshabilita

### Paso 3: Verificar mensaje de éxito
Debe aparecer:
```
┌─ ✓ VERDE ─────────────────┐
│ Conectado a INFINITUM0279.│
│ El ESP32 lo usará en el   │
│ próximo reinicio.         │
└──────────────────────────┘
```

**✅ PASS si:** Aparece mensaje verde de éxito

---

## 🔍 Test 8: Verificar en Firebase Console

### Paso 1: Refrescar Firebase Console
```
Console.firebase.google.com → Realtime Database
(F5 o recargar)
```

### Paso 2: Expandir `/wifi_config`
Debe ver:
```
wifi_config
├─ ssid: "INFINITUM0279"
├─ password: "6Bi42kmmEB"
└─ timestamp: "2026-02-13T..."
```

### Paso 3: Verificar que cambió el timestamp
El campo timestamp debe ser MÁS RECIENTE que antes

**✅ PASS si:** /wifi_config contiene los datos correctos y el timestamp es actual

---

## 🔍 Test 9: Verificar Sincronización ESP32

### Paso 1: Reiniciar ESP32
- Presiona el botón RESET en la placa
- O desconecta/reconecta poder

### Paso 2: Observar Serial Monitor
Debe mostrar:
```
🚀 SafeAllergy - Sistema Multi-Sensor
📡 Cargando configuración WiFi desde Firebase...
✅ WiFi encontrado: INFINITUM0279
📡 Conectando a: INFINITUM0279
✅ WiFi conectado
IP: 192.168.0.X
✅ Firebase listo para enviar
```

### Paso 3: Verificar OLED
Debe mostrar en la esquina inferior:
```
WiFi: ON   FB: OK
```

**✅ PASS si:** ESP32 se conecta automáticamente a la nueva red

---

## 🔍 Test 10: Verificar App Monitorea Cambios

### Paso 1: En la app, ir a "Monitoreo"
```
Navegación → Monitoreo
```

### Paso 2: Verificar que recibe datos
Debe mostrar:
```
❤️ HR: 72 BPM
🫁 SpO2: 98 %
🌡️ Temp: 36.5 °C
⚡ GSR: 2048
  Actualiza cada 1 segundo
```

**✅ PASS si:** La app recibe datos en tiempo real del ESP32

---

## 🔍 Test 11: Prueba de Red Abierta

### Paso 1: Seleccionar red abierta (Guest_WiFi)
```
┌─────────────────────────────┐
│ 🔓 Guest_WiFi              │ ← TAP
│    -75 dBm | Abierta       │
└─────────────────────────────┘
```

### Paso 2: NO ingresar contraseña
Dejar el campo vacío:
```
🔐 Contraseña (si es requerida)
[_______________________] (vacío)
```

### Paso 3: Presionar "Conectar "
```
[Conectar a Guest_WiFi]
```

### Paso 4: Verificar guardado
Debe mostrar éxito y en Firebase:
```
wifi_config
├─ ssid: "Guest_WiFi"
├─ password: "" (vacío - red abierta)
└─ timestamp: "2026-..."
```

**✅ PASS si:** Se conecta a red abierta sin contraseña

---

## 🔍 Test 12: Prueba de Error - Red Inexistente

### Paso 1: Intentar conectar sin seleccionar red
(Si es posible presionar botón)

### Paso 2: Debe mostrar error:
```
┌─ ❌ ROJO ───────────────────┐
│ SSID no puede estar vacío   │
└─────────────────────────────┘
```

**✅ PASS si:** Valida que se seleccione una red

---

## 📊 Resultado Final Esperado

Después de completar TODOS los tests:

| Test | Status | Resultado |
|------|--------|-----------|
| 1. Firebase | ✅ | /wifi_config existe |
| 2. Arduino | ✅ | Serial muestra datos |
| 3. App Flutter | ✅ | Abre sin errores |
| 4. Escaneo | ✅ | Muestra 3+ redes |
| 5. Selección | ✅ | Red se marca |
| 6. Contraseña | ✅ | Se oculta correctamente |
| 7. Guardar | ✅ | Mensaje verde |
| 8. Firebase Update | ✅ | Datos aparecen |
| 9. ESP32 Sync | ✅ | Se conecta auto |
| 10. App Monitoreo | ✅ | Recibe datos |
| 11. Red Abierta | ✅ | Funciona sin contraseña |
| 12. Validación | ✅ | Rechaza entrada vacía |

---

## 🏆 Certificado de Funcionamiento

Si todos los tests pasan, **el sistema está 100% FUNCIONAL**:

✅ Escaneo de WiFi: **PERFECTO**
✅ Selección de red: **PERFECTO**
✅ Ingreso de contraseña: **PERFECTO**
✅ Guardado en Firebase: **PERFECTO**
✅ Sincronización ESP32: **PERFECTO**
✅ OLED actualizado: **PERFECTO**
✅ App recibe datos: **PERFECTO**

---

## 📝 Notas para Debugging

Si algún test falla:

### Firebase no guarda:
```
Verificar:
- Reglas de seguridad permiten escritura
- API Key en Arduino es correcta
- Internet disponible en teléfono
```

### ESP32 no carga config:
```
Verificar:
- Firebase.ready() == true
- /wifi_config existe en Firebase
- WiFi del router está activo
- Reinicia el ESP32
```

### App no recibe datos:
```
Verificar:
- Firebase Services en el teléfono (/sensores/datos_actuales existe)
- SensorDataProvider tiene la URL correcta
- Internet en teléfono
- Reinicia la app
```

---

## 🎓 Interpretación de Resultados

### Todos los tests ✅:
**Status: PRODUCCIÓN LISTA**
- Desplegar a usuarios reales
- Monitorear en Firebase Analytics

### 1-2 tests ❌:
**Status: REVISIÓN NECESARIA**
- Revisar configuración Firebase Rules
- Verificar permisos del teléfono

### 3+ tests ❌:
**Status: DEPURACIÓN REQUERIDA**
- Revisar código Arduino
- Revisar main.dart del proveedor
- Ejecutar `flutter clean && flutter pub get`

---

¡Que disfrutes probando el sistema! 🚀
