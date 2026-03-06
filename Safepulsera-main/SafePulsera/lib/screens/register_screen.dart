import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../notification_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- CONTROLADORES ---
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _edad = TextEditingController();
  final _peso = TextEditingController();
  final _altura = TextEditingController();
  final _contactoNombre = TextEditingController();
  final _contactoTel = TextEditingController();
  final _medNombreRecordatorio = TextEditingController();
  final _vacunaEspecificaController = TextEditingController();
  final _otroDeporteController = TextEditingController();

  // --- ESTADOS ---
  String? _tipoSangre;
  String? _nivelActividad;
  bool _quiereRecordatorio = false;
  bool _mostrarOtroDeporte = false;
  bool _contactoFavorito = false;
  final bool _especificarOtroDeporte = false;
  final Map<String, bool> _mostrarOtroAlergia = {'Ambiental': false, 'Medicamentos': false, 'Alimentos': false};
  TimeOfDay _horaAlarma = const TimeOfDay(hour: 8, minute: 0);

  final List<String> _deportesSeleccionados = [];

  final Map<String, List<String>> _alergiasComunes = {
    'Ambiental': ['Ninguno', 'Ácaros del Polvo', 'Polen de Olivo', 'Humedad / Moho', 'Pelo de Gato', 'Pelo de Perro', 'Látex', 'Polen de Abedul', 'Cucarachas', 'Humo de Tabaco', 'Pasto / Césped', 'Picadura de Abeja', 'Picadura de Hormiga', 'Polvo de Madera', 'Cloro / Químicos', 'Lana', 'Níquel', 'Algodón'],
    'Medicamentos': ['Ninguno', 'Penicilina', 'Aspirina (AAS)', 'Ibuprofeno', 'Sulfamidas', 'Insulina', 'Naproxeno', 'Amoxicilina', 'Anestesia local', 'Yodo (Contraste)', 'Morfina', 'Codeína', 'Anticonvulsivos', 'Quimioterapia', 'Vacunas (especificar)', 'Paracetamol', 'Ketorolaco', 'Metamizol'],
    'Alimentos': ['Ninguno', 'Maní / Cacahuetes', 'Mariscos', 'Pescados', 'Leche de Vaca', 'Huevo', 'Gluten', 'Nueces', 'Soya', 'Fresas', 'Chocolate', 'Cítricos', 'Tomate', 'Colorantes (Rojo 40)', 'Piña', 'Kiwi', 'Canela', 'Lentejas'],
  };

  final Map<String, List<String>> _seleccionados = {};
  final Map<String, List<String>> _otrasAlergiasList = {
    'Ambiental': [],
    'Medicamentos': [],
    'Alimentos': [],
  };
  final Map<String, bool> _condicionesCronicas = {
    'Asma': false, 'Diabetes': false, 'Hipertensión': false, 'Epilepsia': false,
  };

  @override
  void initState() {
    super.initState();
    for (var cat in _alergiasComunes.keys) {
      _seleccionados[cat] = [];
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _edad.dispose();
    _peso.dispose();
    _altura.dispose();
    _contactoNombre.dispose();
    _contactoTel.dispose();
    _medNombreRecordatorio.dispose();
    _vacunaEspecificaController.dispose();
    _otroDeporteController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // CORRECCIÓN: Eliminado el Dead Code y el warning unnecessary_nullable
  void _probarNotificacion() async {
    try {
      final bool hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        Vibration.vibrate(duration: 500);
      }
      // Asegúrate que la ruta en pubspec.yaml sea exactamente assets/audiodenotificaciones/
      await _audioPlayer.play(AssetSource('audiodenotificaciones/notificacion1.mp3'));
    } catch (e) {
      debugPrint("Error multimedia: $e");
    }
  }

  void _manejarSeleccionOpcion(String categoria, String opcion) {
    setState(() {
      final isSelected = _seleccionados[categoria]!.contains(opcion);
      
      if (opcion == 'Ninguno') {
        if (!isSelected) {
          _seleccionados[categoria]!.clear();
          _seleccionados[categoria]!.add('Ninguno');
        } else {
          _seleccionados[categoria]!.remove('Ninguno');
        }
      } else {
        if (!isSelected) {
          _seleccionados[categoria]!.remove('Ninguno');
          _seleccionados[categoria]!.add(opcion);
        } else {
          _seleccionados[categoria]!.remove(opcion);
        }
      }
    });
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final String uid = userCredential.user!.uid;
      String horaStr = '${_horaAlarma.hour.toString().padLeft(2, '0')}:${_horaAlarma.minute.toString().padLeft(2, '0')}';

      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'perfil': {
          'email': _emailController.text.trim(),
          'edad': _edad.text,
          'peso': _peso.text,
          'altura': _altura.text,
          'nivel_actividad': _nivelActividad,
          'deportes': _deportesSeleccionados,
          'otro_deporte': _especificarOtroDeporte ? _otroDeporteController.text : null,
        },
        'clinico': {
          'sangre': _tipoSangre,
          'condiciones': _condicionesCronicas,
          'emergencia': {'contacto_nombre': _contactoNombre.text, 'contacto_tel': _contactoTel.text},
        },
        'alergias': {
          'seleccionadas': _seleccionados,
          'detalle_vacuna': _vacunaEspecificaController.text,
          'otros': _otrasAlergiasList,
        },
        'notificaciones': _quiereRecordatorio ? {
          'medicamento': _medNombreRecordatorio.text,
          'hora': horaStr,
        } : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_quiereRecordatorio && _medNombreRecordatorio.text.isNotEmpty) {
        debugPrint('🔔 INTENTANDO PROGRAMAR NOTIFICACIÓN');
        debugPrint('   Medicamento: ${_medNombreRecordatorio.text}');
        debugPrint('   Hora: ${_horaAlarma.hour}:${_horaAlarma.minute.toString().padLeft(2, '0')}');
        // Programar recordatorio diario simple
        bool resultado = await NotificationService.programarAlertaDiaria(
          id: 101,
          title: "Recordatorio Médico",
          body: "Es hora de tomar: ${_medNombreRecordatorio.text}",
          hora: _horaAlarma.hour,
          minuto: _horaAlarma.minute,
        );
        debugPrint(resultado ? '✅ Notificación programada exitosamente' : '❌ Error al programar notificación');
      } else {
        debugPrint('⚠️ No se programó notificación. Recordatorio: $_quiereRecordatorio, Medicamento: ${_medNombreRecordatorio.text}');
      }
      // Guardar contacto SOS en colección emergencia global
      if (_contactoNombre.text.isNotEmpty && _contactoTel.text.isNotEmpty) {
        await FirebaseFirestore.instance.collection('emergency_contacts').doc(uid).set({
          'uid': uid,
          'nombre': _contactoNombre.text.trim(),
          'telefono': _contactoTel.text.trim(),
          'email_usuario': _emailController.text.trim(),
          'isFavorito': _contactoFavorito,
          'activo': true,
          'fecha_registro': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text("EXPEDIENTE SEGURO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          children: [
            _header("1. DATOS PERSONALES"),
            _buildField(_emailController, "Email", Icons.email, type: TextInputType.emailAddress, hint: "tu@email.com"),
            _buildField(_passwordController, "Contraseña", Icons.lock, obscure: true, hint: "Mín. 6 caracteres"),
            Row(children: [
              Expanded(child: _buildField(_edad, "Edad", Icons.cake, type: TextInputType.number, hint: "Ej: 25")),
              const SizedBox(width: 10),
              Expanded(child: _buildField(_peso, "Peso (kg)", Icons.monitor_weight, type: TextInputType.number, hint: "Ej: 70")),
              const SizedBox(width: 10),
              Expanded(child: _buildField(_altura, "Altura (cm)", Icons.height, type: TextInputType.number, hint: "Ej: 180")),
            ]),
            _header("2. INFORMACIÓN CLÍNICA"),
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF1D1E33),
              style: const TextStyle(color: Colors.white),
              decoration: _inputStyle("Grupo Sanguíneo", Icons.bloodtype),
              items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _tipoSangre = v),
            ),
            const SizedBox(height: 15),
            _buildChipsCondiciones(),
            _header("3. ACTIVIDAD FÍSICA"),
            DropdownButtonFormField<String?>(
              dropdownColor: const Color(0xFF0A0E21),
              style: const TextStyle(color: Colors.white),
              initialValue: _nivelActividad,
              decoration: _inputStyle("Nivel de Actividad Física", Icons.fitness_center, hint: "Selecciona"),
              items: [
                const DropdownMenuItem(value: null, child: Text("Selecciona", style: TextStyle(color: Colors.white54))),
                ...['Sedentario', 'Moderado', 'Atleta'].map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() => _nivelActividad = v),
            ),
            if (_nivelActividad == 'Atleta') 
              Padding(
                padding: const EdgeInsets.only(top: 15, bottom: 15),
                child: _buildDeportesSelection(),
              ),
            _header("4. ALERGIAS REGISTRADAS"),
            ..._alergiasComunes.keys.map((cat) => _buildExpandableAlergias(cat)),
            _header("5. CONTACTO Y ALERTAS"),
            _buildField(_contactoNombre, "Contacto SOS", Icons.person_pin, hint: "Nombre del contacto"),
            _buildField(_contactoTel, "Teléfono SOS", Icons.phone, type: TextInputType.phone, hint: "8674410213"),
            CheckboxListTile(
              title: const Text("Marcar como favorito", style: TextStyle(color: Colors.white, fontSize: 13)),
              value: _contactoFavorito,
              onChanged: (value) {
                setState(() {
                  _contactoFavorito = value ?? false;
                });
              },
              activeColor: const Color(0xFF00F5D4),
              checkColor: Colors.black,
              contentPadding: EdgeInsets.zero,
            ),
            _buildAlertaSwitch(),
            if (_quiereRecordatorio) ...[
              const SizedBox(height: 15),
              _buildField(_medNombreRecordatorio, "Medicina", Icons.medication, hint: "Nombre del medicamento"),
              _buildTimePickerTile(),
              const SizedBox(height: 10),
              _buildProbarAlertaBtn(),
            ],
            // --- SECCIÓN 6: VACUNAS ---
            if (_seleccionados['Medicamentos']!.contains('Vacunas (especificar)')) ...[
              const SizedBox(height: 25),
              _header("6. VACUNAS"),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.cyanAccent, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.vaccines, color: Colors.cyanAccent, size: 20),
                        SizedBox(width: 10),
                        Text('Especifique la vacuna', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.only(left: 30),
                      child: Text(
                        '(Esta sección aparece porque seleccionaste "Vacunas (especificar)" en Medicamentos)',
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _vacunaEspecificaController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputStyle("Nombre de la vacuna", Icons.vaccines, hint: "Ej: Pfizer COVID-19, AstraZeneca"),
                      validator: (v) => v == null || v.isEmpty ? "Especifique la vacuna" : null,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
            // --- BOTÓN DE PRUEBA DE NOTIFICACIÓN ---
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              onPressed: () {
                if (_quiereRecordatorio && _medNombreRecordatorio.text.isNotEmpty) {
                  debugPrint('🧪 PROBANDO NOTIFICACIÓN INMEDIATA...');
                  NotificationService.showNotification(
                    id: 999,
                    title: "PRUEBA: Recordatorio Médico",
                    body: "Es hora de tomar: ${_medNombreRecordatorio.text}",
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("📢 Notificación de prueba enviada"), backgroundColor: Colors.orangeAccent),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("⚠️ Habilita recordatorio y escribe medicamento primero"), backgroundColor: Colors.orange),
                  );
                }
              },
              child: const Text("🧪 PROBAR NOTIFICACIÓN AHORA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 15),
            _buildSubmitButton(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _header(String t) => Padding(
    padding: const EdgeInsets.only(top: 25, bottom: 15), 
    child: Text(t, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14))
  );

  InputDecoration _inputStyle(String l, IconData i, {String? hint}) => InputDecoration(
    labelText: l, 
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
    labelStyle: const TextStyle(color: Colors.cyan),
    prefixIcon: Icon(i, color: Colors.cyan),
    filled: true, 
    fillColor: Colors.white.withValues(alpha: 0.05),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent)),
  );

  Widget _buildField(TextEditingController c, String l, IconData i, {bool obscure = false, TextInputType type = TextInputType.text, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c, 
        obscureText: obscure, 
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: _inputStyle(l, i, hint: hint),
        validator: (v) => v == null || v.isEmpty ? "Requerido" : null,
      ),
    );
  }

  Widget _buildAlertaSwitch() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
      child: SwitchListTile(
        title: const Text("Recordatorio Diario", style: TextStyle(color: Colors.white)),
        value: _quiereRecordatorio,
        activeThumbColor: Colors.cyanAccent,
        onChanged: (v) => setState(() => _quiereRecordatorio = v),
      ),
    );
  }

  Widget _buildTimePickerTile() {
    return ListTile(
      tileColor: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(Icons.access_time, color: Colors.cyanAccent),
      title: const Text("Hora de la Alarma", style: TextStyle(color: Colors.white70)),
      trailing: Text(_horaAlarma.format(context), style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
      onTap: () async {
        TimeOfDay? p = await showTimePicker(context: context, initialTime: _horaAlarma);
        if (p != null) setState(() => _horaAlarma = p);
      },
    );
  }

  Widget _buildProbarAlertaBtn() {
    return Center(
      child: TextButton.icon(
        onPressed: _probarNotificacion,
        icon: const Icon(Icons.play_circle_fill),
        label: const Text("Probar Sonido y Vibración"),
        style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return _isSaving 
      ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
      : ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent, 
            minimumSize: const Size(double.infinity, 60), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
          ),
          onPressed: _registrar,
          child: const Text("CREAR CUENTA Y EXPEDIENTE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        );
  }

  Widget _buildChipsCondiciones() {
    return Wrap(
      spacing: 8,
      children: _condicionesCronicas.keys.map((c) => FilterChip(
        label: Text(c, style: TextStyle(color: _condicionesCronicas[c]! ? Colors.black : Colors.white)),
        selected: _condicionesCronicas[c]!,
        selectedColor: Colors.cyanAccent,
        checkmarkColor: Colors.black,
        onSelected: (v) => setState(() => _condicionesCronicas[c] = v),
      )).toList(),
    );
  }

  Widget _buildExpandableAlergias(String cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        iconColor: Colors.cyanAccent,
        collapsedIconColor: Colors.white,
        title: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 14)),
        children: [
          ..._alergiasComunes[cat]!.map((a) {
            final hasNinguno = _seleccionados[cat]!.contains('Ninguno');
            final isNinguno = a == 'Ninguno';
            final isDisabled = hasNinguno && !isNinguno;
            
            return Column(
              children: [
                CheckboxListTile(
                  title: Text(a, style: TextStyle(
                    color: isDisabled ? Colors.white30 : Colors.white70,
                    fontSize: 12,
                  )),
                  value: _seleccionados[cat]!.contains(a),
                  enabled: !isDisabled,
                  activeColor: Colors.cyanAccent,
                  checkColor: Colors.black,
                  onChanged: isDisabled ? null : (v) {
                    _manejarSeleccionOpcion(cat, a);
                  },
                ),
                // --- COMENTARIO PARA VACUNAS ---
                if (a == 'Vacunas (especificar)' && _seleccionados[cat]!.contains(a))
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    child: Text(
                      '💡 Completa los detalles en la sección 6. VACUNAS',
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            );
          }).toList(),
          const Divider(color: Colors.white24, height: 12),
          CheckboxListTile(
            title: const Text("Otro", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            value: _mostrarOtroAlergia[cat] ?? false,
            activeColor: Colors.orangeAccent,
            checkColor: Colors.black,
            onChanged: (v) {
              setState(() {
                _mostrarOtroAlergia[cat] = v ?? false;
                if (v == false) {
                  _otrasAlergiasList[cat]!.clear();
                }
              });
            },
          ),
          if (_mostrarOtroAlergia[cat] ?? false)
            _buildOtrasAlergias(cat),
        ],
      ),
    );
  }

  Widget _buildDeportesSelection() {
    final deportes = ['Fútbol', 'Baloncesto', 'Tenis', 'Natación', 'Ciclismo', 'Atletismo', 'Gym / Pesas', 'Yoga', 'Crossfit', 'Danza', 'Otros'];
    
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Deportes:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: deportes.map((deporte) {
            final isSelected = _deportesSeleccionados.contains(deporte);
            return FilterChip(
              label: Text(deporte),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _deportesSeleccionados.add(deporte);
                  } else {
                    _deportesSeleccionados.remove(deporte);
                  }
                });
              },
              backgroundColor: Colors.grey[800],
              selectedColor: Colors.cyanAccent.withValues(alpha: 0.7),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
        CheckboxListTile(
          title: const Text("Otro deporte", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          value: _mostrarOtroDeporte,
          activeColor: Colors.orangeAccent,
          checkColor: Colors.black,
          onChanged: (v) {
            setState(() {
              _mostrarOtroDeporte = v ?? false;
              if (v == false) {
                _otroDeporteController.clear();
              }
            });
          },
        ),
        if (_mostrarOtroDeporte)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 12),
            child: TextField(
              controller: _otroDeporteController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: "Especifique",
                hintText: "Ej: Tenis de mesa, Hockey, Escalada",
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                labelStyle: const TextStyle(color: Colors.cyan),
                prefixIcon: const Icon(Icons.sports, color: Colors.cyan),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.cyan, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOtrasAlergias(String cat) {
    final controller = TextEditingController();
    final hints = {
      'Ambiental': 'Ej: Polen de roble, Humedad extrema',
      'Medicamentos': 'Ej: Cefalosporinas, Diclofenaco',
      'Alimentos': 'Ej: Cacahuate, Mariscos, Lácteos',
    };
    
    final icons = {
      'Ambiental': Icons.cloud_queue,
      'Medicamentos': Icons.local_pharmacy,
      'Alimentos': Icons.restaurant,
    };
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              labelText: "Especifique",
              hintText: hints[cat] ?? "Escribe y presiona Enter",
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 10),
              labelStyle: const TextStyle(color: Colors.cyan),
              prefixIcon: Icon(icons[cat] ?? Icons.note, color: Colors.cyanAccent, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.cyan, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),

            ),
            onSubmitted: (v) {
              if (v.isNotEmpty && !_otrasAlergiasList[cat]!.contains(v)) {
                setState(() => _otrasAlergiasList[cat]!.add(v));
                controller.clear();
              }
            },
          ),
        ),
        if (_otrasAlergiasList[cat]!.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _otrasAlergiasList[cat]!.map((alergia) {
              return Chip(
                label: Text(alergia, style: const TextStyle(color: Colors.black, fontSize: 11)),
                deleteIcon: const Icon(Icons.close, size: 16),
                backgroundColor: Colors.cyanAccent,
                onDeleted: () => setState(() => _otrasAlergiasList[cat]!.remove(alergia)),
              );
            }).toList(),
          ),
      ],
    );
  }
}