import 'package:cloud_firestore/cloud_firestore.dart';
class SaleItem { final String productoId; final String nombre; final int cantidad; final double precioUSD; SaleItem({required this.productoId, required this.nombre, required this.cantidad, required this.precioUSD}); Map<String,dynamic> toMap() => {'productoId': productoId, 'nombre': nombre, 'cantidad': cantidad, 'precioUSD': precioUSD}; factory SaleItem.fromMap(Map<String,dynamic> m) => SaleItem(productoId: m['productoId'], nombre: m['nombre'], cantidad: (m['cantidad'] as num).toInt(), precioUSD: (m['precioUSD'] as num).toDouble());}
class Sale {
  final String id; final Timestamp fecha; final String cajeroId; final String? clienteId; final List<SaleItem> items;
  final double subtotalUSD; final double totalUSD; final double totalBs; final double tasaBCV; final String metodoPago; final Timestamp creadoEn;
  Sale({required this.id, required this.fecha, required this.cajeroId, this.clienteId, required this.items, required this.subtotalUSD, required this.totalUSD, required this.totalBs, required this.tasaBCV, required this.metodoPago, required this.creadoEn});
  Map<String,dynamic> toMap() => {'fecha': fecha, 'cajeroId': cajeroId, 'clienteId': clienteId, 'items': items.map((e)=>e.toMap()).toList(), 'subtotalUSD': subtotalUSD, 'totalUSD': totalUSD, 'totalBs': totalBs, 'tasaBCV': tasaBCV, 'metodoPago': metodoPago, 'creadoEn': creadoEn};
}
