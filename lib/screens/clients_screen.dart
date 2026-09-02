import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../services/client_service.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _clientService = ClientService();
  String _search = '';

  Future<void> _showClientDialog([Client? client]) async {
    final isEditing = client != null;
    final nombreCtrl = TextEditingController(text: client?.nombre ?? '');
    final cedulaCtrl = TextEditingController(text: client?.cedula ?? '');
    final telefonoCtrl = TextEditingController(text: client?.telefono ?? '');
    final direccionCtrl = TextEditingController(text: client?.direccion ?? '');
    final saldoUSDCtrl = TextEditingController(text: client != null ? client.saldoFiadoUSD.toString() : '0');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Editar Cliente' : 'Nuevo Cliente'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre Completo *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cedulaCtrl,
                  decoration: const InputDecoration(labelText: 'Cédula / RIF'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: direccionCtrl,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: saldoUSDCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Saldo Fiado USD',
                    prefixText: '\$ ',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: Text(isEditing ? 'Actualizar' : 'Guardar'),
          ),
        ],
      ),
    );

    if (result == true) {
      if (!mounted) return;
      final cfg = context.read<ConfigService>();
      final tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;
      final saldoUSD = double.tryParse(saldoUSDCtrl.text.replaceAll(',', '.')) ?? 0;

      if (isEditing) {
        await FirebaseFirestore.instance.collection('clients').doc(client.id).update({
          'nombre': nombreCtrl.text.trim(),
          'cedula': cedulaCtrl.text.trim(),
          'telefono': telefonoCtrl.text.trim(),
          'direccion': direccionCtrl.text.trim(),
          'saldoFiadoUSD': saldoUSD,
          'saldoFiadoBs': saldoUSD * tasa,
        });
      } else {
        final newClient = Client(
          id: '',
          nombre: nombreCtrl.text.trim(),
          cedula: cedulaCtrl.text.trim(),
          telefono: telefonoCtrl.text.trim(),
          direccion: direccionCtrl.text.trim(),
          saldoFiadoUSD: saldoUSD,
          saldoFiadoBs: saldoUSD * tasa,
          creadoEn: Timestamp.now(),
        );
        await _clientService.create(newClient);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Cliente actualizado' : 'Cliente registrado')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigService>();
    final double tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes y Fiado'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClientDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Nuevo Cliente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, cédula o teléfono...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Client>>(
              stream: _clientService.stream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var clients = snapshot.data ?? [];
                if (_search.isNotEmpty) {
                  clients = clients.where((c) =>
                    c.nombre.toLowerCase().contains(_search) ||
                    c.cedula.toLowerCase().contains(_search) ||
                    c.telefono.toLowerCase().contains(_search)
                  ).toList();
                }

                if (clients.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            'No se encontraron clientes',
                            style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Registra clientes para llevar control de cuentas y fiado.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                  itemCount: clients.length,
                  itemBuilder: (context, i) {
                    final c = clients[i];
                    final hasDebt = c.saldoFiadoUSD > 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: hasDebt ? const Color(0xFFFEE2E2) : AppColors.primaryLight,
                          child: Icon(
                            Icons.person,
                            color: hasDebt ? AppColors.danger : AppColors.primary,
                          ),
                        ),
                        title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'CI: ${c.cedula.isNotEmpty ? c.cedula : "N/A"} • Tel: ${c.telefono.isNotEmpty ? c.telefono : "N/A"}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Fiado: \$${c.saldoFiadoUSD.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: hasDebt ? AppColors.danger : AppColors.secondary,
                              ),
                            ),
                            Text(
                              'Bs ${(c.saldoFiadoUSD * tasa).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        onTap: () => _showClientDialog(c),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
