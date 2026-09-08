import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

class DiscordAppAuthResult {
  final String appToken;
  final int driverId;
  final String driverName;

  const DiscordAppAuthResult({
    required this.appToken,
    required this.driverId,
    required this.driverName,
  });
}

class DiscordAuthException implements Exception {
  final String message;
  DiscordAuthException(this.message);
  @override
  String toString() => message;
}

/// Discord login for the app — replaces pairing codes. The app never sees the Discord client
/// secret: it only opens the system browser to Discord's consent screen and hands the resulting
/// "code" to our backend, which does the actual token exchange server-side (see
/// domain/livetiming/service/LiveTimingAppAuthService on the backend).
///
/// Uses PKCE (RFC 7636) so that even if another app registered the same cheetahlive:// scheme,
/// it couldn't complete the login with an intercepted code — it wouldn't have the verifier.
class DiscordAuthClient {
  static const _clientId = '1416788884188172309';
  static const _redirectUri = 'cheetahlive://auth';
  static const _callbackUrlScheme = 'cheetahlive';

  Future<DiscordAppAuthResult> login(String backendBaseUrl) async {
    final verifier = _generateCodeVerifier();
    final challenge = _codeChallengeFromVerifier(verifier);

    final authorizeUrl = Uri.https('discord.com', '/api/oauth2/authorize', {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope': 'identify',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'prompt': 'consent',
    });

    final String callbackResult;
    try {
      // preferEphemeral is deliberately NOT set — it enables incognito-style ephemeral
      // browsing (no cookies persisted), which would force Discord's username/password
      // to be re-entered on every login instead of reusing the browser's normal session
      // after the first one. The actual "doesn't return to app" fix was the
      // flutter_web_auth_2 5.x upgrade (AuthTabIntent), not this option.
      callbackResult = await FlutterWebAuth2.authenticate(
        url: authorizeUrl.toString(),
        callbackUrlScheme: _callbackUrlScheme,
      );
    } catch (e) {
      throw DiscordAuthException('Logowanie przez Discord przerwane lub nieudane: $e');
    }

    final code = Uri.parse(callbackResult).queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw DiscordAuthException('Discord nie zwrócił kodu autoryzacji.');
    }

    return _exchangeWithBackend(backendBaseUrl, code, verifier);
  }

  Future<DiscordAppAuthResult> _exchangeWithBackend(String backendBaseUrl, String code, String verifier) async {
    final uri = Uri.parse('$backendBaseUrl/api/livetiming/app/auth/discord');
    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code': code,
              'redirectUri': _redirectUri,
              'codeVerifier': verifier,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw DiscordAuthException('Nie można połączyć z serwerem ($backendBaseUrl): $e');
    }

    if (response.statusCode != 200) {
      String message = 'Logowanie nie powiodło się (${response.statusCode})';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['message'] != null) message = body['message'] as String;
      } catch (_) {
        // Non-JSON error body — keep the generic message above.
      }
      throw DiscordAuthException(message);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return DiscordAppAuthResult(
      appToken: json['appToken'] as String,
      driverId: json['driverId'] as int,
      driverName: json['driverName'] as String,
    );
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(64, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _codeChallengeFromVerifier(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
