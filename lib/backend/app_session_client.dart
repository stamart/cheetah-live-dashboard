import 'dart:convert';

import 'package:http/http.dart' as http;

import 'pairing_client.dart';

class JoinableEvent {
  final int id;
  final String name;
  final String sim;
  final DateTime? startAt;

  const JoinableEvent({required this.id, required this.name, required this.sim, this.startAt});

  factory JoinableEvent.fromJson(Map<String, dynamic> json) => JoinableEvent(
        id: json['id'] as int,
        name: json['name'] as String,
        sim: json['sim'] as String? ?? '',
        startAt: json['startAt'] != null ? DateTime.tryParse(json['startAt'] as String) : null,
      );
}

/// Thrown when the stored app token is invalid or was revoked (e.g. logged out from another
/// device, or the backend's row got cleaned up) — callers should drop the stored token and
/// send the driver back to the Discord login screen.
class AppTokenExpiredException implements Exception {}

/// Starts a live-timing session for an already-Discord-authenticated app user — no pairing
/// code involved (see backend LiveTimingAppController). eventId is optional: omitted/null
/// means an ad-hoc session, matching the panel's self-service page.
class AppSessionClient {
  final String backendBaseUrl;
  AppSessionClient(this.backendBaseUrl);

  Future<PairingResult> startSession(String appToken, {int? eventId}) async {
    final uri = Uri.parse('$backendBaseUrl/api/livetiming/app/sessions/start');
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'X-App-Token': appToken},
            body: jsonEncode({if (eventId != null) 'eventId': eventId}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw PairingException('Nie można połączyć z serwerem ($backendBaseUrl): $e');
    }

    if (response.statusCode == 401) {
      throw AppTokenExpiredException();
    }
    if (response.statusCode != 200) {
      String message = 'Nie udało się rozpocząć sesji (${response.statusCode})';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['message'] != null) message = body['message'] as String;
      } catch (_) {
        // Non-JSON error body — keep the generic message above.
      }
      throw PairingException(message);
    }

    return PairingResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<JoinableEvent>> listJoinableEvents(String appToken) async {
    final uri = Uri.parse('$backendBaseUrl/api/livetiming/app/events');
    final http.Response response;
    try {
      response = await http.get(uri, headers: {'X-App-Token': appToken}).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw PairingException('Nie można połączyć z serwerem ($backendBaseUrl): $e');
    }

    if (response.statusCode == 401) {
      throw AppTokenExpiredException();
    }
    if (response.statusCode != 200) {
      throw PairingException('Nie udało się pobrać listy eventów (${response.statusCode})');
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => JoinableEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Best-effort — the token gets deleted locally regardless of whether this call succeeds.
  Future<void> logout(String appToken) async {
    final uri = Uri.parse('$backendBaseUrl/api/livetiming/app/logout');
    try {
      await http.post(uri, headers: {'X-App-Token': appToken}).timeout(const Duration(seconds: 10));
    } catch (_) {
      // ignore — local cleanup still happens
    }
  }
}
