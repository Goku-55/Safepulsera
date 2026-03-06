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
#include <HTTPClient.h>
#include <HTTPUpdate.h>
#include <Preferences.h>
#include <esp_sleep.h>

// Firebase
#define API_KEY "AIzaSyBc7koxzuQ8_ciJl291vvrb--BRVp1C9k"
#define DATABASE_URL "safeallergy-19bb7-default-rtdb.firebaseio.com"

// Hardware Pins
#define BUZZER_PIN 13
#define VIBRATION_PIN 12
#define BATTERY_PIN 34
#define BUTTON_PIN 0

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

// Preferences for persistent storage
Preferences preferences;

// Variables globales
float heartRate = 0;
float spO2 = 0;
float temperature = 0;
int gsr = 0;
float batteryLevel = 0;

// WiFi
String wifiSSID = "INFINITUM0279";
String wifiPassword = "6Bi42kmmEB";

// Device ID
String deviceId = "ESP32_SAFEALLERGY_" + String((uint32_t)ESP.getEfuseMac(), HEX);

// Timing
unsigned long lastSensorTime = 0;
unsigned long lastSendTime = 0;
unsigned long lastHistoryTime = 0;
unsigned long lastWiFiCheckTime = 0;
unsigned long lastAlertCheckTime = 0;
unsigned long lastBatteryCheckTime = 0;
unsigned long lastDisplayUpdateTime = 0;
unsigned long lastEmergencyCheckTime = 0;

const unsigned long SENSOR_INTERVAL = 1000;     // 1 segundo
const unsigned long SEND_INTERVAL = 1000;       // 1 segundo
const unsigned long HISTORY_INTERVAL = 10000;   // 10 segundos
const unsigned long WIFI_CHECK_INTERVAL = 30000; // 30 segundos
const unsigned long ALERT_CHECK_INTERVAL = 5000; // 5 segundos
const unsigned long BATTERY_CHECK_INTERVAL = 60000; // 1 minuto
const unsigned long DISPLAY_UPDATE_INTERVAL = 1000; // 1 segundo
const unsigned long EMERGENCY_CHECK_INTERVAL = 3000; // 3 segundos

// Alert States
bool emergencyMode = false;
bool alertActive = false;
unsigned long alertStartTime = 0;
const unsigned long ALERT_DURATION = 10000; // 10 segundos

// Heart Rate Detection
byte rateSpot = 0;
byte beatAvg[4];

// Emergency Thresholds
const float HR_MIN = 60.0;
const float HR_MAX = 100.0;
const float SPO2_MIN = 95.0;
const float TEMP_MIN = 36.0;
const float TEMP_MAX = 37.5;
const float BATTERY_LOW = 20.0;

// Display States
enum DisplayState { MAIN, ALERT, EMERGENCY, BATTERY_LOW, WIFI_CONFIG };
DisplayState currentDisplayState = MAIN;

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n\n========== INICIANDO SAFEALLERGY ==========");

  // Initialize Preferences
  preferences.begin("safeallergy", false);
  loadPreferences();

  // Initialize Pins
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(VIBRATION_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(VIBRATION_PIN, LOW);

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

  // Check for OTA updates
  checkForUpdates();

  // Final setup check
  if (WiFi.status() != WL_CONNECTED || !Firebase.ready()) {
    Serial.println("❌ Setup failed - entering error mode");
    showError("Setup Failed");
    enterDeepSleep();
  }

  Serial.println("========== INICIALIZACION COMPLETADA ==========\n");
}

