import 'dart:convert';

import 'package:http/http.dart' as http;

class PairingResult {
  final String ingestToken;
  final int eventId;
  final String eventName;
  final int driverId;
  final String driverName;

  const PairingResult({
    required this.ingestToken,
    required this.eventId,
    required this.eventName,
    required this.driverId,
    required this.driverName,
  });

  factory PairingResult.fromJson(Map<String, dynamic> json) => PairingResult(
        ingestToken: json['ingestToken'] as String,
        eventId: json['eventId'] as int,
        eventName: json['eventName'] as String,
        driverId: json['driverId'] as int,
        driverName: json['driverName'] as String,
      );
}

class PairingException implements Exception {
  final String message;
  PairingException(this.message);
  @override
  String toString() => message;
}

/// Exchanges a short-lived pairing code (issued from the PANEL) for an ingest
/// token scoped to one live-timing session — see backend domain/livetiming.
class PairingClient {
  final String backendBaseUrl;
  PairingClient(this.backendBaseUrl);

  Future<PairingResult> exchange(String pairingCode) async {
    final uri = Uri.parse('$backendBaseUrl/api/livetiming/sessions/exchange');
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'pairingCode': pairingCode.trim()}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw PairingException('Nie można połączyć z serwerem ($backendBaseUrl): $e');
    }

    if (response.statusCode != 200) {
      String message = 'Parowanie nie powiodło się (${response.statusCode})';
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
}
