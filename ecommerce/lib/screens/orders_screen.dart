import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert' show utf8, base64;
import 'package:provider/provider.dart';
import '../models/api_config.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, String>> _orders = [];
  bool _loading = true;

  List<Map<String, String>> _filteredOrders = [];
  String _searchQuery = '';

  List<String> _statusLabels = ['Tous'];
  String _selectedStatus = 'Tous';

  String _sortOrder = 'desc';


    void _sortFilteredOrders() {
  _filteredOrders.sort((a, b) {
    final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(0);
    final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(0);
    return _sortOrder == 'asc'
        ? dateA.compareTo(dateB)
        : dateB.compareTo(dateA);
    });
  }



  void _filterOrders(String query) {
    setState(() {
      _filteredOrders = _orders.where((order) {
        final id = (order['id'] ?? '').toLowerCase();
        final reference = (order['name'] ?? '').toLowerCase();
        final status = (order['statusName'] ?? 'Inconnu').toLowerCase();
        final q = query.toLowerCase();

        final matchesQuery = id.contains(q) || reference.contains(q);
        final matchesStatus = _selectedStatus == 'Tous' || status == _selectedStatus.toLowerCase();

        return matchesQuery && matchesStatus;
      }).toList();

      _sortFilteredOrders();
    });
  }




  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchOrders(context);
    });
  }

  Future<void> fetchOrders(BuildContext context) async {
    final apiConfig = Provider.of<ApiConfig>(context, listen: false);
    final apiKey = apiConfig.apiKey;
    final baseUrl = apiConfig.apiUrl;
    final ordersUrl = '$baseUrl/orders';
    final auth = 'Basic ${base64.encode(utf8.encode('$apiKey:'))}';

    final res = await http.get(Uri.parse(ordersUrl), headers: {'Authorization': auth});

    if (res.statusCode == 200) {
      final xmlDoc = XmlDocument.parse(res.body);
      final orderElements = xmlDoc.findAllElements('order');

      final futures = orderElements.map((order) async {
        final id = order.getAttribute('id') ?? '';
        final detailUrl = '$ordersUrl/$id';
        final detailRes = await http.get(Uri.parse(detailUrl), headers: {'Authorization': auth});

        if (detailRes.statusCode == 200) {
          final detailXml = XmlDocument.parse(detailRes.body);
          final reference = detailXml.findAllElements('reference').first.text;
          final stateId = detailXml.findAllElements('current_state').first.text;
          final date = detailXml.findAllElements('date_add').first.text;

          final stateUrl = '$baseUrl/order_states/$stateId';
          final stateRes = await http.get(Uri.parse(stateUrl), headers: {'Authorization': auth});

          String stateName = 'Inconnu';
          if (stateRes.statusCode == 200) {
            final stateXml = XmlDocument.parse(stateRes.body);
            final nameElement = stateXml.findAllElements('name').first;
            stateName = nameElement.findElements('language').first.text;
          }

          return {
            'id': id,
            'name': reference,
            'statusName': stateName,
            'date': date,
          };
        } else {
          return null;
        }
      });

      final results = await Future.wait(futures);
      final validOrders = results.whereType<Map<String, String>>().toList();

      final statusSet = <String>{'Tous'};
      for (var order in results.whereType<Map<String, String>>()) {
        final status = order['statusName'] ?? 'Inconnu';
        statusSet.add(status);
      }


      setState(() {
         _orders = results.whereType<Map<String, String>>().toList();
        //_orders = validOrders;
        _filteredOrders = validOrders;
          _statusLabels = statusSet.toList();
        _loading = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement commandes : ${res.statusCode}')),
      );
      setState(() => _loading = false);
    }
  }

  Color getStatusColor(String statusName) {
    final name = statusName.toLowerCase();
    if (name.contains('préparation') || name.contains('en cours')) return Colors.orange;
    if (name.contains('livré')) return Colors.blue;
    if (name.contains('annulé')) return Colors.red;
    if (name.contains('rembourse')) return Colors.purple;
    if (name.contains('paiement')) return Colors.green;
    return Colors.grey;
  }

  String formatDate(String dateTime) {
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📦 Commandes')),


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
        onChanged: _filterOrders,
        decoration: InputDecoration(
          hintText: 'Rechercher une commande...',
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
        value: _selectedStatus,
        onChanged: (value) {
          setState(() {
            _selectedStatus = value!;
            _filterOrders('');
          });
        },
        items: _statusLabels.map((status) {
          return DropdownMenuItem(
            value: status,
            child: Text(status == 'Tous' ? 'Tous les statuts' : status),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: 'Filtrer par statut',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _sortOrder,
        onChanged: (value) {
          setState(() {
            _sortOrder = value!;
            _sortFilteredOrders();
          });
        },
        items: const [
          DropdownMenuItem(
            value: 'desc',
            child: Text('Plus récent en premier'),
          ),
          DropdownMenuItem(
            value: 'asc',
            child: Text('Plus ancien en premier'),
          ),
        ],
        decoration: InputDecoration(
          labelText: 'Trier par date',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    ],
  ),
),
          Expanded(
            child: _filteredOrders.isEmpty
                ? const Center(child: Text('Aucune commande trouvée.', style: TextStyle(fontSize: 18)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = _filteredOrders[index];
                      final statusLabel = order['statusName'] ?? 'Inconnu';
                      final statusColor = getStatusColor(statusLabel);
                      final date = formatDate(order['date'] ?? '');

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: CircleAvatar(
                            backgroundColor: statusColor,
                            child: Text(
                              statusLabel[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            'Commande #${order['name']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text('Statut: $statusLabel\nDate: $date'),
                          isThreeLine: true,
                          trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderDetailScreen(
                                  id: order['id'] ?? '',
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
