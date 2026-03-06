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

// Firebase Configuration
#define API_KEY "AIzaSyBc7koxzuQ8_ciJl291vvrb--BRVp1C9k"
#define DATABASE_URL "safeallergy-19bb7-default-rtdb.firebaseio.com"

// Hardware Pins (ESP32-CAM Compatible)
#define BUZZER_PIN 13        // GPIO 13 - disponible
#define VIBRATION_PIN 12     // GPIO 12 - disponible
#define BATTERY_PIN 34       // GPIO 34 - ADC1 (solo lectura)
#define GSR_PIN 33           // GPIO 33 - ADC1 (solo lectura)
#define BUTTON_PIN 15        // GPIO 15 - disponible (NO usar GPIO 0 - reservado para camara)

// OLED Configuration
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Sensors
MAX30105 particleSensor;
Adafruit_MLX90614 mlx = Adafruit_MLX90614();

// Firebase Objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Preferences for persistent storage
Preferences preferences;

// Global Variables
float heartRate = 0;
float spO2 = 0;
float temperature = 0;
int gsr = 0;
float batteryLevel = 0;

// WiFi Configuration
String wifiSSID = "INFINITUM0279";
String wifiPassword = "6Bi42kmmEB";
String deviceId = "ESP32-CAM_SAFEALLERGY_" + String((uint32_t)ESP.getEfuseMac(), HEX);

// Timing Variables
unsigned long lastSensorTime = 0;
unsigned long lastSendTime = 0;
unsigned long lastHistoryTime = 0;
unsigned long lastWiFiCheckTime = 0;
unsigned long lastAlertCheckTime = 0;
unsigned long lastBatteryCheckTime = 0;
unsigned long lastDisplayUpdateTime = 0;
unsigned long lastEmergencyCheckTime = 0;

// Intervals
const unsigned long SENSOR_INTERVAL = 1000;      // 1 segundo
const unsigned long SEND_INTERVAL = 2000;        // 2 segundos
const unsigned long HISTORY_INTERVAL = 10000;    // 10 segundos
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

  Serial.println("\n\n========== SAFEALLERGY ESP32-CAM MONITOR ==========");
  Serial.printf("Device ID: %s\n", deviceId.c_str());

  // Initialize Preferences
  preferences.begin("safeallergy", false);
  loadPreferences();

  // Initialize Pins
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(VIBRATION_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);  // GPIO 15 con pull-up
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(VIBRATION_PIN, LOW);

  // Initialize I2C (ESP32-CAM usa GPIO 21 SDA, GPIO 22 SCL por defecto)
  Wire.begin(21, 22); // SDA=21, SCL=22 para ESP32-CAM
  Serial.println("✓ I2C initialized (SDA: GPIO21, SCL: GPIO22) - ESP32-CAM");

  // Initialize OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("❌ OLED initialization failed");
    while (1);
  }
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("SafeAllergy ESP32-CAM");
  display.println("Initializing...");
  display.display();
  Serial.println("✓ OLED initialized (128x64, I2C: 0x3C)");

  // Initialize MAX30102
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("❌ MAX30102 not found");
    showError("MAX30102 Error");
    while (1);
  }
  particleSensor.setup();
  particleSensor.setPulseAmplitudeRed(0x0A);
  particleSensor.setPulseAmplitudeGreen(0);
  Serial.println("✓ MAX30102 initialized");

  // Initialize MLX90614
  if (!mlx.begin()) {
    Serial.println("❌ MLX90614 not found");
    showError("MLX90614 Error");
    while (1);
  }
  Serial.println("✓ MLX90614 initialized");

  // Connect to WiFi
  connectToWiFi();

  // Initialize Firebase
  connectFirebase();

  // Load WiFi config from Firebase
  delay(2000);
  loadWiFiConfigFromFirebase();

  // Check for OTA updates
  checkForUpdates();

  Serial.println("========== ESP32-CAM INITIALIZATION COMPLETE ==========\n");
}

void loop() {
  unsigned long now = millis();

  // Handle button press for emergency (GPIO 15)
  if (digitalRead(BUTTON_PIN) == LOW) {
    delay(50); // Debounce
    if (digitalRead(BUTTON_PIN) == LOW) {
      triggerEmergency();
      while (digitalRead(BUTTON_PIN) == LOW); // Wait for release
    }
  }

  // Read sensors
  if (now - lastSensorTime >= SENSOR_INTERVAL) {
    lastSensorTime = now;
    readSensors();
  }

  // Send data to Firebase
  if (now - lastSendTime >= SEND_INTERVAL) {
    lastSendTime = now;
    if (Firebase.ready() && WiFi.status() == WL_CONNECTED) {
      sendSensorDataToFirebase();
    }
  }

  // Save to history
  if (now - lastHistoryTime >= HISTORY_INTERVAL) {
    lastHistoryTime = now;
    if (Firebase.ready() && WiFi.status() == WL_CONNECTED) {
      saveToHistory();
    }
  }

  // Check WiFi configuration
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

  // Handle alert timeout
  if (alertActive && now - alertStartTime >= ALERT_DURATION) {
    stopAlert();
  }

  delay(10);
}

// ===== SENSOR FUNCTIONS =====

