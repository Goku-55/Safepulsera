import 'package:flutter/material.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';

class USBSerialService {
  static UsbPort? _port;
  static UsbDevice? _device;
  
  // Stream para emitir datos del sensor
  static final List<Function(String)> _listeners = [];

  // Conectar a dispositivo USB (Arduino/ESP32)
  static Future<bool> connect() async {
    try {
      debugPrint('🔌 Buscando dispositivos USB...');
      
      List<UsbDevice> devices = await UsbSerial.listDevices();
      
      if (devices.isEmpty) {
        debugPrint('❌ No hay dispositivos USB conectados');
        return false;
      }
      
      _device = devices.first;
      debugPrint('✅ Dispositivo encontrado: ${_device?.productName}');
      
      // Abrir puerto
      _port = await _device!.create();
      if (_port == null) {
        debugPrint('❌ No se pudo crear el puerto');
        return false;
      }
      
      // Configurar puerto serial
      await _port!.setDTR(true);
      await _port!.setRTS(true);
      
      // Para ESP32: 115200, Para Arduino: 9600
      await _port!.setPortParameters(
        115200,           // Baud rate (cambiar a 9600 para Arduino UNO)
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );
      
      debugPrint('✅ Puerto configurado correctamente');
      
      // Escuchar datos
      _port!.inputStream!.listen(_onDataReceived);
      
      return true;
    } catch (e) {
      debugPrint('❌ Error conectando USB: $e');
      return false;
    }
  }

  // Callback cuando se reciben datos
  static void _onDataReceived(Uint8List data) {
    try {
      String message = String.fromCharCodes(data).trim();
      
      debugPrint('📨 Dato recibido: $message');
      
      // Notificar a todos los listeners
      for (var listener in _listeners) {
        listener(message);
      }
    } catch (e) {
      debugPrint('❌ Error procesando datos: $e');
    }
  }

  // Agregar listener para recibir datos
  static void addListener(Function(String) listener) {
    _listeners.add(listener);
  }

  // Remover listener
  static void removeListener(Function(String) listener) {
    _listeners.remove(listener);
  }

  // Enviar comando al Arduino (si es necesario)
  static Future<void> sendData(String data) async {
    if (_port == null) {
      debugPrint('❌ Puerto no conectado');
      return;
    }
    
    try {
      _port!.write(Uint8List.fromList(data.codeUnits));
      debugPrint('✅ Datos enviados: $data');
    } catch (e) {
      debugPrint('❌ Error enviando datos: $e');
    }
  }

  // Desconectar
  static Future<void> disconnect() async {
    try {
      await _port?.close();
      _port = null;
      _device = null;
      debugPrint('✅ Desconectado');
    } catch (e) {
      debugPrint('❌ Error desconectando: $e');
    }
  }

  // Verificar si está conectado
  static bool isConnected() {
    return _port != null;
  }
}
