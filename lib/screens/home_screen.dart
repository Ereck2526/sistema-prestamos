import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeLoans = [];
  double _totalLent = 0;
  double _totalInterest = 0;
  int _alertCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final db = context.read<DatabaseService>();
      final loans = await db.fetchActiveLoansWithDetails();
      double lent = 0;
      for (var loan in loans) {
        lent += (loan['original_principal'] ?? 0).toDouble();
      }
      
      final globalInterest = await db.fetchTotalGlobalInterest();

      int alerts = 0;
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      for (var loan in loans) {
        String? nextStr = loan['next_payment_date'];
        if (nextStr == null) continue;
        DateTime nextDate = DateTime.parse(nextStr);
        if (nextDate.isBefore(today) || nextDate.isAtSameMomentAs(today)) {
          alerts++;
        }
      }

      setState(() {
        _activeLoans = loans;
        _totalLent = lent;
        _totalInterest = globalInterest;
        _alertCount = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _checkNotifications(List<Map<String, dynamic>> loans) {
    List<String> todayAlerts = [];
    List<String> overdueAlerts = [];
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    for (var loan in loans) {
      String? nextStr = loan['next_payment_date'];
      if (nextStr == null) continue;
      DateTime nextDate = DateTime.parse(nextStr);
      String clientName = loan['client'] != null ? loan['client']['name'] : 'Desconocido';
      
      if (nextDate.isBefore(today)) {
        int days = today.difference(nextDate).inDays;
        overdueAlerts.add('El préstamo de $clientName venció hace $days días');
      } else if (nextDate.isAtSameMomentAs(today)) {
        todayAlerts.add('El día de hoy se vence el préstamo de $clientName');
      }
    }

    if (todayAlerts.isEmpty && overdueAlerts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay alertas pendientes')));
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('🔔 Alertas de Cobro', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (overdueAlerts.isNotEmpty) ...[
                  const Text('🔴 ATRASADOS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...overdueAlerts.map((e) => Text('• $e', style: const TextStyle(fontSize: 14))),
                  const SizedBox(height: 16),
                ],
                if (todayAlerts.isNotEmpty) ...[
                  const Text('🟠 PARA HOY', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...todayAlerts.map((e) => Text('• $e', style: const TextStyle(fontSize: 14))),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: const Text('Entendido')
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Principal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive),
            tooltip: 'Archivo (Pagados)',
            onPressed: () => context.push('/paid-loans').then((_) => _fetchData()),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _alertCount > 0,
              label: Text('$_alertCount'),
              child: const Icon(Icons.notifications, color: Colors.amberAccent),
            ),
            tooltip: 'Ver Alertas',
            onPressed: () => _checkNotifications(_activeLoans),
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Directorio de Clientes',
            onPressed: () => context.push('/clients'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchData,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Text('Capital Prestado', style: TextStyle(fontSize: 14, color: Colors.blueGrey)),
                          const SizedBox(height: 4),
                          Text('\$${_totalLent.toStringAsFixed(2)}', 
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)
                          ),
                        ],
                      ),
                      Container(width: 1, height: 40, color: Colors.blue.shade200),
                      Column(
                        children: [
                          const Text('Interés Generado', style: TextStyle(fontSize: 14, color: Colors.blueGrey)),
                          const SizedBox(height: 4),
                          Text('\$${_totalInterest.toStringAsFixed(2)}', 
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _activeLoans.isEmpty
                      ? const Center(child: Text('No hay préstamos activos'))
                      : ListView.builder(
                          itemCount: _activeLoans.length,
                          itemBuilder: (context, index) {
                            final loan = _activeLoans[index];
                            final client = loan['client'];
                            
                            double original = (loan['original_principal'] ?? 0).toDouble();
                            double paid = 0;
                            if (loan['payments'] != null) {
                              for (var p in loan['payments']) {
                                paid += (p['principal_paid'] ?? 0).toDouble();
                              }
                            }
                            double remaining = original - paid;
                            
                            String? nextStr = loan['next_payment_date'];
                            Color statusColor = Colors.grey;
                            String dateText = 'Sin fecha';
                            if (nextStr != null) {
                              DateTime nextDate = DateTime.parse(nextStr);
                              DateTime now = DateTime.now();
                              DateTime today = DateTime(now.year, now.month, now.day);
                              dateText = 'Cobro: ${nextDate.day}/${nextDate.month}/${nextDate.year}';
                              if (nextDate.isBefore(today)) {
                                statusColor = Colors.red;
                              } else if (nextDate.isAtSameMomentAs(today)) {
                                statusColor = Colors.orange;
                              } else {
                                statusColor = Colors.green;
                              }
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: statusColor, child: const Icon(Icons.person, color: Colors.white)),
                                title: Text(client != null ? client['name'] : 'Desconocido', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Deuda: \$${remaining.toStringAsFixed(2)}\n$dateText'),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {
                                  context.push('/loan/${loan['id']}', extra: loan).then((_) => _fetchData());
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-loan').then((_) => _fetchData()),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Préstamo'),
      ),
    );
  }
}
