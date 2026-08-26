import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/config_service.dart';
import 'screens/login_screen.dart';
import 'screens/pos_screen.dart';
void main() async { WidgetsFlutterBinding.ensureInitialized(); await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); runApp(const App()); }
class App extends StatelessWidget { const App({super.key}); @override Widget build(BuildContext context){ return MultiProvider(providers: [ChangeNotifierProvider(create: (_)=>AuthService()), ChangeNotifierProvider(create: (_)=>ConfigService()..load())], child: MaterialApp(title: 'Inversiones dCaro', theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)), home: const AuthWrapper())); } }
class AuthWrapper extends StatelessWidget { const AuthWrapper({super.key}); @override Widget build(BuildContext context){ final auth=context.watch<AuthService>(); return StreamBuilder(stream: auth.authState, builder: (c,s){ if(s.connectionState==ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator())); if(!s.hasData) return const LoginScreen(); return const PosScreen(); }); } }
