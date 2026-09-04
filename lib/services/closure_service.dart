import 'package:cloud_firestore/cloud_firestore.dart';

class ClosureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> closeDay(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final snapshot = await _db
        .collection('sales')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    double totalUSD = 0;
    double totalBs = 0;
    final Map<String, double> porMetodo = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final usd = (data['totalUSD'] as num?)?.toDouble() ?? 0;
      final bs = (data['totalBs'] as num?)?.toDouble() ?? 0;
      final metodo = (data['metodoPago'] as String?) ?? 'otro';

      totalUSD += usd;
      totalBs += bs;
      porMetodo[metodo] = (porMetodo[metodo] ?? 0) + usd;
    }

    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final closureData = {
      'fecha': Timestamp.fromDate(date),
      'dateKey': dateKey,
      'totalUSD': totalUSD,
      'totalBs': totalBs,
      'cantidadVentas': snapshot.docs.length,
      'porMetodo': porMetodo,
      'cerradoEn': FieldValue.serverTimestamp(),
    };

    await _db.collection('closures').doc(dateKey).set(closureData, SetOptions(merge: true));
    await _db.collection('cierres_diarios').doc(dateKey).set(closureData, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCierres() {
    return _db.collection('closures').orderBy('fecha', descending: true).limit(30).snapshots();
  }
}
