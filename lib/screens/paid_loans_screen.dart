import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';

class PaidLoansScreen extends StatefulWidget {
  const PaidLoansScreen({super.key});

  @override
  State<PaidLoansScreen> createState() => _PaidLoansScreenState();
}

class _PaidLoansScreenState extends State<PaidLoansScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _paidLoans = [];
  double _totalProfit = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final db = context.read<DatabaseService>();
      final loans = await db.fetchPaidLoansWithDetails();

      double profit = 0;
      for (var loan in loans) {
        final payments = List<Map<String, dynamic>>.from(loan['payments'] ?? []);
        for (var payment in payments) {
          profit += (payment['interest_paid'] ?? 0).toDouble();
        }
      }

      setState(() {
        _paidLoans = loans;
        _totalProfit = profit;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivo de Préstamos Pagados'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: Colors.green.shade50,
                child: Column(
                  children: [
                    const Text('Total Ganado (Intereses)', style: TextStyle(fontSize: 16)),
                    Text('\$${_totalProfit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
              Expanded(
                child: _paidLoans.isEmpty 
                  ? const Center(child: Text('No hay préstamos finalizados aún'))
                  : ListView.builder(
                      itemCount: _paidLoans.length,
                      itemBuilder: (context, index) {
                        final loan = _paidLoans[index];
                        final clientName = loan['client'] != null ? loan['client']['name'] : 'Desconocido';
                        double originalPrincipal = (loan['original_principal'] ?? 0).toDouble();
                        
                        double loanInterest = 0;
                        final payments = List<Map<String, dynamic>>.from(loan['payments'] ?? []);
                        for (var payment in payments) {
                          loanInterest += (payment['interest_paid'] ?? 0).toDouble();
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(Icons.check, color: Colors.white),
                            ),
                            title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Préstamo: \$${originalPrincipal.toStringAsFixed(2)} | Ganancia: \$${loanInterest.toStringAsFixed(2)}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await context.push('/loan/${loan['id']}', extra: loan);
                              // Refresh on return in case they deleted a payment and it's active again
                              _fetchData();
                            },
                          ),
                        );
                      }
                    ),
              )
            ],
          ),
    );
  }
}
