import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_drawer.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _monthlyData = [];
  double _totalAll = 0;

  static const List<String> _monthNames = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final db = context.read<DatabaseService>();
      final data = await db.fetchMonthlyInterest();
      double total = 0;
      for (var d in data) {
        total += (d['total'] as double);
      }
      setState(() {
        _monthlyData = data;
        _totalAll = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ve al Panel Principal para ver las alertas de cobro')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Interes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesion',
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      drawer: AppDrawer(
        currentRoute: '/reports',
        onNotificationsTap: _showNotifications,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: Column(
                children: [
                  // Resumen total
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border(bottom: BorderSide(color: Colors.green.shade100)),
                    ),
                    child: Column(
                      children: [
                        const Text('Interes Total Cobrado', style: TextStyle(fontSize: 15, color: Colors.blueGrey)),
                        const SizedBox(height: 6),
                        Text(
                          'S/. ${_totalAll.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  // Lista por mes
                  Expanded(
                    child: _monthlyData.isEmpty
                        ? const Center(child: Text('No hay registros de interes aun'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _monthlyData.length,
                            itemBuilder: (context, index) {
                              final item = _monthlyData[index];
                              final int month = item['month'] as int;
                              final int year = item['year'] as int;
                              final double total = item['total'] as double;
                              final List<dynamic> payments = item['payments'] ?? [];
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.green.shade100,
                                    child: const Icon(Icons.calendar_month, color: Colors.green),
                                  ),
                                  title: Text(
                                    '${_monthNames[month]} $year',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  trailing: Text(
                                    'S/. ${total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  children: payments.map((p) {
                                    final DateTime date = p['date'];
                                    final double amount = p['amount'];
                                    final String clientName = p['clientName'];
                                    
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.monetization_on, color: Colors.grey, size: 20),
                                      title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Text('${date.day}/${date.month}/${date.year}'),
                                      trailing: Text(
                                        'S/. ${amount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
