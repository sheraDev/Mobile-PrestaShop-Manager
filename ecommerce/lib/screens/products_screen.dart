import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert' show utf8, base64;
import 'dart:typed_data'; 
import 'package:provider/provider.dart';
import '../models/api_config.dart';
import 'product_detail_screen.dart';

class ProductsScreen extends StatefulWidget {
  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {

void _filterProducts(String query) {
  setState(() {
    _filteredProducts = _products.where((product) {
      final name = (product['name'] ?? '').toLowerCase();
      final id = (product['id'] ?? '').toLowerCase();
      final category = product['category'] ?? '';
      final q = query.toLowerCase();

      final matchesQuery = name.contains(q) || id.contains(q);
      final matchesCategory = _selectedCategory == 'Toutes' || category == _selectedCategory;

      return matchesQuery && matchesCategory;
    }).toList();
  });
}



  //List<Map<String, dynamic>> _products = [];
    List<Map<String, dynamic>> _products = [];
    List<Map<String, dynamic>> _filteredProducts = [];

    bool _loading = true;
    String _selectedCategory = 'Toutes';
    List<String> _categories = ['Toutes'];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchProducts(context);
    });
  }

  Future<void> fetchProducts(BuildContext context) async {
    final apiConfig = Provider.of<ApiConfig>(context, listen: false);
    final apiKey = apiConfig.apiKey;
    final baseApiUrl = apiConfig.apiUrl;
    final apiUrl = '$baseApiUrl/products';

    final authHeader = 'Basic ${base64.encode(utf8.encode('$apiKey:'))}';
    final res = await http.get(Uri.parse(apiUrl), headers: {'Authorization': authHeader});

    if (res.statusCode == 200) {
      final xmlDoc = XmlDocument.parse(res.body);
      final productElements = xmlDoc.findAllElements('product');

      final futures = productElements.map((product) async {
        final id = product.getAttribute('id') ?? '';
        final detailUrl = '$apiUrl/$id';

        final detailRes = await http.get(Uri.parse(detailUrl), headers: {'Authorization': authHeader});
        if (detailRes.statusCode == 200) {
          final detailXml = XmlDocument.parse(detailRes.body);
          final nameElement = detailXml.findAllElements('name').first;
          final name = nameElement.findElements('language').first.text;

          //final categoryElement = detailXml.findAllElements('id_category_default').firstOrNull;
          //final category = categoryElement?.text ?? 'Inconnue';

          final categoryElement = detailXml.findAllElements('id_category_default').firstOrNull;
          final categoryId = categoryElement?.text;
          String categoryName = 'Inconnue';

          if (categoryId != null && categoryId.isNotEmpty) {
            final categoryUrl = '$baseApiUrl/categories/$categoryId';
            final categoryRes = await http.get(Uri.parse(categoryUrl), headers: {'Authorization': authHeader});

            if (categoryRes.statusCode == 200) {
              final categoryXml = XmlDocument.parse(categoryRes.body);
              final nameElement = categoryXml.findAllElements('name').firstOrNull;
              if (nameElement != null) {
                final langElement = nameElement.findElements('language').firstOrNull;
                if (langElement != null) {
                  categoryName = langElement.text;
                }
              }
            }
          }


          // récupération image
          final imageElement = detailXml.findAllElements('id_default_image').firstOrNull;
          Uint8List? imageBytes;

          if (imageElement != null && imageElement.text.isNotEmpty) {
            final imageId = imageElement.text;
            final imageUrl = '$baseApiUrl/images/products/$id/$imageId';

            try {
              final imageRes = await http.get(Uri.parse(imageUrl), headers: {'Authorization': authHeader});
              if (imageRes.statusCode == 200) {
                imageBytes = imageRes.bodyBytes;
              }
            } catch (_) {
            }
          }

          return {
            'id': id,
            'name': name,
            'image': imageBytes,
            'category': categoryName,
          };
        } else {
          return null;
        }
      });

      final results = await Future.wait(futures);

      final products = results.whereType<Map<String, dynamic>>().toList();

      final categories = <String>{'Toutes'};
      for (var p in products) {
        final cat = p['category'] ?? 'Inconnue';
        categories.add(cat);
      }


      setState(() {
         _products = products;
        _filteredProducts = products;
        _categories = categories.toList();
        _loading = false;
        //_products = results.whereType<Map<String, dynamic>>().toList();
        //_loading = false;
      });


    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des produits')),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🛒 Produits')),
      body: _loading
    ? const Center(child: CircularProgressIndicator())
    : Column(
        children: [
          Padding(
  padding: const EdgeInsets.all(12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        onChanged: _filterProducts,
        decoration: InputDecoration(
          hintText: 'Rechercher un produit...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[200],
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _selectedCategory,
        onChanged: (value) {
          setState(() {
            _selectedCategory = value!;
            _filterProducts('');
          });
        },
        items: _categories.map((cat) {
          return DropdownMenuItem(
            value: cat,
            child: Text(cat == 'Toutes' ? 'Toutes les catégories' : 'Catégorie $cat'),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: 'Filtrer par catégorie',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        isExpanded: true,
      ),
    ],
  ),
),
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(child: Text('Aucun produit trouvé.', style: TextStyle(fontSize: 18)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final imageBytes = product['image'] as Uint8List?;

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: imageBytes != null ? MemoryImage(imageBytes) : null,
                            child: imageBytes == null
                                ? const Icon(Icons.image_not_supported, color: Colors.grey)
                                : null,
                          ),
                          title: Text(
                            product['name'] ?? 'Sans nom',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text('ID: ${product['id']}'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(
                                  id: product['id'] ?? '',
                                  //name: product['name'] ?? '',
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
