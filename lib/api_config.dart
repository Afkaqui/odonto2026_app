// =====================================================================
//  Configuracion del backend (API REST en el VPS).
//  La API key NO se hardcodea (repo publico): se pasa al compilar con
//  --dart-define. Ver README del repo.
//
//  Compilar:
//    flutter build apk --release \
//      --dart-define=API_BASE=https://pulsera.lucyscan.com \
//      --dart-define=API_KEY=<la-misma-API_KEY-del-backend>
// =====================================================================

class ApiConfig {
  // URL base del API. Por defecto el subdominio HTTPS de produccion.
  static const String baseUrl =
      String.fromEnvironment('API_BASE', defaultValue: 'https://pulsera.lucyscan.com');

  // Clave que viaja en el header X-API-Key. Debe coincidir con API_KEY del
  // backend. Se inyecta con --dart-define=API_KEY=...  (vacia => no funcionara).
  static const String apiKey = String.fromEnvironment('API_KEY', defaultValue: '');

  static const String endpointSesiones = "/api/sesiones";
}
