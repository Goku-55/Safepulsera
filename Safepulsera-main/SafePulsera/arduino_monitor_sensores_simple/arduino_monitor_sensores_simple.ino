#include <Preferences.h>

// Firebase
#define API_KEY "AIzaSyBc7koxzuQ8_ciJl291vvrb--BRVp1C9k"
#define DATABASE_URL "safeallergy-19bb7-default-rtdb.firebaseio.com"

// Hardware Pins
#define GSR_PIN 2  // GPIO2 para sensor GSR

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

// WiFi
String wifiSSID = "INFINITUM0279";
String wifiPassword = "6Bi42kmmEB";

// Device ID
String deviceId = "ESP32_SAFEALLERGY_" + String((uint32_t)ESP.getEfuseMac(), HEX);

// Timing
unsigned long lastSensorTime = 0;
unsigned long lastSendTime = 0;
unsigned long lastHistoryTime = 0;

const unsigned long SENSOR_INTERVAL = 1000;     // 1 segundo
const unsigned long SEND_INTERVAL = 2000;       // 2 segundos
const unsigned long HISTORY_INTERVAL = 10000;   // 10 segundos

// Heart Rate Detection
byte rateSpot = 0;
byte beatAvg[4];

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n\n========== INICIANDO SAFEALLERGY MONITOR ==========");

  // Initialize Preferences
  preferences.begin("safeallergy", false);
  loadWiFiPreferences();

  // Inicializar I2C
  Wire.begin(12, 15);  // SDA=12, SCL=15
  Serial.println("✓ I2C inicializado");

  // Inicializar OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("❌ Error inicializando OLED");
    while (1);
  }
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("Iniciando Monitor...");
  display.display();
  Serial.println("✓ OLED inicializado");

  // Inicializar MAX30102
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("❌ MAX30102 no encontrado");
    while (1);
  }
  particleSensor.setup();
  particleSensor.setPulseAmplitudeRed(0x0A);
  particleSensor.setPulseAmplitudeGreen(0);
  Serial.println("✓ MAX30102 inicializado");

  // Inicializar MLX90614
  if (!mlx.begin()) {
    Serial.println("❌ MLX90614 no encontrado");
    while (1);
  }
  Serial.println("✓ MLX90614 inicializado");

  // Conectar WiFi
  connectToWiFi();

  // Cargar configuración WiFi desde Firebase
  loadWiFiConfigFromFirebase();

  // Verificar credenciales WiFi
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("✓ Credenciales WiFi verificadas correctamente");
  } else {
    Serial.println("❌ Credenciales WiFi inválidas o red no disponible");
    Serial.println("💡 Verificar:");
    Serial.println("   - SSID correcto");
    Serial.println("   - Contraseña correcta");
    Serial.println("   - Red WiFi al alcance");
  }

  // Inicializar Firebase
  connectFirebase();

  Serial.println("========== MONITOREO LISTO ==========\n");
}

void loop() {
  unsigned long now = millis();

  // Enviar estado del dispositivo periódicamente
  static unsigned long lastStatusSend = 0;
  if (now - lastStatusSend >= 60000) {  // Cada minuto
    lastStatusSend = now;
    sendDeviceStatus();
  }

  // Verificar actualizaciones de firmware
  static unsigned long lastFirmwareCheck = 0;
  if (now - lastFirmwareCheck >= 300000) {  // Cada 5 minutos
    lastFirmwareCheck = now;
    checkForFirmwareUpdates();
  }

  // Verificar comandos remotos desde la app
  static unsigned long lastCommandCheck = 0;
  if (now - lastCommandCheck >= 5000) {  // Cada 5 segundos
    lastCommandCheck = now;
    checkRemoteCommands();
  }

  // Verificar cambios de WiFi cada 30 segundos
  static unsigned long lastWiFiConfigCheck = 0;
  if (now - lastWiFiConfigCheck >= 30000) {  // Cada 30 segundos
    lastWiFiConfigCheck = now;
    checkAndUpdateWiFiConfig();
  }

  // Verificar conexión WiFi periódicamente
  static unsigned long lastWiFiCheck = 0;
  if (now - lastWiFiCheck >= 30000) {  // Cada 30 segundos
    lastWiFiCheck = now;
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("⚠️ Conexión WiFi perdida - reconectando...");
      connectToWiFi();
    }
  }

  // Leer sensores cada SENSOR_INTERVAL
  if (now - lastSensorTime >= SENSOR_INTERVAL) {
    lastSensorTime = now;
    readAllSensors();
    updateDisplay();
  }

  // Enviar datos a Firebase cada SEND_INTERVAL
  if (now - lastSendTime >= SEND_INTERVAL) {
    lastSendTime = now;
    sendSensorDataToFirebase();
  }

  // Guardar en histórico cada HISTORY_INTERVAL
  if (now - lastHistoryTime >= HISTORY_INTERVAL) {
    lastHistoryTime = now;
    saveToHistory();
  }

  delay(10);
}

