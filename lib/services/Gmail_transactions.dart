// lib/services/gmail_backend.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GmailBackend {
  static const _base = 'https://pocketplanner-backend-0seo.onrender.com';   // 🖉

  /// Abre la URL raíz para lanzar el login
  static Uri get authUrl => Uri.parse('$_base/');

  /// Llama a /transactions tras el login
  static Future<List<Map<String, dynamic>>> fetchTransactions() async {
    final res = await http.get(Uri.parse('$_base/transactions'));
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['transactions'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  
}
