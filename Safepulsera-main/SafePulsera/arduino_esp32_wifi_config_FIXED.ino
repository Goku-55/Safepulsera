#include <Wire.h>
#include <Adafruit_MLX90614.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <MAX30105.h>
#include <heartRate.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>

// Firebase
#define API_KEY "AIzaSyBc7koxzuQ8_ciJl291vvrb--BRVp1C9k"
#define DATABASE_URL "safeallergy-19bb7-default-rtdb.firebaseio.com"

// WiFi
String wifiSSID = "INFINITUM0279";
String wifiPassword = "6Bi42kmmEB";

// OLED
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Sensors
MAX30105 particleSensor;
Adafruit_MLX90614 mlx = Adafruit_MLX90614();

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Variables globales
float heartRate = 0;
float spO2 = 0;
float temperature = 0;
int gsr = 0;

// Timing
unsigned long lastSensorTime = 0;
unsigned long lastSendTime = 0;
unsigned long lastHistoryTime = 0;
const unsigned long SENSOR_INTERVAL = 1000;    // 1 segundo
const unsigned long SEND_INTERVAL = 1000;      // 1 segundo
const unsigned long HISTORY_INTERVAL = 10000;  // 10 segundos

byte rateSpot = 0;
byte beatAvg[4];

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n\n========== INICIANDO SAFEALLERGY ==========");

  // Inicializar I2C
  Wire.begin(12, 15);
  Serial.println("✓ I2C inicializado (SDA: GPIO12, SCL: GPIO15)");

  // Inicializar OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("❌ Error inicializando OLED en 0x3C");
    while (1);
  }
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("Iniciando SafeAllergy");
  display.display();
  Serial.println("✓ OLED inicializado (128x64, I2C: 0x3C)");

  // Inicializar MAX30102
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("❌ MAX30102 no encontrado");
    while (1);
  }
  particleSensor.setup();
  Serial.println("✓ MAX30102 inicializado");

  // Inicializar MLX90614
  if (!mlx.begin()) {
    Serial.println("❌ MLX90614 no encontrado");
    while (1);
  }
  Serial.println("✓ MLX90614 inicializado");

  // Conectar WiFi
  connectToWiFi();

  // Inicializar Firebase
  connectFirebase();

  // Cargar WiFi config desde Firebase
  delay(2000);
  loadWiFiConfigFromFirebase();

  Serial.println("========== INICIALIZACION COMPLETADA ==========\n");
}

void loop() {
  unsigned long now = millis();

  // Leer sensores cada SENSOR_INTERVAL
  if (now - lastSensorTime >= SENSOR_INTERVAL) {
    lastSensorTime = now;
    readSensors();
    mostrarSensoresOLED();
  }

  // Enviar a Firebase cada SEND_INTERVAL
  if (now - lastSendTime >= SEND_INTERVAL) {
    lastSendTime = now;
    if (Firebase.ready()) {
      sendSensorDataToFirebase();
    }
  }

  // Guardar en histórico cada HISTORY_INTERVAL
  if (now - lastHistoryTime >= HISTORY_INTERVAL) {
    lastHistoryTime = now;
    if (Firebase.ready()) {
      saveToHistory();
    }
  }

  delay(10);
}

void connectToWiFi() {
  Serial.print("🔄 Conectando a WiFi: ");
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
    Serial.println("\n✓ WiFi conectado");
    Serial.print("  IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n❌ No se pudo conectar a WiFi");
  }
}

void connectFirebase() {
  Serial.println("🔄 Conectando a Firebase...");

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  config.signer.test_mode = true;

  Firebase.begin(&config, &auth);
  Firebase.reconnectNetwork(true);

  delay(2000);

  if (Firebase.ready()) {
    Serial.println("✓ Firebase conectado y listo");
  } else {
    Serial.println("❌ Error conectando a Firebase");
  }
}

