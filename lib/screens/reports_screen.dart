import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/config_service.dart';
import '../services/report_service.dart';
import '../widgets/report_widgets.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final _reportService = ReportService();
  final _db = FirebaseFirestore.instance;
  late TabController _tabController;

  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  ReportData? _dayReport;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarReporteDelDia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarReporteDelDia() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cfg = context.read<ConfigService>();
      final tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;

      final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0, 0);
      final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59, 999);

      final report = await _reportService.getReport(start: start, end: end, tasaBCV: tasa);
      if (mounted) {
        setState(() {
          _dayReport = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error cargando datos: $e';
          _loading = false;
        });
      }
    }
  }

  void _cambiarDia(int deltaDias) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: deltaDias));
    });
    _cargarReporteDelDia();
  }

  Future<void> _seleccionarFechaCalendario() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Seleccionar día para reporte',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _cargarReporteDelDia();
    }
  }

  bool get _esHoy {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigService>();
    final double tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial y Reporte de Ventas'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'Detalle del Día'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Todas las Ventas'),
            Tab(icon: Icon(Icons.lock_clock), text: 'Cierres Guardados'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDayReportTab(tasa),
          _buildAllSalesTab(tasa),
          _buildSavedClosuresTab(tasa),
        ],
      ),
    );
  }

  Widget _buildDayReportTab(double tasa) {
    return RefreshIndicator(
      onRefresh: _cargarReporteDelDia,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Selector de fecha
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Día anterior',
                    onPressed: () => _cambiarDia(-1),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _seleccionarFechaCalendario,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('EEEE, dd/MM/yyyy', 'es').format(_selectedDate).toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            if (_esHoy)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  '(Hoy)',
                                  style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Día siguiente',
                    onPressed: _esHoy ? null : () => _cambiarDia(1),
                  ),
                  if (!_esHoy)
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedDate = DateTime.now());
                        _cargarReporteDelDia();
                      },
                      child: const Text('Hoy'),
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
          else if (_dayReport != null) ...[
            // Métricas Financieras (Ventas, Bruta, Gastos, Compras, Neta)
            LayoutBuilder(
              builder: (ctx, constraints) {
                return ReportWidgets.buildFinancialCards(
                  context,
                  _dayReport!,
                  tasa,
                  isNarrow: constraints.maxWidth < 650,
                );
              },
            ),
            const SizedBox(height: 24),

            // Desglose por Método de Pago
            _buildSectionHeader('Desglose por Métodos de Pago', Icons.payments_outlined),
            const SizedBox(height: 8),
            ReportWidgets.buildPaymentMethods(_dayReport!, tasa),
            const SizedBox(height: 24),

            // Qué se vendió hoy
            _buildSectionHeader('¿Qué se vendió hoy? (Productos Vendidos)', Icons.inventory_outlined,
                badge: '${_dayReport!.productosVendidos.length} productos'),
            const SizedBox(height: 8),
            ReportWidgets.buildProductsSold(_dayReport!.productosVendidos, tasa),
            const SizedBox(height: 24),

            // Gastos del día
            _buildSectionHeader('Gastos del Día', Icons.receipt_long_outlined,
                badge: '${_dayReport!.gastos.length} gastos'),
            const SizedBox(height: 8),
            ReportWidgets.buildExpensesList(_dayReport!.gastos, tasa),
            const SizedBox(height: 24),

            // Compras del día
            _buildSectionHeader('Compras de Mercancía del Día', Icons.shopping_bag_outlined,
                badge: '${_dayReport!.compras.length} compras'),
            const SizedBox(height: 8),
            ReportWidgets.buildPurchasesList(_dayReport!.compras, tasa),
            const SizedBox(height: 24),

            // Ventas individuales del día
            _buildSectionHeader('Tickets de Venta del Día', Icons.format_list_bulleted,
                badge: '${_dayReport!.ventas.length} ventas'),
            const SizedBox(height: 8),
            ReportWidgets.buildSalesList(_dayReport!.ventas, tasa, (sale) {
              ReportWidgets.showSaleDetailsModal(context, sale);
            }),
            const SizedBox(height: 32),
          ],
        ],
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

  Widget _buildAllSalesTab(double tasa) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('sales').orderBy('fecha', descending: true).limit(100).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final sales = snapshot.data?.docs ?? [];
        if (sales.isEmpty) {
          return const Center(
            child: Text('No hay ventas registradas', style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        double totalUSD = 0;
        for (final s in sales) {
          totalUSD += (s.data()['totalUSD'] as num?)?.toDouble() ?? 0;
        }

        final salesList = sales.map((doc) {
          final m = Map<String, dynamic>.from(doc.data());
          m['id'] = doc.id;
          return m;
        }).toList();

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
                        const Text('Total Registrado (Últimas 100 ventas)',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          '\$${totalUSD.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                        Text(
                          'Bs ${(totalUSD * tasa).toStringAsFixed(2)}',
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
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  ReportWidgets.buildSalesList(salesList, tasa, (sale) {
                    ReportWidgets.showSaleDetailsModal(context, sale);
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSavedClosuresTab(double tasa) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('cierres_diarios').orderBy('fecha', descending: true).limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final closures = snapshot.data?.docs ?? [];
        if (closures.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay cierres de caja guardados aún.\nPulsa "Cerrar Día" en el menú principal para generar uno.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: closures.length,
          itemBuilder: (context, i) {
            final c = closures[i].data();
            final dateKey = c['dateKey'] ?? closures[i].id;
            final totalUSD = (c['totalUSD'] as num?)?.toDouble() ?? 0.0;
            final totalBs = (c['totalBs'] as num?)?.toDouble() ?? 0.0;
            final gastosUSD = (c['gastosUSD'] as num?)?.toDouble() ?? 0.0;
            final gananciaNetaUSD = (c['gananciaNetaUSD'] ?? c['balanceNetoUSD'] as num?)?.toDouble() ?? (totalUSD - gastosUSD);
            final transacciones = (c['transacciones'] ?? c['cantidadVentas'] as num?)?.toInt() ?? 0;
            final cerradoEn = (c['cerradoEn'] as Timestamp?)?.toDate();
            final horaStr = cerradoEn != null ? DateFormat('hh:mm a').format(cerradoEn) : '';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              dateKey,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        if (horaStr.isNotEmpty)
                          Text('Cerrado a las $horaStr', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _closureStat('Ventas', '\$${totalUSD.toStringAsFixed(2)}', 'Bs ${totalBs.toStringAsFixed(2)}'),
                        _closureStat('Gastos', '-\$${gastosUSD.toStringAsFixed(2)}', ''),
                        _closureStat(
                          'Ganancia Neta',
                          '\$${gananciaNetaUSD.toStringAsFixed(2)}',
                          'Bs ${(gananciaNetaUSD * tasa).toStringAsFixed(2)}',
                          color: gananciaNetaUSD >= 0 ? AppColors.secondary : AppColors.danger,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('$transacciones ventas registradas en este día',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _closureStat(String label, String usd, String bs, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          usd,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color ?? AppColors.primaryDark),
        ),
        if (bs.isNotEmpty)
          Text(bs, style: TextStyle(fontSize: 10, color: color ?? AppColors.textSecondary)),
      ],
    );
  }
}
