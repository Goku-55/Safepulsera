#include <Wire.h>
#include <Adafruit_MLX90614.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>

// ===== PANTALLA OLED =====
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// ===== Firebase =====
#define FIREBASE_HOST "safeallergy-19bb7-default-rtdb.firebaseio.com"
#define API_KEY "AIzaSyBc7koxzuQ8_ciJl291vvrb--BRVp1C9k"

// ===== Sensores =====
MAX30105 particleSensor;
Adafruit_MLX90614 mlx = Adafruit_MLX90614();
const int GSR_PIN = 2;

// ===== Firebase =====
FirebaseData fbdo;
FirebaseConfig config;
unsigned long sendDataPrevMillis = 0;

// ===== Variables MAX30102 =====
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute = 0;
int spo2 = 95;

unsigned long lastSensorTime = 0;
const unsigned long SENSOR_INTERVAL = 1000;

// ===== WiFi Variables =====
String wifiSSID = "INFINITUM0279";
String wifiPassword = "6Bi42kmmEB";
bool wifiConfigLoaded = false;
unsigned long lastWiFiCheckTime = 0;
const unsigned long WIFI_CHECK_INTERVAL = 10000; // Verificar cada 10s

// ===== Variables de envío de datos en tiempo real =====
const unsigned long SEND_INTERVAL = 1000; // Enviar cada 1 segundo
const uint8_t MAX_RETRIES = 2;
uint8_t sendRetries = 0;
bool lastSendSuccess = false;
unsigned long lastSuccessfulSend = 0;
bool firebaseReady = false;

void setup() {
  Serial.begin(115200);
  delay(2000);
  Serial.println("\n\n🚀 SafeAllergy - Sistema Multi-Sensor");
  Serial.println("======================================\n");

  // ===== Inicializar I2C =====
  Wire.begin(12, 15);
  
  // ===== Inicializar OLED =====
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("❌ OLED NO ENCONTRADA");
  } else {
    Serial.println("✅ OLED inicializada");
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.println("SafeAllergy");
    display.println("Inicializando...");
    display.display();
    delay(1000);
  }
  
  // ===== MAX30102 =====
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("❌ MAX30102 NO ENCONTRADO");
  } else {
    Serial.println("✅ MAX30102 inicializado");
    particleSensor.setup(60, 4, 2, 100, 411, 4096);
  }

  // ===== MLX90614 =====
  if (!mlx.begin()) {
    Serial.println("❌ MLX90614 NO ENCONTRADO");
  } else {
    Serial.println("✅ MLX90614 inicializado");
  }

  Serial.println("✅ GSR inicializado (GPIO 2)\n");

  // ===== Conectar WiFi primero =====
  connectToWiFi();
  delay(1000);
  
  // ===== Conectar Firebase =====
  connectFirebase();
  delay(1000);
  
  // ===== Cargar configuración WiFi desde Firebase (OPCIÓN 2) =====
  loadWiFiConfigFromFirebase();
  delay(2000);
}

void loop() {
  unsigned long currentTime = millis();
  
  // ===== Verificar WiFi =====
  if (currentTime - lastWiFiCheckTime >= WIFI_CHECK_INTERVAL) {
    lastWiFiCheckTime = currentTime;
    
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("⚠️  WiFi desconectado, reintentando...");
      connectToWiFi();
    }
  }
  
  // ===== Leer sensores cada 1 segundo =====
  if (currentTime - lastSensorTime >= SENSOR_INTERVAL) {
    lastSensorTime = currentTime;
    
    readMAX30102();
    float bodyTemp = readMLX90614();
    int gsrValue = readGSR();
    
    Serial.println("\n📊 ===== LECTURA DE SENSORES =====");
    Serial.print("❤️  Ritmo Cardíaco: ");
    Serial.print(beatsPerMinute, 1);
    Serial.println(" BPM");
    Serial.print("🫁 SpO2: ");
    Serial.print(spo2);
    Serial.println(" %");
    Serial.print("🌡️  Temperatura: ");
    Serial.print(bodyTemp, 1);
    Serial.println(" °C");
    Serial.print("⚡ GSR: ");
    Serial.println(gsrValue);
    Serial.println("==================================\n");
    
    // Mostrar en OLED
    mostrarSensoresOLED(beatsPerMinute, spo2, bodyTemp, gsrValue);
    
    // Enviar a Firebase cada 5 segundos
    if (currentTime - sendDataPrevMillis >= SEND_INTERVAL) {
      sendDataPrevMillis = currentTime;
      sendSensorDataToFirebase(beatsPerMinute, spo2, bodyTemp, gsrValue);
    }
  }
}

