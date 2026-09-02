import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

class ReportesSemanalScreen extends StatelessWidget {
  const ReportesSemanalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigService>();
    final double tasa = cfg.tasaBCV == 0 ? 780 : cfg.tasaBCV;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Semanal (Últimos 7 Días)'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('sales')
            .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sales = snapshot.data?.docs ?? [];
          double totalUSD = 0;
          final Map<String, double> salesByMethod = {};

          for (final doc in sales) {
            final data = doc.data();
            final usd = (data['totalUSD'] as num?)?.toDouble() ?? 0;
            final metodo = (data['metodoPago'] as String?) ?? 'otro';
            totalUSD += usd;
            salesByMethod[metodo] = (salesByMethod[metodo] ?? 0) + usd;
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Ventas - 7 Días',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${totalUSD.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Bs ${(totalUSD * tasa).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${sales.length} transacciones registradas',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Desglose por Método de Pago',
                    style: TextStyle(
                      fontSize: isNarrow ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (salesByMethod.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('No hay ventas registradas en este período',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                    )
                  else
                    ...salesByMethod.entries.map((entry) {
                      final pct = totalUSD > 0 ? (entry.value / totalUSD) * 100 : 0.0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            entry.key.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('${pct.toStringAsFixed(1)}% del total'),
                          trailing: Text(
                            '\$${entry.value.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
