import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../models/api_config.dart';
import 'order_detail_screen.dart'; 


class OrdersToPrepareScreen extends StatefulWidget {
  const OrdersToPrepareScreen({super.key});

  @override
  State<OrdersToPrepareScreen> createState() => _OrdersToPrepareScreenState();
}

class _OrdersToPrepareScreenState extends State<OrdersToPrepareScreen> {
  List<Map<String, String>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final api = Provider.of<ApiConfig>(context, listen: false);
      final auth = 'Basic ${base64.encode(utf8.encode('${api.apiKey}:'))}';
      final url = '${api.apiUrl}/orders';

      final res = await http.get(Uri.parse('$url?display=[id,date_add,total_paid,id_customer,current_state]'), headers: {
        'Authorization': auth,
      });

      if (res.statusCode != 200) throw Exception("Erreur chargement commandes");

      final doc = XmlDocument.parse(res.body);
      final orders = doc.findAllElements('order');

      final futures = orders.map((e) async {
        final id = e.getElement('id')?.text ?? '';
        final date = e.getElement('date_add')?.text ?? '';
        final total = e.getElement('total_paid')?.text ?? '';
        final state = e.getElement('current_state')?.text ?? '';
        final customerId = e.getElement('id_customer')?.text ?? '';

        if (state != '2') return null; // Paiement accepté 

        final customerRes = await http.get(Uri.parse('${api.apiUrl}/customers/$customerId'),
            headers: {'Authorization': auth});
        if (customerRes.statusCode != 200) return null;

        final customerDoc = XmlDocument.parse(customerRes.body);
        final first = customerDoc.findAllElements('firstname').first.text;
        final last = customerDoc.findAllElements('lastname').first.text;

        return {
          'id': id,
          'date': date.split(' ')[0],
          'total': total,
          'customer': '$first $last',
        };
      });

      final results = await Future.wait(futures);
      setState(() {
        _orders = results.whereType<Map<String, String>>().toList();
        _loading = false;
      });
    } catch (e) {
      print("Erreur API: $e");
      setState(() => _loading = false);
    }
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("📦 Commandes à préparer"),
      centerTitle: false,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _orders.isEmpty
            ? const Center(child: Text("Aucune commande à préparer 👌"))
            : ListView.separated(
                itemCount: _orders.length,
                padding: const EdgeInsets.all(16),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      tileColor: Theme.of(context).cardColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailScreen(id: order['id'] ?? ''),
                          ),
                        );
                      },
                      title: Text(
                        "Commande #${order['id']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text("📋 Client : ${order['customer']}"),
                          Text("🗓️ Date : ${order['date']}"),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                             // "💶 ${order['total']} €",
                              "💶 ${double.parse(order['total'] ?? '0').toStringAsFixed(2)} €",
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  );
                },
              ),
  );
}

}
