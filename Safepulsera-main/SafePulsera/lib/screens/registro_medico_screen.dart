import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notification_service.dart';

class RegistroMedicoScreen extends StatefulWidget {
  const RegistroMedicoScreen({super.key});

  @override
  State<RegistroMedicoScreen> createState() => _RegistroMedicoScreenState();
}

class _RegistroMedicoScreenState extends State<RegistroMedicoScreen> {
  final _edadController = TextEditingController();
  final _pesoController = TextEditingController();
  final _alturaController = TextEditingController();
  final _medNombreRecordatorio = TextEditingController();
  final _vacunaEspecificaController = TextEditingController();
  final _otroDeporteController = TextEditingController();
  final _contactoNombre = TextEditingController();
  final _contactoTel = TextEditingController();

  final Map<String, List<String>> _alergiasMaster = {
    'Ambiental': [
      'Ninguno', 'Ácaros del Polvo', 'Polen de Olivo', 'Humedad / Moho', 'Pelo de Gato',
      'Pelo de Perro', 'Látex', 'Polen de Abedul', 'Cucarachas', 'Humo de Tabaco',
      'Pasto / Césped', 'Picadura de Abeja', 'Picadura de Hormiga', 'Polvo de Madera',
      'Cloro / Químicos', 'Lana', 'Níquel', 'Algodón'
    ],
    'Medicamentos': [
      'Ninguno', 'Penicilina', 'Aspirina (AAS)', 'Ibuprofeno', 'Sulfamidas', 'Insulina',
      'Naproxeno', 'Amoxicilina', 'Anestesia local', 'Yodo (Contraste)', 'Morfina',
      'Codeína', 'Anticonvulsivos', 'Quimioterapia', 'Vacunas (especificar)', 'Paracetamol',
      'Ketorolaco', 'Metamizol'
    ],
    'Alimentos': [
      'Ninguno', 'Maní / Cacahuetes', 'Mariscos', 'Pescados', 'Leche de Vaca', 'Huevo', 'Gluten',
      'Nueces', 'Soya', 'Fresas', 'Chocolate', 'Cítricos', 'Tomate',
      'Colorantes (Rojo 40)', 'Piña', 'Kiwi', 'Canela', 'Lentejas'
    ],
  };

  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _mostrarOtroDeporte = false;
  bool _contactoFavorito = false;
  String? _tipoSangre;
  String? _nivelActividad;
  final Map<String, bool> _mostrarOtroAlergia = {'Ambiental': false, 'Medicamentos': false, 'Alimentos': false};
  bool _especificarOtroDeporte = false;
  TimeOfDay _horaAlarma = const TimeOfDay(hour: 8, minute: 0);

  final Map<String, bool> _condicionesCronicas = {
    'Asma': false, 'Diabetes': false, 'Hipertensión': false, 'Epilepsia': false,
  };

  final Map<String, List<String>> _seleccionados = {
    'Ambiental': [], 'Medicamentos': [], 'Alimentos': []
  };
  List<String> _deportesSeleccionados = [];

  final Map<String, List<String>> _otrasAlergiasList = {
    'Ambiental': [], 'Medicamentos': [], 'Alimentos': []
  };

  @override
  void initState() {
    super.initState();
    _cargarDatosSincronizados();
  }

