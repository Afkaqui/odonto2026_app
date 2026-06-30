import 'package:flutter/material.dart';
import 'local_store.dart';
import 'sync_service.dart';
import 'models.dart';

// Lista de sesiones guardadas en el celular con su estado de sincronización.
// El estado se actualiza solo (ValueListenableBuilder) cuando el sync sube algo.
class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesiones guardadas'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          // Indicador de conexión al servidor.
          ValueListenableBuilder<bool>(
            valueListenable: SyncService.instance.online,
            builder: (_, online, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Icon(online ? Icons.cloud_done : Icons.cloud_off, size: 20),
                const SizedBox(width: 4),
                Text(online ? 'En línea' : 'Sin conexión', style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<LocalConsultation>>(
        valueListenable: LocalStore.instance.consultations,
        builder: (_, lista, __) {
          if (lista.isEmpty) {
            return const Center(child: Text('No hay sesiones guardadas todavía.'));
          }
          final pendientes = lista.where((c) => !c.synced && c.endedAt != null).length;
          return Column(children: [
            Container(
              width: double.infinity,
              color: pendientes > 0 ? Colors.orange.shade50 : Colors.green.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: Text(
                  pendientes > 0 ? '$pendientes sesión(es) pendiente(s) de subir' : 'Todo sincronizado',
                  style: TextStyle(color: pendientes > 0 ? Colors.orange.shade900 : Colors.green.shade900),
                )),
                ValueListenableBuilder<bool>(
                  valueListenable: SyncService.instance.sincronizando,
                  builder: (_, sinc, __) => ElevatedButton.icon(
                    onPressed: sinc ? null : () => SyncService.instance.syncNow(),
                    icon: sinc
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync),
                    label: const Text('Sincronizar'),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: lista.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = lista[i];
                  final enCurso = c.endedAt == null;
                  return ListTile(
                    leading: Icon(
                      enCurso ? Icons.timelapse : (c.synced ? Icons.cloud_done : Icons.cloud_upload),
                      color: enCurso ? Colors.blue : (c.synced ? Colors.green : Colors.orange),
                    ),
                    title: Text('Paciente: ${c.patientCode ?? "—"}  ·  ${c.records.length} momento(s)'),
                    subtitle: Text(
                      'Inicio: ${_fmt(c.startedAt)}\n'
                      'Pulsera: ${c.braceletCode ?? "—"}  ·  '
                      '${enCurso ? "EN CURSO" : (c.synced ? "Sincronizada" : "Pendiente de subir")}',
                    ),
                    isThreeLine: true,
                    trailing: _badge(enCurso, c.synced),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _badge(bool enCurso, bool synced) {
    if (enCurso) return const Chip(label: Text('En curso'), backgroundColor: Color(0xFFE3F2FD));
    return synced
        ? const Chip(label: Text('Subida'), backgroundColor: Color(0xFFE8F5E9))
        : const Chip(label: Text('Pendiente'), backgroundColor: Color(0xFFFFF3E0));
  }

  String _fmt(String iso) {
    try {
      return DateTime.parse(iso).toLocal().toString().substring(0, 19);
    } catch (_) {
      return iso;
    }
  }
}
