import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert' show utf8, base64;
import 'dart:typed_data';
import 'package:provider/provider.dart';
import '../models/api_config.dart';

class ProductDetailScreen extends StatefulWidget {
  final String id;

  const ProductDetailScreen({Key? key, required this.id}) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _loading = true;
  String _name = '';
  String _category = 'Inconnue';
  String _price = '0.00';
  String _quantity = '0';
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }

  Future<void> _fetchProductDetails() async {
    final apiConfig = Provider.of<ApiConfig>(context, listen: false);
    final auth = 'Basic ${base64.encode(utf8.encode('${apiConfig.apiKey}:'))}';

    try {
      // === 1. Récupération des infos produit ===
      final productUrl = '${apiConfig.apiUrl}/products/${widget.id}';
      final productRes = await http.get(Uri.parse(productUrl), headers: {'Authorization': auth});
      if (productRes.statusCode != 200) throw Exception('Erreur chargement produit');
      final productDoc = XmlDocument.parse(productRes.body);

      // Nom
      final nameElem = productDoc.findAllElements('name').firstOrNull;
      if (nameElem != null) {
        final langElem = nameElem.findElements('language').firstOrNull;
        if (langElem != null) _name = langElem.text;
      }

      // Catégorie
      final categoryId = productDoc.findAllElements('id_category_default').first.text;

      // Prix
      final priceElem = productDoc.findAllElements('price').firstOrNull;
      if (priceElem != null) _price = priceElem.text;

      // === 2. Nom de catégorie ===
      if (categoryId.isNotEmpty) {
        final categoryUrl = '${apiConfig.apiUrl}/categories/$categoryId';
        final catRes = await http.get(Uri.parse(categoryUrl), headers: {'Authorization': auth});
        if (catRes.statusCode == 200) {
          final catDoc = XmlDocument.parse(catRes.body);
          final catNameElem = catDoc.findAllElements('name').firstOrNull;
          if (catNameElem != null) {
            final langElem = catNameElem.findElements('language').firstOrNull;
            if (langElem != null) _category = langElem.text;
          }
        }
      }

      // === 3. Récupération du stock total ===
      final stockListUrl = '${apiConfig.apiUrl}/stock_availables?filter[id_product]=${widget.id}';
      final stockListRes = await http.get(Uri.parse(stockListUrl), headers: {'Authorization': auth});

      if (stockListRes.statusCode == 200) {
        final stockListDoc = XmlDocument.parse(stockListRes.body);
        final stockElems = stockListDoc.findAllElements('stock_available');

        int totalQuantity = 0;

        for (var stockRef in stockElems) {
          final href = stockRef.getAttribute('xlink:href');
          if (href != null) {
            final stockDetailRes = await http.get(Uri.parse(href), headers: {'Authorization': auth});
            if (stockDetailRes.statusCode == 200) {
              final stockDetailDoc = XmlDocument.parse(stockDetailRes.body);
              final stockElem = stockDetailDoc.findAllElements('stock_available').firstOrNull;
              if (stockElem != null) {
                final qtyText = stockElem.getElement('quantity')?.text ?? '0';
                final qty = int.tryParse(qtyText) ?? 0;
                totalQuantity += qty;
              }
            }
          }
        }

        _quantity = totalQuantity.toString();
      }

      // === 4. Image produit ===
      final imageIdElem = productDoc.findAllElements('id_default_image').firstOrNull;
      if (imageIdElem != null) {
        final imageId = imageIdElem.text;
        final imageUrl = '${apiConfig.apiUrl}/images/products/${widget.id}/$imageId';
        final imageRes = await http.get(Uri.parse(imageUrl), headers: {'Authorization': auth});
        if (imageRes.statusCode == 200) {
          _imageBytes = imageRes.bodyBytes;
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      print('Erreur détails produit: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_loading ? 'Chargement...' : _name),
        //backgroundColor: Colors.teal,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _imageBytes != null
                        ? Image.memory(_imageBytes!, height: 240, fit: BoxFit.cover)
                        : Container(
                            height: 240,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      _name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Catégorie : $_category',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _infoBox(Icons.inventory_2_outlined, 'Stock', _quantity, Colors.orange),
                      _infoBox(Icons.euro_outlined, 'Prix', '${double.tryParse(_price)?.toStringAsFixed(2) ?? _price} €', Colors.green),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoBox(IconData icon, String label, String value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// Extensions utiles
extension XmlExtensions on XmlElement {
  XmlElement? get firstOrNull => children.whereType<XmlElement>().firstOrNull;
}

extension IterableExtensions<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
