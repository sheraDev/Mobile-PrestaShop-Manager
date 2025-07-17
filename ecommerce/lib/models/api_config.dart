import 'package:flutter/material.dart';

class ApiConfig extends ChangeNotifier {
  String _apiKey = '';
  String _apiUrl = '';

  String get apiKey => _apiKey;
  String get apiUrl => _apiUrl;

  void update(String apiKey, String apiUrl) 
  {
    _apiKey = apiKey.trim();
   // _apiUrl = apiUrl.trim()+'/api';
   _apiUrl = apiUrl.trim();
    if (_apiUrl.endsWith('/')) {
      _apiUrl = _apiUrl.substring(0, _apiUrl.length - 1);
    }
    _apiUrl += '/api';

    notifyListeners();
  }
}