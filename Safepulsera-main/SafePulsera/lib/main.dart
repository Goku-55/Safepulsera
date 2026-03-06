import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'dart:developer' as developer;

// --- IMPORTACIONES DE SERVICIOS ---
import 'notification_service.dart';
import 'background_tasks.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

// --- IMPORTACIÓN DE PROVIDERS ---
import 'providers/sensor_data_provider.dart';
import 'services/wifi_provider.dart';

// --- IMPORTACIÓN DE PANTALLAS ---
import 'screens/navegacion_base.dart'; 
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/clinical_history.dart'; 
import 'screens/emergency_contacts_screen.dart'; 
import 'screens/settings_screen.dart';
import 'screens/wifi_settings_screen.dart';

void main() async {
  // 1. Asegurar que los bindings de Flutter estén listos
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. Inicializar Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 3. Inicializar Zonas Horarias
    tz.initializeTimeZones();

    // 4. Inicializar Notificaciones
    await NotificationService.init();
    
    // 5. NUEVO: Inicializar WorkManager para tareas en background
    await initializeBackgroundTasks();

    runApp(const MyApp());
  } catch (e, stackTrace) {
    developer.log("Error en arranque", error: e, stackTrace: stackTrace);
    
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text("Error crítico al iniciar: $e")),
      ),
    ));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  
  @override
  void initState() {
    super.initState();
    // 5. PEDIR PERMISOS DESPUÉS del primer frame para estabilidad
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestAppPermissions();
    });
  }

  Future<void> _requestAppPermissions() async {
    // Pedir permisos secuencialmente
    await [
      Permission.notification,
      Permission.location,
      Permission.scheduleExactAlarm,
    ].request();
    
    await Permission.ignoreBatteryOptimizations.request();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SensorDataProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => WiFiProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'SafeAllergy Band',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          primaryColor: const Color(0xFF00F5D4),
          scaffoldBackgroundColor: const Color(0xFF0A0E17),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00F5D4),
            surface: Color(0xFF1A1F29),
          ),
        ),
        // NUEVO: Detectar si hay usuario logueado
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            debugPrint('🔐 Auth State: connection=${snapshot.connectionState}, hasData=${snapshot.hasData}, user=${snapshot.data?.email}');
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            // Si hay usuario logueado → ir a home
            if (snapshot.hasData && snapshot.data != null) {
              debugPrint('✅ Usuario detectado: ${snapshot.data!.email}');
              return const NavegacionBase();
            }
            
            // Si NO hay usuario → ir a login
            debugPrint('❌ No hay usuario, mostrando login');
            return const LoginScreen();
          },
        ),
        routes: {
          '/login': (context) => const LoginScreen(), 
          '/register': (context) => const RegisterScreen(), 
          '/main': (context) => const NavegacionBase(), 
          '/home': (context) => const NavegacionBase(), 
          '/clinical': (context) => const ClinicalHistoryScreen(), 
          '/contacts': (context) => const EmergencyContactsScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/wifi': (context) => const WiFiSettingsScreen(),
        },
      ),
    );
  }
}