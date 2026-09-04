import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../services/report_service.dart';
import '../widgets/report_widgets.dart';
import '../theme/app_theme.dart';

class ReportesSemanalScreen extends StatefulWidget {
  const ReportesSemanalScreen({super.key});

  @override
  State<ReportesSemanalScreen> createState() => _ReportesSemanalScreenState();
}

class _ReportesSemanalScreenState extends State<ReportesSemanalScreen> {
  final _reportService = ReportService();
  int _weeksOffset = 0;
  bool _loading = false;
  ReportData? _reportData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarReporteSemanal();
  }

  DateTime get _startOfWeek {
    final now = DateTime.now().add(Duration(days: _weeksOffset * 7));
    final sevenDaysAgo = now.subtract(const Duration(days: 6));
    return DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day, 0, 0, 0);
  }

  DateTime get _endOfWeek {
    final now = DateTime.now().add(Duration(days: _weeksOffset * 7));
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  Future<void> _cargarReporteSemanal() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cfg = context.read<ConfigService>();
      final tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;

      final report = await _reportService.getReport(
        start: _startOfWeek,
        end: _endOfWeek,
        tasaBCV: tasa,
      );
      if (mounted) {
        setState(() {
          _reportData = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cargando reporte semanal: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigService>();
    final double tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;

    final startStr = DateFormat('dd/MM').format(_startOfWeek);
    final endStr = DateFormat('dd/MM/yyyy').format(_endOfWeek);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Semanal'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarReporteSemanal,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Selector de semana
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Semana anterior',
                      onPressed: () {
                        setState(() => _weeksOffset--);
                        _cargarReporteSemanal();
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.date_range, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                '$startStr al $endStr',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          if (_weeksOffset == 0)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                '(Últimos 7 días)',
                                style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Semana siguiente',
                      onPressed: _weeksOffset >= 0
                          ? null
                          : () {
                              setState(() => _weeksOffset++);
                              _cargarReporteSemanal();
                            },
                    ),
                    if (_weeksOffset != 0)
                      TextButton(
                        onPressed: () {
                          setState(() => _weeksOffset = 0);
                          _cargarReporteSemanal();
                        },
                        child: const Text('Actual'),
                      ),
                  ],
                ),
              ),
            ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                color: const Color(0xFFFEE2E2),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ),
              )
            else if (_reportData != null) ...[
              // Métricas Financieras
              LayoutBuilder(
                builder: (ctx, constraints) {
                  return ReportWidgets.buildFinancialCards(
                    context,
                    _reportData!,
                    tasa,
                    isNarrow: constraints.maxWidth < 650,
                  );
                },
              ),
              const SizedBox(height: 24),

              // Métodos de Pago
              _buildSectionHeader('Desglose Semanal por Método de Pago', Icons.payments_outlined),
              const SizedBox(height: 8),
              ReportWidgets.buildPaymentMethods(_reportData!, tasa),
              const SizedBox(height: 24),

              // Productos Vendidos
              _buildSectionHeader('¿Qué se vendió en la semana? (Top Productos)', Icons.inventory_outlined,
                  badge: '${_reportData!.productosVendidos.length} productos'),
              const SizedBox(height: 8),
              ReportWidgets.buildProductsSold(_reportData!.productosVendidos, tasa),
              const SizedBox(height: 24),

              // Gastos de la semana
              _buildSectionHeader('Gastos de la Semana', Icons.receipt_long_outlined,
                  badge: '${_reportData!.gastos.length} gastos'),
              const SizedBox(height: 8),
              ReportWidgets.buildExpensesList(_reportData!.gastos, tasa),
              const SizedBox(height: 24),

              // Compras de la semana
              _buildSectionHeader('Compras de Mercancía de la Semana', Icons.shopping_bag_outlined,
                  badge: '${_reportData!.compras.length} compras'),
              const SizedBox(height: 8),
              ReportWidgets.buildPurchasesList(_reportData!.compras, tasa),
              const SizedBox(height: 24),

              // Transacciones de la semana
              _buildSectionHeader('Ventas Realizadas en la Semana', Icons.format_list_bulleted,
                  badge: '${_reportData!.ventas.length} ventas'),
              const SizedBox(height: 8),
              ReportWidgets.buildSalesList(_reportData!.ventas, tasa, (sale) {
                ReportWidgets.showSaleDetailsModal(context, sale);
              }),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {String? badge}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}
