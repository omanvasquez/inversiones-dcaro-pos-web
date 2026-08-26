import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/config_service.dart';
class PosScreen extends StatelessWidget { const PosScreen({super.key}); @override Widget build(BuildContext context){ final cfg=context.watch<ConfigService>(); return Scaffold(appBar: AppBar(title: Text(cfg.nombreNegocio), actions: [Center(child: Text('BCV: ${cfg.tasaBCV}')), IconButton(onPressed: ()=>context.read<AuthService>().logout(), icon: const Icon(Icons.logout))]), body: const Center(child: Text('POS - Papelería - Base lista'))); } }
