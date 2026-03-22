// lib/providers/locale_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_lang';
  String _lang = 'en';
  String get lang => _lang;
  bool   get isNepali => _lang == 'ne';

  LocaleProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved != _lang) {
      _lang = saved;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    _lang = _lang == 'en' ? 'ne' : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _lang);
    notifyListeners();
  }

  Future<void> set(String l) async {
    if (l == _lang) return;
    _lang = l;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _lang);
    notifyListeners();
  }
}
