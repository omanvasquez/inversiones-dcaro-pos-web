import 'package:cloud_firestore/cloud_firestore.dart';
class Client {
  final String id; final String nombre; final String cedula; final String telefono; final String direccion;
  final double saldoFiadoUSD; final double saldoFiadoBs; final Timestamp creadoEn;
  Client({required this.id, required this.nombre, required this.cedula, required this.telefono, required this.direccion, required this.saldoFiadoUSD, required this.saldoFiadoBs, required this.creadoEn});
  Map<String,dynamic> toMap() => {'nombre': nombre, 'cedula': cedula, 'telefono': telefono, 'direccion': direccion, 'saldoFiadoUSD': saldoFiadoUSD, 'saldoFiadoBs': saldoFiadoBs, 'creadoEn': creadoEn};
  factory Client.fromMap(String id, Map<String,dynamic> m) => Client(id: id, nombre: m['nombre'], cedula: m['cedula'], telefono: m['telefono'], direccion: m['direccion'], saldoFiadoUSD: (m['saldoFiadoUSD'] as num).toDouble(), saldoFiadoBs: (m['saldoFiadoBs'] as num).toDouble(), creadoEn: m['creadoEn']);
  factory Client.fromFirestore(DocumentSnapshot<Map<String,dynamic>> d) => Client.fromMap(d.id, d.data()!);
}
