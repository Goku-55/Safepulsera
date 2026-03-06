// ===== ESP32 CON WiFi Y FIREBASE =====
// Envía datos del sensor GSR a Firebase en tiempo real
// Compatible con Flutter

#include <WiFi.h>
#include <FirebaseESP32.h>

// ===== CONFIGURACIÓN WiFi =====
const char* WIFI_SSID = "TU_RED_WIFI";        // Cambia con tu WiFi
const char* WIFI_PASSWORD = "TU_CONTRASEÑA";  // Cambia con tu contraseña

// ===== CONFIGURACIÓN FIREBASE =====
#define FIREBASE_HOST "safeallergy-19bb7-default-rtdb.firebaseio.com"  // ✅ Tu URL
#define FIREBASE_AUTH ""  // Vacío porque usamos reglas abiertas

// ===== CONFIGURACIÓN DEL SENSOR =====
const int gsrPin = 2;  // Pin IO2 para sensor GSR
const int baudRate = 115200;

// Variables para suavizado
const int numSamples = 10;
int readings[numSamples];
int readIndex = 0;
int total = 0;
int promedio = 0;

// Firebase
FirebaseData firebaseData;
unsigned long lastSendTime = 0;
const unsigned long SEND_INTERVAL = 1000; // Enviar cada 1 segundo

void setup() {
  Serial.begin(baudRate);
  delay(1000);
  
  Serial.println("\n\n=== ESP32 GSR Monitor con WiFi ===");
  
  // Inicializar array
  for (int i = 0; i < numSamples; i++) {
    readings[i] = 0;
  }
  
  // Conectar a WiFi
  connectToWiFi();
  
  // Inicializar Firebase
  Firebase.begin(FIREBASE_HOST, FIREBASE_AUTH);
  Firebase.reconnectWiFi(true);
  
  Serial.println("✅ Sistema iniciado");
}

void loop() {
  // Leer sensor
  int valor = analogRead(gsrPin);
  
  // Suavizado (promedio móvil)
  total -= readings[readIndex];
  readings[readIndex] = valor;
  total += readings[readIndex];
  readIndex = (readIndex + 1) % numSamples;
  promedio = total / numSamples;
  
  // Enviar a Firebase cada cierto tiempo
  if (millis() - lastSendTime >= SEND_INTERVAL) {
    lastSendTime = millis();
    
    // Mostrar en Serial
    Serial.print("GSR:");
    Serial.println(promedio);
    
    // Enviar a Firebase
    if (Firebase.setInt(firebaseData, "/sensores/gsr/valor", promedio)) {
      Serial.println("✅ Enviado a Firebase");
    } else {
      Serial.print("❌ Error Firebase: ");
      Serial.println(firebaseData.errorReason());
    }
    
    // También guardar timestamp
    Firebase.setInt(firebaseData, "/sensores/gsr/timestamp", millis());
  }
  
  delay(100);
}

void connectToWiFi() {
  Serial.print("🔌 Conectando a WiFi: ");
  Serial.println(WIFI_SSID);
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 50) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.print("✅ Conectado con IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println();
    Serial.println("❌ No se pudo conectar a WiFi");
  }
}

// ===== INSTRUCCIONES =====
/*
1. INSTALAR LIBRERÍAS en Arduino IDE:
   - Sketch → Include Library → Manage Libraries
   - Buscar "Firebase ESP32" y instalar
   - Buscar "WiFi" (ya incluida normalmente)

2. CONFIGURAR:
   - Cambia "TU_RED_WIFI" con tu red WiFi
   - Cambia "TU_CONTRASEÑA" con tu contraseña
   - Cambiar FIREBASE_HOST y FIREBASE_AUTH

3. OBTENER CREDENCIALES FIREBASE:
   - Ve a Firebase Console
   - Realtime Database → Datos
   - Copia la URL (ej: https://tu-proyecto.firebaseio.com)
   - Ve a Reglas → Cambia a: {"rules": {".read": true, ".write": true}}
   - En Authentication obtén el token

4. SUBIR A ESP32:
   - Selecciona placa: ESP32 Dev Module
   - Selecciona puerto COM
   - Presiona Upload

5. VERIFICAR EN FIREBASE:
   - Ve a Firebase Console
   - Realtime Database
   - Deberías ver /sensores/gsr/valor actualizándose

6. FLUTTER LEERÁ AUTOMÁTICAMENTE:
   - Ya configuré el servicio Firebase en Flutter
   - Los datos aparecerán en tiempo real
*/
