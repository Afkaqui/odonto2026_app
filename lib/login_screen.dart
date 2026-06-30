import 'package:flutter/material.dart';
import 'api_service.dart';
import 'setup_screen.dart';
import 'sessions_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _cargando = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final doctor = await ApiService.loginDoctor(_user.text.trim(), _pass.text);
      if (!mounted) return;
      _irASetup(doctor);
    } catch (e) {
      // ¿Es por falta de conexión? Entonces ofrecer modo offline.
      final online = await ApiService.health();
      if (!online) {
        if (mounted) _ofrecerOffline();
      } else {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _irASetup(Map<String, dynamic> doctor) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SetupScreen(doctor: doctor)));
  }

  // Modo offline: continúa con solo el usuario; la sesión se sincroniza luego.
  void _ofrecerOffline() {
    if (_user.text.trim().isEmpty) {
      setState(() => _error = 'Sin conexión. Escribe tu usuario para continuar offline.');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sin conexión al servidor'),
        content: const Text(
            'Puedes trabajar en modo OFFLINE: las atenciones se guardan en el '
            'celular y se sincronizan solas cuando el servidor vuelva.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _irASetup({'id': null, 'username': _user.text.trim(), 'name': _user.text.trim(), 'lastname': ''});
            },
            child: const Text('Continuar offline'),
          ),
        ],
      ),
    );
  }

  Future<void> _registrar() async {
    final creado = await showDialog<bool>(context: context, builder: (_) => const _RegistroDoctorDialog());
    if (creado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odontólogo registrado. Ahora inicia sesión.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso Odontólogo'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sesiones guardadas',
            icon: const Icon(Icons.folder_shared),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionsScreen())),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.medical_services, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              TextField(controller: _user, decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder())),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _login,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: _cargando ? const CircularProgressIndicator() : const Text('INGRESAR'),
                ),
              ),
              TextButton(onPressed: _cargando ? null : _registrar, child: const Text('Registrar nuevo odontólogo')),
              TextButton(onPressed: _cargando ? null : _ofrecerOffline, child: const Text('Entrar en modo offline')),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistroDoctorDialog extends StatefulWidget {
  const _RegistroDoctorDialog();
  @override
  State<_RegistroDoctorDialog> createState() => _RegistroDoctorDialogState();
}

class _RegistroDoctorDialogState extends State<_RegistroDoctorDialog> {
  final _n = TextEditingController();
  final _a = TextEditingController();
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _cargando = false;
  String? _error;

  Future<void> _guardar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      await ApiService.registerDoctor(_n.text.trim(), _a.text.trim(), _u.text.trim(), _p.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo odontólogo'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _n, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: _a, decoration: const InputDecoration(labelText: 'Apellido')),
          TextField(controller: _u, decoration: const InputDecoration(labelText: 'Usuario')),
          TextField(controller: _p, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _cargando ? null : _guardar, child: const Text('Crear')),
      ],
    );
  }
}
