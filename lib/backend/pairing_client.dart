/// Response shape shared by every way of starting a live-timing session — today just
/// AppSessionClient.startSession (Discord login, see app_session_client.dart). Kept in its own
/// file since it's a plain data model with no dependency on how the session was started.
class PairingResult {
  final String ingestToken;
  // Null for an ad-hoc session not tied to any league event (see backend
  // domain/livetiming — event assignment is optional).
  final int? eventId;
  final String? eventName;
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
        eventId: json['eventId'] as int?,
        eventName: json['eventName'] as String?,
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