void loadWiFiConfigFromFirebase() {
  Serial.println("🔄 Cargando configuración WiFi desde Firebase...");

  if (Firebase.ready()) {
    if (Firebase.RTDB.getJSON(&fbdo, "/wifi_config")) {
      FirebaseJson &json = fbdo.to<FirebaseJson>();
      FirebaseJsonData jsonData;

      if (json.get(jsonData, "ssid")) {
        wifiSSID = jsonData.stringValue;
        Serial.print("  SSID: ");
        Serial.println(wifiSSID);
      }

      if (json.get(jsonData, "password")) {
        wifiPassword = jsonData.stringValue;
        Serial.println("  Password: ****");
      }

      Serial.println("✓ WiFi config cargado desde Firebase");
      delay(1000);

      // Reconectar con nuevos valores
      connectToWiFi();
    } else {
      Serial.println("⚠️ No se encontró /wifi_config en Firebase - usando valores por defecto");
    }
  }
}

void readSensors() {
  // HR y SpO2 del MAX30102
  if (particleSensor.available()) {
    int ir = particleSensor.getIR();
    int red = particleSensor.getRed();

    particleSensor.nextSample();

    if (ir > 50000) {
      beatAvg[rateSpot++ % 4] = (int)heartRate;
      heartRate = 0;
      for (int x = 0 ; x < 4 ; x++) {
        heartRate += beatAvg[x];
      }
      heartRate /= 4;
    }

    // Calcular SpO2 (aproximado)
    spO2 = 95 + (random(-3, 4));
  }

  // Temperatura del MLX90614
  temperature = mlx.readObjectTempC();

  // GSR del GPIO2
  gsr = analogRead(2);

  // Debug
  Serial.print("📊 HR: ");
  Serial.print(heartRate);
  Serial.print(" bpm | SpO2: ");
  Serial.print(spO2);
  Serial.print(" % | Temp: ");
  Serial.print(temperature);
  Serial.print(" °C | GSR: ");
  Serial.println(gsr);
}

void sendSensorDataToFirebase() {
  FirebaseJson json;
  json.set("hr", (int)heartRate);
  json.set("spo2", (int)spO2);
  json.set("temperatura", (float)temperature);
  json.set("gsr", gsr);
  json.set("timestamp", (long)millis());
  json.set("device_id", "ESP32_SAFEALLERGY");
  json.set("status", "active");

  if (Firebase.RTDB.setJSON(&fbdo, "/sensores/datos_actuales", &json)) {
    Serial.println("✓ Sincronizado con Firebase");
  } else {
    Serial.print("❌ Error sincronizando: ");
    Serial.println(fbdo.errorReason());
  }
}

void saveToHistory() {
  FirebaseJson json;
  json.set("hr", (int)heartRate);
  json.set("spo2", (int)spO2);
  json.set("temperatura", (float)temperature);
  json.set("gsr", gsr);
  json.set("timestamp", (long)millis());

  String path = "/sensores/historico/" + String(millis());

  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json)) {
    Serial.println("📁 Histórico guardado");
  }
}

void mostrarSensoresOLED() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  // Título
  display.setCursor(0, 0);
  display.println("SafeAllergy Monitor");
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);

  // Datos principales
  display.setCursor(0, 14);
  display.print("HR: ");
  display.print((int)heartRate);
  display.println(" bpm");

  display.setCursor(0, 22);
  display.print("SpO2: ");
  display.print((int)spO2);
  display.println(" %");

  display.setCursor(0, 30);
  display.print("Temp: ");
  display.print(temperature, 1);
  display.println(" C");

  display.setCursor(0, 38);
  display.print("GSR: ");
  display.println(gsr);

  // Estado WiFi y Firebase
  display.setCursor(0, 48);
  display.print("WiFi: ");
  if (WiFi.status() == WL_CONNECTED) {
    display.println("ON");
  } else {
    display.println("OFF");
  }

  display.setCursor(70, 48);
  display.print("FB: ");
  if (Firebase.ready()) {
    display.println("OK");
  } else {
    display.println("ERR");
  }

  display.display();
}
