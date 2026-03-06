import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _alarmTimer;
  bool _isButtonEnabled = false;
  bool _isAlarmPlaying = false;
  bool _isContactFavorito = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateForm);
    _phoneController.addListener(_validateForm);
    _searchController.addListener(() => setState(() {}));
  }

  void _validateForm() {
    setState(() {
      _isButtonEnabled = _nameController.text.trim().isNotEmpty && 
                         _phoneController.text.trim().length >= 10;
    });
  }

  // --- LÓGICA DE ALERTA (SONIDO Y VIBRACIÓN) ---
  void _startPanicAlert() async {
    if (!_isAlarmPlaying) {
      try {
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.play(AssetSource('audio/alarma.mp3'));
        
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
        }
        
        setState(() => _isAlarmPlaying = true);

        _alarmTimer?.cancel();
        _alarmTimer = Timer(const Duration(minutes: 5), () {
          if (_isAlarmPlaying) _stopPanicAlert();
        });
      } catch (e) {
        debugPrint("Error al iniciar alarma: $e");
      }
    }
  }

  void _stopPanicAlert() async {
    await _audioPlayer.stop();
    Vibration.cancel();
    _alarmTimer?.cancel();
    setState(() => _isAlarmPlaying = false);
  }

  // --- ENVÍO DE SOS CON GPS ---
  Future<void> _sendEmergencyAlert(String phoneNumber, String platform) async {
    _startPanicAlert();
    
    String locationUrl = "";
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
        );
        // Link de Google Maps estándar
        locationUrl = "\n\nMi ubicación: https://www.google.com/maps?q=${position.latitude},${position.longitude}";
      }
    } catch (e) {
      debugPrint("Error GPS: $e");
    }

    final String message = "¡EMERGENCIA! Soy usuario de SafeAllergy y necesito ayuda urgente.$locationUrl";

    if (platform == 'sms') {
      final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber, queryParameters: {'body': message});
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    } else if (platform == 'whatsapp') {
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (!cleanPhone.startsWith('52')) cleanPhone = '52$cleanPhone';
      
      final Uri whatsappUri = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _saveContact() async {
    if (_isButtonEnabled) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance.collection('emergency_contacts').add({
        'nombre': _nameController.text.trim(),
        'telefono': _phoneController.text.trim(),
        'isFavorito': _isContactFavorito,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      });
      _nameController.clear();
      _phoneController.clear();
      _isContactFavorito = false;
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _toggleFavorito(String docId, bool isFavorito) async {
    await FirebaseFirestore.instance.collection('emergency_contacts').doc(docId).update({
      'isFavorito': !isFavorito,
    });
  }

  void _showAddDialog() {
    _isContactFavorito = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1F29),
            title: const Text("Nuevo Contacto", style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Nombre", labelStyle: TextStyle(color: Colors.white70)),
                  onChanged: (v) => setDialogState(() {}),
                ),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Teléfono", labelStyle: TextStyle(color: Colors.white70)),
                  onChanged: (v) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text("Marcar como favorito", style: TextStyle(color: Colors.white, fontSize: 13)),
                  value: _isContactFavorito,
                  onChanged: (value) {
                    setDialogState(() {
                      _isContactFavorito = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFF00F5D4),
                  checkColor: Colors.black,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _isButtonEnabled ? const Color(0xFF00F5D4) : Colors.grey),
                onPressed: _isButtonEnabled ? _saveContact : null,
                child: const Text("GUARDAR", style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text("CONTACTOS SOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isAlarmPlaying)
            IconButton(
              icon: const Icon(Icons.notifications_off, color: Colors.redAccent),
              onPressed: _stopPanicAlert,
            )
        ],
      ),
      body: Column(
        children: [
          // --- BUSCADOR CON LUPA ---
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Buscar por nombre o número",
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00F5D4)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF00F5D4), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white10, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF00F5D4), width: 2),
                ),
              ),
            ),
          ),

          // --- CONTACTO SOS PRINCIPAL (DEL REGISTRO) - SIEMPRE VISIBLE ---
          // --- CONTACTO SOS PRINCIPAL (DEL REGISTRO) - SIEMPRE VISIBLE ---
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('emergency_contacts').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
              var data = snapshot.data!.data() as Map<String, dynamic>;
              String nombre = data['nombre'] ?? 'Contacto Principal';
              String telefono = data['telefono'] ?? '';
              String email = data['email_usuario'] ?? '';
              bool isFavorito = data['isFavorito'] ?? false;
              if (telefono.isEmpty) return const SizedBox();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 20, top: 12, bottom: 8),
                    child: Text("TU CONTACTO SOS", 
                      style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.white10, 
                      child: Icon(Icons.person, color: Colors.white)
                    ),
                    title: Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(telefono, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        if (email.isNotEmpty) Text(email, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isFavorito ? Icons.star : Icons.star_outline,
                            color: isFavorito ? Colors.amberAccent : Colors.white38,
                            size: 20,
                          ),
                          onPressed: () => _toggleFavorito(user!.uid, isFavorito),
                        ),
                        IconButton(
                          icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.greenAccent, size: 16), 
                          onPressed: () => _sendEmergencyAlert(telefono, 'whatsapp'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.message, color: Colors.blueAccent, size: 16), 
                          onPressed: () => _sendEmergencyAlert(telefono, 'sms'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
          // --- CONTACTOS FAVORITOS Y OTROS CONTACTOS ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('emergency_contacts')
                .where('userId', isEqualTo: user?.uid)
                .where('isFavorito', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();

              List<QueryDocumentSnapshot> favoritos = snapshot.data!.docs
                  .where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String nombre = data['nombre']?.toString().toLowerCase() ?? '';
                    String telefono = data['telefono']?.toString() ?? '';
                    String searchText = _searchController.text.toLowerCase();
                    return nombre.contains(searchText) || telefono.contains(searchText);
                  })
                  .toList();

              if (favoritos.isEmpty) return const SizedBox();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 20, top: 12, bottom: 8),
                    child: Text("CONTACTOS FAVORITOS", 
                      style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  ...favoritos.map((doc) => _buildContactTile(doc)),
                  const Padding(
                    padding: EdgeInsets.only(left: 20, top: 12, bottom: 8),
                    child: Text("OTROS CONTACTOS", 
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ),
                ],
              );
            },
          ),

          // --- LISTA DE TODOS LOS CONTACTOS (FILTRADOS Y ORDENADOS) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('emergency_contacts')
                  .where('userId', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00F5D4)));

                List<QueryDocumentSnapshot> allContacts = snapshot.data!.docs;
                
                // Filtrar por búsqueda y excluir el contacto principal del usuario actual
                List<QueryDocumentSnapshot> filtrados = allContacts
                    .where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      String nombre = data['nombre']?.toString().toLowerCase() ?? '';
                      String telefono = data['telefono']?.toString() ?? '';
                      String searchText = _searchController.text.toLowerCase();
                      return (nombre.contains(searchText) || telefono.contains(searchText)) && data['uid'] != user?.uid;
                    })
                    .toList();

                // Mostrar solo no favoritos (los favoritos ya se muestran arriba)
                List<QueryDocumentSnapshot> noFavoritos = filtrados
                    .where((doc) {
                      bool isFav = (doc.data() as Map<String, dynamic>)['isFavorito'] ?? false;
                      return !isFav;
                    })
                    .toList();

                if (noFavoritos.isEmpty) {
                  return Center(
                    child: Text(
                      _searchController.text.isEmpty ? "No hay otros contactos" : "No hay resultados",
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: noFavoritos.length,
                  itemBuilder: (context, index) => _buildContactTile(noFavoritos[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00F5D4),
        onPressed: _showAddDialog,
        child: const Icon(Icons.person_add_alt_1, color: Colors.black),
      ),
    );
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    _audioPlayer.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildContactTile(QueryDocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String nombre = data['nombre'] ?? 'Sin nombre';
    String telefono = data['telefono'] ?? '';
    String email = data['email_usuario'] ?? '';
    bool isFavorito = data['isFavorito'] ?? false;

    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.white10, 
        child: Icon(Icons.person, color: Colors.white)
      ),
      title: Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 13)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(telefono, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          if (email.isNotEmpty) Text(email, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isFavorito ? Icons.star : Icons.star_outline,
              color: isFavorito ? Colors.amberAccent : Colors.white38,
              size: 20,
            ),
            onPressed: () => _toggleFavorito(doc.id, isFavorito),
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.greenAccent, size: 16), 
            onPressed: () => _sendEmergencyAlert(telefono, 'whatsapp'),
          ),
          IconButton(
            icon: const Icon(Icons.message, color: Colors.blueAccent, size: 16), 
            onPressed: () => _sendEmergencyAlert(telefono, 'sms'),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white24, size: 16),
            onPressed: () => FirebaseFirestore.instance.collection('emergency_contacts').doc(doc.id).delete(),
          ),
        ],
      ),
    );
  }
}