import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  final _db = FirebaseFirestore.instance;

  Future<void> _agregarGasto() async {
    final descripcionCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    String categoria = 'Servicios';
    final categorias = ['Servicios', 'Alquiler', 'Sueldos', 'Mantenimiento', 'Transporte', 'Otros'];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registrar Gasto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: categoria,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: categorias
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => categoria = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descripcionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
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
      ),
    );

    if (result == true && descripcionCtrl.text.isNotEmpty && montoCtrl.text.isNotEmpty) {
      final monto = double.tryParse(montoCtrl.text.replaceAll(',', '.')) ?? 0;
      await _db.collection('expenses').add({
        'categoria': categoria,
        'descripcion': descripcionCtrl.text.trim(),
        'montoUSD': monto,
        'fecha': Timestamp.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gasto registrado exitosamente')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos Operativos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarGasto,
        backgroundColor: AppColors.danger,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Gasto', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('expenses').orderBy('fecha', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = snapshot.data?.docs ?? [];
          if (expenses.isEmpty) {
            return const Center(
              child: Text(
                'No hay gastos registrados',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
            itemCount: expenses.length,
            itemBuilder: (context, i) {
              final e = expenses[i].data();
              final cat = e['categoria'] ?? 'Gasto';
              final desc = e['descripcion'] ?? '';
              final monto = (e['montoUSD'] as num?)?.toDouble() ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEE2E2),
                    child: Icon(Icons.receipt_long, color: AppColors.danger),
                  ),
                  title: Text(desc, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Categoría: $cat'),
                  trailing: Text(
                    '-\$${monto.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.danger,
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
