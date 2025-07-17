// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert' show utf8, base64;
import 'package:provider/provider.dart';
import '../models/api_config.dart';
import 'product_detail_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String id;

  const OrderDetailScreen({required this.id});

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _loading = true;
  Map<String, String> _order = {};
  List<Map<String, String>> _products = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrder();
    });
  }

  Future<void> _loadOrder() async {
    final apiConfig = Provider.of<ApiConfig>(context, listen: false);
    final auth = 'Basic ${base64.encode(utf8.encode('${apiConfig.apiKey}:'))}';
    final orderUrl = '${apiConfig.apiUrl}/orders/${widget.id}';

    try {
      final res = await http.get(Uri.parse(orderUrl), headers: {'Authorization': auth});
      if (res.statusCode != 200) throw Exception("Erreur chargement commande");

      final doc = XmlDocument.parse(res.body);
      final order = doc.findAllElements('order').first;

      final customerId = order.findElements('id_customer').first.text;
      final addressId = order.findElements('id_address_delivery').first.text;
      final stateId = order.findElements('current_state').first.text;

      // Récup nom état
      final stateRes = await http.get(Uri.parse('${apiConfig.apiUrl}/order_states/$stateId'),
          headers: {'Authorization': auth});
      final stateDoc = XmlDocument.parse(stateRes.body);
      final stateName = stateDoc.findAllElements('language').first.text;

      // Récup nom client
      final customerRes = await http.get(Uri.parse('${apiConfig.apiUrl}/customers/$customerId'),
          headers: {'Authorization': auth});
      final customerDoc = XmlDocument.parse(customerRes.body);
      final firstname = customerDoc.findAllElements('firstname').first.text;
      final lastname = customerDoc.findAllElements('lastname').first.text;
      final fullName = '$firstname $lastname';

      // Récup adresse
      final addressRes = await http.get(Uri.parse('${apiConfig.apiUrl}/addresses/$addressId'),
          headers: {'Authorization': auth});
      final addressDoc = XmlDocument.parse(addressRes.body);
      final address1 = addressDoc.findAllElements('address1').first.text;
      final city = addressDoc.findAllElements('city').first.text;
      final address = '$address1, $city';

      final orderData = {
        'id': order.findElements('id').first.text,
        'reference': order.findElements('reference').first.text,
        'delivery': address,
        'customer': fullName,
        'total': order.findElements('total_paid_tax_incl').first.text,
        'payment': order.findElements('payment').first.text,
        'state': stateName,
        'date': order.findElements('date_add').first.text,
      };

      // Produits
      final productElements = order.findAllElements('order_row');
      final products = productElements.map((row) {
        return {
          'id': row.findElements('product_id').first.text,
          'name': row.findElements('product_name').first.text.trim(),
          'quantity': row.findElements('product_quantity').first.text,
          'price': row.findElements('unit_price_tax_incl').first.text,
        };
      }).toList();

      setState(() {
        _order = orderData;
        _products = products;
        _loading = false;
      });
    } catch (e) {
      print('Erreur: $e');
      setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande #${widget.id}')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📁 Fiche commande',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _infoRow(Icons.confirmation_number, 'Référence', _order['reference']),
                          _infoRow(Icons.assignment, 'Client', _order['customer']),
                          _infoRow(Icons.location_on, 'Adresse', _order['delivery']),
                          _infoRow(Icons.payment, 'Paiement', _order['payment']),
                          _infoRow(Icons.euro, 'Total TTC', '${double.parse(_order['total'] ?? '0').toStringAsFixed(2)} €'),
                          _infoRow(Icons.flag, 'État', _order['state']),
                          _infoRow(Icons.calendar_today, 'Date', _order['date']),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text('🛒 Produits',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Divider(),
                  ..._products.map((p) => Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: Icon(Icons.shopping_bag, color: Colors.blue),
                          title: Text(p['name'] ?? ''),
                          subtitle: Text('Quantité: ${p['quantity']}'),
                          trailing: Text('${double.parse(p['price'] ?? '0').toStringAsFixed(2)} €'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(
                                  id: p['id'] ?? '',
                                 // name: p['name'] ?? '',
                                ),
                              ),
                            );
                          },
                        ),
                      ))
                ],
              ),
            ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(value ?? '', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
