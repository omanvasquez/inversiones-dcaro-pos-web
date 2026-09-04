import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_service.dart';

class ClosureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ReportService _reportService = ReportService();

  Future<ReportData> getDaySummary(DateTime date, double tasaBCV) async {
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    return _reportService.getReport(start: startOfDay, end: endOfDay, tasaBCV: tasaBCV);
  }

  Future<void> closeDay(DateTime date, {double tasaBCV = 780.0}) async {
    final report = await getDaySummary(date, tasaBCV);
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final Map<String, dynamic> productosMap = {};
    for (final p in report.productosVendidos) {
      productosMap[p.nombre] = {
        'cantidad': p.cantidad,
        'totalUSD': p.totalUSD,
      };
    }

    final closureData = {
      'fecha': Timestamp.fromDate(date),
      'dateKey': dateKey,
      'totalUSD': report.totalVentasUSD,
      'totalBs': report.totalVentasBs,
      'cantidadVentas': report.totalTransacciones,
      'transacciones': report.totalTransacciones,
      'porMetodo': report.ventasPorMetodo,
      'metodosPagoUSD': report.ventasPorMetodo,
      'totalCostoVentasUSD': report.totalCostoVentasUSD,
      'gananciaUSD': report.gananciaBrutaUSD,
      'gananciaBrutaUSD': report.gananciaBrutaUSD,
      'gastosUSD': report.totalGastosUSD,
      'gastosBs': report.totalGastosBs,
      'comprasUSD': report.totalComprasUSD,
      'comprasBs': report.totalComprasBs,
      'egresosUSD': report.totalGastosUSD + report.totalComprasUSD,
      'egresosBs': report.totalGastosBs + report.totalComprasBs,
      'gananciaNetaUSD': report.gananciaNetaUSD,
      'balanceNetoUSD': report.gananciaNetaUSD,
      'productosVendidos': productosMap,
      'cerradoEn': FieldValue.serverTimestamp(),
    };

    await _db.collection('closures').doc(dateKey).set(closureData, SetOptions(merge: true));
    await _db.collection('cierres_diarios').doc(dateKey).set(closureData, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCierres() {
    return _db.collection('cierres_diarios').orderBy('fecha', descending: true).limit(30).snapshots();
  }
}
