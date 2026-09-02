import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _tasaCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _rifCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cfg = context.read<ConfigService>();
    _tasaCtrl.text = cfg.tasaBCV.toString();
    _nombreCtrl.text = cfg.nombreNegocio;
    _rifCtrl.text = cfg.rif;
  }

  @override
  void dispose() {
    _tasaCtrl.dispose();
    _nombreCtrl.dispose();
    _rifCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _saving = true);
    try {
      final configService = context.read<ConfigService>();
      final tasa = double.tryParse(_tasaCtrl.text.replaceAll(',', '.')) ?? 0;
      final doc = FirebaseFirestore.instance.collection('config').doc('global');
      await doc.set({
        'tasaBCV': tasa,
        'nombreNegocio': _nombreCtrl.text.trim(),
        'rif': _rifCtrl.text.trim(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await configService.load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del Sistema'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Datos del Negocio y Tasa',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tasaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Tasa BCV (Bs por USD)',
                          prefixIcon: Icon(Icons.currency_exchange),
                          suffixText: 'Bs',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Negocio',
                          prefixIcon: Icon(Icons.store),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _rifCtrl,
                        decoration: const InputDecoration(
                          labelText: 'RIF / Identificación Fiscal',
                          prefixIcon: Icon(Icons.badge),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _guardar,
                          child: _saving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Guardar Cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
