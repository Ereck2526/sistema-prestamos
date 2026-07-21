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
  String? _selectedClientFilter; // null = todos

  List<Map<String, dynamic>> get _filteredLoans {
    if (_selectedClientFilter == null) return _activeLoans;
    return _activeLoans.where((loan) {
      final client = loan['client'];
      return client != null && client['name'] == _selectedClientFilter;
    }).toList();
  }

  List<String> get _clientNames {
    final names = _activeLoans
        .map((loan) => loan['client']?['name'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    names.sort();
    return names;
  }

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

  void _showEditLoanModal(Map<String, dynamic> loan) {
    final formKey = GlobalKey<FormState>();
    final principalCtrl = TextEditingController(text: loan['original_principal'].toString());
    final interestCtrl = TextEditingController(text: loan['interest_rate'].toString());
    
    DateTime startDate = loan['created_at'] != null ? DateTime.parse(loan['created_at']) : DateTime.now();
    DateTime nextDate = loan['next_payment_date'] != null ? DateTime.parse(loan['next_payment_date']) : DateTime.now();
    String selectedFrequency = loan['payment_frequency'] ?? 'Mensual';
    final String originalFrequency = loan['payment_frequency'] ?? 'Mensual';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text('Editar Préstamo'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: principalCtrl,
                        decoration: const InputDecoration(labelText: 'Capital Inicial'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Requerido';
                          if (double.tryParse(value) == null) return 'Número inválido';
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: interestCtrl,
                        decoration: const InputDecoration(labelText: 'Tasa de Interés (%)'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Requerido';
                          if (double.tryParse(value) == null) return 'Número inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Frecuencia de Pago',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedFrequency,
                            isDense: true,
                            items: ['Mensual', 'Quincenal', 'Semanal'].map((String val) {
                              return DropdownMenuItem<String>(value: val, child: Text(val));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setStateModal(() => selectedFrequency = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Fecha de Préstamo (Inicio)', style: TextStyle(fontSize: 14)),
                        subtitle: Text('${startDate.day}/${startDate.month}/${startDate.year}'),
                        trailing: const Icon(Icons.calendar_today, size: 20),
                        contentPadding: EdgeInsets.zero,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setStateModal(() => startDate = picked);
                          }
                        },
                      ),
                      ListTile(
                        title: const Text('Fecha de Próximo Cobro', style: TextStyle(fontSize: 14)),
                        subtitle: Text('${nextDate.day}/${nextDate.month}/${nextDate.year}'),
                        trailing: const Icon(Icons.calendar_today, size: 20),
                        contentPadding: EdgeInsets.zero,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: nextDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setStateModal(() => nextDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    try {
                      final db = context.read<DatabaseService>();
                      final bool freqChanged = selectedFrequency != originalFrequency;
                      await db.updateLoan(
                        id: loan['id'],
                        originalPrincipal: double.parse(principalCtrl.text),
                        interestRate: double.parse(interestCtrl.text),
                        startDate: startDate,
                        nextDate: freqChanged ? null : nextDate,
                        paymentFrequency: freqChanged ? selectedFrequency : null,
                      );
                      _fetchData();
                    } catch(e) {
                      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          }
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por cliente',
                      prefixIcon: Icon(Icons.filter_list),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedClientFilter,
                        isDense: true,
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Todos los clientes')),
                          ..._clientNames.map((name) => DropdownMenuItem<String?>(value: name, child: Text(name))),
                        ],
                        onChanged: (val) => setState(() => _selectedClientFilter = val),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredLoans.isEmpty
                      ? Center(
                          child: Text(
                            _selectedClientFilter != null
                                ? 'No hay préstamos para este cliente'
                                : 'No hay préstamos activos',
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredLoans.length,
                          itemBuilder: (context, index) {
                            final loan = _filteredLoans[index];
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showEditLoanModal(loan),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 16),
                                  ],
                                ),
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

