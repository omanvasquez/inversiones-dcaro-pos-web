import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = FirebaseFirestore.instance;

  void _showSaleDetails(Map<String, dynamic> sale) {
    final items = (sale['items'] as List<dynamic>?) ?? [];
    final totalUSD = (sale['totalUSD'] as num?)?.toDouble() ?? 0;
    final totalBs = (sale['totalBs'] as num?)?.toDouble() ?? 0;
    final tasa = (sale['tasaBCV'] as num?)?.toDouble() ?? 0;
    final metodo = sale['metodoPago'] ?? 'otro';
    final fecha = (sale['fecha'] as Timestamp?)?.toDate();
    final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy hh:mm a').format(fecha) : 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Detalle de Venta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(fechaStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const Divider(height: 24),
              Text('Método de pago: ${metodo.toString().replaceAll('_', ' ').toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Tasa aplicada: $tasa Bs/\$', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              const Text('Productos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ...items.map((it) {
                final itemMap = it as Map<String, dynamic>;
                final nombre = itemMap['nombre'] ?? '';
                final cant = itemMap['cantidad'] ?? 1;
                final precio = (itemMap['precioUSD'] as num?)?.toDouble() ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('$cant x $nombre', style: const TextStyle(fontSize: 14)),
                      ),
                      Text('\$${(precio * cant).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total USD:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('\$${totalUSD.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Bs:', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  Text('Bs ${totalBs.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigService>();
    final double tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Ventas'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('sales').orderBy('fecha', descending: true).limit(100).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sales = snapshot.data?.docs ?? [];
          if (sales.isEmpty) {
            return const Center(
              child: Text(
                'No hay ventas registradas',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          double totalAcumuladoUSD = 0;
          for (final s in sales) {
            totalAcumuladoUSD += (s.data()['totalUSD'] as num?)?.toDouble() ?? 0;
          }

          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Registrado (Últimas 100)',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '\$${totalAcumuladoUSD.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                          Text(
                            'Bs ${(totalAcumuladoUSD * tasa).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13, color: AppColors.secondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${sales.length} ventas',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: sales.length,
                  itemBuilder: (context, i) {
                    final data = sales[i].data();
                    final totalUSD = (data['totalUSD'] as num?)?.toDouble() ?? 0;
                    final totalBs = (data['totalBs'] as num?)?.toDouble() ?? 0;
                    final metodo = data['metodoPago'] ?? 'otro';
                    final items = (data['items'] as List<dynamic>?) ?? [];
                    final fecha = (data['fecha'] as Timestamp?)?.toDate();
                    final fechaStr = fecha != null ? DateFormat('dd/MM hh:mm a').format(fecha) : '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(Icons.receipt_long, color: AppColors.primary),
                        ),
                        title: Text(
                          '\$${totalUSD.toStringAsFixed(2)} - Bs ${totalBs.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('$fechaStr • ${items.length} items • $metodo'),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                        onTap: () => _showSaleDetails(data),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
