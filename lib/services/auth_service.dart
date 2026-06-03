import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String loginUrl =
      "https://jinntv.com/login_app.php";

  static Future<bool> login(String email, String password) async {
    final response = await http.post(
      Uri.parse(loginUrl),
      body: {
        'email': email,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      return response.body.contains("pass");
    }
    return false;
  }
}