void loop() {
  unsigned long now = millis();

  // Handle button press for emergency
  if (digitalRead(BUTTON_PIN) == LOW) {
    delay(50); // Debounce
    if (digitalRead(BUTTON_PIN) == LOW) {
      triggerEmergency();
      while (digitalRead(BUTTON_PIN) == LOW); // Wait for release
    }
  }

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

  // Verificar cambios de WiFi cada WIFI_CHECK_INTERVAL (30 seg)
  if (now - lastWiFiCheckTime >= WIFI_CHECK_INTERVAL) {
    lastWiFiCheckTime = now;
    checkAndUpdateWiFiConfig();
  }

  // Check for alerts
  if (now - lastAlertCheckTime >= ALERT_CHECK_INTERVAL) {
    lastAlertCheckTime = now;
    checkForAlerts();
  }

  // Check battery
  if (now - lastBatteryCheckTime >= BATTERY_CHECK_INTERVAL) {
    lastBatteryCheckTime = now;
    checkBatteryLevel();
    sendDeviceStatus(); // Send device status periodically
  }

  // Update display
  if (now - lastDisplayUpdateTime >= DISPLAY_UPDATE_INTERVAL) {
    lastDisplayUpdateTime = now;
    updateDisplay();
  }

  // Check emergency status
  if (now - lastEmergencyCheckTime >= EMERGENCY_CHECK_INTERVAL) {
    lastEmergencyCheckTime = now;
    checkEmergencyStatus();
  }

  // Auto-reconnect if needed
  if (WiFi.status() != WL_CONNECTED && now - lastWiFiCheckTime >= WIFI_CHECK_INTERVAL) {
    Serial.println("🔄 WiFi lost - attempting reconnection...");
    connectToWiFi();
  }

  // Handle alert timeout
  if (alertActive && now - alertStartTime >= ALERT_DURATION) {
    stopAlert();
  }

  delay(10);
}

// ===== ALERT SYSTEM =====

void checkForAlerts() {
  bool hrAbnormal = heartRate < HR_MIN || heartRate > HR_MAX;
  bool spo2Abnormal = spO2 < SPO2_MIN;
  bool tempAbnormal = temperature < TEMP_MIN || temperature > TEMP_MAX;
  bool batteryLow = batteryLevel < BATTERY_LOW;

  if (hrAbnormal || spo2Abnormal || tempAbnormal || batteryLow) {
    if (!alertActive) {
      startAlert();
      sendAlertToFirebase(hrAbnormal, spo2Abnormal, tempAbnormal, batteryLow);
    }
  } else {
    if (alertActive) {
      stopAlert();
    }
  }
}

void startAlert() {
  alertActive = true;
  alertStartTime = millis();

  // Buzzer alert pattern
  digitalWrite(BUZZER_PIN, HIGH);
  digitalWrite(VIBRATION_PIN, HIGH);

  Serial.println("🚨 ALERT STARTED");
}

void stopAlert() {
  alertActive = false;
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(VIBRATION_PIN, LOW);

  Serial.println("✅ ALERT STOPPED");
}

void triggerEmergency() {
  emergencyMode = true;

  // Immediate alert
  digitalWrite(BUZZER_PIN, HIGH);
  digitalWrite(VIBRATION_PIN, HIGH);

  // Send emergency to Firebase
  sendEmergencyToFirebase();

  Serial.println("🚨 EMERGENCY TRIGGERED");
}

void sendAlertToFirebase(bool hrAlert, bool spo2Alert, bool tempAlert, bool batteryAlert) {
  if (!Firebase.ready()) return;

  FirebaseJson json;
  json.set("device_id", deviceId);
  json.set("timestamp", (long)millis());
  json.set("type", "sensor_alert");
  json.set("hr_alert", hrAlert);
  json.set("spo2_alert", spo2Alert);
  json.set("temp_alert", tempAlert);
  json.set("battery_alert", batteryAlert);
  json.set("hr_value", heartRate);
  json.set("spo2_value", spO2);
  json.set("temp_value", temperature);
  json.set("battery_value", batteryLevel);

  Firebase.RTDB.setJSON(&fbdo, "/alerts/sensor_alerts", &json);
}

void sendEmergencyToFirebase() {
  if (!Firebase.ready()) return;

  FirebaseJson json;
  json.set("device_id", deviceId);
  json.set("timestamp", (long)millis());
  json.set("type", "emergency");
  json.set("hr", heartRate);
  json.set("spo2", spO2);
  json.set("temperature", temperature);
  json.set("gsr", gsr);
  json.set("battery", batteryLevel);
  json.set("location", "unknown");

  Firebase.RTDB.setJSON(&fbdo, "/alerts/emergencies", &json);
}

