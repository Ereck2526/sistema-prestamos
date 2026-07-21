import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/payment_model.dart';

class LoanDetailScreen extends StatefulWidget {
  final Map<String, dynamic> loan;
  const LoanDetailScreen({super.key, required this.loan});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  List<Payment> _ledger = [];
  bool _isLoading = true;
  late double _remainingPrincipal;
  late double _originalPrincipal;
  late double _interestRate;

  @override
  void initState() {
    super.initState();
    _originalPrincipal = (widget.loan['original_principal'] ?? 0).toDouble();
    _interestRate = (widget.loan['interest_rate'] ?? 0).toDouble();
    _fetchLedger();
  }

  Future<void> _fetchLedger() async {
    setState(() => _isLoading = true);
    try {
      final db = context.read<DatabaseService>();
      final ledger = await db.fetchLoanLedger(widget.loan['id']);
      
      double paid = 0;
      for(var p in ledger) {
        paid += p.principalPaid;
      }
      
      setState(() {
        _ledger = ledger;
        _remainingPrincipal = _originalPrincipal - paid;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showRegisterPaymentModal() {
    final principalController = TextEditingController(text: '0');
    double suggestedInterest = _remainingPrincipal * (_interestRate / 100);
    final interestController = TextEditingController(text: suggestedInterest.toStringAsFixed(2));
    final notesController = TextEditingController();
    DateTime paymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text('Registrar Pago'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: interestController,
                      decoration: const InputDecoration(labelText: 'Abono a Interés (Sugerido)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: principalController,
                      decoration: const InputDecoration(labelText: 'Abono a Capital'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notas / Detalles'),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Fecha de Pago', style: TextStyle(fontSize: 14)),
                      subtitle: Text('${paymentDate.day}/${paymentDate.month}/${paymentDate.year}'),
                      trailing: const Icon(Icons.calendar_today, size: 20),
                      contentPadding: EdgeInsets.zero,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: paymentDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setStateModal(() => paymentDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    double? p = double.tryParse(principalController.text);
                    double? i = double.tryParse(interestController.text);
                    
                    if (p == null || p < 0 || i == null || i < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Montos inválidos')));
                      return;
                    }
                    if (p > _remainingPrincipal) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('El abono a capital no puede ser mayor a \$${_remainingPrincipal.toStringAsFixed(2)}')));
                      return;
                    }

                    Navigator.pop(dialogContext);
                    try {
                      final db = context.read<DatabaseService>();
                      await db.registerPayment(
                        loanId: widget.loan['id'],
                        principalPaid: double.parse(principalController.text),
                        interestPaid: double.parse(interestController.text),
                        notes: notesController.text.isNotEmpty ? notesController.text : null,
                        paymentDate: paymentDate,
                      );
                      _fetchLedger();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago guardado')));
                    } catch(e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }, 
                  child: const Text('Guardar Pago')
                )
              ],
            );
          }
        );
      }
    );
  }

  void _confirmDelete(String paymentId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar Pago'),
          content: const Text('¿Estás seguro de que deseas eliminar este pago? Esta acción recalculará los saldos y fechas.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final db = context.read<DatabaseService>();
                  await db.deletePayment(paymentId, widget.loan['id']);
                  _fetchLedger();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago eliminado')));
                } catch(e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }, 
              child: const Text('Eliminar')
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.loan['client']['name'])),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: Colors.blue.shade50,
                child: Column(
                  children: [
                    const Text('Saldo Restante a Cobrar', style: TextStyle(fontSize: 16)),
                    Text('\$${_remainingPrincipal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 16),
                    Text('Préstamo Original: \$${_originalPrincipal.toStringAsFixed(2)}'),
                    Text('Tasa: $_interestRate% ${widget.loan['payment_frequency']}'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _remainingPrincipal > 0 ? _showRegisterPaymentModal : null,
                        icon: Icon(_remainingPrincipal > 0 ? Icons.attach_money : Icons.check_circle),
                        label: Text(_remainingPrincipal > 0 ? 'REGISTRAR PAGO' : 'PRÉSTAMO PAGADO', style: const TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _remainingPrincipal > 0 ? Colors.blue : Colors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.green,
                          disabledForegroundColor: Colors.white,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(alignment: Alignment.centerLeft, child: Text('Historial de Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _ledger.length,
                  itemBuilder: (context, index) {
                    final p = _ledger[index];
                    String cleanNotes = p.notes?.replaceAll('[PERIODO_COMPLETO]', '').trim() ?? '';
                    String noteText = cleanNotes.isNotEmpty ? ' - $cleanNotes' : '';
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.arrow_downward, color: Colors.white)),
                      title: Text('Abonó Cap: \$${p.principalPaid} | Int: \$${p.interestPaid}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${p.paymentDate.day}/${p.paymentDate.month}/${p.paymentDate.year}$noteText'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Eliminar Pago',
                        onPressed: () => _confirmDelete(p.id),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
    );
  }
}
