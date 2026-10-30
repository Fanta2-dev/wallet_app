import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Erreur affichable à l'utilisateur (message déjà en français)
class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, {this.status});

  @override
  String toString() => message;
}

class ApiResponse {
  final int status;
  final dynamic body;
  ApiResponse(this.status, this.body);

  bool get ok => status >= 200 && status < 300;

  /// Message d'erreur renvoyé par les microservices : {"status":..,"error":".."}
  String get errorMessage {
    if (body is Map && (body as Map)['error'] != null) return (body as Map)['error'].toString();
    if (body is Map && (body as Map)['message'] != null) return (body as Map)['message'].toString();
    return 'Erreur serveur ($status)';
  }
}

/// Client HTTP commun aux deux microservices : ajoute le JWT et normalise les erreurs.
class ApiClient {
  final AppConfig config;
  String? token;

  /// Appelé quand le serveur répond 401 alors qu'un token était envoyé (session expirée)
  void Function()? onUnauthorized;

  ApiClient(this.config);

  Future<ApiResponse> send(
    String method,
    String baseUrl,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? tokenOverride,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    final t = tokenOverride ?? token;
    if (t != null) headers['Authorization'] = 'Bearer $t';

    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(streamed);

      dynamic data;
      if (res.bodyBytes.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(res.bodyBytes));
        } catch (_) {
          data = null;
        }
      }
      if (res.statusCode == 401 && t != null) {
        onUnauthorized?.call();
      }
      return ApiResponse(res.statusCode, data);
    } on TimeoutException {
      throw ApiException('Le serveur ne répond pas (délai dépassé).');
    } catch (_) {
      throw ApiException(
          'Impossible de joindre le serveur ($baseUrl). Vérifiez que Docker est lancé et l\'adresse dans ⚙ Paramètres.');
    }
  }

  /// Envoie la requête et lève une [ApiException] si le statut n'est pas 2xx
  Future<dynamic> call(
    String method,
    String baseUrl,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? tokenOverride,
  }) async {
    final res = await send(method, baseUrl, path,
        body: body, query: query, tokenOverride: tokenOverride);
    if (!res.ok) {
      if (res.status == 401) {
        throw ApiException('Session expirée, reconnectez-vous.', status: 401);
      }
      throw ApiException(res.errorMessage, status: res.status);
    }
    return res.body;
  }
}
