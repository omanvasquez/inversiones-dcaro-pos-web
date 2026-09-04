import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../services/report_service.dart';
import '../widgets/report_widgets.dart';
import '../theme/app_theme.dart';

class ReportesMensualScreen extends StatefulWidget {
  const ReportesMensualScreen({super.key});

  @override
  State<ReportesMensualScreen> createState() => _ReportesMensualScreenState();
}

class _ReportesMensualScreenState extends State<ReportesMensualScreen> {
  final _reportService = ReportService();
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loading = false;
  ReportData? _reportData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarReporteMensual();
  }

  DateTime get _startOfMonth => DateTime(_currentMonth.year, _currentMonth.month, 1, 0, 0, 0);

  DateTime get _endOfMonth => DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59, 999);

  bool get _esMesActual {
    final now = DateTime.now();
    return _currentMonth.year == now.year && _currentMonth.month == now.month;
  }

  Future<void> _cargarReporteMensual() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cfg = context.read<ConfigService>();
      final tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;

      final report = await _reportService.getReport(
        start: _startOfMonth,
        end: _endOfMonth,
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
          _error = 'Error cargando reporte mensual: $e';
          _loading = false;
        });
      }
    }
  }

  void _cambiarMes(int deltaMeses) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + deltaMeses, 1);
    });
    _cargarReporteMensual();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigService>();
    final double tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;
    final mesStr = DateFormat('MMMM yyyy', 'es').format(_currentMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Mensual'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarReporteMensual,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Selector de mes
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Mes anterior',
                      onPressed: () => _cambiarMes(-1),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                mesStr.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          if (_esMesActual)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                '(Mes en curso)',
                                style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Mes siguiente',
                      onPressed: _esMesActual ? null : () => _cambiarMes(1),
                    ),
                    if (!_esMesActual)
                      TextButton(
                        onPressed: () {
                          setState(() => _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1));
                          _cargarReporteMensual();
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
              _buildSectionHeader('Desglose Mensual por Método de Pago', Icons.payments_outlined),
              const SizedBox(height: 8),
              ReportWidgets.buildPaymentMethods(_reportData!, tasa),
              const SizedBox(height: 24),

              // Productos Vendidos
              _buildSectionHeader('¿Qué se vendió en el mes? (Productos más vendidos)', Icons.inventory_outlined,
                  badge: '${_reportData!.productosVendidos.length} productos'),
              const SizedBox(height: 8),
              ReportWidgets.buildProductsSold(_reportData!.productosVendidos, tasa),
              const SizedBox(height: 24),

              // Gastos del mes
              _buildSectionHeader('Gastos del Mes', Icons.receipt_long_outlined,
                  badge: '${_reportData!.gastos.length} gastos'),
              const SizedBox(height: 8),
              ReportWidgets.buildExpensesList(_reportData!.gastos, tasa),
              const SizedBox(height: 24),

              // Compras del mes
              _buildSectionHeader('Compras de Mercancía del Mes', Icons.shopping_bag_outlined,
                  badge: '${_reportData!.compras.length} compras'),
              const SizedBox(height: 8),
              ReportWidgets.buildPurchasesList(_reportData!.compras, tasa),
              const SizedBox(height: 24),

              // Transacciones del mes
              _buildSectionHeader('Ventas Realizadas en el Mes', Icons.format_list_bulleted,
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
