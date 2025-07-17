import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert' show utf8, base64;
import 'package:provider/provider.dart';
import '../models/api_config.dart';
import 'order_detail_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String id;

  const CustomerDetailScreen({required this.id});

  @override
  _CustomerDetailScreenState createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  bool _loading = true;
  Map<String, String> _customer = {};
  List<Map<String, String>> _orders = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCustomerDetails());
  }

  Future<void> _loadCustomerDetails() async {
    final apiConfig = Provider.of<ApiConfig>(context, listen: false);
    final auth = 'Basic ${base64.encode(utf8.encode('${apiConfig.apiKey}:'))}';
    final customerUrl = '${apiConfig.apiUrl}/customers/${widget.id}';
    final ordersUrl = '${apiConfig.apiUrl}/orders?filter[id_customer]=[${widget.id}]';

    try {
      // Infos client
      final customerRes = await http.get(Uri.parse(customerUrl), headers: {'Authorization': auth});
      if (customerRes.statusCode != 200) throw Exception("Erreur chargement client");

      final customerDoc = XmlDocument.parse(customerRes.body);
      final customer = customerDoc.findAllElements('customer').first;
      final firstname = customer.findElements('firstname').first.text;
      final lastname = customer.findElements('lastname').first.text;
      final email = customer.findElements('email').first.text;

      // Commandes
      final ordersRes = await http.get(Uri.parse(ordersUrl), headers: {'Authorization': auth});
      if (ordersRes.statusCode != 200) throw Exception("Erreur chargement commandes");

      final ordersDoc = XmlDocument.parse(ordersRes.body);
      final orderElements = ordersDoc.findAllElements('order');

      final futures = orderElements.map((e) async {
        final id = e.getAttribute('id') ?? '';
        final detailUrl = '${apiConfig.apiUrl}/orders/$id';

        final detailRes = await http.get(Uri.parse(detailUrl), headers: {'Authorization': auth});
        if (detailRes.statusCode != 200) return null;

        final detailDoc = XmlDocument.parse(detailRes.body);
        final order = detailDoc.findAllElements('order').first;

        return {
          'id': id,
          'reference': order.findElements('reference').first.text,
          'total': order.findElements('total_paid_tax_incl').first.text,
          'date': order.findElements('date_add').first.text,
        };
      });

      final results = await Future.wait(futures);

      setState(() {
        _customer = {'firstname': firstname, 'lastname': lastname, 'email': email};
        _orders = results.whereType<Map<String, String>>().toList();
        _loading = false;
      });
    } catch (e) {
      print("Erreur: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = '${_customer['firstname'] ?? ''} ${_customer['lastname'] ?? ''}';

    return Scaffold(
      appBar: AppBar(title: Text('Client #${widget.id}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📋 Informations Client', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _infoRow('Prénom', _customer['firstname']),
                  _infoRow('Nom', _customer['lastname']),
                  _infoRow('Email', _customer['email']),
                  const SizedBox(height: 24),
                  const Text('🧾 Commandes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(),
                  if (_orders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('Aucune commande', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                    )
                  else
                    ..._orders.map((o) => Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long, color: Colors.blue),
                            title: Text('Commande #${o['id']}'),
                            subtitle: Text('Réf: ${o['reference']} • ${o['date']}'),
                            trailing: Text('${(double.tryParse(o['total'] ?? '0') ?? 0).toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailScreen(id: o['id']!),
                                ),
                              );
                            },
                          ),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? '', style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