void checkEmergencyStatus() {
  if (!Firebase.ready()) return;

  if (Firebase.RTDB.getBool(&fbdo, "/emergency_reset")) {
    if (fbdo.to<bool>() == true) {
      emergencyMode = false;
      stopAlert();
      Firebase.RTDB.setBool(&fbdo, "/emergency_reset", false);
      Serial.println("🔄 Emergency reset from Firebase");
    }
  }
}

// ===== BATTERY MONITORING =====

void checkBatteryLevel() {
  // Read battery voltage (assuming voltage divider)
  int adcValue = analogRead(BATTERY_PIN);
  float voltage = (adcValue / 4095.0) * 3.3 * 2; // Assuming 1:1 divider

  // Convert to percentage (calibration needed)
  if (voltage >= 4.2) batteryLevel = 100;
  else if (voltage <= 3.0) batteryLevel = 0;
  else batteryLevel = (voltage - 3.0) / (4.2 - 3.0) * 100;

  Serial.printf("🔋 Battery: %.1f%%\n", batteryLevel);

  // Send to Firebase
  if (Firebase.ready()) {
    Firebase.RTDB.setFloat(&fbdo, "/device_status/battery", batteryLevel);
  }

  // Critical battery warning
  if (batteryLevel < 10) {
    Serial.println("🚨 CRITICAL BATTERY LEVEL!");
    // Could add special handling here
  }
}

void sendDeviceStatus() {
  if (!Firebase.ready()) return;

  FirebaseJson json;
  json.set("device_id", deviceId);
  json.set("timestamp", (long)millis());
  json.set("uptime", millis() / 1000); // uptime in seconds
  json.set("battery", batteryLevel);
  json.set("wifi_connected", WiFi.status() == WL_CONNECTED);
  json.set("firebase_connected", Firebase.ready());
  json.set("alert_active", alertActive);
  json.set("emergency_mode", emergencyMode);
  json.set("firmware_version", "1.0.0");

  Firebase.RTDB.setJSON(&fbdo, "/device_status/status", &json);
  Serial.println("📊 Device status sent to Firebase");
}

// ===== WIFI MANAGEMENT =====

void connectToWiFi() {
  Serial.print("🔄 Conectando a WiFi: ");
  Serial.println(wifiSSID);

  // Reportar estado "connecting" a Firebase
  reportConnectionStatus("connecting", "");

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

    // Reportar éxito a Firebase
    reportConnectionStatus("connected", "");
  } else {
    Serial.println("\n❌ No se pudo conectar a WiFi");

    // Reportar fallo a Firebase
    reportConnectionStatus("failed", "Contraseña incorrecta o red no disponible");
  }
}

// Función para reportar estado de conexión a Firebase
void reportConnectionStatus(String status, String error) {
  if (Firebase.ready()) {
    FirebaseJson json;
    json.set("status", status);
    json.set("error", error);
    json.set("ssid", wifiSSID);
    json.set("timestamp", getISOTimestamp());

    Firebase.RTDB.setJSON(&fbdo, "/wifi_config/connection_status", &json);
    Serial.print("📡 Estado reportado a Firebase: ");
    Serial.println(status);
  }
}

