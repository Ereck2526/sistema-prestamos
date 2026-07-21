import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/database_service.dart';
import '../models/client_model.dart';

class CreateLoanScreen extends StatefulWidget {
  const CreateLoanScreen({super.key});

  @override
  State<CreateLoanScreen> createState() => _CreateLoanScreenState();
}

class _CreateLoanScreenState extends State<CreateLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _interestController = TextEditingController();
  String _frequency = 'Mensual';
  DateTime _startDate = DateTime.now();
  Client? _selectedClient;
  List<Client> _clients = [];
  bool _isLoadingClients = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    try {
      final db = context.read<DatabaseService>();
      final clients = await db.fetchClients();
      setState(() {
        _clients = clients;
        _isLoadingClients = false;
      });
    } catch (e) {
      setState(() => _isLoadingClients = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un cliente')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = context.read<DatabaseService>();
      
      await db.createLoan(
        clientId: _selectedClient!.id,
        originalPrincipal: double.parse(_amountController.text),
        interestRate: double.parse(_interestController.text),
        paymentFrequency: _frequency,
        startDate: _startDate,
      );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Préstamo registrado')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Préstamo')),
      body: _isLoadingClients 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  DropdownButtonFormField<Client>(
                    value: _selectedClient,
                    decoration: const InputDecoration(labelText: 'Cliente'),
                    hint: const Text('Seleccionar cliente...'),
                    items: _clients.map((c) {
                      return DropdownMenuItem<Client>(
                        value: c,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedClient = val),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Monto Prestado', prefixText: '\$'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _interestController,
                    decoration: const InputDecoration(labelText: 'Tasa de Interés', suffixText: '%'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _frequency,
                    decoration: const InputDecoration(labelText: 'Frecuencia de Pago'),
                    items: ['Mensual', 'Quincenal', 'Semanal'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _frequency = val!),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Fecha de Préstamo (Inicio)'),
                    subtitle: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _startDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving ? const CircularProgressIndicator() : const Text('Guardar Préstamo', style: TextStyle(fontSize: 18)),
                    ),
                  )
                ],
              ),
            ),
          ),
    );
  }
}
