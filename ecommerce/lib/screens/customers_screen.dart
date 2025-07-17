import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert' show utf8, base64;
import 'package:provider/provider.dart';
import '../models/api_config.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  @override
  _CustomersScreenState createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  bool _loading = true;
  List<Map<String, String>> _customers = [];
  List<Map<String, String>> _filteredCustomers = [];
  String _searchQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCustomers());
  }

  Future<void> _fetchCustomers() async {
    final apiConfig = Provider.of<ApiConfig>(context, listen: false);
    final auth = 'Basic ${base64.encode(utf8.encode('${apiConfig.apiKey}:'))}';
    final apiUrl = '${apiConfig.apiUrl}/customers';

    try {
      final res = await http.get(Uri.parse(apiUrl), headers: {'Authorization': auth});
      if (res.statusCode != 200) throw Exception("Erreur lors du chargement des clients.");

      final doc = XmlDocument.parse(res.body);
      final elements = doc.findAllElements('customer');

      final futures = elements.map((e) async {
        final id = e.getAttribute('id') ?? '';
        final detailUrl = '$apiUrl/$id';
        final detailRes = await http.get(Uri.parse(detailUrl), headers: {'Authorization': auth});
        if (detailRes.statusCode != 200) return null;

        final detailDoc = XmlDocument.parse(detailRes.body);
        final customer = detailDoc.findAllElements('customer').first;
        final firstName = customer.findElements('firstname').first.text;
        final lastName = customer.findElements('lastname').first.text;

        return {'id': id, 'firstname': firstName, 'lastname': lastName};
      });

      final results = await Future.wait(futures);
      setState(() {
        _customers = results.whereType<Map<String, String>>().toList();
        _filteredCustomers = _customers;
        _loading = false;
      });
    } catch (e) {
      print("Erreur : $e");
      setState(() {
        _loading = false;
        _error = "Impossible de charger les clients.";
      });
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredCustomers = _customers.where((customer) {
        final id = customer['id']?.toLowerCase() ?? '';
        final firstName = customer['firstname']?.toLowerCase() ?? '';
        final lastName = customer['lastname']?.toLowerCase() ?? '';
        return id.contains(_searchQuery) || firstName.contains(_searchQuery) || lastName.contains(_searchQuery);
      }).toList();
    });
  }


  Widget _buildCustomerCard(Map<String, String> customer) {
    final initials = (customer['firstname']!.isNotEmpty ? customer['firstname']![0] : '') +
        (customer['lastname']!.isNotEmpty ? customer['lastname']![0] : '');

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo,
          child: Text(initials.toUpperCase(), style: TextStyle(color: Colors.white)),
        ),
        title: Text('${customer['firstname']} ${customer['lastname']}',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('ID: ${customer['id']}'),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerDetailScreen(id: customer['id']!),
            ),
          );
        },
      ),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text('📁 Clients')),
    body: _loading
      ? Center(child: CircularProgressIndicator())
      : _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
          : _customers.isEmpty
              ? Center(child: Text('Aucun client trouvé.'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        onChanged: _filterCustomers,
                        decoration: InputDecoration(
                          hintText: 'Rechercher par nom ou ID...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchCustomers,
                        child: ListView.builder(
                          padding: EdgeInsets.only(top: 12),
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            return _buildCustomerCard(_filteredCustomers[index]);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
  );
}

}
