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
#define API_KEY "AIzaSyDummy"

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
// ⚠️ CAMBIA ESTAS CREDENCIALES CON TU WIFI
String wifiSSID = "JUANITO";        // 👈 CAMBIAR
String wifiPassword = "12345678910";  // 👈 CAMBIAR
bool wifiConfigLoaded = false;
unsigned long lastWiFiCheckTime = 0;
const unsigned long WIFI_CHECK_INTERVAL = 10000;

void setup() {
  Serial.begin(115200);
  delay(2000);
  Serial.println("\n\n🚀 SafeAllergy - Sistema Multi-Sensor OLED");
  Serial.println("==========================================\n");

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
    mostrarOLED("MAX30102", "NO ENCONTRADO", "ERROR");
  } else {
    Serial.println("✅ MAX30102 inicializado");
    particleSensor.setup(60, 4, 2, 100, 411, 4096);
    mostrarOLED("MAX30102", "OK", "");
  }
  delay(500);

  // ===== MLX90614 =====
  if (!mlx.begin()) {
    Serial.println("❌ MLX90614 NO ENCONTRADO");
    mostrarOLED("MLX90614", "NO ENCONTRADO", "ERROR");
  } else {
    Serial.println("✅ MLX90614 inicializado");
    mostrarOLED("MLX90614", "OK", "");
  }
  delay(500);

  Serial.println("✅ GSR inicializado (GPIO 2)\n");
  mostrarOLED("GSR", "OK", "");
  delay(500);

  // ===== Conectar WiFi primero =====
  connectToWiFi();
  
  // ===== Conectar Firebase =====
  delay(1000);
  connectFirebase();
  
  // ===== Cargar WiFi desde Firebase (si está disponible) =====
  delay(2000);
  if (wifiConfigLoaded) {
    mostrarOLED("WiFi", "Cargando...", "Firebase");
    loadWiFiConfigFromFirebase();
  }
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
    
    // Mostrar valores en Serial
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
    
    // ===== Mostrar en OLED =====
    mostrarSensoresOLED(beatsPerMinute, spo2, bodyTemp, gsrValue);
    
    // Enviar a Firebase cada 5 segundos
    if (currentTime - sendDataPrevMillis > 5000) {
      sendDataPrevMillis = currentTime;
      sendToFirebase(beatsPerMinute, spo2, bodyTemp, gsrValue);
    }
  }
}

// ===== CONECTAR FIREBASE =====
void connectFirebase() {
  Serial.println("📡 Conectando a Firebase...");
  mostrarOLED("Firebase", "Conectando...", "");
  
  config.api_key = API_KEY;
  config.database_url = FIREBASE_HOST;
  config.timeout.socketConnection = 10 * 1000;
  config.timeout.socketRead = 10 * 1000;

  Firebase.begin(&config, NULL);
  Firebase.reconnectNetwork(true);
  
  Serial.println("✅ Firebase configurado\n");
  mostrarOLED("Firebase", "Listo", "");
  delay(1000);
}

// ===== CARGAR WIFI DESDE FIREBASE =====
void loadWiFiConfigFromFirebase() {
  Serial.println("📡 Cargando configuración WiFi desde Firebase...");
  mostrarOLED("WiFi Config", "Leyendo FB...", "");
  
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
        mostrarOLED("WiFi", wifiSSID.c_str(), "Conectando...");
        connectToWiFi();
      } else {
        Serial.println("⚠️  No hay WiFi configurado en Firebase");
        mostrarOLED("WiFi Config", "No encontrada", "En Firebase");
        delay(2000);
      }
    } else {
      Serial.println("⚠️  Error: " + String(fbdo.errorReason()));
      mostrarOLED("WiFi Config", "Error en FB", fbdo.errorReason().c_str());
      delay(2000);
    }
  } catch (e) {
    Serial.println("❌ Error: " + String(e));
    mostrarOLED("Error", "Cargando WiFi", "");
    delay(2000);
  }
}

// ===== CONECTAR A WIFI =====
void connectToWiFi() {
  if (wifiSSID.length() == 0) {
    Serial.println("❌ No hay SSID configurado");
    mostrarOLED("Error", "Sin SSID", "Configura en app");
    return;
  }
  
  Serial.print("📡 Conectando a: ");
  Serial.println(wifiSSID);
  mostrarOLED("WiFi", "Conectando", wifiSSID.c_str());
  
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
    mostrarOLED("WiFi", "Conectado", WiFi.localIP().toString().c_str());
    wifiConfigLoaded = true;
    delay(2000);
  } else {
    Serial.println("\n❌ No se pudo conectar a WiFi");
    mostrarOLED("WiFi", "Error", "Reintentando...");
    delay(2000);
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

// ===== ENVIAR A FIREBASE =====
void sendToFirebase(float hr, int sp02, float temp, int gsr) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️  WiFi desconectado");
    return;
  }

  // Enviar ritmo cardíaco
  if (Firebase.RTDB.setFloat(&fbdo, "/sensores/hr/valor", hr)) {
    Serial.println("✅ HR enviado");
  }

  // Enviar SpO2
  if (Firebase.RTDB.setInt(&fbdo, "/sensores/spo2/valor", sp02)) {
    Serial.println("✅ SpO2 enviado");
  }

  // Enviar Temperatura
  if (Firebase.RTDB.setFloat(&fbdo, "/sensores/temperatura/valor", temp)) {
    Serial.println("✅ Temperatura enviada");
  }

  // Enviar GSR
  if (Firebase.RTDB.setInt(&fbdo, "/sensores/gsr/valor", gsr)) {
    Serial.println("✅ GSR enviado");
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
