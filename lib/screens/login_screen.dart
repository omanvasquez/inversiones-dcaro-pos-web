import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState()=>_LoginScreenState();}
class _LoginScreenState extends State<LoginScreen>{
  final _email=TextEditingController(); final _pass=TextEditingController(); bool loading=false; String? error;
  @override Widget build(BuildContext context){ return Scaffold(body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: Card(margin: const EdgeInsets.all(24), child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Inversiones dCaro - Login', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height:16), TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')), TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Password'), obscureText: true), if(error!=null) Padding(padding: const EdgeInsets.only(top:8), child: Text(error!, style: const TextStyle(color: Colors.red))), const SizedBox(height:16), if(loading) const CircularProgressIndicator() else ElevatedButton(onPressed: () async { setState(()=>loading=true); try{ await context.read<AuthService>().login(_email.text.trim(), _pass.text.trim()); } on Exception catch(e){ setState(()=>error=e.toString()); } finally{ setState(()=>loading=false); } }, child: const Text('Entrar'))])))))); }
}
