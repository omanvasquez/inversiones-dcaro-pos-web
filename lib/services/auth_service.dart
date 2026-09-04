import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_role.dart';
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance; final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? get user => _auth.currentUser; Stream<User?> get authState => _auth.authStateChanges();
  Future<UserRole?> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final roleStr = (doc.data()?['rol'] ?? doc.data()?['role'] ?? 'cashier').toString();
    return userRoleFromString(roleStr);
  }
  Future<void> login(String email, String pass) async { await _auth.signInWithEmailAndPassword(email: email, password: pass); notifyListeners(); }
  Future<void> logout() async { await _auth.signOut(); notifyListeners(); }
}
