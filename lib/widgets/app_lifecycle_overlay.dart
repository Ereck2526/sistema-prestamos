import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class AppLifecycleOverlay extends StatefulWidget {
  final Widget child;
  const AppLifecycleOverlay({super.key, required this.child});

  @override
  State<AppLifecycleOverlay> createState() => _AppLifecycleOverlayState();
}

class _AppLifecycleOverlayState extends State<AppLifecycleOverlay> with WidgetsBindingObserver {
  DateTime? _backgroundTime;
  bool _isLocked = false;
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Validar al iniciar si la sesión está activa para bloquearla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<AuthService>().isAuthenticated) {
        _lockAndAuthenticate();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.inactive) {
      _backgroundTime ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundTime != null) {
        final diff = DateTime.now().difference(_backgroundTime!);
        if (diff.inMinutes >= 3) {
          if (context.read<AuthService>().isAuthenticated) {
            _lockAndAuthenticate();
          }
        }
        _backgroundTime = null;
      }
    }
  }

  Future<void> _lockAndAuthenticate() async {
    if (_isAuthenticating) return;
    
    setState(() {
      _isLocked = true;
      _isAuthenticating = true;
    });

    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        context.read<AuthService>().signOut();
        setState(() {
          _isLocked = false;
        });
        return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Desbloquea la aplicación para continuar',
      );

      if (didAuthenticate) {
        setState(() {
          _isLocked = false;
        });
      } else {
        context.read<AuthService>().signOut();
        setState(() {
          _isLocked = false;
        });
      }
    } on PlatformException catch (_) {
      context.read<AuthService>().signOut();
      setState(() {
        _isLocked = false;
      });
    } finally {
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthService>().isAuthenticated;
    
    return Stack(
      children: [
        widget.child,
        if (isAuthenticated && _isLocked)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).primaryColor,
              child: const SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 80, color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        'Sesión Protegida',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Ingresa tu huella o PIN\npara acceder a la bóveda.',
                        style: TextStyle(color: Colors.white70, fontSize: 16, decoration: TextDecoration.none),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
