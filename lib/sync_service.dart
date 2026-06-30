// Servicio de sincronización automática: cada cierto tiempo revisa si el
// servidor está disponible y sube las consultas pendientes (terminadas y no
// sincronizadas). Marca 'synced=true' al subir, lo que la UI refleja sola.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'local_store.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  Timer? _timer;
  final ValueNotifier<bool> online = ValueNotifier(false);
  final ValueNotifier<bool> sincronizando = ValueNotifier(false);

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) => syncNow());
    syncNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> syncNow() async {
    if (sincronizando.value) return;
    sincronizando.value = true;
    try {
      final ok = await ApiService.health();
      online.value = ok;
      if (!ok) return;

      final pendientes = LocalStore.instance.pendientes();
      for (final c in pendientes) {
        try {
          await ApiService.syncConsultation(c.toSyncJson());
          c.synced = true;
          await LocalStore.instance.touch();
        } catch (_) {
          // si falla una, cortamos y reintentamos en el próximo ciclo
          break;
        }
      }
    } finally {
      sincronizando.value = false;
    }
  }
}
