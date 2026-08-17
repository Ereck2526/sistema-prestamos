import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;
  final VoidCallback? onNotificationsTap;
  final int alertCount;

  const AppDrawer({
    super.key,
    required this.currentRoute,
    this.onNotificationsTap,
    this.alertCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Icon(Icons.account_balance_wallet, color: Colors.white, size: 40),
                SizedBox(height: 8),
                Text('Capital Vivo', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text('Sistema de Prestamos', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          _NavItem(icon: Icons.home, label: 'Panel Principal', route: '/home', currentRoute: currentRoute),
          _NavItem(icon: Icons.people, label: 'Clientes', route: '/clients', currentRoute: currentRoute),
          _NavItem(icon: Icons.archive, label: 'Archivo', route: '/paid-loans', currentRoute: currentRoute),
          _NavItem(icon: Icons.bar_chart, label: 'Reportes', route: '/reports', currentRoute: currentRoute),
          const Divider(),
          ListTile(
            leading: Badge(
              isLabelVisible: alertCount > 0,
              label: Text('$alertCount'),
              child: const Icon(Icons.notifications, color: Colors.amber),
            ),
            title: const Text('Notificaciones'),
            onTap: () {
              Navigator.pop(context);
              onNotificationsTap?.call();
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar Sesion', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              context.read<AuthService>().signOut();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;

  const _NavItem({required this.icon, required this.label, required this.route, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final bool isSelected = currentRoute == route;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : null),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.blue : null)),
      tileColor: isSelected ? Colors.blue.shade50 : null,
      onTap: () {
        Navigator.pop(context);
        if (!isSelected) context.go(route);
      },
    );
  }
}