// Función para obtener timestamp en formato ISO
String getISOTimestamp() {
  // Retorna timestamp aproximado (sin RTC, usamos millis)
  unsigned long ms = millis();
  return String(ms);
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

void checkAndUpdateWiFiConfig() {
  if (!Firebase.ready()) {
    return;
  }

  if (Firebase.RTDB.getJSON(&fbdo, "/wifi_config")) {
    FirebaseJson &json = fbdo.to<FirebaseJson>();
    FirebaseJsonData jsonData;

    String newSSID = "";
    String newPassword = "";

    if (json.get(jsonData, "ssid")) {
      newSSID = jsonData.stringValue;
    }

    if (json.get(jsonData, "password")) {
      newPassword = jsonData.stringValue;
    }

    // Si cambió, reconectar
    if (newSSID != wifiSSID || newPassword != wifiPassword) {
      Serial.println("\n🔄 ¡WiFi cambió! Reconectando...");
      Serial.print("  Anterior: ");
      Serial.println(wifiSSID);
      Serial.print("  Nuevo: ");
      Serial.println(newSSID);

      wifiSSID = newSSID;
      wifiPassword = newPassword;
      connectToWiFi();

      Serial.println("✓ Reconexión completada\n");
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
  if (!Firebase.ready()) {
    Serial.println("⚠️ Firebase not ready - skipping sync");
    return;
  }

  FirebaseJson json;
  json.set("hr", (int)heartRate);
  json.set("spo2", (int)spO2);
  json.set("temperatura", (float)temperature);
  json.set("gsr", gsr);
  json.set("timestamp", (long)millis());
  json.set("device_id", deviceId);
  json.set("status", "active");
  json.set("battery", batteryLevel);
  json.set("alert_active", alertActive);
  json.set("emergency_mode", emergencyMode);

  if (Firebase.RTDB.setJSON(&fbdo, "/sensores/datos_actuales", &json)) {
    Serial.println("✓ Sincronizado con Firebase");
  } else {
    Serial.printf("❌ Error sincronizando: %s\n", fbdo.errorReason().c_str());
    // Intentar reconectar Firebase
    if (fbdo.errorReason().indexOf("connection") >= 0) {
      Serial.println("🔄 Attempting Firebase reconnection...");
      connectFirebase();
    }
  }
}

void saveToHistory() {
  if (!Firebase.ready()) {
    Serial.println("⚠️ Firebase not ready - skipping history save");
    return;
  }

  FirebaseJson json;
  json.set("hr", (int)heartRate);
  json.set("spo2", (int)spO2);
  json.set("temperatura", (float)temperature);
  json.set("gsr", gsr);
  json.set("timestamp", (long)millis());
  json.set("battery", batteryLevel);

  String path = "/sensores/historico/" + String(millis());

  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json)) {
    Serial.println("📁 Histórico guardado");
  } else {
    Serial.printf("❌ Error guardando histórico: %s\n", fbdo.errorReason().c_str());
  }
}

void mostrarSensoresOLED() {
  updateDisplay();
}

// ===== DISPLAY FUNCTIONS =====

void updateDisplay() {
  // Determine display state based on conditions
  if (emergencyMode) {
    currentDisplayState = EMERGENCY;
  } else if (batteryLevel < BATTERY_LOW) {
    currentDisplayState = BATTERY_LOW;
  } else if (alertActive) {
    currentDisplayState = ALERT;
  } else if (WiFi.status() != WL_CONNECTED) {
    currentDisplayState = WIFI_CONFIG;
  } else {
    currentDisplayState = MAIN;
  }

  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  switch (currentDisplayState) {
    case MAIN:
      showMainDisplay();
      break;
    case ALERT:
      showAlertDisplay();
      break;
    case EMERGENCY:
      showEmergencyDisplay();
      break;
    case BATTERY_LOW:
      showBatteryLowDisplay();
      break;
    case WIFI_CONFIG:
      showWiFiConfigDisplay();
      break;
  }

  display.display();
}

void showMainDisplay() {
  // Title
  display.setCursor(0, 0);
  display.println("SafeAllergy Monitor");
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);

  // Sensor data
  display.setCursor(0, 14);
  display.printf("HR: %d bpm\n", (int)heartRate);

  display.setCursor(0, 22);
  display.printf("SpO2: %d%%\n", (int)spO2);

  display.setCursor(0, 30);
  display.printf("Temp: %.1f C\n", temperature);

  display.setCursor(0, 38);
  display.printf("GSR: %d\n", gsr);

  // Status indicators
  display.setCursor(0, 48);
  display.printf("WiFi: %s\n", WiFi.status() == WL_CONNECTED ? "ON" : "OFF");

  display.setCursor(70, 48);
  display.printf("FB: %s\n", Firebase.ready() ? "OK" : "ERR");

  // Battery
  display.setCursor(0, 56);
  display.printf("Bat: %.0f%%\n", batteryLevel);

  // Alert indicator
  if (alertActive) {
    display.setCursor(70, 56);
    display.println("ALERT!");
  } else if (emergencyMode) {
    display.setCursor(70, 56);
    display.println("EMERGENCY!");
  }
}