// ===== FUNCIONES DE SENSORES =====

void readAllSensors() {
  // Leer frecuencia cardíaca y SpO2
  readHeartRateAndSpO2();

  // Leer temperatura
  temperature = mlx.readObjectTempC();

  // Leer GSR
  gsr = analogRead(GSR_PIN);

  // Mostrar en Serial para debugging
  Serial.printf("📊 HR: %.1f bpm | SpO2: %.1f%% | Temp: %.1f°C | GSR: %d\n",
                heartRate, spO2, temperature, gsr);
}

void readHeartRateAndSpO2() {
  // Buffer para almacenar lecturas
  const int numReadings = 50;
  static long irBuffer[numReadings];
  static long redBuffer[numReadings];
  static int bufferIndex = 0;

  // Tomar lecturas del sensor
  if (particleSensor.available()) {
    long irValue = particleSensor.getIR();
    long redValue = particleSensor.getRed();

    // Almacenar en buffer
    irBuffer[bufferIndex] = irValue;
    redBuffer[bufferIndex] = redValue;
    bufferIndex = (bufferIndex + 1) % numReadings;

    particleSensor.nextSample();

    // Calcular promedio de las últimas lecturas
    long irSum = 0;
    long redSum = 0;
    for (int i = 0; i < numReadings; i++) {
      irSum += irBuffer[i];
      redSum += redBuffer[i];
    }

    long avgIR = irSum / numReadings;
    long avgRed = redSum / numReadings;

    // Detectar latidos si hay señal suficiente
    if (avgIR > 50000) {
      // Calcular frecuencia cardíaca (simplificado)
      static unsigned long lastBeatTime = 0;
      static int beatCount = 0;

      if (millis() - lastBeatTime > 600) {  // Evitar detección demasiado frecuente
        beatCount++;
        lastBeatTime = millis();

        // Calcular HR basado en latidos por minuto
        if (beatCount >= 4) {
          heartRate = (beatCount * 60.0) / ((millis() - lastBeatTime + 600) / 1000.0);
          beatCount = 0;
        }
      }
    }

    // Calcular SpO2 (fórmula simplificada basada en ratio R/IR)
    if (avgIR > 0 && avgRed > 0) {
      float ratio = (float)avgRed / (float)avgIR;
      spO2 = 110 - 25 * ratio;  // Aproximación simplificada

      // Limitar valores razonables
      if (spO2 > 100) spO2 = 100;
      if (spO2 < 80) spO2 = 80;
    }
  }
}

// Función para verificar credenciales WiFi específicas
bool verifyWiFiCredentials(String testSSID, String testPassword) {
  Serial.printf("🔍 Verificando credenciales para: %s\n", testSSID.c_str());

  // Desconectar WiFi actual
  WiFi.disconnect(true);
  delay(1000);

  // Intentar conectar con las nuevas credenciales
  WiFi.mode(WIFI_STA);
  WiFi.begin(testSSID.c_str(), testPassword.c_str());

  int attempts = 0;
  const int maxAttempts = 15;  // Menos tiempo para verificación

  while (WiFi.status() != WL_CONNECTED && attempts < maxAttempts) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("✓ Credenciales WiFi válidas!");
    Serial.printf("  📡 Conectado a: %s\n", WiFi.SSID().c_str());
    Serial.printf("  🌐 IP obtenida: %s\n", WiFi.localIP().toString().c_str());
    return true;
  } else {
    Serial.println("❌ Credenciales WiFi inválidas");
    diagnoseWiFiError();
    return false;
  }
}

