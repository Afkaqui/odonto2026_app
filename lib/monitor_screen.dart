import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'models.dart';
import 'local_store.dart';
import 'sync_service.dart';
import 'chatbot_screen.dart';

// Monitor de una consulta en curso (OFFLINE-FIRST): conecta la pulsera por BLE,
// muestra el BPM en vivo y guarda "momentos clave" en el almacén LOCAL. Al
// terminar, marca el fin y dispara la sincronización (sube si hay servidor).
class MonitorScreen extends StatefulWidget {
  final LocalConsultation consultation;
  final String? deviceId; // MAC de la pulsera elegida; null = escanear
  const MonitorScreen({super.key, required this.consultation, this.deviceId});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  final String DEVICE_PREFIX = "Pulsera"; // las pulseras se anuncian "Pulsera-XXXXXX"

  BluetoothDevice? connectedDevice;
  List<int> _heartRateData = [];
  String _status = "Desconectado";
  StreamSubscription? _scanSubscription;
  StreamSubscription? _valueSubscription;

  final _momento = TextEditingController(); // etiqueta editable del momento
  String _estado = 'a3';
  bool _terminada = false;

  // Ansiedad: a1 (menor) .. a5 (mayor).
  static const Map<String, String> anxLabels = {
    'a1': 'Muy baja', 'a2': 'Baja', 'a3': 'Media', 'a4': 'Alta', 'a5': 'Muy alta',
  };
  // Sugerencias comunes de momento (el odontólogo puede escribir cualquiera).
  static const List<String> momentoSugerencias = [
    'Tamizaje', 'Limpieza', 'Anestesia', 'Procedimiento', 'Post-atención',
  ];

