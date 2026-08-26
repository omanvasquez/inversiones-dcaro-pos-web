import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
class ConfigService extends ChangeNotifier {
  final _doc = FirebaseFirestore.instance.collection('config').doc('global');
  double tasaBCV = 0; String rif = ''; String nombreNegocio = 'Inversiones dCaro';
  Stream<DocumentSnapshot<Map<String,dynamic>>> stream() => _doc.snapshots();
  Future<void> load() async { final s = await _doc.get(); if(s.exists){ final d=s.data()!; tasaBCV=(d['tasaBCV'] as num?)?.toDouble()??0; rif=d['rif']??''; nombreNegocio=d['nombreNegocio']??'Inversiones dCaro'; notifyListeners(); } }
  Future<void> updateTasa(double tasa) async { await _doc.update({'tasaBCV': tasa, 'actualizadoEn': FieldValue.serverTimestamp()}); }
}
