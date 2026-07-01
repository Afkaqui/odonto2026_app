# odonto2026_app — App Pulsera PPG (Flutter)

App móvil para el estudio de ansiedad en consulta odontológica. Se conecta a la
pulsera PPG por BLE, registra "momentos clave" durante la atención y los guarda
**offline-first** (en el celular), sincronizándolos al backend cuando hay red.

## Secretos (NO van en el código — repo público)
Las claves se inyectan al compilar con `--dart-define`:

| Define | Qué es |
|--------|--------|
| `API_BASE`  | URL del backend (default `https://pulsera.lucyscan.com`) |
| `API_KEY`   | Misma `API_KEY` del backend (header `X-API-Key`) |
| `GEMINI_KEY`| Clave de Google Gemini para el asistente IA (opcional) |

## Compilar el APK
```bash
flutter pub get

# Recomendado: copia env.example.json a env.json (gitignored) y completa las claves,
# luego compila corto:
flutter build apk --release --dart-define-from-file=env.json

# Alternativa sin archivo (mínimo — API_BASE ya tiene default y GEMINI_KEY es opcional):
# flutter build apk --release --dart-define=API_KEY=TU_API_KEY
```
APK en `build/app/outputs/flutter-apk/app-release.apk`.

> Probar en **celular físico** (BLE no funciona en emulador).

## Flujo
Login (odontólogo, tolera offline) → Configurar paciente + pulsera (escaneo BLE
en vivo) → Iniciar consulta → Guardar momentos (fase m1–m6 / estado a1–a5) →
Terminar. Las sesiones se ven en "Sesiones guardadas" con su estado de sync.

## Pulseras
El firmware se anuncia como `Pulsera-XXXXXX` (único por MAC). La app escanea por
SERVICE_UUID, lista las pulseras y conecta a la elegida por su MAC.
