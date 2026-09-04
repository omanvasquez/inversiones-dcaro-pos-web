import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../services/product_service.dart';
import '../services/sale_service.dart';
import '../services/closure_service.dart';
import '../services/report_service.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../theme/app_theme.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'config_screen.dart';
import 'dashboard_screen.dart';
import 'compras_screen.dart';
import 'gastos_screen.dart';
import 'clients_screen.dart';
import 'reportes_semanal_screen.dart';
import 'reportes_mensual_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _productService = ProductService();
  final _saleService = SaleService();
  final _closureService = ClosureService();

  final Map<String, int> _cart = {};
  final Map<String, Product> _cartProducts = {};
  String _search = '';
  ProductCategory? _selectedCategory;

  double get totalUSD {
    double t = 0;
    _cart.forEach((id, cant) {
      t += (_cartProducts[id]?.precioUSD ?? 0) * cant;
    });
    return t;
  }

  int get totalItems {
    int count = 0;
    _cart.forEach((_, cant) => count += cant);
    return count;
  }

  void _addToCart(Product p) {
    final currentQty = _cart[p.id] ?? 0;
    if (p.stock <= currentQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sin stock suficiente: ${p.nombre} (Disponibles: ${p.stock})'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _cart[p.id] = currentQty + 1;
      _cartProducts[p.id] = p;
    });
  }

  void _decrementInCart(String id) {
    setState(() {
      final currentQty = _cart[id] ?? 0;
      if (currentQty > 1) {
        _cart[id] = currentQty - 1;
      } else {
        _cart.remove(id);
        _cartProducts.remove(id);
      }
    });
  }

  void _removeFromCart(String id) {
    setState(() {
      _cart.remove(id);
      _cartProducts.remove(id);
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _cartProducts.clear();
    });
  }

  Future<void> _cerrarDia() async {
    final cfg = context.read<ConfigService>();
    final tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;

    ReportData? summary;
    try {
      summary = await _closureService.getDaySummary(DateTime.now(), tasa);
    } catch (_) {}

    if (!mounted) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cierre de Caja Diario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Deseas generar y guardar el cierre de caja del día de hoy?',
              style: TextStyle(fontSize: 14),
            ),
            if (summary != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _resumenFila(
                      'Ventas de Hoy:',
                      '\$${summary.totalVentasUSD.toStringAsFixed(2)} (${summary.totalTransacciones} ventas)',
                    ),
                    const SizedBox(height: 4),
                    _resumenFila(
                      'Gastos del Día:',
                      '-\$${summary.totalGastosUSD.toStringAsFixed(2)}',
                      color: summary.totalGastosUSD > 0 ? AppColors.danger : null,
                    ),
                    const SizedBox(height: 4),
                    _resumenFila(
                      'Compras del Día:',
                      '-\$${summary.totalComprasUSD.toStringAsFixed(2)}',
                      color: summary.totalComprasUSD > 0 ? AppColors.warning : null,
                    ),
                    const Divider(height: 12),
                    _resumenFila(
                      'Ganancia Neta:',
                      '\$${summary.gananciaNetaUSD.toStringAsFixed(2)}',
                      bold: true,
                      color: summary.gananciaNetaUSD >= 0 ? AppColors.secondary : AppColors.danger,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar y Guardar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await _closureService.closeDay(DateTime.now(), tasaBCV: tasa);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cierre diario guardado exitosamente'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar el día: $error'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Widget _resumenFila(String label, String value, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color ?? AppColors.primaryDark,
          ),
        ),
      ],
    );
  }

  Future<void> _cobrar(double tasa) async {
    if (_cart.isEmpty) return;

    const metodos = {
      'efectivo_dolar': 'Efectivo Dólar (\$)',
      'efectivo_bolivar': 'Efectivo Bolívar (Bs)',
      'pago_movil': 'Pago Móvil (Bs)',
      'punto_venta': 'Punto de Venta (Bs)',
      'fiado': 'Fiado / Cuenta por Cobrar',
    };

    String metodo = 'efectivo_dolar';
    final recibidoController = TextEditingController();
    double recibido = 0;
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          final esBolivar = metodo == 'efectivo_bolivar';
          final esEfectivo = metodo == 'efectivo_dolar' || esBolivar;
          final recibidoUSD = esBolivar ? (tasa > 0 ? recibido / tasa : 0) : recibido;
          final vueltoUSD = (recibidoUSD - totalUSD).clamp(0, double.infinity).toDouble();

          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Cobrar Venta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '\$${totalUSD.toStringAsFixed(2)}  /  Bs ${(totalUSD * tasa).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: metodo,
                      decoration: const InputDecoration(labelText: 'Método de pago'),
                      items: metodos.entries
                          .map((entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ))
                          .toList(),
                      onChanged: (value) => setSt(() {
                        metodo = value!;
                        error = null;
                        recibidoController.clear();
                        recibido = 0;
                      }),
                    ),
                    if (esEfectivo) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: recibidoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: esBolivar ? 'Monto Recibido en Bs' : 'Monto Recibido en USD',
                          prefixText: esBolivar ? 'Bs ' : '\$ ',
                          errorText: error,
                        ),
                        onChanged: (value) => setSt(() {
                          recibido = double.tryParse(value.replaceAll(',', '.')) ?? 0;
                          error = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Vuelto:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '\$${vueltoUSD.toStringAsFixed(2)} / Bs ${(vueltoUSD * tasa).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  if (esEfectivo && recibidoUSD < totalUSD && recibido > 0) {
                    setSt(() => error = 'El monto recibido es menor al total');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Confirmar Venta'),
              ),
            ],
          );
        },
      ),
    );

    recibidoController.dispose();
    if (ok != true) return;

    final items = _cart.entries
        .map((e) => SaleItem(
              productoId: e.key,
              nombre: _cartProducts[e.key]!.nombre,
              cantidad: e.value,
              precioUSD: _cartProducts[e.key]!.precioUSD,
            ))
        .toList();

    final sale = Sale(
      id: '',
      fecha: Timestamp.now(),
      cajeroId: FirebaseAuth.instance.currentUser?.uid ?? 'owner',
      clienteId: null,
      items: items,
      subtotalUSD: totalUSD,
      totalUSD: totalUSD,
      totalBs: totalUSD * tasa,
      tasaBCV: tasa,
      metodoPago: metodo,
      creadoEn: Timestamp.now(),
    );

    await _saleService.createSale(sale);

    setState(() {
      _cart.clear();
      _cartProducts.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Venta registrada con éxito!'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  void _showMobileCart(double tasa) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Carrito ($totalItems items)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (_cart.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          _clearCart();
                          setModalState(() {});
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                        label: const Text('Vaciar', style: TextStyle(color: AppColors.danger, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: _cart.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('El carrito está vacío', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: _cart.entries.map((e) {
                          final p = _cartProducts[e.key]!;
                          final subtotal = p.precioUSD * e.value;

                          return ListTile(
                            title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('\$${p.precioUSD.toStringAsFixed(2)} x ${e.value} = \$${subtotal.toStringAsFixed(2)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary, size: 22),
                                  onPressed: () {
                                    _decrementInCart(e.key);
                                    setModalState(() {});
                                    setState(() {});
                                    if (_cart.isEmpty) Navigator.pop(ctx);
                                  },
                                ),
                                Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
                                  onPressed: () {
                                    _addToCart(p);
                                    setModalState(() {});
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total USD:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          '\$${totalUSD.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Bs:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        Text(
                          'Bs ${(totalUSD * tasa).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _cart.isEmpty
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _cobrar(tasa);
                              },
                        child: const Text('COBRAR AHORA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primaryDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SvgPicture.asset(
                  'web/assets/dcaro_logo.svg',
                  width: 52,
                  height: 36,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Inversiones D\'Caro',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Papelería y Variedades',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Dashboard'),
            leading: const Icon(Icons.dashboard_outlined, color: AppColors.primary),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
            },
          ),
          ListTile(
            title: const Text('Punto de Venta'),
            leading: const Icon(Icons.point_of_sale, color: AppColors.primary),
            selected: true,
            selectedTileColor: AppColors.primaryLight,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            title: const Text('Inventario'),
            leading: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
            },
          ),
          ListTile(
            title: const Text('Clientes y Fiado'),
            leading: const Icon(Icons.people_outline, color: AppColors.primary),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen()));
            },
          ),
          ListTile(
            title: const Text('Compras'),
            leading: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ComprasScreen()));
            },
          ),
          ListTile(
            title: const Text('Gastos'),
            leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GastosScreen()));
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Historial de Ventas'),
            leading: const Icon(Icons.bar_chart_outlined, color: AppColors.primary),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
            },
          ),
          ListTile(
            title: const Text('Cerrar Día'),
            leading: const Icon(Icons.lock_clock_outlined, color: AppColors.secondary),
            onTap: () {
              Navigator.pop(context);
              _cerrarDia();
            },
          ),
          ListTile(
            title: const Text('Reporte Semanal'),
            leading: const Icon(Icons.date_range_outlined, color: AppColors.primary),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportesSemanalScreen()));
            },
          ),
          ListTile(
            title: const Text('Reporte Mensual'),
            leading: const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportesMensualScreen()));
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Configuración'),
            leading: const Icon(Icons.settings_outlined, color: AppColors.primary),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigScreen()));
            },
          ),
          ListTile(
            title: const Text('Cerrar Sesión'),
            leading: const Icon(Icons.logout, color: AppColors.danger),
            onTap: () {
              Navigator.pop(context);
              context.read<AuthService>().logout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Product> prods, double tasa, int crossAxisCount) {
    if (prods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 54, color: AppColors.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const Text(
                'No hay productos que coincidan',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: crossAxisCount == 1 ? 2.8 : (crossAxisCount == 2 ? 1.4 : 1.6),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: prods.length,
      itemBuilder: (_, i) {
        final p = prods[i];
        final inCart = _cart[p.id] ?? 0;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _addToCart(p),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (inCart > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$inCart',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${catToString(p.categoria)} • Stock: ${p.stock}',
                    style: TextStyle(
                      fontSize: 11,
                      color: p.stock > 0 ? AppColors.textSecondary : AppColors.danger,
                      fontWeight: p.stock > 0 ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$${p.precioUSD.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Bs ${(p.precioUSD * tasa).toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_shopping_cart, size: 16, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopCart(double tasa) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Carrito ($totalItems items)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
                if (_cart.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger),
                    tooltip: 'Vaciar Carrito',
                    onPressed: _clearCart,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 10),
                        const Text(
                          'El carrito está vacío',
                          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Haz clic en un producto para agregarlo',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: _cart.entries.map((e) {
                      final p = _cartProducts[e.key]!;
                      final subtotal = p.precioUSD * e.value;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.nombre,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '\$${p.precioUSD.toStringAsFixed(2)} c/u • \$${subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 18),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    onPressed: () => _decrementInCart(e.key),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${e.value}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 18),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    onPressed: () => _addToCart(p),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    onPressed: () => _removeFromCart(e.key),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total USD:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      '\$${totalUSD.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Bs:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text(
                      'Bs ${(totalUSD * tasa).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _cart.isEmpty ? null : () => _cobrar(tasa),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('COBRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigService>();
    final double tasa = cfg.tasaBCV == 0 ? 780.0 : cfg.tasaBCV;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return Scaffold(
          appBar: AppBar(
            title: Text(cfg.nombreNegocio),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    'BCV: $tasa',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (isMobile)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart),
                      onPressed: () => _showMobileCart(tasa),
                    ),
                    if (totalItems > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$totalItems',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              IconButton(
                icon: const Icon(Icons.inventory_2_outlined),
                tooltip: 'Inventario',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryScreen()),
                ),
              ),
            ],
          ),
          drawer: _buildDrawer(context),
          bottomNavigationBar: isMobile && _cart.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalItems items • \$${totalUSD.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            Text(
                              'Bs ${(totalUSD * tasa).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showMobileCart(tasa),
                        icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                        label: const Text('Ver / Cobrar'),
                      ),
                    ],
                  ),
                )
              : null,
          body: Row(
            children: [
              Expanded(
                flex: isMobile ? 1 : 3,
                child: Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Buscar producto...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _search.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => setState(() => _search = ''),
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                FilterChip(
                                  label: const Text('Todos'),
                                  selected: _selectedCategory == null,
                                  onSelected: (_) => setState(() => _selectedCategory = null),
                                ),
                                const SizedBox(width: 6),
                                ...ProductCategory.values.map((cat) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
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
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          var prods = snap.data ?? [];
                          if (_search.isNotEmpty) {
                            prods = prods.where((p) =>
                              p.nombre.toLowerCase().contains(_search) ||
                              p.codigoBarras.toLowerCase().contains(_search)
                            ).toList();
                          }

                          if (_selectedCategory != null) {
                            prods = prods.where((p) => p.categoria == _selectedCategory).toList();
                          }

                          int gridCols = 1;
                          if (!isMobile) {
                            final catalogWidth = constraints.maxWidth * 0.6;
                            if (catalogWidth >= 700) {
                              gridCols = 4;
                            } else if (catalogWidth >= 500) {
                              gridCols = 3;
                            } else {
                              gridCols = 2;
                            }
                          } else {
                            if (constraints.maxWidth >= 550) {
                              gridCols = 3;
                            } else if (constraints.maxWidth >= 360) {
                              gridCols = 2;
                            } else {
                              gridCols = 1;
                            }
                          }

                          return _buildProductGrid(prods, tasa, gridCols);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Expanded(
                  flex: 2,
                  child: _buildDesktopCart(tasa),
                ),
            ],
          ),
        );
      },
    );
  }
}
