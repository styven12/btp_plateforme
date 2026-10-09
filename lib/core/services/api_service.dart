import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiService.baseUrl;

  static final ApiService instance = ApiService();
  static const String _tokenKey = 'auth_token';
  static const String _roleKey = 'user_role';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static final String baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : kIsWeb || defaultTargetPlatform != TargetPlatform.android
      ? 'http://localhost:3000/api'
      : 'http://10.0.2.2:3000/api';

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) => _request('POST', path, body: body);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) => _request('PATCH', path, body: body);

  Future<Map<String, dynamic>> uploadProjectImage({
    required String projectId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final normalizedBaseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final uri = Uri.parse('$normalizedBaseUrl/uploads/project-image');
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..fields['projectId'] = projectId
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ),
      );
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    late final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 60)),
      );
    } on TimeoutException {
      throw const ApiException(
        'Le téléversement a dépassé le délai de 60 secondes.',
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        'Serveur API injoignable ($uri) : ${error.message}. '
        'Sur un téléphone physique, configurez API_BASE_URL avec l’adresse IP '
        'de votre ordinateur et vérifiez le pare-feu.',
      );
    }

    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw ApiException(
            'Réponse serveur invalide (${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }
        data = decoded;
      } on FormatException {
        throw ApiException(
          'Réponse serveur illisible (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message'] is String
            ? data['message'] as String
            : 'Le téléversement de l’image a échoué.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final normalizedBaseUrl = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBaseUrl$normalizedPath');
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    late final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
        case 'POST':
          response = await _client
              .post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 15));
        case 'PATCH':
          response = await _client
              .patch(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 15));
        default:
          throw const ApiException('Méthode HTTP non prise en charge.');
      }
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Le serveur API ne répond pas ($uri).');
    } on http.ClientException catch (error) {
      throw ApiException('Serveur API injoignable ($uri) : ${error.message}.');
    }

    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw ApiException(
            'Réponse serveur invalide (${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }
        data = decoded;
      } on FormatException {
        throw ApiException(
          'Réponse serveur illisible (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message'] is String
            ? data['message'] as String
            : 'Une erreur est survenue.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<void> saveToken(String token, {String? role}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
    if (role != null) await preferences.setString(_roleKey, role);
  }

  Future<String?> get savedRole async =>
      (await SharedPreferences.getInstance()).getString(_roleKey);

  Future<void> clearToken() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_roleKey);
  }
}
