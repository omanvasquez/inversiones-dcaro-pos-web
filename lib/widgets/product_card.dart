import 'package:flutter/material.dart';
import '../models/product.dart';
class ProductCard extends StatelessWidget {
  final Product product; final VoidCallback? onTap;
  const ProductCard({super.key, required this.product, this.onTap});
  @override Widget build(BuildContext context){ return Card(child: ListTile(title: Text(product.nombre), subtitle: Text('${catToString(product.categoria)} - Stock: ${product.stock}'), trailing: Text('\$${product.precioUSD.toStringAsFixed(2)}'), onTap: onTap)); }
}
