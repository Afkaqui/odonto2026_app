import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'models.dart';
import 'local_store.dart';
import 'monitor_screen.dart';
import 'sessions_screen.dart';
import 'scan_screen.dart';
import 'util.dart';

// Configura una atención (OFFLINE-FIRST): datos del paciente + pulsera por BLE,
// y crea la consulta LOCAL. No requiere servidor; se sincroniza luego.
class SetupScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  const SetupScreen({super.key, required this.doctor});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _code = TextEditingController();
  final _age = TextEditingController();
  String _gender = 'M';

  String? _braceletCode; // nombre BLE de la pulsera
  String? _deviceId;     // MAC (remoteId) para conectar luego

  Future<void> _buscarPulserasBle() async {
    // Abre la pantalla de escaneo en vivo y recibe el dispositivo elegido.
    final elegido = await Navigator.push<ScanResult>(
      context, MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (elegido == null || !mounted) return;
    setState(() {
      _deviceId = elegido.device.remoteId.str;
      _braceletCode = elegido.device.platformName.isEmpty ? elegido.device.remoteId.str : elegido.device.platformName;
    });
    _msg('Pulsera asignada: $_braceletCode');
  }

  void _iniciar() {
    if (_code.text.trim().isEmpty) { _msg('Ingresa el código del paciente'); return; }
    final doc = widget.doctor;
    final consulta = LocalConsultation(
      clientUuid: genClientUuid(),
      doctorUsername: doc['username']?.toString(),
      doctorName: doc['name']?.toString(),
      doctorLastname: doc['lastname']?.toString(),
      patientCode: _code.text.trim(),
      patientAge: int.tryParse(_age.text.trim()),
      patientGender: _gender,
      braceletCode: _braceletCode,
      startedAt: DateTime.now().toIso8601String(),
    );
    LocalStore.instance.add(consulta);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MonitorScreen(consultation: consulta, deviceId: _deviceId),
    ));
  }

  void _msg(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doctor;
    final nombreDoc = (doc['name']?.toString().isNotEmpty ?? false)
        ? "${doc['name']} ${doc['lastname'] ?? ''}"
        : (doc['username']?.toString() ?? 'Odontólogo');
    return Scaffold(
      appBar: AppBar(
        title: Text('Dr(a). $nombreDoc'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sesiones guardadas',
            icon: const Icon(Icons.folder_shared),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionsScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Paciente', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: _code, decoration: const InputDecoration(labelText: 'Código (ej. PAC-2025-001)')),
          TextField(controller: _age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Edad')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(labelText: 'Género'),
            items: const [
              DropdownMenuItem(value: 'M', child: Text('Masculino')),
              DropdownMenuItem(value: 'F', child: Text('Femenino')),
              DropdownMenuItem(value: 'O', child: Text('Otro')),
            ],
            onChanged: (v) => setState(() => _gender = v ?? 'M'),
          ),
          const SizedBox(height: 20),
          const Text('Pulsera', style: TextStyle(fontWeight: FontWeight.bold)),
          OutlinedButton.icon(
            onPressed: _buscarPulserasBle,
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('Buscar pulseras por Bluetooth (auto-asignar)'),
          ),
          if (_braceletCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Pulsera: $_braceletCode', style: const TextStyle(fontSize: 12, color: Colors.green)),
            ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _iniciar,
            icon: const Icon(Icons.play_arrow),
            label: const Text('INICIAR CONSULTA'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ]),
      ),
    );
  }
}
