import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/client_model.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  bool _isLoading = true;
  List<Client> _clients = [];

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    setState(() => _isLoading = true);
    try {
      final db = context.read<DatabaseService>();
      final clients = await db.fetchClients();
      setState(() {
        _clients = clients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAddClientModal() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo Cliente'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl, 
                  decoration: const InputDecoration(labelText: 'Nombre Completo *'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                Navigator.pop(context);
                try {
                  final db = context.read<DatabaseService>();
                  await db.createClient(
                    name: nameCtrl.text.trim(),
                  );
                  _fetchClients();
                } catch(e) {
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }, 
              child: const Text('Guardar')
            )
          ],
        );
      }
    );
  }

  void _showEditClientModal(Client client) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: client.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Cliente'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl, 
                  decoration: const InputDecoration(labelText: 'Nombre Completo *'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Este campo es obligatorio';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context);
                try {
                  final db = context.read<DatabaseService>();
                  await db.updateClient(
                    id: client.id,
                    name: nameCtrl.text.trim(),
                  );
                  _fetchClients();
                } catch(e) {
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }, 
              child: const Text('Actualizar')
            )
          ],
        );
      }
    );
  }

  void _confirmDeleteClient(Client client) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Cliente', style: TextStyle(color: Colors.red)),
          content: Text('¿Estás SEGURO de que deseas eliminar a ${client.name}? Esta acción borrará TODO su historial, sus préstamos y sus pagos de forma permanente. No se puede deshacer.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final db = context.read<DatabaseService>();
                  await db.deleteClient(client.id);
                  _fetchClients();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente eliminado exitosamente')));
                } catch(e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
                }
              }, 
              child: const Text('Sí, Eliminar Todo')
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
        title: const Text('Directorio de Clientes'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddClientModal)
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _clients.length,
            itemBuilder: (context, index) {
              final c = _clients[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditClientModal(c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () => _confirmDeleteClient(c),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}
