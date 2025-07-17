import 'package:ecommerce/screens/orders_to_prepare_screen.dart';
import 'package:ecommerce/screens/orders_to_ship_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert' show base64, utf8;
import 'package:provider/provider.dart';
import '../models/api_config.dart';
import 'low_stock_screen.dart';


class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  int? lowStockCount;
  int? ordersToPrepareCount;
  int? ordersToShipCount;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([
      _fetchLowStockCount(),
      _fetchOrdersToPrepareCount(),
      _fetchOrdersToShipCount(),
    ]);
    setState(() => _loading = false);
  }

Future<void> _fetchLowStockCount() async {
  try {
    final apiConfig = Provider.of<ApiConfig>(context, listen: false);
    final auth = 'Basic ${base64.encode(utf8.encode('${apiConfig.apiKey}:'))}';

    final productsRes = await http.get(
      Uri.parse('${apiConfig.apiUrl}/products?display=[id]'),
      headers: {'Authorization': auth},
    );
    if (productsRes.statusCode != 200) throw Exception('Erreur récupération produits');

    final productsDoc = XmlDocument.parse(productsRes.body);
    final productIds = productsDoc
        .findAllElements('product')
        .map((e) => e.getElement('id')?.text)
        .whereType<String>()
        .toList();

    int totalLowStock = 0;
    const batchSize = 5;

    //  récupérer le stock d'un produit
    Future<int> fetchStockForProduct(String productId) async {
      final stockRes = await http.get(
        Uri.parse('${apiConfig.apiUrl}/stock_availables?filter[id_product]=[$productId]&display=[quantity,id_product_attribute]'),
        headers: {'Authorization': auth},
      );

      if (stockRes.statusCode != 200) {
        print('Erreur récupération stock produit $productId');
        return 0;
      }

      final stockDoc = XmlDocument.parse(stockRes.body);
      final stockElements = stockDoc.findAllElements('stock_available');

      int lowStockCount = 0;
      for (final stock in stockElements) {
        final attr = stock.getElement('id_product_attribute')?.text ?? 'null';
        final qtyText = stock.getElement('quantity')?.text ?? 'null';
        final quantity = int.tryParse(qtyText) ?? -1;

        if (quantity >= 0 && quantity < 15 && attr == '0') {
          lowStockCount++;
        }
      }
      return lowStockCount;
    }

    for (int i = 0; i < productIds.length; i += batchSize) {
      final batch = productIds.skip(i).take(batchSize).toList();
      final results = await Future.wait(batch.map(fetchStockForProduct));
      totalLowStock += results.fold(0, (a, b) => a + b);
    }

    setState(() => lowStockCount = totalLowStock);
  } catch (e) {
    print(' Erreur lors du comptage des stocks bas : $e');
    setState(() => lowStockCount = 0);
  }
}

  Future<void> _fetchOrdersToPrepareCount() async {
    try {
      final api = Provider.of<ApiConfig>(context, listen: false);
      final auth = 'Basic ${base64.encode(utf8.encode('${api.apiKey}:'))}';
      final res = await http.get(
        Uri.parse('${api.apiUrl}/orders?display=[id,current_state]'),
        headers: {'Authorization': auth},
      );

      if (res.statusCode != 200) throw Exception('Erreur chargement commandes');

      final doc = XmlDocument.parse(res.body);
      final orders = doc.findAllElements('order');

      int count = 0;
      for (var order in orders) {
        final state = order.getElement('current_state')?.text;
        if (state == '2') count++; // Paiement accepté
      }

      setState(() => ordersToPrepareCount = count);
    } catch (e) {
      print('Erreur commandes à préparer : $e');
      setState(() => ordersToPrepareCount = 0);
    }
  }

  Future<void> _fetchOrdersToShipCount() async {
    try {
      final api = Provider.of<ApiConfig>(context, listen: false);
      final auth = 'Basic ${base64.encode(utf8.encode('${api.apiKey}:'))}';
      final res = await http.get(
        Uri.parse('${api.apiUrl}/orders?display=[id,current_state]'),
        headers: {'Authorization': auth},
      );

      if (res.statusCode != 200) throw Exception('Erreur chargement commandes');

      final doc = XmlDocument.parse(res.body);
      final orders = doc.findAllElements('order');

      int count = 0;
      for (var order in orders) {
        final state = order.getElement('current_state')?.text;
        if (state == '3') count++; // Statut expédition
      }

      setState(() => ordersToShipCount = count);
    } catch (e) {
      print('Erreur commandes à expédier : $e');
      setState(() => ordersToShipCount = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📋 Tâches"),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TaskItem(
                  title: 'Commandes à préparer',
                  subtitle: 'Préparez les commandes payées.',
                  badgeCount: ordersToPrepareCount ?? 0,
                  icon: Icons.inventory_2_outlined,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrdersToPrepareScreen()),
                    );
                  },
                ),
                TaskItem(
                  title: 'Commandes à expédier',
                  subtitle: 'Expédiez les commandes préparées.',
                  badgeCount: ordersToShipCount ?? 0,
                  icon: Icons.local_shipping_outlined,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrdersToShipScreen()),
                    );
                  },
                ),
                TaskItem(
                  title: 'Produits à réapprovisionner',
                  subtitle: 'Consultez les produits à faible stock.',
                  badgeCount: lowStockCount ?? 0,
                  icon: Icons.warning_amber_rounded,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LowStockScreen()),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class TaskItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badgeCount;
  final IconData icon;
  final Color color;

  const TaskItem({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.badgeCount,
    required this.icon,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeCount.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
