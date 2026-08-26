import 'package:cloud_firestore/cloud_firestore.dart';
enum ProductCategory { cuadernos, lapices, boligrafos, resmas, carpetas, escolar, oficina, arte, otros }
String catToString(ProductCategory c) {
  switch(c){
    case ProductCategory.cuadernos: return 'Cuadernos';
    case ProductCategory.lapices: return 'Lápices';
    case ProductCategory.boligrafos: return 'Bolígrafos';
    case ProductCategory.resmas: return 'Resmas';
    case ProductCategory.carpetas: return 'Carpetas';
    case ProductCategory.escolar: return 'Escolar';
    case ProductCategory.oficina: return 'Oficina';
    case ProductCategory.arte: return 'Arte';
    case ProductCategory.otros: return 'Otros';
  }
}
ProductCategory catFromString(String s){
  switch(s){
    case 'Cuadernos': return ProductCategory.cuadernos;
    case 'Lápices': return ProductCategory.lapices;
    case 'Bolígrafos': return ProductCategory.boligrafos;
    case 'Resmas': return ProductCategory.resmas;
    case 'Carpetas': return ProductCategory.carpetas;
    case 'Escolar': return ProductCategory.escolar;
    case 'Oficina': return ProductCategory.oficina;
    case 'Arte': return ProductCategory.arte;
    default: return ProductCategory.otros;
  }
}
class Product {
  final String id; final String nombre; final String codigoBarras; final ProductCategory categoria;
  final int stock; final double costoUSD; final double precioUSD; final double precioBs;
  final bool activo; final Timestamp creadoEn;
  Product({required this.id, required this.nombre, required this.codigoBarras, required this.categoria, required this.stock, required this.costoUSD, required this.precioUSD, required this.precioBs, required this.activo, required this.creadoEn});
  Map<String,dynamic> toMap() => {'nombre': nombre, 'codigoBarras': codigoBarras, 'categoria': catToString(categoria), 'stock': stock, 'costoUSD': costoUSD, 'precioUSD': precioUSD, 'precioBs': precioBs, 'activo': activo, 'creadoEn': creadoEn};
  factory Product.fromMap(String id, Map<String,dynamic> m) => Product(id: id, nombre: m['nombre'] as String, codigoBarras: m['codigoBarras'] as String, categoria: catFromString(m['categoria'] as String), stock: (m['stock'] as num).toInt(), costoUSD: (m['costoUSD'] as num).toDouble(), precioUSD: (m['precioUSD'] as num).toDouble(), precioBs: (m['precioBs'] as num).toDouble(), activo: m['activo'] as bool, creadoEn: m['creadoEn'] as Timestamp);
  factory Product.fromFirestore(DocumentSnapshot<Map<String,dynamic>> doc) => Product.fromMap(doc.id, doc.data()!);
}