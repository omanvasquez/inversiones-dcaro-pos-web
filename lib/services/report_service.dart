import 'package:cloud_firestore/cloud_firestore.dart';

class SoldProductItem {
  final String productoId;
  final String nombre;
  final int cantidad;
  final double totalUSD;

  SoldProductItem({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.totalUSD,
  });
}

class ReportData {
  final DateTime startDate;
  final DateTime endDate;
  final double totalVentasUSD;
  final double totalVentasBs;
  final int totalTransacciones;
  final Map<String, double> ventasPorMetodo;
  final List<SoldProductItem> productosVendidos;

  final double totalGastosUSD;
  final double totalGastosBs;
  final List<Map<String, dynamic>> gastos;

  final double totalComprasUSD;
  final double totalComprasBs;
  final List<Map<String, dynamic>> compras;

  final double totalCostoVentasUSD;
  final double gananciaBrutaUSD;
  final double gananciaBrutaBs;
  final double gananciaNetaUSD;
  final double gananciaNetaBs;

  final List<Map<String, dynamic>> ventas;

  ReportData({
    required this.startDate,
    required this.endDate,
    required this.totalVentasUSD,
    required this.totalVentasBs,
    required this.totalTransacciones,
    required this.ventasPorMetodo,
    required this.productosVendidos,
    required this.totalGastosUSD,
    required this.totalGastosBs,
    required this.gastos,
    required this.totalComprasUSD,
    required this.totalComprasBs,
    required this.compras,
    required this.totalCostoVentasUSD,
    required this.gananciaBrutaUSD,
    required this.gananciaBrutaBs,
    required this.gananciaNetaUSD,
    required this.gananciaNetaBs,
    required this.ventas,
  });
}

