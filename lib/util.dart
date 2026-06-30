import 'dart:math';

// UUID simple (suficiente para deduplicar sesiones; no criptográfico).
String genClientUuid() {
  final r = Random();
  final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
  final rand = List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join();
  return 'c-$ts-$rand';
}
