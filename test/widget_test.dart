// Pruebas del modelo de datos local (offline-first).
import 'package:flutter_test/flutter_test.dart';
import 'package:test_base/models.dart';
import 'package:test_base/util.dart';

void main() {
  test('LocalConsultation se serializa y deserializa sin perder datos', () {
    final c = LocalConsultation(
      clientUuid: genClientUuid(),
      patientCode: 'PAC-1',
      patientName: 'Ana',
      startedAt: '2026-07-01T10:00:00Z',
      records: [
        LocalRecord(
          capturedAt: '2026-07-01T10:01:00Z',
          ppg: 80,
          phaseNum: 1,
          phaseLabel: 'Tamizaje',
          status: 'a2',
          source: 'SIM',
        ),
      ],
    );

    final copia = LocalConsultation.fromJson(c.toJson());

    expect(copia.clientUuid, c.clientUuid);
    expect(copia.patientName, 'Ana');
    expect(copia.records.single.phaseNum, 1);
    expect(copia.records.single.phaseLabel, 'Tamizaje');
    expect(copia.synced, isFalse);
  });

  test('El payload de sync envía phase_num, phase_label y status', () {
    final c = LocalConsultation(
      clientUuid: 'c-x',
      startedAt: '2026-07-01T10:00:00Z',
      records: [
        LocalRecord(capturedAt: 't', phaseNum: 2, phaseLabel: 'Limpieza', status: 'a5'),
      ],
    );

    final rec = (c.toSyncJson()['records'] as List).single as Map;

    expect(rec['phase_num'], 2);
    expect(rec['phase_label'], 'Limpieza');
    expect(rec['status'], 'a5');
  });
}