class _ProductAcc {
  final String productoId;
  final String nombre;
  int cantidad = 0;
  double totalUSD = 0.0;
  _ProductAcc({required this.productoId, required this.nombre});
}

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<ReportData> getReport({
    required DateTime start,
    required DateTime end,
    required double tasaBCV,
  }) async {
    final startTimestamp = Timestamp.fromDate(start);
    final endTimestamp = Timestamp.fromDate(end);

    final results = await Future.wait([
      _db
          .collection('sales')
          .where('fecha', isGreaterThanOrEqualTo: startTimestamp)
          .where('fecha', isLessThanOrEqualTo: endTimestamp)
          .get(),
      _db
          .collection('expenses')
          .where('fecha', isGreaterThanOrEqualTo: startTimestamp)
          .where('fecha', isLessThanOrEqualTo: endTimestamp)
          .get(),
      _db
          .collection('purchases')
          .where('fecha', isGreaterThanOrEqualTo: startTimestamp)
          .where('fecha', isLessThanOrEqualTo: endTimestamp)
          .get(),
      _db.collection('products').get(),
    ]);

    final salesSnap = results[0];
    final expensesSnap = results[1];
    final purchasesSnap = results[2];
    final productsSnap = results[3];

    final Map<String, double> productCosts = {};
    for (final doc in productsSnap.docs) {
      final data = doc.data();
      productCosts[doc.id] = (data['costoUSD'] as num?)?.toDouble() ?? 0.0;
    }

    double totalVentasUSD = 0;
    double totalVentasBs = 0;
    double totalCostoVentasUSD = 0;
    final Map<String, double> porMetodo = {
      'efectivo_dolar': 0.0,
      'efectivo_bolivar': 0.0,
      'punto_venta': 0.0,
      'pago_movil': 0.0,
      'fiado': 0.0,
    };
    final Map<String, _ProductAcc> accProds = {};
    final List<Map<String, dynamic>> ventasList = [];

    for (final doc in salesSnap.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      ventasList.add(data);

      final usd = (data['totalUSD'] as num?)?.toDouble() ?? 0.0;
      final bs = (data['totalBs'] as num?)?.toDouble() ?? (usd * tasaBCV);
      final metodo = (data['metodoPago'] as String?) ?? 'otro';

      totalVentasUSD += usd;
      totalVentasBs += bs;
      porMetodo[metodo] = (porMetodo[metodo] ?? 0.0) + usd;

      final items = (data['items'] as List<dynamic>?) ?? [];
      for (final it in items) {
        final itemMap = it as Map<String, dynamic>;
        final prodId = (itemMap['productoId'] as String?) ?? '';
        final nombre = (itemMap['nombre'] as String?) ?? 'Sin nombre';
        final cant = (itemMap['cantidad'] as num?)?.toInt() ?? 1;
        final precio = (itemMap['precioUSD'] as num?)?.toDouble() ?? 0.0;

        final unitCost = productCosts[prodId] ?? 0.0;
        totalCostoVentasUSD += (unitCost * cant);

        final key = prodId.isNotEmpty ? prodId : nombre;
        final acc = accProds.putIfAbsent(
          key,
          () => _ProductAcc(productoId: prodId, nombre: nombre),
        );
        acc.cantidad += cant;
        acc.totalUSD += (precio * cant);
      }
    }

    final productosVendidos = accProds.values.map((p) => SoldProductItem(
      productoId: p.productoId,
      nombre: p.nombre,
      cantidad: p.cantidad,
      totalUSD: p.totalUSD,
    )).toList();
    productosVendidos.sort((a, b) => b.totalUSD.compareTo(a.totalUSD));

    double totalGastosUSD = 0;
    double totalGastosBs = 0;
    final List<Map<String, dynamic>> gastosList = [];
    for (final doc in expensesSnap.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      gastosList.add(data);

      final usd = (data['montoUSD'] as num?)?.toDouble() ?? 0.0;
      final bs = (data['montoBs'] as num?)?.toDouble() ?? (usd * tasaBCV);
      totalGastosUSD += usd;
      totalGastosBs += bs;
    }

    double totalComprasUSD = 0;
    double totalComprasBs = 0;
    final List<Map<String, dynamic>> comprasList = [];
    for (final doc in purchasesSnap.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      comprasList.add(data);

      final usd = (data['montoUSD'] ?? data['totalCostoUSD'] as num?)?.toDouble() ?? 0.0;
      final bs = (data['totalCostoBs'] ?? data['montoBs'] as num?)?.toDouble() ?? (usd * tasaBCV);
      totalComprasUSD += usd;
      totalComprasBs += bs;
    }

    final gananciaBrutaUSD = totalVentasUSD - totalCostoVentasUSD;
    final gananciaBrutaBs = gananciaBrutaUSD * tasaBCV;
    final gananciaNetaUSD = gananciaBrutaUSD - totalGastosUSD;
    final gananciaNetaBs = gananciaNetaUSD * tasaBCV;

    ventasList.sort((a, b) {
      final tA = (a['fecha'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final tB = (b['fecha'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return tB.compareTo(tA);
    });
    gastosList.sort((a, b) {
      final tA = (a['fecha'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final tB = (b['fecha'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return tB.compareTo(tA);
    });
    comprasList.sort((a, b) {
      final tA = (a['fecha'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final tB = (b['fecha'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return tB.compareTo(tA);
    });

    return ReportData(
      startDate: start,
      endDate: end,
      totalVentasUSD: totalVentasUSD,
      totalVentasBs: totalVentasBs,
      totalTransacciones: salesSnap.docs.length,
      ventasPorMetodo: porMetodo,
      productosVendidos: productosVendidos,
      totalGastosUSD: totalGastosUSD,
      totalGastosBs: totalGastosBs,
      gastos: gastosList,
      totalComprasUSD: totalComprasUSD,
      totalComprasBs: totalComprasBs,
      compras: comprasList,
      totalCostoVentasUSD: totalCostoVentasUSD,
      gananciaBrutaUSD: gananciaBrutaUSD,
      gananciaBrutaBs: gananciaBrutaBs,
      gananciaNetaUSD: gananciaNetaUSD,
      gananciaNetaBs: gananciaNetaBs,
      ventas: ventasList,
    );
  }
}
