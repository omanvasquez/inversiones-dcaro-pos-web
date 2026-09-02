import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _productService = ProductService();
  String _search = '';
  ProductCategory? _selectedCategory;

  Future<void> _showProductDialog([Product? product]) async {
    final isEditing = product != null;
    final nombreCtrl = TextEditingController(text: product?.nombre ?? '');
    final codigoCtrl = TextEditingController(text: product?.codigoBarras ?? '');
    final stockCtrl = TextEditingController(text: product != null ? product.stock.toString() : '0');
    final costoCtrl = TextEditingController(text: product != null ? product.costoUSD.toString() : '0');
    final precioCtrl = TextEditingController(text: product != null ? product.precioUSD.toString() : '0');
    ProductCategory cat = product?.categoria ?? ProductCategory.cuadernos;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del Producto *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codigoCtrl,
                    decoration: const InputDecoration(labelText: 'Código de Barras / Ref'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProductCategory>(
                    initialValue: cat,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: ProductCategory.values.map((c) {
                      return DropdownMenuItem(value: c, child: Text(catToString(c)));
                    }).toList(),
                    onChanged: (v) => setDlg(() => cat = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: costoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Costo USD', prefixText: '\$ '),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: precioCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Precio de Venta USD *', prefixText: '\$ '),
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
                if (nombreCtrl.text.trim().isEmpty || precioCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(isEditing ? 'Actualizar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      if (!mounted) return;
      final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
      final costo = double.tryParse(costoCtrl.text.replaceAll(',', '.')) ?? 0;
      final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.')) ?? 0;
      final cfg = context.read<ConfigService>();
      final tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;

      if (isEditing) {
        await FirebaseFirestore.instance.collection('products').doc(product.id).update({
          'nombre': nombreCtrl.text.trim(),
          'codigoBarras': codigoCtrl.text.trim(),
          'categoria': catToString(cat),
          'stock': stock,
          'costoUSD': costo,
          'precioUSD': precio,
          'precioBs': precio * tasa,
        });
      } else {
        final newProd = Product(
          id: '',
          nombre: nombreCtrl.text.trim(),
          codigoBarras: codigoCtrl.text.trim(),
          categoria: cat,
          stock: stock,
          costoUSD: costo,
          precioUSD: precio,
          precioBs: precio * tasa,
          activo: true,
          creadoEn: Timestamp.now(),
        );
        await _productService.create(newProd);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Producto actualizado' : 'Producto creado')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigService>();
    final double tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario de Productos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Producto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o código...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Todos'),
                        selected: _selectedCategory == null,
                        onSelected: (_) => setState(() => _selectedCategory = null),
                      ),
                      const SizedBox(width: 8),
                      ...ProductCategory.values.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(catToString(cat)),
                            selected: _selectedCategory == cat,
                            onSelected: (sel) {
                              setState(() => _selectedCategory = sel ? cat : null);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _productService.streamActivos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var prods = snapshot.data ?? [];
                if (_search.isNotEmpty) {
                  prods = prods.where((p) =>
                    p.nombre.toLowerCase().contains(_search) ||
                    p.codigoBarras.toLowerCase().contains(_search)
                  ).toList();
                }

                if (_selectedCategory != null) {
                  prods = prods.where((p) => p.categoria == _selectedCategory).toList();
                }

                if (prods.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            'No se encontraron productos',
                            style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Presiona el botón "Nuevo Producto" para registrar mercancía.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    int crossAxisCount = 1;
                    if (width >= 1200) {
                      crossAxisCount = 4;
                    } else if (width >= 900) {
                      crossAxisCount = 3;
                    } else if (width >= 600) {
                      crossAxisCount = 2;
                    }

                    if (crossAxisCount == 1) {
                      return ListView.builder(
                        padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 80),
                        itemCount: prods.length,
                        itemBuilder: (context, i) {
                          final p = prods[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${catToString(p.categoria)} • Stock: ${p.stock}\nCosto: \$${p.costoUSD.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${p.precioUSD.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    'Bs ${(p.precioUSD * tasa).toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              onTap: () => _showProductDialog(p),
                            ),
                          );
                        },
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 80),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: prods.length,
                      itemBuilder: (context, i) {
                        final p = prods[i];
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showProductDialog(p),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.nombre,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: p.stock > 5
                                              ? AppColors.secondary.withValues(alpha: 0.12)
                                              : AppColors.danger.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Stock: ${p.stock}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: p.stock > 5 ? AppColors.secondary : AppColors.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    catToString(p.categoria),
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '\$${p.precioUSD.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          Text(
                                            'Bs ${(p.precioUSD * tasa).toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                      const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
