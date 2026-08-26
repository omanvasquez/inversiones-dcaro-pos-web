import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
class ProductService {
  final _col = FirebaseFirestore.instance.collection('products').withConverter<Product>(fromFirestore: (s,_)=>Product.fromFirestore(s), toFirestore: (p,_)=>p.toMap());
  Stream<List<Product>> streamActivos() => _col.where('activo', isEqualTo: true).snapshots().map((s)=>s.docs.map((d)=>d.data()).toList());
  Future<void> create(Product p) async { await _col.doc().set(p); }
  Future<void> updateStock(String id, int nuevo) async { await _col.doc(id).update({'stock': nuevo}); }
}