// ===== CONECTAR FIREBASE =====
void connectFirebase() {
  Serial.println("📡 Conectando a Firebase...");
  
  config.api_key = API_KEY;
  config.database_url = FIREBASE_HOST;
  config.timeout.socketConnection = 5 * 1000;
  config.timeout.socketRead = 5 * 1000;

  Firebase.begin(&config, NULL);
  Firebase.reconnectNetwork(true);
  
  int attempts = 0;
  while (!Firebase.ready() && attempts < 10) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (Firebase.ready()) {
    firebaseReady = true;
    Serial.println("\n✅ Firebase listo para enviar\n");
  } else {
    Serial.println("\n⚠️  Firebase en modo degradado\n");
  }
}

// ===== CARGAR WIFI DESDE FIREBASE =====
void loadWiFiConfigFromFirebase() {
  Serial.println("📡 Cargando configuración WiFi desde Firebase...");
  
  try {
    if (Firebase.RTDB.getJSON(&fbdo, "/wifi_config")) {
      FirebaseJson json;
      json.setJsonData(fbdo.to<const char*>());
      
      FirebaseJsonData jsonObj;
      json.get(jsonObj, "ssid");
      if (jsonObj.success) {
        wifiSSID = jsonObj.stringValue;
      }
      
      json.get(jsonObj, "password");
      if (jsonObj.success) {
        wifiPassword = jsonObj.stringValue;
      }
      
      if (wifiSSID.length() > 0 && wifiPassword.length() > 0) {
        Serial.print("✅ WiFi encontrado: ");
        Serial.println(wifiSSID);
        connectToWiFi();
      } else {
        Serial.println("⚠️  No hay WiFi configurado en Firebase");
      }
    } else {
      Serial.println("⚠️  No se pudo leer wifi_config: " + String(fbdo.errorReason()));
    }
  } catch (e) {
    Serial.println("❌ Error cargando WiFi: " + String(e));
  }
}

// ===== CONECTAR A WIFI =====
void connectToWiFi() {
  if (wifiSSID.length() == 0) {
    Serial.println("❌ No hay SSID configurado");
    return;
  }
  
  Serial.print("📡 Conectando a: ");
  Serial.println(wifiSSID);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi conectado");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
    wifiConfigLoaded = true;
  } else {
    Serial.println("\n❌ No se pudo conectar a WiFi");
  }
}

// ===== LEER MAX30102 =====
void readMAX30102() {
  long irValue = particleSensor.getIR();
  
  if (checkForBeat(irValue) == true) {
    long delta = millis() - lastBeat;
    lastBeat = millis();
    
    beatsPerMinute = 60 / (delta / 1000.0);
    
    if (beatsPerMinute < 255 && beatsPerMinute > 20) {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= RATE_SIZE;
    }
  }
  
  // SpO2 estimado
  spo2 = 95 + (irValue / 10000000);
  if (spo2 > 100) spo2 = 100;
  if (spo2 < 80) spo2 = 80;
}

// ===== LEER MLX90614 =====
float readMLX90614() {
  return mlx.readObjectTempC();
}

