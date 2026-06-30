import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// Pantalla de escaneo Bluetooth EN VIVO: muestra los dispositivos según
// aparecen, con indicador de progreso. Las pulseras ("Pulsera-XXXXXX") salen
// destacadas arriba. Devuelve el ScanResult elegido al tocar uno.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const String prefijoPulsera = "Pulsera";

  final Map<String, ScanResult> _devices = {};
  bool _scanning = false;
  bool _soloPulseras = true; // por defecto filtra; se puede ver todos
  String? _error;

  StreamSubscription<List<ScanResult>>? _resultsSub;
  StreamSubscription<bool>? _scanStateSub;

  @override
  void initState() {
    super.initState();
    _scanStateSub = FlutterBluePlus.isScanning.listen((s) {
      if (mounted) setState(() => _scanning = s);
    });
    _resultsSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        _devices[r.device.remoteId.str] = r;
      }
      if (mounted) setState(() {});
    });
    _empezar();
  }

  @override
  void dispose() {
    _resultsSub?.cancel();
    _scanStateSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _empezar() async {
    setState(() { _error = null; _devices.clear(); });
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      setState(() => _error = 'El Bluetooth está apagado. Actívalo y reintenta.');
      return;
    }
    try {
      // Sin filtro de servicio: así se VEN todos los dispositivos (el proceso).
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
    } catch (e) {
      setState(() => _error = 'Error al escanear: $e');
    }
  }

  bool _esPulsera(ScanResult r) => r.device.platformName.startsWith(prefijoPulsera);

  @override
  Widget build(BuildContext context) {
    // Ordena: pulseras primero, luego por señal (RSSI) descendente.
    final lista = _devices.values.where((r) {
      if (_soloPulseras) return _esPulsera(r);
      return true;
    }).toList()
      ..sort((a, b) {
        final pa = _esPulsera(a) ? 0 : 1;
        final pb = _esPulsera(b) ? 0 : 1;
        if (pa != pb) return pa - pb;
        return b.rssi.compareTo(a.rssi);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar pulseras'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _soloPulseras ? 'Ver todos los dispositivos' : 'Ver solo pulseras',
            icon: Icon(_soloPulseras ? Icons.filter_alt : Icons.filter_alt_off),
            onPressed: () => setState(() => _soloPulseras = !_soloPulseras),
          ),
        ],
      ),
      body: Column(children: [
        // Barra de estado del escaneo
        Container(
          width: double.infinity,
          color: Colors.blue.shade50,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            if (_scanning)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.bluetooth, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Expanded(child: Text(
              _scanning
                  ? 'Buscando dispositivos...  (${lista.length})'
                  : 'Búsqueda terminada · ${lista.length} dispositivo(s)',
            )),
            Text(_soloPulseras ? 'solo pulseras' : 'todos', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ]),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: lista.isEmpty
              ? Center(child: Text(_scanning ? 'Buscando...' : 'No se encontraron dispositivos.'))
              : ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = lista[i];
                    final pulsera = _esPulsera(r);
                    final nombre = r.device.platformName.isEmpty ? '(sin nombre)' : r.device.platformName;
                    return ListTile(
                      leading: Icon(pulsera ? Icons.watch : Icons.bluetooth,
                          color: pulsera ? Colors.green : Colors.grey),
                      title: Text(nombre, style: TextStyle(fontWeight: pulsera ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text('${r.device.remoteId.str}   ·   señal ${r.rssi} dBm'),
                      trailing: pulsera
                          ? const Chip(label: Text('Pulsera'), backgroundColor: Color(0xFFE8F5E9))
                          : null,
                      onTap: () async {
                        await FlutterBluePlus.stopScan();
                        if (context.mounted) Navigator.pop(context, r);
                      },
                    );
                  },
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? null : _empezar,
        icon: const Icon(Icons.refresh),
        label: const Text('Reescanear'),
      ),
    );
  }
}
