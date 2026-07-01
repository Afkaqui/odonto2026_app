// =====================================================================
//  Capa de acceso al backend (API REST en el VPS).
//  Entorno de laboratorio: validaciones ligeras.
// =====================================================================
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-API-Key': ApiConfig.apiKey,
      };

  static Uri _u(String path) => Uri.parse(ApiConfig.baseUrl + path);

  static dynamic _decode(http.Response r) {
    final body = r.body.isEmpty ? '{}' : r.body;
    final j = jsonDecode(body);
    if (r.statusCode >= 200 && r.statusCode < 300) return j;
    throw Exception(j is Map && j['error'] != null ? j['error'] : 'HTTP ${r.statusCode}');
  }

  // ---------------- Disponibilidad / Sync ----------------
  // Devuelve true si el backend responde (para decidir cuándo sincronizar).
  static Future<bool> health() async {
    try {
      final r = await http
          .get(_u('/health'))
          .timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Sube una sesión completa (consulta + records). Idempotente por client_uuid.
  static Future<void> syncConsultation(Map<String, dynamic> payload) async {
    final r = await http
        .post(_u('/api/sync/consultation'), headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 20));
    _decode(r);
  }

  // ---------------- Doctor ----------------
  static Future<Map<String, dynamic>> loginDoctor(String username, String password) async {
    final r = await http.post(_u('/api/doctors/login'),
        headers: _headers, body: jsonEncode({'username': username, 'password': password}));
    return Map<String, dynamic>.from(_decode(r)['doctor']);
  }

  static Future<Map<String, dynamic>> registerDoctor(
      String name, String lastname, String username, String password) async {
    final r = await http.post(_u('/api/doctors'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'lastname': lastname,
          'username': username,
          'password': password,
        }));
    return Map<String, dynamic>.from(_decode(r)['doctor']);
  }

  // ---------------- Pacientes ----------------
  // Lista (o busca con q) pacientes reutilizables del backend.
  static Future<List<dynamic>> listPatients({String? q}) async {
    final path = (q != null && q.trim().isNotEmpty)
        ? '/api/patients?q=${Uri.encodeQueryComponent(q.trim())}'
        : '/api/patients';
    final r = await http.get(_u(path), headers: _headers);
    return _decode(r)['patients'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createPatient(
      String code, int? age, String? gender, {String? name}) async {
    final r = await http.post(_u('/api/patients'),
        headers: _headers,
        body: jsonEncode({'code': code, 'age': age, 'gender': gender, 'name': name}));
    return Map<String, dynamic>.from(_decode(r)['patient']);
  }

  // ---------------- Pulseras ----------------
  static Future<List<dynamic>> listBracelets() async {
    final r = await http.get(_u('/api/bracelets'), headers: _headers);
    return _decode(r)['bracelets'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createBracelet(String code, String type) async {
    final r = await http.post(_u('/api/bracelets'),
        headers: _headers, body: jsonEncode({'code': code, 'type': type}));
    return Map<String, dynamic>.from(_decode(r)['bracelet']);
  }

  // Auto-asignación: busca la pulsera por su code (nombre BLE único) y, si no
  // existe, la crea. Así una pulsera nueva se registra sola al detectarla.
  static Future<Map<String, dynamic>> findOrCreateBracelet(String code) async {
    final lista = await listBracelets();
    final existente = lista.where((e) => e['code']?.toString() == code).toList();
    if (existente.isNotEmpty) return Map<String, dynamic>.from(existente.first);
    return createBracelet(code, 'ppg');
  }

  // ---------------- Consultas ----------------
  static Future<Map<String, dynamic>> startConsultation(
      int patientId, int doctorId, int? braceletId) async {
    final r = await http.post(_u('/api/consultations'),
        headers: _headers,
        body: jsonEncode({
          'patient_id': patientId,
          'doctor_id': doctorId,
          'bracelet_id': braceletId,
        }));
    return Map<String, dynamic>.from(_decode(r)['consultation']);
  }

  static Future<Map<String, dynamic>> endConsultation(int consultationId) async {
    final r = await http.patch(_u('/api/consultations/$consultationId/end'), headers: _headers);
    return Map<String, dynamic>.from(_decode(r)['consultation']);
  }

  // Nota: el envío de records va por syncConsultation (offline-first), no hay
  // createRecord directo.
}
