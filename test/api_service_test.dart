import 'dart:typed_data';

import 'dart:convert';

import 'package:apptest/core/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
  });

  test(
    'sends the bearer token and JSON body to the normalized API URL',
    () async {
      late http.Request sentRequest;
      final client = MockClient((request) async {
        sentRequest = request;
        return http.Response('{"project":{"id":"1"}}', 201);
      });
      addTearDown(client.close);

      final api = ApiService(client: client, baseUrl: 'http://localhost/api/');
      final result = await api.post('projects', body: {'name': 'Chantier'});

      expect(sentRequest.url, Uri.parse('http://localhost/api/projects'));
      expect(sentRequest.headers['authorization'], 'Bearer test-token');
      expect(sentRequest.headers['content-type'], 'application/json');
      expect(jsonDecode(sentRequest.body), {'name': 'Chantier'});
      expect(result['project'], {'id': '1'});
    },
  );

  test('reports successful responses that are not JSON objects', () async {
    final client = MockClient(
      (_) async => http.Response('["unexpected"]', 200),
    );
    addTearDown(client.close);

    final api = ApiService(client: client, baseUrl: 'http://localhost/api');

    await expectLater(
      api.get('/projects'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 200)
            .having((error) => error.message, 'message', contains('invalide')),
      ),
    );
  });

  test('reports the target URL when the API connection fails', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('Connection refused'),
    );
    addTearDown(client.close);

    final api = ApiService(client: client, baseUrl: 'http://10.0.2.2:3000/api');

    await expectLater(
      api.get('/projects'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('http://10.0.2.2:3000/api/projects'),
            contains('Connection refused'),
          ),
        ),
      ),
    );
  });

  test('uploads a project image as authenticated multipart form data', () async {
    late http.Request sentRequest;
    final client = MockClient((request) async {
      sentRequest = request;
      return http.Response('{"url":"https://blob.example/photo.jpg"}', 201);
    });
    addTearDown(client.close);

    final api = ApiService(client: client, baseUrl: 'http://localhost/api');
    final result = await api.uploadProjectImage(
      projectId: '42',
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'chantier.jpg',
      contentType: 'image/jpeg',
    );

    expect(sentRequest.url, Uri.parse('http://localhost/api/uploads/project-image'));
    expect(sentRequest.headers['authorization'], 'Bearer test-token');
    expect(sentRequest.headers['content-type'], startsWith('multipart/form-data;'));
    expect(sentRequest.body, contains('projectId'));
    expect(sentRequest.body, contains('42'));
    expect(sentRequest.body, contains('chantier.jpg'));
    expect(result['url'], 'https://blob.example/photo.jpg');
  });
}