  @override
  void dispose() {
    _edadController.dispose();
    _pesoController.dispose();
    _alturaController.dispose();
    _medNombreRecordatorio.dispose();
    _vacunaEspecificaController.dispose();
    _otroDeporteController.dispose();
    _contactoNombre.dispose();
    _contactoTel.dispose();
    super.dispose();
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

  Future<void> _cargarDatosSincronizados() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final perfil = data['perfil'] ?? {};
        final clinico = data['clinico'] ?? {};
        final alergias = data['alergias'] ?? {};
        final notif = data['notificaciones'] ?? {};

        // Cargar favorito desde emergency_contacts
        bool favoritoValue = false;
        try {
          final emergencyDoc = await FirebaseFirestore.instance
              .collection('emergency_contacts')
              .doc(user.uid)
              .get();
          if (emergencyDoc.exists) {
            favoritoValue = emergencyDoc['isFavorito'] ?? false;
          }
        } catch (e) {
          debugPrint("Error cargando favorito: $e");
        }

        setState(() {
          _edadController.text = perfil['edad']?.toString() ?? '';
          _pesoController.text = perfil['peso']?.toString() ?? '';
          _alturaController.text = perfil['altura']?.toString() ?? '';
          _nivelActividad = perfil['nivel_actividad'];
          _deportesSeleccionados = List<String>.from(perfil['deportes'] ?? []);
          _otroDeporteController.text = perfil['otro_deporte'] ?? '';
          _especificarOtroDeporte = _otroDeporteController.text.isNotEmpty;

          _tipoSangre = clinico['sangre'];
          _contactoNombre.text = clinico['emergencia']?['contacto_nombre'] ?? '';
          _contactoTel.text = clinico['emergencia']?['contacto_tel'] ?? '';
          _contactoFavorito = favoritoValue;

          Map<String, dynamic> cond = clinico['condiciones'] ?? {};
          cond.forEach((k, v) {
            if (_condicionesCronicas.containsKey(k)) _condicionesCronicas[k] = v ?? false;
          });

          Map<String, dynamic> sel = alergias['seleccionadas'] ?? {};
          sel.forEach((cat, items) {
            if (items is List) _seleccionados[cat] = items.cast<String>();
          });

          _vacunaEspecificaController.text = alergias['detalle_vacuna'] ?? '';
          _medNombreRecordatorio.text = notif['medicamento'] ?? '';

          if (notif['hora'] != null) {
            String h = notif['hora'];
            _horaAlarma = TimeOfDay(
              hour: int.parse(h.split(":")[0]), 
              minute: int.parse(h.split(":")[1])
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Error al cargar: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarCambios() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);

    try {
      String horaStr = "${_horaAlarma.hour.toString().padLeft(2, '0')}:${_horaAlarma.minute.toString().padLeft(2, '0')}";

      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
        'perfil.edad': _edadController.text,
        'perfil.peso': _pesoController.text,
        'perfil.altura': _alturaController.text,
        'perfil.nivel_actividad': _nivelActividad,
        'perfil.deportes': _deportesSeleccionados,
        'perfil.otro_deporte': _especificarOtroDeporte ? _otroDeporteController.text : null,
        'clinico.sangre': _tipoSangre,
        'clinico.condiciones': _condicionesCronicas,
        'clinico.emergencia': {
          'contacto_nombre': _contactoNombre.text,
          'contacto_tel': _contactoTel.text
        },
        'alergias.seleccionadas': _seleccionados,
        'alergias.otros': _otrasAlergiasList,
        'notificaciones': {
          'medicamento': _medNombreRecordatorio.text,
          'hora': horaStr,
        },
      });

      // Sincronizar contacto SOS en colección emergencia global
      if (_contactoNombre.text.isNotEmpty && _contactoTel.text.isNotEmpty) {
        await FirebaseFirestore.instance.collection('emergency_contacts').doc(user.uid).set({
          'uid': user.uid,
          'nombre': _contactoNombre.text.trim(),
          'telefono': _contactoTel.text.trim(),
          'isFavorito': _contactoFavorito,
          'activo': true,
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (_medNombreRecordatorio.text.isNotEmpty) {
        debugPrint('🔔 INTENTANDO PROGRAMAR NOTIFICACIÓN EN PERFIL');
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
        debugPrint('⚠️ Cancelando notificación - medicamento vacío');
        // Cancelar alerta si el usuario limpia el medicamento
        await NotificationService.cancelarAlerta(101);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Expediente actualizado"), backgroundColor: Color(0xFF00F5D4)),
        );
      }
    } catch (e) {
      debugPrint("Error al guardar: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF050505), 
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00F5D4)))
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("EXPEDIENTE MÉDICO", style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          _isSaving 
            ? const Center(child: Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F5D4))))
            : IconButton(
                icon: Icon(_isEditing ? Icons.check_circle : Icons.edit, color: const Color(0xFF00F5D4), size: 28),
                onPressed: () async {
                  if (_isEditing) await _guardarCambios();
                  setState(() => _isEditing = !_isEditing);
                },
              )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            _buildSectionCard("1. BIOMETRÍA Y ACTIVIDAD", [
              Row(children: [
                Expanded(child: _buildInput(_edadController, "Edad", Icons.cake, hint: "Ej: 25")),
                const SizedBox(width: 15),
                Expanded(child: _buildInput(_pesoController, "Peso (kg)", Icons.monitor_weight, hint: "Ej: 70")),
              ]),
              _buildInput(_alturaController, "Altura (cm)", Icons.height, hint: "Ej: 180"),
              const SizedBox(height: 10),
              _buildActividadDropdown(),
              if (_nivelActividad == 'Atleta') _buildDeportesSelection(),
            ]),
            _buildSectionCard("2. CLÍNICA Y EMERGENCIA", [
              _buildSangreDropdown(),
              const SizedBox(height: 15),
              const Text("Condiciones Crónicas:", style: TextStyle(color: Colors.white70, fontSize: 13)),
              _buildCondicionesChips(),
              const Divider(color: Colors.white10, height: 30),
              _buildInput(_contactoNombre, "Contacto SOS", Icons.person_pin, hint: "Nombre del contacto"),
              _buildInput(_contactoTel, "Teléfono SOS", Icons.phone_android, hint: "8674410213"),
              CheckboxListTile(
                title: const Text("Marcar como favorito", style: TextStyle(color: Colors.white, fontSize: 13)),
                value: _contactoFavorito,
                onChanged: _isEditing ? (value) {
                  setState(() {
                    _contactoFavorito = value ?? false;
                  });
                } : null,
                activeColor: const Color(0xFF00F5D4),
                checkColor: Colors.black,
                contentPadding: EdgeInsets.zero,
              ),
            ]),
            _buildSectionCard("3. ALERGIAS", [
              ..._alergiasMaster.keys.map((cat) => _buildAlergiaExpansion(cat)),
            ]),
            _buildSectionCard("4. RECORDATORIO MÉDICO (DIARIO)", [
              _buildInput(_medNombreRecordatorio, "Medicamento", Icons.medication, hint: "Nombre del medicamento"),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: _isEditing,
                leading: const Icon(Icons.access_time, color: Color(0xFF00F5D4)),
                title: const Text("Hora del mensaje diario", style: TextStyle(color: Colors.white70)),
                trailing: Text(_horaAlarma.format(context), 
                  style: const TextStyle(color: Color(0xFF00F5D4), fontSize: 18, fontWeight: FontWeight.bold)),
                onTap: () async {
                  TimeOfDay? p = await showTimePicker(context: context, initialTime: _horaAlarma);
                  if (p != null) setState(() => _horaAlarma = p);
                },
              ),
            ]),
            // --- SECCIÓN 6: VACUNAS ---
            if (_seleccionados['Medicamentos']!.contains('Vacunas (especificar)'))
              _buildSectionCard("6. VACUNAS", [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F5D4).withValues(alpha: 0.1),
                    border: Border.all(color: const Color(0xFF00F5D4), width: 1.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.vaccines, color: Color(0xFF00F5D4), size: 18),
                          SizedBox(width: 10),
                          Text('Especifique la vacuna', style: TextStyle(color: Color(0xFF00F5D4), fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.only(left: 28),
                        child: Text(
                          '(Esta sección aparece porque seleccionaste "Vacunas (especificar)" en Medicamentos)',
                          style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInput(_vacunaEspecificaController, "Nombre de la vacuna", Icons.vaccines, hint: "Ej: Pfizer COVID-19, AstraZeneca"),
                    ],
                  ),
                ),
              ]),
            const SizedBox(height: 30),
            // --- BOTÓN DE PRUEBA DE NOTIFICACIÓN ---
            if (_medNombreRecordatorio.text.isNotEmpty)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: () {
                  debugPrint('🧪 PROBANDO NOTIFICACIÓN INMEDIATA DESDE PERFIL...');
                  NotificationService.showNotification(
                    id: 999,
                    title: "PRUEBA: Recordatorio de Medicamento",
                    body: "Es hora de tu medicamento: ${_medNombreRecordatorio.text}",
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("📢 Notificación de prueba enviada"), backgroundColor: Colors.orangeAccent),
                  );
                },
                child: const Text("🧪 PROBAR NOTIFICACIÓN AHORA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F29), 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05))
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFF00F5D4), fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 15),
        ...children,
      ]),
    );
  }

  Widget _buildInput(TextEditingController c, String l, IconData i, {bool isNumber = false, String? hint}) {
    return TextFormField(
      controller: c,
      enabled: _isEditing,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: l,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(i, color: const Color(0xFF00F5D4), size: 20),
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildActividadDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _nivelActividad,
      dropdownColor: const Color(0xFF1A1F29),
      style: const TextStyle(color: Colors.white),
      items: ['Sedentario', 'Moderado', 'Atleta']
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: _isEditing ? (v) => setState(() => _nivelActividad = v) : null,
      decoration: const InputDecoration(
        labelText: "Nivel de Actividad", 
        labelStyle: TextStyle(color: Colors.white38), 
        prefixIcon: Icon(Icons.fitness_center, color: Color(0xFF00F5D4))
      ),
    );
  }

  Widget _buildSangreDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _tipoSangre,
      dropdownColor: const Color(0xFF1A1F29),
      style: const TextStyle(color: Colors.white),
      items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: _isEditing ? (v) => setState(() => _tipoSangre = v) : null,
      decoration: const InputDecoration(
        labelText: "Grupo Sanguíneo", 
        labelStyle: TextStyle(color: Colors.white38), 
        prefixIcon: Icon(Icons.bloodtype, color: Color(0xFF00F5D4))
      ),
    );
  }

  Widget _buildCondicionesChips() {
    return Wrap(
      spacing: 8, 
      children: _condicionesCronicas.keys.map((c) => FilterChip(
        label: Text(c, style: TextStyle(color: _condicionesCronicas[c]! ? Colors.black : Colors.white70, fontSize: 12)),
        selected: _condicionesCronicas[c]!,
        selectedColor: const Color(0xFF00F5D4),
        onSelected: _isEditing ? (v) => setState(() => _condicionesCronicas[c] = v) : null,
      )).toList(),
    );
  }

  Widget _buildAlergiaExpansion(String cat) {
    return ExpansionTile(
      iconColor: const Color(0xFF00F5D4),
      title: Text(cat, style: const TextStyle(color: Colors.white, fontSize: 14)),
      children: [
        ..._alergiasMaster[cat]!.map((item) {
          final hasNinguno = _seleccionados[cat]!.contains('Ninguno');
          final isNinguno = item == 'Ninguno';
          final isDisabled = hasNinguno && !isNinguno;
          
          return Column(
            children: [
              CheckboxListTile(
                enabled: _isEditing && !isDisabled,
                title: Text(item, style: TextStyle(
                  color: isDisabled ? Colors.white30 : Colors.white70,
                  fontSize: 13,
                )),
                value: _seleccionados[cat]?.contains(item) ?? false,
                onChanged: isDisabled ? null : (v) {
                  _manejarSeleccionOpcion(cat, item);
                },
              ),
              // --- COMENTARIO PARA VACUNAS ---
              if (item == 'Vacunas (especificar)' && _seleccionados[cat]!.contains(item))
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Text(
                    '💡 Completa los detalles en la sección 6. VACUNAS',
                    style: const TextStyle(color: Color(0xFF00F5D4), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          );
        }).toList(),
        // --- SECCIÓN VACUNAS ---
        if (cat == 'Medicamentos' && _seleccionados[cat]!.contains('Vacunas (especificar)')) ...[
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00F5D4).withValues(alpha: 0.1),
              border: Border.all(color: const Color(0xFF00F5D4), width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.vaccines, color: Color(0xFF00F5D4), size: 18),
                    SizedBox(width: 8),
                    Text('VACUNAS', style: TextStyle(color: Color(0xFF00F5D4), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _vacunaEspecificaController,
                  enabled: _isEditing,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: "Nombre de la vacuna",
                    hintText: "Ej: Pfizer COVID-19, AstraZeneca, Neumocócica",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 10),
                    labelStyle: const TextStyle(color: Colors.cyan),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.cyan, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white12, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF00F5D4), width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
          ),
        ] else
        const SizedBox.shrink(),
        const Divider(color: Colors.white24, height: 12),
        CheckboxListTile(
          enabled: _isEditing,
          title: const Text("Otro", style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildDeportesSelection() {
    final deportes = ['Fútbol', 'Baloncesto', 'Tenis', 'Natación', 'Ciclismo', 'Atletismo', 'Gym / Pesas', 'Yoga', 'Crossfit', 'Danza'];
    
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
          enabled: _isEditing,
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
              enabled: _isEditing,
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
                disabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.cyan, width: 1.5),
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
            enabled: _isEditing,
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