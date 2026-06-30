// Almacén local de consultas (offline-first), persistido en shared_preferences.
// Expone un ValueNotifier para que las pantallas se actualicen solas.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  static const _key = 'consultations_v1';
  final ValueNotifier<List<LocalConsultation>> consultations = ValueNotifier([]);

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw != null) {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => LocalConsultation.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      consultations.value = list;
    }
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(consultations.value.map((c) => c.toJson()).toList()));
  }

  Future<void> add(LocalConsultation c) async {
    consultations.value = [c, ...consultations.value];
    await _persist();
  }

  // Notifica cambios (p.ej. tras agregar un record o terminar) y persiste.
  Future<void> touch() async {
    consultations.value = List.of(consultations.value);
    await _persist();
  }

  List<LocalConsultation> pendientes() =>
      consultations.value.where((c) => !c.synced && c.endedAt != null).toList();

  int get totalPendientes => pendientes().length;
}
