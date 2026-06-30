import 'dart:async';
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

  String _phase = 'm1';
  String _estado = 'a3';
  bool _terminada = false;

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
    _scanSubscription?.cancel();
    _valueSubscription?.cancel();
    connectedDevice?.disconnect();
    super.dispose();
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

    widget.consultation.records.add(LocalRecord(
      capturedAt: DateTime.now().toIso8601String(),
      ppg: ppg,
      bpmRaw: crudo,
      source: fuente,
      deviceTime: horaDisp,
      phase: _phase,
      status: _estado,
    ));
    await LocalStore.instance.touch();
    setState(() {});
    _msg('✅ Momento guardado ($_phase / $_estado) — local');
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
          Icon(Icons.monitor_heart, size: 80, color: _status.contains("Monitoreando") ? Colors.redAccent : Colors.grey),
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
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: _phase,
              decoration: const InputDecoration(labelText: 'Momento (fase)', border: OutlineInputBorder()),
              items: const ['m1','m2','m3','m4','m5','m6'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _phase = v ?? 'm1'),
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(
              value: _estado,
              decoration: const InputDecoration(labelText: 'Estado (ansiedad)', border: OutlineInputBorder()),
              items: const ['a1','a2','a3','a4','a5'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _estado = v ?? 'a3'),
            )),
          ]),
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
