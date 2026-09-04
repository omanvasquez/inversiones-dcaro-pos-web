import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';

class ReportWidgets {
  static const Map<String, String> metodoNombres = {
    'efectivo_dolar': 'Efectivo Dólar (\$)',
    'efectivo_bolivar': 'Efectivo Bolívar (Bs)',
    'punto_venta': 'Punto de Venta (Bs)',
    'pago_movil': 'Pago Móvil (Bs)',
    'fiado': 'Fiado / Por Cobrar',
  };

  static const Map<String, IconData> metodoIconos = {
    'efectivo_dolar': Icons.attach_money,
    'efectivo_bolivar': Icons.payments_outlined,
    'punto_venta': Icons.credit_card,
    'pago_movil': Icons.smartphone,
    'fiado': Icons.assignment_late_outlined,
  };

  static Widget buildFinancialCards(BuildContext context, ReportData data, double tasa, {bool isNarrow = false}) {
    final cardWidth = isNarrow ? double.infinity : 220.0;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildMetric(
          title: 'Total Ventas',
          usdValue: data.totalVentasUSD,
          bsValue: data.totalVentasBs,
          subtitle: '${data.totalTransacciones} transacciones',
          icon: Icons.point_of_sale,
          iconColor: AppColors.primary,
          width: cardWidth,
        ),
        _buildMetric(
          title: 'Ganancia Bruta',
          usdValue: data.gananciaBrutaUSD,
          bsValue: data.gananciaBrutaBs,
          subtitle: 'Ventas menos costos',
          icon: Icons.trending_up,
          iconColor: AppColors.secondary,
          width: cardWidth,
        ),
        _buildMetric(
          title: 'Gastos Operativos',
          usdValue: data.totalGastosUSD,
          bsValue: data.totalGastosBs,
          subtitle: '${data.gastos.length} gastos registrados',
          icon: Icons.trending_down,
          iconColor: AppColors.danger,
          width: cardWidth,
        ),
        _buildMetric(
          title: 'Compras Mercancía',
          usdValue: data.totalComprasUSD,
          bsValue: data.totalComprasBs,
          subtitle: '${data.compras.length} compras registradas',
          icon: Icons.shopping_bag_outlined,
          iconColor: AppColors.warning,
          width: cardWidth,
        ),
        _buildMetric(
          title: 'Ganancia Neta',
          usdValue: data.gananciaNetaUSD,
          bsValue: data.gananciaNetaBs,
          subtitle: 'Bruta menos gastos',
          icon: Icons.account_balance_wallet,
          iconColor: data.gananciaNetaUSD >= 0 ? AppColors.secondary : AppColors.danger,
          highlight: true,
          width: cardWidth,
        ),
      ],
    );
  }

  static Widget _buildMetric({
    required String title,
    required double usdValue,
    required double bsValue,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double width,
    bool highlight = false,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        color: highlight ? iconColor.withValues(alpha: 0.08) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: highlight ? iconColor.withValues(alpha: 0.4) : AppColors.border,
            width: highlight ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Icon(icon, color: iconColor, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '\$${usdValue.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: highlight ? iconColor : AppColors.primaryDark,
                ),
              ),
              Text(
                'Bs ${bsValue.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: highlight ? iconColor.withValues(alpha: 0.8) : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildPaymentMethods(ReportData data, double tasa) {
    if (data.totalVentasUSD <= 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Sin ventas registradas para desglosar métodos de pago.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: metodoNombres.entries.map((entry) {
            final metodoKey = entry.key;
            final label = entry.value;
            final amount = data.ventasPorMetodo[metodoKey] ?? 0.0;
            final pct = data.totalVentasUSD > 0 ? (amount / data.totalVentasUSD) : 0.0;
            final icon = metodoIconos[metodoKey] ?? Icons.payment;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Bs ${(amount * tasa).toStringAsFixed(2)} (${(pct * 100).toStringAsFixed(1)}%)',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        amount > 0 ? AppColors.primary : Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  static Widget buildProductsSold(List<SoldProductItem> productos, double tasa) {
    if (productos.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No se registraron productos vendidos en este período.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: productos.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final prod = productos[index];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                '${index + 1}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            title: Text(
              prod.nombre,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text('${prod.cantidad} ${prod.cantidad == 1 ? "unidad vendida" : "unidades vendidas"}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${prod.totalUSD.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                ),
                Text(
                  'Bs ${(prod.totalUSD * tasa).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget buildExpensesList(List<Map<String, dynamic>> gastos, double tasa) {
    if (gastos.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No se registraron gastos en este período.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: gastos.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final g = gastos[index];
          final desc = (g['descripcion'] as String?) ?? 'Sin descripción';
          final cat = (g['categoria'] as String?) ?? 'Otros';
          final usd = (g['montoUSD'] as num?)?.toDouble() ?? 0.0;
          final bs = (g['montoBs'] as num?)?.toDouble() ?? (usd * tasa);
          final fecha = (g['fecha'] as Timestamp?)?.toDate();
          final fechaStr = fecha != null ? DateFormat('dd/MM hh:mm a').format(fecha) : '';

          return ListTile(
            dense: true,
            leading: const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFFEE2E2),
              child: Icon(Icons.arrow_downward, color: AppColors.danger, size: 14),
            ),
            title: Text(desc, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text('$cat • $fechaStr'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-\$${usd.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger),
                ),
                Text(
                  '-Bs ${bs.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget buildPurchasesList(List<Map<String, dynamic>> compras, double tasa) {
    if (compras.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No se registraron compras en este período.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: compras.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final c = compras[index];
          final desc = (c['descripcion'] ?? c['nombreProducto'] as String?) ?? 'Compra';
          final prov = (c['proveedor'] as String?) ?? '';
          final cant = (c['cantidad'] as num?)?.toInt();
          final usd = (c['montoUSD'] ?? c['totalCostoUSD'] as num?)?.toDouble() ?? 0.0;
          final bs = (c['totalCostoBs'] ?? c['montoBs'] as num?)?.toDouble() ?? (usd * tasa);
          final fecha = (c['fecha'] as Timestamp?)?.toDate();
          final fechaStr = fecha != null ? DateFormat('dd/MM hh:mm a').format(fecha) : '';

          return ListTile(
            dense: true,
            leading: const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFFEF3C7),
              child: Icon(Icons.shopping_bag, color: AppColors.warning, size: 14),
            ),
            title: Text(desc, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text('${cant != null ? "$cant unid. • " : ""}${prov.isNotEmpty ? "$prov • " : ""}$fechaStr'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-\$${usd.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.warning),
                ),
                Text(
                  '-Bs ${bs.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget buildSalesList(
    List<Map<String, dynamic>> ventas,
    double tasa,
    Function(Map<String, dynamic>) onSelect,
  ) {
    if (ventas.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No se registraron ventas en este período.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ventas.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final s = ventas[index];
          final usd = (s['totalUSD'] as num?)?.toDouble() ?? 0.0;
          final bs = (s['totalBs'] as num?)?.toDouble() ?? (usd * tasa);
          final metodo = s['metodoPago'] ?? 'otro';
          final metodoLabel = metodoNombres[metodo] ?? metodo.toString().toUpperCase();
          final items = (s['items'] as List<dynamic>?) ?? [];
          final fecha = (s['fecha'] as Timestamp?)?.toDate();
          final fechaStr = fecha != null ? DateFormat('dd/MM hh:mm a').format(fecha) : '';

          return ListTile(
            dense: true,
            leading: const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.receipt, color: AppColors.primary, size: 14),
            ),
            title: Text(
              '\$${usd.toStringAsFixed(2)}  •  Bs ${bs.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text('$fechaStr • ${items.length} ${items.length == 1 ? "ítem" : "ítems"} • $metodoLabel'),
            trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
            onTap: () => onSelect(s),
          );
        },
      ),
    );
  }

  static void showSaleDetailsModal(BuildContext context, Map<String, dynamic> sale) {
    final items = (sale['items'] as List<dynamic>?) ?? [];
    final totalUSD = (sale['totalUSD'] as num?)?.toDouble() ?? 0;
    final totalBs = (sale['totalBs'] as num?)?.toDouble() ?? 0;
    final tasa = (sale['tasaBCV'] as num?)?.toDouble() ?? 0;
    final metodo = sale['metodoPago'] ?? 'otro';
    final metodoLabel = metodoNombres[metodo] ?? metodo.toString().toUpperCase();
    final fecha = (sale['fecha'] as Timestamp?)?.toDate();
    final fechaStr = fecha != null ? DateFormat('dd/MM/yyyy hh:mm a').format(fecha) : 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
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
                  const Text('Ticket de Venta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(fechaStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Método: $metodoLabel', style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (tasa > 0)
                    Text('Tasa: $tasa Bs/\$', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Productos Vendidos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
}
