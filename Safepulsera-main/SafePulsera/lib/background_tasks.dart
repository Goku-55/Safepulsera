import 'package:workmanager/workmanager.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';

// NUEVO: Tareas en background para notificaciones inteligentes
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('WorkManager ejecutando tarea: $task');
      
      if (task == 'medicamento_recordatorio') {
        // Detectar modo del dispositivo JUSTO ANTES de enviar
        bool esSilencio = await _isPhoneInSilentMode();
        
        final title = inputData?['title'] ?? 'Recordatorio Médico';
        final body = inputData?['body'] ?? 'Es hora de tu medicamento';
        final id = inputData?['id'] ?? 101;
        
        debugPrint('Detectado: ${esSilencio ? "SILENCIO/VIBRACION" : "MODO NORMAL"}');
        
        // Enviar notificación con modo detectado
        await NotificationService.sendSmartNotification(
          id: id,
          title: title,
          body: body,
          isSilent: esSilencio,
        );
        
        return true;
      }
      
      return true;
    } catch (e) {
      debugPrint('Error en WorkManager: $e');
      return false;
    }
  });
}

// Detectar modo del dispositivo desde background
Future<bool> _isPhoneInSilentMode() async {
  try {
    const platform = MethodChannel('com.safeallergy/audio');
    final result = await platform.invokeMethod<bool>('isInSilentMode');
    return result ?? false;
  } catch (e) {
    debugPrint('Error detectando modo: $e');
    return false;
  }
}

// NUEVO: Inicializar WorkManager
Future<void> initializeBackgroundTasks() async {
  try {
    await Workmanager().initialize(
      callbackDispatcher,
    );
    debugPrint('WorkManager inicializado');
  } catch (e) {
    debugPrint('Error inicializando WorkManager: $e');
  }
}

// NUEVO: Programar tarea con WorkManager
Future<void> scheduleSmartNotification({
  required int id,
  required String title,
  required String body,
  required int hora,
  required int minuto,
}) async {
  try {
    // Calcular delay hasta la hora programada
    final ahora = DateTime.now();
    var scheduledTime = DateTime(ahora.year, ahora.month, ahora.day, hora, minuto);
    
    if (scheduledTime.isBefore(ahora)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    
    final delayDuration = scheduledTime.difference(ahora);
    
    debugPrint('Programando notificacion para: ${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}');
    debugPrint('   Tiempo desde ahora: ${delayDuration.inMinutes} minutos');
    
    // Programar con WorkManager (repetir diariamente)
    await Workmanager().registerPeriodicTask(
      'medicamento_$id',
      'medicamento_recordatorio',
      frequency: const Duration(days: 1),
      initialDelay: delayDuration,
      inputData: {
        'id': id,
        'title': title,
        'body': body,
      },
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresDeviceIdle: false,
        requiresCharging: false,
        requiresBatteryNotLow: false,
      ),
    );
    
    debugPrint('Notificacion programada con WorkManager');
  } catch (e) {
    debugPrint('Error programando notificacion: $e');
  }
}

// Cancelar tarea
Future<void> cancelSmartNotification(int id) async {
  try {
    await Workmanager().cancelByTag('medicamento_$id');
    debugPrint('Notificacion $id cancelada');
  } catch (e) {
    debugPrint('Error cancelando notificacion: $e');
  }
}
