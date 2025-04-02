import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // TODO: Move base URL to config/env
  static const String _baseUrl = 'http://10.0.2.2:3000/api/v1';

  // Helper to get the auth token
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Helper to create authenticated headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // --- Mood Endpoints --- 

  // GET /moods
  static Future<http.Response> getMoods() async {
    final url = Uri.parse('$_baseUrl/moods');
    final headers = await _getHeaders();
    return http.get(url, headers: headers);
  }

  // POST /moods
  static Future<http.Response> addMood(Map<String, dynamic> moodData) async {
    final url = Uri.parse('$_baseUrl/moods');
    final headers = await _getHeaders();
    return http.post(
      url,
      headers: headers,
      body: json.encode(moodData),
    );
  }

  // PUT /moods/:id
  static Future<http.Response> updateMood(int id, Map<String, dynamic> moodData) async {
    final url = Uri.parse('$_baseUrl/moods/$id');
    final headers = await _getHeaders();
    return http.put(
      url,
      headers: headers,
      body: json.encode(moodData),
    );
  }

  // DELETE /moods/:id
  static Future<http.Response> deleteMood(int id) async {
    final url = Uri.parse('$_baseUrl/moods/$id');
    final headers = await _getHeaders();
    return http.delete(url, headers: headers);
  }

  // --- Auth Endpoints (can also be moved here if desired) --- 
  // Example: static Future<http.Response> login(String email, String password) { ... }
} 