  // Modo simulado: genera PPG aleatorio sin necesidad de pulsera (para pruebas).
  // Funciona igual offline u online (los records se guardan local y sincronizan).
  bool _simulado = false;
  Timer? _simTimer;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    if (widget.deviceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        connectToDevice(BluetoothDevice.fromId(widget.deviceId!));
      });
    }
  }

  @override
  void dispose() {
    _momento.dispose();
    _simTimer?.cancel();
    _scanSubscription?.cancel();
    _valueSubscription?.cancel();
    connectedDevice?.disconnect();
    super.dispose();
  }

  // Activa/desactiva la generación de datos aleatorios.
  void _setSimulado(bool v) {
    setState(() => _simulado = v);
    _simTimer?.cancel();
    if (v) {
      _status = "Simulando (sin pulsera)";
      _simTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickSim());
    } else {
      _heartRateData = [];
      _status = connectedDevice != null ? "Monitoreando..." : "Desconectado";
    }
    setState(() {});
  }

  // Genera una lectura aleatoria con el mismo formato del ESP: "HH:MM:SS,BPM,SIM".
  void _tickSim() {
    final now = DateTime.now();
    String d2(int n) => n.toString().padLeft(2, '0');
    final hora = "${d2(now.hour)}:${d2(now.minute)}:${d2(now.second)}";
    final bpm = 60 + _rng.nextInt(51); // 60..110
    final payload = "$hora,$bpm,SIM";
    setState(() => _heartRateData = payload.codeUnits);
  }

  void startScanAndConnect() async {
    setState(() => _status = "Escaneando...");
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      setState(() => _status = "Enciende el Bluetooth primero");
      return;
    }
    try {
      await FlutterBluePlus.startScan(withServices: [Guid(SERVICE_UUID)], timeout: const Duration(seconds: 15));
    } catch (e) {
      debugPrint("Error al iniciar escaneo: $e");
    }
    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName.startsWith(DEVICE_PREFIX)) {
          FlutterBluePlus.stopScan();
          connectToDevice(r.device);
          break;
        }
      }
    }, onError: (e) => debugPrint("Error en escaneo: $e"));
  }

  void connectToDevice(BluetoothDevice device) async {
    setState(() => _status = "Conectando...");
    try {
      await device.connect(license: License.free, timeout: const Duration(seconds: 15));
      setState(() { _status = "Conectado"; connectedDevice = device; });
      final services = await device.discoverServices();
      for (var s in services) {
        if (s.uuid.toString() == SERVICE_UUID) {
          for (var c in s.characteristics) {
            if (c.uuid.toString() == CHARACTERISTIC_UUID) setupNotifications(c);
          }
        }
      }
    } catch (e) {
      setState(() => _status = "Error de conexión: $e");
    }
  }

  void setupNotifications(BluetoothCharacteristic c) async {
    await c.setNotifyValue(true);
    _valueSubscription = c.onValueReceived.listen((value) {
      setState(() => _heartRateData = value);
    });
    setState(() => _status = "Monitoreando...");
  }

  String _interpretar(List<int> d) {
    if (d.isEmpty) return "0";
    try { return String.fromCharCodes(d); } catch (_) { return d.toString(); }
  }

  // Guarda un momento clave en el almacén LOCAL (no requiere servidor).
  Future<void> _guardarMomento() async {
    if (_heartRateData.isEmpty) { _msg('⚠️ Esperando datos de la pulsera...'); return; }
    final crudo = _interpretar(_heartRateData); // "HH:MM:SS,BPM,SRC"
    String? horaDisp;
    double? ppg;
    String? fuente;
    final partes = crudo.split(',');
    if (partes.length >= 3) {
      horaDisp = partes[0].trim();
      ppg = double.tryParse(partes[1].trim());
      fuente = partes[2].trim().toUpperCase();
    } else {
      ppg = double.tryParse(crudo.trim());
    }

    final num = widget.consultation.records.length + 1;      // contador de momento
    final label = _momento.text.trim().isEmpty ? 'Momento $num' : _momento.text.trim();

    widget.consultation.records.add(LocalRecord(
      capturedAt: DateTime.now().toIso8601String(),
      ppg: ppg,
      bpmRaw: crudo,
      source: fuente,
      deviceTime: horaDisp,
      phaseNum: num,
      phaseLabel: label,
      status: _estado,
    ));
    await LocalStore.instance.touch();
    setState(() {});
    _msg('✅ Momento #$num "$label" · ansiedad ${anxLabels[_estado]} — guardado');
  }

  Future<void> _terminar() async {
    widget.consultation.endedAt = DateTime.now().toIso8601String();
    await LocalStore.instance.touch();
    setState(() => _terminada = true);
    SyncService.instance.syncNow(); // intenta subir ya (si hay servidor)
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Consulta finalizada'),
        content: Text('Momentos registrados: ${widget.consultation.records.length}\n'
            'Guardada localmente. Se sincronizará cuando haya servidor.'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.popUntil(context, (route) => route.isFirst); },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _msg(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final bpm = _heartRateData.isNotEmpty ? _interpretar(_heartRateData) : "--";
    final n = widget.consultation.records.length;
    return Scaffold(
      appBar: AppBar(
        title: Text("Consulta · ${widget.consultation.patientCode ?? '—'}"),
        backgroundColor: Colors.blueAccent, foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(Icons.monitor_heart, size: 80, color: (_status.contains("Monitoreando") || _simulado) ? Colors.redAccent : Colors.grey),
          Text("Estado: $_status", textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
            child: Column(children: [
              const Text("Lectura pulsera (PPG)"),
              const SizedBox(height: 8),
              Text(bpm, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _simulado ? Colors.amber.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SwitchListTile(
              value: _simulado,
              onChanged: _terminada ? null : _setSimulado,
              secondary: Icon(Icons.science, color: _simulado ? Colors.amber.shade800 : Colors.grey),
              title: const Text('Modo simulado'),
              subtitle: const Text('Genera PPG aleatorio (sin pulsera)'),
            ),
          ),
          const SizedBox(height: 12),
          // --- Momento: contador automático + etiqueta editable ---
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Momento #${widget.consultation.records.length + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _momento,
            decoration: const InputDecoration(
              labelText: 'Nombre del momento (ej. Tamizaje, Limpieza...)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: momentoSugerencias.map((s) => ActionChip(
              label: Text(s),
              onPressed: () => setState(() => _momento.text = s),
            )).toList(),
          ),
          const SizedBox(height: 14),
          // --- Nivel de ansiedad (a1 menor .. a5 mayor) con etiquetas ---
          DropdownButtonFormField<String>(
            value: _estado,
            decoration: const InputDecoration(labelText: 'Nivel de ansiedad', border: OutlineInputBorder()),
            items: anxLabels.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key.toUpperCase()} · ${e.value}')))
                .toList(),
            onChanged: (v) => setState(() => _estado = v ?? 'a3'),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: startScanAndConnect, child: const Text("BUSCAR PULSERA"))),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _terminada ? null : _guardarMomento,
            icon: const Icon(Icons.save),
            label: Text("GUARDAR MOMENTO  ($n)"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _terminada ? null : _terminar,
            icon: const Icon(Icons.stop_circle),
            label: const Text("TERMINAR CONSULTA"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
            icon: const Icon(Icons.smart_toy_outlined),
            label: const Text("ASISTENTE DE ANSIEDAD (IA)"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
        ]),
      ),
    );
  }
}