void connectToWiFi() {
  Serial.print("🔄 Conectando WiFi: ");
  Serial.println(wifiSSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(wifiSSID.c_str(), wifiPassword.c_str());

  int attempts = 0;
  const int maxAttempts = 20;

  while (WiFi.status() != WL_CONNECTED && attempts < maxAttempts) {
    delay(500);
    Serial.print(".");

    // Mostrar progreso cada 5 intentos
    if ((attempts + 1) % 5 == 0) {
      Serial.printf(" (%d/%d)", attempts + 1, maxAttempts);
    }
    attempts++;
  }

  Serial.println(); // Nueva línea después de los puntos

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("✓ WiFi conectado exitosamente!");
    Serial.print("  📡 SSID: ");
    Serial.println(WiFi.SSID());
    Serial.print("  🌐 IP: ");
    Serial.println(WiFi.localIP());
    Serial.print("  📶 Señal: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");

    // Guardar configuración exitosa en memoria
    saveWiFiPreferences();

    // Reportar éxito a Firebase
    reportConnectionStatus("connected", "");

    // Verificar que la conexión sea estable
    delay(1000);
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("✓ Conexión WiFi verificada y estable");
    } else {
      Serial.println("⚠️ Conexión WiFi inestable - reconectando...");
      connectToWiFi(); // Reconectar recursivamente
    }
  } else {
    Serial.println("❌ Falló la conexión WiFi");

    // Diagnosticar el tipo de error
    diagnoseWiFiError();

    // Reportar fallo a Firebase
    reportConnectionStatus("failed", "Credenciales inválidas o red no disponible");

    // Intentar reconectar después de un delay
    Serial.println("🔄 Reintentando conexión en 5 segundos...");
    delay(5000);
    connectToWiFi();
  }
}

void diagnoseWiFiError() {
  wl_status_t status = WiFi.status();

  switch (status) {
    case WL_NO_SHIELD:
      Serial.println("  ❌ No se encontró el shield WiFi");
      break;
    case WL_IDLE_STATUS:
      Serial.println("  ⏳ WiFi está cambiando de estado");
      break;
    case WL_NO_SSID_AVAIL:
      Serial.println("  ❌ Red WiFi no encontrada - verificar SSID");
      break;
    case WL_SCAN_COMPLETED:
      Serial.println("  🔍 Escaneo completado");
      break;
    case WL_CONNECTED:
      Serial.println("  ✓ Conectado (esto no debería pasar aquí)");
      break;
    case WL_CONNECT_FAILED:
      Serial.println("  ❌ Falló la conexión - posible contraseña incorrecta");
      break;
    case WL_CONNECTION_LOST:
      Serial.println("  ❌ Conexión perdida");
      break;
    case WL_DISCONNECTED:
      Serial.println("  ❌ Desconectado");
      break;
    default:
      Serial.printf("  ❓ Error WiFi desconocido: %d\n", status);
      break;
  }

  // Información adicional de diagnóstico
  Serial.print("  📡 Redes disponibles: ");
  int numNetworks = WiFi.scanNetworks();
  Serial.println(numNetworks);

  if (numNetworks > 0) {
    Serial.println("  📋 Redes encontradas:");
    for (int i = 0; i < min(numNetworks, 5); i++) {  // Mostrar máximo 5 redes
      Serial.printf("    %d. %s (%d dBm)\n", i + 1, WiFi.SSID(i).c_str(), WiFi.RSSI(i));
    }
  }
}