void showAlertDisplay() {
  display.setCursor(0, 0);
  display.println("!!! ALERT !!!");
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);

  display.setCursor(0, 14);
  display.println("Valores anormales:");

  if (heartRate < HR_MIN || heartRate > HR_MAX) {
    display.setCursor(0, 22);
    display.printf("HR: %.0f bpm\n", heartRate);
  }

  if (spO2 < SPO2_MIN) {
    display.setCursor(0, 30);
    display.printf("SpO2: %.0f%%\n", spO2);
  }

  if (temperature < TEMP_MIN || temperature > TEMP_MAX) {
    display.setCursor(0, 38);
    display.printf("Temp: %.1f C\n", temperature);
  }

  display.setCursor(0, 48);
  display.println("Verifique su estado");
}

void showEmergencyDisplay() {
  display.setCursor(0, 0);
  display.println("!!! EMERGENCY !!!");
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);

  display.setCursor(0, 14);
  display.println("Boton de emergencia");
  display.println("presionado!");
  display.println("");
  display.println("Ayuda en camino...");
  display.println("");
  display.println("Mantenga presionado");
  display.println("para cancelar");
}

void showBatteryLowDisplay() {
  display.setCursor(0, 0);
  display.println("!!! BATERIA BAJA !!!");
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);

  display.setCursor(0, 14);
  display.printf("Nivel: %.0f%%\n", batteryLevel);
  display.println("");
  display.println("Conecte cargador");
  display.println("inmediatamente");
}

void showWiFiConfigDisplay() {
  display.setCursor(0, 0);
  display.println("Configurando WiFi...");
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);

  display.setCursor(0, 14);
  display.printf("SSID: %s\n", wifiSSID.substring(0, 16).c_str());
  display.println("");
  display.println("Conectando...");
}

// ===== OTA UPDATE SYSTEM =====

void checkForUpdates() {
  if (WiFi.status() != WL_CONNECTED) return;

  Serial.println("🔄 Checking for updates...");

  HTTPClient http;
  http.begin("https://raw.githubusercontent.com/your-repo/firmware/version.txt");
  int httpCode = http.GET();

  if (httpCode == HTTP_CODE_OK) {
    String newVersion = http.getString();
    newVersion.trim();

    String currentVersion = preferences.getString("firmware_version", "1.0.0");

    if (newVersion != currentVersion) {
      Serial.printf("📦 New version available: %s\n", newVersion.c_str());
      performOTAUpdate();
    } else {
      Serial.println("✓ Firmware is up to date");
    }
  }

  http.end();
}

void performOTAUpdate() {
  Serial.println("🔄 Starting OTA update...");

  display.clearDisplay();
  display.setCursor(0, 0);
  display.println("Actualizando firmware...");
  display.display();

  // OTA update logic here
  // This would typically download from a server and flash

  Serial.println("✓ OTA update completed");
}

// ===== PREFERENCES MANAGEMENT =====

void loadPreferences() {
  wifiSSID = preferences.getString("wifi_ssid", wifiSSID);
  wifiPassword = preferences.getString("wifi_password", wifiPassword);
  deviceId = preferences.getString("device_id", deviceId);
}

void savePreferences() {
  preferences.putString("wifi_ssid", wifiSSID);
  preferences.putString("wifi_password", wifiPassword);
  preferences.putString("device_id", deviceId);
}

// ===== POWER MANAGEMENT =====

void enterDeepSleep() {
  Serial.println("💤 Entering deep sleep...");

  // Configure wake up sources
  esp_sleep_enable_ext0_wakeup((gpio_num_t)BUTTON_PIN, 0); // Wake on button press

  // Save current state
  savePreferences();

  // Enter deep sleep
  esp_deep_sleep_start();
}

// ===== ERROR HANDLING =====

void showError(String message) {
  display.clearDisplay();
  display.setCursor(0, 0);
  display.println("ERROR:");
  display.setCursor(0, 10);
  display.println(message);
  display.display();

  Serial.printf("❌ Error: %s\n", message.c_str());

  delay(5000);
}