import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale.dart';
class SaleService {
  final _db = FirebaseFirestore.instance;
  Future<void> createSale(Sale sale) async {
    final batch = _db.batch();
    final saleRef = _db.collection('sales').doc();
    batch.set(saleRef, sale.toMap());
    for(final item in sale.items){ final prodRef = _db.collection('products').doc(item.productoId); batch.update(prodRef, {'stock': FieldValue.increment(-item.cantidad)}); }
    await batch.commit();
  }
  Stream<QuerySnapshot<Map<String,dynamic>>> streamRecientes() => _db.collection('sales').orderBy('fecha', descending: true).limit(50).snapshots();
}