void connectFirebase() {
  Serial.println("🔄 Conectando Firebase...");

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  config.signer.test_mode = true;

  Firebase.begin(&config, &auth);
  Firebase.reconnectNetwork(true);

  // Esperar hasta 10 segundos para la conexión
  int attempts = 0;
  const int maxAttempts = 20;

  while (!Firebase.ready() && attempts < maxAttempts) {
    delay(500);
    Serial.print("🔄");
    attempts++;
  }

  Serial.println(); // Nueva línea

  if (Firebase.ready()) {
    Serial.println("✓ Firebase conectado exitosamente!");
    Serial.print("  📊 URL: ");
    Serial.println(DATABASE_URL);
    Serial.println("✓ Base de datos lista para recibir datos");
  } else {
    Serial.println("❌ Error conectando Firebase");

    // Diagnosticar problemas de conexión
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("  ❌ WiFi no conectado - Firebase necesita WiFi");
    } else {
      Serial.println("  ❌ Problema con credenciales o configuración Firebase");
      Serial.println("  💡 Verificar:");
      Serial.println("     - API Key correcta");
      Serial.println("     - Database URL correcta");
      Serial.println("     - Proyecto Firebase activo");
    }

    // Reintentar conexión después de delay
    Serial.println("🔄 Reintentando conexión Firebase en 3 segundos...");
    delay(3000);
    connectFirebase();
  }
}

void sendSensorDataToFirebase() {
  // Verificar conexión WiFi primero
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️ WiFi desconectado - omitiendo envío");
    return;
  }

  // Verificar conexión Firebase
  if (!Firebase.ready()) {
    Serial.println("⚠️ Firebase no listo - reconectando...");
    connectFirebase();
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
  json.set("wifi_signal", WiFi.RSSI());

  if (Firebase.RTDB.setJSON(&fbdo, "/sensores/datos_actuales", &json)) {
    Serial.println("✓ Datos enviados a Firebase");
  } else {
    Serial.printf("❌ Error enviando datos: %s\n", fbdo.errorReason().c_str());

    // Intentar reconectar Firebase si hay error de conexión
    if (fbdo.errorReason().indexOf("connection") >= 0 ||
        fbdo.errorReason().indexOf("timeout") >= 0) {
      Serial.println("🔄 Reconectando Firebase...");
      connectFirebase();
    }
  }
}

void saveToHistory() {
  // Verificar conexiones antes de guardar
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️ WiFi desconectado - omitiendo histórico");
    return;
  }

  if (!Firebase.ready()) {
    Serial.println("⚠️ Firebase no listo para histórico");
    return;
  }

  FirebaseJson json;
  json.set("hr", (int)heartRate);
  json.set("spo2", (int)spO2);
  json.set("temperatura", (float)temperature);
  json.set("gsr", gsr);
  json.set("timestamp", (long)millis());

  String path = "/sensores/historico/" + String(millis());

  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json)) {
    Serial.println("📁 Histórico guardado");
  } else {
    Serial.printf("❌ Error guardando histórico: %s\n", fbdo.errorReason().c_str());
  }
}

void reportConnectionStatus(String status, String error) {
  if (Firebase.ready()) {
    FirebaseJson json;
    json.set("status", status);
    json.set("error", error);
    json.set("ssid", wifiSSID);
    json.set("timestamp", getISOTimestamp());
    json.set("device_id", deviceId);

    Firebase.RTDB.setJSON(&fbdo, "/wifi_config/connection_status", &json);
    Serial.print("📡 Estado reportado a Firebase: ");
    Serial.println(status);
  }
}

String getISOTimestamp() {
  // Retorna timestamp aproximado (sin RTC, usamos millis)
  unsigned long ms = millis();
  return String(ms);
}

void loadWiFiPreferences() {
  wifiSSID = preferences.getString("wifi_ssid", wifiSSID);
  wifiPassword = preferences.getString("wifi_password", wifiPassword);
  Serial.println("✓ Configuración WiFi cargada desde memoria");
}

void saveWiFiPreferences() {
  preferences.putString("wifi_ssid", wifiSSID);
  preferences.putString("wifi_password", wifiPassword);
  Serial.println("💾 Configuración WiFi guardada en memoria");
}

void checkForFirmwareUpdates() {
  if (!Firebase.ready()) return;

  Serial.println("🔄 Verificando actualizaciones de firmware...");

  if (Firebase.RTDB.getJSON(&fbdo, "/firmware_updates")) {
    FirebaseJson &json = fbdo.to<FirebaseJson>();
    FirebaseJsonData jsonData;

    if (json.get(jsonData, "latest_version")) {
      String latestVersion = jsonData.stringValue;
      String currentVersion = "1.0.0";

      if (latestVersion != currentVersion) {
        Serial.printf("📦 Nueva versión disponible: %s\n", latestVersion.c_str());

        // Aquí se podría implementar OTA update
        // Por ahora solo notificamos
        Serial.println("⚠️ Actualización OTA no implementada aún");
      } else {
        Serial.println("✓ Firmware está actualizado");
      }
    }
  }
}

