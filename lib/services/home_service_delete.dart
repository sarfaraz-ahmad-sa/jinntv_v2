import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeService {
  static const String baseUrl = "https://jinntv.com/api_forApp/home.php";

  static Future<Map<String, dynamic>> fetchHome() async {
    final res = await http.get(Uri.parse("$baseUrl"));
    if (res.statusCode != 200) throw Exception("Home API failed");
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
