import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/api_config.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int totalOrders = 0;
  double totalRevenue = 0;
  int outOfStockProducts = 0;
  int totalCustomers = 0;

  Map<String, int> ordersPerDay = {};
  Map<String, double> revenuePerDay = {};

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final apiConfig = Provider.of<ApiConfig>(context, listen: false);
    final auth = 'Basic ${base64.encode(utf8.encode('${apiConfig.apiKey}:'))}';

    try {
      final ordersUrl = '${apiConfig.apiUrl}/orders?display=full';
      final ordersRes = await http.get(Uri.parse(ordersUrl), headers: {'Authorization': auth});
      if (ordersRes.statusCode == 200) {
        final ordersDoc = XmlDocument.parse(ordersRes.body);
        final orders = ordersDoc.findAllElements('order');
        totalOrders = 0;
        totalRevenue = 0;
        ordersPerDay.clear();
        revenuePerDay.clear();

        for (final orderElem in orders) {
          totalOrders++;
          final totalPaid = double.tryParse(orderElem.getElement('total_paid')?.text ?? '0') ?? 0;
          totalRevenue += totalPaid;

          final date = orderElem.getElement('date_add')?.text;
          if (date != null) {
            final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(date));
            ordersPerDay[formattedDate] = (ordersPerDay[formattedDate] ?? 0) + 1;
            revenuePerDay[formattedDate] = (revenuePerDay[formattedDate] ?? 0) + totalPaid;
          }
        }
      }

      final productsUrl = '${apiConfig.apiUrl}/products?display=full';
      final productsRes = await http.get(Uri.parse(productsUrl), headers: {'Authorization': auth});
      if (productsRes.statusCode == 200) {
        final productsDoc = XmlDocument.parse(productsRes.body);
        final products = productsDoc.findAllElements('product');
        outOfStockProducts = 0;

        for (final product in products) {
          final id = product.getElement('id')?.text;
          if (id == null) continue;

          final stockUrl = '${apiConfig.apiUrl}/stock_availables?filter[id_product]=[$id]&display=full';
          final stockRes = await http.get(Uri.parse(stockUrl), headers: {'Authorization': auth});
          if (stockRes.statusCode == 200) {
            final stockDoc = XmlDocument.parse(stockRes.body);
            final stockItems = stockDoc.findAllElements('stock_available');

            XmlElement? matchingStock;
            for (final stock in stockItems) {
              if (stock.getElement('id_product')?.text == id) {
                matchingStock = stock;
                break;
              }
            }

            final quantity = int.tryParse(matchingStock?.getElement('quantity')?.text ?? '0') ?? 0;
            if (quantity <= 0) outOfStockProducts++;
          }
        }
      }

      final customersUrl = '${apiConfig.apiUrl}/customers?display=full';
      final customersRes = await http.get(Uri.parse(customersUrl), headers: {'Authorization': auth});
      if (customersRes.statusCode == 200) {
        final customersDoc = XmlDocument.parse(customersRes.body);
        totalCustomers = customersDoc.findAllElements('customer').length;
      }

      setState(() {});
    } catch (e) {
      print('Erreur récupération dashboard: $e');
    }
  }

  List<FlSpot> _mapDataToSpots(Map<String, num> data) {
    final sortedKeys = data.keys.toList()..sort();
    return List.generate(sortedKeys.length, (index) {
      final key = sortedKeys[index];
      return FlSpot(index.toDouble(), data[key]!.toDouble());
    });
  }

  List<String> _mapKeysToLabels(Map<String, num> data) {
    final sortedKeys = data.keys.toList()..sort();
    return sortedKeys.map((d) => DateFormat('dd/MM').format(DateTime.parse(d))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final revenueSpots = _mapDataToSpots(revenuePerDay);
    final ordersSpots = _mapDataToSpots(ordersPerDay);

    final revenueLabels = _mapKeysToLabels(revenuePerDay);
    final ordersLabels = _mapKeysToLabels(ordersPerDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prestashop Dashboard'),
        leading: const Icon(Icons.home),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    _statCard('Commandes', totalOrders.toString(), Colors.blue.shade100, Colors.blue),
                    _statCard('Revenu', '${totalRevenue.toStringAsFixed(0)} €', Colors.green.shade100, Colors.green),
                    _statCard('En rupture', outOfStockProducts.toString(), Colors.red.shade100, Colors.red),
                    _statCard('Clients', totalCustomers.toString(), Colors.purple.shade100, Colors.purple),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 300,
                child: _buildGraph(
                  revenueSpots,
                  revenueLabels,
                  'Revenus par jour',
                  Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: _buildGraph(
                  ordersSpots,
                  ordersLabels,
                  'Commandes par jour',
                  Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, Color bgColor, Color textColor) {
    return SizedBox(
      width: 140,
      height: 100,
      child: Card(
        elevation: 4,
        color: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraph(List<FlSpot> spots, List<String> labels, String title, Color color) {
    if (spots.isEmpty) {
      return Center(child: Text('Pas de données', style: TextStyle(color: color)));
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: spots.map((e) => e.y).fold(0.0, (prev, y) => y > prev ? y : prev) * 1.2,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (spots.length / (labels.length < 6 ? labels.length : 6)).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index < 0 || index >= labels.length) return const SizedBox.shrink();
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(labels[index], style: TextStyle(color: color, fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.3)),
                      dotData: FlDotData(show: false),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
