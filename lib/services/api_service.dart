import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // A base URL agora é configurável via construtor. Passe a URL do seu backend
  // ao criar uma instância de ApiService. O valor padrão é localhost para
  // facilitar desenvolvimento local.
  final String _baseUrl;

  ApiService({String? baseUrl}) : _baseUrl = baseUrl ?? 'http://localhost:8080/api';

  Future<Map<String, dynamic>> get(String endpoint) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('GET $uri failed: ${response.statusCode} ${response.reasonPhrase}');
    }
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('POST $uri failed: ${response.statusCode} ${response.reasonPhrase}');
    }
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final response = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('PUT $uri failed: ${response.statusCode} ${response.reasonPhrase}');
    }
  }

  Future<void> delete(String endpoint) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final response = await http.delete(uri);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('DELETE $uri failed: ${response.statusCode} ${response.reasonPhrase}');
    }
  }
}

