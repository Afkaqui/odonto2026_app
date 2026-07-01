// Modelos locales para el modo offline-first.
// Una consulta y sus records se guardan SIEMPRE en el celular primero; luego
// se sincronizan al backend. 'synced' indica si ya subió al servidor.

class LocalRecord {
  final String capturedAt; // ISO8601
  final double? ppg;
  final String? bpmRaw;
  final String? source;
  final String? deviceTime;
  final String phase;  // m1..m6
  final String status; // a1..a5

  LocalRecord({
    required this.capturedAt,
    this.ppg,
    this.bpmRaw,
    this.source,
    this.deviceTime,
    required this.phase,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'captured_at': capturedAt,
        'ppg': ppg,
        'bpm_raw': bpmRaw,
        'source': source,
        'device_time': deviceTime,
        'phase': phase,
        'status': status,
      };

  factory LocalRecord.fromJson(Map<String, dynamic> j) => LocalRecord(
        capturedAt: j['captured_at'] as String,
        ppg: (j['ppg'] as num?)?.toDouble(),
        bpmRaw: j['bpm_raw'] as String?,
        source: j['source'] as String?,
        deviceTime: j['device_time'] as String?,
        phase: j['phase'] as String,
        status: j['status'] as String,
      );
}

class LocalConsultation {
  final String clientUuid;
  final String? doctorUsername;
  final String? doctorName;
  final String? doctorLastname;
  final String? patientCode;
  final int? patientAge;
  final String? patientGender;
  final String? patientName;
  final String? braceletCode;
  final String startedAt; // ISO8601
  String? endedAt;        // ISO8601 (null = en curso)
  final List<LocalRecord> records;
  bool synced;            // true = ya subió al servidor

  LocalConsultation({
    required this.clientUuid,
    this.doctorUsername,
    this.doctorName,
    this.doctorLastname,
    this.patientCode,
    this.patientAge,
    this.patientGender,
    this.patientName,
    this.braceletCode,
    required this.startedAt,
    this.endedAt,
    List<LocalRecord>? records,
    this.synced = false,
  }) : records = records ?? [];

  // Payload que espera POST /api/sync/consultation
  Map<String, dynamic> toSyncJson() => {
        'client_uuid': clientUuid,
        'started_at': startedAt,
        'ended_at': endedAt,
        'doctor': {'username': doctorUsername},
        'patient': {'code': patientCode, 'age': patientAge, 'gender': patientGender, 'name': patientName},
        'bracelet': {'code': braceletCode},
        'records': records.map((r) => r.toJson()).toList(),
      };

  Map<String, dynamic> toJson() => {
        'client_uuid': clientUuid,
        'doctor_username': doctorUsername,
        'doctor_name': doctorName,
        'doctor_lastname': doctorLastname,
        'patient_code': patientCode,
        'patient_age': patientAge,
        'patient_gender': patientGender,
        'patient_name': patientName,
        'bracelet_code': braceletCode,
        'started_at': startedAt,
        'ended_at': endedAt,
        'records': records.map((r) => r.toJson()).toList(),
        'synced': synced,
      };

  factory LocalConsultation.fromJson(Map<String, dynamic> j) => LocalConsultation(
        clientUuid: j['client_uuid'] as String,
        doctorUsername: j['doctor_username'] as String?,
        doctorName: j['doctor_name'] as String?,
        doctorLastname: j['doctor_lastname'] as String?,
        patientCode: j['patient_code'] as String?,
        patientAge: j['patient_age'] as int?,
        patientGender: j['patient_gender'] as String?,
        patientName: j['patient_name'] as String?,
        braceletCode: j['bracelet_code'] as String?,
        startedAt: j['started_at'] as String,
        endedAt: j['ended_at'] as String?,
        records: (j['records'] as List<dynamic>? ?? [])
            .map((e) => LocalRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        synced: j['synced'] as bool? ?? false,
      );
}
