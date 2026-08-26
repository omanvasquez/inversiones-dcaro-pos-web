import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client.dart';
class ClientService {
  final _col = FirebaseFirestore.instance.collection('clients').withConverter<Client>(fromFirestore: (s,_)=>Client.fromFirestore(s), toFirestore: (c,_)=>c.toMap());
  Stream<List<Client>> stream() => _col.snapshots().map((s)=>s.docs.map((d)=>d.data()).toList());
  Future<void> create(Client c) async { await _col.doc().set(c); }
}
