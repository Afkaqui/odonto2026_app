import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'api_service.dart';
import 'models.dart';
import 'local_store.dart';
import 'monitor_screen.dart';
import 'sessions_screen.dart';
import 'scan_screen.dart';
import 'util.dart';

// Configura una atención (OFFLINE-FIRST). Dos modos de paciente:
//  - Sencillo: escribes el código/edad/género en el momento (efímero).
//  - Detallado: buscas un paciente reutilizable del servidor o creas uno nuevo.
class SetupScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  const SetupScreen({super.key, required this.doctor});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _modo = 0; // 0 = sencillo, 1 = detallado

  // Sencillo
  final _code = TextEditingController();
  final _age = TextEditingController();
  String _gender = 'M';

  // Detallado
  final _busqueda = TextEditingController();
  List<dynamic> _resultados = [];
  Map<String, dynamic>? _pacienteSel;
  bool _buscando = false;

  // Pulsera
  String? _braceletCode;
  String? _deviceId;

  Future<void> _buscarPulserasBle() async {
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

  // --- Modo detallado: búsqueda de pacientes reutilizables ---
  Future<void> _buscar() async {
    setState(() => _buscando = true);
    try {
      final list = await ApiService.listPatients(q: _busqueda.text);
      setState(() => _resultados = list);
    } catch (e) {
      _msg('Sin conexión al servidor para buscar. Usa el modo sencillo si estás offline.');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _crearPacienteReutilizable() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final age = TextEditingController();
    String genero = 'M';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nuevo paciente reutilizable'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: code, decoration: const InputDecoration(labelText: 'Código (único, ej. PAC-2025-001)')),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre / identificador')),
              TextField(controller: age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Edad')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: genero,
                decoration: const InputDecoration(labelText: 'Género'),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Masculino')),
                  DropdownMenuItem(value: 'F', child: Text('Femenino')),
                  DropdownMenuItem(value: 'O', child: Text('Otro')),
                ],
                onChanged: (v) => genero = v ?? 'M',
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (code.text.trim().isEmpty) { _msg('El código es obligatorio'); return; }
    try {
      final p = await ApiService.createPatient(
        code.text.trim(), int.tryParse(age.text.trim()), genero, name: name.text.trim(),
      );
      setState(() {
        _pacienteSel = p;
        _resultados = [p, ..._resultados];
      });
      _msg('Paciente creado y seleccionado');
    } catch (e) {
      _msg('Error: $e');
    }
  }

  void _iniciar() {
    String? code, gender, name;
    int? age;
    if (_modo == 0) {
      if (_code.text.trim().isEmpty) { _msg('Ingresa el código del paciente'); return; }
      code = _code.text.trim();
      age = int.tryParse(_age.text.trim());
      gender = _gender;
    } else {
      if (_pacienteSel == null) { _msg('Selecciona o crea un paciente'); return; }
      code = _pacienteSel!['code']?.toString();
      age = _pacienteSel!['age'] is int ? _pacienteSel!['age'] : int.tryParse('${_pacienteSel!['age']}');
      gender = _pacienteSel!['gender']?.toString();
      name = _pacienteSel!['name']?.toString();
    }

    final doc = widget.doctor;
    final consulta = LocalConsultation(
      clientUuid: genClientUuid(),
      doctorUsername: doc['username']?.toString(),
      doctorName: doc['name']?.toString(),
      doctorLastname: doc['lastname']?.toString(),
      patientCode: code,
      patientAge: age,
      patientGender: gender,
      patientName: name,
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
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.bolt), label: Text('Sencillo')),
              ButtonSegment(value: 1, icon: Icon(Icons.badge), label: Text('Detallado')),
            ],
            selected: {_modo},
            onSelectionChanged: (s) => setState(() => _modo = s.first),
          ),
          const SizedBox(height: 12),
          if (_modo == 0) _modoSencillo() else _modoDetallado(),
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
          const SizedBox(height: 28),
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

  Widget _modoSencillo() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
    ]);
  }

  Widget _modoDetallado() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _busqueda,
            decoration: const InputDecoration(labelText: 'Buscar por código o nombre', prefixIcon: Icon(Icons.search)),
            onSubmitted: (_) => _buscar(),
          ),
        ),
        IconButton(onPressed: _buscando ? null : _buscar, icon: const Icon(Icons.search)),
        IconButton(onPressed: _crearPacienteReutilizable, icon: const Icon(Icons.person_add, color: Colors.green)),
      ]),
      const SizedBox(height: 6),
      if (_pacienteSel != null)
        Card(
          color: Colors.green.shade50,
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text('${_pacienteSel!['name'] ?? _pacienteSel!['code'] ?? '—'}'),
            subtitle: Text('Código: ${_pacienteSel!['code'] ?? '—'} · Edad: ${_pacienteSel!['age'] ?? '?'} · ${_pacienteSel!['gender'] ?? '?'}'),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _pacienteSel = null)),
          ),
        ),
      if (_buscando) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
      ..._resultados.take(15).map((e) {
        final m = Map<String, dynamic>.from(e);
        final sel = _pacienteSel != null && _pacienteSel!['id'].toString() == m['id'].toString();
        return ListTile(
          dense: true,
          leading: Icon(Icons.person, color: sel ? Colors.green : Colors.grey),
          title: Text('${m['name'] ?? m['code'] ?? '—'}'),
          subtitle: Text('Código: ${m['code'] ?? '—'} · Edad: ${m['age'] ?? '?'}'),
          onTap: () => setState(() => _pacienteSel = m),
        );
      }),
      if (_resultados.isEmpty && !_buscando)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Busca un paciente existente o crea uno nuevo (➕). Requiere conexión.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ),
    ]);
  }
}
