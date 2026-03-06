import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static const platform = MethodChannel('com.safeallergy/audio');

  // NUEVO: Detectar estado de sonido del dispositivo
  static Future<bool> _isPhoneInSilentMode() async {
    try {
      final result = await platform.invokeMethod<bool>('isInSilentMode');
      return result ?? false;
    } catch (e) {
      debugPrint('Error detectando modo silencio: $e');
      return false;
    }
  }

  static Future<void> init() async {
    try {
      tz.initializeTimeZones();
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      await requestAllPermissions();
    } catch (e) {
      debugPrint('ERROR EN INICIALIZACIÓN: $e');
    }
  }

  @pragma('vm:entry-point')
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('\nNOTIFICACIÓN PRESIONADA: ${response.payload}');
  }

  static Future<bool> requestAllPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    return await Permission.notification.isGranted;
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      // NUEVO: Detectar si está en silencio o vibración
      bool esSilencio = await _isPhoneInSilentMode();
      
      final NotificationDetails details = NotificationDetails(
        android: AndroidNotificationDetails(
          'high_priority_alerts',
          'Alertas Criticas',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          sound: esSilencio ? null : RawResourceAndroidNotificationSound('notification_sound'),
          audioAttributesUsage: esSilencio ? AudioAttributesUsage.notification : AudioAttributesUsage.alarm,
          fullScreenIntent: !esSilencio,
        ),
        iOS: const DarwinNotificationDetails(),
      );

      await _notificationsPlugin.show(id, title, body, details, payload: payload);
      
      if (esSilencio) {
        debugPrint('Notificación enviada en MODO SILENCIO (solo vibración)');
      } else {
        debugPrint('Notificación enviada con SONIDO + VIBRACIÓN');
      }
    } catch (e) {
      debugPrint('Error al mostrar notificacion: $e');
    }
  }

  // NUEVO: Cancelar notificación programada para evitar duplicados
  static Future<void> cancelarAlerta(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      debugPrint('Notificacion $id cancelada correctamente');
    } catch (e) {
      debugPrint('Error al cancelar notificacion $id: $e');
    }
  }

  static Future<bool> programarAlertaDiaria({
    required int id,
    required String title,
    required String body,
    required int hora,
    required int minuto,
  }) async {
    try {
      // NUEVO: Detectar si está en silencio
      bool esSilencio = await _isPhoneInSilentMode();
      
      await cancelarAlerta(id);

      debugPrint('🔔 INICIANDO PROGRAMACIÓN DE ALARMA');
      debugPrint('   ID: $id, Título: $title');
      
      // CRÍTICO: Obtener la zona horaria de Nuevo Laredo
      final chicagoTz = tz.getLocation('America/Chicago');
      
      // Obtener la hora ACTUAL en la zona de Chicago
      final ahoraChicago = tz.TZDateTime.now(chicagoTz);
      var scheduledDateChicago = tz.TZDateTime(chicagoTz, ahoraChicago.year, ahoraChicago.month, ahoraChicago.day, hora, minuto);

      // Si la hora ya pasó hoy, programar para mañana
      if (scheduledDateChicago.isBefore(ahoraChicago)) {
        scheduledDateChicago = scheduledDateChicago.add(const Duration(days: 1));
      }

      debugPrint('   Zona Horaria: America/Chicago (Nuevo Laredo)');
      debugPrint('   Hora programada: $hora:${minuto.toString().padLeft(2, '0')}');
      debugPrint('   Próxima ejecución: ${scheduledDateChicago.hour}:${scheduledDateChicago.minute.toString().padLeft(2, '0')} el ${scheduledDateChicago.day}/${scheduledDateChicago.month}/${scheduledDateChicago.year}');
      debugPrint('   Ahora es: ${ahoraChicago.hour}:${ahoraChicago.minute} del ${ahoraChicago.day}/${ahoraChicago.month}/${ahoraChicago.year}');

      // Usar zonedSchedule() con exactAllowWhileIdle para máxima confiabilidad
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDateChicago,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'med_daily_reminders',
            'Recordatorios Diarios',
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
            sound: esSilencio ? null : RawResourceAndroidNotificationSound('notification_sound'),
            audioAttributesUsage: esSilencio ? AudioAttributesUsage.notification : AudioAttributesUsage.alarm,
            fullScreenIntent: !esSilencio,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Repite DIARIAMENTE a esa hora
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      debugPrint('✅ Alerta programada correctamente');
      debugPrint('   Tipo: dailyAtTime ($hora:${minuto.toString().padLeft(2, '0')})');
      debugPrint('   Próxima: ${scheduledDateChicago.hour}:${scheduledDateChicago.minute.toString().padLeft(2, '0')}');
      if (esSilencio) {
        debugPrint('   ⚠️ Modo silencio: solo VIBRACIÓN');
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error al programar alerta diaria: $e');
      return false;
    }
  }

  // NUEVO: Enviar notificación inteligente (detecta modo en el momento)
  static Future<void> sendSmartNotification({
    required int id,
    required String title,
    required String body,
    bool isSilent = false,
  }) async {
    try {
      final NotificationDetails details = NotificationDetails(
        android: AndroidNotificationDetails(
          'med_daily_reminders',
          'Recordatorios Diarios',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
          sound: isSilent ? null : RawResourceAndroidNotificationSound('notification_sound'),
          audioAttributesUsage: isSilent ? AudioAttributesUsage.notification : AudioAttributesUsage.alarm,
          fullScreenIntent: !isSilent,
        ),
        iOS: const DarwinNotificationDetails(),
      );

      await _notificationsPlugin.show(id, title, body, details);
      
      if (isSilent) {
        debugPrint('Notificación enviada en MODO SILENCIO (solo vibración)');
      } else {
        debugPrint('Notificación enviada con SONIDO + VIBRACIÓN');
      }
    } catch (e) {
      debugPrint('Error al enviar notificacion inteligente: $e');
    }
  }
}