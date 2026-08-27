import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../services/product_service.dart';
import '../services/sale_service.dart';
import '../models/product.dart';
import '../models/sale.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'config_screen.dart';
import 'dashboard_screen.dart';
import 'compras_screen.dart';
import 'gastos_screen.dart';
import 'reportes_semanal_screen.dart';
import 'reportes_mensual_screen.dart';
import '../services/closure_service.dart';
import '../theme/app_theme.dart';

const _posPrimary = AppColors.primary;
const _posSecondary = AppColors.accent;
const _posSurface = AppColors.surface;
const _posBorder = AppColors.border;

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _productService = ProductService();
  final _saleService = SaleService();
  Map<String, int> cart = {};
  Map<String, Product> cartProducts = {};
  String search = '';

  Future<void> _cerrarDia() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar día'),
        content: const Text(
            'Se guardará el cierre con los valores históricos de hoy.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar cierre')),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await ClosureService().closeDay(DateTime.now());
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cierre diario guardado')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo cerrar el día: $error')));
    }
  }

  double get totalUSD {
    double t = 0;
    cart.forEach((id, cant) {
      t += (cartProducts[id]?.precioUSD ?? 0) * cant;
    });
    return t;
  }

  void _addToCart(Product p) {
    if (p.stock <= (cart[p.id] ?? 0)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sin stock: ${p.nombre}')));
      return;
    }
    setState(() {
      cart[p.id] = (cart[p.id] ?? 0) + 1;
      cartProducts[p.id] = p;
    });
  }

  Future<void> _cobrar(double tasa) async {
    if (cart.isEmpty) return;
    const metodos = {
      'efectivo_dolar': 'Efectivo dólar',
      'efectivo_bolivar': 'Efectivo bolívar',
      'pago_movil': 'Pago móvil',
      'punto_venta': 'Punto de venta',
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
          final recibidoUSD = esBolivar ? recibido / tasa : recibido;
          final vueltoUSD =
              (recibidoUSD - totalUSD).clamp(0, double.infinity).toDouble();

          return AlertDialog(
            title: Text(
                'Cobrar \$${totalUSD.toStringAsFixed(2)} / Bs ${(totalUSD * tasa).toStringAsFixed(2)}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: metodo,
                    decoration:
                        const InputDecoration(labelText: 'Método de pago'),
                    items: metodos.entries
                        .map((entry) => DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)))
                        .toList(),
                    onChanged: (value) => setSt(() {
                      metodo = value!;
                      error = null;
                      recibidoController.clear();
                      recibido = 0;
                    }),
                  ),
                  if (esEfectivo) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: recibidoController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText:
                            esBolivar ? 'Recibido en Bs' : 'Recibido en USD',
                        prefixText: esBolivar ? 'Bs ' : '\$ ',
                        errorText: error,
                      ),
                      onChanged: (value) => setSt(() {
                        recibido =
                            double.tryParse(value.replaceAll(',', '.')) ?? 0;
                        error = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                      'Vuelto: \$${vueltoUSD.toStringAsFixed(2)} / Bs ${(vueltoUSD * tasa).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: _posPrimary)),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  if (esEfectivo && recibidoUSD < totalUSD) {
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

    final items = cart.entries
        .map((e) => SaleItem(
              productoId: e.key,
              nombre: cartProducts[e.key]!.nombre,
              cantidad: e.value,
              precioUSD: cartProducts[e.key]!.precioUSD,
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
      cart.clear();
      cartProducts.clear();
    });
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Venta registrada')));
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigService>();
    final double tasa = cfg.tasaBCV == 0 ? 780 : cfg.tasaBCV;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _posPrimary,
          primary: _posPrimary,
          secondary: _posSecondary,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _posPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: _posBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: _posBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: _posPrimary, width: 1.5),
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _posBorder),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _posSecondary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(cfg.nombreNegocio),
          actions: [
            Center(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('BCV: $tasa'))),
            IconButton(
                icon: const Icon(Icons.inventory_2),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InventoryScreen()))),
            IconButton(
                onPressed: () => context.read<AuthService>().logout(),
                icon: const Icon(Icons.logout)),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: AppColors.primaryDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SvgPicture.asset('web/assets/dcaro_logo.svg',
                      width: 52, height: 36, fit: BoxFit.contain),
                    const SizedBox(height: 12),
                    const Text('Inversiones D\'Caro',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Papelería - Las Vegas',
                        style: TextStyle(
                            color: Colors.white.withOpacity(.75),
                            fontSize: 13)),
                  ],
                ),
              ),
              ListTile(
                  title: const Text('Dashboard'),
                  leading: const Icon(Icons.dashboard),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DashboardScreen()));
                  }),
              ListTile(
                  title: const Text('Punto de Venta'),
                  leading: const Icon(Icons.point_of_sale),
                  onTap: () => Navigator.pop(context)),
              ListTile(
                  title: const Text('Inventario'),
                  leading: const Icon(Icons.inventory),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const InventoryScreen()));
                  }),
              ListTile(
                  title: const Text('Compras'),
                  leading: const Icon(Icons.shopping_cart),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ComprasScreen()));
                  }),
              ListTile(
                  title: const Text('Gastos'),
                  leading: const Icon(Icons.receipt_long),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GastosScreen()));
                  }),
              ListTile(
                  title: const Text('Reportes / Cierre'),
                  leading: const Icon(Icons.bar_chart),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReportsScreen()));
                  }),
              ListTile(
                  title: const Text('Cerrar día'),
                  leading: const Icon(Icons.lock_clock),
                  onTap: () {
                    Navigator.pop(context);
                    _cerrarDia();
                  }),
              ListTile(
                  title: const Text('Reporte semanal'),
                  leading: const Icon(Icons.date_range),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReportesSemanalScreen()));
                  }),
              ListTile(
                  title: const Text('Reporte mensual'),
                  leading: const Icon(Icons.calendar_month),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReportesMensualScreen()));
                  }),
              ListTile(
                  title: const Text('Configurar Tasa'),
                  leading: const Icon(Icons.settings),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ConfigScreen()));
                  }),
            ],
          ),
        ),
        body: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                        decoration: const InputDecoration(
                            labelText: 'Buscar producto...',
                            prefixIcon: Icon(Icons.search)),
                        onChanged: (v) =>
                            setState(() => search = v.toLowerCase())),
                  ),
                  Expanded(
                    child: StreamBuilder<List<Product>>(
                      stream: _productService.streamActivos(),
                      builder: (ctx, snap) {
                        if (!snap.hasData)
                          return const Center(
                              child: CircularProgressIndicator());
                        var prods = snap.data!
                            .where((p) =>
                                p.nombre.toLowerCase().contains(search) ||
                                p.codigoBarras.contains(search))
                            .toList();
                        if (prods.isEmpty)
                          return const Center(
                              child: Text(
                                  'No hay productos. Ve a Inventario + para agregar'));
                        return GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3, childAspectRatio: 2.5),
                          itemCount: prods.length,
                          itemBuilder: (_, i) {
                            final p = prods[i];
                            return Card(
                              child: InkWell(
                                onTap: () => _addToCart(p),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p.nombre,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(
                                          '${p.categoria.name} - Stock: ${p.stock}',
                                          style: const TextStyle(fontSize: 12)),
                                      const Spacer(),
                                      Text(
                                          '\$${p.precioUSD.toStringAsFixed(2)} / Bs ${(p.precioUSD * tasa).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              color: _posPrimary,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                color: _posSurface,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Text('Carrito (${cart.length})',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _posPrimary)),
                    ),
                    Expanded(
                      child: ListView(
                        children: cart.entries.map((e) {
                          final p = cartProducts[e.key]!;
                          return ListTile(
                            title: Text(p.nombre),
                            subtitle: Text('\$${p.precioUSD} x ${e.value}'),
                            trailing: IconButton(
                                icon: const Icon(Icons.remove_circle),
                                onPressed: () =>
                                    setState(() => cart.remove(e.key))),
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total USD:'),
                                Text('\$${totalUSD.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _posPrimary))
                              ]),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Bs:'),
                                Text(
                                    'Bs ${(totalUSD * tasa).toStringAsFixed(2)}',
                                    style: const TextStyle(color: _posPrimary))
                              ]),
                          const SizedBox(height: 12),
                          SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                  onPressed: () => _cobrar(tasa),
                                  child: const Text('COBRAR'))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