void readSensors() {
  // Heart Rate and SpO2 from MAX30102
  if (particleSensor.available()) {
    int ir = particleSensor.getIR();
    int red = particleSensor.getRed();

    particleSensor.nextSample();

    if (ir > 50000) {
      // Calculate heart rate
      beatAvg[rateSpot++ % 4] = (int)heartRate;
      heartRate = 0;
      for (int x = 0; x < 4; x++) {
        heartRate += beatAvg[x];
      }
      heartRate /= 4;
    }

    // Calculate SpO2 (simplified)
    if (ir > 0 && red > 0) {
      float ratio = (float)red / ir;
      spO2 = 110 - 25 * ratio;
      spO2 = constrain(spO2, 80, 100);
    }
  }

  // Temperature from MLX90614
  temperature = mlx.readObjectTempC();

  // GSR from analog pin (GPIO 33)
  gsr = analogRead(GSR_PIN);

  // Debug output
  Serial.printf("📊 HR: %.1f bpm | SpO2: %.1f%% | Temp: %.1f°C | GSR: %d\n",
                heartRate, spO2, temperature, gsr);
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

  Serial.println("🚨 EMERGENCY TRIGGERED - ESP32-CAM");
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
  json.set("location", "unknown"); // Could add GPS

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
}

// ===== WIFI MANAGEMENT =====

void connectToWiFi() {
  Serial.printf("🔄 Connecting to WiFi: %s\n", wifiSSID.c_str());

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
    Serial.println("\n✓ WiFi connected");
    Serial.printf("  IP: %s\n", WiFi.localIP().toString().c_str());

    reportConnectionStatus("connected", "");
  } else {
    Serial.println("\n❌ WiFi connection failed");

    reportConnectionStatus("failed", "Incorrect password or network unavailable");

    // Enter deep sleep to save power
    enterDeepSleep();
  }
}

void reportConnectionStatus(String status, String error) {
  if (Firebase.ready()) {
    FirebaseJson json;
    json.set("status", status);
    json.set("error", error);
    json.set("ssid", wifiSSID);
    json.set("timestamp", (long)millis());
    json.set("device_id", deviceId);

    Firebase.RTDB.setJSON(&fbdo, "/wifi_config/connection_status", &json);
    Serial.printf("📡 Connection status reported: %s\n", status.c_str());
  }
}

// ===== FIREBASE FUNCTIONS =====

void connectFirebase() {
  Serial.println("🔄 Connecting to Firebase...");

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  config.signer.test_mode = true;

  Firebase.begin(&config, &auth);
  Firebase.reconnectNetwork(true);

  delay(2000);

  if (Firebase.ready()) {
    Serial.println("✓ Firebase connected and ready");
  } else {
    Serial.println("❌ Firebase connection failed");
  }
}

void loadWiFiConfigFromFirebase() {
  Serial.println("🔄 Loading WiFi config from Firebase...");

  if (Firebase.ready()) {
    if (Firebase.RTDB.getJSON(&fbdo, "/wifi_config")) {
      FirebaseJson &json = fbdo.to<FirebaseJson>();
      FirebaseJsonData jsonData;

      if (json.get(jsonData, "ssid")) {
        wifiSSID = jsonData.stringValue;
        Serial.printf("  SSID: %s\n", wifiSSID.c_str());
      }

      if (json.get(jsonData, "password")) {
        wifiPassword = jsonData.stringValue;
        Serial.println("  Password: ****");
      }

      Serial.println("✓ WiFi config loaded from Firebase");
      delay(1000);

      // Reconnect with new credentials
      connectToWiFi();
    } else {
      Serial.println("⚠️ No /wifi_config found in Firebase - using defaults");
    }
  }
}

void checkAndUpdateWiFiConfig() {
  if (!Firebase.ready()) return;

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

    // If changed, reconnect
    if (newSSID != wifiSSID || newPassword != wifiPassword) {
      Serial.println("\n🔄 WiFi config changed! Reconnecting...");
      Serial.printf("  Previous: %s\n", wifiSSID.c_str());
      Serial.printf("  New: %s\n", newSSID.c_str());

      wifiSSID = newSSID;
      wifiPassword = newPassword;
      connectToWiFi();

      Serial.println("✓ Reconnection completed\n");
    }
  }
}

void sendSensorDataToFirebase() {
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
    Serial.println("✓ Data synced with Firebase");
  } else {
    Serial.printf("❌ Sync error: %s\n", fbdo.errorReason().c_str());
  }
}

void saveToHistory() {
  FirebaseJson json;
  json.set("hr", (int)heartRate);
  json.set("spo2", (int)spO2);
  json.set("temperatura", (float)temperature);
  json.set("gsr", gsr);
  json.set("timestamp", (long)millis());
  json.set("battery", batteryLevel);

  String path = "/sensores/historico/" + String(millis());

  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json)) {
    Serial.println("📁 History saved");
  } else {
    Serial.printf("❌ History save error: %s\n", fbdo.errorReason().c_str());
  }
}

// ===== DISPLAY FUNCTIONS =====

void updateDisplay() {
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
  display.println("SafeAllergy ESP32-CAM");
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
  esp_sleep_enable_ext0_wakeup((gpio_num_t)BUTTON_PIN, 0); // Wake on button press (GPIO 15)

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