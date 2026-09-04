import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigService>();
    final double tasa = cfg.tasaBCV == 0 ? 780 : cfg.tasaBCV;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Operativo'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('sales')
            .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .snapshots(),
        builder: (context, salesSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('expenses')
                .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                .snapshots(),
            builder: (context, expSnapshot) {
              if (salesSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final sales = salesSnapshot.data?.docs ?? [];
              double totalUSD = 0;
              for (final s in sales) {
                totalUSD += (s.data()['totalUSD'] as num?)?.toDouble() ?? 0;
              }
              final double totalBs = totalUSD * tasa;

              final expenses = expSnapshot.data?.docs ?? [];
              double totalGastosUSD = 0;
              for (final e in expenses) {
                totalGastosUSD += (e.data()['montoUSD'] as num?)?.toDouble() ?? 0;
              }
              final double totalGastosBs = totalGastosUSD * tasa;
              final double gananciaNetaUSD = totalUSD - totalGastosUSD;
              final double gananciaNetaBs = gananciaNetaUSD * tasa;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 650;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Resumen del Día',
                        style: TextStyle(
                          fontSize: isNarrow ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildMetricCard(
                            context,
                            title: 'Ventas de Hoy',
                            value: '\$${totalUSD.toStringAsFixed(2)}',
                            subtitle: 'Bs ${totalBs.toStringAsFixed(2)}',
                            icon: Icons.attach_money,
                            color: AppColors.secondary,
                            width: isNarrow ? double.infinity : (constraints.maxWidth - 44) / 2,
                          ),
                          _buildMetricCard(
                            context,
                            title: 'Gastos de Hoy',
                            value: '-\$${totalGastosUSD.toStringAsFixed(2)}',
                            subtitle: 'Bs ${totalGastosBs.toStringAsFixed(2)}',
                            icon: Icons.trending_down,
                            color: AppColors.danger,
                            width: isNarrow ? double.infinity : (constraints.maxWidth - 44) / 2,
                          ),
                          _buildMetricCard(
                            context,
                            title: 'Ganancia Neta de Hoy',
                            value: '\$${gananciaNetaUSD.toStringAsFixed(2)}',
                            subtitle: 'Bs ${gananciaNetaBs.toStringAsFixed(2)}',
                            icon: Icons.account_balance_wallet,
                            color: gananciaNetaUSD >= 0 ? AppColors.secondary : AppColors.danger,
                            width: isNarrow ? double.infinity : (constraints.maxWidth - 44) / 2,
                          ),
                          _buildMetricCard(
                            context,
                            title: 'Transacciones',
                            value: '${sales.length}',
                            subtitle: 'Ventas registradas',
                            icon: Icons.receipt_long,
                            color: AppColors.primary,
                            width: isNarrow ? double.infinity : (constraints.maxWidth - 44) / 2,
                          ),
                          _buildMetricCard(
                            context,
                            title: 'Tasa BCV',
                            value: '$tasa Bs/\$',
                            subtitle: 'Tasa oficial configurada',
                            icon: Icons.currency_exchange,
                            color: AppColors.accent,
                            width: isNarrow ? double.infinity : (constraints.maxWidth - 44) / 2,
                          ),
                        ],
                      ),
                  const SizedBox(height: 24),
                  Text(
                    'Últimas Ventas de Hoy',
                    style: TextStyle(
                      fontSize: isNarrow ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (sales.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No hay ventas registradas el día de hoy',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    )
                  else
                    ...sales.take(10).map((doc) {
                      final data = doc.data();
                      final usd = (data['totalUSD'] as num?)?.toDouble() ?? 0;
                      final bs = (data['totalBs'] as num?)?.toDouble() ?? 0;
                      final metodo = data['metodoPago'] ?? 'efectivo';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.shopping_bag, color: AppColors.primary),
                          ),
                          title: Text(
                            '\$${usd.toStringAsFixed(2)} - Bs ${bs.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Método: $metodo'),
                          trailing: const Icon(Icons.check_circle_outline, color: AppColors.secondary),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      );
    },
  ),
);
}

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
