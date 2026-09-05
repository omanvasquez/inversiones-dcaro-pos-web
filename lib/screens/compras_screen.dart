import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});

  @override
  State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> {
  final _db = FirebaseFirestore.instance;

  Future<void> _agregarCompra() async {
    // Cargar productos activos del inventario
    List<Product> productos = [];
    try {
      final snap = await _db
          .collection('products')
          .where('activo', isEqualTo: true)
          .get();
      productos = snap.docs.map((d) => Product.fromFirestore(d)).toList();
      if (productos.isEmpty) {
        final allSnap = await _db.collection('products').get();
        productos = allSnap.docs
            .map((d) => Product.fromFirestore(d))
            .where((p) => p.activo)
            .toList();
      }
      productos.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    } catch (e) {
      debugPrint('Error cargando productos para compras: $e');
    }

    if (!mounted) return;

    final descripcionCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController(text: '1');
    final costoUnitarioCtrl = TextEditingController();
    final montoTotalCtrl = TextEditingController();
    final proveedorCtrl = TextEditingController();
    final searchCtrl = TextEditingController();

    bool esDelInventario = productos.isNotEmpty;
    Product? selectedProduct;
    String searchFilter = '';

    void recalcularTotal() {
      final cant = int.tryParse(cantidadCtrl.text.trim()) ?? 0;
      final costoU = double.tryParse(costoUnitarioCtrl.text.replaceAll(',', '.')) ?? 0;
      if (cant > 0 && costoU > 0) {
        montoTotalCtrl.text = (cant * costoU).toStringAsFixed(2);
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlg) {
          final width = MediaQuery.of(ctx).size.width;
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_shopping_cart, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Registrar Compra'),
              ],
            ),
            content: SizedBox(
              width: width > 500 ? 460 : double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Modo de compra: del inventario o gasto general
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          esDelInventario
                              ? 'Artículo del Inventario'
                              : 'Gasto / Compra Libre',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: esDelInventario ? AppColors.primaryDark : AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setDlg(() {
                              esDelInventario = !esDelInventario;
                              selectedProduct = null;
                            });
                          },
                          child: Text(
                            esDelInventario ? 'Cambiar a compra libre' : 'Elegir del inventario',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (esDelInventario) ...[
                      if (selectedProduct == null) ...[
                        TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Buscar artículo en inventario...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setDlg(() {
                                        searchCtrl.clear();
                                        searchFilter = '';
                                      });
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (v) => setDlg(() => searchFilter = v.trim().toLowerCase()),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Builder(
                            builder: (_) {
                              final filtered = productos.where((p) {
                                if (searchFilter.isEmpty) return true;
                                return p.nombre.toLowerCase().contains(searchFilter) ||
                                    p.codigoBarras.toLowerCase().contains(searchFilter);
                              }).toList();

                              if (filtered.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      'No se encontraron artículos en inventario',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                    ),
                                  ),
                                );
                              }

                              return ListView.separated(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final p = filtered[i];
                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: const CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primaryLight,
                                      child: Icon(Icons.inventory_2, size: 14, color: AppColors.primary),
                                    ),
                                    title: Text(
                                      p.nombre,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      'Stock actual: ${p.stock} • Costo: \$${p.costoUSD.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: const Icon(Icons.add_circle, color: AppColors.primary, size: 20),
                                    onTap: () {
                                      setDlg(() {
                                        selectedProduct = p;
                                        if (p.costoUSD > 0) {
                                          costoUnitarioCtrl.text = p.costoUSD.toStringAsFixed(2);
                                        }
                                        recalcularTotal();
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedProduct!.nombre,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Stock actual: ${selectedProduct!.stock} unid. • Costo actual: \$${selectedProduct!.costoUSD.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => setDlg(() => selectedProduct = null),
                                icon: const Icon(Icons.swap_horiz, size: 16),
                                label: const Text('Cambiar', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cantidadCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Cantidad comprada *',
                                helperText: selectedProduct != null
                                    ? 'Nuevo stock: ${selectedProduct!.stock + (int.tryParse(cantidadCtrl.text.trim()) ?? 0)}'
                                    : null,
                                helperStyle: const TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              onChanged: (_) => setDlg(() => recalcularTotal()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: costoUnitarioCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Costo Unitario USD',
                                prefixText: '\$ ',
                              ),
                              onChanged: (_) => setDlg(() => recalcularTotal()),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      TextField(
                        controller: descripcionCtrl,
                        decoration: const InputDecoration(labelText: 'Descripción / Producto *'),
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextField(
                      controller: montoTotalCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto Total USD *',
                        prefixText: '\$ ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: proveedorCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Proveedor (opcional)',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (esDelInventario) {
                    if (selectedProduct == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Selecciona un artículo del inventario')),
                      );
                      return;
                    }
                    final cant = int.tryParse(cantidadCtrl.text.trim()) ?? 0;
                    if (cant <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ingresa una cantidad válida')),
                      );
                      return;
                    }
                  } else {
                    if (descripcionCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ingresa una descripción')),
                      );
                      return;
                    }
                  }

                  final monto = double.tryParse(montoTotalCtrl.text.replaceAll(',', '.')) ?? 0;
                  if (monto <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingresa un monto válido en USD')),
                    );
                    return;
                  }

                  Navigator.pop(ctx, true);
                },
                child: const Text('Guardar Compra'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      final monto = double.tryParse(montoTotalCtrl.text.replaceAll(',', '.')) ?? 0;
      final prov = proveedorCtrl.text.trim();

      if (esDelInventario && selectedProduct != null) {
        final cant = int.tryParse(cantidadCtrl.text.trim()) ?? 0;
        final costoU = double.tryParse(costoUnitarioCtrl.text.replaceAll(',', '.')) ?? 0;

        // 1. Guardar la compra en Firestore
        await _db.collection('purchases').add({
          'productoId': selectedProduct!.id,
          'nombreProducto': selectedProduct!.nombre,
          'descripcion': selectedProduct!.nombre,
          'cantidad': cant,
          'costoUnitarioUSD': costoU > 0 ? costoU : (cant > 0 ? monto / cant : 0),
          'montoUSD': monto,
          'totalCostoUSD': monto,
          'proveedor': prov,
          'fecha': Timestamp.now(),
        });

        // 2. Alimentar el inventario (incrementar el stock del producto)
        final updateData = <String, dynamic>{
          'stock': FieldValue.increment(cant),
        };
        if (costoU > 0) {
          updateData['costoUSD'] = costoU;
        }
        await _db.collection('products').doc(selectedProduct!.id).update(updateData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Compra registrada: +$cant unid. a "${selectedProduct!.nombre}"'),
              backgroundColor: AppColors.secondary,
            ),
          );
        }
      } else {
        // Compra no inventariada / general
        await _db.collection('purchases').add({
          'descripcion': descripcionCtrl.text.trim(),
          'nombreProducto': descripcionCtrl.text.trim(),
          'proveedor': prov,
          'montoUSD': monto,
          'totalCostoUSD': monto,
          'fecha': Timestamp.now(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Compra registrada exitosamente')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras de Mercancía'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarCompra,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva Compra', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('purchases').orderBy('fecha', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final purchases = snapshot.data?.docs ?? [];
          if (purchases.isEmpty) {
            return const Center(
              child: Text(
                'No hay compras registradas',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
            itemCount: purchases.length,
            itemBuilder: (context, i) {
              final p = purchases[i].data();
              final desc = (p['descripcion'] ?? p['nombreProducto'] as String?) ?? 'Compra';
              final prov = (p['proveedor'] as String?) ?? '';
              final cant = (p['cantidad'] as num?)?.toInt();
              final monto = (p['montoUSD'] ?? p['totalCostoUSD'] as num?)?.toDouble() ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.shopping_cart, color: AppColors.primary),
                  ),
                  title: Text(desc, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    [
                      if (cant != null && cant > 0) '$cant unid.',
                      if (prov.isNotEmpty) 'Proveedor: $prov' else 'Sin proveedor',
                    ].join(' • '),
                  ),
                  trailing: Text(
                    '\$${monto.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
