// ===== CÓDIGO PARA ESP32 O ARDUINO CON SENSOR GSR =====
// Compatible con Flutter via USB Serial
// Formato de envío: GSR:valor\n

const int gsrPin = 2;  // Pin IO2 del ESP32 (configurable)
const int baudRate = 115200;  // ESP32 recomendado

// Variables para suavizado de datos
const int numSamples = 10;
int readings[numSamples];
int readIndex = 0;
int total = 0;
int promedio = 0;

void setup() {
  Serial.begin(baudRate);
  delay(1000); // Esperar a que se inicialice
  
  // Mensaje inicial
  Serial.println("=== Monitor GSR Iniciado ===");
  Serial.println("Formato: GSR:valor");
  Serial.println("================");
  delay(2000);
  
  // Inicializar array
  for (int i = 0; i < numSamples; i++) {
    readings[i] = 0;
  }
}

void loop() {
  // Leer valor del sensor GSR
  int valor = analogRead(gsrPin);
  
  // Algoritmo de suavizado (promedio móvil)
  total -= readings[readIndex];
  readings[readIndex] = valor;
  total += readings[readIndex];
  readIndex = (readIndex + 1) % numSamples;
  promedio = total / numSamples;
  
  // Enviar en formato compatible con Flutter
  // Formato: GSR:valor (sin espacios)
  Serial.print("GSR:");
  Serial.println(promedio);
  
  // También enviar datos detallados para depuración
  Serial.print("Valor_Crudo:");
  Serial.println(valor);
  Serial.print("Promedio:");
  Serial.println(promedio);
  Serial.println("---");
  
  // Pequeña pausa
  delay(500); // Cambiar según necesidad (200-1000ms)
}

// ===== NOTAS =====
// 1. ESP32: Usa Serial.begin(115200) - recomendado para ESP32
// 2. Arduino UNO: Usa Serial.begin(9600)
// 3. Para ver en Visual Studio Code:
//    - Instala "Serial Monitor" extension
//    - Abre paleta de comandos (Ctrl+Shift+P)
//    - Busca "Serial Monitor: Open"
//    - Selecciona puerto y velocidad (115200 para ESP32)
// 4. Para Flutter: Leerá la línea "GSR:valor" automáticamente
// 5. Verifica el pin IO2 si usas otra placa
