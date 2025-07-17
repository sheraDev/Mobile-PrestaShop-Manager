import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert' show utf8, base64;
import 'package:provider/provider.dart';
import '../models/api_config.dart';
import 'product_detail_screen.dart';

class LowStockScreen extends StatefulWidget {
  const LowStockScreen({super.key});

  @override
  State<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  bool _loading = true;
  List<Map<String, String>> _products = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchLowStock());
  }

  Future<void> _fetchLowStock() async {
    final apiConfig = Provider.of<ApiConfig>(context, listen: false);
    final auth = 'Basic ${base64.encode(utf8.encode('${apiConfig.apiKey}:'))}';

    try {
      // Récupérer les produits avec nom
      final productsRes = await http.get(
        Uri.parse('${apiConfig.apiUrl}/products?display=[id,name]'),
        headers: {'Authorization': auth},
      );
      if (productsRes.statusCode != 200) throw Exception("Erreur produits");

      final productsDoc = XmlDocument.parse(productsRes.body);
      final productElements = productsDoc.findAllElements('product');

      List<Map<String, String>> lowStockProducts = [];

      for (var p in productElements) {
        final id = p.getElement('id')?.text ?? '';
        final name = p.getElement('name')?.text ?? '';

        if (id.isEmpty) continue;

        // Stock sans suivre les hrefs
        final stockRes = await http.get(
          Uri.parse('${apiConfig.apiUrl}/stock_availables?filter[id_product]=[$id]&display=[quantity,id_product_attribute]'),
          headers: {'Authorization': auth},
        );
        if (stockRes.statusCode != 200) continue;

        final stockDoc = XmlDocument.parse(stockRes.body);
        final stockElements = stockDoc.findAllElements('stock_available');

        // On cherche le stock sans attribut (produit simple)
        final stockElem = stockElements.firstWhere(
          (e) => e.getElement('id_product_attribute')?.text == '0',
          orElse: () => XmlElement(XmlName('')),
        );

        if (stockElem.name.toString() != '') {
          final quantity = int.tryParse(stockElem.getElement('quantity')?.text ?? '0') ?? 0;
          if (quantity < 15) {
            lowStockProducts.add({
              'id': id,
              'name': name,
              'quantity': quantity.toString(),
            });
          }
        }
      }

      setState(() {
        _products = lowStockProducts;
        _loading = false;
      });
    } catch (e) {
      print("Erreur: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🧯 Faible stock"),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text("Aucun produit à faible stock."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade100,
                          child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
                        ),
                        title: Text(
                          product['name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "Stock actuel : ${product['quantity']}",
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${product['quantity']}",
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                id: product['id']!,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
