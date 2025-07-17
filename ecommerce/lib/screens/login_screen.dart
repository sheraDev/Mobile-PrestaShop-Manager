import 'package:flutter/material.dart';
import '../models/api_config.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' show utf8, base64;

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _apikey;
  late final TextEditingController _apiUrl;

  @override
  void initState() {
    _apikey = TextEditingController();
    _apiUrl = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _apiUrl.dispose();
    _apikey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion à PrestaShop')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 32),

              TextField(
                controller: _apiUrl,
                decoration: InputDecoration(
                  labelText: 'URL de PrestaShop',
                  hintText: 'https://myshop.com',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _apikey,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Clé API',
                  hintText: '176383FGD79847497DD29',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (_apikey.text.isNotEmpty && _apiUrl.text.isNotEmpty) {
                    String apiKey = _apikey.text.trim();
                    String apiUrl = _apiUrl.text.trim();
                    
                    if (apiUrl.endsWith('/')) {
                      apiUrl = apiUrl.substring(0, apiUrl.length - 1);
                    }
                    final fullUrl = '$apiUrl/api';
                    final auth = 'Basic ${base64.encode(utf8.encode('$apiKey:'))}';

                    try {
                      final response = await http.get(
                        Uri.parse(fullUrl),
                        headers: {'Authorization': auth},
                      );

                      if (response.statusCode == 200) {
                        Provider.of<ApiConfig>(context, listen: false).update(apiKey, apiUrl);
                        Navigator.pushReplacementNamed(context, '/home');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Connexion refusée : ${response.statusCode}\nURL: $fullUrl'),
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur de connexion : ${e.toString()}')),
                      );
                    }
                  }
                },
                child: const Text('Se connecter', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