void sendDeviceStatus() {
  if (!Firebase.ready()) return;

  FirebaseJson json;
  json.set("device_id", deviceId);
  json.set("timestamp", (long)millis());
  json.set("uptime", millis() / 1000); // uptime in seconds
  json.set("wifi_connected", WiFi.status() == WL_CONNECTED);
  json.set("firebase_connected", Firebase.ready());
  json.set("wifi_signal", WiFi.RSSI());
  json.set("free_heap", ESP.getFreeHeap());
  json.set("firmware_version", "1.0.0");
  json.set("last_sensor_reading", lastSensorTime);

  Firebase.RTDB.setJSON(&fbdo, "/device_status/" + deviceId, &json);
  Serial.println("📊 Estado del dispositivo enviado a Firebase");
}

void checkRemoteCommands() {
  if (!Firebase.ready()) return;

  // Verificar si hay comandos pendientes
  if (Firebase.RTDB.getJSON(&fbdo, "/device_commands/" + deviceId)) {
    FirebaseJson &json = fbdo.to<FirebaseJson>();
    FirebaseJsonData jsonData;

    if (json.get(jsonData, "command")) {
      String command = jsonData.stringValue;

      if (command == "restart") {
        Serial.println("🔄 Comando remoto: Reiniciando dispositivo...");
        // Limpiar el comando
        Firebase.RTDB.setString(&fbdo, "/device_commands/" + deviceId + "/command", "");
        delay(1000);
        ESP.restart();
      } else if (command == "reconnect_wifi") {
        Serial.println("🔄 Comando remoto: Reconectando WiFi...");
        Firebase.RTDB.setString(&fbdo, "/device_commands/" + deviceId + "/command", "");
        connectToWiFi();
      } else if (command == "reset_wifi") {
        Serial.println("🔄 Comando remoto: Reseteando configuración WiFi...");
        wifiSSID = "INFINITUM0279";  // Valores por defecto
        wifiPassword = "6Bi42kmmEB";
        saveWiFiPreferences();
        Firebase.RTDB.setString(&fbdo, "/device_commands/" + deviceId + "/command", "");
        connectToWiFi();
      }
    }
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
  } else {
    Serial.println("⚠️ Firebase no listo - usando configuración WiFi por defecto");
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
      Serial.println("\n🔄 ¡WiFi cambió desde la app! Reconectando...");
      Serial.print("  Anterior: ");
      Serial.println(wifiSSID);
      Serial.print("  Nuevo: ");
      Serial.println(newSSID);

      wifiSSID = newSSID;
      wifiPassword = newPassword;

      // Guardar nuevas credenciales
      saveWiFiPreferences();

      connectToWiFi();

      Serial.println("✓ Reconexión completada\n");
    }
  }
}

// ===== FUNCIONES DE DISPLAY =====

void updateDisplay() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  // Título
  display.setCursor(0, 0);
  display.println("SafeAllergy Monitor");
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);

  // Datos de sensores
  display.setCursor(0, 14);
  display.printf("HR: %.0f bpm\n", heartRate);

  display.setCursor(0, 22);
  display.printf("SpO2: %.0f%%\n", spO2);

  display.setCursor(0, 30);
  display.printf("Temp: %.1f C\n", temperature);

  display.setCursor(0, 38);
  display.printf("GSR: %d\n", gsr);

  // Estado de conexiones
  display.setCursor(0, 48);
  String wifiStatus = WiFi.status() == WL_CONNECTED ? "ON" : "OFF";
  display.printf("WiFi: %s\n", wifiStatus.c_str());

  display.setCursor(70, 48);
  String fbStatus = Firebase.ready() ? "SYNC" : "ERR";
  display.printf("FB: %s\n", fbStatus.c_str());

  // Información adicional
  display.setCursor(0, 56);
  if (WiFi.status() == WL_CONNECTED) {
    display.printf("Sig:%d T:%lu\n", WiFi.RSSI(), millis() / 1000);
  } else {
    display.printf("T:%lu\n", millis() / 1000);
  }

  display.display();
}