// ===== LEER GSR =====
int readGSR() {
  return analogRead(GSR_PIN);
}

// ===== ENVIAR DATOS EN TIEMPO REAL A FIREBASE =====
void sendSensorDataToFirebase(float hr, int sp02, float temp, int gsr) {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  if (!firebaseReady) {
    return;
  }

  // Crear objeto JSON con todos los datos
  FirebaseJson json;
  json.set("hr", round(hr * 10) / 10.0);
  json.set("spo2", sp02);
  json.set("temperatura", round(temp * 10) / 10.0);
  json.set("gsr", gsr);
  json.set("timestamp", (double)millis());
  json.set("device_id", "ESP32_SAFEALLERGY");
  json.set("status", "active");

  // Enviar datos actuales (para lectura en tiempo real)
  if (Firebase.RTDB.setJSON(&fbdo, "/sensores/datos_actuales", &json)) {
    lastSuccessfulSend = millis();
    lastSendSuccess = true;
    
    // Solo log cada 5 envíos para evitar spam
    static uint32_t sendCount = 0;
    if (sendCount++ % 5 == 0) {
      Serial.print("✅ Sincronizado #");
      Serial.println(sendCount);
    }
    
    // Guardar histórico cada 10 intentos (10 segundos)
    if (sendCount % 10 == 0) {
      saveHistoricalData(hr, sp02, temp, gsr);
    }
  } else {
    lastSendSuccess = false;
  }
}

// ===== GUARDAR DATOS HISTÓRICOS EN FIREBASE =====
void saveHistoricalData(float hr, int sp02, float temp, int gsr) {
  if (WiFi.status() != WL_CONNECTED || !firebaseReady) return;

  FirebaseJson historyJson;
  historyJson.set("hr", round(hr * 10) / 10.0);
  historyJson.set("spo2", sp02);
  historyJson.set("temperatura", round(temp * 10) / 10.0);
  historyJson.set("gsr", gsr);
  historyJson.set("timestamp", (double)millis());

  String pathHistorico = "/sensores/historico/" + String(millis());
  
  if (Firebase.RTDB.setJSON(&fbdo, pathHistorico, &historyJson)) {
    Serial.println("✅ Histórico guardado");
  }
}

// ===== FUNCIONES OLED =====

// Mostrar mensaje simple en OLED
void mostrarOLED(const char* linea1, const char* linea2, const char* linea3) {
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println(linea1);
  
  display.setTextSize(1);
  display.setCursor(0, 30);
  display.println(linea2);
  display.setCursor(0, 45);
  display.println(linea3);
  
  display.display();
}

// Mostrar todos los sensores en OLED
void mostrarSensoresOLED(float hr, int sp02, float temp, int gsr) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  
  // Fila 1: Ritmo Cardíaco
  display.setCursor(0, 0);
  display.print("HR: ");
  display.print(hr, 0);
  display.println(" BPM");
  
  // Fila 2: SpO2
  display.setCursor(0, 10);
  display.print("SpO2: ");
  display.print(sp02);
  display.println(" %");
  
  // Fila 3: Temperatura
  display.setCursor(0, 20);
  display.print("Temp: ");
  display.print(temp, 1);
  display.println(" C");
  
  // Fila 4: GSR
  display.setCursor(0, 30);
  display.print("GSR: ");
  display.println(gsr);
  
  // Línea separadora
  display.drawLine(0, 40, 128, 40, SSD1306_WHITE);
  
  // Estado WiFi
  display.setCursor(0, 45);
  display.setTextSize(1);
  if (WiFi.status() == WL_CONNECTED) {
    display.print("WiFi: ON");
  } else {
    display.print("WiFi: OFF");
  }
  
  // Estado Firebase
  display.setCursor(70, 45);
  display.print("FB: ");
  if (Firebase.ready()) {
    display.println("OK");
  } else {
    display.println("XX");
  }
  
  display.display();
}
