import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'gt7_packet_decoder.dart';
import 'gt7_telemetry.dart';

/// Sends the GT7 heartbeat and decodes incoming telemetry over UDP. GT7 stops
/// sending packets if the heartbeat lapses, so it's resent periodically, not
/// just once. The PS5 always streams telemetry to local port 33740 on the
/// client — NOT to whatever ephemeral source port the heartbeat happened to
/// come from — so the receiving socket must be explicitly bound there (this
/// matches every reference implementation, e.g. snipem/gt7dashboard's
/// `s.bind(('0.0.0.0', 33740))`). Binding to an ephemeral port instead sends
/// heartbeats fine but never receives anything back.
class Gt7Socket {
  Gt7Socket(this.ps5Ip);

  static const _heartbeatPort = 33739;
  static const _telemetryPort = 33740;
  static const _heartbeatInterval = Duration(seconds: 1);
  static const _badPacketDisconnectThreshold = 30;

  final String ps5Ip;

  RawDatagramSocket? _socket;
  Timer? _heartbeatTimer;
  StreamSubscription<RawSocketEvent>? _subscription;
  int _consecutiveBadPackets = 0;
  bool _connected = false;

  // Diagnostics-only counters — logged sparingly so a real session (60Hz once
  // GT7 is talking) doesn't flood logcat.
  int _rawDatagramsReceived = 0;
  int _decryptFailures = 0;

  final _telemetryController = StreamController<Gt7Telemetry>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Gt7Telemetry> get telemetry => _telemetryController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  bool get connected => _connected;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _telemetryPort);
    debugPrint('[GT7] UDP socket bound on local port ${_socket!.port}, heartbeat target $ps5Ip:$_heartbeatPort');
    _subscription = _socket!.listen(_onEvent);
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
  }

  void _sendHeartbeat() {
    try {
      final sent = _socket?.send(const [0x41], InternetAddress(ps5Ip), _heartbeatPort); // 'A'
      debugPrint('[GT7] heartbeat -> $ps5Ip:$_heartbeatPort (sent=$sent bytes, packetsIn=$_rawDatagramsReceived, decryptFail=$_decryptFailures)');
    } catch (e) {
      debugPrint('[GT7] heartbeat send failed: $e');
    }
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;

    _rawDatagramsReceived++;
    if (_rawDatagramsReceived <= 3) {
      debugPrint('[GT7] raw datagram #$_rawDatagramsReceived from ${datagram.address.address}:${datagram.port}, ${datagram.data.length} bytes');
    }

    final decrypted = decryptGt7Packet(datagram.data);
    if (decrypted == null) {
      _decryptFailures++;
      if (_decryptFailures <= 3 || _decryptFailures % 60 == 0) {
        debugPrint('[GT7] decrypt/magic check failed (#$_decryptFailures) on a ${datagram.data.length}-byte packet');
      }
      _consecutiveBadPackets++;
      if (_connected && _consecutiveBadPackets > _badPacketDisconnectThreshold) {
        debugPrint('[GT7] too many bad packets in a row, marking disconnected');
        _connected = false;
        _connectionController.add(false);
      }
      return;
    }

    _consecutiveBadPackets = 0;
    if (!_connected) {
      debugPrint('[GT7] first valid packet decrypted — connected');
      _connected = true;
      _connectionController.add(true);
    }

    final telemetry = parseGt7Packet(decrypted);
    if (telemetry != null) _telemetryController.add(telemetry);
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
    _telemetryController.close();
    _connectionController.close();
  }
}
