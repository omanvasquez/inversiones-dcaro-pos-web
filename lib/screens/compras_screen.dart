import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});

  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  final _db = FirebaseFirestore.instance;

  Future<void> _agregarCompra() async {
    final descripcionCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final proveedorCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Compra'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descripcionCtrl,
                decoration: const InputDecoration(labelText: 'Descripción / Producto'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proveedorCtrl,
                decoration: const InputDecoration(labelText: 'Proveedor'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto USD',
                  prefixText: '\$ ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == true && descripcionCtrl.text.isNotEmpty && montoCtrl.text.isNotEmpty) {
      final monto = double.tryParse(montoCtrl.text.replaceAll(',', '.')) ?? 0;
      await _db.collection('purchases').add({
        'descripcion': descripcionCtrl.text.trim(),
        'proveedor': proveedorCtrl.text.trim(),
        'montoUSD': monto,
        'fecha': Timestamp.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compra registrada exitosamente')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras de Mercancía'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarCompra,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva Compra', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('purchases').orderBy('fecha', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final purchases = snapshot.data?.docs ?? [];
          if (purchases.isEmpty) {
            return const Center(
              child: Text(
                'No hay compras registradas',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
            itemCount: purchases.length,
            itemBuilder: (context, i) {
              final p = purchases[i].data();
              final desc = p['descripcion'] ?? '';
              final prov = p['proveedor'] ?? '';
              final monto = (p['montoUSD'] as num?)?.toDouble() ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.shopping_cart, color: AppColors.primary),
                  ),
                  title: Text(desc, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(prov.isNotEmpty ? 'Proveedor: $prov' : 'Sin proveedor'),
                  trailing: Text(
                    '\$${monto.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
