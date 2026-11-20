import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static String? _token;
  static String? companyName;

  /// Stato di login osservabile dalla UI
  static final ValueNotifier<bool> loggedIn = ValueNotifier(false);

  /// Si incrementa quando viene pubblicato un annuncio (la bacheca si ricarica)
  static final ValueNotifier<int> jobsChanged = ValueNotifier(0);

  // ---------- Sessione persistente ----------
  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    companyName = prefs.getString('companyName');
    loggedIn.value = _token != null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('companyName');
    _token = null;
    companyName = null;
    loggedIn.value = false;
  }

  // ---------- Utilità ----------
  static Map<String, String> get _jsonHeaders =>
      {'Content-Type': 'application/json'};

  static Map<String, String> get _authHeaders =>
      {..._jsonHeaders, 'Authorization': 'Bearer $_token'};

  static dynamic _parse(http.Response r) {
    dynamic body;
    try {
      body = r.body.isEmpty ? null : jsonDecode(r.body);
    } catch (_) {}
    if (r.statusCode >= 400) {
      final msg = (body is Map && body['error'] != null)
          ? body['error'].toString()
          : 'Errore del server (${r.statusCode})';
      throw ApiException(msg);
    }
    return body;
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 20));
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Server non raggiungibile (timeout)');
    } on SocketException {
      throw ApiException('Server non raggiungibile. Controlla IP e rete.');
    } on http.ClientException {
      throw ApiException('Server non raggiungibile. Controlla IP e rete.');
    }
  }

  // ---------- Azienda ----------
  static Future<void> register(String name, String email, String password) =>
      _guard(() async {
        final r = await http.post(
          Uri.parse('$baseUrl/register'),
          headers: _jsonHeaders,
          body: jsonEncode({'name': name, 'email': email, 'password': password}),
        );
        _parse(r);
      });

  static Future<void> login(String email, String password) => _guard(() async {
    final r = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = _parse(r) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', body['token']);
    await prefs.setString('companyName', body['name']);
    _token = body['token'];
    companyName = body['name'];
    loggedIn.value = true;
  });

  static Future<void> createJob(
      String title, String description, String location) =>
      _guard(() async {
        final r = await http.post(
          Uri.parse('$baseUrl/jobs'),
          headers: _authHeaders,
          body: jsonEncode({
            'title': title,
            'description': description,
            'location': location,
          }),
        );
        _parse(r);
        jobsChanged.value++;
      });

  static Future<List<Job>> getMyJobs() => _guard(() async {
    final r = await http.get(Uri.parse('$baseUrl/my-jobs'),
        headers: _authHeaders);
    final list = _parse(r) as List;
    return list.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  });

  static Future<List<Application>> getApplications(int jobId) =>
      _guard(() async {
        final r = await http.get(
            Uri.parse('$baseUrl/jobs/$jobId/applications'),
            headers: _authHeaders);
        final list = _parse(r) as List;
        return list
            .map((e) => Application.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  static Future<void> openCv(Application a) => _guard(() async {
    final r = await http.get(Uri.parse('$baseUrl/uploads/${a.cvFile}'));
    if (r.statusCode != 200) throw ApiException('Curriculum non trovato');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${a.cvFile}');
    await file.writeAsBytes(r.bodyBytes);
    final res = await OpenFilex.open(file.path);
    if (res.type != ResultType.done) {
      throw ApiException('Impossibile aprire il file: ${res.message}');
    }
  });

  // ---------- Candidato (nessun login) ----------
  static Future<List<Job>> getJobs() => _guard(() async {
    final r = await http.get(Uri.parse('$baseUrl/jobs'));
    final list = _parse(r) as List;
    return list.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
  });

  static Future<void> apply({
    required int jobId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String message,
    required PlatformFile cv,
  }) =>
      _guard(() async {
        final req = http.MultipartRequest(
            'POST', Uri.parse('$baseUrl/jobs/$jobId/apply'))
          ..fields['first_name'] = firstName
          ..fields['last_name'] = lastName
          ..fields['email'] = email
          ..fields['phone'] = phone
          ..fields['message'] = message;
        req.files.add(
            await http.MultipartFile.fromPath('cv', cv.path!, filename: cv.name));
        final streamed = await req.send();
        final r = await http.Response.fromStream(streamed);
        _parse(r);
      });
}